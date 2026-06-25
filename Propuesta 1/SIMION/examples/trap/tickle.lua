-- tickle.lua - ion trap demo program with tickle voltage
--
-- D.Manura-2006-08 - based on PRG code from SIMION 7.0 - David A. Dahl 1995
-- (c) 2006 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--=======================================================================
simion.workbench_program()

print "NOTE: Before use, set TQual = 0, enable "
print "Grouped flying, set Repulsion to None, and"
print "enable Dots flying at maximum speed (use slider)."

local TRAP = simion.import("traputil.lua")
local SIMPLE = simion.import("collision_simple.lua")

-- override adjustables from traputil.lua
adjustable _qz_tune             = 0.84
adjustable _amu_mass_per_charge = 50.0

-- tickle parameters (adjustable during flight)
adjustable _tickle_voltage      = 0.0      -- tickle voltage
adjustable _tickle_frequency    = 544.0e3  -- tickle frequency in hz

local tickle = 0  -- saved last used tickle voltage

local tickle_segment = {}

-- SIMION fast_adjust segment.
-- This segment is called to modify electrode voltages. 
function tickle_segment.fast_adjust()
    -- Set left end cap voltage for tickle.
    tickle = _tickle_voltage *
             sin(_tickle_frequency * 6.28318E-6 * ion_time_of_flight)
    adj_elect01 = tickle
end

-- SIMION other_actions segment.
-- This segment is called on each time-step.
local RED  = 1
local BLUE = 3
function tickle_segment.other_actions()
    -- Display ion color according to polarity of tickle.
    if tickle < 0 then
        ion_color = RED
    else
        ion_color = BLUE
    end
end

TRAP.install_segments {
    TRAP.segment,
    SIMPLE.segment,
    tickle_segment
}
