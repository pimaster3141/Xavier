# distutils: extra_compile_args=-fopenmp
# distutils: extra_link_args=-fopenmp
#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION

from libc.stdint cimport *
from libc.math cimport *
import numpy as np
cimport numpy as np
cimport cython
from cython.parallel import prange

#WARNING: THERE IS NO CHECK IF len(a) == len(b)
@cython.boundscheck(False)
@cython.wraparound(False)
cdef double arraySumProd(double[::1] a, double[::1] b) nogil:
	if(a.shape[0] != b.shape[0]):
		return -20;
	cdef int i = 0;
	cdef double output = 0;
	# for i in prange(a.shape[0], nogil=True):
	for i in prange(a.shape[0]):
		output += (a[i]*b[i]);
	return output;

@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double[::1] multipleTau(double[::1] data, char levels, bint normalize):
	if(((levels>>1)<<1) != levels):
		levels = levels + 1;

	cdef double err[1];
	cdef double [::1] err_view = err;

	cdef int dataLength = data.shape[0];
	cdef int k = int(log2(dataLength/levels));
	cdef int outLength = levels + k * (levels>>1) + 1;

	output = np.zeros((outLength), dtype=np.double);
	normstat = np.zeros((outLength), dtype=np.double);
	normnump = np.zeros((outLength), dtype=np.double);
	cdef double[::1] output_view = output; 
	cdef double[::1] normstat_view = normstat;
	cdef double[::1] normnump_view = normnump;

	trace = np.zeros((dataLength), dtype=np.double);
	cdef double[::1] trace_view = trace;
	cdef double traceAvg = 0;
	cdef int i = 0;
	for i in prange(dataLength, nogil=True):
		trace_view[i] = data[i];
		# traceAvg = traceAvg + data[i]; ##this doesnt wrk for some fucked reason
		traceAvg += data[i]; #but this does
	traceAvg = traceAvg / dataLength;

	cdef int N = dataLength;
	if(N < levels<<1):
		err_view[0] = -1;
		return err_view;


	if(normalize):
		i = 0;
		for i in prange(dataLength, nogil=True):
			trace_view[i] = trace_view[i] - traceAvg;
			#there is possibly supposed to be a check for "zero cutoff" here



	i = 0;
	for i in prange(0, levels+1, nogil=True):
		# output_view[i] = arraySum(arrayProd(trace_view[:N-i], trace_view[i:]));
		output_view[i] = arraySumProd(trace_view[:N-i], trace_view[i:]);
		normstat_view[i] = N - i;
		normnump_view[i] = N;

	N = N>>1;
	i=0;
	temp = np.zeros(dataLength, dtype=np.double);
	cdef double[::1] temp_view = temp;
	for i in prange(N, nogil=True):
		temp_view[i] = (trace_view[i*2] + trace_view[i*2+1])/2;
	for i in prange(N, nogil=True):
		trace_view[i] = temp_view[i];

	# cdef int counter = 0; ## TEST LINE ##
	cdef int npmd2 = 0;
	cdef int idx = 0;
	cdef int step = 0;
	for step in range(1, k+1):
		i=0;
		for i in prange(1, (levels>>1)+1, nogil=True):
			npmd2 = i+(levels>>1);
			idx = levels + i + (step-1) * (levels >> 1);
			# if(N<=npmd2): #Idk what this line is for...

			output_view[idx] = arraySumProd(trace_view[:N - npmd2], trace_view[npmd2:N]);
			normstat_view[idx] = N - npmd2;
			normnump_view[idx] = N;
			# output_view[idx] = counter; ## Test line ##
			# counter+=1;

		i = 0;
		N = N>>1;
		for i in prange(N, nogil=True):
			temp_view[i] = (trace_view[i*2] + trace_view[i*2+1])/2;
		for i in prange(N, nogil=True):
			trace_view[i] = temp_view[i];

	if normalize:
		i = 0;
		traceAvg = traceAvg*traceAvg;
		for i in prange(outLength, nogil=True):
			output_view[i] /= (traceAvg)*normstat_view[i]
	else:
		i=0;
		for i in prange(outLength, nogil=True):
			output_view[i] *= dataLength / normnump_view[i];

	return output_view;




@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double[::1] getDelayTimes(int dataLength, char levels, double deltaT):
	cdef int k = int(log2(dataLength/levels));
	cdef int outLength = levels + k * (levels>>1) + 1;
	cdef int N = dataLength;

	output = np.zeros((outLength), dtype=np.double);
	cdef double[::1] output_view = output;

	cdef int i = 0;

	for i in prange(0, levels+1, nogil=True):
		output_view[i] = deltaT * i;

	N = N>>1;
	cdef int npmd2 = 0;
	cdef int idx = 0;
	cdef int step = 0;
	for step in prange(1, k+1, nogil=True):
		i=0;
		for i in prange(1, (levels>>1)+1):
			npmd2 = i+(levels>>1);
			idx = levels + i + (step-1) * (levels >> 1);

			output_view[idx] = deltaT*npmd2*2**step;
		N /= 2;

	return output_view;

cpdef int getReturnLength(int dataLength, char levels) nogil:
	cdef int k = int(log2(dataLength/levels));
	cdef int outLength = levels + k * (levels>>1) + 1;
	return outLength;