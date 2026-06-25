# swirl.pl
# Generates a swirl-like SIMION potential array
#   (like a ribbon wrapped around a cylinder)
#
# David Manura, Scientific Instrument Services, Inc.
# $Revision$ $Date$ Created: 2003-11.

use strict;
use POSIX;
use SIMION::PA;     # potential array library
my $pi = 3.141592;

print "Generating swirl.pa# file....\n";

# create new potential array
my $pa = new SIMION::PA(nx => 100, ny => 100, nz => 100);

# iterate over all points ($x, $y, $z).
for my $x (0..$pa->nx-1) {
for my $y (0..$pa->ny-1) {
for my $z (0..$pa->nz-1) {
    # compute polar coordinates
    my $dx = $x - 50;
    my $dy = $y - 50;
    my $radius = sqrt($dx * $dx + $dy * $dy);
    my $theta = atan2($dy, $dx);  # -PI..PI

    # this is what generates the rotation along the axis.
    my $omega = $pi + $theta + $z/5;
    # wrap around to range 0..2*PI
    $omega -= 2*$pi while $omega >= 2*$pi;

    # compute point value
    my $is_electrode = ($radius > 30 && $radius < 35 && $omega < 2);
    my $voltage = 1.0;

    # set point value
    $pa->point($x, $y, $z, $is_electrode, $voltage) if $is_electrode;
}}} # end loop

# write file
$pa->save("swirl.pa#");

print "done\n";


