--[[
 tune80.lua - lens tuning example.
 
 This is like tune.lua but uses a SIMION 8.0 compatible approach
 (without new segments).

 This focuses on ion #6.

 The electrode tuning resembles a binary search.  It searches for an
 electrode voltage that causes ions to hit within a certain radius.
 The search terminates when the goal is reached or the maximum permitted
 number of tries is exceeded.

 (c) 2006-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--]]

simion.workbench_program()

adjustable _abs_goal_for_y = 0.001   -- goal for abs(y) bounds
 
adjustable max_voltage = 1000        -- tuning voltage upper bound
adjustable min_voltage = 0           -- tuning voltage lower bound
 
adjustable max_tries = 20            -- rerun limit
adjustable run_number = 0            -- rerun counter
 
adjustable test_voltage = 900        -- electrode voltage (current run)
adjustable upper_volts = 0           -- last upper bound voltage
adjustable lower_volts = 0           -- last lower bound voltage
adjustable upper_y = 0               -- last upper y hit
adjustable lower_y = 0               -- last lower y hit

adjustable request_rerun = 1         -- flag: request a rerun
 
local update_pe = true               -- mark PE display update at start of
                                     --   each run.
 

-- Called on each particle creation inside PA instance.
function segment.initialize()
    -- Set initial voltages and control reflying.

    update_pe = true
    if run_number == 0 then
        test_voltage = min_voltage      -- setup voltage for first run
    end

    -- If the last run cleared the rerun flag, we'll disable further reruns.
    -- (The current run will still execute.)
    sim_rerun_flym = request_rerun
end
 
-- Called when SIMION needs electrode voltages (multiple times per time-step).
function segment.fast_adjust()
    adj_elect02 = test_voltage
end

-- Called on every time-step.
function segment.other_actions()
    -- Update PE surface display.
    if update_pe then
        update_pe = false
        sim_update_pe_surface = 1
    end
end
 
-- Called on each particle termination inside PA instance.
function segment.terminate()
    -- Tune at end of each fly.

    if ion_number ~= 6 then return end         -- tune only on ion --6

    run_number = run_number + 1 

    if run_number == 1 then

        -- save first run results
        upper_volts = test_voltage
        upper_y = ion_py_gu

        -- setup voltage for second run
        test_voltage = max_voltage

    elseif run_number == 2 then

        -- save second run results
        lower_volts = test_voltage
        lower_y = ion_py_gu

        if upper_y <= lower_y then  -- swap
            upper_volts, lower_volts = lower_volts, upper_volts
        end
 
        -- setup voltage for third run (mid-point)
        test_voltage = (min_voltage + max_voltage) / 2

    elseif run_number < max_tries then

        if ion_py_gu < 0 then   -- reverse tuning
            lower_volts = test_voltage
        else                    -- direct tuning
            upper_volts = test_voltage
        end

        if request_rerun == 1 then
            -- display results
            print("n = " .. run_number ..
                  ", y = " .. ion_py_gu ..
                  ", volts = " .. test_voltage) 
            -- goal reached?
            if _abs_goal_for_y < abs(ion_py_gu) then
                -- try again
                test_voltage = (lower_volts + upper_volts) / 2
            else
                print("Attained Tuning Goal of ", _abs_goal_for_y)
                print("Final Rerun to Save Trajectories")
                request_rerun = 0       --  flag termination
            end
        end

    else   -- run_number >= max_tries

        if request_rerun == 1 then
            print("Aborted: Hit Loop Limit")
        end
        request_rerun = 0       --  flag termination (if not already)

    end
end

