# distutils: extra_compile_args=-fopenmp
# distutils: extra_link_args=-fopenmp
# distutils: define_macros=NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION

from libc.stdint cimport uint8_t
from libc.stdint cimport uint16_t
import numpy as np
cimport numpy as np
cimport cython
from cython.parallel import prange


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
# d1|d2|s1|s2 || d3|d4|s3|s4 || m|adc
cpdef parse(uint8_t[::1] data):
	cdef long length = data.shape[0];
	cdef long outLength = (length >> 2);

	spadData = np.zeros((4, outLength), dtype=np.uint8);
	dDataAll = np.zeros((4, outLength), dtype=np.uint8);
	aDataAll = np.zeros((outLength), dtype=np.uint16);
	cdef uint8_t[:, ::1] spadData_view = spadData;
	cdef uint8_t[:, ::1] dDataAll_view = dDataAll;
	cdef uint16_t[::1] aDataAll_view = aDataAll;

	cdef uint8_t dValue = 0;
	cdef long i;
	cdef long j;
	for i in prange(outLength, nogil=True):
		j = i << 2;

		dDataAll_view[0,i] = (data[j] >> 7);
		dDataAll_view[1,i] = (data[j] >> 6) & 0x01;
		dDataAll_view[2,i] = (data[j+1] >> 7) & 0x01;
		dDataAll_view[3,i] = (data[j+1] >> 6) & 0x01;
		# dValue = (data[j] >> 4) & 0x0C;
		# dDataAll_view[i] = dValue | ((data[j+1] >> 6) & 0x03);

		spadData_view[0,i] = (data[j] >> 3) & 0x07;
		spadData_view[1,i] = (data[j]) & 0x07;
		spadData_view[2,i] = (data[j+1] >> 3) & 0x07;
		spadData_view[3,i] = (data[j+1]) & 0x07;

		aDataAll_view[i] = (data[j+2] << 8) | data[j+3];


	cdef long adcLength = (outLength >> 2);
	cdef uint16_t ADCOffset = aDataAll_view[0] >> 14;

	aData = np.zeros((4, adcLength), dtype=np.uint16);
	cdef uint16_t[:, ::1] aData_view = aData;

	for i in prange(adcLength, nogil=True):
		j = i << 2; 
		aData_view[ADCOffset, i] = aDataAll_view[j] & 0x3FFF;
		aData_view[(ADCOffset+1) & 0x0003, i] = aDataAll_view[j+1] & 0x3FFF;
		aData_view[(ADCOffset+2) & 0x0003, i] = aDataAll_view[j+2] & 0x3FFF;
		aData_view[(ADCOffset+3) & 0x0003, i] = aDataAll_view[j+3] & 0x3FFF;

	return (spadData_view, aData_view, dDataAll_view)
	# return data;

cpdef parseAll(uint8_t[:, ::1] data):
	cdef int depth = data.shape[0];
	cdef int outLength = data.shape[1] >> 2;
	cdef int adcLength = outLength >> 2;
	cdef int i = 0;
	spadData = np.zeros((depth, 4, outLength), dtype=np.uint8);
	dDataAll = np.zeros((depth, outLength), dtype=np.uint8);
	aData = np.zeros((depth, 4, adcLength), dtype=np.uint16);
	cdef uint8_t[:, :, ::1] spadData_view = spadData;
	cdef uint8_t[:, :, ::1] dDataAll_view = dDataAll;
	cdef uint16_t[:, :, ::1] aData_view = aData;

	for i in range(depth):
		s, a, d = parse(data[i]);
		spadData_view[i, :, :] = s;
		aData_view[i, :, :] = a;
		dDataAll_view[i, :, :] = d;

	return spadData_view, aData_view, dDataAll_view



