--   SIMION 8.0 equivalent of a SIMION 4.0 .FAC user program
--   based on D.A. DAHL 1994. Lua-D.Manura2006-08
--
--   factor.pa has two parallel plate electrodes
--   one set to 100 volts and the other set to -100 volts
--   this efield_adjust program modulates the field
simion.workbench_program()

adjustable omega = 1.0  -- angular velocity (rad/usec)

-- SIMION efield_adjust segment.  Called to override electric potential/field.
function segment.efield_adjust()
    -- Compute oscillating factor in [-1, -1].
    local factor = sin(ion_time_of_flight * omega)

    -- Multiply voltage and field by this factor.
    ion_volts      = factor * ion_volts
    ion_dvoltsx_gu = factor * ion_dvoltsx_gu
    ion_dvoltsy_gu = factor * ion_dvoltsy_gu
    ion_dvoltsz_gu = factor * ion_dvoltsz_gu
end
