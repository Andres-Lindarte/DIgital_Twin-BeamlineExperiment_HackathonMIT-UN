--[[
 parallel_plates.lua
 Lua workbench user program to compute/plot induced charge/current
 on electrodes given moving particles.
 Uses inductionlib.lua for the calculation and plotlib.lua for the
 plotting.
 2012-08-18,2008-05,D.Manura
--]]

simion.workbench_program()

assert(simion.pas, 'This example requires SIMION 8.1.')

-- Magnetic field in Z direction (Gauss)
adjustable bz_gauss = -47.688984

-- Time in microseconds after which to terminate simulation.  Set to a
-- large value, e.g. 1E+30, to never prematurely terminate simulation.
adjustable max_time_usec = 0.02

-- Whether to plot data graphically (1=yes, 0=no).
-- Set to 0 if you don't have a plotting program installed
-- or don't want to plot.
adjustable plot_enable = 1

-- Currents in plots are plotted relative to this current (A).
-- Set as appropriate to obtain the vertical scale as desired.
-- This is only used for plotting purposes.
adjustable units_current_A = 1E-12

-- Charges in plots are plotted relative to this charge (C).
-- Set as appropriate to obtain the vertical scale as desired.
-- This is only used for plotting purposes.
adjustable units_charge_C = 1E-20

-- Velocities in plots are plotted relative to this velocity (mm usec^-1).
-- Set as appropriate to obtain the vertical scale as desired.
-- This is only used for plotting purposes.
adjustable units_velocity_mmusec = 1E2

-- Positions in plots are plotted relative to this velocity (mm usec^-1).
-- Set as appropriate to obtain the vertical scale as desired.
-- This is only used for plotting purposes.
adjustable units_position_mm = 1


-- Load charge/current induction calculation code.
local INDUCE = simion.import 'inductionlib.lua'

-- Specify list of which electrodes on which instances we will measure
-- the induced charge/current on.  Multiple electrodes may be
-- specified.  See inductionlib.lua for details.
INDUCE.measure {
  {instance = 1, electrode = 1},
}

-- Load plotting library
local PLOT = simion.import '../plot/plotlib.lua'

local plotdata = {}   -- data to be plotted


-- SIMION segment for defining magnetic field at current particle position.
function segment.mfield_adjust()
  -- Define perpendicular field so that particle moves in circle.
  ion_bfieldz_gu = bz_gauss
end


-- SIMION segment called on each time-step.
local last_tof
local stop
function segment.other_actions()
  -- Terminate run (if stop flag set).
  if stop then ion_splat = 1; return end
  if ion_time_of_flight > max_time_usec then
    stop = true
  end

  -- Record data from previous induction calculation.
  if INDUCE.tof and INDUCE.tof ~= last_tof then
    last_tof = INDUCE.tof
    -- Define data header if not exist.
    if not plotdata.header then
      plotdata.header = {
        'time (usec)',
        'current (' .. units_current_A .. ' A)',
        'charge (' .. units_charge_C .. ' C',
        'y (' .. units_position_mm .. ' mm)',
        'vx (' .. units_velocity_mmusec .. ' mm/usec)',
        'vy (' .. units_velocity_mmusec .. ' mm/usec)'
      }
    end
    -- Record data point.
    local row = {
      INDUCE.tof,
      INDUCE.current/units_current_A,
      INDUCE.charge/units_charge_C,
      ion_py_mm / units_position_mm,
      ion_vx_mm / units_velocity_mmusec,
      ion_vy_mm / units_velocity_mmusec
    }
    table.insert(plotdata, row)
    print(unpack(row))
  end

  -- Run charge/current induction calculation code.
  INDUCE.other_actions()
end


-- called exactly once at the end of each run.
function segment.terminate_run()
  if plot_enable == 1 then PLOT.plot(plotdata) end
end


--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
