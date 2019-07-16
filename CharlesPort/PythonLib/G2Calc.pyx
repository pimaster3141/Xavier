import multipletau as mt
import numpy as np
import HSDCSParser

import warnings

def mtAuto(data, fs=10E6, levels=16):
	with warnings.catch_warnings():
		warnings.simplefilter("ignore");
		try:
			out = mt.autocorrelate(data, m=levels, deltat=1.0/fs, normalize=True);
		except:
			data[0] = 1;
			out = mt.autocorrelate(data, m=levels, deltat=1.0/fs, normalize=True);
		out[:,1] = out[:,1]+1;
		return out;

def mtAutoQuad(data, fs=2.5E6, levels=16):
	g20 = mtAuto(data[0,:], fs, levels)[:,1];
	g21 = mtAuto(data[1,:], fs, levels)[:,1];
	g22 = mtAuto(data[2,:], fs, levels)[:,1];
	g23 = mtAuto(data[3,:], fs, levels)[:,1];

	return np.array((g20, g21, g22, g23));

def calculateG2(data, fs, levels, legacy):
	channel = None;
	vap = None;
	if(legacy):
		channel, vap = HSDCSParser.parseCharlesLegacy(data);
	else:
		channel, vap = HSDCSParser.parseCharles2(data);

	g2Data = mtAutoQuad(channel, fs, levels);
	# vap = np.array((np.mean(vap, axis=1)+.5), dtype=np.int8);
	vap = np.array((np.mean(vap, axis=1)>0.05), dtype=np.int8);

	return(g2Data, vap);

def calcSNR(g2Data):
	return np.abs((np.mean(g2Data, axis=0) - 1) / (np.std(g2Data, axis=0)));

def calcBeta(g2Data, limit=5):
	return np.mean(g2Data[1:limit]) -1;

def G1Calc(g2Data):
	beta = calcBeta(g2Data);
	g1Data = np.sqrt(np.abs((g2Data-1)/beta));
	return g1Data, beta;