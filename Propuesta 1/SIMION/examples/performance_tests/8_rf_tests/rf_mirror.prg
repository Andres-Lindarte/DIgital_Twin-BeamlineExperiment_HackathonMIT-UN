;rf mirror energy conservation test

defa  RF_voltage			100 	;volts
defa  RF_frequency			1.4e5	;140,000 cps
defa  PE_Update_step		3.0e-1	;update each .3 usec
defa  Long_Simulation_if_1	0.0 	;use short simulation if not 1

defs  pe_time				0.0 	;time for next pe surface update
defs  ypeak 				0.0 	;peak to peak y in mm
defs  del_tof				0.0 	;time for 3/4 of a cycle
defs  next_tof				0.0 	;time to start looking for next peak

adefs show_flag 			100 	;data has been shown for each ion flag (1)
adefa first_flag			1		;first pass flag for banner display


seg initialize
							;exit if banner already shown
	1 arcl first_flag x!=0 exit
							;display simulation banner
	message ;RF mirroring conservation of energy test
	1 1 asto first_flag 	;set flag to prevent displaying again
	exit


seg fast_adjust
							;compute potential to use
	rcl ion_time_of_flight
	rcl RF_frequency 1.0e6 /  360 >rad * * cos

	rcl RF_voltage *

	sto adj_elect01 	   ;store as electrode 1
	chs
	sto adj_elect02 	   ;store -1 * value in electrode 2
	exit



seg other_actions
	rcl pe_time 			;get next pe update time
	rcl ion_time_of_flight	;get current time of flight
	x<y goto next			;skip to next if pe update not needed
							;save next time to update pe surface
	rcl pe_time rcl PE_Update_step + sto pe_time
	1 sto Update_PE_surface ;set pe surface update flag

	lbl next				;skip pe update entry
							;jump if still looking for first peak
	rcl ion_number arcl show_flag x=0 goto first_pass
							;don't look for peak until 3/4 through cycle
	rcl next_tof rcl ion_time_of_flight x<y exit
							;update ypeak as necessary
	rcl ypeak rcl ion_py_mm x>y sto ypeak
	x>y exit				;exit if not past next peak
							;just past next peak
	rcl ypeak				;display peak to peak y
	message ; dy (peak to peak) = # mm (SIMION)
							;save time to start looking for next peak
	rcl ion_time_of_flight rcl del_tof + sto next_tof
	0 sto ypeak 			;reset peak to peak y

	exit


  lbl first_pass			;still looking for first peak
							;update ypeak as necessary
	rcl ypeak rcl ion_py_mm x>y sto ypeak
							;exit if not past first peak
	x>y exit

	message ;
	rcl ion_mass			;display ion's mass
	message ; ion mass			= # amu
							;compute and display expected ypeak value
	rcl RF_voltage rcl ion_mass /
	rcl RF_frequency 360 >rad * entr * /
	2.41213271e12 * 2 * 	;d = peak to peak y estimate
							;d = 2 * r
							;r = 2.41213271e12 * rf_voltage /(ion_mass * w^2)
							;w = rf_frequency * radians/cycle
	message ; dy (peak to peak) = # mm (expected)

	rcl ypeak				;display peak to peak y from simulation
	message ; dy (peak to peak) = # mm (SIMION)
							;set the first peak shown flag for ion
	1 rcl ion_number asto show_flag
							;3/4 cycle
	rcl ion_time_of_flight 1.5 * sto del_tof
							;start looking for peak 3/4 cycle from now
	rcl ion_time_of_flight rcl del_tof + sto next_tof
	0 sto ypeak 			;reset the peak to peak y value
							;exit if this is a long simulation
	rcl Long_Simulation_if_1 x!=0 exit
	-3 sto ion_splat		;else kill ion to truncate simulation
	exit
