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
