
import multiprocessing as mp

cdef list locks = [mp.Event()]*5;

print(locks[3].is_set());
locks[3].set();
print(locks[3].is_set());