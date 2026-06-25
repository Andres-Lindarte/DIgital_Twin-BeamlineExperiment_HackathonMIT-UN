defa gauss 10000		;default to a 1 tesla field

adefa vt 100			;array for holding initial speed of ions
defs dx 0				;holds max dx orbital diameter value (start at zero)

seg initialize
						;skip if not ion number one
rcl ion_number 1 x!=y goto skip
						;display banner message
Message ;Orbit Diameters in Magnetic Fields
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


seg mfield_adjust		;used to set magnetic field

0
sto ion_bfieldx_gu		;zero magnetic field in x and y directions
sto ion_bfieldy_gu
rcl gauss				;get user requested B field in gauss
sto ion_bfieldz_gu		;store in z direction
exit


seg other_actions
						;compute abs of current delta x
						;save as dx if greated than current dx
rcl dx rcl ion_px_mm abs x>y sto dx
x>=y exit				;exit if haven't reached xmax yet

rcl ion_mass			;get ion's mass
rcl ion_number			;index to array by ion number
arcl vt *				;get ion's initial speed
rcl gauss / 			;get B field
1.03642722e2 *		   ;r = 1.03642722e2 * mass * vt / gauss
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
1 rcl ion_mass rcl rel_factor *
rcl gauss / 6.5120643e-4 * /
message ;orbital frequency = # 1/sec (expected)
						;display orbital frequency from simulation
1 rcl ion_time_of_flight 2 * / 1.0e6 *
message ;orbital frequency = # 1/sec (SIMION)
message ;
-3 sto ion_splat		;kill ion
