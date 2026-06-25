simion.workbench_program()

-- Import waveform library.
local WAVE = simion.import 'waveformlib.lua'

-- Install waveform.
WAVE.install {
  -- Define waveform for each adjustable electrode.
  -- Note: times in microseconds.
  waves =
  WAVE.waveforms {
    WAVE.electrode(1) {
      -- triangular wave pulse.
      WAVE.lines {
        {time=0,  potential=0};
        {time=10, potential=3};
        {time=30, potential=-3};
        {time=40, potential=0};
      };
    };
    WAVE.electrode(2) {
      -- square wave pulse.
      WAVE.lines {
        {time=0,  potential=0};
        {time=60, potential=0};
        {time=60, potential=2};
        {time=80, potential=2};
        {time=80, potential=-4};
        {time=90, potential=-4};
        {time=90, potential=0};
      };
    };
  };

  -- Update PE surface display every this number of microseconds.
  -- This is optional.  Remove or set to nil to disable.
  pe_update_period = 1;
}

-- Plot waveform.
-- This is optional.  Remove to disable.
WAVE.plot_waveform()
