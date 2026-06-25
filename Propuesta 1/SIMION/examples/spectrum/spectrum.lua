--[[
 spectrum.lua
 SIMION workbench user program, illustrating how to aquire a spectrum
 by performing multiple reruns, each at a different electrode voltage,
 and counting the number of particles that are accepted.
 Multiple scans can be done, and the cumulative spectrum can be displayed
 interactively (e.g. in Excel or gnuplot).
 
 D.Manura, 2012-12-22, 2011-11.
 (c) 2011-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

adjustable Estart = 1450    -- Starting energy to scan for
adjustable Eend   = 1700    -- Ending energy to scan for
adjustable nsteps = 26      -- Number of steps in scan
adjustable nscans = 5       -- Number of scans
adjustable plot_frequency = 3  -- how often to plot spectrum:
                               -- 0=never, 1=last scan, 2=every scan,
                               -- 3=every step of every scan
adjustable plot_type = 1       -- 0=scatter,1=bar,2=area
adjustable use_plot = 1        -- 1=use, 0=do not use plotting program
adjustable pause_seconds = 0   -- pause in seconds between scans for easier viewing

adjustable exit_width = 4      -- size of exit width, mm (changing this will force a PA regeneration)
adjustable entrance_width = 4  -- size of entrance width, mm (changing this will force a PA regeneration)

-- Change these if you change geometry dimensions or particle charge.
local d0 = 50      -- distance between plates (must have same units as x0)
local x0 = 160     -- distance between slits
local q0 = -1      -- elementary charge (e) to scan, typically -1 for electrons


-- Gets scan energy (eV) at step number i.
local function energy_from_step(i)
    return Estart + (Eend - Estart) * (i-1) / (nsteps-1)
end

-- Gets plate voltage difference required for scan energy (eV).
-- This is the theoretical equation for a PPA.
local function volts_from_energy(eV)
    return ((1/q0)*2*d0/x0) * eV
end

-- Load plotting library.
local PLOT = simion.import '../plot/plotlib.lua'

-- These variables are updated during the runs.
local iscan = 0    -- Current scan number, [0..nscans)
local istep = 0    -- Current step number in scan, [0..nsteps)
local counts = {}  -- Particle counts for each step (cumulative over all scans)
local count        -- Particle count in current step (or run).

-- Plots scan data from counts table.
local myplot
local function plot_it()
    if use_plot ~= 0 then
        -- Plot.
        local table = {header={'eV', 'count'}, title='scan',
                       chart_type=(plot_type==0 and 'scatter' or
                                   plot_type==1 and 'bar_vertical' or 'area') }
        for i=1, nsteps do
            table[i] = {energy_from_step(i), counts[i] or 0}  --[4]
        end
        if not myplot then  -- first plot
            myplot = PLOT.plot(table)
        else
            myplot:update_data(table)
        end
        myplot:title('sum of scans\n 1..' .. iscan .. ', ' .. os.date() ..
                     ', entrace_width=' .. entrance_width .. ', exit_width=' .. exit_width)
    else
        -- Output to log window.
        for i=1, nsteps do
            print(('eV=%f,count=%d'):format(energy_from_step(i), counts[i] or 0))
        end
    end
end

-- Recreates PA from GEM file if specified electrode dimensions have changed.
local function regenerate(force)
  local inst = simion.wb.instances[2]
  
  -- We want to avoid unnecessarily regenerating the PA because doing so
  -- causes a Refine, and for larger PA's the Refine might take a long time.
  -- The PA needs to be regenerated only if the electrode dimensions used in
  -- creating the PA don't match the latest dimensions specified by the user.
  -- A convenient technique for determining whether these match
  -- is to embed the dimensions in the PA file name whenever
  -- the PA is regenerated.  At any later time when we need to ensure
  -- that the dimensions in the PA are up-to-date (e.g. when starting
  -- another Fly'm), we generate the PA if and only if the dimensions
  -- specified by the user are found to not match the PA file name.
  local basename = 'ppa2d_slits-'..entrance_width..'-'..exit_width

  -- Skip regeneration if PA already has required dimensions.
  if not force and inst.pa.filename == basename..'.pa0' then
    return
  end

  local GEM = simion.import 'gemlib.lua'
  GEM.update_painst_from_gem(inst, 'ppa2d_slits.gem', '', {
    entrance_width=4, entrance_width=entrance_width, exit_width=exit_width
  })
  inst.pa.filename = basename..'.pa#'
  inst.pa:refine{convergence=1E-7}
end

-- called on Fly'm to invoke a series of runs by calling `run()`. [1]
local first_time_step
function segment.flym()
    sim_trajectory_image_control = 1 -- don't retain trajectories

    -- Regenerate PA's if dimensions in GEM have changed.
    regenerate()

    -- Do scans...
    for _iscan = 1, nscans do
        -- Optionally alternate between forward and reverse scans for a bit
        -- more realism.
        local is_reversed = (_iscan % 2 == 0)  -- even scans are reversed
        local istep_first = is_reversed and nsteps or 1
        local istep_last  = is_reversed and 1 or nsteps
        local istep_delta = is_reversed and -1 or 1

        -- Step the voltage on each scan...
        for _istep = istep_first, istep_last, istep_delta do

            -- Setup parameters for this scan.
            first_time_step = true
            count = 0
            iscan = _iscan
            istep = _istep

            -- Perform trajectory calculation run.
            run()

            -- Display status.
            print(('scan=%d,step=%d,eV=%d,count=%d'):format(
                   iscan, istep, energy_from_step(istep), count))

            -- Store count for future reporting.
            counts[istep] = (counts[istep] or 0) + count

            -- Optional plot after each step.
            if plot_frequency >= 3 then plot_it() end

            -- Optional delay between scans (for easier visualization).
            simion.sleep(pause_seconds)

        end -- each step

        -- Optional plot after each scan.
        if plot_frequency == 2 then plot_it() end

    end -- each scan
  
    -- Optional plot after all scans.
    if plot_frequency == 1 then plot_it() end

    -- Do one last run, preserving trajectories.
    sim_trajectory_image_control = 0 -- retain trajectories
    run()

    sim_retain_changed_potentials = 1 -- keep tuned potentials
end


-- called exactly once on start of each run. [1,2]
function segment.initialize_run()
end


-- called whenever electrode potentials needed.
function segment.fast_adjust()
    adj_elect02 = volts_from_energy(energy_from_step(istep))
end


-- called on every time-step.
function segment.other_actions()
    -- Update PE surface display (optional, does not affect calculation).
    if first_time_step then  -- only at start of new run [6]
        first_time_step = false
        sim_update_pe_surface = 1
    end
end


-- called on each particle termination in a PA. [1,2]
function segment.terminate()
    -- Avoid double counting splats inside magnetic arrays. [5]
    if simion.wb.instances[ion_instance].pa.potential_type == 'electric' then
        -- Count how many particles are accepted in this run.
        if ion_py_mm > -5 and ion_py_mm < -2 then -- hitting detector
            count = count + 1
        end
    end
end


-- called exactly once on end of each run. [1,2]
function segment.terminate_run()
end

-- This allows regenerate() to be executed at anytime from the SIMION command bar,
-- if need be.
_G.regenerate = regenerate

--[[
 Footnotes:
  [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
      See "Workbench Program Extensions in SIMION 8.1" in the supplemental documentation
      (Help menu).
  [2] The initialize_run/terminate_run segments are
      called exactly once when the run starts/stops (just before/after any
      initialize/terminate segment calls).  On the other hand, the
      initialize or terminate segments are only called for a particle when the
      particle respectively starts or splats inside a PA instance (if ever).
  [3] ion_run is a positive integer rerun number.  Requires SIMION >= 8.1.0.
  [4] `or 0` avoids passing `nil` to Excel (causing a type conversion error)
  [5] If a particle may terminate inside both magnetic and electric
      arrays, the terminate segment will be called twice, once for each,
      which will cause double counting.  We should only count terminates for the
      electric array since the large electric blank.pa always ensures particles
      are termined in an electric array.
  [6] Voltages are constant during each run, so it is sufficient (and more
      efficient) to update PE display only on the first time-step of each run.
--]]
