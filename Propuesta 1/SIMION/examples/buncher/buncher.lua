--[[
 buncher.lua - Buncher electrode control

 This program controls the voltage on a buncher and also keeps
 the display up-to-date.

 (c) 2003-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
--]]

simion.workbench_program()

adjustable switch_time = 1.7      -- switch time (microseconds)
adjustable buncher_voltage = 900  -- buncher deceleration voltage

-- Adjust time step.
function segment.tstep_adjust()
    -- Let's make sure the time step ends right on the switch time
    -- when that time occurs.
    if ion_time_of_flight < switch_time then
        ion_time_step = min(ion_time_step, switch_time - ion_time_of_flight)
    end
end

-- Control buncher voltage: switch off voltage at switch time.
function segment.fast_adjust()
    adj_elect01 = ion_time_of_flight < switch_time and buncher_voltage or 0
end

-- Handle display updates.
local update_flag = 1         -- flag for updating PE surface display
function segment.other_actions()
    if switch_time == ion_time_of_flight then  -- (transition point)
        ion_color = 3         -- Set ion color to blue.
        mark()                -- Mark ion location.
        update_flag = 1       -- Trigger PE surface update at next time step.
    elseif update_flag == 1 then  -- (time step immediately after transition point)
        update_flag = 0
        sim_update_pe_surface = 1 -- Mark PE display for update.
    end
end

-- Calculate and display results and the end of simulation.
local first_ion = 0               -- flag for first ion
local max_time = 0                -- holds max tof
local min_time = 0                -- holds min tof
function segment.terminate()
    -- no printing for first ion
    if first_ion == 0 then
        first_ion = 1                -- flag first ion
        max_time = ion_time_of_flight
        min_time = ion_time_of_flight
    else
        -- compute if not first ion
        max_time = max(ion_time_of_flight, max_time)
        min_time = min(ion_time_of_flight, min_time)

        print("Avg TOF = " .. (max_time + min_time)/2 ..
              " Delta TOF = " .. (max_time - min_time) ..
              " usec")
    end
end
