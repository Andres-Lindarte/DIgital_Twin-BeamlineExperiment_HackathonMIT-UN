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

seg initialize

	message ;Radius of curvature verses PA size test
	message ;Expected Radius	= 3.00000000e+002 mm
	message ;Expected Potential = 1.58496250e+003 volts
	message ;Expected Gradient	= 4.80898347e+000 volts/mm
	message ;
