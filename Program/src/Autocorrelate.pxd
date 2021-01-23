cdef double[::1] multipleTau(double[::1] data, char levels, bint normalize);
cdef int getReturnLength(int dataLength, char levels) nogil;
cdef double[::1] getDelayTimes(int dataLength, char levels, double deltaT);
