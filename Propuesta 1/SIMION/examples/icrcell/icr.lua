--[[
 icr.lua - SIMION workbench user program for ICR

 (c) 2006-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
--]]

simion.workbench_program()

---- Voltage/Field control
adjustable start_rht_voltage = 5     -- starting right end voltage
adjustable capture_voltage   = 3     -- endcap capture voltage
adjustable rf_voltage        = 20    -- peak voltage on rf plates for excite phase
adjustable bx_gauss          = 30000 -- magnetic field in gauss
adjustable starting_mass_amu = 950   -- lower mass for rf sweep
adjustable ending_mass_amu   = 1050  -- upper mass for rf sweep
adjustable rf_sweep_time_usec= 100   -- rf sweep time in usec
adjustable start_delay_usec  = 80    -- time delay before starting rf sweep
adjustable max_time_usec     = 1000  -- stop simulation after this time (microsec)

---- PE surface display
adjustable pe_update_each_usec = 1.0 -- pe surface update time step in usec

-- Static variables 
local t_delay_usec = start_delay_usec   -- time delay before starting rf sweep
local t_excite_usec = t_delay_usec + rf_sweep_time_usec   -- time at end of excite phase
local tmark = 1000   -- time for next transition
local color = 1      -- ion color after transition

-- On IOB load, enable Grouped flying and T.Qual = 0 by default.
function segment.load()
    sim_grouped = 1
    sim_trajectory_quality = 0
end

-- SIMION time_step adjust segment.  Called to override time-step size. 
function segment.tstep_adjust()
    -- End time-steps precisely on transitions (for improved accuracy).
    -- Also change ion color at transitions.
    if ion_time_of_flight < t_delay_usec then
        tmark = t_delay_usec
        color = 1                       -- next color is red
        ion_time_step = min(ion_time_step, tmark - ion_time_of_flight)
    else
        color = 2                       -- next color is green
        tmark = t_excite_usec
        --test for sweep stop transition
        if ion_time_of_flight < tmark then
            ion_time_step = min(ion_time_step, tmark - ion_time_of_flight)
        end
    end
end       

-- SIMION fast_adjust segment.  Called to modify electrode voltages.  
-- Controls ICR cell voltages.
function segment.fast_adjust()
    local base_rf = (bx_gauss / 10000)  -- convert magnetic field to tesla
                  * 1.6022E-19 / 1.6605E-27 / 1E6
    local starting_rf = base_rf / starting_mass_amu -- start mass freq. for sweep
    local ending_rf   = base_rf / ending_mass_amu   -- end mass freq. for sweep
    local rf_slope = (ending_rf - starting_rf) / rf_sweep_time_usec
                         -- RF sweep slope (rate of frequency change)
  
    if ion_time_of_flight <= t_delay_usec then  -- initial
        -- set elect 1-4 to half of right voltage
        adj_elect01 = start_rht_voltage / 2
        adj_elect02 = adj_elect01
        adj_elect03 = adj_elect01
        adj_elect04 = adj_elect01
        adj_elect05 = 0                    -- left entrance
        adj_elect06 = start_rht_voltage    -- right entrance
    elseif ion_time_of_flight > t_excite_usec then  -- end of rf sweep time
        -- set electrode voltages
        adj_elect01 = 0
        adj_elect02 = 0
        adj_elect03 = 0
        adj_elect04 = 0
        adj_elect05 = capture_voltage
        adj_elect06 = capture_voltage
    else
        -- calculate omega for rf voltage calculation
        local omega = (ion_time_of_flight - t_delay_usec) * rf_slope + starting_rf
 
        -- calculate rf voltage for exciter plates
        adj_elect01 = sin(omega * (ion_time_of_flight - t_delay_usec))
                      * rf_voltage
        adj_elect02 = -adj_elect01
        adj_elect03 = 0
        adj_elect04 = 0
        adj_elect05 = capture_voltage
        adj_elect06 = capture_voltage
    end
end

-- SIMION mfield_adjust segment.  Called to override magnetic field.
function segment.mfield_adjust()
    -- Impose uniform magnetic field.
    ion_bfieldx_gu = bx_gauss
    --ion_bfieldy_gu = 0
    --ion_bfieldz_gu = 0
end

-- SIMION other_actions segment.  Called on each time-step.
local last_pe_update = 0   -- time of last PE update
function segment.other_actions()
    -- update PE surface display
    if abs(ion_time_of_flight - last_pe_update) >= pe_update_each_usec then
        last_pe_update = ion_time_of_flight
        sim_update_pe_surface = 1      -- request a pe surface update
    end
    -- transition color control
    if ion_time_of_flight == tmark then
        ion_color = color           -- set ion's after transition color
    end

    -- Prematurely stop simulation.
    if ion_time_of_flight > max_time_usec then
        ion_splat = 1
        print('prematurely stopping particle', ion_number, '(t > max_time_usec)')
    end
end

