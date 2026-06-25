--[[
 direct.lua
 This is a couple simple tests demonstrating how to send commands to gnuplot
 directly.  Note: It can be simpler and more robust to use the gnuplotlib.lua
 library instead, which handles some of the technicalities for you.
 You may need to adjust some of the code below to get it to run on your system.
 D.Manura, 2011-09
--]]

-- Location of gnuplot executable (you may need to change this).
local gnuplot = (simion._internal.simion_root or '') .. '/gnuplot/bin/gnuplot.exe'
--local gnuplot = 'c:/cygwin/bin/gnuplot.exe'
--local gnuplot = 'gnuplot'

local terminal = ''
-- local terminal = 'set terminal ggi; '  -- required for non-xterm Cygwin

-- gnuplot may be executed simply via os.execute .
-- prefixing the command with "start" (a Windows convention), avoids
-- freezing SIMION until gnuplot closes.
--os.execute('start ' .. gnuplot .. ' simple_cygwin.gp')
os.execute('start ' .. gnuplot .. ' -e "' .. terminal .. ' plot sin(x); pause -1"')

-- We can alternately pipe commands.  This works under Windows.
-- The piping does not work quite right under Wine in Linux, in which case
-- named pipes created on the Linux side may be used instead (as used in gnuplotlib.lua).
local fh = assert(io.popen(gnuplot, 'w'))
fh:write(terminal)
fh:write[[
plot tan(x)
]]
fh:flush()  -- be sure to flush; otherwise commands might not be sent immediately.
simion.sleep(5)

-- We can send further commands in the same pipe, allowing incremental updates to the
-- graph.
for i=1,10 do
  fh:write('plot sin(x*', i, '); pause 0.3;\n')
  fh:flush()
  simion.sleep(0.5)
end

-- Finally close pipe (warning: this will close the gnuplot window).
fh:close()


-- Notes:
-- The gnuplot command "pause -1" pauses indefinitely.
-- On Cygwin, "set terminal ggi" seems to be required outside xterm.  Omit this
--   or use a different terminal type on other platforms.
--   "gnuplot -e 'set terminal'" will list all terminal types available on your
--   platform.
