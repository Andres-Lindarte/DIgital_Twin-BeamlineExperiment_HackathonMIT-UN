---------------------------------------------------
-- secondarylib.lua - Utility functions for the secondary
-- emissions effects.
--
-- This implements secondary emissions effects.
--
-- Please see all the comments.  There's a number of things in here
-- you might want to adjust.  The code should be fairly robust
-- and general purpose enough that other users can take this
-- example and use it in their own simulations (though with care).
--
-- One of the more difficult things in the code is estimating
-- the surface normal vector on the electrode surface where the
-- particle hits.  We need to know the surface normal vector to
-- determine the angle at which the incident particle hits, which
-- affects the angle of the secondary particle.  For a curved surface,
-- the surface normal is not obvious to SIMION since the curved
-- surface is approximated with surface jags.  However, luckilly,
-- for a number of geometries, the surface normal can be defined
-- rather easily with a simple analytical expression that you
-- may specify inside this program.
--
-- However, this code also aims to address the more general case
-- when the user does not need to input an analytical expression for
-- the surface normal but rather the program attempts as best as
-- possible to calculate that for you.  One way to estimate the
-- surface normal is from the calculated electric field near the surface.
-- After all, theory tells us that the electric field should
-- be perpendicular to the surface, so this is our surface normal.
-- In practice, if the surface is curved and has jags, we
-- need to step back a few grid units from the surface before
-- measuring the electric field so that the averaging affect of
-- Laplace averages out some of the local deviations from the
-- surface jags.  However, if the electric field changes quickly
-- near the surface, we don't want to step too far back.  That
-- limits the accuracy of this method, so its prefered to define the
-- surface normal analytically.
--
-- David Manura, 2007-01.
-- (c) 2007 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0) 
---------------------------------------------------

-- Load history module.
-- (Used only if secondary_normal_mode == 1 and secondary_offset_gu > 0.)
-- The history module allows us to record a history of particle
-- data just before the splat.  See secondary_offset_gu.
-- We first set it to nil to force a reload (in case user modified it).
package.loaded['history'] = nil; require "history"


-- BEGIN OF CONFIGURABLE VARIABLES.
-- You may want to adjust some of these.


-- Mass of secondary emission particles.
-- Particle mass will change to this upon secondary emission.
-- Specify 1e30 for no change.
adjustable secondary_mass = 1e30  -- amu

-- Charge of secondary emission particles.
-- Particle charge will change to this upon secondary emission.
-- Specify 1e30 for no change.
adjustable secondary_charge = 1e30  -- elementary charge

-- Maximum number of repeated secondary emissions per particle.
-- This is any integer >= 0.
-- Set to 0 for no secondary emissions.  Set to 1 to
-- have secondary emissions not cause further secondary emissions.
-- Specify 1e30 for infinite (e.g. electron multiplier).
adjustable secondary_max_times = 1

-- Scheme for direction of secondary emissions:
--   1 - specular reflection (incidence angle = reflection angle)
--       [ http://en.wikipedia.org/wiki/Specular_reflection ]
--   2 - perpendicular to surface normal vector.
--   3 - Lambertian reflectance (Lambert's cosine law) (randomized)
--       [ http://en.wikipedia.org/wiki/Lambertian_reflectance ]
--       [ http://en.wikipedia.org/wiki/Lambert's_cosine_law ]
adjustable secondary_direction_mode = 1

-- Scheme for energy of secondary emissions:
--   1 - constant value
--       Specify secondary_energy_mode as well.
--   2 - fraction of original KE (or multiple or no change).
--       Specify secondary_energy_mode as well.
--   3 - Maxwell-Boltzmann distribution of KE (randomized)
--       Specify secondary_energy_mode as well.
adjustable secondary_energy_mode = 2

-- Secondary energy parameter.
-- The meaning of this value depends on the value of secondary_energy_mode.
-- If secondary_energy_mode == 1 (constant value):
--   This is the secondary emission energy in eV.
-- If secondary_energy_mode == 2 (fractional):
--   This is the fraction or multiple of the KE of the incident particle.
--   Specify 1 for no change from incident KE.
-- If secondary_energy_mode == 3 (Maxwell-Boltzmann):
--   This is k*T in units of eV.
--   Note:
--     k = 1.3806505e-23 J/K is the Boltzmann constant.
--     T is temperature in Kelvin (K).
--     eV/J conversion factor is 6.2415095e+18 eV/J.
adjustable secondary_energy_value = 1

-- Scheme for computing surface normal at secondary emission surface.
--  1 = estimate from electric field some distance back from surface
--      (less accurate and reliable but works automatically)
--  2 = analytical definition
--      (more accurate but requires manual definition for your system)
adjustable secondary_normal_mode = 2

-- Distance in grid units away from surface to apply secondary emission effects.
-- The precise meaning of this value depends on the value of secondary_normal_mode.
-- If secondary_normal_mode == 1:
--   This is the distance away from surface to measure the electric field
--   used for estimating the surface normal.  Note: at the surface of
--   an electrode, the electric field is parallel to the surface normal.
--   If too small, jags on curve surface will seriously affect the answer.
--   If too large, fields from other electrodes might interfere.
--   2-3 is likely good for curved surfaces.
--   0 should be best if the surface is flat with no jags.
-- If secondary_normal_mode == 2:
--   This is the distance away from surface to calculate secondary emission
--   effects.  If positive, particles are not actually flown to the surface
--   but rather when a particle reaches this distance, a quick calculation
--   is done using the electric field at that point an an exact analytical
--   definition of the surface.  Performing the secondary emission calculation
--   in this way away from the surface itself may improve accuracy
--   on curved surfaces as it avoids local effects of jags on curved surface.
--   1-3 grid units might be best for curved surfaces.
--   0 should be best if the surface is flat with no jags.
--   Set to 0 to disable this.
adjustable secondary_offset_gu = 2

-- Probability of secondary emission.
-- This is a real number from 0 to 1.
-- Set to 1 to always emit secondary. 0 disables all secondaries.
adjustable secondary_probability = 1

-- Whether to display debug messages (1=yes,0=no).
adjustable secondary_debug = 1

-- Minimum distance in grid units between successive secondary emissions.
-- After a secondary emission, further splats or secondary emissions
-- are prevented within this radius in grid units since those might
-- undesirably occur due to surface jags.
-- Approximately 1-2 grid units is probably good.
local secondary_radius_gu = 2


-- END OF CONFIGURABLE VARIABLES.

-- Count of number of repeated secondary emissions for each particle.
-- This is used in secondary_max_times.
-- map: ion_number --> integer count
local secondary_count = {}

-- Positions of last secondary emission for each particle.
-- This is related to secondary_radius_gu.
-- map: ion_number --> position {x, y, z}
local secondary_positions = {}

-- History structure for each particle.
-- (Used only if secondary_normal_mode == 1 and secondary_offset_gu > 0.)
-- map: ion_number --> history object
local hists = {}


-- Return Cartesian distance between two 3D position vectors v1 and v2.
-- (utility function)
local function distance(v1, v2)
  return sqrt((v1[1]-v2[1])^2 + (v1[2]-v2[2])^2 + (v1[3]-v2[3])^2)
end

-- Detect and calculate effect of collision with curved surface
-- before it happens.
-- (Used only if secondary_normal_mode == 2, secondary_offset_gu > 0,
--  and a global "secondary_user_time_to_surface" function is defined.)
-- See secondary_offset_gu.
-- Returns Boolean whether collision was processed.
local function process_collisions_early()
  local is_collision = false
  if secondary_user_time_to_surface then
    local dt = secondary_user_time_to_surface(
        ion_px_mm, ion_py_mm, ion_pz_mm, ion_vx_mm, ion_vy_mm, ion_vz_mm)
    if dt then
      -- convert time to distance lambda.
      local speed = sqrt(ion_vx_mm^2 + ion_vy_mm^2 + ion_vz_mm^2)
      local lambda = speed * dt

      if lambda < secondary_offset_gu * ion_mm_per_grid_unit then 
        -- Perform an integration to the surface
        -- (assuming for simplicity approximately constant acceleration)
        ion_px_mm = ion_px_mm + ion_vx_mm * dt
        ion_py_mm = ion_py_mm + ion_vy_mm * dt
        ion_pz_mm = ion_pz_mm + ion_vz_mm * dt
        ion_vx_mm = ion_vx_mm + ion_ax_mm * dt
        ion_vy_mm = ion_vy_mm + ion_ay_mm * dt
        ion_vz_mm = ion_vz_mm + ion_az_mm * dt
        ion_time_of_flight = ion_time_of_flight + dt
        ion_splat = -1
        is_collision = true
      end
    end
  end
  return is_collision
end


-- Compute time particle will take to hit spherical surface
-- params:
--   x0,y0,z0 - origin of sphere to test
--   r - radius of sphere to test
--   x,y,z - current particle position
--   vx,vy,vz - current particle speed
function secondary_time_to_sphere(x0,y0,z0, r, x,y,z, vx,vy,vz)
  -- Position (x', y', z') at time t from now is (x+vx*t, y+vy*t, z+zy*t).
  -- Plugging that into the equation of the sphere gives
  --   ((x + vx*t) - x0)^2 + ((y + vy*t) - y0)^2 + ((z + vy*t) - z0)^2 = r^2
  -- Solving for t, this is a quadratic equation of the form:
  --   a*t^2+ b*t + c = 0
  -- Then solve quadratic equation:
  --   t = (-b +- sqrt(b^2 - 4*a*c)) / (2*a)
  local a = vx^2 + vy^2 + vz^2
  local b = 2*vx*(x - x0) + 2*vy*(y-y0) + 2*vz*(z - z0)
  local c = (x - x0)^2 + (y - y0)^2 + (z - z0)^2 - r^2
  local descriminant = b^2 - 4*a*c
  local result
  if descriminant >= 0 then  -- solutions exist
    -- note: select closest positive of the two solutions (if any)
    local tmp1 = -b/(2*a); local tmp2 = sqrt(descriminant)/(2*a)
    local result1 = tmp1 + tmp2
    local result2 = tmp1 - tmp2
    result = (result1 >= 0 and result2 >= 0) and min(result1, result2) or
             (result1 >= 0 or  result2 >= 0) and max(result1, result2) or
             nil  -- leave result unrefined if both solutions negative
  end
  return result
end



-- Default SIMION terminate segment for secondary emission example.
-- This segment is called on every time step.
function secondary_other_actions()

  -- Detect and handle collisions on surfaces before those collisions happen.
  -- (Used only if secondary_normal_mode == 2 and secondary_offset_gu > 0.)
  -- See secondary_offset_gu.
  local is_early_collision
  if secondary_normal_mode == 2 and secondary_offset_gu > 0 then
    is_early_collision = process_collisions_early()
  end

  if ion_splat == -1 then  -- particle is on or inside electrode
    local allow_secondary = true  -- whether to continue with secondary emission

    -- If hitting electrode within short distance of previous secondary
    -- emission point, prevent splat or further secondary emission.
    -- See secondary_radius_gu.
    if allow_secondary then
      local sp = secondary_positions[ion_number]  -- previous position
      if sp and distance(sp, {ion_px_mm, ion_py_mm, ion_pz_mm})
                < secondary_radius_gu * ion_mm_per_grid_unit
      then
        -- Apply short jump of length surface_jump_gu (in grid units)
        -- along velocity vector in attempt to clear particle from inside of electrode.
        -- For surface_jump_gu, a fraction of a grid unit is ok. 
        --   Smaller values won't hurt since program will try multiple jumps
        --   if first jump does not exit electrode.
        -- As fields inside electrodes are zero, this task is simplified a bit.
        ----print("DEBUG:jump some")
        local surface_jump_gu = 0.1
        ---- Compute time offset (dt) for jump.
        local v = sqrt(ion_vx_mm^2 + ion_vy_mm^2 + ion_vz_mm^2) -- speed
        local dt = (surface_jump_gu * ion_mm_per_grid_unit) / v
        ion_px_mm = ion_px_mm + ion_vx_mm * dt  -- do jump
        ion_py_mm = ion_py_mm + ion_vy_mm * dt
        ion_pz_mm = ion_pz_mm + ion_vz_mm * dt
        ion_time_of_flight = ion_time_of_flight + dt

        allow_secondary = false
        ion_splat = 0  -- cancel splat, and continue
      end
    end

    -- Limit the number of repeated secondary emissions per particle.
    if allow_secondary then
      if (secondary_count[ion_number] or 0) >= secondary_max_times then
        --print("DEBUG:secondary limit reached")
        allow_secondary = false
      end
    end

    -- Cause secondary emission to occur with specified probability.
    -- See secondary_probability.
    if rand() > secondary_probability then
      allow_secondary = false
    end

    -- Compute surface normals at splat point.
    -- This is needed for the secondary emissions calculation.
    -- The surface normal found here does not need to be normalized.
    -- There's a few ways to do this depending on the secondary_normal_mode selected.
    local nx,ny,nz  -- components of surface normal to calculate
    if allow_secondary then
      if secondary_normal_mode == 1 then  -- estimated from field
        -- Surface normal is estimated from electric field near surface,
        -- which should be parallel according to theory.
        if secondary_offset_gu > 0 then  -- field away from surface
          -- Recall field from history data.
          local h = hists[ion_number]  -- history object
          local v = h:value_at_distance(secondary_offset_gu * ion_mm_per_grid_unit)
          nx, ny, nz = v[4], v[5], v[6]
        else  -- field at surface (simpler case)
          nx, ny, nz = ion_dvoltsx_mm, ion_dvoltsy_mm, ion_dvoltsz_mm
        end
        -- Ensure normal is oriented in opposite direction of velocity
        -- vector.  Test orientation by sign of dot product.
        local dir = nx*ion_vx_mm + ny*ion_vy_mm + nz*ion_vz_mm -- dot product
        if dir > 0 then nx, ny, nz = -nx, -ny, -nz end
      elseif secondary_normal_mode == 2 then  -- defined analytically
        nx, ny, nz = secondary_user_normal(ion_px_mm, ion_py_mm, ion_pz_mm)
      else
        assert("invalid secondary_normal_mode")
      end
      --print('DEBUG:norm', nx,ny,nz, ion_px_mm, ion_py_mm, ion_pz_mm)

      -- Prevent secondary emissions if normal not defined on surface.
      -- You might use this if only some surfaces result in secondary emissions.
      if nx == nil then
        allow_secondary = false
      end
    end

    -- Perform secondary emission.
    if allow_secondary then

      -- Store incident velocity vector.
      local vx, vy, vz = ion_vx_mm, ion_vy_mm, ion_vz_mm

      -- Store incident KE
      local v = sqrt(vx^2 + vy^2 + vz^2)  -- speed
      local ke = speed_to_ke(v, ion_mass)

      -- Rotate coordinate system so that surface normal
      -- coincides with +Y axis.  To do this, first undo
      -- the azimuth angle.  Then undo the elevation angle.  This gets
      -- you back to the +X axis.  Finally elevate +90 degrees to the +Y axis.
      local _, az, el = rect3d_to_polar3d(nx, ny, nz)
      vx,vy,vz = elevation_rotate(-el+90,azimuth_rotate(-az, vx, vy, vz))

      -- Reflect velocity vector (converting incident velocity vector
      -- to reflected velocity vector).
      local r2, az2, el2 = rect3d_to_polar3d(vx,vy,vz)
      if secondary_direction_mode == 1 then -- specular
        -- This reflection is easily expressed in polar coordinates.
        -- We just negate the elevation angle, assuming
        -- the surface normal is the +Y axis as assured above.
        el2 = -el2
      elseif secondary_direction_mode == 2 then -- perfectly normal
        el2 = 90
      elseif secondary_direction_mode == 3 then -- lambertian
        -- In Lambert's cosine law, theta is the angle relative to the normal.
        -- In 3D, theta has a probability density function
        -- p(theta) = 2*cos(theta)*sin(theta) = sin(2*theta).
        -- From the fundamental transformation law of probabilities
        -- this implies a random variable X in p can be expressed in terms
        -- of a uniform random variable Y according to the equation
        -- 1 - 2*X == cos(2*Y).
        local theta = 0.5*acos(1-2*rand())
        el2 = 90 - theta * 180/math.pi
        az2 = rand() * 360
      else
        error("invalid scatter_direction")
      end
      vx,vy,vz = polar3d_to_rect3d(r2, az2, el2)

      -- Rotate back to original coordinate system.
      vx, vy, vz = azimuth_rotate(az, elevation_rotate(el-90, vx,vy,vz))

      if secondary_debug ~= 0 then
        print(string.format(
              "DEBUG:hit_event,x=%f,y=%f,z=%f,theta=%f,vx=%f,vy=%f,vz=%f,ke=%f",
              ion_px_mm, ion_py_mm, ion_pz_mm,
              90 - el2,
              ion_vx_mm, ion_vy_mm, ion_vz_mm,
              ke))
      end

      -- Modify KE of secondary.
      if     secondary_energy_mode == 1 then  -- constant
        ke = secondary_energy_value
      elseif secondary_energy_mode == 2 then  -- fractional
        ke = ke * secondary_energy_value
      elseif secondary_energy_mode == 3 then  -- Maxwell-Boltzmann
        ke = maxwell_ke(secondary_energy_value)
      else
        error("invalid secondary_energy_mode")
      end

      -- Modify charge of secondary (if enabled)
      if secondary_charge <= 1e29 then
        ion_charge = secondary_charge
      end

      -- Modify mass of secondary (if enabled)
      if secondary_mass <= 1e29 then
        ion_mass = secondary_mass
      end

      -- Correct velocity of secondary.
      -- Note: mass or KE might have changed.
      -- Do this by scaling velocity vector.
      local vnew = ke_to_speed(ke, ion_mass)
      vx = vx * (vnew / v)
      vy = vy * (vnew / v)
      vz = vz * (vnew / v)

      -- Set it.
      ion_vx_mm, ion_vy_mm, ion_vz_mm = vx, vy, vz

      -- Prevent ion splat since this is a secondary emission event.
      ion_splat = 0

      -- Record info
      secondary_count[ion_number] = (secondary_count[ion_number] or 0) + 1
      secondary_positions[ion_number] = {ion_px_mm, ion_py_mm, ion_pz_mm}
      if secondary_debug ~= 0 then
        print(string.format(
                "DEBUG:secondary_event,vx'=%f,vy'=%f,vz'=%f,ke=%f,count=%f",
                ion_vx_mm, ion_vy_mm, ion_vz_mm, ke,
                secondary_count[ion_number]))
      end

      -- Mark location of secondary emission.
      -- Useful for visualization and data recording (e.g. record on all marks).
      -- (Actually, if is_early_collision is true, mark will actually be
      --  redefined away from the surface.  If grouped is enabled, then this
      --  will mark all particles.)
      mark()

      if is_early_collision then  -- calculated away from surface
        -- Apply short jump along velocity vector in attempt to
        -- clear particle away from field deviations near surface.
        -- See secondary_offset_gu.
        -- First compute time offset (dt) for that.
        local v = sqrt(ion_vx_mm^2 + ion_vy_mm^2 + ion_vz_mm^2)  -- speed
        local lambda = secondary_offset_gu * ion_mm_per_grid_unit  -- distance step
        local dt = lambda / v
        -- Compute new acceleration (since mass/charge may have changed)
        -- Using e/Coloumb and kg/amu conversion factors + Lorentz force law.
        local factor = -1 * 1.6021765314e-19 / 1.66053886e-27 * 1e-6
                       * (ion_charge / ion_mass)
        local ax = ion_dvoltsx_mm * factor
        local ay = ion_dvoltsy_mm * factor
        local az = ion_dvoltsz_mm * factor
        -- Perform an integration to the surface
        -- (assuming for simplicity approximately constant acceleration)
        ion_px_mm = ion_px_mm + ion_vx_mm * dt
        ion_py_mm = ion_py_mm + ion_vy_mm * dt
        ion_pz_mm = ion_pz_mm + ion_vz_mm * dt
        ion_vx_mm = ion_vx_mm + ax * dt
        ion_vy_mm = ion_vy_mm + ay * dt
        ion_vz_mm = ion_vz_mm + az * dt
        ion_time_of_flight = ion_time_of_flight + dt
      end
    end
  else  -- particle is not touching electrode (but flying normally)
    -- Record history data during normal trajectory flight
    -- (if option is enabled--see secondary_offset_gu).
    if secondary_normal_mode == 1 and secondary_offset_gu > 0 then
      -- Get history object for particle (or create it if not exists)
      local h = hists[ion_number]
      if not h then
         h = history.History()
         hists[ion_number] = h
      end

      -- Ensure max_distance in the history object is up-to-date (e.g if multiple PAs).
      h:set_max_distance(secondary_offset_gu * ion_mm_per_grid_unit)
      -- Store voltage gradient data at current time-step.
      h:insert{ion_px_mm, ion_py_mm, ion_pz_mm,
               ion_dvoltsx_mm, ion_dvoltsy_mm, ion_dvoltsz_mm}
    end
  end

  if ion_splat ~= 0 then  -- particle will die.
    -- No need to keep this data around anymore.
    -- (Save memory if flying lots of particles.)
    secondary_count[ion_number] = nil
    secondary_positions[ion_number] = nil
    hists[ion_number] = nil
  end
end

-- Return random number according to the normalized
-- Gaussian distribution.
-- [ http://en.wikipedia.org/wiki/Normal_distribution ]
function gaussian_random()
  -- Compute a normalized Gaussian random variable (-inf, +inf).
  -- Using the Box-Muller algorithm.
  s = 1
  while s >= 1 do
    v1 = 2*rand() - 1
    v2 = 2*rand() - 1
    s = v1*v1 + v2*v2
  end
  rand1 = v1*sqrt(-2*ln(s) / s)  -- (assume divide by zero improbable?)
  return rand1
end

-- Return random number according to the normalized
-- chi-square distribution with k degrees of freedom.
-- [ http://en.wikipedia.org/wiki/Chi-square_distribution ]
function chisquare_random(k)
  assert(k == math.floor(k) and k >= 1)
  -- A random variable in this distribution is the sum of squares
  -- of k independent variables in the normalized Gaussian distribution.
  local result = 0
  for n=1,k do
    result = result + gaussian_random()^2
  end
  return result
end

-- Return random KE according to Maxwell-Boltzmann distribution.
-- kt_ev is k*T in terms of electron volts, where k is the
-- Boltzmann constant and T is temperature in Kelvin (K).
-- Returned energy is also in terms of electron volts.
-- Note:
--   k = 1.3806505e-23 -- Boltzmann constant (J/K)
--   eV_J = 6.2415095e+18 -- (eV/J) conversion factor
function maxwell_ke(kt_ev)
  -- As noted at [ http://en.wikipedia.org/wiki/Maxwell-Boltzmann_distribution ]
  -- a Maxwell-Boltzmann distribution of KE follows a chi-square
  -- distribution chi^2(x;k) of k=3 degrees of freedom and
  -- with x=(2E)/(kT).
  local x = chisquare_random(3)
  local E = (x*kt_ev / 2)
  return E
end


