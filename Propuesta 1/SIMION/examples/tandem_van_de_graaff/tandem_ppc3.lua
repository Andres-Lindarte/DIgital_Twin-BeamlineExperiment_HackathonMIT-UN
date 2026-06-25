--[[
 tandem_ppc3.lua

 This simulates the principle behind the gain in energy of an ion 
 accelerated in a Tandem Van de Graaff Accelerator.

 This program assumes three parallel plane electrodes perpendicular
 to the y-axis, with the middle one at y = y_at_stripping_position_mm
 (user adjustable). The middle plane (foil) is the tandem terminal at
 terminal_voltage_volts (user adjustable) and is always POSITIVE.
 The other two planes in a tandem are at 0V but could be changed by
 user with Fast Adjust.
 
 Ions must start as negative ions (usually charge state q=-1)
 set in the user-defined Particles Define screen prior to flying.
 Ions fly along the negative y direction of the workbench. 

 From the first plane to middle plane, a negative ion is accelerated,
 gaining energy K1 = |-1 e| * terminal_voltage_volts.

 At the middle plane (foil), the ion is stripped of its electrons,
 becoming positively charged with a Gaussian distribution of charges
 centered at around ion_q_state_at_stripping (user adjustable), which
 we'll refer to as new_charge.

 The ion then travels from the middle plane to the final plane,
 gaining energy K2 = new_charge * e * terminal_voltage_volts.

 The overall energy gain in the tandem accelerator is thus
 K = (1 + new_charge) * e * terminal_voltage_volts.

 The program also changes the color of the trajectory by setting
 ion_color = new_charge and prints a line informing of the new charge state.

 Program by Theo Zouros, 2011, using imported code testplanelib.lua by D. Manura.
--]]

simion.workbench_program()

adjustable ion_q_state_at_stripping = 5
adjustable y_at_stripping_position_mm = 30
adjustable terminal_voltage_volts = 1000000


local ST = require 'simionx.Statistics'      -- Load Gaussian distribution
local TP = simion.import 'testplanelib.lua'  -- Load test plane library code.

-- Define the test planes
-- These define segments that should be called inside your own segments.
local test = TP(
  0,y_at_stripping_position_mm,0,   -- point on test plane
  0,1,0,                            -- surface normal vector components
  function()  -- function called when a particle hits the test plane
    local new_charge = math.floor(ST.gaussian_rand() * 2 + ion_q_state_at_stripping + 0.5)
    ion_charge = new_charge
    ion_color = new_charge
    mark()
    local speed, az, el = rect3d_to_polar3d(ion_vx_mm,ion_vy_mm,ion_vz_mm)
    local ke = speed_to_ke(speed,ion_mass)
    print('At stripping terminal has V=', terminal_voltage_volts, " V",
          'Ion(', ion_number, ')', 'q=', new_charge, 'KE=', ke, ' at y=',
          y_at_stripping_position_mm, 'mm')
  end
)

-- sets terminal voltage on electrode 2
function segment.init_p_values()
  adj_elect02 = terminal_voltage_volts
end

function segment.tstep_adjust()
  test.tstep_adjust()  -- call test plane library code
end

function segment.other_actions()
  test.other_actions() -- call test plane library code
end 
