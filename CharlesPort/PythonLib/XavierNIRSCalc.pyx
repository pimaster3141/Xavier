import numpy as np
import XavierParser

def calculateNIRS(data, antialias=False, DPF=6):
	data = XavierParser.parseNIRS(data);

	data = np.mean(data, axis=1);

	# print(data);

	return data;
