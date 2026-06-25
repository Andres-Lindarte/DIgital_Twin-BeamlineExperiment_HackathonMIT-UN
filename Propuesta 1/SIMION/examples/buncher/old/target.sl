#=======================================================================
# target.sl - Calculations at the target electrode of the Buncher lens.
#
# This program computes a measure of the dispersion of ions hitting
# the target electrode.  Since the ions have been focused by the
# Buncher lens, we expect the dispersion to be small.
#
# Upon compilation, this SL program can be used as an near exact
# replacement for the TARGET.PRG program in the _Buncher example of
# SIMION 7.0.
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
#           Based on the TARGET.PRG example in SIMION 7.0.
# $Revision$ $Date$
#=======================================================================

#===== variables

adjustable first_ion = 0        # flag for first ion
adjustable max_time  = 0        # holds max tof
adjustable min_time  = 0        # holds min tof

#===== subroutines

# Calculate and display results and the end of simulation.
sub terminate
    # no printing for first ion
    if first_ion == 0
        first_ion = 1                # flag first ion
        max_time = ion_time_of_flight
        min_time = ion_time_of_flight
    else
        # compute if not first ion
        max_time = max(ion_time_of_flight, max_time)
        min_time = min(ion_time_of_flight, min_time)

        print("Avg TOF = # Delta TOF = # usec",
            (max_time + min_time)/2, max_time - min_time)
    endif
endsub