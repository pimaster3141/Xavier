# distutils: extra_compile_args=-fopenmp
# distutils: extra_link_args=-fopenmp
# distutils: define_macros=NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION

from libc.stdint cimport *
from libc.math cimport *
import numpy as np
cimport numpy as np
cimport cython
from cython.parallel import prange
from scipy import optimize

cdef double ADB_SCALE = 1E-9;

cdef double ADB_LB = 1E-11 / ADB_SCALE;
cdef double ADB_UB = 1E-6 / ADB_SCALE;
cdef double ADB_0 = 1E-9 / ADB_SCALE;

cdef double BETA_LB= 0.01;
cdef double BETA_UB= 0.06;
cdef double BETA_0 = 0.25;

@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
cdef double[::1] G2Analytical(double[::1] delayTimes, double aDb, double beta, double rho, double no, double wavelength, double mua, double musp):
	aDb = aDb * ADB_SCALE;

	cdef int outLengh = delayTimes.shape[0];
	cdef np.ndarray output = np.zeros((outLengh), dtype=np.double);
	cdef double[::1] output_view = output;

	cdef double k0=2*M_PI*no/(wavelength);
	cdef double n=no/1;
	cdef double Reff=-1.44/(n*n)+0.710/n+0.668+0.00636*n;
	cdef double zb=(2*(1+Reff))/(3*musp*(1-Reff));
	cdef double r1=sqrt(1/(musp*musp)+rho*rho);
	cdef double rb=sqrt((2*zb+1)**2/(musp*musp)+rho*rho);
	cdef double G1_0=exp(-sqrt(3*mua*musp)*r1)/r1-exp(-sqrt(3*mua*musp)*rb)/rb;
	
	cdef double k = 0;
	cdef double G1 = 0;
	cdef double g1 = 0;
	cdef int i = 0;

	for i in prange(outLengh, nogil=True):
		k=sqrt(3*mua*musp+6*musp*musp*k0*k0*aDb*delayTimes[i]);
		G1=exp(-k*r1)/r1-exp(-k*rb)/rb;
		g1 = G1/G1_0;
		output_view[i] = (g1*g1)*beta+1;

	return output_view;

@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double[::1] G2AnalyticalWeighted(double[::1] delayTimes, double aDb, double beta, double[::1] SNR, double rho, double no, double wavelength, double mua, double musp):
	cdef double[::1] G2 = G2Analytical(delayTimes, aDb, beta, rho, no, wavelength, mua, musp);
	cdef int i = 0;
	cdef int outLengh = delayTimes.shape[0];
	for i in prange(outLengh, nogil=True):
		G2[i] *= SNR[i];
	return G2;

# cpdef (double, double) G2Fit(double[::1] g2Data, double[::1] delayTimes, double[::1] SNR, (double, double) p0, double rho, double no, double wavelength, double mua, double musp):
# 	cdef int outLengh = delayTimes.shape[0];
# 	cdef np.ndarray weighted = np.zeros((outLengh), dtype=np.double);
# 	cdef double[::1] weighted_view = weighted;
# 	cdef int i = 0;
# 	for i in prange(outLengh, nogil=True):
# 		weighted_view[i] = g2Data[i]*SNR[i];

# 	p0[0] = p0[0]/ADB_SCALE;
# 	if(p0[0] < ADB_LB or p0[0] > ADB_UB):
# 		p0[0] = ADB_0;
# 	if(p0[1] < BETA_LB or p0[1] > BETA_UB):
# 		p0[1] = BETA_0;

# 	cdef (double, double) params;
# 	cdef (double, double) cov;

# 	def f(delayTimes, aDb, beta):
# 		return G2AnalyticalWeighted(delayTimes, aDb, beta, SNR, rho, no, wavelength, mua, musp);

# 	# params, cov = optimize.curve_fit(lambda delayTimesf, aDbf, betaf: G2AnalyticalWeighted(delayTimesf, aDbf, betaf, SNR, rho, no, wavelength, mua, musp), delayTimes, weighted_view, p0, bounds=((ADB_LB, BETA_LB), (ADB_UB, BETA_UB)));
# 	params, cov = optimize.curve_fit(f, delayTimes, weighted_view, p0, bounds=((ADB_LB, BETA_LB), (ADB_UB, BETA_UB)));

# 	params[0] = params[0]*ADB_SCALE;
# 	return params;

def G2Fit(g2Data, delayTimes, SNR, p0=(ADB_0, BETA_0), rho=2, no=1.33, wavelength=8.48E-5, mua=0.1, musp=10):
	g2Data = np.asarray(g2Data);
	weighted = g2Data * SNR;

	p0[0] = p0[0]/ADB_SCALE;
	if(p0[0] < ADB_LB or p0[0] > ADB_UB):
		p0[0] = ADB_0;
	if(p0[1] < BETA_LB or p0[1] > BETA_UB):
		p0[1] = BETA_0;

	# def f(delayTimes, aDb, beta):
	# 	return G2AnalyticalWeighted(delayTimes, aDb, beta, SNR, rho, no, wavelength, mua, musp);
	# params, cov = optimize.curve_fit(f, delayTimes, weighted, p0, bounds=((ADB_LB, BETA_LB), (ADB_UB, BETA_UB)));
	params, cov = optimize.curve_fit(lambda delayTimes, aDb, beta: G2AnalyticalWeighted(delayTimes, aDb, beta, SNR, rho, no, wavelength, mua, musp), delayTimes, weighted, p0, bounds=((ADB_LB, BETA_LB), (ADB_UB, BETA_UB)));

	params[0] = params[0]*ADB_SCALE;
	return params;
	