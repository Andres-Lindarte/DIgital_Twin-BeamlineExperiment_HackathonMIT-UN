--[[
 spread.lua - SIMION workbench user program for measuring particle variations
 at each step in the trajectory integration.

 Grouped flying is required.
 See README.html for details.

 D.Manura, 2011-12-6
 (c) 2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.1/8.0)
--]]

simion.workbench_program()

-- Min and max range for x to search for best focus point in.
adjustable x_min = -200
adjustable x_max = 390

-- Whether to plot profiles: 0=no, 1=with Excel, 2=with gnuplot
adjustable plot = 1

-- Saved x,y,z positions and time t of all particles during current step.
-- Position of particle `i` is `xs[i],ys[i],zs[i],ts[i]` only if `found[i] == true`.
local found = {}
local xs = {}
local ys = {}
local zs = {}
local ts = {}

local max_ion   -- maximum ion number found.
local max_count = 0 -- max number of particles observed in step (safety check)
local did_header -- true iff table header has been printed

-- Copy of recorded data, for use in plotting (optional).
local data1 = {header={'x_ave','dr_max','dt_max*1000'}}

-- These are the lowest spatial (dr) and temporal (dr) variations observed
-- so far during the entire trajectory integration, along with corresponding
-- averaged x,y,z,t values.  Variations are measured both in terms of
-- maximum (max) and average (average) displacement magnitude from the
-- first-order moment.
local dr_max_best = {math.huge, nil, nil, nil, nil}
local dr_ave_best = {math.huge, nil, nil, nil, nil}
local dt_max_best = {math.huge, nil, nil, nil, nil}
local dt_ave_best = {math.huge, nil, nil, nil, nil}

-- More nicely formats a list of numbers in scientific notation, returning a string.
local function formatnums(...)
  local ts = {}
  for i=1,select('#',...) do
    ts[i] = ('%+0.3e'):format(select(i, ...))
  end
  return table.concat(ts,', ')
end


-- Compure spreads of all particles.
-- This should be called at the end of a time-step, once current parameters
-- for all particles have been stored.
local function analyze_particles()
  -- Determine mean position and time `(xave,yave,zave,tave)` of all
  -- particles.
  local count = 0
  local xsum = 0
  local ysum = 0
  local zsum = 0
  local tsum = 0
  for i=1,max_ion do
    if found[i] then
      xsum = xsum + xs[i]
      ysum = ysum + ys[i]
      zsum = zsum + zs[i]
      tsum = tsum + ts[i]
      count = count + 1
    end
  end
  local xave = xsum / count
  local yave = ysum / count
  local zave = zsum / count
  local tave = tsum / count

  -- Determine average (`dr_ave`) and max (`dr_max`) deviation from mean point.
  local dr_max = 0
  local dr_sum = 0
  for i=1,max_ion do
    if found[i] then
      local dx = xs[i] - xave
      local dy = ys[i] - yave
      local dz = zs[i] - zave
      local dr = math.sqrt(dx^2 + dy^2 + dz^2)
      dr_max = math.max(dr_max, dr)
      dr_sum = dr_sum + dr
    end
  end
  local dr_ave = dr_sum / count
  -- Determine average (`dt_ave`) and max (`dt_max`) deviation from mean time.
  local dt_max = 0
  local dt_sum = 0
  for i=1,max_ion do
    if found[i] then
      local dt = math.abs(ts[i] - tave)
      dt_max = math.max(dt_max, dt)
      dt_sum = dt_sum + dt
    end
  end
  local dt_ave = dt_sum / count
   
  -- Determine if this deviation is smaller than in all previous steps.
  if ion_px_mm >= x_min and ion_px_mm <= x_max then
    if dr_ave < dr_ave_best[1] then
      dr_ave_best = {dr_ave, xave, yave, zave, tave}
    end
    if dr_max < dr_max_best[1] then
      dr_max_best = {dr_max, xave, yave, zave, tave}
    end
    if dt_ave < dt_ave_best[1] then
      dt_ave_best = {dt_ave, xave, yave, zave, tave}
    end
    if dt_max < dt_max_best[1] then
      dt_max_best = {dt_max, xave, yave, zave, tave}
    end
  end
  
  -- Record data at this step.
  if not did_header then
    print('tave,xave,yave,zave,tave,dr_max,dr_ave,dt_max,dt_ave,count')
    did_header = true
  end
  print(formatnums(tave, xave, yave, zave, tave,
                   dr_max, dr_ave, dt_max, dt_ave, count))
  table.insert(data1, {xave, dr_max, dt_max*1000}) -- store for plot
  max_count = math.max(max_count, count)
end

function segment.initialize()
  max_ion = ion_number
end

function segment.tstep_adjust()
  -- This is an unconventional use of the tstep-adjust segment.
  -- We want to clear saved points on each new time-step.
  -- tstep_adjust is called before other_actions.
  found = {}
end

-- called on every time-step for every particle.
function segment.other_actions()
  -- Record particle point.
  found[ion_number] = true
  xs[ion_number] = ion_px_mm
  ys[ion_number] = ion_py_mm
  zs[ion_number] = ion_pz_mm
  ts[ion_number] = ion_time_of_flight
  
  -- If last particle flown in this time-step, compute statistics.
  -- Warning: assumes last particle doesn't terminate before other particles
  -- (if this is not the case, you might move `analyze_particles()`
  -- into the tstep_adjust as well to ensure it gets called).
  if ion_number == max_ion then
    analyze_particles()
  end
end

function segment.initialize_run()
  -- Grouped particle flying is required for this example.
  sim_grouped = 1
end

function segment.terminate_run()
  -- Record final summary data at end of run.
  print()
  print('dr_max_best:dr(mm);x;y;z(mm);t(usec):'..formatnums(unpack(dr_max_best)))
  print('dr_ave_best:dr(mm);x;y;z(mm);t(usec):'..formatnums(unpack(dr_ave_best)))
  print('dt_max_best:dt(mm);x;y;z(mm);t(usec):'..formatnums(unpack(dt_max_best)))
  print('dt_ave_best:dt(mm);x;y;z(mm);t(usec):'..formatnums(unpack(dt_ave_best)))

  -- safety check
  if max_count == 1 and max_ion ~= 1 then
    error("\n\nOnly one particle was observed during trajectory steps. "..
          "Do you have Grouped flying mode enabled on the Particles tab?  "..
          "Groups flying is required to properly use this example.\n")
  end
  
  -- Optionally plot.
  if plot ~= 0 then
    local libname = (plot == 1 and '../../excel/excellib.lua' or '../../gnuplot/gnuplotlib.lua')
    simion.import(libname).plot(data1)
  end
end
