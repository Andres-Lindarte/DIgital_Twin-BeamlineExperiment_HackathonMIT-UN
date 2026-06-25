-- funnel.lua - SIMION Lua workbench user program for ion funnel.
--
-- There are 16 electrodes in the funnel, plus a DC electrode at the end.
-- This program controls the voltages on those electrodes.
-- The electrodes are 0.5 mm thick and separated 0.5 mm, similar to [1+2].
-- The program incorporates an ion-neutral collision model
-- (SIMION HS1-collision model - collision_hs1.lua), which is
-- duplicated in this folder.
-- The collision cross section is m/z dependent.
--
-- [1] Belov, M. E. et.al. JASMS 2000, 11,19.
--   http://dx.doi.org/10.1016/S1044-0305(99)00121-X
-- [2] Kim, T. et. al. AC 2000, 72,2247. http://dx.doi.org/10.1021/ac991412x
--   [see also: http://citeseer.ist.psu.edu/397575.html ]
--
-- Yehia Ibrahim, PNNL 2007 - Adapted from SIMION 8 quadrupole example.
-- D.Manura-2007-03 - refactored.

simion.workbench_program()

-- import standard HS1 collision model from this directory.
simion.import("collision_hs1.lua")

-- adjustable variables during flight
 
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

-- adjustable variables at beginning of flight

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
local dcgradient            -- DC gradient through the funnel

function segment.fast_adjust()
    -- Initialize constants once.
    if not theta then
        theta = phase_angle_deg * (3.141592 / 180)
        omega = _freqency_hz * 6.28318E-6
        dcgradient = (_DC_offset_1 - _DC_offset_16) / 15
    end

    -- Apply RF+DC to each electrode.
    local rfvolts = sin(ion_time_of_flight * omega + theta) * _RF_amplitude
    local dcvolts = _DC_offset_1
    for n=1,16 do
       adj_elect[n] = dcvolts + rfvolts
       rfvolts = -rfvolts
       dcvolts = dcvolts - dcgradient
    end
    adj_elect17 = _DC_offset_17  -- DC only plate with no RF applied (Y.I.)
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

