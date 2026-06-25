
There are three linear acceleration tests in this sequence.

1.    Non-Relativistic

    Preparation:  Refine the non-relativistic.pa# file to 1.0e-7.
                  Remove all PAs from RAM

    To Run:     Load non-relativistic.iob into View.
                Click the Fly'm button.

    Discussion:

    A 200 amu ion with 20 eV ke in the negative y direction is accelerated
    to an additional 50 eV in the positive x direction by a linear
    gradient electrostatic field.

    Expected and observed TOF and kinetic energies are displayed for
    comparison.

2.    Relativistic Linear

    Preparation:  Refine the relativistic_linear.pa# file to 1.0e-7.
                  Remove all PAs from RAM

    To Run:     Load relativistic_linear.iob into View.
                Click the Fly'm button.

    Discussion:

    An electron is accelerated by a linear gradient electrostatic field
    to a kinetic energy equal to its rest mass.

    Its expected and computed final velocities are compared.

3.    Relativistic Cross

    Preparation:  Create PA with New and geometry file relativistic_cross.gem
                  Save the created PA as relativistic_cross.pa#
                  Refine the relativistic_cross.pa# file to 1.0e-7.
                  Remove all PAs from RAM

    To Run:     Load relativistic_cross.iob into View.
                Click the Fly'm button.

    Discussion:

    Three electrons with 1, 3, and 7 rest masses of kinetic energy
    in the negative y direction are accelerated in with a cross
    acceleration in the positive x that imparts one rest mass of
    additional kinetic energy.

    Expected velocities and ke are compared with calculated value.

    Note: At relativistic velocities vx and vy are NOT independent.

