
seg initialize
message ;Relativistic Electron Linear Acceleration
message ;Initial ke = 0 eV in x direction
message ;Acceleration in x direction
message ;ke gain will be one electron rest mass in x
message ;ke gain in x direction will be 501,999.06 eV
Message ;
rcl ion_vy_mm
rcl ion_vx_mm
>P
rcl ion_mass
x<>y
>KE
message ;starting speed(vx=0) -> ke = # eV
exit

seg other_actions
rcl ion_splat x=0 exit
message ;
message ;Expected Final Velocity linear Acceleration
message ; v = c * sqrt(0.75) ; where
message ;	  c  = 299792.458 mm/usec (speed of light)
0.75 sqrt 299792.458 *
message ; v =  # mm/usec (EXPECTED)
rcl ion_vx_mm
message ; v =  # mm/usec (SIMION)
message ;
rcl ion_vy_mm
rcl ion_vx_mm
>P
rcl ion_mass
x<>y
>KE
message ;Ending speed(vx & vy) -> ke = # eV
exit
