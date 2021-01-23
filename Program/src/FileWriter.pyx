# distutils: extra_compile_args=-fopenmp
# distutils: extra_link_args=-fopenmp
# distutils: define_macros=NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION


from datetime import datetime
import multiprocessing as mp
cimport cython
import os
import queue
import time

cdef class FileWriter:
	_UPDATE_TIMEOUT = 5;

	def __str__(self):
		return("File Writer");

	def __init__(self, logger, filePath=None):
		self.logger = logger;
		self.logger.printMesage(self, "Creating File Writer Object");

		self.filePath = None;
		self.enableWrite = mp.Event();
		self.enableWrite.clear();
		self.outFile = None;
		self.filePathQueue = mp.Queue(1);

		self.setFilePath(filePath);
		self.setWriter();

		return;

	cpdef setFilePath(self, filePath):
		if not(filePath == None or filePath == ''):
			self.logger.printMesage(self, "Setting file path name to: " + filePath);
		else:
			filePath = None;
		self.filePath = filePath;
		return;

	cpdef setWriter(self):
		if(self.filePath == None):
			self.enableWrite.clear();
			return;
		newFile = open(self.directory+'/'+self.filePath, 'wb');
		self.logger.printMesage(self, "Updating output file");
		self.outFile = newFile;
		return;


	#public methods below:

	def updateFilePath(self, filePath):
		self.filePathQueue.put(filePath, timeout=FileWriter._UPDATE_TIMEOUT);
		return;

	def enableWrite(self):
		if not(self.filePath == None):
			self.enableWrite.set();
		return;

	def disableWrite(self):
		self.enableWrite.clear();
		return;


	#must be called from creating thread below:

	def writeData(self, data):
		if(self.enableWrite.is_set()):
			self.outFile.write(data);
		return;

	def writerUpdateTasks(self):
		try:
			filePath = self.filePathQueue.get_nowait();
			self.setFilePath(filePath);
			self.setWriter();
		except queue.empty as e:
			return;
		except Exception as e:
			self.logger.printError(self, e);
			return;
		return;

	def cleanup(self):
		time.sleep(0.5);
		while(True):
			try:
				(self.filePathQueue.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.filePathQueue.empty():
					continue
				else:
					break;
		self.filePathQueue.close();
		self.filePathQueue.cancel_join_thread();