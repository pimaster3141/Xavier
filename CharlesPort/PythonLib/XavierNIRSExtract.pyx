import setuptools
import pyximport; pyximport.install()
import XavierNIRSCalc
import numpy as np
import time
import hdf5storage as matWriter
import os

def processNIRS(filename, fs=2.5E6, fsout=200, maxBytes=4096*1024*1024):
	print("Reading: " + filename);

	NIRSCalculator = XavierNIRSCalc.NIRSCalc(weight=4/(self.fs*10.0));
	windowSize = int(fs/fsout/4)*4;
	maxBytes = int(maxBytes/windowSize/2)*windowSize*2;
	fsize = os.stat(filename).st_size;
	numChunks = int(fsize/windowSize/2);

	data=np.zeros((numChunks, 2), dtype=np.float);

	f = open(filename, 'rb');
	chunk = np.fromfile(f, count=maxBytes/2, dtype=np.uint16);

	chunkCounter = 0;
	while(len(chunk) > 0):
		numWindows = int(len(chunk)/windowSize/4)*4;
		for i in range(numWindows):
			data[chunkCounter+i] = NIRSCalculator.calculateNIRS(chunk[i:i+windowSize]);


	return data;


def writeNIRSMatlab(filename, data):
	print("Creating Matlab File: " + filename);
	outdata = {};

	outdata['NIRS'] = data;

	matWriter.savemat(filename, outdata);


