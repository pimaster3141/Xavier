import multiprocessing as mp
from multiprocessing import shared_memory
import USBReader
import Logger
import FileWriter
cimport cython
import os
import psutil
import time

class DataHandler(mp.Process):
	_NICENESS = -10;
	_POLL_STEP = 1.0/100;

	def __str__(self):
		return("Data Handler");

	def __init__(self, logger, shmName, shmReadyName):
		mp.Process.__init__(self);

		self.logger = logger;
		self.isDead = mp.Event();

		self.shmName = shmName;
		self.shmReadyName = shmReadyName;
		self.shm = shared_memory(create=False, name=self.shmName);
		self.shmReady = shared_memory(create=False, name=self.shmReadyName);
		
		self.fileWriter=FileWriter.FileWriter(self.logger);

		self.logger.printMessage(self, "Data Handler Created", 2);

	def run(self):
		try:
			self.logger.printMessage(self, "Changing Niceness...", 3);
			p = psutil.Process(os.getpid());
			p.nice(DataHandler._NICENESS);
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

		while(not self.isDead.is_set()):
			if(rdy[counter] & 0x80):
				break;

			self.fileWriter.writerUpdateTasks();

			if(rdy[counter] & 0x01 == 0):
				time.sleep(DataHandler._POLL_STEP);
				continue;

			startIndex = counter*bufferWidth;
			endIndex = (counter+1)*bufferWidth;
			self.fileWriter.writeData(buf[startIndex:endIndex]);

			rdy[counter] &= ~(0x01);

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

		self.fileWriter.cleanup();


	def enableWrite(self):
		self.fileWriter.enableWrite();

	def disableWrite(self):
		self.fileWriter.disableWrite();

	def updateFilePath(self, filePath):
		self.fileWriter.updateFilePath(filePath);

