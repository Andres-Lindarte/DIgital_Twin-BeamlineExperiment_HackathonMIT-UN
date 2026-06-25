/**
 * @file field.cpp
 * Generates magnetic PA from magnetic field vectors.
 *
 * David Manura, Scientific Instrument Services, Inc.
 * $Revision$ $Date$ Created 2004-07.
 */

#include <simion/pa.h>
#include <cmath>
using namespace std;
using namespace simion;

void test1()
{
    PA pa(PAArgs().nx(100).ny(100));
    int z = 0;
    for(int x = 0; x < pa.nx(); x++) {
    for(int y = 0; y < pa.ny(); y++) {
        double ex = x;
        double ey = y*y;
        double ez = z;
        pa.field(x, y, z, ex, ey, ez);
    }}
    pa.save("mag1.pa");
}

void test2()
{
    PA pa(PAArgs().nx(100).ny(100).field_type(MAGNETIC));

    int z = 0;
    for(int x = 0; x < pa.nx()-1; x++) {
    for(int y = 0; y < pa.ny()-1; y++) {
        double ex = cos((double)x / 10.0);
        double ey = sin((double)y / 10.0);
        double ez = 0;
        pa.field(x, y, z, ex, ey, ez);
    }}
    pa.save("mag2.pa");
}

int main()
{
    test1();
    test2();

    return 0;
}


