-- Helper function to prepend a relative path to package.cpath.
local function prepend_relative_cpath(path)
  local dir = require 'lfs'.currentdir()
  local fullpath = dir .. '/' .. path .. '/?.dll'
  if not package.cpath:find(fullpath, nil, true) then
    package.cpath = fullpath .. ';' .. package.cpath
  end
end
-- Test whether SIMION is 64-bit or not.
local IS64BIT = tostring(io.stdout):find'%(........%)' ~= nil
-- Add the path.
if IS64BIT then
  prepend_relative_cpath('x32')
else
  prepend_relative_cpath('x64')
end
-- Note: none of the above code is needed if you place simple.dll in the
-- "c:\Program Files\SIMION-8.1\lib\lua" folder.

-- Now test it.
local simple = require 'simple'
print('1+2=', simple.add(1,2))
