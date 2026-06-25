seg other_actions

rcl ion_splat x=0 exit			;exit if ion hasn't splatted
1 rcl ion_mass x>y goto ions	;jump if proton
								;else output relativistic electron data
	message ;Relativistic ke -> v Test
	message ;An electron with ke = its rest mass
								;relativistic velocity from
								; 2 = 1/(sqrt(1 - v*v/c*c))
	message ; v   =  c * sqrt(0.75)
								; given c = 2.99792458e+005 mm/usec
	message ; v   =  2.59627884e+005 mm/usec (expected)
	rcl ion_vx_mm				; velocity at splat
	message ; v   = # mm/usec (SIMION)

								; rest mass of electron
								; and starting ke
	message ; ke  =  5.1099906 e+005 eV (rest mass ke)
	rcl ion_mass				; get mass of electron
	rcl ion_vx_mm				; get its exit velocity
	>ke 						; convert back to ke as check
	message ; ke  = # eV (SIMION v >KE fn)

								;equation for const velocity tof
	message ; tof =  1000mm / v ;array and workbench 1000mm long

								;tof assuming expected velocity
	message ; tof =  3.85166641e-003 usec (expected)
	rcl ion_time_of_flight		;tof computed by SIMION
	message ; tof = # usec (SIMION)
	message ;
	exit

lbl ions						;proton data output
message ;Non-Relativistic ke -> v Test
message ;A proton with ke = 1eV
message ; v   =  sqrt(2 * ke/m)
		; v   =  sqrt(2.0 * 1.60217733e-19/1.6726231e-27)
					;where			 1eV = 1.60217733e-19 J
					;	   proton's mass = 1.6726231e-27 kg
message ; v   =  1.38411203e+001 mm/usec (expected)
rcl ion_vx_mm					; velocity at splat
message ; v   = # mm/usec (SIMION)
								; defined initial ke
message ; ke  =  1.0000000 e+000 eV (defined ke)
rcl ion_mass					; get mass of proton
rcl ion_vx_mm					; get its exit velocity
>ke 							; convert back to ke as check
message ; ke  = # eV (SIMION v >KE fn)

								;equation for const velocity tof
message ; tof =  1000mm / v 	;array and workbench 1000mm long
								;tof assuming expected velocity
message ; tof =  7.22484869e+001 usec (expected)
rcl ion_time_of_flight			;tof computed by SIMION
message ; tof = # usec (SIMION)
exit
