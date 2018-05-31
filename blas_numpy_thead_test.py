#!/usr/bin/env python

# USAGE:
#  python  testThreadCount.py 
#  OPENBLAS_NUM_THREADS=5 python  testThreadCount.py
# and watch htop in tree view sorted by cpu (push t for tree, P for cpu sort )
#

# copied from
#   https://gist.github.com/alimuldal/eb0f4eea8af331b2a890
# provided as response to
#   https://stackoverflow.com/questions/11443302/compiling-numpy-with-openblas-integration

import numpy
from numpy.distutils.system_info import get_info
import sys
import timeit

print("version: %s" % numpy.__version__)
print("maxint:  %i\n" % sys.maxsize)

info = get_info('blas_opt')
print('BLAS info:')
for kk, vv in info.items():
    print(' * ' + kk + ' ' + str(vv))

setup = "import numpy; x = numpy.random.random((5000, 2000))"
count = 10

t = timeit.Timer("numpy.dot(x, x.T)", setup=setup)
print("\ndot: %f sec" % (t.timeit(count) / count))
