;  dv = k ln (r2/r1)
;	where:
;		dv = 1000 volts
;		r1 = 200 mm
;		r2 = 400 mm
;  k = dv/ln(r2/r1) = 1.442695041e3
;  expected Vgradient(at r = 300) = k/r = 4.80898347 volts/mm
;  expected potential(at r = 300) = 1000 + k ln (300/200)
;								  = 1.584962501e+003 volts
;  Required ke (non-relativistic) for radius of refraction of 300 mm
;  r = 2 * ke(eV) / V/mm
;  ke = r * V/mm / 2 = 300 * 4.80898347 / 2
;	  = 7.213475204e2 eV

Adefa k 1		; define a single element array

seg initialize

	rcl ion_number 1 x!=y exit	;single pass for first ion

	1000 2 ln / 1 asto k   ;compute k(1)
	message ;Radius of curvature verses PA size test
	message ;Expected Radius	= 3.00000000e+002 mm
	message ;Expected Potential = 1.58496250e+003 volts
	message ;Expected Gradient	= 4.80898347e+000 volts/mm
	message ;
	message ; Ion 1 flown with array fields
	message ; Ion 2 flown with analytical fields
	message ;

seg efield_adjust
	rcl ion_number 1 x=y exit	; use array's fields for ion 1
								; use analytical fields for ion 2
	rcl ion_py_mm
	rcl ion_px_mm
	>p							; convert ion's velocity into polor coords
	sto r						; save vr
	rlup sto angle				; save vangle

								;compute analytical potential at r
	rcl r 200 / ln 1 arcl k * 1000 + sto Ion_volts
	1 arcl k rcl r / sto dv 	;analytical potential gradient at r
	rcl angle >rad sto angle	;convert angle to radians
	rcl angle					;compute and store the z gradient component
	cos rcl dv * rcl ion_mm_per_grid_unit * sto ion_dvoltsz_gu
	rcl angle					;compute and store the y gradient component
	sin rcl dv * rcl ion_mm_per_grid_unit * sto ion_dvoltsy_gu


	exit

