import multiprocessing as mp
import array
import queue
import time
# import numpy as np
import copy
import psutil
import os

# import threading


class DataHandler(mp.Process):
# class DataHandler(threading.Thread):
	_TIMEOUT = 1
	QUEUE_DEPTH = 100;

	def __init__(self, MPI, dataPipe, bufferSize, sampleSize=2, filename=None, directory='./output/'):
		mp.Process.__init__(self);
		# threading.Thread.__init__(self);

		self.sampleSizeCode = None;
		if(sampleSize == 2):
			self.sampleSizeCode = 'h';
		else:
			raise Exception("Sample Size Code not implemented");

		self.MPI = MPI;
		self.dataPipe = dataPipe;
		if(int(bufferSize/sampleSize)*sampleSize != bufferSize):
			raise Exception("Sample Size not integer multiple of buffer size");

		self.dataBuffer = array.array(self.sampleSizeCode, [0]*int(bufferSize/sampleSize));

		self.realtimeData = mp.Event();
		self.realtimeQueue = mp.Queue(DataHandler.QUEUE_DEPTH);

		self.outFile = None;
		if(directory == None):
			directory = '';
		self.directory = directory;
		self.debug = mp.Event();
		self.debug.set();
		if(filename != None):
			if(not(directory[-1] == '/')):
				self.directory = directory + '/'
			os.makedirs(self.directory, exist_ok=True);
			self.outFile = open(self.directory + filename, 'wb');
			self.debug.clear();

		self.fileUpdateQueue = mp.Queue(2);
		self.isOutFileUpdate = mp.Event();

		self.isDead = mp.Event();
		self.isPaused = mp.Event();
		# self.isPaused.set();


	def run(self):
		p = psutil.Process(os.getpid());
		p.nice(-13);
		try: 
			while(not self.isDead.is_set()):				
				if(self.dataPipe.poll(DataHandler._TIMEOUT)):					
					self.dataPipe.recv_bytes_into(self.dataBuffer);					

					if(not self.isPaused.is_set()):
						if(not self.debug.is_set()):						
							self.dataBuffer.tofile(self.outFile);						

						if(self.realtimeData.is_set()):						
							try:							
								self.realtimeQueue.put_nowait(copy.copy(self.dataBuffer));						
							except queue.Full:														
								self.MPI.put_nowait("Realtime Buffer Overrun");							
								self.realtimeData.clear();		

				if(self.isOutFileUpdate.is_set()):
					filename = self.fileUpdateQueue.get(False);
					self.outFile.close();
					self.outFile = open(filename, 'wb');
					self.isOutFileUpdate.clear();												

		except Exception as e:			
			try:				
				self.MPI.put_nowait(e);				
			except Exception as ei:				
				pass
		finally:			
			self.shutdown();			
		
		return;

	def shutdown(self):
		self.isDead.set();
		if(not self.outFile == None):
			self.outFile.close();
		
		time.sleep(0.5);
		while(True):
			try:
				(self.realtimeQueue.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.realtimeQueue.empty():
					continue
				else:
					break;

		self.realtimeQueue.close();
		self.realtimeQueue.cancel_join_thread();
		try:				
			self.MPI.put_nowait("Stopping Handler");
			time.sleep(0.5);				
		except Exception as ei:
			pass
		finally:
			self.MPI.close();
			self.MPI.cancel_join_thread();


	def stop(self):		
		if(not self.isDead.is_set()):			
			self.isDead.set();			
			# self.join();			

	def getRealtimeQueue(self):
		return self.realtimeQueue;

	def enableRealtime(self):
		self.realtimeData.set();

	def disableRealtime(self):
		self.realtimeData.clear();

	def pause(self):
		self.isPaused.set();

	def resume(self):
		self.isPaused.clear();

	def updateOutFile(self, filename, directory=None):
		if(directory == None):
			directory = self.directory;
		else:
			if(not (type(directory) == str)):
				raise Exception("Directory not a string");
			if(not(directory[-1] == '/')):
				directory = directory + '/'
			os.makedirs(directory, exist_ok=True);

		if(filename == None):
			self.debug.set();
			return;
		else:
			if(not (type(filename) == str)):
				raise Exception("Filename not a string");
			self.debug.clear();

			filename = directory+filename;

			self.fileUpdateQueue.put(filename);
			self.isOutFileUpdate.set();
			while(self.isOutFileUpdate.is_set()):
				time.sleep(0.5);


