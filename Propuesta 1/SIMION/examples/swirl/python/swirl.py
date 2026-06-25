# swirl.pl
# Generates a swirl-like SIMION potential array
#   (like a ribbon wrapped around a cylinder)
#
# David Manura, Scientific Instrument Services, Inc.
# $Revision$ $Date$ Created 2003-11.

from SIMION.PA import *
from math import *

print("Generating swirl.pa# file....\n");

# create new potential array
pa = PA(nx=100, ny=100, nz=100)

# iterate over all points
for x in range(0, pa.nx()):
    for y in range(0, pa.ny()):
        for z in range(0, pa.nz()):

            # compute polar coordinates
            dx = x - 50
            dy = y - 50
            radius = sqrt(dx * dx + dy * dy)

            if dx == 0 and dy == 0: # atan2 would fail on this
                theta = 0
            else:
                theta = atan2(dy, dx);  # -PI..PI

            # this is what generates the rotation along the axis.
            omega = pi + theta + z/5.0
            # wrap around omega to range 0..2*PI
            while omega >= 2*pi:
                omega -= 2*pi 

            # compute point value
            is_electrode = (radius > 30 and radius < 35 and omega < 2)
            voltage = 1

            # set point value
            if is_electrode: pa.point(x, y, z, 1, voltage)

# write file
pa.save("swirl.pa#")

print("done")


