--[[
 cardinal_points.lua - SIMION Lua workbench user program.
 Calculates cardinal points of lens by ray tracing.

 D.Manura, 2011-11-30,2007-11.
 (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
--]]

simion.workbench_program()


--## SECTION: ADJUSTABLE AND SYSTEM VARIABLES


-- Lens diameter D (mm).
-- Some parameters are specified relative to lens diameter.
adjustable _D_mm = 100

-- Lens object position relative to the reference plane (x=0).
adjustable _P_D = -4  -- (units of D)


local lensutil = simion.import "lensutil.lua"
local detect_xcross = lensutil.detect_xcross
local detect_ycross = lensutil.detect_ycross
local move_ray      = lensutil.move_ray


--## SECTION: SIMION SEGMENTS


-- The following variables are updated by the SIMION segments during the Fly'm.
-- They are used for the calculation of lens properties for the current scan.

-- Note: reference plane is assumed at x=0 mm.

local H1 -- first principal plane (mm) relative to reference plane
local H2 -- second principal plane (mm) relative to reference plane
local Q  -- image position (mm) relative to reference plane
local F1 -- first focal point (mm) relative to H1
local F2 -- second focal point (mm) relative to H2

-- Radius (mm)
local r1   -- object
local r2   -- image

-- Potential in space (V)
local V1  -- in object plane
local V2  -- in image plane

-- Beam angle (relative to axis) of particle 1
local alpha1  -- in object plane
local alpha2  -- in image plane


-- called on each particle creation in PA instance
function segment.initialize()
  if ion_number == 1 then
    -- Particle #1 starts at the object, on-axis, and is directed
    -- at a small angle relative to the axis.
    assert(ion_py_mm == 0)
    assert(ion_vy_mm > 0)

    -- Variable object location.
    move_ray(_P_D*_D_mm, ion_px_mm)

    alpha1 = ion_vy_mm / ion_vx_mm
  elseif ion_number == 2 then
    -- Particle #2 (first principle ray) starts at the object,
    -- off-axis (positive y), and is direced parallel to the axis
    -- toward the object.
    assert(ion_py_mm > 0)
    assert(ion_vy_mm == 0)
    r1 = ion_py_mm
  elseif ion_number == 3 then
    -- Particle #3 (second principle ray) starts at the image,
    -- off-axis (negative y), and is directed parallel to the axis
    -- toward the image.
    -- Note: initial KE of particle is different from #1 and #2 since
    --       this starts in the image plane.
    assert(ion_py_mm < 0)
    assert(ion_vy_mm == 0)
  end
end

-- called on each time-step for every particle in PA instance
function segment.other_actions()
  local x = ion_px_mm > -399 and detect_ycross(0)

  if ion_number == 1 and x and not Q then
    Q = x
    alpha2 = ion_vy_mm / ion_vx_mm
  elseif ion_number == 2 and x and not F2 then
    F2 = x
    H2 = F2 + (ion_vx_mm/ion_vy_mm) * r1
  elseif ion_number == 3 and x and not F1 then
    F1 = x
    H1 = F1 + (ion_vx_mm/ion_vy_mm) * r2
  end

  if ion_number == 2 then
    local y = detect_xcross(Q)
    if y and not r2 then
      r2 = y
    end

    if not V1 then V1 = ion_volts end
  elseif ion_number == 3 then
    if ion_time_of_flight - ion_time_step == 0 then
      ion_py_mm = r2
    end
    if not V2 then V2 = ion_volts end
  end
end

-- called exactly one at end of each run
function segment.terminate_run()
  local P = _P_D * _D_mm
  local p = P - F1
  local q = Q - F2
  local f1 = F1 - H1
  local f2 = F2 - H2
  print('P=',P,'Q=',Q)
  print('F1=', F1, 'F2=', F2)
  print('H1=', H1, 'H2=', H2)
  print('p=', p, 'q=', q)
  print('f1=', f1, 'f2=', f2)
  local M = r2/r1
  print('M=r2/r1=', M)
  local M_a = alpha2/alpha1
  print('Ma=alpha2/alpha1=', M_a)

  print(' ')
  print('Consistency checks:')
  print('pq/(f1*f2) =', p*q/(f1*f2), '(expect 1 - Newton\'s relation)')
  print('M=-f1/p=', -f1/p, '(compare to above)')
  print('M=-q/f2=', -q/f2, '(compare to above)')
  local M_a = (-r1/r2)*(f1/f2)
  print('M_a=(-r1/r2)*(f1/f2)=', M_a, '(compare to above)')
  print('M*M_a=', M*M_a, '=-f1/f2=', -f1/f2,
        '=(V1/V2)^0.5=', (V1/V2)^0.5, '(Helmholtz-Lagrange)')
end


--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
