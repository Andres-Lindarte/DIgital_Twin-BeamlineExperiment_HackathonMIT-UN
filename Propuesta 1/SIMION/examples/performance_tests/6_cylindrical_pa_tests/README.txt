Introduction:

This simulation test uses cylindrical 2D arrays to simulate the fields
between two infinite cylinders.  Large and small cylindrical array
simulations are provided for comparison purposes.

The small array simulation:

Preparation:
    Load the file small_pa_cylinder.pa# and refine it to 1.0e-7
    Remove all PAs
    Load the small_pa_cylinder.iob file into View
    Click the Fly'm button.

Discussion:
    Two ions are given the appropriate energy so that they would be expected
    to have orbits with a radius of 300mm in the field.  Expected values
    for radius, potential, and potential gradient are given along with
    those obtained from the simulation.

    Two ions are flown.  Ion number one used the potential array's fields.
    Ion number two uses analytical fields via a user program.  The second
    ion's trajectories are much more accurate.  However the large array
    simulation below gives almost as good results.

The large array simulation:

Preparation:
    Use New with the geometry file big_pa_cylinder.gem to create a PA
    Save the PA as big_pa_cylinder.pa#
    Refine big_pa_cylinder.pa# to 1.0e-7.
    Remove all PAs
    Load the big_pa_cylinder.iob file into View
    Click the Fly'm button.

Discussion:
    The ion is given the appropriate energy so that it would be expected
    to have an orbit with a radius of 300mm in the field.  Expected values
    for radius, potential, and potential gradient are given along with
    those obtained from the simulation.


    The Cylindrical PA Tests do better than the planar array tests
    in simulating infinite concentric cylinders.
