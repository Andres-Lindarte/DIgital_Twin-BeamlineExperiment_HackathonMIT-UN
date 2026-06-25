-- collision_simple.lua - Simple collision model.
--
-- A very simple elastic ion-gas collision model.
-- For a more complex collision model, see the SIMION collision_hs1
-- example.
--
-- D.Manura-2006-08 - based on PRG code from SIMION 7.0 - David A. Dahl 1995
-- (c) 2006 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)


-- collision damping (if enabled)
adjustable _gas_mass_amu        = 4.0    -- mass in amu (helium=4)
adjustable _mean_free_path_mm   = 4.0    -- mean free path in mm

local SIMPLE = {}
SIMPLE.segment = {}

-- SIMION other_action code, called on every time step.
function SIMPLE.segment.other_actions()
    -- Get particle speed v.
    local v, az, el = rect3d_to_polar3d(ion_vx_mm, ion_vy_mm, ion_vz_mm)     
    -- Compute distance step (distance traveled in time-step) in mm
    local distance_step = v * ion_time_step

    -- Detect collision.
    -- This uses a probability of collision by comparing the
    -- distance step to the mean-free-path.
    if rand() <= 1 - exp(- distance_step / _mean_free_path_mm) then
        -- Optionally mark where collision occurs.
        -- mark()

        -- Attenuate velocity, ASSUMING direct hit on resting gas molecule.
        v = v * (ion_mass - _gas_mass_amu) / (ion_mass + _gas_mass_amu)
        -- Convert back to rectangular coordinates and save.
        ion_vx_mm, ion_vy_mm, ion_vz_mm = polar3d_to_rect3d(v, az, el)
    end
end

return SIMPLE
