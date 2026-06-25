--[[
 mag_halback_2dp.lua
 Solves magnetic B-field of Halbach array.
 See README.html for details.
 
 D.Manura, 2012-05
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1/8.2)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- Load libraries.
local CON = simion.import '../contour/contourlib81.lua'  -- vector plotting

-- Get PA instances.
local Mxinst = simion.wb.instances[1]   -- Mx (x-component of M), A/mm
local Myinst = simion.wb.instances[2]   -- My (y-component of M), A/mm
local jinst  = simion.wb.instances[3]   -- -div M, A/mm^2
local inst   = simion.wb.instances[4]   -- magnetic scalar potential

-- Maps contour color numbers to specific PA instance numbers, for clarity.
simion.experimental.contour_color_instance{[2]={4}}

-- vacuum permeability, T m/A
local MU0 = 4*math.pi*1E-7

-- conversion factors
local GAUSS_PER_TESLA = 10000   -- gauss/tesla
local M_PER_MM = 0.001          -- m/mm

-- M-field in A/mm
local function Mfield(x,y,z)
  local hgu = Mxinst.pa.dx_mm * Mxinst.scale * 0.5  -- 1/2 gu adjustment should be more accurate
  local Mx,My,Mz = Mxinst:potential_wc(x-hgu,y-hgu,z-hgu), Myinst:potential_wc(x-hgu,y-hgu,z-hgu), 0
  if x < 0 then Mx=-Mx end -- antimirror Mx in x and y
  if y < 0 then Mx=-Mx end -- antimirror Mx in x and y
  return Mx,My,Mz
end

-- B-field in gauss.
-- Note: B = mu0*(H + M)
local function bfield(x,y,z)
  -- Highest priority magnetic PA instance contains H*mu0.
  -- simion.wb:bfield returns negative gradient of this.
  local bx,by,bz = simion.wb:bfield(x,y,z)
  if y < 0 then bx,by,bz=-bx,-by,-bz end  -- H-field has anti-mirror in y.

  -- Add M*mu0 to H*mu0.
  local Mx,My,Mz = Mfield(x,y,z)
  bx = bx + (Mx/M_PER_MM)*(MU0*GAUSS_PER_TESLA)
  by = by + (My/M_PER_MM)*(MU0*GAUSS_PER_TESLA)
  bz = bz + (Mz/M_PER_MM)*(MU0*GAUSS_PER_TESLA)

  return bx,by,bz
end

function segment.flym()
  -- Optionally force idealized magnetization.
  --[[
  local Mr = 1 -- A/mm
  local k = 2
  local Ri,Ro = 40,60
  for x,y,z in Mxinst.pa:points() do
    local xc,yc,zc = x+0.5,y+0.5,z+0.5  -- cell centered
    local rc = math.sqrt(xc^2+yc^2)
    local phi = math.atan2(yc,xc)
    local Mx =  Mr * math.sin(k*phi)
    local My = -Mr * math.cos(k*phi)
    if rc < Ri or rc > Ro then Mx,My = 0,0 end
    Mxinst.pa:potential(x,y,z, Mx)
    Myinst.pa:potential(x,y,z, My)
  end
  --]]

  -- Compute -div M.  Note: the negative gradient can be reused for this calculation.
  for x,y,z in jinst.pa:points() do
    local fixup = (-1)*(-1) / Mxinst.pa.ng
    local dMx_dx, _, _ = Mxinst.pa:field_vc(x,y,z)
    local _, dMy_dy, _ = Myinst.pa:field_vc(x,y,z)
    dMx_dx = dMx_dx * fixup  -- convert to A/mm^2
    dMy_dy = dMy_dy * fixup
    local dMz_dz = 0
    local j = dMx_dx + dMy_dy + dMz_dz  -- div M  (A/mm^2)
    jinst.pa:potential(x,y,z, j)
  end

  -- Solve for mu0*H.
  inst.pa:refine{charge=jinst.pa, convergence=1e-7}

  -- Plot B-field(s).
  simion.redraw_screen()  
  CON.plot{{func=Mfield, color=3}, mark=true,npoints=40, vscale=0.7}
  CON.plot{{func=bfield, color=1}, mark=true,npoints=30}
  
  run() -- continue any runs
end
