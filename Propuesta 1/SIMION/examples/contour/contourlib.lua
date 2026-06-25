-- contourlib.lua
-- Utility routine for plotting field lines using particle trajectories.
--
-- The type of plot is defined by the particle mass:
--
--   1000    - electrostatic equipotential contour
--   1001    - electrostatic field line
--   1002    - magnetic equipotential contour
--   1003    - magnetic field line
--   (other) - particle not used for contouring
--
-- D.Manura, 2008-03
-- (c) 2008 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--
simion.workbench_program()

-- http://simion.com/issue/490
if checkglobals then checkglobals() end


-- Begin user modifiable variables

  -- Number of PA grid units to step when plotting contour lines.
  -- Decrease for higher quality.  Increase for faster speed.  A
  -- fraction of a grid unit is convenient.
  adjustable contour_step_gu = 0.03

  -- Minimum and maximum lengths of contour lines (non-negative
  -- numbers).  If contour_max_gu is > 0, the length of each contour
  -- line is made between these two lengths, with the fraction
  -- proportional to the magnitude of the field.  Set contour_max_gu to
  -- 0 to disable limiting the length of contour lines.  contour_min_gu
  -- is ignored if contour_max_gu is 0.
  -- If this option is enabled, Grouped particle flying must be enabled
  -- (the program checks this and raises an error if it is not).
  adjustable contour_min_gu = 0
  adjustable contour_max_gu = 0

-- End user modifable variables


-- Save old segments if they exist (avoid overwrite)
local old_other_actions = segment.other_actions
local old_tstep_adjust  = segment.tstep_adjust

-- start[n] = {x,y,z} is starting position vector (mm) of particle
-- number n.
local start = {}

-- mags[n] is magnetic of field at starting position of particle n.
local mags = {}

-- max_mag is the maximum value of the mags[n].
local max_mag = 0

-- maxdistance[n] is maximum distance particle number n travels (mm)
-- from its starting position start[n].
local maxdistance = {}


-- Utility routine to calculate the Euclidean distance between points
-- (ax,ay,az) and (bx,by,bz).
local sqrt = math.sqrt
local function distance(ax,ay,az, bx,by,bz)
  local dx,dy,dz = ax-bx, ay-by, az-bz
  return sqrt(dx*dx + dy*dy + dz*dz)
end


-- Trick to check that Grouped flying is disabled.
-- This is designed to be called from every
-- other_actions segment call.
-- Returns true only if non-Grouped flying detected.
local inst, lastn, same
local function detect_nongrouped()
  -- Non-grouped is detected by sequental calls with
  -- ion numbers a, b, c where a==b and b~=c.
  -- Watch only a single PA instance.
  inst = inst or ion_instance
  if ion_instance ~= inst then return end
  if ion_number == lastn then same = true end
  if same and ion_number ~= lastn then
    return true
  end
  lastn = ion_number
end


-- SIMION segment called to set time step.
function segment.tstep_adjust()
  if old_tstep_adjust then old_tstep_adjust() end

  if ion_mass < 1000 or ion_mass > 1003 or
     math.floor(ion_mass) ~= ion_mass
  then
    return -- particle not used for contouring
  end

  -- Set time step size to zero, effectively disabling
  -- SIMION's own trajectory integration.
  ion_time_step = 0
end


-- SIMION segment called on each time step.
local TWO_PI = 2 * math.pi
function segment.other_actions()
  if old_other_actions then old_other_actions() end

  -- Determine type of contour to plot from particle color.
  local is_magnetic, is_field
  if ion_mass == 1000 then
    is_magnetic, is_field = false, false
  elseif ion_mass == 1001 then
    is_magnetic, is_field = false, true
  elseif ion_mass == 1002 then
    is_magnetic, is_field = true, false
  elseif ion_mass == 1003 then
    is_magnetic, is_field = true, true
  else
    return -- particle not used for contouring
  end

  -- Verify that Grouped flying is enabled if contour lengths
  -- are limited (this option will not work otherwise).
  if contour_max_gu > 0 then
    if detect_nongrouped() then
      error '\n\n\nGrouped flying is not enabled.  In the Particles tab, make sure Grouped is checked before running this example.\n\n'
    end
  end

  -- Get field vector.
  local ex,ey,ez
  if is_magnetic then
    ex,ey,ez = ion_bfieldx_mm, ion_bfieldy_mm, ion_bfieldz_mm
  else
    ex,ey,ez = -ion_dvoltsx_mm,-ion_dvoltsy_mm,-ion_dvoltsz_mm
  end

  -- Normalize it.
  local mag = sqrt(ex*ex+ey*ey+ez*ez)
  local nx,ny,nz
  if mag ~= 0 then
    local factor = 1 / mag    
    nx,ny,nz = ex*factor, ey*factor, ez*factor
  else
    nx,ny,nz = 0,1,0
  end

  -- Initialize some data on particle creation.
  if not start[ion_number] then
    start[ion_number] = {ion_px_mm, ion_py_mm, ion_pz_mm}
    maxdistance[ion_number] = 0
    mags[ion_number] = mag
    max_mag = math.max(max_mag, mag)
    return -- don't continue until all particles in group initialized
           -- so that max_mag calculation is completed.
  end

  -- Rotate normal 90 degrees if we want contour lines instead.
  -- This assumes contours in the 2D XY plane.
  if not is_field then
    nx,ny = -ny,nx
  end

  -- Trace negatively charged particles in reverse direction to
  -- allow bidirectional tracing.
  if ion_charge < 0 then
    nx,ny,nz = -nx,-ny,-nz
  end

  -- Set step size.
  local dr = ion_mm_per_grid_unit * contour_step_gu

  -- Step particle position by distance dr along normal vector.
  ion_px_mm = ion_px_mm + nx * dr
  ion_py_mm = ion_py_mm + ny * dr
  ion_pz_mm = ion_pz_mm + nz * dr
  ion_time_of_flight = ion_time_of_flight + dr

  -- Terminate ray if it line loops around on itself.
  -- Without this, a particle tracing a magnetic field (which has no poles)
  -- would loop infinitely.
  local s = start[ion_number]
  local d = distance(ion_px_mm,ion_py_mm,ion_pz_mm, s[1],s[2],s[3])
  if d > maxdistance[ion_number] then
    maxdistance[ion_number] = d
  end
  if ion_time_of_flight / maxdistance[ion_number] > TWO_PI then
    ion_splat = 1  -- terminate this particle trace
  end

  -- Limit contour lengths if contour lengths are selected to be
  -- limited (contour_max_gu > 0)
  if contour_max_gu > 0 then
    local frac = mags[ion_number]/max_mag
    local length_gu =
      contour_min_gu + frac * (contour_max_gu - contour_min_gu)
    if ion_time_of_flight > length_gu * ion_mm_per_grid_unit then
      ion_splat = 1  -- terminate this particle trace
    end
  end
end 
