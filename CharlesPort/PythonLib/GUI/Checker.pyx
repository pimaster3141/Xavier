import time;
import numpy as np

class PulseChecker():
	CHECK_INTERVAL = 2;

	def __init__(self, pusher, sampleRate, highBPM=200, lowBPM=70, quietTimeout=30):
		self.pusher = pusher;
		self.sampleRate = sampleRate;
		self.highBPM = highBPM;
		self.lowBPM = lowBPM;
		self.quietTimeout = quietTimeout;

		self.lastTrigger = time.time();
		self.lastCheck = time.time();

		print(sampleRate);

	def check(self, pulseBuffer):
		current = time.time();
		if((current - self.lastCheck)>PulseChecker.CHECK_INTERVAL and (current - self.lastTrigger)>self.quietTimeout):
			self.lastCheck = current;

			data = self.findEdges(pulseBuffer);
			hr = self.sampleRate/np.mean(np.diff(data))*60;	
			# print(hr);		
			if(hr > self.highBPM or hr < self.lowBPM):
				self.pusher.send("EKG FAULT - HR: " + str(int(hr)) + "BPM");
				print("EKG FAULT - HR: " + str(int(hr)) + "BPM");
				self.lastTrigger = current;

	def findEdges(self, data, rising=True):
		data = data*1;
		shift = np.roll(data, 1);
		data = data-shift;

		output = None;
		if(rising):
			output = np.where(data==1)[0];
		else:
			output = np.where(data==-1)[0];
		return output;


class BetaChecker():
	FM_THRESHOLD = 0.14;
	SM_THRESHOLD = 0.3;
	THRESHOLD_CUTOFF = 0.5;

	def __init__(self, pusher, fewMode=True, quietTimeout=30):
		self.pusher = pusher;
		self.threshold = None;
		if(fewMode):
			self.threshold = BetaChecker.FM_THRESHOLD;
		else:
			self.threshold = BetaChecker.SM_THRESHOLD;

		self.quietTimeout = quietTimeout;
		self.lastTrigger = time.time();
		self.faultStart = 0;
		self.inFault = False;

	def check(self, data):
		current = time.time();
		if((current - self.lastTrigger)>self.quietTimeout):
			if(np.mean(data) < self.threshold):
				if(not self.inFault):
					self.inFault = True;
					self.faultStart = current;
				else:
					if((current - self.faultStart) > BetaChecker.THRESHOLD_CUTOFF):
						self.pusher.send("LASER INSTABILITY - Beta: " + str(np.mean(data)));
						print("LASER INSTABILITY - Beta: " + str(np.mean(data)));
						self.lastTrigger = current;
						self.inFault = False;
			else:
				self.inFault = False;

