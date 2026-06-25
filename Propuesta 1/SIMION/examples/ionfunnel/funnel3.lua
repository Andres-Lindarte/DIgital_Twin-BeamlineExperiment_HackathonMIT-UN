-- funnel3.lua - SIMION Lua workbench user program for ion funnel.
--
-- This is similar to funnel2.lua but uses additional electrode
-- solution arrays to allow adjustable variables (_RF_amplitude,
-- _DC_offset_1, _DC_offset_16, and _DC_offset_17) to be adjusted
-- during the Fly'm (without editing the .pa+ file and re-refining
-- the array).
--
-- D.Manura, 2009-08, based on funnel2.lua.

simion.workbench_program()

-- import standard HS1 collision model from this directory.
simion.import("collision_hs1.lua")

-- adjustable during flight
 
adjustable _temperature_k       = 273.0      -- Background gas temperature (K)
                                             --   [OVERRIDE HS1]
adjustable _sigma_m2            = 2.27E-18   -- Collision-cross section (m^2),
                                             --   from experiment
                                             --   [OVERRIDE HS1]
adjustable _gas_mass_amu        = 28.0       -- Mass of background gas particle
                                             --   (u), (N2 gas)
                                             --   [OVERRIDE HS1]
adjustable _mark_collisions     = 0          -- Mark collisions (1=yes,0=no).
                                             --   [OVERRIDE HS1]
adjustable pe_update_each_usec  = 0.05       -- PE display update period (in usec)

-- adjustable at beginning of flight

adjustable _freqency_hz         = 5E5        -- RF frequency of funnel (in Hz)
                                             --   CAREFUL: time-step sizes should
                                             --   be some fraction below period.
adjustable phase_angle_deg      = 0.0        -- entry phase angle of ion (deg)
adjustable _RF_amplitude        = 50         -- RF peak-to-ground voltage (in V)
adjustable _DC_offset_1         = 100.0      -- DC offset of electrode 1 (in V)
adjustable _DC_offset_16        = 68.0       -- DC offset of electrode 16 (in V)
adjustable _DC_offset_17        = 60.0       -- DC offset of electrode 17 (in V),
                                             --   DC only electrode
adjustable _pressure_pa         = 1.0*133.28 -- Pressure (in Pa)
                                             -- Note: 1 Torr = 133.28 Pa.
                                             --   [OVERRIDE HS1]

-- internal variables
local omega                 -- frequency in radians / usec
local theta                 -- phase offset in radians
local last_pe_update = 0.0  -- last potential energy surface update time (usec)

function segment.fast_adjust()
    -- NOTE: This segment is the only code that differs from funnel2.lua.

    -- Initialize constants once.
    if not theta then
        theta = phase_angle_deg * (3.141592 / 180)
        omega = _freqency_hz * 6.28318E-6
    end

    -- Apply RF+DC to each electrode (see README file for explanation).
    adj_elect01 = _RF_amplitude * sin(ion_time_of_flight * omega + theta)
    adj_elect02 = _DC_offset_1
    adj_elect03 = _DC_offset_16 - _DC_offset_1
    adj_elect04 = _DC_offset_17
end
      

-- This trick first runs the other_actions segment defined previously
-- by the HS1 collision model and then runs our own code.
local previous_other_actions = segment.other_actions  -- copy previously defined segment.
function segment.other_actions()
    -- Run previously defined segment.
    previous_other_actions()
    -- Now run our own code...

    -- Update PE surface display.
    if abs(ion_time_of_flight - last_pe_update) >= pe_update_each_usec then
        last_pe_update = ion_time_of_flight
        sim_update_pe_surface = 1    -- Request a PE surface display update.
    end
end
