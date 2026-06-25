--[[
 experimentallinewavelib.lua - Experimentally acquired waveform, using waveformlib.lua.

 v2013-01-29, D.Manura, 2008-07
 (c) 2007-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]
 
local M = {}
M.segment = {}

-- Optionally rescale experimental waveform to specified CV and DV values.
-- (required for spectrum.iob scanning)
--
-- Dispersion voltage
adjustable wave_DV = 750
-- Compensation voltage
adjustable wave_CV = 0

-- plots waveform if non-zero.  Value is time in microseconds to plot.
adjustable wave_plot = 0

local WAVE = simion.import 'waveformlib.lua'


--[[
 Experimental wave data.
 Based on data provided with permission by Papanastasiou et.al.
 This is shown in Fig 2 of their paper:
 http://dx.doi.org/10.1021/jp711732c
 Note: for faster speed, remove unnecessary data points.

 time (microseconds), potential (V)
--]]
local wavedata = [[
0	-327.813
0.005	-328.719
0.01	-327.875
0.015	-327.531
0.02	-328.125
0.025	-328
0.03	-327
0.035	-328.063
0.04	-328.25
0.045	-326.812
0.05	-328.438
0.055	-327.406
0.06	-327.469
0.065	-331.062
0.07	-333.656
0.075	-332.688
0.08	-331.688
0.085	-331.469
0.09	-306.781
0.095	-168.219
0.1	124.156
0.105	480.656
0.11	713.687
0.115	778.688
0.12	782.063
0.125	747.594
0.13	728.125
0.135	735.531
0.14	741.281
0.145	744.594
0.15	748.562
0.155	739.844
0.16	742
0.165	748.469
0.17	750.344
0.175	749.406
0.18	750.563
0.185	748.844
0.19	746.312
0.195	741.812
0.2	745.219
0.205	748.219
0.21	751.563
0.215	751.375
0.22	751.75
0.225	748.281
0.23	745.906
0.235	746.906
0.24	751.563
0.245	748.562
0.25	752.344
0.255	748.156
0.26	752.813
0.265	748.281
0.27	750.594
0.275	751.875
0.28	751.5
0.285	749.375
0.29	752.313
0.295	748.719
0.3	753.469
0.305	750.687
0.31	748.156
0.315	749.344
0.32	749.719
0.325	750.531
0.33	751.5
0.335	751.125
0.34	755.719
0.345	753.75
0.35	752.656
0.355	750.875
0.36	751.375
0.365	753.688
0.37	755.719
0.375	754.531
0.38	755.813
0.385	754.625
0.39	752.125
0.395	689.688
0.4	533.656
0.405	306.438
0.41	80.9375
0.415	-89.8438
0.42	-204.219
0.425	-268.219
0.43	-299.156
0.435	-301.531
0.44	-302
0.445	-305.438
0.45	-309.469
0.455	-317.75
0.46	-317.531
0.465	-318.562
0.47	-319.469
0.475	-320.125
0.48	-319.781
0.485	-323.281
0.49	-318.812
0.495	-319.656
0.5	-319.219
0.505	-319.063
0.51	-321.406
0.515	-320.906
0.52	-323.062
0.525	-320.812
0.53	-320.656
0.535	-322.875
0.54	-320.969
0.545	-320.344
0.55	-321.344
0.555	-322.25
0.56	-321.719
0.565	-322.875
0.57	-322.969
0.575	-321.687
0.58	-322.313
0.585	-322.313
0.59	-319.969
0.595	-320.25
0.6	-321.437
0.605	-319.781
0.61	-319.969
0.615	-320.313
0.62	-319.75
0.625	-318.75
0.63	-319.656
0.635	-321.906
0.64	-320.625
0.645	-322.688
0.65	-321.969
0.655	-319.844
0.66	-320.594
0.665	-319.937
0.67	-320.531
0.675	-320.375
0.68	-320.469
0.685	-321.625
0.69	-320.75
0.695	-321.75
0.7	-320.469
0.705	-320.188
0.71	-322.156
0.715	-320.188
0.72	-319.469
0.725	-324.125
0.73	-321.313
0.735	-321.906
0.74	-323.969
0.745	-321.75
0.75	-323.125
0.755	-322.438
0.76	-321.75
0.765	-322.344
0.77	-322.188
0.775	-323.25
0.78	-321.781
0.785	-322.562
0.79	-322.719
0.795	-321.094
0.8	-323.406
0.805	-321.531
0.81	-322.469
0.815	-322.594
0.82	-321.719
0.825	-323.969
0.83	-324.25
0.835	-322.781
0.84	-323.5
0.845	-323.281
0.85	-323.406
0.855	-322.5
0.86	-324.562
0.865	-322.219
0.87	-324.125
0.875	-323.125
0.88	-321.531
0.885	-323.625
0.89	-323.438
0.895	-322.438
0.9	-324.969
0.905	-324.094
0.91	-326.375
0.915	-326.313
0.92	-326.781
0.925	-324.938
0.93	-327
0.935	-327.375
0.94	-327
0.945	-325.719
0.95	-326.406
0.955	-325.156
0.96	-326.563
0.965	-327.219
0.97	-326.125
0.975	-328.063
0.98	-326.563
0.985	-325.344
0.99	-327.438
0.995	-326.469
1	-327.719
1.005	-327.563
1.01	-324.969
1.015	-327.75
1.0164	-329.094
]]


function M.segment.initialize_run()
  -- Note: unlike in segmentedwavelib.lua, we omit TOL since there are no
  -- abrupt voltage transitions.

  -- Set up waveform.  Times in microsec.

  -- Transform data into a table that can be passed to the waveform library.
  local points = {}
  for time,potential in wavedata:gmatch('(%S+)%s+(%S+)') do
    points[#points+1] = {time=tonumber(time), potential=tonumber(potential)}
  end

  -- Optionally rescale experimental waveform to current CV and DV values.
  -- Note: Particularly for examples\faims\spectrum.iob, we scan the CV value.
  --   Although we could import an experimental waveform for each CV value
  --   required, here we simplify by importing the waveform at just a single
  --   value of CV and DV and rescale it for whatever other CV and DV values
  --   we want.
  local proto_DV = 750   -- DV of original waveform
  local proto_CV = 0     -- CV of original waveform
  for i=1,#points do
    local V = points[i].potential
    points[i].potential = wave_CV + (V - proto_CV) * (wave_DV/proto_DV)
  end
  
  WAVE.set_waveforms(
    WAVE.waveforms {
      WAVE.electrode(2) {
        WAVE.loop(math.huge) {
          WAVE.lines(points)
        };
      };
    }
  )
  -- Plot waveform (this is optional and can be removed).
  if wave_plot ~= 0 then WAVE.plot_waveform(nil, wave_plot) end
end

-- merge segments with any previous ones.
WAVE.install()
WAVE.install_segment(M.segment)

return M
