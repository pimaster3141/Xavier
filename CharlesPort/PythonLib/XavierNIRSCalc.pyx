import numpy as np
import XavierParser

def calculateNIRS(data, antialias=False, DPF=6, rho=2.5):
	data = XavierParser.parseNIRS(data);
	data = np.array(data, dtype=np.double);
	# print(data);

	data = np.mean(data, axis=1, dtype=np.double);

	dmua1 = (data[0]-8192)/101/data[2] * (-1/(DPF*rho));
	dmua2 = (data[1]-8192)/101/data[3] * (-1/(DPF*rho));

	# print(data);

	return ([dmua1]);
