import multiprocessing as mp
from multiprocessing import shared_memory
import usb.core
import usb.util
import time
import psutil
import os
import Logger
from cython.parallel import prange
cimport cython

class DeviceReader(mp.Process):
	_READ_SIZE = 524288/4; #bytes #this is about 50Tr/s at 2MHz clock,4B/Tr
	_BUFFER_DEPTH = 1024; 
	# _SHM_NAME = "USB_SHM"
	# _SHM_READY_NAME = "SHM_READY"
	_NICENESS = -15;

	def __str__(self):
		return "DeviceReader";

	def __init__(self, logger, bufferWidth):
		mp.Process.__init__(self);

		self.logger = logger;
		self.bufferWidth = bufferWidth;
		self.isDead = mp.Event();
		self.stopped = mp.Event();

		# self.shm = shared_memory.SharedMemory(create=True, name=DeviceReader._SHM_NAME, size=bufferWidth*DeviceReader._BUFFER_DEPTH);
		# self.shmReady = shared_memory.SharedMemory(create=True, name=DeviceReader._SHM_READY_NAME, size=DeviceReader._BUFFER_DEPTH);
		# self.dataReady = [mp.Event()]*DeviceReader._BUFFER_DEPTH;
		self.shm = shared_memory.SharedMemory(create=True, size=bufferWidth*DeviceReader._BUFFER_DEPTH);
		self.shmReady = shared_memory.SharedMemory(create=True, size=DeviceReader._BUFFER_DEPTH);
		self.shmName = self.shm.name();
		self.shmReadyName = self.shmReady.name();

		self.logger.printMessage(self, "USBDevice Created", 2);

	def run(self):
		try:
			self.logger.printMessage(self, "Changing Niceness...", 3);
			p = psutil.Process(os.getpid());
			p.nice(DeviceReader._NICENESS);
		except Exception as e:
			self.logger.printMessage(self, "Cannot Change Niceness", -2);
			self.logger.printError(self, e);

	def stop(self):
		self.isDead.set();

	@cython.boundscheck(False)
	@cython.wraparound(False)
	def shutdown(self):
		self.logger.printMessage(self, "Shutting Down", 3);
		self.isDead.set();
		self.stopped.wait(5);

		cdef unsigned char [::1] rdy = self.shmReady.buf();
		cdef int i = 0;
		cdef int bufferDepth = DeviceReader._BUFFER_DEPTH;
		for i in prange(bufferDepth, nogil=True):
			rdy[i] = 0x80;

		self.shm.close();
		self.shm.unlink();
		self.shmReady.close();
		self.shmReady.unlink();

	def getSHMName(self):
		return(self.shmName);

	def getSHMReadyName(self):
		return(self.shmReadyName);



@cython.boundscheck(False)
@cython.wraparound(False)
class USBReader(DeviceReader):
	_ENDPOINT_ID = 0x81;
	_TIMEOUT = 3000;

	def __str__(self):
		return("USBReader");

	def __init__(self, logger, device, bufferWidth=DeviceReader._READ_SIZE):
		super().__init__(logger, bufferWidth);
		
		self.device = device;

		try:
			self.device.read(USBReader._ENDPOINT_ID, 524288, USBReader._TIMEOUT);
			self.logger.printMessage(self, "USB Device Buffer Flushed", 3);
		except Exception as e:
			self.logger.printMessage(self, "Device not ready!", -2);
			raise Exception("Device did not flush buffer");

	def run(self):
		super().run();

		self.logger.printMessage(self, "Starting USB Reader", 1);

		cdef int numRead = 0;
		cdef int counter = 0;
		cdef int bufferWidth = self.bufferWidth;
		cdef int startIndex = 0;
		cdef int endIndex = 0;
		cdef unsigned char [::1] buf = self.shm.buf();
		cdef unsigned char [::1] rdy = self.shmReady.buf();
		cdef int i = 0;
		cdef int bufferDepth = DeviceReader._BUFFER_DEPTH;
		for i in prange(bufferDepth, nogil=True):
			buf[i] = 0;
			rdy[i] = 0;

		cdef char endpoint = USBReader._ENDPOINT_ID;
		cdef int timeout = USBReader._TIMEOUT;

		try:
			while(not self.isDead.is_set()):
				startIndex = counter*bufferWidth;
				endIndex = (counter+1)*bufferWidth;
				numRead = self.device.read(endpoint, buf[startIndex:endIndex], timeout);
				if(numRead != bufferWidth):
					break;

				rdy[counter] = 3;
				counter = counter + 1;
				if(counter >= bufferDepth):
					counter = 0;

			if(numRead != bufferWidth):
				self.logger.printMessage(self, "Device Failure", -2);
				raise Exception("Transfer Interrupted");

		except Exception as e:
			self.logger.printError(self, e)

		finally:
			self.stopped.set();
			self.shutdown();




@cython.boundscheck(False)
@cython.wraparound(False)
class FileReader(DeviceReader):

	def __str__(self):
		return("FileReader");

	def __init__(self, logger, file, period, bufferWidth=DeviceReader._READ_SIZE):
		super().__init__(logger, bufferWidth);

		self.file = file;
		self.period = period;

	def run(self):
		super().run();

		self.logger.printMessage(self, "Starting File Reader", 1);

		cdef int numRead = 0;
		cdef int counter = 0;
		cdef int bufferWidth = self.bufferWidth;
		cdef int startIndex = 0;
		cdef int endIndex = 0;

		cdef double period = self.period;
		cdef double lastTime = time.time();
		cdef double currentTime = time.time();
		cdef double pauseTime = 0;
		cdef unsigned char [::1] buf = self.shm.buf();
		cdef unsigned char [::1] rdy = self.shmReady.buf();
		cdef int i = 0;
		cdef int bufferDepth = DeviceReader._BUFFER_DEPTH;
		for i in prange(bufferDepth, nogil=True):
			buf[i] = 0;
			rdy[i] = 0;

		with open(self.file, 'rb') as inFile:
			while(not self.isDead.is_set()):
				startIndex = counter*bufferWidth;
				endIndex = (counter+1)*bufferWidth;
				numRead = inFile.readinto(buf[startIndex:endIndex]);
				if(numRead != bufferWidth):
					break;

				currentTime = time.time();
				pauseTime = period-(currentTime-lastTime);
				pauseTime = max(pauseTime, 0);
				time.sleep(pauseTime);

				rdy[counter] = 3;
				counter = counter + 1;
				if(counter >= bufferDepth):
					counter = 0;
				lastTime = currentTime;

		self.stopped.set();
		self.shutdown();
		