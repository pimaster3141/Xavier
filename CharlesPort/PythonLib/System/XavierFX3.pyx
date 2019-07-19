import multiprocessing as mp
import usb.core
import usb.util
# import array
import time
import psutil
import os

class DCS(mp.Process):
	_TIMEOUT = 5000;
	_READ_SIZE = 262144/4;	#512KB = 524288 base2

	_ENDPOINT_ID = 0x81;

	def __init__(self, MPI, device, bufferSize=_READ_SIZE):
		mp.Process.__init__(self);

		self.MPI = MPI;
		self.device = device;
		self.bufferSize = bufferSize;
		(self.pipeOut, self.pipeIn) = mp.Pipe(duplex=False);
		self._packet = usb.util.create_buffer(self.bufferSize);

		try:
			self.device.read(DCS._ENDPOINT_ID, 524288, DCS._TIMEOUT);
		except Exception as e:
			raise Exception("UNKNOWN HARDWARE ERROR");

		self.isDead = mp.Event();


	def run(self):
		p = psutil.Process(os.getpid());
		p.nice(-15);
		try:
			self.device.read(DCS._ENDPOINT_ID, 524288, DCS._TIMEOUT);
		except Exception as e:
			try:
				self.MPI.put_nowait(e);
			except Exception as ei:
				pass
			finally:
				self.shutdown();
			
		try:
			while(not self.isDead.is_set()):
				# self.pipeOut.send_bytes(self._dev.read(DCS._ENDPOINT_ID, self.bufferSize, DCS._TIMEOUT));
				numRead = self.device.read(DCS._ENDPOINT_ID ,self._packet, DCS._TIMEOUT);
				if((numRead) != self.bufferSize):
					raise Exception("Device not ready");

				self.pipeIn.send_bytes(self._packet);

		except Exception as e:
			try:
				self.MPI.put_nowait(e);
			except Exception as ei:
				pass
		finally:
			self.shutdown();

	def shutdown(self):
		self.isDead.set();
		try:
			self.MPI.put_nowait("Stopping FX3");
		except Exception as ei:
			pass
		finally:
			self.MPI.close();
			self.MPI.cancel_join_thread();

	def stop(self):
		if(not self.isDead.is_set()):
			self.isDead.set();
			self.join();
		
	def getPipe(self):
		return self.pipeOut;

	def getBufferSize(self):
		return self.bufferSize;


class Emulator(mp.Process):
	_TIMEOUT = 2000;
	_READ_SIZE = 262144;	#512KB = 524288 base2
	_NUM_BYTES = 2;

	def __init__(self, MPI, dummyFile, bufferSize=_READ_SIZE, fs=2.5E6):
		mp.Process.__init__(self);

		self.MPI = MPI;
		self.file = open(dummyFile, 'rb');
		self.bufferSize = bufferSize;
		(self.pipeOut, self.pipeIn) = mp.Pipe(duplex=False);
		self._packet = usb.util.create_buffer(self.bufferSize);

		self.loadClk = float(bufferSize)/fs;

		self.isDead = mp.Event();

	def run(self):	
		p = psutil.Process(os.getpid());
		p.nice(-15);
		try:
			tstart = time.time();
			while(not self.isDead.is_set()):
				# self.pipeOut.send_bytes(self._dev.read(DCS._ENDPOINT_ID, self.bufferSize, DCS._TIMEOUT));
				self._packet = self.file.read(self.bufferSize);
				if(len(self._packet) != self.bufferSize):
					raise Exception("Device not ready");

				self.pipeIn.send_bytes(self._packet);

				trun = time.time() - tstart;
				tstart = time.time();

				time.sleep(max(0, self.loadClk-trun));

		except Exception as e:
			try:
				self.MPI.put_nowait(e);
			except Exception as ei:
				pass
		finally:
			self.shutdown();

	def shutdown(self):
		self.isDead.set();
		self.file.close();
		try:
			self.MPI.put_nowait("Stopping FX3");
			time.sleep(1);
		except Exception as ei:
			pass
		finally:
			self.MPI.close();
			self.MPI.cancel_join_thread();

	def stop(self):
		if(not self.isDead.is_set()):
			self.isDead.set();
			# self.join();
		
	def getPipe(self):
		return self.pipeOut;

	def getBufferSize(self):
		return self.bufferSize;
