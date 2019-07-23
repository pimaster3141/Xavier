import setuptools
import pyximport; pyximport.install()
# import G2Extract
# import HSDCSParser
import XavierG2Calc
import numpy as np
from functools import partial
import os
import csv
import multiprocessing as mp
import time
# import h5py;
import hdf5storage as matWriter
import tqdm


BYTES_PER_SAMPLE = 2;
SAMPLE_DTYPE = np.int16;

def processG2(filename, legacy=False, fs=2.5E6, intg=0.05, fsout=200, levels=16, numProcessors=None):
	if(numProcessors==None):
		numProcessors = mp.cpu_count();
		
	print("Reading: " + filename);
	start = time.time();
	fsize = os.stat(filename).st_size;
	windowSize = int(fs*intg);
	windowShift = int(fs/fsout/4)*4;
	numSamples = np.floor(((fsize/BYTES_PER_SAMPLE)-windowSize)/windowShift)+1;

	tauList = G2Calc.mtAuto(np.ones(windowSize), fs=fs, levels=levels)[:,0];

	# print(numSamples);
	# print(windowShift);
	startIndexes = np.arange(numSamples, dtype=np.uint64)*windowShift;
	# print(type(startIndexes[0]));
	pool = mp.Pool(processes=numProcessors);
	fcn = partial(seekExtract, windowSize=windowSize, fs=fs, levels=levels, legacy=legacy, filename=filename);

	# data = pool.map(fcn, startIndexes, chunksize=100);
	data = list(tqdm.tqdm(pool.imap(fcn, startIndexes, chunksize=max(int(len(startIndexes)/10000/numProcessors), 100)), total=len(startIndexes)));

	pool.close();
	pool.join();

	g2Data = np.array([item[0] for item in data]);
	g2Data = np.swapaxes(g2Data, 1, 2);
	g2Data = np.swapaxes(g2Data, 0, 1);

	# count = np.array([item[1] for item in data]);
	# count = np.swapaxes(count, 0, 1);
	vap = np.array([item[1] for item in data]);
	# vap = np.swapaxes(vap, 0, 1);
	del(pool);
	del(data);
	print("G2 Computation time: " + str(time.time()-start));
	return (g2Data, tauList, vap);

def seekExtract(startIndex, windowSize, fs, levels, legacy, filename):
	f = open(filename, 'rb');
	# print(startIndex);
	f.seek(int(startIndex*BYTES_PER_SAMPLE), os.SEEK_SET);
	data = np.fromfile(f, count=windowSize, dtype=SAMPLE_DTYPE);
	f.close();
	(g2Data, vap) = G2Calc.calculateG2(data, fs, levels, legacy);

	del(data);

	return (g2Data, vap);

# def loadG2(path, ssd=True):
# 	pool = mp.Pool(processes=1);
# 	if(ssd):
# 		pool = mp.Pool(processes=4);

# 	filenames = [path+'/G2channel0', path+'/G2channel1', path+'/G2channel2', path+'/G2channel3'];

# 	g2Data = pool.map(loadG2Channel, filenames);

# 	filenames = [path+'/VAPchannel0', path+'/VAPchannel1', path+'/VAPchannel2', path+'/VAPchannel3'];

# 	vapData = pool.map(loadVAPChannel, filenames);
# 	pool.close();
# 	pool.join();

# 	tauList = loadTauList(path+'/TAU');

# 	g2Data = np.array(g2Data);
# 	g2Data = np.swapaxes(g2Data, 0, 2);
# 	# g2Data = np.swapaxes(g2Data, 0, 1);

# 	vapData = np.array(vapData);
# 	vapData = np.swapaxes(vapData, 0, 1);

# 	return g2Data, tauList, vapData;

# def loadG2Channel(filename):
# 	g2Data = [];
# 	with open(filename, 'r') as g2File:
# 		g2Reader = csv.reader(g2File, quoting=csv.QUOTE_NONNUMERIC);
# 		for row in g2Reader:
# 			g2Data.append(row);

# 	g2Data = np.array(g2Data);
# 	return g2Data;

# def loadVAPChannel(filename):
# 	with open(filename, 'rb') as vapFile:
# 		vapData = np.fromfile(vapFile, dtype='int8');
# 		return vapData

# def loadTauList(filename):
# 	tauList = [];
# 	with open(filename, 'r') as tauFile:
# 		tauReader = csv.reader(tauFile, quoting=csv.QUOTE_NONNUMERIC);
# 		for row in tauReader:
# 			tauList.append(row);
# 	return np.array(tauList)[0];

def writeG2Matlab(filename, g2, tau, vap, legacy, fs, intg, fsout, saveG2=False):

	BW = int(1.0/intg + 0.5);
	folder = filename+str(BW)+"Hz";

	print("Creating Matlab File: " + folder);
	outData = {};

	if(saveG2):
		outData['g2Raw'] = g2;
	outData['tauList'] = tau;
	outData['vap'] = vap;
	outData['legacy'] = legacy;
	outData['fs'] = fs;
	outData['intg'] = intg;
	outData['fsout'] = fsout;

	matWriter.savemat(folder, outData);

	del(outData);

	return folder;

# def writeG2Data(folder, g2, tau, vap, legacy, fs, intg, fs_out):
# 	print("Writing G2 to Disk");
# 	vap = np.swapaxes(vap, 0, 1);
# 	g2 = np.swapaxes(g2, 0, 2);
# 	# g2 = np.swapaxes(g2, 0, 1);

# 	for c in range(len(g2)):
# 		with open(folder+"/G2channel"+str(c), 'w', newline='') as g2File:
# 			g2writer = csv.writer(g2File);
# 			for g in g2[c]:
# 				g2writer.writerow(g);

# 		with open(folder+"/VAPchannel"+str(c), 'wb') as vapFile:
# 			vapFile.write(bytes(vap[c]));

# 	with open(folder+"/TAU", 'w', newline='') as tauFile:
# 		tauwriter = csv.writer(tauFile);
# 		tauwriter.writerow(tau);

# 	writeNotes(folder, legacy, fs, intg, fs_out);

# def writeNotes(folder, legacy, fs, intg, fsout):
# 	print("Writing G2 Notes");
# 	with open(folder + "/G2_Parameters.txt", 'w') as notes:
# 		notes.write("Folder="+str(folder)+"\n");
# 		notes.write("legacy="+str(legacy)+"\n");
# 		notes.write("fs="+str(fs)+"\n");
# 		notes.write("intg="+str(intg)+"\n");
# 		notes.write("fsout="+str(fsout)+"\n");
