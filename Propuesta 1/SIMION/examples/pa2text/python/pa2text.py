#
# pa2text.py
# Reads the contents of a SIMION potential array file and writes the contents
# to standard output.
#
# This makes use of the SL Potential Array Tools library for
# the file I/O.
#
# David Manura, Scientific Instrument Services, Inc.
# $Revision$ $Date$ Created 2003-11-14.
#

import sys
from SIMION.PA import *

def print_usage():
    print("usage: python pa2text.py <file>")
    sys.exit(1)

if len(sys.argv) < 2:
    print_usage()
    sys.exit(1)

path = sys.argv[1]

outfile = open(path + ".txt", "w")

#-- example reading
pa = PA(file = path)

# print header parameters
outfile.write("begin_header\n")
outfile.write("symmetry=" + pa.symmetry() + "\n")
outfile.write("max_voltage=" + str(pa.max_voltage()) + "\n")
outfile.write("nx=" + str(pa.nx()) + "\n")
outfile.write("ny=" + str(pa.ny()) + "\n")
outfile.write("nz=" + str(pa.nz()) + "\n")
outfile.write("mirror_x=" + str(pa.mirror_x()) + "\n")
outfile.write("mirror_y=" + str(pa.mirror_y()) + "\n")
outfile.write("mirror_z=" + str(pa.mirror_z()) + "\n")
outfile.write("field=" + pa.field_type() + "\n")
outfile.write("ng=" + str(pa.ng()) + "\n")
outfile.write("end_header\n")


outfile.write("begin_points\n")
for z in range(0, pa.nz()):
    for y in range(0, pa.ny()):
        for x in range(0, pa.nx()):
            (electrode, potential) = pa.point(x,y,z)
            electrode_str = electrode and "1" or "0"
            outfile.write(electrode_str + "," + str(potential) + "\n")
outfile.write("end_points\n")

outfile.close()



