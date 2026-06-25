-- teleportutil.lua
--
-- Utility code to support moving particles between multiple running
-- SIMION processes (simion.exe instances) that communicate over
-- TCP/IP sockets.
--
-- D.Manura-2008-03.
-- (c) 2008 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--

-- This module.
local M = {}

-- Add the 'lib' subfolder inside the current directory to the module
-- search path in case the LuaSocket modules are located there rather
-- than in the main 'lib/lua' subfolder of the SIMION program folder
-- (otherwise this code can be removed).
if not package.path:find ';lib/' then
  package.path  = package.path  .. ';lib/?.lua'
  package.cpath = package.cpath .. ';lib/?.dll'
end

-- Load the LuaSocket module ( http://luasocket.luaforge.net/ ).
local socket = require "socket"

-- Maps ion number to status of that ion.
-- The status can be one of these values:
--   nil (active)
--     indicates the particle is normal (active).
--   true (paused)
--     indicates the particle is paused (i.e. it is currently being
--     flown in another SIMION process).
--   a table value (resumable)
--     indicates the particle is paused but ready to be resumed back
--     to a normal state.  The table is an array constaining the
--     parameters to apply to the particle upon resuming the particle.
local ionstate = {}

-- Values passed to the "configure" function (see comments below on
-- configure).
local jumps
local addreses
local simion_number

-- Equals jumps[simion_number] iff simion_number ~= nil.
local myjumps

-- Server socket used to listen to incomming communication from
-- other SIMION processes.
local server

-- Table that maps SIMION process number to the TCP socket for that
-- process (or nil if not opened).  Also, clients[simion_number] ==
-- server.
local clients = {}

-- Extracts a TCP/IP address string of the form "name:port", returning
-- host name and port sepeately (port as a number type).  For example,
--
--   "127.0.0.1:12345"       --> "127.0.0.1",      12345
--   "me.example.com:12345"  --> "me.example.com", 12345
--
local function splitaddress(address)
  local name,port = address:match("^([^:]+):([0-9]+)$")
  if not name then
    error('bad address format (' .. tostring(address) .. ')')
  end
  port = tonumber(port)
  return name, port
end

-- Converts a string of delimited numbers to a list of numbers.
-- Delimiters can include whitespace and commas.
-- Example: "12.3 -3.4e-5" -> 12.3, -3.4e-3
local function unpack_numbers(line, start)
  local val, start2 = line:match("([0-9eE.+-]+)[, \r\n\t]*()", start)
  if val then
    return tonumber(val), unpack_numbers(line, start2)
  end
end

-- Converts a list of numbes of a string of comma-delimited numbers.
-- Example: 12.3, -3.4e-3 -> "12.3,-0.0034"
local function pack_numbers(...)
  local ts = {...}
  for i,v in ipairs(ts) do
    ts[i] = tostring(v)
  end
  return table.concat(ts, ',')
end

-- Configures this modules.
-- Before using this module, this function must be called, beging
-- passing it a table containing these fields:
--
-- jumps:
--
--   This table maps a SIMION process number to another table that
--   maps PA instance numbers to how that PA instance should be treated.
--   The "how" can be one of these two things:
--     a number (SIMION process number)
--       indicates that an ion entering the given PA instance should be
--       teleported to the given SIMION process
--     "pause"
--       indicates an ion in the given PA instance should be paused in
--       the given SIMION process because it would be flying in another
--       SIMION process.
--     nil (unspecified)
--       indicates that an ion in the given instance shall fly inside the
--       given SIMION process.
--
-- addresses:
--
--   This table maps a SIMION process number to the TCP/IP address (IP
--   address or host name) and port number that the process will use to
--   listen to communications from other SIMION processes.  These must
--   be unique.  Note that an address of 127.0.0.1 refers to the current
--   computer on which SIMION is running, and you may leave the
--   addresses at 127.0.0.1 if all the processes are running on the same
--   computer.  The port number must be be used by any other process on
--   the computer.
--
-- simion_number:
--
--   This is the SIMION process number of the currently running
--   process.  Process numbers should be sequential, starting at 1.
--
local function configure(t)
  -- Apply configuration.
  jumps         = assert(t.jumps)
  addresses     = assert(t.addresses)
  simion_number = assert(t.simion_number)
  myjumps       = assert(jumps[simion_number])
end
M.configure = configure

-- Connects to SIMION process with given process number.
-- Returns socket on success.  Errors on failure.
local function hello(snumber)
  local nextaddress = addresses[snumber]
  local nextname, nextport = splitaddress(nextaddress)
  local client = socket.tcp()
  client:settimeout(2)
  local ok, msg = client:connect(nextname, nextport)
  if not ok then
    error('Could not connect to SIMION process ' .. snumber ..
          ' at address "' .. nextaddress ..
          '" (returned message: ' .. msg .. ').' ..
          ' Check that a SIMION process is flying the ' ..
          'workbench at that address and that nothing (e.g. firewall) ' ..
          'is interfering with the communication.\n')
  end
  client:send('hello,' .. simion_number .. '\n')
  local result = client:receive '*l'
  if result == 'hello' then
    print('Hello from SIMION process ' .. snumber)
  else
    client:close()
    error('Could not communicate with SIMION process ' .. snumber ..
          ' at address "' .. nextaddress ..
          '" (though connection did succeed). ' ..
          ' Check that a SIMION process is flying the ' ..
          'workbench.\n')
  end
  return client
end

-- Handles incomming connection from another SIMION process.
-- Returns immediately if there is no imcomming connection.
-- Does nothing on failure.
local function hello_reply()
  local client = server:accept()
  if not client then
    return
  end
  client:settimeout(2)
  local line = client:receive '*l'
  local snumber = line and line:match '^hello,(%d+)$'
  local snumber = snumber and tonumber(snumber)
  if not snumber then
    client:close()
    return
  end
  assert(not snumber or snumber >= simion_number)

  client:send 'hello\n'
  clients[snumber] = client
  print('Hello from SIMION process ' .. snumber)
end

-- Establishes connections with other SIMION processes.
-- This blocks but can be terminated by pressing the ESC key.
-- Note: SIMION processes must be started in order of their
-- process numbers.
local function synchronize()
  -- Create a TCP server socket for listening.
  local myaddress = addresses[simion_number]
  local myname, myport = splitaddress(myaddress)
  server = assert(socket.bind(myname, myport))
  server:settimeout(0)  -- non-blocking server:accept()
  clients[simion_number] = server

  -- Wait for SIMION processes with higher process numbers
  -- to connect to current SIMION process.
  local msg = 'Waiting for incomming connections... (press ESC to abort)'
  print(msg); simion.status(msg)
  while 1 do
    -- Exit loop when all clients opened.
    local done = true
    for i=simion_number+1,#addresses do
      if not clients[i] then done = false end
    end
    if done then break end

    hello_reply()

    -- Allow abort.
    if simion.key() == 27 then error 'Connect aborted.' end
  end
  print 'All incomming connections created.'

  local msg = 'Waiting for outgoing connections... (press ESC to abort)'
  print(msg); simion.status(msg)

  -- Connect to SIMION processes with lower process numbers.
  local nnext = simion_number - 1
  while nnext >= 1 do
    local client = hello(nnext)
    if client then
      clients[nnext] = client
      nnext = nnext - 1
    end

    -- Allow abort.
    if simion.key() == 27 then error 'Connect aborted.' end
  end
  print 'All outgoing connections created.'
end

-- Returns the state of the current particle ('active', 'paused', or
-- 'resumable').
local function state_of_ion()
  local data = ionstate[ion_number]
  return (data == nil ) and 'active'    or
         (data == true) and 'paused'    or
                            'resumable'
end

-- Pauses a particle that is currently active.
local function pause_ion()
  assert(state_of_ion() == 'active')
    -- Prevent particle movement until particle definition
    -- received from another SIMION process.
    ion_vx_mm = 0
    ion_vy_mm = 0
    ion_vz_mm = 0
    ionstate[ion_number] = true
    print('pausing ion ' .. ion_number)
  assert(state_of_ion() == 'paused')
end

-- Resumes a particle.  That is, a particle in a resumable
-- state is made to be in an active state again.
-- Note: sets sim_trajectory_image_control.
local function resume_ion()
  assert(state_of_ion() == 'resumable')
    -- Update particle parameters.
    local data = ionstate[ion_number]
    local _ ;
      _,
      ion_splat,
      ion_time_of_flight,
      ion_vx_mm, ion_vy_mm, ion_vz_mm,
      ion_px_mm, ion_py_mm, ion_pz_mm
      = unpack(data)
    print('resuming ion ' .. ion_number)

    ionstate[ion_number] = nil  -- done
  assert(state_of_ion() == 'active')
end

-- Transports current particle to SIMION process with given SIMION
-- process number.  This makes an active particle paused.
local function transport_ion(snumber)
  assert(state_of_ion() == 'active')
    if ion_splat ~= 0 then
      print('terminating ion ' .. ion_number ..
            ' in SIMION ' .. snumber)
    else
      print('transporting ion ' .. ion_number ..
            ' to SIMION ' .. snumber)
    end

    -- Encode and send particle parameters to new SIMION process.
    local line = pack_numbers(
      ion_number,
      ion_splat,
      ion_time_of_flight,
      ion_vx_mm, ion_vy_mm, ion_vz_mm,
      ion_px_mm, ion_py_mm, ion_pz_mm
    )
    local client = assert(clients[snumber], snumber)
    client:send(line .. '\n')
    pause_ion()
  assert(state_of_ion() == 'paused')
end

-- Attempts to receive a particle from other SIMION processes.  If
-- there is no particle to receive, this function immediately returns.
local function receive_ion()
  local clients = socket.select(clients, nil, 0)
  if #clients > 0 then
    -- Recieve, unencode, and store parameters of incomming particle.
    local client = clients[1]
    local line = assert(client:receive())
    local data = { unpack_numbers(line) }
    local snumber = data[1]
    local new_ion_splat = data[2]
    ionstate[snumber] = data
    if new_ion_splat ~= 0 then
      print('received terminated ion ' .. ion_number)
    else
      print('received ion ' .. ion_number)
    end
  end
end

-- Kills current particle, setting ion_splat to new_ion_splat.
-- This also notifies other SIMION processes that might currently
-- have the particle paused by resuming the particle in a splat
-- state in all processes.
local function kill_ion(new_ion_splat)
  ion_splat = new_ion_splat or 1
  for i=1,#addresses do
    if i ~= simion_number then
      transport_ion(i)
    end
  end
end

-- SIMION other_actions segment code required for particle teleportation.
-- You must call this from your own other_actions segment.
local function other_actions()
  receive_ion()

  local old_state = state_of_ion()

  if ion_splat ~= 0 then
    kill_ion(ion_splat)
  end
  if state_of_ion() == 'active' and
     type(myjumps[ion_instance]) == 'number'
  then
    local snumber = myjumps[ion_instance]
    transport_ion(snumber)
  end

  if state_of_ion() == 'resumable' then
    resume_ion()
  end

  -- Enable trajectory recording and viewing (0) only when particle
  -- inside current process.
  -- Note: this doesn't work the best in Grouped flying since the particles
  -- are either all on or all off.
  sim_trajectory_image_control = 
    (old_state == 'active' and state_of_ion() == 'active' or ion_splat ~= 0)
    and 0 or 3
end
M.other_actions = other_actions

-- SIMION initialize segment code required for particle teleportation.
-- You must call this from your own initialize segment.
local function initialize()
  if ion_number == 1 then
    synchronize()
  end

  if myjumps[ion_instance] == 'pause' then
    pause_ion()
  end
end
M.initialize = initialize

-- Forward calls to this module to the "configure" function.
setmetatable(M, {__call = function(_, ...) configure(...) return M end})

return M
