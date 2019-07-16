import setuptools
import pyximport; pyximport.install()

import PyQt5
import pyqtgraph as pg
import numpy as np
import DataProcessor
import G2Calc
import queue
import time
import warnings

class GraphWidget(pg.GraphicsLayoutWidget):
	PEN_COLORS = ['w', 'y', 'g', 'b'];
	QUEUE_TIMEOUT = 5;	


	def __init__(self, processor, depth=10, legacy=False, refreshRate=30, stopFcn=None, **kwargs):
		super().__init__(None, **kwargs);
		warnings.catch_warnings();
		warnings.simplefilter("ignore");
		# self.processor = processor;
		# (self.g2Source, self.flowSource) = self.processor.getBuffers();
		# self.tauList = self.processor.getTauList();
		# self.samplePeriod = self.processor.getTWindow();
		self.samplePeriod=.05;
		# self.binRate = self.processor.getFs();
		# self.calcFlow = self.processor.isFlowEnabled();
		self.calcFlow=True;

		self.numSamples = int((depth/self.samplePeriod)+0.5);
		self.xData = np.arange(-self.numSamples, 0, dtype=np.int)*self.samplePeriod;

		self._lastTime = time.time();
		self._refreshPeriod = 1/refreshRate;
		self.stopFcn = stopFcn;
		self.isAlive = True;

		# self.setupDataBuffers();
		self.setupPlots(legacy);
		
	def setupPlots(self, legacy):
		self.g2Plot = self.addPlot(title="G2", labels={'left':('g2'),'bottom':('Delay Time', 's')}, row=0, col=0);
		self.g2Plot.setMouseEnabled(x=False, y=False);
		self.g2Plot.enableAutoRange(x=False, y=False);
		self.g2Plot.setLogMode(x=True, y=False);
		self.g2Plot.setYRange(0.99, 1.3);
		self.g2Plot.showGrid(x=True, y=True);
		self.g2Legend = self.g2Plot.addLegend(offset=(-1,1));

		self.betaPlot = self.addPlot(title="Beta", labels={'bottom':('Time', 's')}, row=0, col=1);
		self.betaPlot.setMouseEnabled(x=False, y=False);
		self.betaPlot.showGrid(x=False, y=True);

		self.snrPlot = self.addPlot(title="SNR", labels={'left':('SNR'),'bottom':('Time', 's')}, row=1, col=0);
		self.snrPlot.setMouseEnabled(x=False, y=False);
		self.snrPlot.enableAutoRange(x=False, y=True);
		self.snrPlot.setLogMode(x=True, y=False);
		self.snrPlot.showGrid(x=True, y=True);

		self.vapPlot = self.addPlot(title="Vaporizer", labels={'bottom':('Time', 's')}, row=1, col=1);
		self.vapPlot.setMouseEnabled(x=False, y=False);
		self.vapPlot.enableAutoRange(x=True, y=False);
		self.vapPlot.setYRange(0, 1);

		self.countPlot = self.addPlot(title="Photon Count", labels={'left':('Count', 'cps'),'bottom':('Time', 's')}, row=2, col=0, colspan=2);
		self.countPlot.setMouseEnabled(x=False, y=False);
		self.countPlot.enableAutoRange(x=True, y=True);
		self.countPlot.showGrid(x=False, y=True);

		self.flowPlot = None;
		if(self.calcFlow):
			self.flowPlot = self.addPlot(title="Fitted Flow", labels={'left':('aDb'), 'bottom':('Time', 's')}, row=3, col=0, colspan=2);
			self.flowPlot.setMouseEnabled(x=False, y=False);
			self.flowPlot.showGrid(x=False, y=True);

		# self.setupCurves();

	def setupCurves(self):
		self.g2Curves = [];
		self.vapCurves = [];
		self.snrCurves = [];
		self.betaCurves = [];
		self.countCurves = [];
		self.flowCurves = [];

		snrData = G2Calc.calcSNR(self.g2Buffer);
		for c in range(self.numG2Channels):
			self.g2Curves.append(self.g2Plot.plot(x=self.tauList, y=self.g2Buffer[0,c,:], pen=GraphWidget.PEN_COLORS[c], name='CH'+str(c)));
			self.snrCurves.append(self.snrPlot.plot(x=self.tauList, y=snrData[c], pen=GraphWidget.PEN_COLORS[c], name='CH'+str(c)));
			self.vapCurves.append(self.vapPlot.plot(x=self.xData, y=self.vapBuffer[:,c], pen=GraphWidget.PEN_COLORS[c], name='CH'+str(c)));
			self.countCurves.append(self.countPlot.plot(x=self.xData, y=self.countBuffer[:,c], pen=GraphWidget.PEN_COLORS[c], name='CH'+str(c)));
			self.betaCurves.append(self.betaPlot.plot(x=self.xData, y=self.betaBuffer[:,c], pen=GraphWidget.PEN_COLORS[c], name='CH'+str(c)));

		if(self.calcFlow):
			for c in range(self.numFlowChannels):
				self.flowCurves.append(self.flowPlot.plot(x=self.xData, y=self.flowBuffer[:,c], pen=GraphWidget.PEN_COLORS[c], name='CH'+str(c)));

	def setupDataBuffers(self):
		g2QueueData = self.g2Source.get(block=True, timeout=GraphWidget.QUEUE_TIMEOUT);
		self.numG2Channels = len(g2QueueData[0][0]);
		self.numVapChannels = len(g2QueueData[0][1]);
		
		self.g2Buffer = np.ones((self.numSamples, self.numG2Channels, len(self.tauList)));
		self.vapBuffer = np.zeros((self.numSamples, self.numVapChannels));
		self.countBuffer = np.zeros((self.numSamples, self.numG2Channels));
		self.betaBuffer = np.zeros((self.numSamples, self.numG2Channels));

		flowQueueData = None;
		self.numFlowChannels = None;
		self.flowBuffer = None;
		if(self.calcFlow):
			flowQueueData = self.flowSource.get(block=True, timeout=GraphWidget.QUEUE_TIMEOUT);
			self.numFlowChannels = len(flowQueueData[0])
			self.flowBuffer = np.zeros((self.numSamples, self.numFlowChannels));

		self.updateDataBuffers(g2QueueData, flowQueueData);


	def updateDataBuffers(self, g2QueueData, flowQueueData):
		numShift = len(g2QueueData);
		g2Data = np.array([item[0] for item in g2QueueData]);
		vapData = np.array([item[1] for item in g2QueueData]);

		self.countBuffer = np.roll(self.countBuffer, -1*numShift, axis=0);
		self.countBuffer[-numShift:] = self.binRate/g2Data[:, :, 0];

		g2Data[:,:,0] = 0;

		self.g2Buffer = np.roll(self.g2Buffer, -1*numShift, axis=0);
		self.g2Buffer[-numShift:] = g2Data;

		self.vapBuffer = np.roll(self.vapBuffer, -1*numShift, axis=0);
		self.vapBuffer[-numShift:] = vapData;

		betaData = np.mean(g2Data[:,:,1:4], axis=2)-1;
		self.betaBuffer = np.roll(self.betaBuffer, -1*numShift, axis=0);
		self.betaBuffer[-numShift:] = betaData;

		if(self.calcFlow):
			numShift = len(flowQueueData);
			flowData = flowQueueData;

			self.flowBuffer = np.roll(self.flowBuffer, -1*numShift, axis=0);
			self.flowBuffer[-numShift:] = flowData;

	def redrawCurves(self):
		snrData = G2Calc.calcSNR(self.g2Buffer);
		for c in range(self.numG2Channels):
			self.g2Curves[c].setData(x=self.tauList, y=self.g2Buffer[-1,c,:]);
			self.snrCurves[c].setData(x=self.tauList, y=snrData[c]);
			self.vapCurves[c].setData(x=self.xData, y=self.vapBuffer[:,c]);
			self.countCurves[c].setData(x=self.xData, y=self.countBuffer[:,c]);
			self.betaCurves[c].setData(x=self.xData, y=self.betaBuffer[:,c]);

		if(self.calcFlow):
			for c in range(self.numFlowChannels):
				self.flowCurves[c].setData(x=self.xData, y=self.flowBuffer[:,c]);


	def updateRoutine(self):
		g2QueueData = self.g2Source.get(block=True, timeout=GraphWidget.QUEUE_TIMEOUT);
		g2QueueData = GraphWidget.emptyBuffer(self.g2Source, g2QueueData);

		flowQueueData = None;
		if(self.calcFlow):
			flowQueueData = self.flowSource.get(block=True, timeout=GraphWidget.QUEUE_TIMEOUT);
			flowQueueData = GraphWidget.emptyBuffer(self.flowSource, flowQueueData.tolist());

		self.updateDataBuffers(g2QueueData, flowQueueData);
		self.redrawCurves();

	def run(self):
		if(self.isAlive):
			try:
				self.updateRoutine();
			except queue.Empty, OSError:
				self.isAlive = False;

			current = time.time();
			deltaTime = current - self._lastTime;
			self._lastTime = current;
			pg.QtCore.QTimer.singleShot(max((self._refreshPeriod-deltaTime)*1000, 1), self.run);
			# print(max((self._refreshPeriod-deltaTime)*1000, 1));
		else:
			return;

	def emptyBuffer(buf, initial): #DO NOT USE FOR FLOW
		try:
			while(True):
				data = buf.get_nowait();
				if(type(data) == np.ndarray):
					data = data.tolist();
				initial = initial+data;
		except queue.Empty:
			pass;
		return initial;

	def closeEvent(self, event):
		print("Closing");
		event.accept();
		self.stop();
		self.close();
		if(not self.stopFcn == None):
			self.stopFcn();

	def stop(self):
		self.isAlive = False;

	def closeWindow(self):
		self.close();






