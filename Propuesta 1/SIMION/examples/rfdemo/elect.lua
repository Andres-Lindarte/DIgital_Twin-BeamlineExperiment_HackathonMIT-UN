--   SIMION 8.0 equivalent of a SIMION 4.0 .ELE user program
--   Based on D.A. DAHL 1994. D.Manura-200608-Lua version.
--
--   elect.pa0 has two parallel plate electrodes
--   this fast_adjust segment creates a simple RF field between
--   the plates using dynamic fast adjust
simion.workbench_program()
 
adjustable omega = 1.0                -- angular velocity (rad/usec)
adjustable rf_voltage = 100.0         -- RF voltage
adjustable pe_update_each_usec = 0.3  -- PE display update time step (usec)

-- SIMION fast_adjust segment.  Called to override electrode potentials.
function segment.fast_adjust()
   -- Set electrode voltages.
   adj_elect01 = rf_voltage * sin(Ion_Time_of_Flight * omega)
   adj_elect02 = -adj_elect01
end

-- SIMION other_actions segment. Called on each time-step.
local next_pe_update = 0   -- next time to update PE surface display (usec)
function segment.other_actions()
    -- Note: the following is optional and is only for display purposes.

    -- Trigger PE surface display updates.
    -- If TOF reached next PE display update time...
    if ion_time_of_flight >= next_pe_update then
        -- Request a PE surface display update.
        sim_update_pe_surface = 1
        -- Compute next PE display update time (usec).
        next_pe_update = ion_time_of_flight + pe_update_each_usec
    end
end
