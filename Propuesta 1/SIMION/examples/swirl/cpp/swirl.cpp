/**
 * @file swirl.cpp
 * This generates a potential array file describing a swirl-like
 * shape (e.g. a ribbon wrapped around a cylinder).
 *
 * David Manura, Scientific Instrument Services, Inc.
 * $Revision$ $Date$ Created 2003-11.
 */

#include <iostream>
#include <cmath>

#include <simion/pa.h>           // SL potential array class
//#include <simion/pa.cpp>
using namespace std;
using namespace simion;

const double pi = 3.141592;

int main()
{
    cout << "Generating swirl.pa# file....\n";

    // create array in memory
    PA pa(PAArgs().nx(100).ny(100).nz(100));

    // iterate over all points
    for(int x = 0; x < pa.nx(); x++) {
    for(int y = 0; y < pa.ny(); y++) {
    for(int z = 0; z < pa.nz(); z++) {
        // compute polar coordinates
        int dx = x - 50;
        int dy = y - 50;
        double radius = sqrt((double)(dx * dx + dy * dy));
        double theta = atan2((double)dy, (double)dx);  // -PI..PI

        double omega = pi + theta + (double)z/5;
        // wrap omega to range 0..2*PI
        while(omega >= 2*pi)
            omega -= 2*pi;

        bool is_electrode = (radius > 30 && radius < 35 && omega < 2);
        double voltage = 1;

        // set point value
        if(is_electrode) pa.point(x, y, z, true, voltage);
    }}} // end loops

    // save to file
    pa.save("swirl.pa#");

    cout << "done\n";

    return 0;
}
