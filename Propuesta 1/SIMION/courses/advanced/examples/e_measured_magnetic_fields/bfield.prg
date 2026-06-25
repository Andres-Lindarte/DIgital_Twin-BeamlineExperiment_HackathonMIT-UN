	;instance scaling 1 mm/gu

adefa bfield	1681	;"bfield.dat" holds bfield data
						; bx, by   840 points
						; bx, by   21x by 40 y	first point is 0,0
						; bx, by   scan lines in x then y  every 10 gu


seg mfield_adjust
	rcl ion_number 1 x=y exit  ;use pa B values if first ion

	0							;Assume fields are zero
	sto ion_bfieldx_gu
	sto ion_bfieldy_gu
	sto ion_bfieldz_gu
								;exit if ion beyond data array limits
	rcl ion_px_abs_gu  95 x<y exit	; 19 x 5 gu per data point
	rcl ion_py_abs_gu 190 x<y exit	; 38 x 5 gu per data point

	rcl ion_px_abs_gu 5 / sto x 	;convert into data array spacings
	int sto xint					;convert into int and frac components
	rcl x frac sto xfrac
	1 x<>y - sto xlfrac 			;1-xfrac

	rcl ion_py_abs_gu 5 / sto y 	;convert into data array spacings
	int sto yint					;convert into int and frac components
	rcl y frac sto yfrac
	1 x<>y - sto ylfrac 			;1-yfrac

	rcl yint 21 * rcl xint +		;offset to ll corner point
	2 * 1 + 						;bx,by	addressing + first index = 1
	sto llnbx						;index of ll corner of bx
	1 + sto llnby					;index of ll corner of by


	;calculate ion's bx field by linear interpolation

	rcl llnbx	   arcl bfield rcl xlfrac * rcl ylfrac *
	rcl llnbx 2 +  arcl bfield rcl xfrac  * rcl ylfrac * +
	rcl llnbx 42 + arcl bfield rcl xlfrac * rcl yfrac  * +
	rcl llnbx 44 + arcl bfield rcl xfrac  * rcl yfrac  * +
	sto ion_bfieldx_gu



	;calculate ion's by field by linear interpolation

	rcl llnby	   arcl bfield rcl xlfrac * rcl ylfrac *
	rcl llnby 2 +  arcl bfield rcl xfrac  * rcl ylfrac * +
	rcl llnby 42 + arcl bfield rcl xlfrac * rcl yfrac  * +
	rcl llnby 44 + arcl bfield rcl xfrac  * rcl yfrac  * +
	sto bfieldr

	rcl ion_pz_gu		;rcl ion's pz in gu
	rcl ion_py_gu		;rcl ion's py in gu
	>p					;convert to polar coords
	rlup				;roll pointer up
	rcl bfieldr 		;replace r with bfieldr
	>r					;convert back to rectangular coords
	sto ion_bfieldy_gu	;store bfield in y dir
	rlup				;roll pointer up
	sto ion_bfieldz_gu	;store bfield in z dir
	exit
