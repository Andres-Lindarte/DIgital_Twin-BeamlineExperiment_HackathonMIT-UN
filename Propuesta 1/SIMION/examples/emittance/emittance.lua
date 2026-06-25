-- emittance.lua
-- SIMION 8 user program to calculate emittance of beam at the splat location.
--
-- The program is designed to monitor ions (mass > 1 amu), and ignore electrons.
--
-- Author: Based on PRG code by Justin R. Carmichael 2006-08-06.
--         Converted to Lua by David Manura 2006-08-09.
simion.workbench_program()

-- various arrays to store variables on each particle
local y = {}        -- y positions (mm)
local yprime = {}   -- y' (radians)
local vx = {}       -- x-velocity (mm/usec)
local vy = {}       -- y-velocity (mm/usec)

-- Compute y-emittance from points in phase space.
-- parameters:
--   y - array of y points (mm)
--   yprime - array of angles (radians)
--   vx - array of x-velocities
--   vy - array of y-relocities
-- returns
--   emit - emittance
--   norm_emit - normalized emittance
function compute_emittance(y, yprime, vx, vy)
    -- Compute average of all numbers in given array.
    -- Returns 0 if array contains zero elements.
    function average(array)
        local result = 0
        for _,a in ipairs(array) do result = result + a end
        if #array ~= 0 then result = result / #array end
        return result
    end

    -- Compute various averages for emittance.
    local y_ave = average(y)
    local yprime_ave = average(yprime)
    local t = {}; for n = 1,#y do t[n] = (y[n] - y_ave)^2 end
    local dy2_ave = average(t)
    local t = {}; for n = 1,#y do t[n] = (yprime[n] - yprime_ave)^2 end
    local dyprime2_ave = average(t)
    local t = {}; for n = 1,#y do t[n] = (y[n]-y_ave)*(yprime[n]-yprime_ave) end
    local dy_dyprime_ave = average(t)

    -- Compute emittance from averages, in correct units.
    local m = dy2_ave * dyprime2_ave - dy_dyprime_ave^2
    if m < 0 then m = 0 end      -- safety on numerical roundoff
    local emit = sqrt(m) * 1000  -- (mm * mrad)

    -- Compute average speed for normalized emittance.
    local vx_avg = average(vx)
    local vy_avg = average(vy)
    local v_avg = sqrt(vx_avg^2 + vy_avg^2)
    --FIX: or this:
    --local t = {}; for n = 1,#y do t[n] = sqrt(vx[n]^2 + vy[n]^2) end
    --local v_avg = average(t)

    -- compute normalized emittance from averages
    local c = 300000                    -- speed of light (mm/usec)
    local beta = v_avg / c              -- relativistic beta
    local gamma = 1 / sqrt(1 - beta^2)  -- relativistic gamma
    local norm_emit = beta * gamma * emit

    return emit, norm_emit   
end

-- SIMION segment called on every time-step
function segment.other_actions()
    if ion_mass < 1   then return end -- skip if not ion (amu < 1)
    if ion_splat == 0 then return end -- skip if ion not yet splatted.

    -- store variables for emittance calculation
    local particle_count = #y + 1
    y[particle_count] = ion_py_mm    -- store y position (mm)
    vx[particle_count] = ion_vx_mm   -- store x-velocity (mm/usec)
    vy[particle_count] = ion_vy_mm   -- store y-velocity (mm/usec)
    yprime[particle_count] = ion_vy_mm / ion_vx_mm  -- store ~tan(theta) (rad)
    -- FIX? or this: yprime[particle_count] = atan2(ion_vy_mm, ion_vx_mm)

    --print(particle_count .. "," .. y[particle_count] .. "," .. yprime[particle_count])
end

-- Called on end of run.
function segment.terminate_run()
    -- calculate/display emittance
    print("Num particles = " .. #y)
    local emit, norm_emit = compute_emittance(y, yprime, vx, vy)
    print("Beam Emittance = " .. emit .. " mm * mrad (Normalized = " .. norm_emit .. ")")
end


--[[
Footnotes:
  The terminate_run segment, new in SIMION 8.1.0.32, is called exactly once
  when the run completes (just after any terminate segment calls).
--]]
