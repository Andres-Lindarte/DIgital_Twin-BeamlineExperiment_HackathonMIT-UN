# field.pl
# Generates magnetic PA from magnetic field vectors.
#
# David Manura, Scientific Instrument Services, Inc.
# $Revision$ $Date$ Created: 2004-07.

use strict;
use SIMION::PA;

my $pa = new SIMION::PA(nx => 100, ny => 100);

my $z = 0;
for my $x (0..$pa->nx()-1) {
for my $y (0..$pa->ny()-1) {
    my $ex = $x;
    my $ey = $y**2;
    my $ez = 0;
    $pa->field($x, $y, $z, $ex, $ey, $ez);
}}

$pa->save('mag1.pa');

print "Created mag1.pa.\n";

my $pa = new SIMION::PA(nx => 100, ny => 100, field_type => 'magnetic');

my $z = 0;
for my $x (0..$pa->nx()-1) {
for my $y (0..$pa->ny()-1) {
    my $ex = cos($x/10);
    my $ey = sin($y/10);
    my $ez = 0;
    $pa->field($x, $y, $z, $ex, $ey, $ez);
}}

$pa->save('mag2.pa');

print "Created mag2.pa.\n";
