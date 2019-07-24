import setuptools
import pyximport; pyximport.install()
import XavierNIRSCalc
import numpy as np
import time
import hdf5storage as matWriter
import os

def processNIRS(filename, clk=2.5E6, fsout=200, maxBytes=4096*1024*1024):
	print("Reading: " + filename);

	#reference to channel sample rates (1/4)
	fs = clk/4;
	NIRSCalculator = XavierNIRSCalc.NIRSCalc(weight=1/(fsout*10.0));
	windowSize = int(fs/fsout); #single channel samples per point
	maxNumSamples = int(maxBytes/2/4/windowSize)*windowSize;
	# maxBytes = int(maxBytes/(windowSize*4*2))*windowSize*4*2;
	# print(maxBytes);
	fsize = os.stat(filename).st_size;
	numOutPoints = int((fsize/2/4)/windowSize);

	data=np.zeros((numOutPoints, 2), dtype=np.float);

	f = open(filename, 'rb');
	chunk = np.fromfile(f, count=int(maxNumSamples*4), dtype=np.uint16);

	chunkCounter = 0;
	lastData = 0;
	while(int(len(chunk)/4) > 0):
		numWindows = int(len(chunk)/4/windowSize);
		for i in range(numWindows):
			data[lastData+i] = NIRSCalculator.calculateNIRS(chunk[i*windowSize*4:i*windowSize*4+windowSize*4]);
		chunkCounter = chunkCounter+1;
		lastData = lastData+i+1;
		chunk = np.fromfile(f, count=int(maxBytes/2), dtype=np.uint16);

	return data;


def writeNIRSMatlab(filename, data):
	print("Creating Matlab File: " + filename);
	outdata = {};

	outdata['NIRS'] = data;

	matWriter.savemat(filename, outdata);


