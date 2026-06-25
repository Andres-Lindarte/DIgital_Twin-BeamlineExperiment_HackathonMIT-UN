--[[
 bngrid.lua
 Lua workbench user program for controlling a Bradbury-Nielsen grid.
 
 A special technique is used here to make the fields match up between
 the fine and coarse PA instances, even when RF voltages are being applied
 in the PA instances.
 This is done by defining Dirichlet conditions (expressed in SIMION as
 electrodes) on the edges of both PA instances and using this user program
 to appropriately set potentials on those boundary conditions so that
 the fields are the same on both sides of those boundary conditions,
 over all time.

 D.Manura, 2012-06,2008-05
 (c) 2008-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()
assert(simion.pas, 'SIMION 8.1 required for this example')

-- Period of gate RF in microseconds.
adjustable period_usec = 1

-- Amplitude of gate RF in volts.
adjustable amplitude = 5

--[[
 Returns the required potential (v) to apply to electrodes electrode1
 and electrode2 in PA instance objects instance1 and instance2 respectively
 so that fields would match up at points (x1,y1,z1) and (x2,y2,z2) mm
 (in workbench coordinates) inside the respective PA instances.
 Normally, you want these two points to be at the same location,
 but they will need to differ slightly if the insides of the
 two PA instances don't overlap.

 t1 and t2 are tables that map electrode numbers to desired
 potentials for the two respective PA instances.
 These potentials will be assumed when matching up the fields.
 Warning: t1[electrode1] and t2[electrode2] will be modified.

 Warning: A side effect of this function is that electrode solution
 arrays not identified in t1 and t2 nor as electrode1 and electrode2
 are unloaded from memory.  This can cause severe performance
 degradation if not paid attention to.
--]]
local function match_fields(instance1, instance2, electrode1, electrode2,
                            x1,y1,z1, x2,y2,z2, t1, t2)

  --[[
   We require that the potentials and fields in
   the two joined arrays are identical on the two points: V1 = V2 and
   E1 = E2.  Because fields are additive (superposition), we know
     E1 = E1a + (E1b - E1a)*V1 and E2 = E2a + (E2b - E2a)*V2,
   where E1a and E2a are the fields observed when fast adjusting V=0, and
   E1b and E2b are the fields observed when fast adjusting V=1 volt.
   That can be solved for v = V1 = V2.
  --]]

  -- Measure fields at both points, for both 0V and 1V applied to electrodes.
  t1[electrode1] = 0
  local e1ax,e1ay,e1az = instance1:field_wc(x1,y1,z1, t1)
  t1[electrode1] = 1
  local e1bx,e1by,e1bz = instance1:field_wc(x1,y1,z1, t1)
  t2[electrode2] = 0
  local e2ax,e2ay,e2az = instance2:field_wc(x2,y2,z2, t2)
  t2[electrode2] = 1
  local e2bx,e2by,e2bz = instance2:field_wc(x2,y2,z2, t2)
  
  -- Difference in fields between points.
  local eax,eay,eaz = e1ax-e2ax,e1ay-e2ay,e1az-e2az  -- Ea=E1a-E2a
  local ebx,eby,ebz = e1bx-e2bx,e1by-e2by,e1bz-e2bz  -- Eb=E1b-E2b

  -- The vector equation to solve is
  --   Ea = v*(Ea - Eb),
  -- which represents three scalar equations and one scalar unknown (v),
  -- so it is overspecified.  If we do dot product multiplication of
  -- both sides by (Ea - Eb), this should preserve accuracy, while
  -- reducing to a single scalar equation.
  local ux,uy,uz = eax-ebx, eay-eby, eaz-ebz        -- Ea-Eb
  local eas = eax*ux + eay*uy + eaz*uz              -- Ea*(Ea-Eb)
  local ebs = ebx*ux + eby*uy + ebz*uz              -- Eb*(Ea-Eb)

  -- Solve for v.
  local v = eas / (eas - ebs)

  return v
end

-- PA instance objects
local instance1 = simion.wb.instances[1]
local instance2 = simion.wb.instances[2]

--[[
 Gets potentials (va, vb) for two boundaries
 such that fields match up across boundaries.
 t1 and t2 are tables of electrode potentials for PA
 instances 1 and 2 respectively.
--]]
local function match(t1,t2)
  local va = match_fields(instance1, instance2, 10,10,
                          92-0.001,0,0, 92+0.001,0,0, t1, t2)
  local vb = match_fields(instance1, instance2, 11,11,
                          108+0.001,0,0, 108-0.001,0,0, t1, t2)
  return va,vb
end

--[[
 The following "reset()" function can be called from the SIMION command-bar.
 It permanently changes boundary condition potentials, for viewing purposes,
 such that fields match.
--]]
function _G.reset()
  local va,vb = match({},{})
  instance1.pa:fast_adjust{[10] = va, [11] = vb}
  instance2.pa:fast_adjust{[10] = va, [11] = vb}
  simion.redraw_screen()
end


local TWO_PI = 2 * math.pi
local t1 = {[10]=0,[11]=0}
local t2 = {[10]=0,[11]=0}
local ts = {t1,t2}

function segment.fast_adjust()
  -- Define RF potentials.
  local dv = amplitude * sin(TWO_PI * ion_time_of_flight / period_usec)
  t2[1] = 10 + dv
  t2[2] = 10 - dv
  
  -- Given above potentials, calculate potentials for boundary
  -- conditions necessary to match fields across those boundaries.
  local va,vb = match(t1, t2)
  t1[10] = va; t2[10] = va
  t1[11] = vb; t2[11] = vb

  -- Apply potentials.
  local t = ts[ion_instance]
  for k,v in pairs(t) do adj_elect[k] = v end
end

local lasts, last = {true,true}, -math.huge
function segment.other_actions()
  -- Periodically update PE surface.  It can be computationally
  -- intensive if this were instead done on every time-step.
  if abs(ion_time_of_flight - last) > period_usec/8 then
    last = ion_time_of_flight
    lasts[1] = true; lasts[2] = true
  end
  if lasts[ion_instance] then
    lasts[ion_instance] = false
    sim_update_pe_surface = 1
    --print('update', ion_instance, ts[ion_instance][10], ts[ion_instance][11])
  end
end

-- Optionally, force step time steps to not exceed a fraction of RF period.
function segment.tstep_adjust()
  ion_time_step = math.min(ion_time_step, period_usec/20)
end
