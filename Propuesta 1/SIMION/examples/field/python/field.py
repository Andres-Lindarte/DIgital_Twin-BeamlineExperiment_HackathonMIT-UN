# field.pl
# Generates magnetic PA from magnetic field vectors.
#
# David Manura, Scientific Instrument Services, Inc.
# $Revision$ $Date$ Created 2004-07.

from SIMION.PA import *
from math import *

pa = PA(nx = 100, ny = 100)

z = 0
for x in range(0, pa.nx()):
    for y in range(0, pa.ny()):
        ex = x;
        ey = y**2;
        ez = 0
        pa.field(x, y, z, ex, ey, ez)

pa.save('mag1.pa')
print("Created mag1.pa.\n")

pa = PA(nx = 100, ny = 100, field_type = 'magnetic')

z = 0
for x in range(0, pa.nx()):
    for y in range(0, pa.ny()):
        ex = cos(x/10)
        ey = sin(y/10)
        ez = 0
        pa.field(x, y, z, ex, ey, ez)
pa.save('mag2.pa')
print("Created mag2.pa.\n")
