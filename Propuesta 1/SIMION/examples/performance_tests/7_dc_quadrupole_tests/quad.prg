;  Potential = 0.1 * (x * x - y * y)
;  dVx		 = 0.2 * x
;  dVy		 = -0.2 * y
;  where:
;		Potential is in volts
;		x and y are in mm
;		dVx = Volts/mm
;		dVy = Volts/mm


seg initialize

	1 rcl ion_number x!=y exit
	message ;Ion Motions in Static Quadrupole Field test
	message ;Ions 1,2,3 flown in array's field
	message ;Ions 4,5,6 flown in analytical field
	message ;For Ions 1 and 4  ke = 500eV
	message ;Expected x reversal  = 7.071067812e+001 mm
	message ;For Ions 2 and 5  ke = 250eV
	message ;Expected x reversal  = 5.000000000e+001 mm
	message ;For Ions 3 and 6  ke = 62.5eV
	message ;Expected x reversal  = 2.500000000e+001 mm
	message ;For All Ions
	message ;Expected TOF(1/4cyc) = 6.193482464e+000  usec
	message ;

seg efield_adjust
	3 rcl ion_number x<=y exit

	rcl ion_px_mm entr *
	rcl ion_py_mm entr * -
	10 / sto ion_volts
	rcl ion_px_mm 0.2 * rcl ion_mm_per_grid_unit * sto ion_dvoltsx_gu
	rcl ion_py_mm -0.2 * rcl ion_mm_per_grid_unit * sto ion_dvoltsy_gu

	exit
