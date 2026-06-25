--[[
 simionx.CachedField
 This module is documented in the SIMION supplemental documentation.
 version: 20130403
 (c) 2007-2013 Scientific Instrument Services, Inc. (SIMION 8.0 License)
--]]

local M = {}; M._index = M

local floor = math.floor

-- somewhat of a hack
local system_to_array_coords =
  (require "simionx.FieldArray")._system_to_array_coords
local array_to_system_coords_rotate =
  (require "simionx.FieldArray")._array_to_system_coords_rotate

local function calc_array_point(field,header,data, aloc, xi,yi,zi)
  local cyl_angle = 0; local z_depth = 0
  local x,y,z = array_to_system_coords_rotate(header, xi,yi,zi, cyl_angle)
  local s = header.scale
  local x,y,z = x*s + header.x, y*s + header.y, z*s + header.z
  data[aloc], data[aloc+1], data[aloc+2] = field(x,y,z)
end

local function construct(class, field, field_array)
  local data = field_array.data
  local header = field_array
  return function(x,y,z)
    local xa, ya, za, cyl_angle, z_depth = system_to_array_coords(header, x,y,z)

    -- Get integer and fractional parts of grid positions.
    local xi = floor(xa); local fxr = xa - xi; local fxl = 1 - fxr
    local yi = floor(ya); local fyr = ya - yi; local fyl = 1 - fyr
    local zi = floor(za); local fzr = za - zi; local fzl = 1 - fzr

    local nx, ny, nz = header.nx, header.ny, header.nz

    local bx, by, bz

    -- If position inside array.
    if xi >= 0 and (xi < nx-1 or xi == nx-1 and fxr == 0) and
       yi >= 0 and (yi < ny-1 or yi == ny-1 and fyr == 0) and
       zi >= 0 and (zi < nz-1 or zi == nz-1 and fzr == 0)
    then
      -- offset to most negative (LLL) corner point of interpolation box.
      local idx = ((zi * ny + yi) * nx + xi) * 3
      local idx1 = idx + 1  -- Bx

      -- x,y,z index increments in flat array.
      local AX = (xi == nx-1 and 0 or 3)
      local AY = (yi == ny-1 and 0 or nx*3)
      local AZ = (zi == nz-1 and 0 or ny*nx*3)

      local i = idx1
      if not data[i] then
        calc_array_point(field,header,data, i, xi,yi,zi)
      end
      bx,by,bz = data[i]*fxl, data[i+1]*fxl, data[i+2]*fxl
      if AX ~= 0 then
        i = idx1 + AX 
        if not data[i] then
          calc_array_point(field,header,data, i, xi+1,yi,zi)
        end
        bx,by,bz = bx+data[i]*fxr, by+data[i+1]*fxr, bz+data[i+2]*fxr
      end
      bx,by,bz = bx*fyl, by*fyl, bz*fyl
      if AY ~= 0 then
        i = idx1 + AY
        if not data[i] then
          calc_array_point(field,header,data, i, xi,yi+1,zi)
        end
        local bx2,by2,bz2 = data[i]*fxl, data[i+1]*fxl, data[i+2]*fxl
        if AX ~= 0 then
          i = idx1 + AX + AY
          if not data[i] then
            calc_array_point(field,header,data, i, xi+1,yi+1,zi)
          end
          bx2,by2,bz2 = bx2+data[i]*fxr, by2+data[i+1]*fxr, bz2+data[i+2]*fxr
        end
        bx,by,bz = bx+bx2*fyr, by+by2*fyr, bz+bz2*fyr
      end
      bx,by,bz = bx*fzl, by*fzl, bz*fzl
      if AZ ~= 0 then
        idx1 = idx1 + AZ
        local i = idx1
        if not data[i] then
          calc_array_point(field,header,data, i, xi,yi,zi+1)
        end
        local bx2,by2,bz2 = data[i]*fxl, data[i+1]*fxl, data[i+2]*fxl
        if AX ~= 0 then
          i = idx1 + AX 
          if not data[i] then
            calc_array_point(field,header,data, i, xi+1,yi,zi+1)
          end
          bx2,by2,bz2 = bx2+data[i]*fxr, by2+data[i+1]*fxr, bz2+data[i+2]*fxr
        end
        bx2,by2,bz2 = bx2*fyl, by2*fyl, bz2*fyl
        if AY ~= 0 then
          i = idx1 + AY
          if not data[i] then
            calc_array_point(field,header,data, i, xi,yi+1,zi+1)
          end
          local bx3,by3,bz3 = data[i]*fxl, data[i+1]*fxl, data[i+2]*fxl
          if AX ~= 0 then
            i = idx1 + AX + AY
            if not data[i] then
              calc_array_point(field,header,data, i, xi+1,yi+1,zi+1)
            end
            bx3,by3,bz3 = bx3+data[i]*fxr, by3+data[i+1]*fxr, bz3+data[i+2]*fxr
          end
          bx2,by2,bz2 = bx2+bx3*fyr, by2+by3*fyr, bz2+bz3*fyr
        end
        bx,by,bz = bx+bx2*fzr, by+by2*fzr, bz+bz2*fzr
      end -- AZ ~= 0

      bx, by, bz = array_to_system_coords_rotate(header, bx,by,bz, cyl_angle)


    else -- else if outside array (not cached)
      bx, by, bz = field(x,y,z)
    end
    return bx,by,bz
  end -- function
end
setmetatable(M, { __call = construct})

return M
