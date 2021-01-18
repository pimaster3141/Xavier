import multiprocessing as mp
import threading
from datetime import datetime
import time
import queue

from cpython cimport array
import array

class Logger(threading.Thread):
	QUEUE_TIMEOUT = 1;

	def __str__(self):
		return "Logger";

	def __init__(self, logName, debugLevel=0, displayLevel=0):
		threading.Thread.__init__(self);

		self.debugLevel = debugLevel;
		self.displayLevel = displayLevel;

		now = datetime.now();
		startTime = str(now.strftime("%Y-%m-%d_%H%M"));
		self.logName = logName+"_"+startTime+".log";

		self.messageQueue = mp.Queue();

		self.isDead = threading.Event();

	def run(self):

		cdef int level;
		cdef str module;
		cdef str message;
		cdef int error;
		cdef array.array packet = array.array([]);

		try:
			# packet = [];

			try:
				with open(self.logName, 'w') as log:
					log.write("Log started: " + (str(datetime.now())) +"\n");
			except:
				print("Could not write log file!");

			while(not self.isDead.is_set()):
				try:
					packet = self.messageQueue.get(block=True, timeout=Logger.QUEUE_TIMEOUT);
				except queue.Empty:
					continue;

				level = packet[0];
				module = str(packet[1]);
				message = str(packet[2]);
				now = datetime.now();
				error = level<-1;

				if(level <= self.debugLevel):
					nowStr = now.strftime("%H:%M:%S-")
					try:
						with open(self.logName, 'w') as log:
							if(error):
								log.write(nowStr+"[ERROR] "+"["+module+"]: " + message +"\n");
							else:
								log.write(nowStr+"["+module+"]: " + message +"\n");
					except:
						print("Could not write log file!");

				if(level <= self.displayLevel):
					if(error):
						print("[ERROR] "+"["+module+"]: " + message);
					else:
						print("["+module+"]: " + message);

		finally:
			self.shutdown();


	def shutdown(self):
		self.isDead.set();
		while(True):
			try:
				(self.messageQueue.get(False));
			except queue.Empty:
				time.sleep(0.5)    # Give tasks a chance to put more data in
				if not self.messageQueue.empty():
					continue
				else:
					break;
		self.messageQueue.close();
		self.messageQueue.cancel_join_thread();

	def stop(self):
		self.isDead.set();


	def printError(self, obj, e):
		packet = [-2, str(obj), str(e)];
		try:
			self.messageQueue.put_nowait(packet);
		except:
			pass;
		return;

	def printMessage(self, obj, str message, level=5):
		packet = [level, str(obj), message];
		try:
			self.messageQueue.put_nowait(packet);
		except:
			pass;
		return;
