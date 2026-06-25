--[[
 sector_3dp.lua - workbench user program for sector_3dp.iob.
 See README.html for a summary of what this does.
 
 D.Manura, 2012-02.
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

-- Draws cross centered at point (x,y,z).  Also prints it and stores in table.
local point = {}
local function mark_point(x,y,z, name, color) -- plot point.
  print('mark:'..tostring(name), x,y,z)
  local d = 5
  color = color or 10 -- orange
  simion.experimental.plot_line_segment(x-d,y,z, x+d,y,z, 0,0, color,color)
  simion.experimental.plot_line_segment(x,y-d,z, x,y+d,z, 0,0, color,color)
  simion.experimental.plot_line_segment(x,y,z-d, x,y,z+d, 0,0, color,color)
  if name then point[name] = {x,y,z} end -- store
end

-- Rotates vector CCW around X (looking down positive X axis)
local function x_rotate(theta, x, y, z)
  local sint, cost = math.sin(theta), math.cos(theta)
  local yb = cost * y - sint * z
  local zb = sint * y + cost * z
  return x, yb, zb
end

-- Trigonometric functions in terms of degrees (not radians).
local function sind(x) return sin(rad(x)) end
local function cosd(x) return cos(rad(x)) end
local function tand(x) return tan(rad(x)) end


-- Load geometric parameters from last GEM -> PA conversion.
local phi
local rm
local n
local epsilon
local yorigin
local function load_params()
  local t = dofile 'params.txt'
  for k,v in pairs(t) do print(k,'=',v) end
  phi = t.phi
  rm = t.rm
  n = t.n
  epsilon = t.epsilon
  yorigin = t.yorigin
  simion.wb.instances[1].oy = yorigin  -- set PA instance origin.
end
load_params()


--[[
 These equations are based on Liebl Section 3.3 "Axial Focusing with
 Uniform Magnetic Sector Field".
--]]
local function calc_inclined()
  print 'focus for inlined boundaries'
  local epsilon1 = epsilon
  local epsilon2 = epsilon
  local Omega = phi - epsilon1 - epsilon2
  local f  = rm*cosd(epsilon1)*cosd(epsilon2)/sind(Omega)
  local g1 = rm*cosd(epsilon1)*cosd(phi-epsilon2)/sind(Omega)
  local g2 = rm*cosd(epsilon2)*cosd(phi-epsilon1)/sind(Omega)
  local p1 = f - g1
  local p2 = f - g2
  local L = 2*f  -- assume L1=L2 in Eq 3.8
  local enter_y = rm*sind(45-phi/2)
  local enter_z = rm*cosd(45-phi/2)
  mark_point(0,enter_y,enter_z, 'enter')
  local exit_y = rm*sind(45+phi/2)
  local exit_z = rm*cosd(45+phi/2)
  mark_point(0,exit_y,exit_z, 'exit')
  local obj_y = enter_y + (L-p1)*sind(-90+45-phi/2)
  local obj_z = enter_z + (L-p1)*cosd(-90+45-phi/2)
  mark_point(0,obj_y,obj_z, 'object')
  local img_y = exit_y + (L-p2)*sind(90+45+phi/2)
  local img_z = exit_z + (L-p2)*cosd(90+45+phi/2)
  mark_point(0,img_y,img_z, 'image')
  
  local B = 100 -- Gauss
  local mass = 100 -- ion mass, u
  local ke = (rm*0.1*B/143.6)^2/mass  -- Eq 3.2, eV
  print('ke:', ke, 'for mass:', mass)
end


--[[
 These equations are based on Liebl Section 3.4 "Non-Uniform
 Magnetic Sector Fields" in the special case n=1/2 (stigmatic focusing).
--]]
local function calc_conical()
  print 'focus for conical poles'
  local fr = rm * sqrt(2) / sind(phi/sqrt(2)) -- Eq 3.25
  local gr = rm * sqrt(2) / tand(phi/sqrt(2))
  local pr = rm * sqrt(2) * tand(phi/sqrt(8))
  local nu =      sqrt(0.5)*sind(phi/sqrt(2))
  local l  = rm * sqrt(2) / tand(phi/sqrt(8))
  print('fr', fr)
  print('gr', gr)
  print('pr', pr)
  print('nu', nu)
  print('l', l)

  local enter_y = rm*sind(45-phi/2)
  local enter_z = rm*cosd(45-phi/2)
  mark_point(0,enter_y,enter_z, 'enter')
  local exit_y  = rm*sind(45+phi/2)
  local exit_z  = rm*cosd(45+phi/2)
  mark_point(0,exit_y,exit_z, 'exit')
  local obj_y = enter_y + l*sind(-90+45-phi/2)
  local obj_z = enter_z + l*cosd(-90+45-phi/2)
  mark_point(0,obj_y,obj_z, 'object')
  local img_y = exit_y  + l*sind(90+45+phi/2)
  local img_z = exit_z  + l*cosd(90+45+phi/2)
  mark_point(0,img_y,img_z, 'image')
   
  local B = 100 -- Gauss
  local mass = 100 -- ion mass, u
  local ke = (rm*0.1*B/143.6)^2/mass  -- Eq 3.2, eV
  print('ke:', ke, 'for mass:', mass)
end


--[[
 Calculate various theoretical focal parameters for current geometry.
--]]
local function calc()
  local xc,yc,zc = 0, rm/sqrt(2), rm/sqrt(2)
  if simion.wb.instances[1].field_wc then  -- only in >= 8.1.1.0
    print('B-field center:', simion.wb.instances[1]:field_wc(xc,yc,zc))
  end
  print('yorigin:', yorigin)
  mark_point(xc,yc,zc, 'B measure')
  mark_point(0,0,0, 'center of curvature')
  if n == 0 then
    calc_inclined()
  elseif epsilon == 0 then
    calc_conical()
  else
    print('focal properties for both n and epilson non-zero are not known')
  end
end


-- Impose x antimirroring on magnetic scalar potential defined with x mirroring.
function segment.mfield_adjust()
  if ion_px_gu < 0 then
    ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu
      = -ion_bfieldx_gu, -ion_bfieldy_gu, -ion_bfieldz_gu
  end
end


-- called on start of each run.
function segment.initialize_run()
  calc()
end


--[[
 Any particles with undefined starting point (origin) will be repositioned
 to correct object location for sector.
 IMPROVE? simplify? and handle case of particles originating outside PA instances.
--]]
function segment.initialize()
  if ion_px_mm == 0 and ion_py_mm == 0 and ion_pz_mm == 0 and point.object then
    ion_px_mm,ion_py_mm,ion_pz_mm = unpack(point.object)
    ion_vx_mm,ion_vy_mm,ion_vz_mm = x_rotate(rad(phi/2-45), ion_vx_mm,ion_vy_mm,ion_vz_mm)
  end
end


--[[
 Recreate PA from GEM file by entering "regenerate()" in command bar.
 Warning: this is not guaranteed to be safe yet.
--]]
function _G.regenerate()
  if not simion.wb.instances[1]._debug_update_size then
    error('This function requires SIMION >= 8.1.1.0')
  end
  simion.command 'gem2pa sector_3dp.gem'  --IMPROVE: avoid saving to disk
  local pa = simion.wb.instances[1].pa
  pa:load()
  simion.wb.instances[1]:_debug_update_size() -- FIX: shouldn't be necessary
  pa:refine{convergence=1e-3}
  --unused: for x,y,z in pa:points() do if x == 0 then pa:electrode(x,y,z, false) end end
  simion.redraw_screen()
  load_params()
  calc()
end


--[[
 Gets angle (-180 to 180 degrees) of current particle with respect
 to line bisecting sector.
--]]
local function phi_ion()
  return (deg(atan2(ion_py_mm, ion_pz_mm)) - 45 + 180) % 360 - 180
end


--[[
 Debugging (normally disabled).
 Artificially impose a uniform field inside the sector
 and zero field outside (sharp cut-off, no fringe fields).
--]]
--[[
function segment.mfield_adjust()
  if abs(phi_ion()) <= phi/2 then
    ion_bfieldx_gu,ion_bfieldy_gu,ion_bfieldz_gu = -100,0,0
  else
    ion_bfieldx_gu,ion_bfieldy_gu,ion_bfieldz_gu = 0,0,0
  end
end
--]]


--[[
 Debugging (normally disabled).
 Artificially zero certain components of the B-field.
 Note: Bx actually extends slightly outside of sector.
--]]
--[[
local old = segment.mfield_adjust or function()end
function segment.mfield_adjust()
  old()
  -- ion_bfieldy_gu = 0; ion_bfieldz_gu = 0
  if abs(phi_ion()) > phi/2 then
    ion_bfieldx_gu = 0
  end
end
--]]


--[[
 Optional: Change points on x=0 plane (Dirichlet boundary condition)
 to electrodes (ele = true) or non-electrodes (ele = false).
 This is merely intended to improve visualization.
 WARNING: but this negatively affects field accuracy on this plane, so
 you might not want to use it when calculating trajectories.
 TODO: This may be removed one SIMION natively supports anti-mirroring.
--]]
function _G.plane(ele)
  local pa = simion.wb.instances[1].pa
  for y=0,pa.ny-1 do for z=0,pa.nz-1 do
    pa:electrode(0,y,z, ele)
  end end
  simion.redraw_screen()
end
