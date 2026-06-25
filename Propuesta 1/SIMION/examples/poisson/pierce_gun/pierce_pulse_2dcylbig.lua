-- SIMION Lua workbench user program for space-charge handling.
-- D.Manura, 2008-02.

simion.workbench_program()

-- reuse
simion.import 'pierce_pulse_2dcyl.lua'

-- Note: larger array with same number of particles.
adjustable PIC_smooth_radius = 50

adjustable PIC_refine_period = 10

-- This lower threshold is necessary.
adjustable PIC_refine_convergence = 1E-6