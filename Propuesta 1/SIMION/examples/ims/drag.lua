-- drag.lua - Stokes' Law damping to ion trajectories.
--
-- This program applies Stokes' Law[1] damping to ion trajectories.
-- By default, this program is coupled with a simple three element lens
-- for demonstration purposes.  See the user programming appendix of the
-- SIMION manual, particularly concerning the accel_adjust segment,
-- for more information.
--
-- == Discussion ==
-- 
-- A viscous fluid applies to the particle a force proportional
-- and opposite in direction to the particle's velocity.
-- Equivalently, we can think of this force as an acceleration
-- since F=m*a:
--
--   a_vis = -linear_damping * v
--
-- Here, a_vis is the component of acceleration due to viscosity.
-- linear_damping is the semi-empirical constant of proportionality
-- defined by Stokes' Law.  a_vis is added to the acceleration
-- a_sim (normally calculated by SIMION) from all other sources
-- to arrive at the total acceleration a:
--
--   a = a_vis + a_sim
--
-- A simple implementation would just add the factor a_vis to a_sim, calculating
-- a_vis by defining v as the velocity at the START of the time-step,
-- so that a_vis would represent the viscosity acceleration at the
-- START of the time-step.
--
-- However, during the time-step Delta(t), the particle's velocity is
-- expected to change slightly, and a_vis changes as well according to
-- the above equation.  As noted in the related discussion on the "accel_adjust"
-- segment in the SIMION User Manual, the speed and accuracy can be
-- improved if we let a_vis be the AVERAGE viscosity acceleration during the
-- time-step. This can be done by applying a correction factor as described below.
--
-- First, express the equation for a_vis in terms of differentials with respect
-- to time (t):
--
--   d(a_vis)/dt = -linear_damping * dv/dt = -linear_damping * a
--
-- Equivalently,
--
--   d(a_vis)/dt = -linear_damping * (a_vis + a_sim)
--
-- Assuming a_sim is relatively constant over the time-step,
-- we can then solve the above differential equation:
--
--   a(t) = exp(-linear_damping * t) * (-linear_damping * v(0) + a_sim)
--
-- The average value of "a" over the time-step is then
--
--   <a> = (1/Delta(t)) * integral[0..Delta(t)] a(t) dt
--       = (1/Delta(t)) *
--          integral[0..Delta(t)] exp(-linear_damping * t) * (-linear_damping * v(0) + a_sim) dt
--       = factor * (a_sim - linear_damping * v(0))
--
-- where
--
--   factor = (Delta(t) * linear_damping)^(-1) * (1 - exp(-linear_damping * Delta(t)))
--
-- This factor is typically close to 1.
--
-- HISTORY:
-- 2006-08 - ported to Lua D.J. manura. based on DRAG.PRG in SIMION 7.0 by
--           D.A.Dahl.
-- (c) 2006 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--
-- [1] Stokes Law: http://en.wikipedia.org/wiki/Stokes'_law
-- [2] Exponential decay: http://en.wikipedia.org/wiki/Exponential_decay
--=======================================================================
simion.workbench_program()

adjustable linear_damping = 0       -- linear damping time constant (usec^-1)
 

-- SIMION accel_adjust segment.  Called to override particle acceleration. 
function segment.accel_adjust()
    if ion_time_step  == 0 then return end   -- skip if zero time step
    if linear_damping == 0 then return end   -- slip if damping set to zero

    -- Compute correction factor.
    linear_damping = abs(linear_damping)          -- force damping factor positive
    local tterm = ion_time_step * linear_damping  -- time constant
    local factor = (1 - exp(-tterm)) / tterm      -- correction factor

    -- Compute new x, y, and z accelerations.
    -- This following the differential equation
    --   da/dt = -v*linear_damping
    -- with the correction factor for dt being finite.
    -- Note: ion_v[xyz]_mm is particle velocity in mm/usec.
    --       ion_a[xyz]_mm is particle acceleration in mm/usec^2.
    ion_ax_mm = factor * (ion_ax_mm - linear_damping * ion_vx_mm)
    ion_ay_mm = factor * (ion_ay_mm - linear_damping * ion_vy_mm)
    ion_az_mm = factor * (ion_az_mm - linear_damping * ion_vz_mm)
end
