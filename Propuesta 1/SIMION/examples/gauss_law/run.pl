# run.pl
# Perl program to assist in calulating the total charge inside some
# defined volume of a SIMION potential array (PA) file.
# This applies Gauss's Law (http://en.wikipedia.org/wiki/Gauss's_law)
# as described on http://www.simion.com/info/Charge-Capacitance_Calculation.
#
# To use this program, you will need to edit the parameters in the "test"
# subroutine.  The defaults given here can be used with the spherical
# capacitor systems shown in (http://www.simion.com/info/HDA).
#
# This program calculates the Gauss's Law equation using a simple but
# suitable Monte-Carlo integration.  The integration will proceed until
# a (configurable) convergence limit is reached.
#

use strict;
use lib '../../lib/perl';  # location of SL libraries.
use SIMION::PA;
use FieldAnalysis;

&test();

sub test {
  # $pa_name: location of the SIMION potential array (PA) file.
  # $L: mm/gu scaling factor used in the PA.
  #my ($pa_name, $L) = ('sc3d.pa', 1);
  #my ($pa_name, $L) = ('sc2d.pa', 1);
  my ($pa_name, $L) = ('sc2d10.pa', 0.1);

  # load potential array
  my $pa = SIMION::PA->new(file => $pa_name);

  # calculate total charge using Gauss's Law.
  print "EXPECTING: 2.225301E-8\n";

  # note: change "if (1)" to enable or "if (0)" to disable blocks.

  if (1) {
    &FieldAnalysis::charge_from_gauss_law_display(
      pa => $pa,
      shape => &FieldAnalysis::sphere(0,0,0, 100),
      mm_per_unit => $L,
      min_coverage => 0.1,
      max_fe => 0.0001
    );
  }

  # Alternately, use a different surface
  # (this box may be a little bit too close):
  if (0) {
    &FieldAnalysis::charge_from_gauss_law_display(
      pa => $pa,
      shape => &FieldAnalysis::box(-82,-82,-82, 82,82,82),
      mm_per_unit => $L,
      min_coverage => 0.5,
      max_fe => 0.001
    );
  }
  if (0) {
    &FieldAnalysis::charge_from_gauss_law_display(
      pa => $pa,
      shape => &FieldAnalysis::cylinder(-82,0,0, 1,0,0, 82, 164),
      mm_per_unit => $L,
      min_coverage => 0.5,
      max_fe => 0.001
    );
  }
}


1
