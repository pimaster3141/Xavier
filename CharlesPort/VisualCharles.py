from sys import platform
if platform == "linux" or platform == "linux2":
	pass
elif platform == "darwin":
	raise Exception("Unsupported OS: " + str(platform));
elif platform == "win32":
	raise Exception("Unsupported OS: " + str(platform));

print("Compiling and Loading Libraries...")

import setuptools
import pyximport; pyximport.install()
import sys
sys.path.insert(0, 'PythonLib');

from PyQt5.QtCore import QDateTime, Qt, QTimer
from PyQt5.QtWidgets import *

import GraphWidget

class CharlesGUI(QWidget):
	def __init__(self, parent=None):
		super(CharlesGUI, self).__init__(parent);

		self.graphs = GraphWidget.GraphWidget(None);

		mainLayout = QGridLayout();
		mainLayout.addLayout(self.initFileBar(), 0, 0, 1, 1);
		mainLayout.addLayout(self.initRunBar(), 0, 1, 1, 1);
		mainLayout.addWidget(self.graphs, 1, 0, 1, 2);
		self.setLayout(mainLayout);

	def initFileBar(self):
		self.directoryField = QLineEdit();
		self.directoryLabel = QLabel("Working Directory:");
		self.directoryButon = QPushButton("Browse");
		self.directoryButon.clicked.connect(self.browseDirectory);
		self.fileField = QLineEdit();
		self.fileLabel = QLabel("Output File:")

		fileBar = QGridLayout();
		fileBar.addWidget(self.directoryLabel, 0, 0);
		fileBar.addWidget(self.directoryField, 0, 1);
		fileBar.addWidget(self.directoryButon, 0, 2);
		fileBar.addWidget(self.fileLabel, 1, 0);
		fileBar.addWidget(self.fileField, 1, 1);

		return(fileBar);

	def browseDirectory(self):
		folder = str(QFileDialog.getExistingDirectory(self, "Select Directory"));
		self.directoryField.setText(folder);

	def initRunBar(self):
		self.runButton = QPushButton("RUN");
		self.runButton.clicked.connect(self.startCollection);

		self.stopButton = QPushButton("STOP");
		self.stopButton.clicked.connect(self.stopCollection);
		self.stopButton.setEnabled(False);


		runBar = QVBoxLayout();
		runBar.addWidget(self.runButton);
		runBar.addWidget(self.stopButton);
		return(runBar);

	def startCollection(self):
		pass;
		self.runButton.setEnabled(False);
		self.stopButton.setEnabled(True);

	def stopCollection(self):
		pass;
		self.runButton.setEnabled(True);
		self.stopButton.setEnabled(False);



if __name__ == '__main__':

    import sys

    app = QApplication(sys.argv)
    gallery = CharlesGUI()
    gallery.show()
    sys.exit(app.exec_()) 