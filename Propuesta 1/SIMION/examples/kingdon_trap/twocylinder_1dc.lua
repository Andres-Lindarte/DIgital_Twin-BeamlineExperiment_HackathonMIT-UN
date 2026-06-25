-- kingdon_1dc.lua - workbench user program for Kingdon trap.

simion.workbench_program()

adjustable max_time = 10  -- microseconds

function segment.other_actions()
  -- Prevent particles from flying forever.
  if ion_time_of_flight >= max_time then
    print('ion terminated early at max_time')
    ion_splat = 1
  end
end
