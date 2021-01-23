import setuptools
import pyximport; pyximport.install()
import XavierG2Calc
import numpy as np
from scipy import optimize 
import multiprocessing as mp
from functools import partial
import tqdm

aDb_BOUNDS = [1E-11 ,1E-6];
BETA_BOUNDS = [0.01, 0.7];

def G1Analytical(aDb, tauList, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10):
	k0=2*np.pi*no/(wavelength);
	n=no/1;
	Reff=-1.44/(n*n)+0.710/n+0.668+0.00636*n;
	zb=(2*(1+Reff))/(3*musp*(1-Reff));
	r1=np.sqrt(1/(musp*musp)+rho*rho);
	rb=np.sqrt((2*zb+1)**2/(musp*musp)+rho*rho);
	G1_0=np.exp(-np.sqrt(3*mua*musp)*r1)/r1-np.exp(-np.sqrt(3*mua*musp)*rb)/rb;
	
	k=np.sqrt(3*mua*musp+6*musp*musp*k0*k0*aDb*tauList);
	G1=np.exp(-k*r1)/r1-np.exp(-k*rb)/rb;
	g1=G1/G1_0;
	return g1;

def G2Analytical(aDb, beta, tauList, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10):
	aDb = aDb * 1E-9;
	g1 = G1Analytical(aDb, tauList, rho, no, wavelength, mua, musp);
	return np.square(g1) * beta + 1;

# def G2Analytical_2Layer(aDb1, aDb2, beta, tauList, d=0.2, rho=2, no1=1.33, no2=1.33, wavelength=8.48E-5, mua1=0.1, mua2=0.1, musp1=10, musp2=10):
# 	g1 = G1Analytical_2Layer(aDb1, aDb2, beta, tauList, d, rho, no1, no2, wavelength, mua1, mua2, musp1, musp2);
# 	return np.squre(g1) * beta + 1;

def G1Fit(g1Data, tauList, SNR, p0=1E-8, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10):
	def f(tau, aDb):
		return G1Analytical(aDb, tau, rho, no, wavelength, mua, musp)*SNR;

	(params, params_covariance) = optimize.curve_fit(f, tauList, g1Data*SNR, p0, bounds=aDb_BOUNDS);
	return params;

def G2Fit(g2Data, tauList, SNR, p0=[1E-9/1E-9, 0.25], rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, ECC=False):
	def f(tau, aDb, beta):
		return G2Analytical(aDb, beta, tau, rho, no, wavelength, mua, musp)*SNR;

	try:
		(params, params_covariance) = optimize.curve_fit(f, tauList, g2Data*SNR, p0, bounds=((aDb_BOUNDS[0]/1E-9, BETA_BOUNDS[0]), (aDb_BOUNDS[1]/1E-9, BETA_BOUNDS[1])));
		return params;
	except:
		# print("fit Error:");
		if(ECC):
			g1Data, beta = XavierG2Calc.G1Calc(g2Data);
			flow = G1Fit(g1Data, tauList, SNR, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10);
			return flow, beta;
		# print(g2Data)
		# print(tauList)
		# print(SNR);
		return(0, 0);

def flowFitSingle(g2Data, tauList, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=6):
	g2Data = g2Data[:, 1:];
	tauList = tauList[1:];

	SNR = XavierG2Calc.calcSNR(g2Data);
	meanG2 = np.mean(g2Data, axis=0);
	meanG1 = XavierG2Calc.G1Calc(g2Data);
	p0 = G1Fit(meanG1, tauList, SNR=SNR, rho=rho, no=no, wavelength=wavelength, mua=mua, musp=musp);

	pool = mp.Pool(processes=numProcessors);
	fcn = partial(G1Fit, tauList=tauList, SNR=SNR, p0=p0, rho=rho, no=no, wavelength=wavelength, mua=mua, musp=musp);

	g1Data = np.array(pool.map(XavierG2Calc.G1Calc, g2Data));
	beta = g1Data[:, 1];
	g1Data = g1Data[:, 0];

	# data = pool.map(fcn, g1Data);
	data = np.array(list(tqdm.tqdm(pool.imap(fcn, g1Data, chunksize=max(int(len(g1Data)/200/numProcessors), 100)), total=len(g1Data))));

	pool.close();
	pool.join();

	return data, beta;

def flowFitDual(g2Data, tauList, rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10, numProcessors=6, chunksize=1, ECC=False):
	g2Data = g2Data[:, 1:];
	tauList = tauList[1:];

	SNR = XavierG2Calc.calcSNR(g2Data);
	meanG2 = np.mean(g2Data, axis=0);
	p0 = G2Fit(meanG2, tauList, SNR=SNR, rho=rho, no=no, wavelength=wavelength, mua=mua, musp=musp, ECC=ECC);


	pool = mp.Pool(processes=numProcessors);
	fcn = partial(G2Fit, tauList=tauList, SNR=SNR, p0=p0, rho=rho, no=no, wavelength=wavelength, mua=mua, musp=musp, ECC=ECC);

	# data = np.array(pool.map(fcn, g2Data, chunksize=chunksize));
	data = np.array(list(tqdm.tqdm(pool.imap(fcn, g2Data, chunksize=max(int(len(g2Data)/200/numProcessors), 100)), total=len(g2Data))));

	pool.close();
	pool.join();

	del(pool);
	

	return data[:, 0]*1E-9, data[:, 1];



