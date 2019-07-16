import sys
sys.path.insert(0, 'PythonLib');
sys.path.insert(0, 'PythonLib/System');
sys.path.insert(0, 'PythonLib/GUI');
import XavierSystem
import code

xavier = None

def start(filename, version=None, sampleClk=None, averages=[[0,3]], numProcessors=None, demo=False):
	global xavier;
	xavier = XavierSystem.XavierSystem(filename, version=version, fs=sampleClk, averages=averages, numProcessors=numProcessors, demo=demo);
	xavier.start();

def stop():
	global xavier;
	if(not xavier == None):
		xavier.stop();
	xavier = None;


print("Starting Up...");
code.interact(local = locals());
