import numpy as np


def parseCharles2(dataStream):
	# dataStream = np.frombuffer(data, dtype=np.int16);

	vap1 = np.bitwise_and(dataStream, 0x0001)>0;
	vap2 = np.bitwise_and(dataStream, 0x0002)>0;
	vap3 = np.bitwise_and(dataStream, 0x0004)>0;
	vap4 = np.bitwise_and(dataStream, 0x0008)>0;

	cn1 = np.bitwise_and(dataStream, 0x0070);
	cn2 = np.bitwise_and(dataStream, 0x0380);
	cn3 = np.bitwise_and(dataStream, 0x1C00);
	cn4 = np.bitwise_and(dataStream, 0xE000);

	cn1 = np.right_shift(cn1, 4);
	cn2 = np.right_shift(cn2, 7);
	cn3 = np.right_shift(cn3, 10);
	cn4 = np.right_shift(cn4, 13);

	ddata = np.diff(cn1);
	e = np.array((ddata<0)*8, dtype=np.int8);
	cn1 = ddata + e;

	ddata = np.diff(cn2);
	e = np.array((ddata<0)*8, dtype=np.int8);
	cn2 = ddata + e;

	ddata = np.diff(cn3);
	e = np.array((ddata<0)*8, dtype=np.int8);
	cn3 = ddata + e;

	ddata = np.diff(cn4);
	e = np.array((ddata<0)*8, dtype=np.int8);
	cn4 = ddata + e;


	return(np.array((cn1,cn2,cn3,cn4), dtype=np.uint8), np.array((vap1,vap2,vap3,vap4), dtype=np.uint8));

def parseCharlesLegacy(dataStream):
	vap1 = np.bitwise_and(dataStream, 0x0040)>0;
	vap2 = np.bitwise_and(dataStream, 0x0080)>0;
	vap3 = np.bitwise_and(dataStream, 0x4000)>0;
	vap4 = np.bitwise_and(dataStream, 0x8000)>0;

	cn1 = np.bitwise_and(dataStream, 0x0007);
	cn2 = np.bitwise_and(dataStream, 0x0038);
	cn3 = np.bitwise_and(dataStream, 0x0700);
	cn4 = np.bitwise_and(dataStream, 0x3800);

	# cn1 = np.right_shift(cn1, 0);
	cn2 = np.right_shift(cn2, 3);
	cn3 = np.right_shift(cn3, 8);
	cn4 = np.right_shift(cn4, 11);

	ddata = np.diff(cn1);
	e = np.array((ddata<0)*8, dtype=np.int8);
	cn1 = ddata + e;

	ddata = np.diff(cn2);
	e = np.array((ddata<0)*8, dtype=np.int8);
	cn2 = ddata + e;

	ddata = np.diff(cn3);
	e = np.array((ddata<0)*8, dtype=np.int8);
	cn3 = ddata + e;

	ddata = np.diff(cn4);
	e = np.array((ddata<0)*8, dtype=np.int8);
	cn4 = ddata + e;


	return(np.array((cn1,cn2,cn3,cn4), dtype=np.uint8), np.array((vap1,vap2,vap3,vap4), dtype=np.uint8));
