-- Lua batch mode program to calculate some
-- parameters for the kingdon_1dc.iob system.
-- This is provided only for convenience.

local ELEMENTARY_CHARGE_C = 1.602176487e-19  -- C/e
local ELECTRON_VOLT_J = 1.602176487e-19  -- eV/J

local R1 = 8E-3   -- m
local R2 = 20E-3  -- m
local r  = 16E-3  -- m
local V1 = -3200  -- V
local V2 = 0      -- V
local q = ELEMENTARY_CHARGE_C * 1  -- C

local k = (V2-V1) / math.log(R2/R1)

local phi = V1 + k * math.log(r/R1)
print('phi=', phi)

local Er = -k/r  -- V/m
print('Er (V/m)=', Er)

print('Energy of particle required for circular orbit:')
local KE = q * k / 2
local KE__eV = KE / ELECTRON_VOLT_J
print('KE (eV) =', KE__eV)
