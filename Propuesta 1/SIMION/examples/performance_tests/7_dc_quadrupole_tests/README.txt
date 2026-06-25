Introduction:

This simulation test uses planar 2D arrays to simulate the fields
in a linear quadrupole.  There are two simulations quad and quad1.
The difference is in the size of the quad rods projected into the
array.

The quad array simulation:

Preparation:
    Use New with the geometry file quad.gem to create a PA
    Save the PA as quad.pa#
    Load the file quad.pa# and refine it to 1.0e-7
    Remove all PAs
    Load the quad.iob file into View
    Click the Fly'm button.

Discussion:
    six ions are flown up the hill from the quad center.  The first
    three have different energies and use the refined field to calculate
    their trajectories.  The key recorded data is x at reversal and
    the 1/4 cycle period.

    The second group of three ions are flown with user program supplied
    analytical fields for comparison.  These ions match the expected values
    much closer.

The quad1 array simulation:

Preparation:
    Use New with the geometry file quad1.gem to create a PA
    Save the PA as quad1.pa#
    Load the file quad1.pa# and refine it to 1.0e-7
    Remove all PAs
    Load the quad.iob file into View
    Click the Fly'm button.

Discussion:
    six ions are flown up the hill from the quad center.  The first
    three have different energies and use the refined field to calculate
    their trajectories.  The key recorded data is x at reversal and
    the 1/4 cycle period.

    The second group of three ions are flown with user program supplied
    analytical fields for comparison.  These ions match the expected values
    much closer.

    Quad1 gives slightly more accurate results than quad, because of the
    larger rods involved.
