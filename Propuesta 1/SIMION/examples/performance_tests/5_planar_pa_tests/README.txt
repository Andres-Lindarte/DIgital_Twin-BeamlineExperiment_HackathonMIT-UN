Introduction:

This simulation test uses planar 2D arrays to simulate the fields between
two infinite cylinders.  Large and small planar array simulations are
provided for comparison purposes.

The small array simulation:

Preparation:
    Use New with the geometry file small_pa_planar.gem to create a PA
    Save the PA as small_pa_planar.pa#
    Refine small_pa_planar.pa# it to 1.0e-7.
    Remove all PAs
    Load the small_pa_planar.iob file into View
    Click the Fly'm button.

Discussion:
    The ion is given the appropriate energy so that it would be expected
    to have an orbit with a radius of 30mm in the field.  Expected values
    for radius, potential, and potential gradient are given along with
    those obtained from the simulation.

The large array simulation:

Preparation:
    Use New with the geometry file big_pa_planar.gem to create a PA
    Save the PA as big_pa_planar.pa#
    Refine big_pa_planar.pa# to 1.0e-7.
    Remove all PAs
    Load the big_pa_planar.iob file into View
    Click the Fly'm button.

Discussion:
    The ion is given the appropriate energy so that it would be expected
    to have an orbit with a radius of 30mm in the field.  Expected values
    for radius, potential, and potential gradient are given along with
    those obtained from the simulation.

    Refine times are very large for the incremental improvement in accuracy
    when compared to the smaller array.

    The Cylindrical PA Tests do much better with smaller arrays.
