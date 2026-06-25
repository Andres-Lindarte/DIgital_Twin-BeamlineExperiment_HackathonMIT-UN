--   SIMION 8.0 equivalent of a SIMION 4.0 .AR? user program
--   based on D.A. DAHL 1994
-- 
--   area.pa has two parallel plate electrodes
--   one set to 100 volts and the other set to -100 volts
--   voltages in the potential array are totally ignored!!!
--   this efield_adjust seg defines an explicit rf field between the plates
simion.workbench_program()

adjustable omega = 1.0         -- angular velocity (rad/usec)
adjustable rf_voltage = 100.0  -- RF voltage

local xc = 22.5 -- x center position
local xr = 21.5 -- x radius, i.e. distance from left edge to center

-- SIMION efield_adjust segment.  Called to override potential/electric field.
-- start of efield_adjust program segment
function segment.efield_adjust()
    -- Calculate potential of left electrode.
    -- Note: TOF is in units of usec.
    local v_left = rf_voltage * sin(ion_time_of_flight * omega)

    -- Calculate gradient of potential.
    ion_dvoltsx_gu = -v_left / xr
    ion_dvoltsy_gu = 0
    ion_dvoltsz_gu = 0

    -- Calculate potential at current particle location.
    ion_volts = ion_dvoltsx_gu * (ion_px_gu - xc)
end

