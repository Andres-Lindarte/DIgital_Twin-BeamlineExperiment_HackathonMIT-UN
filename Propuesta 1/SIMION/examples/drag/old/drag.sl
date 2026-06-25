#=======================================================================
# drag.sl - Stokes' law viscosity damping on ion trajectories
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
#           Based on DRAG.PRG example in SIMION 7.0 (D.Dahl).
#
#=======================================================================

#===== variables

adjustable damping = 0     # damping factor

#===== subroutines

# Modify ion accerations.
sub accel_adjust
    if ion_time_step == 0 or damping == 0
        exit
    endif

    # Restrict user input: damping >= 0.
    damping = abs(damping)

    # apply stokes' damping
    t_term = damping * ion_time_step
    factor = (1 - exp(-t_term)) / t_term
    ion_ax_mm = (ion_ax_mm - ion_vx_mm * damping) * factor
    ion_ay_mm = (ion_ay_mm - ion_vy_mm * damping) * factor 
    ion_az_mm = (ion_az_mm - ion_vz_mm * damping) * factor
endsub
