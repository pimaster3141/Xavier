from sys import platform
if platform == "linux" or platform == "linux2":
    pass
elif platform == "darwin":
    raise Exception("Unsupported OS: " + str(platform));
elif platform == "win32":
    raise Exception("Unsupported OS: " + str(platform));

print("Compiling and Loading Libraries...")
import sys
sys.path.insert(0, 'PythonLib');
import setuptools
import pyximport; pyximport.install()

import FlowExtract
import G2Extract
import os

import psutil
import gc
print("Done");

# def extractG2(filename, legacy=False, fs=2.5E6, intg=0.05, fsout=200, numProcessors=None):
# 	if(numProcessors==None):
# 		numProcessors = os.cpu_count();
		
# 	print("Extracting: " + filename);
# 	(g, t, v) = G2Extract.processG2(filename, legacy, fs, intg, fsout, numProcessors);
# 	folder = createFolder(filename, intg);
# 	G2Extract.writeG2Data(folder, g, t, v, legacy, fs, intg, fsout);
# 	print("Completed G2");

# def extractFlow(folder, averages, fs=2.5E6, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=None):
# 	if(numProcessors==None):
# 		numProcessors = os.cpu_count();
		
# 	print("Extracting: " + folder);
# 	(g, t, v) = G2Extract.loadG2(folder);
# 	(flows, betas, counts, g2a) = FlowExtract.calculateFlow(g, t, averages, fs, rho, no, wavelength, mua, musp, numProcessors);
# 	FlowExtract.writeFlowData(folder, flows, betas, counts, averages, rho, no, wavelength, mua, musp);
# 	print("Completed Flow");

# def batchExtractFlow(folders, averages,fs=2.5E6, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=None):
# 	if(numProcessors==None):
# 		numProcessors = os.cpu_count();
		
# 	for f in folders:
# 		extractFlow(f, averages, fs, rho, no, wavelength, mua, musp, numProcessors);

# def fullExtract(filename, averages, legacy=False, fs=2.5E6, intg=0.05, fsout=200, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=None):
# 	if(numProcessors==None):
# 		numProcessors = os.cpu_count();
		
# 	print("Extracting: " + filename);
# 	(g, t, v) = G2Extract.processG2(filename, legacy, fs, intg, fsout, numProcessors);
# 	folder = createFolder(filename, intg);
# 	G2Extract.writeG2Data(folder, g, t, v, legacy, fs, intg, fsout);
# 	print("Completed G2");
# 	(flows, betas, counts, g2a) = FlowExtract.calculateFlow(g, t, averages, fs, rho, no, wavelength, mua, musp, numProcessors);
# 	FlowExtract.writeFlowData(folder, flows, betas, counts, averages, rho, no, wavelength, mua, musp);
# 	print("Completed Flow");

# def batchFullExtract(files, averages, legacy=False, fs=2.5E6, intg=0.05, fsout=200, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=None):
# 	if(numProcessors==None):
# 		numProcessors = os.cpu_count();
		
# 	for f in files:
# 		fullExtract(f, averages, legacy, fs, intg, fsout, rho, no, wavelength, mua, musp, numProcessors)

# def csv2Matlab(filename, averages, legacy=False, fs=2.5E6, intg=0.05, fsout=200, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=None):
# 	if(numProcessors==None):
# 		numProcessors = os.cpu_count();
		
# 	folder = createFolder(filename, intg);
# 	(g,t,v) = G2Extract.loadG2(folder);
# 	filename = G2Extract.writeG2Matlab(filename, g, t, v, legacy, fs, intg, fsout);
# 	print("Completed G2");
# 	(flows, betas, counts, g2a) = FlowExtract.calculateFlow(g, t, averages, fs, rho, no, wavelength, mua, musp, numProcessors);
# 	FlowExtract.writeFlowMatlab(filename, flows, betas, counts, g2a, averages, rho, no, wavelength, mua, musp);
# 	print("Completed Flow");

def fullExtractMatlab(filename, averages, legacy=None, fs=2.5E6, intg=0.05, fsout=200, levels=16, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=None):
	if(numProcessors==None):
		numProcessors = psutil.cpu_count(logical=False);
		print("Autoselecting Core Count: " + str(numProcessors));

	if(fs==None):
		with open(filename+'.params') as temp:
			value = temp.readline();
			fs = int(''.join(list(filter(str.isdigit, value))));
		print("Autoelecting fs: "+str(fs));

	if(legacy==None):
		with open(filename+'.params') as temp:
			value = temp.readline();
			value = temp.readline();
			legacy = 'True' in value;
		print("Autoselecting Legacy: " + str(legacy));
		
	print("Extracting: " + filename);
	(g, t, v) = G2Extract.processG2(filename, legacy, fs, intg, fsout, levels, numProcessors);
	filename = G2Extract.writeG2Matlab(filename, g, t, v, legacy, fs, intg, fsout, saveG2=False);
	print("Completed G2");
	(flows, betas, counts, g2a) = FlowExtract.calculateFlow(g, t, averages, fs, rho, no, wavelength, mua, musp, numProcessors);
	FlowExtract.writeFlowMatlab(filename, flows, betas, counts, g2a, averages, rho, no, wavelength, mua, musp, saveG2=False);
	print("Completed Flow");

	del(g);
	del(t); 
	del(v);
	del(flows);
	del(betas);
	del(counts);
	del(g2a);
	del(filename);
	gc.collect();

def batchFullExtractMatlab(files, averages, legacy=None, fs=None, intg=0.05, fsout=200, levels=16, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=None):
	if(numProcessors==None):
		numProcessors = psutil.cpu_count(logical=False);
		
	for f in files:
		fullExtractMatlab(f, averages, legacy, fs, intg, fsout, levels, rho, no, wavelength, mua, musp, numProcessors);



def createFolder(filename, intg):
	BW = int(1.0/intg + 0.5);

	folder = filename+str(BW)+"Hz";

	if not os.path.exists(folder):
		print("Creating Directory: " + folder);
		os.makedirs(folder);

	return folder;

