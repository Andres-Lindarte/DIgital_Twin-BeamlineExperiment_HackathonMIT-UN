simion.workbench_program()

-- =========================================================================
-- VIRTUAL DETECTORS
-- =========================================================================
--local checkpoints_x = {126.0, 255.0} 
local checkpoints_z = {133.0, 225.0} 

local z_center_x = 76.0
local z_center_y = 76.0

--local x_center_y = 76.0
--local x_center_z = 76.0

-- =========================================================================
-- POINTS OVER THE CONCENTRIC CILINDERS (With the radious)
-- =========================================================================
local function calculate_points(radii)
    if radii <= 3.0 then 
        return 0.7
    elseif radii <= 5.0 then  -- CORREGIDO: era 'radio'
        return 0.5
    elseif radii <= 8.0 then  -- CORREGIDO: era 'radio'
        return 0.1
    else 
        return 0.001
    end
end

-- =========================================================================
-- SIMULATION LOGIC
-- =========================================================================
local ion_status = {}

function segment.initialize_run()
    ion_status = {}
end

function segment.initialize()
    ion_status[ion_number] = {
        --last_x = ion_px_mm,
        last_z = ion_pz_mm,
        --passed_x = {}, 
        passed_z = {} 
    }
end

function segment.other_actions()
    if not ion_status[ion_number] then return end
    
    local current_x = ion_px_mm
    local current_z = ion_pz_mm
    --local last_x = ion_status[ion_number].last_x
    local last_z = ion_status[ion_number].last_z
    
    -- ---------------------------------------------------------------------
    -- Z-AXIS
    -- ---------------------------------------------------------------------
    for i, target_z in ipairs(checkpoints_z) do
        if not ion_status[ion_number].passed_z[i] then
            if (last_z < target_z and current_z >= target_z) then
                
                local dx = current_x - z_center_x
                local dy = ion_py_mm - z_center_y
                local radii = math.sqrt(dx*dx + dy*dy)
                
                local points = calculate_points(radii)
                -- CORREGIDO: %.3f para leer decimales
                print(string.format("virtual_det_z(Z:%d, radii:%.2f, points:%.3f)", target_z, radii, points))
                
                ion_status[ion_number].passed_z[i] = true 
            end
        end
    end

    -- ---------------------------------------------------------------------
    -- X-AXIS
    -- ---------------------------------------------------------------------
    --[[
    for i, target_x in ipairs(checkpoints_x) do
        if not ion_status[ion_number].passed_x[i] then
            -- Because the beamline travels on -x
            if (last_x > target_x and current_x <= target_x) then
                
                local dy = ion_py_mm - x_center_y
                local dz = current_z - x_center_z
                local radii = math.sqrt(dy*dy + dz*dz)
                
                local points = calculate_points(radii)
                -- CORREGIDO: Unificado a "points:%.3f"
                print(string.format("virtual_det_x(X:%d, radii:%.2f, points:%.3f)", target_x, radii, points))
                
                ion_status[ion_number].passed_x[i] = true 
            end
        end
    end
    --]]

    -- Actualizate the positions
    --ion_status[ion_number].last_x = current_x
    ion_status[ion_number].last_z = current_z
end

-- =========================================================================
-- Last positions (crashed) 
-- =========================================================================
function segment.terminate()
    print(string.format("xyz(%f, %f, %f)mm", ion_px_mm, ion_py_mm, ion_pz_mm))
end