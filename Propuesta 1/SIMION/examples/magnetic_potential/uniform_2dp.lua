simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

local Azinst = simion.wb.instances[1]
local Oinst  = simion.wb.instances[2]

local bfieldv  = simion.import'maglib.lua'.make_bfield_vector(Azinst, '')
local bfields = simion.import'maglib.lua'.make_bfield_scalar(Oinst, nil, '')


function segment.initialize_run()
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{
    npoints=10, mark=true, z=0,
    {func=bfields, color=1},
    {func=bfieldv, color=3},
  }
  print('B(vector)=', bfieldv(50,50,0))
  print('B(scalar)=', bfields(50,50,0))
  
end
