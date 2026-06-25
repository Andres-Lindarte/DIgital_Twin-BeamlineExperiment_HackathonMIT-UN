-- SIMION user program bridge: automation/voltages.csv -> adj_elect[1..41].
-- Launch SIMION with workspace root as current directory.

local voltage_file = "automation/voltages.csv"
local voltages = nil

local function load_voltages()
  local file, message = io.open(voltage_file, "r")
  if not file then error("Cannot open " .. voltage_file .. ": " .. tostring(message)) end

  local loaded = {}
  for line in file:lines() do
    local electrode, voltage = line:match("^%s*(%d+)%s*,%s*([%+%-%.%deE]+)%s*$")
    if electrode then loaded[tonumber(electrode)] = tonumber(voltage) end
  end
  file:close()

  for electrode = 1, 41 do
    if loaded[electrode] == nil then
      error("Missing or invalid voltage for electrode " .. electrode)
    end
  end
  voltages = loaded
end

function segment.initialize()
  if voltages == nil then load_voltages() end
end

function segment.fast_adjust()
  if voltages == nil then load_voltages() end
  for electrode = 1, 41 do
    adj_elect[electrode] = voltages[electrode]
  end
end
