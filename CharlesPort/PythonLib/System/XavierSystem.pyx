from sys import platform
if platform == "linux" or platform == "linux2":
	pass
elif platform == "darwin":
	raise Exception("Unsupported OS: " + str(platform));
elif platform == "win32":
	raise Exception("Unsupported OS: " + str(platform));

print("Compiling and Loading Libraries...")

import setuptools
import pyximport; pyximport.install()
import XavierFX3
import XavierDataHandler
import XavierDataProcessor

import usb
import XavierDisplay
import multiprocessing as mp
import time
import psutil
import os
print("Done")

class XavierSystem():
	VENDOR_ID = 0x04B4;
	PRODUCT_IDs = [0x00F2];
	BENCHMARK_SIZE = 524288; # should be 10s at 2.5MHz
	BENCHMARK_ITERS = 100*4
	BYTES_PER_SAMPLE = 4;

	
	def __init__(self, outFile=None, directory='./output/', version=None, fs=None, averages=[[0, 3]], numProcessors=None, demo=False):
		
		self.isStarted = False;
		self.outFile = outFile;
		self.directory = directory;
		if (directory == None):
			directory = './output/';
		if(not(directory[-1] == '/')):
			self.directory = directory + '/'
		self.demo = demo;

		self.numProcessors = numProcessors;
		if(numProcessors==None):
			self.numProcessors = psutil.cpu_count(logical=False);
			print("Autoselecting core count = " + str(self.numProcessors));

		self.MPIFX3 = mp.Queue();
		self.MPIHandler = mp.Queue();
		self.MPIProcessor = mp.Queue();

		self.FX3 = None;
		self.dev = None;
		self.legacy = False;
		self.fs = 2E6;
		if(self.demo):
			self.FX3 = XavierFX3.Emulator(self.MPIFX3, 'flat_initial');
		else:
			devices, kind = findDevices(version);
			self.dev = devices[0];
			self.legacy = kind[0];
			if(self.legacy):
				self.directory = self.directory+"Xavier1/";
			else:
				self.directory = self.directory+"Xavier2/";
			os.makedirs(self.directory, exist_ok=True);
			self.dev.reset();
			self.dev.set_configuration();
			self.FX3 = XavierFX3.DCS(self.MPIFX3, self.dev)

			self.fs = fs;
			if(self.fs == None):
				self.fs = self.bench();
				print("Device is " + str(self.fs/1E6) + "Msps");

			if(not outFile==None):
				with open(self.directory+str(outFile)+".params", 'w') as f:
					f.write("fs="+str(self.fs)+"\n");
					f.write("legacy="+str(self.legacy)+"\n");
					f.write("averages="+str(averages)+"\n");

		fxPipe = self.FX3.getPipe();
		fxBufferSize = self.FX3.getBufferSize();
		self.handler = XavierDataHandler.DataHandler(self.MPIHandler, fxPipe, fxBufferSize, sampleSize=XavierSystem.BYTES_PER_SAMPLE, filename=self.outFile, directory=self.directory);

		handlerBufferDCS = self.handler.getRealtimeDCSQueue();
		handlerBufferNIRS = self.handler.getRealtimeNIRSQueue();
		self.handler.enableRealtimeDCS();
		self.handler.enableRealtimeNIRS();
		self.processor = XavierDataProcessor.DataProcessor(self.MPIProcessor, handlerBufferDCS, averages, legacy=self.legacy, fs=self.fs, bufferSize=fxBufferSize, sampleSize=XavierSystem.BYTES_PER_SAMPLE, calcFlow=True, calcNIRS=True, inputBufferNIRS=handlerBufferNIRS, numProcessors=numProcessors);


		print("Device Initialized!");		

	def stop(self):
		# if(not self.isStarted):
		# 	print("Device already halted");
		# 	return;

		print("Halting Device");

		self.readAllMPI();
		self.FX3.stop();
		self.handler.stop();
		self.processor.stop();
		try:
			self.Xavierdisplay.stop();
		except:
			print("Error stopping XavierDisplay");
			
		self.FX3.join();
		self.handler.join();
		self.processor.join();

		# time.sleep(1);

		self.readAllMPI();

		if(not self.demo):
			self.dev.reset();
			usb.util.dispose_resources(self.dev);
		print("Device Halted");

	def start(self):
		if(self.isStarted):
			print("Device already running");
			return;		

		self.isStarted = True;
		print("Starting Xavier!");
		self.processor.start();
		self.handler.start();
		self.FX3.start();
		self.Xavierdisplay = XavierDisplay.GraphWindow(self.processor, legacy=self.legacy, stopFcn=self.stop);
		self.Xavierdisplay.run();
		print("Device Running");

	def bench(self):
		if(self.isStarted):
			raise Exception("Cannot benchmark after start");
		else:
			print("Benchmarking Device ~10s");
			s = 0.0;
			e = 0.0;
			self.dev.read(0x81, 524288, 500);
			s = time.time();
			for i in range(XavierSystem.BENCHMARK_ITERS):
				self.dev.read(0x81, XavierSystem.BENCHMARK_SIZE, 5000);
			e = time.time();
			# except Exception as e:
			# 	raise Exception("UNKNOWN HARDWARE ERROR");

			return int((XavierSystem.BENCHMARK_SIZE*XavierSystem.BENCHMARK_ITERS/XavierSystem.BYTES_PER_SAMPLE)/(e-s));

	def readAllMPI(self):
		s = self.MPIFX3.qsize();
		print("FX3 Messges...");
		for i in range(s):
			try:
				print(self.MPIFX3.get(False));
			except Exception as e:
				print("WARNING: ")
				print(e);
				continue;

		# print("");
		s = self.MPIHandler.qsize();
		print("Handler Messages...");
		for i in range(s):
			try:
				print(self.MPIHandler.get(False));
			except Exception as e:
				print("WARNING: ")
				print(e);
				continue;

		# print("");
		s = self.MPIProcessor.qsize();
		print("Processor Messages...");
		for i in range(s):
			try:
				print(self.MPIProcessor.get(False));
			except Exception as e:
				print("WARNING: ")
				print(e);
				continue;


def findDevices(version):
	devicesGen = None;
	if(version == None):
		devicesGen = usb.core.find(idVendor=XavierSystem.VENDOR_ID, find_all=True);
	elif(version == 1):
		devicesGen = usb.core.find(idVendor=XavierSystem.VENDOR_ID, idProduct=XavierSystem.PRODUCT_IDs[0], find_all=True);
	# elif(version == 2):
	# 	devicesGen = usb.core.find(idVendor=XavierSystem.VENDOR_ID, idProduct=XavierSystem.PRODUCT_IDs[1], find_all=True);
	else:
		raise Exception("UNSUPPORTED VERSON" + str(version));

	devices = [];
	legacy = []
	for dev in devicesGen:
		devices.append(dev);
		legacy.append(dev.idProduct == XavierSystem.PRODUCT_IDs[0]);

	if(len(devices) == 0):
		raise Exception("CANNOT FIND DEVICE");

	return devices, legacy;
