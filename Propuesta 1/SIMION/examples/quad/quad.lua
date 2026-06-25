--[[
 SIMION Lua workbench program for quadrupole simulation.
 This oscillates quadrupole rod potentials
 (and also updates PE display periodically).

 D.Dahl. D.Manura-2012-08-06/2006-08
 (c) 2006-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
 --]]

simion.workbench_program()

-- Variables adjustable during flight:
 
adjustable _percent_tune          =    97.0  -- percent of optimum tune.
                                             -- (typically just under 100)
adjustable _amu_mass_per_charge   =   100.0  -- mass/charge tune point (u/e)
                                             -- (particles of this m/z pass)
adjustable _quad_entrance_voltage =     0.0  -- quad entrance voltage
adjustable _quad_axis_voltage     =    -8.0  -- quad axis voltage
adjustable _quad_exit_voltage     =  -100.0  -- quad exit voltage
adjustable _detector_voltage      = -1500.0  -- detector voltage

adjustable pe_update_each_usec      = 0.05   -- potential energy display
                                             -- update period (microsec)
                                             -- (for display purposes only)

-- Variables adjustable only at beginning of flight:
 
adjustable effective_radius_in_cm   = 0.40   -- half the minimum distance between
                                             -- opposite rods (cm)
adjustable phase_angle_deg          = 0.0    -- quad entry phase angle of ion (deg)
adjustable frequency_hz             = 1.1E6  -- RF frequency of quad (Hz)


-- Note: Using circular rods, the radius of the rods themselves
-- should optimally be approximately 1.1487 * r_0.

-- Temporary variables used internally.
local scaled_rf  -- a factor used in the RF component
local omega      -- frequency_hz (reexpressed in units of radians/usec)
local theta      -- phase_angle_deg (reexpressed in units of radians)
local last_pe_update = 0.0 -- last potential energy surface update time (usec)

-- SIMION segment called by SIMION at the start of ion flight for each potential
-- array instance to initialize adjustable electrode voltages in that instance.
-- NOTE: Code here can always more generally be placed instead in the
--   fast_adjust segment.  Typically, the only reason for an
--   init_p_values segment is to initialize static (not time-dependent)
--   voltages all at once, avoiding executing code on every time-step as done
--   in a fast_adjust segment.  This is intended to improve performance
--   (though in some cases could reduce it).
function segment.init_p_values()
    local is_monolithic = (#simion.wb.instances == 1) -- single PA
    if is_monolithic or ion_instance == 2 then      -- entrance PA
        adj_elect03 = _quad_entrance_voltage
    end
    if is_monolithic or ion_instance == 3 then  -- exit PA
        adj_elect04 = _quad_exit_voltage
        adj_elect05 = _detector_voltage
    end
end

-- SIMION segment called by SIMION to set adjustable electrode voltages
-- in the current potential array instance.
-- NOTE: this is called frequently, multiple times per time-step (by
-- Runge-Kutta), so performance concerns here can be important.
function segment.fast_adjust()
    -- See "Overview of Quad Equations" comments for details.

    if not scaled_rf then
        -- Initialize constants if not already initialized.
        -- These constants don't change during particle flight,
        -- so we can calculate them once and reuse them.
        -- Reusing them is a bit more efficient (~25% by one estimate)
        -- than recalculating them on every fast_adjust call.
        scaled_rf = effective_radius_in_cm^2 * frequency_hz^2 * 7.222e-12
        theta = phase_angle_deg * (math.pi / 180)
        omega = frequency_hz * (1E-6 * 2 * math.pi)
    end

    local rfvolts = scaled_rf * _amu_mass_per_charge
    local dcvolts = rfvolts * _percent_tune * ((1/100) * 0.1678399)
    local tempvolts = sin(ion_time_of_flight * omega + theta) * rfvolts + dcvolts

    -- Finally, apply adjustable voltages to rod electrodes.
    adj_elect01 = _quad_axis_voltage + tempvolts
    adj_elect02 = _quad_axis_voltage - tempvolts
end

-- SIMION segment called by SIMION after every time-step.
function segment.other_actions()
  -- Update potential energy surface display periodically.
  -- The performance overhead of this in non-PE views is only a few percent.
  -- NOTE: the value inside abs(...) can be negative when a new ion is flown.
  if abs(ion_time_of_flight - last_pe_update) >= pe_update_each_usec then
    last_pe_update = ion_time_of_flight
    sim_update_pe_surface = 1    -- Request a PE surface display update.
  end
end

-- SIMION segment called by SIMION to override time-step size on each time-step.
function segment.tstep_adjust()
   -- Keep time step size below some fraction of the RF period.
   -- See "Time Step Size" comments.
   ion_time_step = min(ion_time_step, 0.1*1E+6/frequency_hz)  -- X usec
end


-- This imposes a theoretical hyperbolic field,
-- overriding the field in the SIMION potential array.
-- This is OPTIONAL.   Enable this to compare results against
-- a theoretical field.
-- If you enable this efield_adjust segment, you may (though do not need to)
-- disable the fast_adjust segment since the efield_adjust overrides the
-- fields computed using the fast_adjust.
-- Set next line to "--[[" to disable or "----[[" to enable.
--[[
local first
function segment.efield_adjust()
    --enable one of these to limit where/when theoretical field is applied
    --if not(ion_instance == 1) then return end    -- only apply to instance #1.
    --if not(ion_number % 2 == 0) then return end    -- only apply to even number ions.
    --if not(ion_instance == 1 and ion_number % 2 == 0) then return end    -- only apply to even number ions in instance #1

    -- Compute rod potentials
    if not first then
        first = true
        print 'WARNING: theoretical field enabled'
        scaled_rf = effective_radius_in_cm^2 * frequency_hz^2 * 7.222e-12
          --OLD: 7.11016e-12
        theta = phase_angle_deg * (math.pi / 180)
        omega = frequency_hz * (1E-6 * 2 * math.pi)
    end
    local rfvolts = scaled_rf * _amu_mass_per_charge
    local dcvolts = rfvolts * _percent_tune * ((1/100) * 0.1678399)
    local tempvolts = sin(ion_time_of_flight * omega + theta) * rfvolts + dcvolts
    local A = _quad_axis_voltage + tempvolts
    local B = _quad_axis_voltage - tempvolts  

    -- define electric field vector theoretically...

    local r0_gu = effective_radius_in_cm * 10 / ion_mm_per_grid_unit  -- gu
    local x_gu = ion_px_gu
    local y_gu = ion_py_gu

    -- field vector (V/gu) in PA coordinate system.
    local ex = (A-B)*x_gu/(r0_gu*r0_gu)
    local ey = (B-A)*y_gu/(r0_gu*r0_gu)
    local ez = 0

    -- define voltage theoretically too (optional - does not affect ion motion)
    local v = A * (1/2) * (1 + (y_gu*y_gu - x_gu*x_gu)/(r0_gu*r0_gu)) +
              B * (1/2) * (1 + (x_gu*x_gu - y_gu*y_gu)/(r0_gu*r0_gu))

    -- optionally compare before and after
    --printf('compare: %0.3e %0.3e %0.3e %0.3e\n         %0.3e %0.3e %0.3e %0.3e ',
    --  ion_volts, ion_dvoltsx_gu, ion_dvoltsy_gu, ion_dvoltsz_gu,  v,-ex,-ey,-ez)

    -- set it
    ion_dvoltsx_gu = -ex
    ion_dvoltsy_gu = -ey
    ion_dvoltsz_gu = -ez
    ion_volts = v
end
--]]


--[[

  == Overview of Quad Equations ==
  
  The quadrupole mass filter has four rods with sinusoidal (RF)
  waveforms applied to them.  Opposing rods have the same voltage,
  so there are only two voltages, V1 and V2, to define:
  
    V1 =  (U - V sin(omega*t + theta))
    V2 = -(U - V sin(omega*t + theta))
  
  where t is time (microseconds), omega is the angular frequency
  (radians/microsecond), theta is a phase offset, and U and V
  are respectively the magnitudes of the DC and RF voltage components.
  
  U and V are proportional, respectively, to the more system independent
  Mathieu constants a and q, and the stability of the system is
  determined by the values of these constants.
  
    V = (1/4) * r_0^2 * omega^2 * (m/e) * q
    U = (1/8) * r_0^2 * omega^2 * (m/e) * a = (1/2) * V * (a/q)
  
  where r_0 is half the minimum distance between opposite rods,
  and (m/e) is the mass-to-charge ratio of the particle.
  
  The stable region has a local maximum of a at
  
    q_max ~ 0.70600, a_max ~ 0.23699
  
  (This is the intersection of the Mathieu curves -a_0(q) and b_1(q)
   on the q-a plane.)
  
  Note the DC/RF ratio: U/V = (1/2)*(a/q) ~ 0.167839(9).
  
  a_max is the limit of stability.  Typically we operate the system
  at some fraction (_percent_tune/100), just under one, of a_max.
  
  Note the unit conversion_factor ~
    (1.66053886*10^-27 kg/u) * (1.602176462*10^-19 C/e)^-1 *
    (2*PI rad/cycle)^2 * (0.01 m/cm)^2
  which is used for (1/4) * (unit conversion factor) * q ~ 7.22(2)e-12.
  (The original version of this example used a constant 7.11016e-12, which
  reduces transmission under very high _percent_tune under higher field
  calculation accuracy, such as surface enhancement or theoretical fields.)

  == Time Step Size ==
  
  For the trajectory calculation to be reliable, the time step size should
  be no more than some fraction of the RF period so that the ion sees each
  RF cycle as it exists.
  In the SIMION quadruople example under minimum trajectory quality (0)
  and default conditions, ion_time_step is already below one-tenth the
  RF period, so this code isn't really necessary.  However, this code
  reduces the chance of surprises in case the conditions are changed
  and trajectory quality factor is set too low.
  The performance overhead of this is quite low (~1%).
  
  == Other Ideas ==
 
  Maybe have the program tune or auto-tune by iterating over
  various (q,a) values and examining acceptance (or plotting
  diagrams as in the Excel examples).  Optionally automate
  various large studies with batch mode operations.

  A background gas (for collisional cooling) may be added.
  See the trap, drag, and collision_hs1 examples.
  
  Other types of multipoles (hexapoles, octupoles, etc.) can be
  simulated.  Make sure you take full advantage of symmetry
  (e.g. X-Y mirror planes) and adjustable electrodes.
  A multipole might have N rods, but it only uses two distinct
  voltages, so you only need two adjustable voltages (or in some
  cases a single fast scalable electrode set in a PA# file).
  See the octupole example.

--]]
