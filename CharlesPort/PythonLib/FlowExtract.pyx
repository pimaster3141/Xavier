import setuptools
import pyximport; pyximport.install()
import FlowFit
import numpy as np
import time
import csv
import hdf5storage as matWriter
import os


def calculateFlow(g2Data, tauList, averages, fs=2.5E6, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=None):
	if(numProcessors==None):
		numProcessors = os.cpu_count();

	start = time.time();
	flows = [];
	betas = [];
	counts = [];
	g2Avgs = [];
	for i in range(len(averages)):
		print("Fitting Channel Average: " + str(averages[i]));
		average = averages[i];
		g2Avg = np.mean(g2Data[:, :, average[0]:average[1]+1], axis=2);
		flow, beta = FlowFit.flowFitDual(np.swapaxes(g2Avg, 0, 1), tauList, rho, no, wavelength, mua, musp, numProcessors, chunksize=200, ECC=False);
		count = fs/g2Avg[0, :];

		flows.append(flow);
		betas.append(beta);
		counts.append(count);
		g2Avgs.append(g2Avg);

	flows = np.array(flows);
	betas = np.array(betas);
	counts = np.array(counts);
	g2Avgs = np.array(g2Avgs);

	flows = np.swapaxes(flows, 0, 1);
	betas = np.swapaxes(betas, 0, 1);
	counts = np.swapaxes(counts, 0, 1);
	g2Avgs = np.swapaxes(g2Avgs, 0, 2);
	g2Avgs = np.swapaxes(g2Avgs, 0, 1);

	print("Fit Computation time: " + str(time.time()-start));
	return flows, betas, counts, g2Avgs;

# def loadFlow(path):
# 	flow = loadFlowChannel(path+'/flow');
# 	beta = loadBetaChannel(path+'/beta');
# 	count = loadCountChannel(path+'/count');

# 	return (flow, beta, count)

# def loadFlowChannel(filename):
# 	flowData = [];
# 	with open(filename, 'r') as flowFile:
# 		flowReader = csv.reader(flowFile, quoting=csv.QUOTE_NONNUMERIC);
# 		for row in flowReader:
# 			flowData.append(row);

# 	flowData = np.array(flowData);
# 	flowData = np.swapaxes(flowData, 0, 1);
# 	return flowData;

# def loadBetaChannel(filename):
# 	betaData = [];
# 	with open(filename, 'r') as betaFile:
# 		betaReader = csv.reader(betaFile, quoting=csv.QUOTE_NONNUMERIC);
# 		for row in betaReader:
# 			betaData.append(row);

# 	betaData = np.array(betaData);
# 	betaData = np.swapaxes(betaData, 0, 1);
# 	return betaData;

# def loadCountChannel(filename):
# 	countData = [];
# 	with open(filename, 'r') as countFile:
# 		countReader = csv.reader(countFile, quoting=csv.QUOTE_NONNUMERIC);
# 		for row in countReader:
# 			countData.append(row);

# 	countData = np.array(countData);
# 	countData = np.swapaxes(countData, 0, 1);
# 	return countData;

def writeFlowMatlab(filename, flow, beta, count, g2Avg, averages, rho, no, wavelength, mua, musp, saveG2=False):
	print("Creating Matlab File: " + filename);
	outData = {};

	averages = np.array(averages);

	outData['dbfit'] = flow;
	outData['beta'] = beta;
	outData['count'] = count;
	if(saveG2):
		outData['g2'] = g2Avg;
	outData['average'] = averages;
	outData['rho'] = rho;
	outData['no'] = no;
	outData['wavelength'] = wavelength;
	outData['mua'] = mua;
	outData['musp'] = musp;

	matWriter.savemat(filename, outData);

	del(outData);

# def writeFlowData(folder, flows, betas, counts, averages, rho, no, wavelength, mua, musp):
# 	print("Writing Files");

# 	flows = np.swapaxes(flows, 0, 1);
# 	betas = np.swapaxes(betas, 0, 1);
# 	counts = np.swapaxes(counts, 0, 1);

# 	with open(folder + "/flow", 'w', newline='') as flowFile:
# 		flowWriter = csv.writer(flowFile);
# 		for f in flows:
# 			flowWriter.writerow(f);

# 	with open(folder + "/beta", 'w', newline='') as betaFile:
# 		betaWriter = csv.writer(betaFile);
# 		for b in betas:
# 			betaWriter.writerow(b);

# 	with open(folder + "/count", 'w', newline='') as countFile:
# 		countWriter = csv.writer(countFile);
# 		for c in counts:
# 			countWriter.writerow(c);

# 	writeNotes(folder, averages, rho, no, wavelength, mua, musp);
# 	return;

# def writeNotes(folder, averages, rho, no, wavelength, mua, musp):
# 	print("Writing Flow Notes");
# 	with open(folder + "/Flow_Parameters.txt", 'w', newline='') as countFile:
# 		countFile.write("averages=" + str(averages) + "\n");
# 		countFile.write("rho=" + str(rho) + "\n");
# 		countFile.write("no=" + str(no) + "\n");
# 		countFile.write("wavelength=" + str(wavelength) + "\n");
# 		countFile.write("mua=" + str(mua) + "\n");
# 		countFile.write("musp=" + str(musp) + "\n");