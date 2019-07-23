import setuptools
import pyximport; pyximport.install()

import multiprocessing as mp
import threading
import numpy as np
import os
from functools import partial
import queue
import time
import psutil

import sys
sys.path.insert(0, 'PythonLib');
import XavierFlowFit
import XavierG2Calc
import XavierNIRSCalc


# class DataProcessor(mp.Process):
class DataProcessor(threading.Thread):
	QUEUE_TIMEOUT = 1;
	QUEUE_DEPTH = 100;
	G2_LEVELS = 6;

	def __init__(self, MPI, inputBufferDCS, averages, legacy, fs, bufferSize, sampleSize=2, packetMultiple=1, calcFlow=False, SNRBufferDepth=500, calcNIRS=False, inputBufferNIRS=None, numProcessors=None):
		# mp.Process.__init__(self);
		threading.Thread.__init__(self);
		self.MPI = MPI;
		self.inputBufferDCS = inputBufferDCS;
		self.averages = averages
		self.legacy = legacy;
		self.fs = fs;
		self.packetMultiple = packetMultiple;
		# self.packetMultiple = 8;
		self.calcFlow = calcFlow;

		self.npDtype = None;
		if(sampleSize == 2 or sampleSize == 4):
			self.npDtype = np.int16;
		else:
			raise Exception("Sample Size Code not implemented");

		self.numProcessors = numProcessors;
		if(numProcessors==None):
			self.numProcessors = psutil.cpu_count(logical=False);

		self.packetSize = int(bufferSize/sampleSize);
		self.tauList = XavierG2Calc.mtAuto(np.ones(self.packetSize*self.packetMultiple-1), fs=fs, levels=DataProcessor.G2_LEVELS)[:,0];
		

		self.snrBuffer = np.ones((len(self.averages), SNRBufferDepth, len(self.tauList)-1));
		self.snrBuffer[0,:,:] = 0;

		self.g2Buffer = mp.Queue(DataProcessor.QUEUE_DEPTH);
		# self.countBuffer = mp.Queue(DataProcessor.QUEUE_DEPTH);
		self.flowBuffer = mp.Queue(DataProcessor.QUEUE_DEPTH);


		self.calcNIRS = calcNIRS;
		self.NIRSCalculator = XavierNIRSCalc.NIRSCalc(weight=4/(self.fs*10.0));
		self.inputBufferNIRS = inputBufferNIRS;
		self.nirsBuffer = mp.Queue(DataProcessor.QUEUE_DEPTH);
		
		self.isDead = mp.Event();

	def run(self):
		p = psutil.Process(os.getpid());
		p.nice(15);
		try:
			self.pool = mp.Pool(processes=self.numProcessors, initializer=limit_cpu);
			initialData = np.zeros(self.packetSize*self.packetMultiple, dtype=self.npDtype);
			g2Fcn = partial(XavierG2Calc.calculateG2, fs=self.fs, levels=DataProcessor.G2_LEVELS, legacy=self.legacy);
			while(not self.isDead.is_set()):				
				try:
					for i in range(self.packetMultiple):
						initialData[i*self.packetSize:(i+1)*self.packetSize] = self.inputBufferDCS.get(block=True, timeout=DataProcessor.QUEUE_TIMEOUT);
				except queue.Empty:					
					continue
				
				inWaiting = int(self.inputBufferDCS.qsize()/self.packetMultiple);	
				# print(inWaiting);			
				data = np.zeros((inWaiting+1, self.packetSize*self.packetMultiple), dtype=self.npDtype)
				data[0] = initialData;

				try:
					for i in range(inWaiting):
						for j in range(self.packetMultiple):
							data[i+1][j*self.packetSize:(j+1)*self.packetSize] = self.inputBufferDCS.get(block=True, timeout=DataProcessor.QUEUE_TIMEOUT);
				except queue.Empty:
					print("FUCK");
					pass


				g2Data = self.pool.map(g2Fcn, data);
				try:
					self.g2Buffer.put_nowait(g2Data); #(g2, vap)
				except queue.Full:
					pass

				# print(len(g2Data[0][0][0]))
				# time.sleep(0.2)

				if(self.calcFlow):
					g2Data = np.swapaxes(np.array([item[0] for item in g2Data]), 0, 1)[:,:,1:];
					flowData = []
					flowData = np.zeros((len(g2Data[0]), len(self.averages)));
					for c in  range(len(self.averages)):
						avg = self.averages[c]
						meanG2 = np.mean(g2Data[avg[0]:avg[1]+1], axis=0);
						self.snrBuffer = np.roll(self.snrBuffer, -1*(inWaiting+1), axis=1);
						self.snrBuffer[c, -(inWaiting+1):] = meanG2;
						SNR = XavierG2Calc.calcSNR(self.snrBuffer[c]);

						fcn=partial(XavierFlowFit.G2Fit, tauList=self.tauList[1:], SNR=SNR);
						data=np.array(self.pool.map(fcn, meanG2))[:, 0];
						# flowData.append(data);
						flowData[:,c] = data;

					# flowData = np.array(flowData);
					# flowData = np.swapaxes(flowData, 0, 1);
					try:
						self.flowBuffer.put_nowait(flowData); #(g2, vap)
					except queue.Full:
						pass

				if(self.calcNIRS):
					try:
						for i in range(self.packetMultiple):
							initialData[i*self.packetSize:(i+1)*self.packetSize] = self.inputBufferNIRS.get(block=True, timeout=DataProcessor.QUEUE_TIMEOUT);
					except queue.Empty:					
						continue
					
					inWaiting = int(self.inputBufferNIRS.qsize()/self.packetMultiple);	
					# print(inWaiting);			
					data = np.zeros((inWaiting+1, self.packetSize*self.packetMultiple), dtype=self.npDtype)
					data[0] = initialData;

					try:
						for i in range(inWaiting):
							for j in range(self.packetMultiple):
								data[i+1][j*self.packetSize:(j+1)*self.packetSize] = self.inputBufferNIRS.get(block=True, timeout=DataProcessor.QUEUE_TIMEOUT);
					except queue.Empty:
						print("FUCK");
						pass

					# nirsData = self.pool.map(XavierNIRSCalc.calculateNIRS, data);
					nirsData=[0]*len(data);
					for i in len(data):
						nirsData[i] = (self.NIRSCalculator.calculateNIRS(data[i]));
					try:
						self.nirsBuffer.put_nowait(nirsData); 
					except queue.Full:
						pass


		except Exception as e:
			print("SHITBALLS IM MURDERED");
			raise(e);
			try:
				self.MPI.put_nowait(e);
			except Exception as ei:
				pass
		finally:			
			self.shutdown();

	def shutdown(self):
		self.isDead.set();
		self.pool.close();
		self.pool.terminate();		
		self.pool.join();		
		
		time.sleep(0.5);
		while(True):
			try:
				(self.g2Buffer.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.g2Buffer.empty():
					continue
				else:
					break;
		while(True):
			try:
				(self.flowBuffer.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.flowBuffer.empty():
					continue
				else:
					break;
		while(True):
			try:
				(self.nirsBuffer.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.nirsBuffer.empty():
					continue
				else:
					break;

		self.g2Buffer.close();
		self.flowBuffer.close();
		self.nirsBuffer.close();
		self.g2Buffer.cancel_join_thread();
		self.flowBuffer.cancel_join_thread();
		self.nirsBuffer.cancel_join_thread();
		try:
			self.MPI.put_nowait("Stopping Processor");
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

	def getBuffers(self):
		return self.g2Buffer, self.flowBuffer, self.nirsBuffer;

	def getTauList(self):
		return self.tauList;

	def getFs(self):
		return self.fs;

	def getTWindow(self):
		return self.packetSize*self.packetMultiple/self.fs;

	def isFlowEnabled(self):
		return self.calcFlow;

	def isNIRSEnabled(self):
		return self.calcNIRS;

def limit_cpu():
	p = psutil.Process(os.getpid());
	p.nice(15);
