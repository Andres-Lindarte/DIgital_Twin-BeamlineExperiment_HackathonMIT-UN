; demo of the addition of stokes' law damping to ion trajectories
; this is coupled with a simple three element lens for demonstration
; purposes (see Appendix I for more information)
 
defa Linear_Damping 0               ; adjustable variable for linear damping
 
 
seg accel_adjust                    ; beginning of accel_adjust segment
 
    rcl ion_time_step x=0 exit      ; exit if zero time step
    rcl linear_damping x=0 exit     ; exit if damping set to zero
    abs sto damping                 ; force damping term to be positive
    * sto tterm                     ; compute and save number of time constants
    chs e^x 1 x><y -                ; (1 - e^(-(t * damping)))
    rcl tterm / sto factor          ; factor = (1 - e^(-(t * damping)))/(t * damping)
 
    rcl ion_ax_mm                   ; recall ax acceleration
    rcl ion_vx_mm                   ; recall vx velocity
    rcl damping * -                 ; multiply times damping and sub from ax
    rcl factor *                    ; multiply times factor
    sto ion_ax_mm                   ; store as new ax acceleration
 
    rcl ion_ay_mm                   ; recall ay acceleration
    rcl ion_vy_mm                   ; recall vy velocity
    rcl damping * -                 ; multiply times damping and sub from ay
    rcl factor *                    ; multiply times factor
    sto ion_ay_mm                   ; store as new ay acceleration
 
    rcl ion_az_mm                   ; recall az acceleration
    rcl ion_vz_mm                   ; recall vz velocity
    rcl damping * -                 ; multiply times damping and sub from az
    rcl factor *                    ; multiply times factor
    sto ion_az_mm                   ; store as new az acceleration
