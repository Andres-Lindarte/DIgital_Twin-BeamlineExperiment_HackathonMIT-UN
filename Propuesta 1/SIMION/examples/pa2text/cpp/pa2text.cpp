/**
 * @file pa2text.cpp
 * Reads the contents of a SIMION potential array file and writes the
 * contents to standard output.
 *
 * David Manura, Scientific Instrument Services, Inc.
 * $Revision$ $Date$ Created 2003-10.
 */
#include <iostream>
#include <fstream>
#include <simion/pa.h>

using namespace std;
using namespace simion;

void print_usage()
{
    cerr << "usage: pa2text <file>" << endl;
}

// note: issue on precision of double printing
int main(int argc, char** argv)
{
    ifstream is;

    if(argc < 2) {
        print_usage();
        return 1;
    }

    string filename = argv[1];

    ofstream outfile((filename + ".txt").c_str());

    PA pa;
    pa.load(filename);

    outfile
         << "file_type=" << "simion_pa" << endl;

    outfile
         << "begin_header" << endl
         << "mode=" << pa.mode() << endl
         << "symmetry=" << (pa.symmetry() == CYLINDRICAL ?
                            "cylindrical" : "PLANAR") << endl
         << "max_voltage=" << pa.max_voltage() << endl
         << "nx=" << pa.nx() << endl
         << "ny=" << pa.ny() << endl
         << "nz=" << pa.nz() << endl
         << "mirror_x=" << !!(pa.mirror_x()) << endl
         << "mirror_y=" << !!(pa.mirror_y()) << endl
         << "mirror_z=" << !!(pa.mirror_z()) << endl
         << "magnetic_pa=" << pa.field_string(pa.field_type()) << endl
         << "ng=" << pa.ng() << endl
         ;
    outfile
         << "end_header" << endl;

    // note: output in row-major order:
    //   double points[nz][ny][nz]
    outfile << "begin_points" << endl;
    
    for(int z=0; z<pa.nz(); z++) {
        for(int y=0; y<pa.ny(); y++) {
            for(int x=0; x<pa.nx(); x++) {
                PAPoint point = pa.point(x, y, z);
                outfile << point.electrode << "," << point.potential << endl;
            }
        }
    }
    outfile << "end_points" << endl;

    return 0;
}

