import multiprocessing as mp
from multiprocessing import shared_memory
import os
import psutil
import Logger
import USBReader
import Parser
import G2Calc
cimport cython

class DataProcessor(mp.Process):
	_NICENESS = 15;
	_POLL_STEP = 1.0/60;
	_G2_LEVELS = 12

	def __str__(self):
		return("Data Processor");

	def __init__(self, logger, shmName, shmReadyName):
		mp.Process.__init__(self);

		self.logger = logger;
		self.isDead = mp.Event();

		self.shmName = shmName;
		self.shmReadyName = shmReadyName;
		self.shm = shared_memory(create=False, name=self.shmName);
		self.shmReady = shared_memory(create=False, name=self.shmReadyName);

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
		cdef uint8_t[::1] dDataAll_view;
		cdef uint16_t[::1] aDataAll_view;
		cdef double[:,::1] g2_View;
		cdef usnigned char levels = DataProcessor._G2_LEVELS;


		while(not self.isDead.is_set()):
			if(rdy[counter] & 0x80):
				break;

			if(rdy[counter] & 0x02 == 0):
				time.sleep(DataProcessor._POLL_STEP);
				continue;

			startIndex = counter*bufferWidth;
			endIndex = (counter+1)*bufferWidth;
			spadData_view, aDataAll_view, dDataAll_view = Parser.parse(buf[startIndex:endIndex]);
			g2_View = G2Calc.quadCorrelate(spadData_view, levels);
			

			self.fileWriter.writeData(buf[startIndex:endIndex]);

			rdy[counter] &= ~(0x02);

			counter += 1;
			if(counter >= bufferDepth):
				counter = 0;

		self.shutdown();

	def stop(self):
		self.isDead.set();

	def shutdown(self):
		self.logger.printMessage(self, "Shutting Down", 3);
		self.isDead.set();

		self.shm.close();
		self.shmReady.close();