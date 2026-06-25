defa volts_per_mm 40000
; diameter(mm) = 2.07285444 e-2 m(amu) v(mm/usec)^2 / E(V/mm)
; orbit diameter of 0.51099906 Mev electron should be 3.822725116 mm

adefa vt 100			;array for holding initial speed of ions
defs dx 0				;holds max dx orbital diameter value (start at zero)

seg initialize
						;skip if not ion number one
rcl ion_number 1 x!=y goto skip
						;display banner message
Message ;Orbit Diameters in Electrostatic Fields
message ;A collection of relativistic and
message ;non-relativistic ions
message ;

lbl skip				;resume from skip
						;compute ion's speed
rcl ion_vx_mm entr *
rcl ion_vy_mm entr * + sqrt

rcl ion_number			;index to ion's number
asto vt 				;store in speed array
exit


seg efield_adjust		;create radial electrostatic field
rcl ion_vy_mm
rcl ion_vx_mm
>P						;convert ion's current velocity to polar coordinates
rlup 90 +				;add 90 degrees to angle (for radial field)
rcl volts_per_mm		;get voltage gradient to use
>R						;convert voltage gradient into x and y components
sto ion_dvoltsx_gu		;pass x voltage gradient back to simion
rlup					;point to y voltage gradient
sto ion_dvoltsy_gu		;pass y voltage gradient back to simion
0						;use 0 for z voltage gradient
sto ion_dvoltsz_gu
exit


seg other_actions
						;compute abs of current delta x
						;save as dx if greated than current dx
rcl dx rcl ion_px_mm abs x>y sto dx
x>=y exit				;exit if haven't reached xmax yet

rcl ion_mass			;get ion's mass
rcl ion_number			;index to array by ion number
arcl vt entr * *		;get ion's initial speed squared
rcl volts_per_mm /		;get E field
1.03642722e-2 * 		;r = 1.03642722e-2 * mass(amu) * (vt(mm/usec)^2) / E(v/mm)
2 * 					;d = 2 * r

1 1 rcl ion_number arcl vt entr *
2.99792458e5 entr * / - sqrt /
sto rel_factor			;rel_factor = 1/sqrt(1 - (v*v)/(c*c))
*						;drel = rel_factor * d
sto diameter			;save relativistically corrected diameter

rcl ion_mass			;display ion mass
message ;ion mass		   = # amu
						;convert mass and vt to KE and display
rcl ion_number arcl vt >KE
message ;ion ke 		   = # eV
rcl ion_charge			;display ion charge
message ;ion charge 	   = # e
						;display ion's starting speed
rcl ion_number arcl vt
message ;ion velocity	   = # mm/usec
						;display ion's relativity factor
rcl rel_factor
message ;relativity factor = #
rcl diameter			;display expected orbit diameter
message ;orbit diameter    = # mm (expected)
rcl dx					;display orbit diameter from simulation
message ;orbit diameter    = # mm (SIMION)
						;display orbital frequency expected
rcl ion_number arcl vt rcl diameter 3.141592654 * / 1.0e6 *
message ;orbital frequency = # 1/sec (expected)
						;display orbital frequency from simulation
1 rcl ion_time_of_flight 2 * / 1.0e6 *
message ;orbital frequency = # 1/sec (SIMION)
message ;
-3 sto ion_splat		;kill ion
