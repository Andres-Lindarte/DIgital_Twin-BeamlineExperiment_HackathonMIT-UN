;used to kick ions into non-ideal grid simulation volume

defa _Ideal_grid_if_not_zero 0	;used to create ideal grid run if != 0

defs xshift_mm 0	; xoffset to return from non-ideal grid volume
defs zshift_mm 0	; zoffset to return from non-ideal grid volume

seg other_actions	; jumps ions into non-ideal grid volume

rcl _ideal_grid_if_not_zero x!=0 exit	;exit if using ideal grid


rcl ion_px_mm							;get ion's x position
	25.4 /								;convert ion's x pos to inches
	0.040 / 							;number of 0.040" steps
	nint								;convert steps to nearest integer
	0.040 * 							;convert back to inches
	25.4 *								;convert back to mm
	70.5 + sto xshift_mm				;add default x shift an save xshift_mm


rcl ion_pz_mm							;get ion's z position
	25.4 /								;convert ion's z pos to inches
	0.040 / 							;number of 0.040" steps
	nint								;convert steps to nearest integer
	0.040 * 							;convert back to inches
	25.4 *								;convert back to mm
	sto zshift_mm						;save as zshift_mm



   rcl ion_px_mm
   rcl xshift_mm
   - sto ion_px_mm						;jump ion in x into grid volume

   rcl ion_pz_mm
   rcl zshift_mm
   - sto ion_pz_mm						;jump ion in z into grid volume

exit
