simion.workbench_program()

-- load beam calculation utility functions
local beamutil = simion.import 'beamutil.lua'

-- Enable calculation of the disc of least confusion.
beamutil.enable_confusion_mode(
  1,20,  -- range of particle numbers
  0,300, -- range of x (mm),
  1,     -- x step,
  true   -- is plotted
)
