import timeit
import array
import Parser

data = bytes([0b01000001, 0b10111110, 0b00101010, 0b10101010]*32768);
data = array.array('B', data);

spadData, aData, dData = Parser.parse(data);



import timeit
import array
import Parser
import numpy as np

data = bytes([0b01000001, 0b10111110, 0b00101010, 0b10101010]*32768);
data = array.array('B', data);
data = np.array([data, data, data, data]);

spadData, aData, dData = Parser.parseAll(data);




import numpy as np
import Autocorrelate
import multipletau as mt
data = np.random.rand(32768);
data = np.round(data);
normalize=True;
levels=34

out = Autocorrelate.multipleTau(data, levels, 1, normalize);
out = np.asarray(out);
out2 = mt.autocorrelate(data, m=levels, normalize=normalize);
out2[:,0]=out;
out2;
np.max(np.abs(out2[:,0]-out2[:,1]));



python3 -m timeit -s "import numpy as np
import Autocorrelate
import multipletau as mt
data = np.random.rand(3276800);
data = np.round(data);
normalize=True;
levels=32" "out = Autocorrelate.multipleTau(data, levels, normalize);"




