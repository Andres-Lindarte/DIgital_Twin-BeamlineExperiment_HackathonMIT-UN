;rf mirror energy conservation test

defa  RF_delay				20.0	;delay before start
defa  RF_voltage			30		;volts
defa  RF_frequency			1.4e5	;140,000 cps
defa  max_RF_fraction_step	0.001	;max time step as a fraction of rf period
defa  PE_Update_step		3.0e-1	;update each .3 usec

defs  pe_time				0.0 	;time for next pe surface update
defs  ypeak 				0.0 	;peak to peak y in mm

defs  rf_period 			0.0 	;period of one cycle
defs  stop_time 			0.0 	;time to stop (one cycle)

adefa first_flag			1		;first pass flag for banner display
adefa next_flag 			1		;next ion flag flag for banner display


seg initialize
							;exit if banner already shown
	1 arcl first_flag x!=0 exit
							;display simulation banner
	message ;RF jagger conservation of energy test
	1 1 asto first_flag 	;set flag to prevent displaying again
	exit


seg tstep_adjust
	rcl rf_frequency 1.0e6 / 1/x	;cycle time in usec
	sto rf_period					;remember rf period
	rcl rf_delay + sto stop_time	;stop time in usec

	rcl rf_delay
	rcl ion_time_of_flight
	x>=y goto end_check 		;skip if already beyond rf_delay
	rcl ion_time_step +
	rcl rf_delay
	x>=y exit					;exit if will be less than rf_delay
	rcl ion_time_of_flight -
	sto ion_time_step			;force time step to match rf_delay time exactly
	exit

	lbl end_check
	rcl stop_time
	rcl ion_time_of_flight
	x>=y exit					;exit if already beyond stop time

	rcl ion_time_step
	rcl rf_period
	rcl max_rf_fraction_step *
	x<y sto ion_time_step		;keep time step less than period fraction limit

	rcl ion_time_of_flight
	rcl ion_time_step +
	rcl stop_time
	x>=y exit					;exit if will be less than stop time
	rcl ion_time_of_flight -
	sto ion_time_step			;force time step to match stop_time exactly


	exit


seg fast_adjust
	0					   ;pre zero potentials
	sto adj_elect01 	   ;store as electrode 1
	sto adj_elect02 	   ;store in electrode 2
							;compute potential to use
	rcl rf_delay
	rcl ion_time_of_flight
	x<y exit				;exit if within rf_delay

	rcl stop_time
	rcl ion_time_of_flight
	x>y exit				;exit if beyond stop time

	rcl ion_time_of_flight rcl rf_delay -
	rcl RF_frequency 1.0e6 /  360 >rad * * sin

	rcl RF_voltage *

	sto adj_elect01 	   ;store as electrode 1
	chs
	sto adj_elect02 	   ;store -1 * value in electrode 2
	exit



seg other_actions

	1 arcl next_flag x!=0 goto next0
	1 sto Update_PE_surface ;set pe surface update flag
	1 1 asto next_flag		;set flag to prevent displaying again
	goto next

	lbl next0

	rcl rf_delay			;skip surface update if before rf
	rcl ion_time_of_flight
	x<y goto next

	rcl stop_time			;skip surface update if after rf
	rcl ion_time_of_flight
	x>y goto next

	rcl pe_time 			;get next pe update time
	rcl ion_time_of_flight	;get current time of flight
	x<y goto next			;skip to next if pe update not needed
							;save next time to update pe surface
	rcl ion_time_of_flight rcl PE_Update_step + sto pe_time
	1 sto Update_PE_surface ;set pe surface update flag

	lbl next				;skip pe update entry
	rcl ion_splat x=0 goto next1
	rcl ion_py_mm
	message ; dy (at ion splat) = # mm (SIMION)
	exit

	lbl next1
	rcl rf_delay
	rcl ion_time_of_flight
	x=y mark				;mark start time
	rcl stop_time
	rcl ion_time_of_flight
	x!=y exit
	x=y mark				;mark stop time
	rcl ion_py_mm sto ypeak

	message ;
	rcl ion_mass			;display ion's mass
	message ; ion mass			= # amu
							;compute and display expected ypeak value
	rcl RF_voltage rcl ion_mass /
	rcl RF_frequency 1/x 2 / entr * *
	2 * 3.141592654 /		 ;fraction of square wave effect
	2.41213271e12 * 		 ;d = peak to peak y estimate
							;d = 2.41213271e12 * 2 * rf_voltage * (t^2) /(ion_mass * pi)
							;t = 1/(2 * rf_frequency)
	message ; dy (at stop time) = # mm (expected from theory)

	rcl ypeak				;display peak to peak y from simulation
	message ; dy (at stop time) = # mm (SIMION)
	exit
