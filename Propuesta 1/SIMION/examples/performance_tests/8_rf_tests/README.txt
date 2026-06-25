Introduction:

These tests uses a RF linear gradient fields between two plates to test the
conservation of energy in linear RF fields with discontinuities.  The
RF field forms an electrostatic RF trough that acts to reflect the ion
into wave-like motions.

RF Mirror Test:

A sine wave RF is used between the two plates (in y).  A collection of ions
are given a small ke in x relatively close to one of the plates. Each ion
follows a wave-like trajectory.

Preparation:

    Load rf_mirror.pa# and refine to 1.0e-7
    Remove all PAs
    Load rf_mirror.iob into View
    Click the Fly'm button

Discussion:

    The ions are flown 1/2 cycle (by default) and then killed.  The expected
    peak to peak dy (in mm) using a formal integration of the expected forces
    is compared to the dy obtained from the simulation.

    If you want the ions to keep on flying set the adjustable variable:
    Long_Simulation_if_1 to the value of 1.

    Note that higher values of trajectory quality improve the higher mass
    dy accuracies.  The issue here is that these ions have small wave sizes
    in relation to array grid intervals.  To improve accuracy you need to
    either use a higher density array or turn up the trajectory quality to
    shrink the timesteps in trajectory curvature areas.


RF Square Wave Test:

A square wave RF is used between the two plates (in y).  A collection of ions
are given a small ke in x relatively close to one of the plates. Each ion
follows a wave-like trajectory.  The square wave will induce conservation of
energy problems unless the switch edge can be detected accurately and
automatically.

Preparation:

    Load rf_square_wave.pa# and refine to 1.0e-7
    Remove all PAs
    Load rf_square_wave.iob into View
    Click the Fly'm button

Discussion:

    The ions are flown 1/2 cycle (by default) and then killed.  The expected
    peak to peak dy (in mm) using a formal integration of the expected forces
    is compared to the dy obtained from the simulation.

    If you want the ions to keep on flying set the adjustable variable:
    Long_Simulation_if_1 to the value of 1.

    Note that 0 or negative value of trajectory quality cause considerable
    errors because of their fixed time step nature.

    Note that higher values of trajectory quality improve the higher mass
    dy accuracies.  The issue here is that these ions have small wave sizes
    in relation to array grid intervals.  To improve accuracy you need to
    either use a higher density array or turn up the trajectory quality to
    shrink the timesteps in trajectory curvature areas.

    Turn on data recording at each time step to verify that SIMION is indeed
    catching the edge of the RF square wave.
