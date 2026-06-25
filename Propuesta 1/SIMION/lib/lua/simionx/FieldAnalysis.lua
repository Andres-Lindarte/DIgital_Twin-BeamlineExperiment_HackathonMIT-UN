--[[
 simionx.FieldAnalysis
 This module is documented in the SIMION supplemental documentation.
 version: 20130321
 (c) 2006-2013 Scientific Instrument Services, Inc. (SIMION 8.0/8.1 License)
--]]

local INT = require "simionx.Integration"
local FMT = require "simionx.Format"
local Type = require "simionx.Type"

local math = math
local format = string.format
local yield = coroutine.yield
local PI = math.pi
local scientific_notation = FMT.scientific_notation


local M = {}

M.line            = INT.line
M.box             = INT.box
M.box_filled      = INT.box_filled
M.sphere          = INT.sphere
M.sphere_filled   = INT.sphere_filled
M.circle2d        = INT.circle2d
M.circle2d_filled = INT.circle2d_filled

local printf = function(...) print(format(...)) end

local T_pa = Type(
  function(o)
    return simion.pas and simion.pas[1] and
           getmetatable(o) == getmetatable(simion.pas[1])
  end,
  "SIMION PA"
)

local function helper(t)
  local field = t.field
  local mm_per_unit = t.mm_per_unit or 1

  if type(field) == "userdata" then -- SIMION PA
    local pa = field
    assert(pa.potential_type == "electric", "PA may not be magnetic")
    field = function(x,y,z) return pa:field_vc(x,y,z) end
  end

  local e0 = 8.8541878176E-12 -- permittivity of free space (F/m)
  local m_per_gu = 1E-3 * mm_per_unit
  local f = e0 * m_per_gu     -- constant factor on integrand

  -- Integrate over surface area in units of gu^2.
  local co = INT.montecarlo_integrate {
    func = function(x,y,z, ux,uy,uz)
      local ex, ey, ez = field(x, y, z)         -- units: V/gu
      local dflux = ex*ux + ey*uy + ez*uz       -- E * u  (dot product)
      return dflux
    end,
    shape = t.shape,
    min_iterations = t.min_iterations,
    rel_err = t.rel_err,
    abs_err = t.abs_err
  }

  yield()
  repeat
    local result, result_err, count, is_end = co()
    local charge = f * result
    local charge_err = f * result_err
    yield(charge, charge_err, count, is_end)
  until is_end
end
local sig
function M.charge_from_gauss_law(t)
  sig = (sig or Type {
    field          = Type['function'] + T_pa, -- gu
    shape          = Type.table, -- gu
    mm_per_unit    = Type.nonnegative_number + Type['nil'], -- gu/mm
    min_iterations = Type.nonnegative_number + Type['nil'],
    rel_err        = Type.nonnegative_number + Type['nil'],
    abs_err        = Type.nonnegative_number + Type['nil']
  }):check(t,2)
  local co = coroutine.wrap(helper); co(t)
  return co
end

local function helper(t)
  -- Process Inputs.
  local field = t.field
  local mm_per_unit = t.mm_per_unit
  local potential_type
  if type(field) == "userdata" then -- SIMION PA
    local pa = field
    potential_type = pa.potential_type
    field = function(x,y,z) return pa:field_vc(x,y,z) end
  else
    potential_type = t.field_type or "electric"
  end
  local is_magnetic = potential_type == "magnetic"

  -- Determine electric (E) or magnetic (B) field energy (W) by integrating
  -- over volume tau:
  --
  --   W = INTEGRAL (0.5*e0)  E^2 dtau   (electric)
  --   W = INTEGRAL (0.5/mu0) B^2 dtau   (magnetic)
  --
  -- Using SI Units:
  --   W (J), e0 (F/m), mu0 (N*A^-2), E (V/m), B (T=N/(A*m)), tau (m^3).
  -- and SIMION Units:
  --   E (V/gu), B (Gauss=T*1000), tau (gu^3).

  local e0 = 8.8541878176E-12 -- permittivity of free space (F/m)
  local mu0 = 4E-7*PI         -- permeability of free space (N*A^-2)
  local tesla_per_gauss = 1E-4
  local m_per_gu = 1E-3 * mm_per_unit
  -- constant factor on integrand:
  local f = is_magnetic
    and -- magnetic
      (0.5/mu0)         -- units: A^2/N
      * (tesla_per_gauss)^2 * (m_per_gu)^3
    or  -- electric
      0.5*e0            -- units: F/m
      * (m_per_gu)
  -- integrate over volume tau in gu^3:
  local co = INT.montecarlo_integrate {
    func = function(x,y,z, ux,uy,uz)
      local ex, ey, ez = field(x, y, z)
      local e2 = ex*ex + ey*ey + ez*ez
                        -- units: (V/gu)^2 (electric) or Gauss^2 (magnetic)
      return e2 * f     -- units: J/gu^3
    end,
    shape = t.shape,
    min_iterations = t.min_iterations,
    rel_err = t.rel_err,
    abs_err = t.abs_err
  }
  yield()
  repeat
    local result, result_err, count, is_end = co()
    local energy = result
    local energy_err = result_err
    yield(energy, energy_err, count, is_end)
  until is_end
end
local sig
function M.field_energy(t)
  sig = (sig or Type {
    field          = Type['function'] + T_pa, -- gu
    shape          = Type.table, -- gu
    mm_per_unit    = Type.nonnegative_number + Type['nil'], -- gu/mm
    min_iterations = Type.nonnegative_number + Type['nil'],
    rel_err        = Type.nonnegative_number + Type['nil'],
    abs_err        = Type.nonnegative_number + Type['nil']
  }):check(t,2)
  local co = coroutine.wrap(helper); co(t)
  return co
end

local function helper(t)
  local potential = t.potential

  local t2 = {}; for k,v in pairs(t) do t2[k] = v end
  t2.potential = nil
  local co = M.field_energy(t2)

  yield()
  repeat
    local energy, energy_err, iteration, is_end = co()
    local charge = energy * 2 / potential
    local charge_err = energy_err * 2 / potential
    yield(charge, charge_err, iteration, is_end)
  until is_end
end
local sig
function M.charge_from_field_energy(t)
  sig = (sig or Type {
    field          = Type['function'] + T_pa, -- gu
    shape          = Type.table, -- gu
    mm_per_unit    = Type.nonnegative_number + Type['nil'], -- gu/mm
    min_iterations = Type.nonnegative_number + Type['nil'],
    rel_err        = Type.nonnegative_number + Type['nil'],
    abs_err        = Type.nonnegative_number + Type['nil'],
    potential      = Type.number
  }):check(t,2)
  local co = coroutine.wrap(helper); co(t)
  return co
end

local sig
function M.charge_from_gauss_law_display(t)
  sig = (sig or Type {
    field          = Type['function'] + T_pa, -- gu
    shape          = Type.table, -- gu
    mm_per_unit    = Type.nonnegative_number + Type['nil'], -- gu/mm
    min_iterations = Type.nonnegative_number + Type['nil'],
    rel_err        = Type.nonnegative_number + Type['nil'],
    abs_err        = Type.nonnegative_number + Type['nil']
  }):check(t,2)

  local mm_per_unit = t.mm_per_unit or 1
  print "Calculating charge in volume by Gauss's Law..."
  printf("  with mm_per_unit=%g mm/unit",
         mm_per_unit)

  local co = M.charge_from_gauss_law(t)

  local charge, charge_err, iteration, is_end
  repeat
    charge, charge_err, iteration, is_end = co()
    local scharge = scientific_notation(charge, charge_err)
    printf("charge= %s C [iteration= %d pts/gu]",
           scharge, iteration)
    -- don't hog the display
    if simion.key() == 27 then error("ESC key pressed") end
    simion.redraw_screen()
  until is_end

  print "Convergence limits reached."

  return {charge = charge, charge_err = charge_err,
          iteration = iteration}
end

local sig
function M.field_energy_display(t)
  sig = (sig or Type {
    field          = Type['function'] + T_pa, -- gu
    shape          = Type.table, -- gu
    mm_per_unit    = Type.nonnegative_number + Type['nil'], -- gu/mm
    min_iterations = Type.nonnegative_number + Type['nil'],
    rel_err        = Type.nonnegative_number + Type['nil'],
    abs_err        = Type.nonnegative_number + Type['nil']
  }):check(t,2)

  local mm_per_unit = t.mm_per_unit
  print "Calculating field energy in volume..."
  printf("  with mm_per_unit=%g mm/gu",
         mm_per_unit)

  local co = M.field_energy(t)

  local energy, energy_err, iteration, is_end
  repeat
    energy, energy_err, iteration, is_end = co()
    printf("energy= %s J [iteration= %d]",
           scientific_notation(energy, energy_err),
           iteration)
    -- don't hog the display
    if simion.key() == 27 then error("ESC key pressed") end
    simion.redraw_screen()
  until is_end

  print "Convergence limits reached."

  return {energy = energy, energy_err = energy_err,
          iteration = iteration}
end

local sig
function M.charge_from_field_energy_display(t)
  sig = (sig or Type {
    field          = Type['function'] + T_pa, -- gu
    shape          = Type.table, -- gu
    mm_per_unit    = Type.nonnegative_number + Type['nil'], -- gu/mm
    min_iterations = Type.nonnegative_number + Type['nil'],
    rel_err        = Type.nonnegative_number + Type['nil'],
    abs_err        = Type.nonnegative_number + Type['nil'],
    potential      = Type.number
  }):check(t,2)

  local mm_per_unit = t.mm_per_unit
  print "Calculating charge in volume from field energy..."
  printf("  with mm_per_unit=%g mm/gu",
         mm_per_unit)

  local co = M.charge_from_field_energy(t)

  local charge, charge_err, iteration, is_end
  repeat
    charge, charge_err, iteration, is_end = co()
    printf("charge= %s C [iteration= %d]",
           scientific_notation(charge, charge_err), iteration)
    -- don't hog the display
    if simion.key() == 27 then error("ESC key pressed") end
    simion.redraw_screen()
  until is_end

  print "Convergence limits reached."

  return {charge = charge, charge_err = charge_err,
          iteration = iteration}
end


M._scientific_notation = scientific_notation

return M
