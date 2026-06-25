adefa xv 50 				;ion's starting x velocity array
adefa x1 50 				;ion's starting x position array

seg initialize
rcl ion_number 1 x<y exit	;exit if not ion number 1
message ;Test for Conservation of Energy
message ;for ions in reflection fields and
message ;when crossing discontinuities
message ;
rcl ion_vx_mm
rcl ion_number				;array index
asto xv 					;save ion's starting x velocity
rcl ion_px_mm
rcl ion_number				;array index
asto x1 					;save ion's starting x position

seg terminate
rcl ion_number 1 x<y exit	;exit if not ion number 1
message ;
rcl ion_px_mm				;x value at splat (xlast)
rcl ion_number				;array index
arcl x1 -					;dx
rcl ion_number				;array index
arcl xv /					;expected tof = (xlast[1] - x1[1])/xv
message ; tof = # usec (Expected)

rcl ion_time_of_flight		;display computed time of flight
message ; tof = # usec (SIMION)
