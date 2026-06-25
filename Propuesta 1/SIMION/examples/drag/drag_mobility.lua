--[[
  drag_mobility.lua

  An adaptation of the drag.lua example so that the drag coefficient
  is calibrated against a known mobility coefficient.
  See the README.html file for details and caveats.

  D.Manura, 2011-02-01.
--]]

simion.workbench_program()


-- Ion's Stokes' law damping (usec^-1) at STP for each ion.
-- Note: usec == microsecond.
-- This is converted from ion mobility.
-- This is table keyed by ion number.
local ions_STP_damping = {}

-- System parameters at current ion position.
-- You could also make this a function of ion position.
adjustable local_pressure_torr = 10    -- local pressure (torr)
adjustable local_temperature_K = 500   -- local temperature (K)
            -- Bulk gas velocity in x,y,z directions (mm/usec).
adjustable local_vx_mm_per_usec = 0
adjustable local_vy_mm_per_usec = 0
adjustable local_vz_mm_per_usec = 0

-- Reduced mobility coefficient, Ko (10-4 m^2 V^-1 s^-1).
-- This depends on the ion and gas types.
adjustable ko = 2.0   -- you probably want to change this

-- Physical constants (normally don't change).
local ELEMENTARY_CHARGE = 1.602176462e-19  -- elementary charge (C)
local AMU_TO_KG         = 1.66053873e-27   -- mass of one u in kg
local STP_TEMP          = 273.15           -- standard temperature (K)

-- Gets ion's Stoke's law damping (usec^-1) at the local temperature and
-- pressure, given the damping at standard temperature and pressure (STP).
local function get_local_damping(STP_damping, local_temperature_K, local_pressure_torr)
  -- Correct for local temperature and pressure.
  local t_ratio = local_temperature_K / STP_TEMP          -- local T
  local pt_ratio = t_ratio * (760 / local_pressure_torr)  -- local P
  local local_damping = STP_damping / pt_ratio
  return local_damping
end

--[[
  Applies Stokes' Law viscous damping in this time step
  (ion_time_step) by damping acceleration (ion_a[xyz]_mm), given
  damping factor (usec^-1) and mean bulk velocity of background gas
  (vx,vy,vz) (mm/usec in workbench orientation).
  
  This is designed to be called inside a SIMION accel_adjust segment.
  See examples\drag\drag.lua for futher details on this implementation.
--]]
local function apply_stokes_damping(damping, vx,vy,vz)
  if damping ~= 0 and ion_time_step ~= 0 then
    damping = abs(damping)  -- force positive

    local tterm = damping * ion_time_step  -- time constant
    local factor = (1 - exp(-tterm)) / tterm

    -- Store as new acceleration components.
    ion_ax_mm = factor*(ion_ax_mm - (ion_vx_mm - vx)*damping)
    ion_ay_mm = factor*(ion_ay_mm - (ion_vy_mm - vy)*damping)
    ion_az_mm = factor*(ion_az_mm - (ion_vz_mm - vz)*damping)
  end
end

function segment.initialize()
  -- Estimate Stokes' Law damping (usec^-1) for each ion at STP condition.
  local emu = ELEMENTARY_CHARGE/AMU_TO_KG    -- (C kg^-1 u)
  local STP_damping =
      emu
      * 0.01       -- 10^-4 * (10^+6 usec sec^-1)
      / ko         -- (10^-4 m^2 V^-1 s^-1) = 10^-4 s C kg^-1)
      / ion_mass   -- (u)
  ions_STP_damping[ion_number] = STP_damping
end

local debug_found = {}

function segment.accel_adjust()
  -- Calculate ion's damping (usec^-1) at local ion conditions.
  local damping = get_local_damping(ions_STP_damping[ion_number],
      local_temperature_K, local_pressure_torr)

  -- DEBUG
  if not debug_found[ion_number] then
    debug_found[ion_number] = true
    print(
      'DEBUG: local damping =', damping,
      'STP damping =', ions_STP_damping[ion_number],
      'ion_number =', ion_number)
  end

  -- Apply stokes' law viscous mobility effect with local damping
  -- and bulk gas velocity conditions.
  apply_stokes_damping(
    damping, local_vx_mm_per_usec,local_vy_mm_per_usec,local_vz_mm_per_usec)
end
