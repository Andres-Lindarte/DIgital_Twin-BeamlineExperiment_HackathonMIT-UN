--[[
 SIMION workbench user program.
 Computes particle transmission ratio and other basic particle statistics.
 D.Manura, 2013-04-15, 2009-02.
--]]

simion.workbench_program()

-- Counters.
local num_particles
local num_hits = 0
local ystart = {}

-- called on start of each run...
function segment.initialize_run()
  -- Reset the counter before each rerun (only needed if Rerun is enabled).
  num_hits = 0
end

-- called on each particle initialization inside a PA instance...
function segment.initialize()
  -- Infer total number of particles flown.  [*1]
  num_particles = ion_number
  
  -- Optionally store data on this particle's starting conditions.  [*2]
  ystart[ion_number] = ion_py_mm
end

-- called on each particle termination inside a PA instance...
function segment.terminate()
  -- Print data on each splat.
  print('splat:', 'y_begin=', ystart[ion_number], 'y_end=', ion_py_mm)

  -- Count particles that splat within some region of volume
  if ion_px_mm > 84 and ion_px_mm < 86 then
    if ion_instance == 1 then  -- and perhaps inside a specific PA instance [*3]
      num_hits = num_hits + 1
    end
  end
end

-- called on end of each run...
function segment.terminate_run()
  -- Print summary data at end of run.
  local transmission = 100 * num_hits / num_particles
  print('num_particles=',  num_particles)
  print('num_hits=',       num_hits)
  print('efficiency (%)=', transmission)
end


--[[
 Footnotes:
 [*1] num_particles could be set explicitly, but here we infer it implicitly.
      On the last initialize call, num_particles will contain the last
      particle number, which also equals the total number of particles.
      Warning: this code assumes all particles initialize inside the volume of
      at least one PA; otherwise, this code will not be executed.
 [*2] This is an optional demonstration of recording data about a particle
      for later use.  Here, this is used to print the particle's ending y
      position v.s. its starting y position, which may make a useful graph.
      The data can be conveniently keyed to ion_number in a Lua table.
 [*3] Be careful if you have overlapping electric and magnetic PA's.
      The initialize and terminate segments will be called twice for a particle
      if the particle exists within the volume of both PA instances.
--]]
