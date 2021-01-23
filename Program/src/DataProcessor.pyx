# distutils: extra_compile_args=-fopenmp
# distutils: extra_link_args=-fopenmp
# distutils: define_macros=NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION

import multiprocessing as mp
from multiprocessing import shared_memory
import queue
import os
import psutil
import Logger
import USBReader
import Parser
import G2Calc
import time
import FitCore
from libc.stdint cimport uint8_t
from libc.stdint cimport uint16_t
cimport cython
import numpy as np
cimport numpy as np

class DataProcessor(mp.Process):
	_NICENESS = 15;
	_POLL_STEP = 1.0/60;
	_G2_LEVELS = 12
	_G2_DEPTH = 500;
	_QUEUE_DEPTH = 100;

	def __str__(self):
		return("Data Processor");

	def __init__(self, logger, shmName, shmReadyName, sampleRate, g2Average=[]):
		mp.Process.__init__(self);

		self.logger = logger;
		self.isDead = mp.Event();

		self.shmName = shmName;
		self.shmReadyName = shmReadyName;
		self.shm = shared_memory(create=False, name=self.shmName);
		self.shmReady = shared_memory(create=False, name=self.shmReadyName);

		self.sampleRate = sampleRate;
		self.averages = [];
		self.updateAverages(g2Average);

		self.outputBuffer = mp.Queue(DataProcessor._QUEUE_DEPTH);

		self.logger.printMessage(self, "Data Processor Created", 2);

	def run(self):
		try:
			self.logger.printMessage(self, "Changing Niceness...", 3);
			p = psutil.Process(os.getpid());
			p.nice(DataProcessor._NICENESS);
		except Exception as e:
			self.logger.printMessage(self, "Cannot Change Niceness", -2);
			self.logger.printError(self, e);

		cdef int counter = 0;
		cdef int bufferDepth = USBReader.DeviceReader._BUFFER_DEPTH;
		cdef int bufferWidth = self.shm.size()/bufferDepth;
		cdef unsigned char [::1] buf = self.shm.buf();
		cdef unsigned char [::1] rdy = self.shmReady.buf();
		cdef int startIndex = 0;
		cdef int endInddex = 0;

		cdef uint8_t[:, ::1] spadData_view;
		cdef uint8_t[:, ::1] dDataAll_view;
		cdef uint16_t[::1] aDataAll_view;
		cdef unsigned char levels = DataProcessor._G2_LEVELS;
		cdef double pollStep = DataProcessor._POLL_STEP;
		cdef int avg_i = 0;
		cdef int avgLength = 0;

		cdef double[::1] delayTimes = G2Calc.getDelayTimes(bufferWidth>>2, levels, self.sampleRate)
		cdef int g2Length = delayTimes.shape[0];
		cdef np.ndarray g2 = np.zeros((4, g2Length), dtype=np.double);
		cdef double[:,::1] g2_view = g2;
		cdef np.ndarray outputBuffer = np.zeros((DataProcessor._G2_DEPTH, 4, g2Length), dtype=np.double);
		
		cdef np.ndarray snr = np.zeros((4, g2Length), dtype=np.double);
		cdef np.ndarray g2Averaged = np.zeros((4, g2Length), dtype=np.double);
		cdef np.ndarray beta = np.zeros((4), dtype=np.double);
		cdef np.ndarray adb = np.zeros((4), dtype=np.double);
		cdef np.ndarray dData = np.zeros((4), dtype=np.uint8);
		cdef np.ndarray aData = np.zeros((4), dtype=np.double);

		try:
			while(not self.isDead.is_set()):
				if(rdy[counter] & 0x80):
					break;

				if(rdy[counter] & 0x02 == 0):
					time.sleep(pollStep);
					continue;

				startIndex = counter*bufferWidth;
				endIndex = (counter+1)*bufferWidth;
				spadData_view, aDataAll_view, dDataAll_view = Parser.parse(buf[startIndex:endIndex]);

				g2_view = G2Calc.quadCorrelate(spadData_view, levels);
				g2 = np.asarray(g2_view);
				
				avgLength = len(self.averages);
				if(avgLength > 0):
					for avg_i in range(avgLength):
						avg = self.averages[avg_i];
						g2Averaged[avg_i,:] = np.mean(g2[avg[0]:avg[1]+1], axis=0);
				else:
					g2Averaged = g2;

				outputBuffer[0, :, :] = g2Averaged;
				if(avgLength == 0):
					avgLength = 4;
				for avg_i in range(avgLength):
					snr[avg_i,:] = G2Calc.calcSNR(outputBuffer[avg_i,:,:])
					adb[avg_i], beta[avg_i] = FitCore.G2Fit(g2Averaged[avg_i,:], delayTimes, snr[avg_i, :], p0=(adb[avg_i], beta[avg_i]))
				np.roll(outputBuffer, 1, axis=0);

				
				dData = np.mean(np.asarray(dDataAll_view), axis=1);
				aData = np.mean(np.asarray(aDataAll_view), axis=1);

				try:
					self.outputBuffer.put_nowait((g2Averaged, snr, beta, adb, dData, aData));
				except queue.Full:
					self.logger.printError(self, "output buffer full");
					pass;





				rdy[counter] &= ~(0x02);

				counter += 1;
				if(counter >= bufferDepth):
					counter = 0;


		except Exception as e:
			self.logger.printError(self, str(e));
		finally:
			self.shutdown();

	def updateAverages(self, averages=[]):
		if(len(averages) > 4):
			self.logger.printError(self, "Too many Averages");
			return False;
		for a in averages:
			if(not len(a) == 2):
				self.logger.printError(self, "Cannot Update Averages - Invalid Parameters");
				return False;
			if(a[0] > a[1] or a[0] < 0 or a[1] > 4):
				self.logger.printError(self, "Cannot Update Averages - Invalid Parameters");
				return False;
		self.averages = averages;
		return True;


	def stop(self):
		self.isDead.set();

	def shutdown(self):
		self.logger.printMessage(self, "Shutting Down", 3);
		self.isDead.set();

		self.shm.close();
		self.shmReady.close();

		time.sleep(0.5);
		while(True):
			try:
				(self.outputBuffer.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.outputBuffer.empty():
					continue
				else:
					break;
		self.outputBuffer.close();
		self.outputBuffer.cancel_join_thread();

	def getOutputBuffer(self):
		return self.outputBuffer;
