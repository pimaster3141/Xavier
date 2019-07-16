import sys
sys.path.insert(0, 'PythonLib');
sys.path.insert(0, 'PythonLib/System');
sys.path.insert(0, 'PythonLib/GUI');
import CharlesSystem
import code

charles = None

def start(filename, version=None, sampleClk=None, averages=[[0,3]], numProcessors=None, demo=False):
	global charles;
	charles = CharlesSystem.CharlesSystem(filename, version=version, fs=sampleClk, averages=averages, numProcessors=numProcessors, demo=demo);
	charles.start();

def stop():
	global charles;
	if(not charles == None):
		charles.stop();
	charles = None;


print("Starting Up...");
code.interact(local = locals());
