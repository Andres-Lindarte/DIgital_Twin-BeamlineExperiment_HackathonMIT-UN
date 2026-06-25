Introduction:

This test uses linear gradient fields and an ideal grid to test the
conservation of energy in linear fields with discontinuities.  The
fields form an electrostatic trough that acts to reflect the ion into
wave-like motions.

Preparation:

To run the test, you must first load the reflections.pa# file and refine
it to 1.0e-7 convergence. Remove all arrays and load the reflections.iob
file into view, and then click the Fly'm button.

Discussion:

The PA with its central ideal mirror forms a reflection trough.  Ions are
launched with a small amount of kinetic energy in the x direction
half way up one side of the trough in y. The ion forms a trajectory wave
as it swings across the center grid.  Energy is conserved if successive
peak heights remain the same (successive ymaxes remain the same).

Note: Two red neutrals are flown to serve as a reference for peak height
measurements for the tests described below.

As a test, vary the trajectory quality to 103 or above.  Now try 0 and
various negative numbers.  Notice that 0 or negative numbers do not conserve
energy very well.  Turn on data recording so that a marker is generated
each time step.  Notice that time steps bunch near velocity reversals and
around the ideal grid discontinuity when trajectory quality is positive.
This helps to better conserve the ion's energy in the calculation.
