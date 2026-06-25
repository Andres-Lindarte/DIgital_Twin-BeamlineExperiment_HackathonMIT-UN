--[[
 Generate PA with ideal quadro-logarithmic field and analytic electrode
 surfaces.  This uses the Lua PA API (simion.pas).
 DM 2012-08-01,2009. SIMION 8.1.
--]]

-- System dimensions, which you may wish to change.
-- See published papers on such topics concerning choice of dimensions.
local k = 1    -- field curvature
local Rm = 20  -- characteristic radius, mm
local R2 = 14  -- outer radius, mm
local R1 = 5   -- inner radius, mm
local C = 0    -- DC offset
local mmgu = 0.1  -- cell size, mm/gu

-- If a workbench is open, obtain the first PA on workbench;
-- otherwise create new PA from scratch.  The former is mainly to allow this
-- script to be conveniently run from a workbench user program upon IOB load.
local pa
if simion.wb then
  pa = simion.wb.instances[1].pa
else
  simion.pas:close()
  pa = simion.pas:open()
end

-- Set PA dimensions.
pa:size(351,151,1)
pa.symmetry = '2dcylindrical[x]'
pa.dx_mm = mmgu
pa.dy_mm = pa.dx_mm
pa.dz_mm = pa.dx_mm
-- For a 3D PA use   pa:size(351,151,151); pa.symmetry = '3dplanar[xyz]'

-- Analytic quadro-logarithmic potential.
local function phi(x,y,z)  -- mm
  local r = math.sqrt(y*y + z*z)
  return (k/2)*(x*x - r*r/2 + (Rm*Rm)*math.log(r/Rm)) + C
end

-- Fill points in PA with analytic potentials and electrode surfaces.
local V1 = phi(0, R1, 0)
local V2 = phi(0, R2, 0)
pa:fill { function(x,y,z)  -- mm
  local v = phi(x,y,z)
  local e
  if v >= V2 then
    v = V2; e = true
  elseif v <= V1 then
    v = V1; e = true
  else
    e = false
  end
  return v, e
end, surface='fractional' }
-- NOTE: for best accuracy of Refines, enable surface enhancement by setting
-- surface to 'fractional' rather than 'none'.
-- In older versions of SIMION (prior to 8.1.1), which did not have surface
-- enhancement, some accuracy could be regained by applying an approximatly
-- 0.5 gu adjustment to the electrode surfaces (roughly like the "within" v.s.
-- "within_inside" described in the SIMION printed manual Geometry Files
-- appendix), but that should not be done when using surface enhancement.


-- Optionally refine PA and then compare against theory by subtracting
-- theoretical potentials from PA points.  The resultant PA of differences
-- can be examined in Modify and View screens.
-- This can be used to show that surface enhancement improves accuracy by
-- about two orders of magnitude.
-- Warning: this operation overwrites the PA.
--[[
pa:refine { convergence=1E-7 }
for x,y,z in pa:points() do
  local v,e = pa:point(x,y,z)
  local err = e and 0 or math.abs(phi(x*pa.dx_mm,y*pa.dy_mm,z*pa.dz_mm) - v)
  pa:potential(x,y,z, err)
end
--]]


-- Note: the pa:fill above happens to set the non-electrode (not just
-- electrode) point potentials to theoretical values, so the array is
-- built refined and you don't necessarily need to refine it again; in fact,
-- fields will be more accurate if you don't refine.  The following will guard
-- against accidentally refining the PA again.
-- WARNING: If you change electrode shapes to no longer be ideal, then you must
-- remove these lines to allow SIMION to calculate the E-field.
pa.refined = true
pa.refinable = false


-- Finally, save it.
pa:save('quadro_logarithmic.pa')
