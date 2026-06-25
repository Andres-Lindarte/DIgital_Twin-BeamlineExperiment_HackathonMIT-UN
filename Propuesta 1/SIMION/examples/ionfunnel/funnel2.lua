-- funnel2.lua - SIMION Lua workbench user program for ion funnel.
--
-- There are 16 electrodes in the funnel, plus a DC electrode at the end.
-- This program controls the voltages on those electrodes.
-- The electrodes are 0.5 mm thick and separated 0.5 mm, similar to [1+2].
-- The program incorporates an ion-neutral collision model
-- (SIMION HS1-collision model - collision_hs1.lua), which is
-- duplicated in this folder.
-- The collision cross section is m/z dependent.
--
-- WARINING: to you adjust DC and RF voltages in funnel2.iob, you will
-- need to both modify the adjustable variables in funnel2.lua and
-- modify the corresponding variables in funnel2.pa+ (and then
-- re-refine funnel2.pa#).  To avoid this inconvenience, see funnel3.iob.
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

-- Voltages used in .PA+ file.
-- WARNING: If you change any of the following voltage values,
-- you must change the corresponding values in the .pa+ file and re-refine.
-- The fast adjustment assumes these values were applied in the electrode
-- solution arrays.
-- If you wish to avoid this inconvenience, see the funnel3 example, which
-- utilizes additional electrode solution arrays to allow these to be
-- changed by fast adjustment.
local _RF_amplitude_orig   = 50         -- RF peak-to-ground voltage (in V), in .pa+ file
local _DC_offset_1         = 100.0      -- DC offset of electrode 1 (in V), in .pa+ file
local _DC_offset_16        = 68.0       -- DC offset of electrode 16 (in V), in .pa+ file

-- The following voltage CAN be adjusted without re-refining.
-- See the README for details why we can use this in the "rescaling value" below.
adjustable _RF_amplitude   = 50         -- RF peak-to-ground voltage (in V), actual value

adjustable _pressure_pa         = 1.0*133.28 -- Pressure (in Pa)
                                             -- Note: 1 Torr = 133.28 Pa.
                                             --   [OVERRIDE HS1]

-- internal variables
local omega                 -- frequency in radians / usec
local theta                 -- phase offset in radians
local last_pe_update = 0.0  -- last potential energy surface update time (usec)
local max1, max2            -- maximum (control) voltages for adjustable electrodes.

function segment.fast_adjust()
    -- Initialize constants once.
    if not theta then
        theta = phase_angle_deg * (3.141592 / 180)
        omega = _freqency_hz * 6.28318E-6
        local dcgradient = (_DC_offset_1 - _DC_offset_16) / 15;
        max1 = _DC_offset_1 + _RF_amplitude_orig
        max2 = _DC_offset_1 - dcgradient + _RF_amplitude_orig
    end

    local rescale = _RF_amplitude/_RF_amplitude_orig  -- RF rescaling value

    -- Apply RF+DC to each electrode (see README file for explanation).
    local sf = 0.5 + 0.5*rescale*sin(ion_time_of_flight * omega + theta)
    adj_elect01 = sf * max1
    adj_elect02 = (1 - sf) * max2
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
