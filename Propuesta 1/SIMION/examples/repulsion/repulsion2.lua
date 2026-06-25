-- SIMION workbench user program:
-- Computes potential contribution due to space-charge (Colombic repulsion
-- method) at a given set of points.
--
-- To get stable values, the potentials are averaged over time.
--
-- D.Manura, 2007-07-28

simion.workbench_program()

assert(simion.pas, 'This example requires SIMION 8.1.')

---- User adjustable variables

    -- IMPORTANT: Check that these match your simulation.
local total_charge = -3.47E-13  -- total Coloumbs for all particles
local num_particles = 1000      -- number of particles

-- For efficiency, only update calculation every this number of time steps.
local skip_steps = 100

-- mm/gu scale factor for PA in which to store space-charge potentials.
-- This can be a lower resolution than the real PA.
local scale = 0.4

-- Translation (mm) for PA in which to store space-charge potentials.
-- (Assumes not rotated)
local tranx = -10
local trany = 0
local tranz = 0

---- Temporary variables

-- Constant for kQ in V = kQ/r.
local KQ = 9E9 * 1000 * total_charge/num_particles

local pa = simion.pas[1]

local last_tof = -1
local count = -1

-- Called on every time-step for each particle not yet splatted.
function segment.other_actions()
  local is_first = (ion_time_of_flight > last_tof)
  if is_first then  -- first particle in next time step
    count = (count + 1) % skip_steps -- compute only periodically
  end
  if count == 0 then -- calculation in progress
    if is_first then -- start of calculation
      -- Initialize sums to zero.
      for zi=0,pa.nz-1 do
      for yi=0,pa.ny-1 do
      for xi=0,pa.nx-1 do
        pa:potential(xi,yi,zi, 0)
      end end end      
    end
    if ion_time_of_birth < ion_time_of_flight then -- particle was born
      -- This is called for each particle *in flight*.
      -- Update Coloumb's law partial sums for each computation point.
      for zi=0,pa.nz-1 do
      for yi=0,pa.ny-1 do
      for xi=0,pa.nx-1 do
        local x0,y0,z0 = xi*scale+tranx, yi*scale+trany, zi*scale+tranz
        local r = sqrt((ion_px_mm-x0)^2 + (ion_py_mm-y0)^2 + (ion_pz_mm-z0)^2)
        pa:potential(xi,yi,zi, pa:potential(xi,yi,zi) + 1/r)
      end end end
    end
  elseif count == 1 and is_first then -- complete previous calculation
    -- Multiply each point value by KQ.
    for zi=0,pa.nz-1 do
    for yi=0,pa.ny-1 do
    for xi=0,pa.nx-1 do
      local v = pa:potential(xi,yi,zi) * KQ
      pa:potential(xi,yi,zi, v)
    end end end
    -- Refresh sceeen for new potential values.
    -- note: sim_update_pe_surface is not sufficient since "pa"
    -- is not an active PA, and that doesn't update contour views.
    redraw_screen()

    -- Also output data to Log
    local yi,zi = 0,0
    for xi=0,pa.nx-1 do
      local x,y,z = xi*scale + tranx, yi*scale + trany, zi*scale + tranz
      print(x, pa:potential(xi,yi,zi))
    end
  end
  last_tof = ion_time_of_flight
end
