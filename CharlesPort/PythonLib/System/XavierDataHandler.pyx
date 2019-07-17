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

		self.realtimeDCSData = mp.Event();
		self.realtimeDCSQueue = mp.Queue(DataHandler.QUEUE_DEPTH);

		self.realtimeNIRSData = mp.Event();
		self.realtimeNIRSQueue = mp.Queue(DataHandler.QUEUE_DEPTH);

		self.outFileDCS = None;
		self.outFileDCS = None;
		if(directory == None):
			directory = '';
		self.directory = directory;
		self.debug = mp.Event();
		self.debug.set();
		if(filename != None):
			if(not(directory[-1] == '/')):
				self.directory = directory + '/'
			os.makedirs(self.directory, exist_ok=True);
			self.outFileDCS = open(self.directory + filename + "_DCS", 'wb');
			self.outFileNIRS = open(self.directory + filename + "_NIRS", 'wb');
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
			bufferDCS = array.array(self.sampleSizeCode, [0]*len(self.dataBuffer)/2);
			bufferNIRS = array.array(self.sampleSizeCode, [0]*len(self.dataBuffer)/2);
			while(not self.isDead.is_set()):				
				if(self.dataPipe.poll(DataHandler._TIMEOUT)):					
					self.dataPipe.recv_bytes_into(self.dataBuffer);	
					self.dataBuffer.byteswap();				

					if(not self.isPaused.is_set()):
						bufferDCS = self.dataBuffer[0::2];
						bufferNIRS = self.dataBuffer[1::2];
						if(not self.debug.is_set()):						
							bufferDCS.tofile(self.outFileDCS);	
							bufferNIRS.tofile(self.outFileNIRS);					

						if(self.realtimeDCSData.is_set()):						
							try:							
								self.realtimeDCSQueue.put_nowait(copy.copy(bufferDCS));						
							except queue.Full:														
								self.MPI.put_nowait("RealtimeDCS Buffer Overrun");							
								self.realtimeDCSData.clear();					

						if(self.realtimeNIRSData.is_set()):						
							try:							
								self.realtimeNIRSQueue.put_nowait(copy.copy(bufferNIRS));						
							except queue.Full:														
								self.MPI.put_nowait("RealtimeNIRS Buffer Overrun");							
								self.realtimeNIRSData.clear();		

				if(self.isOutFileUpdate.is_set()):
					filename = self.fileUpdateQueue.get(False);
					self.outFileDCS.close();
					self.outFileDCS = open(filename+"_DCS", 'wb');
					self.outFileNIRS.close();
					self.outFileNIRS = open(filename+"_NIRS", 'wb');
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
		if(not self.outFileDCS == None):
			self.outFileDCS.close();
		if(not self.outFileNIRS == None):
			self.outFileNIRS.close();
		
		time.sleep(0.5);
		while(True):
			try:
				(self.realtimeDCSQueue.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.realtimeDCSQueue.empty():
					continue
				else:
					break;
			try:
				(self.realtimeNIRSQueue.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.realtimeNIRSQueue.empty():
					continue
				else:
					break;

		self.realtimeDCSQueue.close();
		self.realtimeDCSQueue.cancel_join_thread();
		self.realtimeNIRSQueue.close();
		self.realtimeNIRSQueue.cancel_join_thread();
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

	def getRealtimeDCSQueue(self):
		return self.realtimeDCSQueue;

	def enableRealtimeDCS(self):
		self.realtimeDCSData.set();

	def disableRealtimeDCS(self):
		self.realtimeDCSData.clear();			

	def getRealtimeNIRSQueue(self):
		return self.realtimeNIRSQueue;

	def enableRealtimeNIRS(self):
		self.realtimeNIRSData.set();

	def disableRealtimeNIRS(self):
		self.realtimeNIRSData.clear();
 
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


