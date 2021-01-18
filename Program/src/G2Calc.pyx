import numpy as np
cimport numpy as np
cimport cython
import Autocorrelate


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double[:, ::1] quadCorrelate(double[:, ::1] data, int levels):
	cdef int length = Autocorrelate.getReturnLength(data.shape[1], levels);
	output = np.zeros((4, length), dtype=np.double);
	cdef double[:,::1] output_view = output;
	cdef int i = 0;

	for i in range(4):
		output[i,:] = Autocorrelate.multipleTau(data[i,:], levels, True);
	return output_view;

cpdef int getDelayTimes(int dataLength, char levels, double deltaT):
	return Autocorrelate.getDelayTimes(dataLength, levels, deltaT);

cpdef calcSNR(double[:,::1] data):
	g2Data = np.asarray(data);
	return np.abs((np.mean(g2Data, axis=0) - 1) / (np.std(g2Data, axis=0)));
	