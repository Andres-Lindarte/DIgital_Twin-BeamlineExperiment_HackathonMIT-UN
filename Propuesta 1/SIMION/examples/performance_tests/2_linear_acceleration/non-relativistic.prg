
seg initialize
message ;Non-Relativistic Proton Acceleration
message ;Initial ke = 20 eV in -y direction
message ;Acceleration in x direction
message ;ke gain in x direction will be 50 eV
Message ;
rcl ion_vy_mm
rcl ion_vx_mm
>P
rcl ion_mass
x<>y
>KE
message ;starting speed(vx=0, vy=) -> ke = # eV
exit

seg other_actions
rcl ion_splat x=0 exit
message ;
message ;Expected TOF with linear Acceleration
message ;TOF = 2 * s / v  ; where
message ;	s  = acceleration length (50mm)
message ;	v  = final velocity (measured)
rcl ion_vx_mm
message ;	vx = # mm/usec (measured)
100 rcl ion_vx_mm / abs
message ;TOF at splat # usec (EXPECTED)
rcl ion_time_of_flight
message ;TOF at splat # usec (SIMION)
message ;
rcl ion_vy_mm
rcl ion_vx_mm
>P
rcl ion_mass
x<>y
>KE
message ;Ending speed(vx & vy) -> ke = # eV
exit
