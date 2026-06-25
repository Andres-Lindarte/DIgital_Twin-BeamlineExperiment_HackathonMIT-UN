;ion jump demo
;Dave Dahl

defa _extract_tube	 -20.0	 ;extraction tube voltage
defa _beam_tube 	  15.0	 ;primary beam tube voltage
defa _jump_radius_mm   4.0	 ;jump radius in mm



;seg init_p_values		 ;adjust values before flym
seg fast_adjust 		 ;adjust values during flym

   rcl _extract_tube
   sto adj_elect01		 ;set electrode 1 to extract tube value

   rcl _beam_tube
   sto adj_elect02		 ;set electrode 2 to beam tube value
   exit


seg other_actions
	rcl ion_px_mm entr *	  ;rx squared
	rcl ion_py_mm entr * +	  ;plus ry squared
	rcl ion_pz_mm entr * +	  ;plus rz squared
	sqrt					  ;radius from origin in mm
	rcl _jump_radius_mm 	  ;get jump radius
	x>y exit				  ;if less than jump radius exit

	rcl ion_pz_mm			  ;jump ion 22 mm in z
	22 +
	sto ion_pz_mm
	mark					  ;mark the jump
