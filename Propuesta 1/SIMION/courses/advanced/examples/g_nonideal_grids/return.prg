;returns ions from non-ideal grid volume to simulation volume

defs xshift_mm 0	;holds the x offset needed to return to simulation
defs zshift_mm 0	;holds the z offset needed to return to simulation

seg other_actions	;returns ions to simulation volume

   rcl ion_px_mm
   rcl xshift_mm
   + sto ion_px_mm	;shift ion in x back into simulation volume

   rcl ion_pz_mm
   rcl zshift_mm
   + sto ion_pz_mm	;shift ion in z back into simulation volume

exit
