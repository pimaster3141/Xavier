import numpy as np
import XavierParser

class NIRSCalc():
	WEIGHT = 0.01;
	DPF = [6,6];
	rho = [2,2];

	FULLSCALE = 2**14 -1;
	AC_GAIN = [101,101];

	def __init__(self, weight=WEIGHT, DPF=DPF, rho=rho, acg=AC_GAIN):
		assert weight>=0 and weight<=1, "Invalid Weight";
		self.weight = weight;
		self.DPF = DPF;
		self.rho = rho;
		self.acg = acg;

		self.values = np.array([1,1,1,1], dtype=np.double);

	def calculateNIRS(self, data, antialias=False):
		data = XavierParser.parseNIRS(data);
		data = np.array(data, dtype=np.double);
		# print(data);

		data = np.mean(data, axis=1, dtype=np.double);
		self.values = data*self.weight + self.values*(1-self.weight);


		dmua1 = (data[0]-self.values[0])/self.acg[0]/self.values[2] * (-1/(self.DPF[0]*self.rho[0]));
		dmua2 = (data[1]-self.values[1])/self.acg[1]/self.values[3] * (-1/(self.DPF[1]*self.rho[1]));

		# print(data);

		# return ([dmua1, dmua2]);
		return(data);
