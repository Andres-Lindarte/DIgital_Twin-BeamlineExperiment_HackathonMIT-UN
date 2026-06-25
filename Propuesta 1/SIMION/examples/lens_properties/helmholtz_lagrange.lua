--[[
 helmholtz_lagrange.lua - SIMION Lua workbench user program.
 Demonstrates Helmholtz-Lagrange Law.

 D.Manura, 2011-11-30,2007-10-03
 (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
--]]

simion.workbench_program()


--## SECTION: ADJUSTABLE AND SYSTEM VARIABLES


-- Number of second ray.
-- Directed from object window top to object pupil center.
local ray1 = 6

-- Number of second ray.
-- Directed from object window top to object pupil top.
local ray2 = 9


--## SECTION: SIMION SEGMENTS


-- The following variables are updated by the SIMION segments during the Fly'm.
-- They are used for the calculation of lens properties for the current scan.

-- Position of object (mm)
local xp -- axial
local yp -- radial

-- Position of image (mm)
local xq -- axial
local yq -- radial

-- Position of rays (1 and 2) upon termination (mm)
-- Used to determined (xq,pq).
local x1t,x2t -- axial
local y1t,y2t -- radial

-- Beam angle (relative to axis) of rays (1 and 2) (mm)
local alpha1p,alpha2p -- object
local alpha1q,alpha2q -- image

-- Ray energies (eV)
local Vp -- object
local Vq -- image


-- Get kinetic energy of current particle.
-- Intended to be called from initialize, other_actions, or terminate segments.
local function get_ke()
  local speed = math.sqrt(ion_vx_mm^2+ion_vy_mm^2+ion_vz_mm^2)
  return speed_to_ke(speed, ion_mass)
end

-- called on each particle creation inside PA instance.
function segment.initialize()
  --print('DEBUG', ion_number, ion_py_mm, ion_vy_mm)
  if ion_number == ray1 then
    assert(ion_py_mm > 0 and ion_vy_mm < 0)
    xp = ion_px_mm
    yp = ion_py_mm
    alpha1p = ion_vy_mm / ion_vx_mm
    Vp = get_ke()
  elseif ion_number == ray2 then
    assert(ion_px_mm == xp)
    assert(ion_py_mm == yp)
    assert(get_ke() == Vp)
    alpha2p = math.atan(ion_vy_mm / ion_vx_mm)
  end
end

-- called on each particle termination inside PA instance.
function segment.terminate()
  assert(alpha1p and alpha2p)
  if ion_number == ray1 then
    -- Store ray 1 data at termination.
    x1t = ion_px_mm
    y1t = ion_py_mm
    alpha1q = ion_vy_mm / ion_vx_mm
    Vq = get_ke()
  elseif ion_number == ray2 then
    -- Store ray 2 data at termination.
    x2t = ion_px_mm
    y2t = ion_py_mm
    alpha2q = ion_vy_mm / ion_vx_mm

    -- Extrapolate termination data to image plane data
    -- by solve for intersection of rays (x,y) = (xq, yq):
    -- yq = alpha1q * (xq - x1t) + y1t
    --    = alpha2q * (xq - x2t) + y2t
    -- This assumes the region from the image plane to
    -- termination is field-free (straight line paths)
    xq = (alpha1q * x1t - alpha2q * x2t + y2t - y1t)
       / (alpha1q - alpha2q)
    assert(xp, "rays did not intersect")
    yq = alpha1q * (xq - x1t) + y1t

    -- Compute final lens parameters.
    -- Pencil angles at object and image (in rad)
    local theta_p = math.abs(alpha2p - alpha1p)
    local theta_q = math.abs(alpha2q - alpha1q)
    local M = yq/yp  -- linear magnification
    local m = -theta_q/theta_p -- angular magnification

    -- Display results.
    print('P=object location, Q=image location')
    print('xp=', xp, 'yp=', yp)
    print('xq=', xq, 'yq=', yq)
    print('theta_p=', theta_p, 'theta_q=', theta_q)
    print('Vp=', Vp, 'Vq=', Vq)
    print('M=yq/yp=', M, 'm=-theta_q/theta_p=', m)

    print('Testing Helmholtz-Lagrange Law:')
    print('sqrt(Vp/Vq) / (M m)=', math.sqrt(Vp/Vq)/(M*m), '(expected = 1)')
  end
end

