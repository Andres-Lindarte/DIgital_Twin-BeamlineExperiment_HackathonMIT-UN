-- Virtual BPM for the hackathon SIMION workbench.
-- It only observes ion crossings near the detector; it does not alter motion.

simion.workbench_program()

adjustable bpm_enable = 1
adjustable bpm_z_mm = 390
adjustable bpm_center_x_mm = 76
adjustable bpm_center_y_mm = 76
adjustable bpm_core_rx_mm = 9
adjustable bpm_core_ry_mm = 9
adjustable bpm_side_rx_mm = 15
adjustable bpm_side_ry_mm = 15
adjustable bpm_side_offset_mm = 10
adjustable bpm_print_hits = 0

adjustable detector_valid_enable = 1
adjustable detector_front_z_mm = 403
adjustable detector_x_min_mm = 70
adjustable detector_x_max_mm = 82
adjustable detector_y_min_mm = 70
adjustable detector_y_max_mm = 83
adjustable detector_theta_max_deg = 180
adjustable detector_require_angle = 0
adjustable detector_z_margin_mm = 2

local previous = {}
local seen = {}
local detector_seen = {}

local launched = 0
local crossings = 0
local center_hits = 0
local left_hits = 0
local right_hits = 0
local down_hits = 0
local up_hits = 0
local score_sum = 0
local sum_x = 0
local sum_y = 0
local sum_x2 = 0
local sum_y2 = 0

local detector_crossings = 0
local detector_in_window = 0
local detector_valid = 0
local detector_wrong_side = 0
local detector_bad_angle = 0
local detector_outside_window = 0
local detector_theta_sum = 0
local detector_theta2_sum = 0
local detector_theta_max = 0
local detector_sum_x = 0
local detector_sum_y = 0
local detector_sum_x2 = 0
local detector_sum_y2 = 0
local face_seen = {}
local face_x_min = 0
local face_x_max = 0
local face_y_min = 0
local face_y_max = 0
local face_z_min = 0
local face_z_max = 0
local terminal_angles = {}
local terminal_count = 0
local terminal_theta_sum = 0
local terminal_theta2_sum = 0
local terminal_theta_max = 0
local terminal_forward_z = 0
local terminal_backward_z = 0
local contact_angle_count = 0
local contact_angle_forward = 0
local contact_angle_backward = 0
local contact_angles = {}
local contact_theta_sum = 0
local contact_theta2_sum = 0
local contact_theta_max = 0
local contact_speed_sum = 0
local contact_speed2_sum = 0
local contact_speed_min = 0
local contact_speed_max = 0
local contact_vperp_sum = 0
local contact_vperp2_sum = 0
local contact_vperp_min = 0
local contact_vperp_max = 0
local contact_vz_sum = 0
local contact_vz2_sum = 0
local contact_vz_min = 0
local contact_vz_max = 0

local function reset_contact_stats()
  contact_angle_count = 0
  contact_angle_forward = 0
  contact_angle_backward = 0
  contact_angles = {}
  contact_theta_sum = 0
  contact_theta2_sum = 0
  contact_theta_max = 0
  contact_speed_sum = 0
  contact_speed2_sum = 0
  contact_speed_min = 0
  contact_speed_max = 0
  contact_vperp_sum = 0
  contact_vperp2_sum = 0
  contact_vperp_min = 0
  contact_vperp_max = 0
  contact_vz_sum = 0
  contact_vz2_sum = 0
  contact_vz_min = 0
  contact_vz_max = 0
end

local function reset_bpm()
  previous = {}
  seen = {}
  launched = 0
  crossings = 0
  center_hits = 0
  left_hits = 0
  right_hits = 0
  down_hits = 0
  up_hits = 0
  score_sum = 0
  sum_x = 0
  sum_y = 0
  sum_x2 = 0
  sum_y2 = 0
  detector_seen = {}
  detector_crossings = 0
  detector_in_window = 0
  detector_valid = 0
  detector_wrong_side = 0
  detector_bad_angle = 0
  detector_outside_window = 0
  detector_theta_sum = 0
  detector_theta2_sum = 0
  detector_theta_max = 0
  detector_sum_x = 0
  detector_sum_y = 0
  detector_sum_x2 = 0
  detector_sum_y2 = 0
  face_seen = {}
  face_x_min = 0
  face_x_max = 0
  face_y_min = 0
  face_y_max = 0
  face_z_min = 0
  face_z_max = 0
  terminal_angles = {}
  terminal_count = 0
  terminal_theta_sum = 0
  terminal_theta2_sum = 0
  terminal_theta_max = 0
  terminal_forward_z = 0
  terminal_backward_z = 0
  reset_contact_stats()
end

local function in_ellipse(x, y, cx, cy, rx, ry)
  if rx <= 0 or ry <= 0 then
    return false
  end
  local dx = (x - cx) / rx
  local dy = (y - cy) / ry
  return dx * dx + dy * dy <= 1
end

local function record_crossing(ion, x, y)
  crossings = crossings + 1
  sum_x = sum_x + x
  sum_y = sum_y + y
  sum_x2 = sum_x2 + x * x
  sum_y2 = sum_y2 + y * y

  local local_score = 0
  local cx = bpm_center_x_mm
  local cy = bpm_center_y_mm
  local off = bpm_side_offset_mm

  if in_ellipse(x, y, cx - off, cy, bpm_side_rx_mm, bpm_side_ry_mm) then
    left_hits = left_hits + 1
    local_score = math.max(local_score, 0.65)
  end
  if in_ellipse(x, y, cx + off, cy, bpm_side_rx_mm, bpm_side_ry_mm) then
    right_hits = right_hits + 1
    local_score = math.max(local_score, 0.65)
  end
  if in_ellipse(x, y, cx, cy - off, bpm_side_rx_mm, bpm_side_ry_mm) then
    down_hits = down_hits + 1
    local_score = math.max(local_score, 0.65)
  end
  if in_ellipse(x, y, cx, cy + off, bpm_side_rx_mm, bpm_side_ry_mm) then
    up_hits = up_hits + 1
    local_score = math.max(local_score, 0.65)
  end
  if in_ellipse(x, y, cx, cy, bpm_core_rx_mm, bpm_core_ry_mm) then
    center_hits = center_hits + 1
    local_score = math.max(local_score, 1.0)
  end

  score_sum = score_sum + local_score

  if bpm_print_hits ~= 0 then
    print(string.format("BPM_REAL_HIT ion=%d x_mm=%.9g y_mm=%.9g z_mm=%.9g score=%.6g",
      ion, x, y, bpm_z_mm, local_score))
  end
end

local function record_detector_crossing(x, y)
  detector_crossings = detector_crossings + 1
  detector_sum_x = detector_sum_x + x
  detector_sum_y = detector_sum_y + y
  detector_sum_x2 = detector_sum_x2 + x * x
  detector_sum_y2 = detector_sum_y2 + y * y

  local in_window =
    x >= detector_x_min_mm and x <= detector_x_max_mm
    and y >= detector_y_min_mm and y <= detector_y_max_mm
  if in_window then
    detector_in_window = detector_in_window + 1
  else
    detector_outside_window = detector_outside_window + 1
  end

  local speed = math.sqrt(
    ion_vx_mm * ion_vx_mm + ion_vy_mm * ion_vy_mm + ion_vz_mm * ion_vz_mm
  )
  local theta = 180
  if speed > 1e-30 then
    if ion_vz_mm > 0 then
      theta = math.deg(math.atan2(
        math.sqrt(ion_vx_mm * ion_vx_mm + ion_vy_mm * ion_vy_mm),
        ion_vz_mm
      ))
    else
      detector_wrong_side = detector_wrong_side + 1
    end
  else
    detector_wrong_side = detector_wrong_side + 1
  end

  detector_theta_sum = detector_theta_sum + theta
  detector_theta2_sum = detector_theta2_sum + theta * theta
  detector_theta_max = math.max(detector_theta_max, theta)

  if in_window and ion_vz_mm > 0
      and (detector_require_angle == 0 or theta <= detector_theta_max_deg) then
    detector_valid = detector_valid + 1
  elseif in_window and ion_vz_mm > 0 then
    detector_bad_angle = detector_bad_angle + 1
  end
end

local function record_detector_terminal()
  if detector_valid_enable == 0 or detector_seen[ion_number] ~= nil then
    return
  end
  local in_detector_z =
    ion_pz_mm >= detector_front_z_mm - detector_z_margin_mm
    and ion_pz_mm <= detector_front_z_mm + 6.0 + detector_z_margin_mm
  local in_detector_xy =
    ion_px_mm >= detector_x_min_mm and ion_px_mm <= detector_x_max_mm
    and ion_py_mm >= detector_y_min_mm and ion_py_mm <= detector_y_max_mm
  if in_detector_z and in_detector_xy then
    detector_seen[ion_number] = 1
    record_detector_crossing(ion_px_mm, ion_py_mm)
  end
end

local function record_terminal_angle()
  terminal_count = terminal_count + 1
  local theta = 180
  if ion_vz_mm > 0 then
    terminal_forward_z = terminal_forward_z + 1
    theta = math.deg(math.atan2(
      math.sqrt(ion_vx_mm * ion_vx_mm + ion_vy_mm * ion_vy_mm),
      ion_vz_mm
    ))
  else
    terminal_backward_z = terminal_backward_z + 1
  end
  terminal_angles[#terminal_angles + 1] = theta
  terminal_theta_sum = terminal_theta_sum + theta
  terminal_theta2_sum = terminal_theta2_sum + theta * theta
  terminal_theta_max = math.max(terminal_theta_max, theta)
end

local function record_detector_contact_angle()
  local in_detector_z =
    ion_pz_mm >= detector_front_z_mm - detector_z_margin_mm
    and ion_pz_mm <= detector_front_z_mm + 6.0 + detector_z_margin_mm
  local in_detector_xy =
    ion_px_mm >= detector_x_min_mm and ion_px_mm <= detector_x_max_mm
    and ion_py_mm >= detector_y_min_mm and ion_py_mm <= detector_y_max_mm
  if not (in_detector_z and in_detector_xy) then
    return
  end

  contact_angle_count = contact_angle_count + 1
  if ion_vz_mm <= 0 then
    contact_angle_backward = contact_angle_backward + 1
    return
  end

  contact_angle_forward = contact_angle_forward + 1
  local speed = math.sqrt(
    ion_vx_mm * ion_vx_mm + ion_vy_mm * ion_vy_mm + ion_vz_mm * ion_vz_mm
  )
  local vperp = math.sqrt(ion_vx_mm * ion_vx_mm + ion_vy_mm * ion_vy_mm)
  local theta = math.deg(math.atan2(
    vperp,
    ion_vz_mm
  ))
  contact_angles[#contact_angles + 1] = theta
  contact_theta_sum = contact_theta_sum + theta
  contact_theta2_sum = contact_theta2_sum + theta * theta
  contact_theta_max = math.max(contact_theta_max, theta)
  contact_speed_sum = contact_speed_sum + speed
  contact_speed2_sum = contact_speed2_sum + speed * speed
  if contact_angle_forward == 1 or speed < contact_speed_min then
    contact_speed_min = speed
  end
  if contact_angle_forward == 1 or speed > contact_speed_max then
    contact_speed_max = speed
  end
  contact_vperp_sum = contact_vperp_sum + vperp
  contact_vperp2_sum = contact_vperp2_sum + vperp * vperp
  if contact_angle_forward == 1 or vperp < contact_vperp_min then
    contact_vperp_min = vperp
  end
  if contact_angle_forward == 1 or vperp > contact_vperp_max then
    contact_vperp_max = vperp
  end
  contact_vz_sum = contact_vz_sum + ion_vz_mm
  contact_vz2_sum = contact_vz2_sum + ion_vz_mm * ion_vz_mm
  if contact_angle_forward == 1 or ion_vz_mm < contact_vz_min then
    contact_vz_min = ion_vz_mm
  end
  if contact_angle_forward == 1 or ion_vz_mm > contact_vz_max then
    contact_vz_max = ion_vz_mm
  end
end

local function between(v, lo, hi)
  return v >= lo and v <= hi
end

local function check_face_crossings()
  if detector_valid_enable == 0 or face_seen[ion_number] ~= nil then
    return
  end
  local prev = previous[ion_number]
  if prev == nil then
    return
  end
  local x0, y0, z0 = prev[1], prev[2], prev[3]
  local x1, y1, z1 = ion_px_mm, ion_py_mm, ion_pz_mm
  local function interp(v0, v1, plane)
    local denom = v1 - v0
    if math.abs(denom) <= 1e-12 then
      return nil
    end
    return (plane - v0) / denom
  end
  local function valid_t(t)
    return t ~= nil and t >= 0 and t <= 1
  end

  local t = interp(x0, x1, detector_x_min_mm)
  if valid_t(t) and x0 < detector_x_min_mm and x1 >= detector_x_min_mm then
    local y = y0 + t * (y1 - y0)
    local z = z0 + t * (z1 - z0)
    if between(y, detector_y_min_mm, detector_y_max_mm) and between(z, detector_front_z_mm, detector_front_z_mm + 6.0) then
      face_x_min = face_x_min + 1
      face_seen[ion_number] = 1
      return
    end
  end
  t = interp(x0, x1, detector_x_max_mm)
  if valid_t(t) and x0 > detector_x_max_mm and x1 <= detector_x_max_mm then
    local y = y0 + t * (y1 - y0)
    local z = z0 + t * (z1 - z0)
    if between(y, detector_y_min_mm, detector_y_max_mm) and between(z, detector_front_z_mm, detector_front_z_mm + 6.0) then
      face_x_max = face_x_max + 1
      face_seen[ion_number] = 1
      return
    end
  end
  t = interp(y0, y1, detector_y_min_mm)
  if valid_t(t) and y0 < detector_y_min_mm and y1 >= detector_y_min_mm then
    local x = x0 + t * (x1 - x0)
    local z = z0 + t * (z1 - z0)
    if between(x, detector_x_min_mm, detector_x_max_mm) and between(z, detector_front_z_mm, detector_front_z_mm + 6.0) then
      face_y_min = face_y_min + 1
      face_seen[ion_number] = 1
      return
    end
  end
  t = interp(y0, y1, detector_y_max_mm)
  if valid_t(t) and y0 > detector_y_max_mm and y1 <= detector_y_max_mm then
    local x = x0 + t * (x1 - x0)
    local z = z0 + t * (z1 - z0)
    if between(x, detector_x_min_mm, detector_x_max_mm) and between(z, detector_front_z_mm, detector_front_z_mm + 6.0) then
      face_y_max = face_y_max + 1
      face_seen[ion_number] = 1
      return
    end
  end
  t = interp(z0, z1, detector_front_z_mm)
  if valid_t(t) and z0 < detector_front_z_mm and z1 >= detector_front_z_mm then
    local x = x0 + t * (x1 - x0)
    local y = y0 + t * (y1 - y0)
    if between(x, detector_x_min_mm, detector_x_max_mm) and between(y, detector_y_min_mm, detector_y_max_mm) then
      face_z_min = face_z_min + 1
      face_seen[ion_number] = 1
      return
    end
  end
  t = interp(z0, z1, detector_front_z_mm + 6.0)
  if valid_t(t) and z0 > detector_front_z_mm + 6.0 and z1 <= detector_front_z_mm + 6.0 then
    local x = x0 + t * (x1 - x0)
    local y = y0 + t * (y1 - y0)
    if between(x, detector_x_min_mm, detector_x_max_mm) and between(y, detector_y_min_mm, detector_y_max_mm) then
      face_z_max = face_z_max + 1
      face_seen[ion_number] = 1
      return
    end
  end
end

function segment.initialize_run()
  reset_bpm()
end

function segment.initialize()
  if ion_number > launched then
    launched = ion_number
  end
  previous[ion_number] = {ion_px_mm, ion_py_mm, ion_pz_mm}
end

function segment.other_actions()
  if ion_splat ~= 0 then
    record_detector_terminal()
  end
  if bpm_enable ~= 0 then
    local prev = previous[ion_number]
    if prev ~= nil and seen[ion_number] == nil then
      local z0 = prev[3]
      local z1 = ion_pz_mm
      if z0 < bpm_z_mm and z1 >= bpm_z_mm then
        local denom = z1 - z0
        if math.abs(denom) > 1e-12 then
          local t = (bpm_z_mm - z0) / denom
          local x = prev[1] + t * (ion_px_mm - prev[1])
          local y = prev[2] + t * (ion_py_mm - prev[2])
          seen[ion_number] = 1
          record_crossing(ion_number, x, y)
        end
      end
    end
  end
  if detector_valid_enable ~= 0 then
    check_face_crossings()
    local prev = previous[ion_number]
    if prev ~= nil and detector_seen[ion_number] == nil then
      local z0 = prev[3]
      local z1 = ion_pz_mm
      if z0 < detector_front_z_mm and z1 >= detector_front_z_mm then
        local denom = z1 - z0
        if math.abs(denom) > 1e-12 then
          local t = (detector_front_z_mm - z0) / denom
          local x = prev[1] + t * (ion_px_mm - prev[1])
          local y = prev[2] + t * (ion_py_mm - prev[2])
          detector_seen[ion_number] = 1
          record_detector_crossing(x, y)
        end
      elseif z0 > detector_front_z_mm and z1 <= detector_front_z_mm then
        detector_seen[ion_number] = 1
        detector_wrong_side = detector_wrong_side + 1
      end
    end
  end
  previous[ion_number] = {ion_px_mm, ion_py_mm, ion_pz_mm}
end

function segment.terminate()
  record_terminal_angle()
  record_detector_terminal()
  record_detector_contact_angle()
end

function segment.terminate_run()
  local mean_x = 0
  local mean_y = 0
  local sigma_x = 0
  local sigma_y = 0
  if crossings > 0 then
    mean_x = sum_x / crossings
    mean_y = sum_y / crossings
    sigma_x = math.sqrt(math.max(0, sum_x2 / crossings - mean_x * mean_x))
    sigma_y = math.sqrt(math.max(0, sum_y2 / crossings - mean_y * mean_y))
  end
  local score = 0
  if launched > 0 then
    score = score_sum / launched
  end

  print(string.format(
    "BPM_REAL_SUMMARY launched=%d crossings=%d center=%d left=%d right=%d down=%d up=%d score=%.9g mean_x_mm=%.9g mean_y_mm=%.9g sigma_x_mm=%.9g sigma_y_mm=%.9g z_mm=%.9g",
    launched, crossings, center_hits, left_hits, right_hits, down_hits, up_hits,
    score, mean_x, mean_y, sigma_x, sigma_y, bpm_z_mm
  ))

  local detector_mean_x = 0
  local detector_mean_y = 0
  local detector_sigma_x = 0
  local detector_sigma_y = 0
  local detector_theta_mean = 0
  local detector_theta_sigma = 0
  if detector_crossings > 0 then
    detector_mean_x = detector_sum_x / detector_crossings
    detector_mean_y = detector_sum_y / detector_crossings
    detector_sigma_x = math.sqrt(math.max(0, detector_sum_x2 / detector_crossings - detector_mean_x * detector_mean_x))
    detector_sigma_y = math.sqrt(math.max(0, detector_sum_y2 / detector_crossings - detector_mean_y * detector_mean_y))
    detector_theta_mean = detector_theta_sum / detector_crossings
    detector_theta_sigma = math.sqrt(math.max(0, detector_theta2_sum / detector_crossings - detector_theta_mean * detector_theta_mean))
  end
  print(string.format(
    "DETECTOR_VALID_SUMMARY crossings=%d in_window=%d valid=%d wrong_side=%d bad_angle=%d outside_window=%d theta_mean_deg=%.9g theta_sigma_deg=%.9g theta_max_deg=%.9g mean_x_mm=%.9g mean_y_mm=%.9g sigma_x_mm=%.9g sigma_y_mm=%.9g front_z_mm=%.9g theta_limit_deg=%.9g",
    detector_crossings, detector_in_window, detector_valid, detector_wrong_side,
    detector_bad_angle, detector_outside_window, detector_theta_mean,
    detector_theta_sigma, detector_theta_max, detector_mean_x, detector_mean_y,
    detector_sigma_x, detector_sigma_y, detector_front_z_mm,
    detector_theta_max_deg
  ))
  print(string.format(
    "DETECTOR_FACE_SUMMARY x_min=%d x_max=%d y_min=%d y_max=%d z_min=%d z_max=%d",
    face_x_min, face_x_max, face_y_min, face_y_max, face_z_min, face_z_max
  ))
  table.sort(terminal_angles)
  local function percentile(p)
    if #terminal_angles == 0 then
      return 0
    end
    local index = math.floor(1 + (#terminal_angles - 1) * p + 0.5)
    if index < 1 then index = 1 end
    if index > #terminal_angles then index = #terminal_angles end
    return terminal_angles[index]
  end
  local terminal_theta_mean = 0
  local terminal_theta_sigma = 0
  if terminal_count > 0 then
    terminal_theta_mean = terminal_theta_sum / terminal_count
    terminal_theta_sigma = math.sqrt(math.max(0, terminal_theta2_sum / terminal_count - terminal_theta_mean * terminal_theta_mean))
  end
  print(string.format(
    "TERMINAL_ANGLE_SUMMARY count=%d forward_z=%d backward_z=%d theta_mean_deg=%.9g theta_sigma_deg=%.9g theta_p50_deg=%.9g theta_p90_deg=%.9g theta_p95_deg=%.9g theta_p99_deg=%.9g theta_max_deg=%.9g",
    terminal_count, terminal_forward_z, terminal_backward_z,
    terminal_theta_mean, terminal_theta_sigma, percentile(0.50),
    percentile(0.90), percentile(0.95), percentile(0.99), terminal_theta_max
  ))

  table.sort(contact_angles)
  local function contact_percentile(p)
    if #contact_angles == 0 then
      return 0
    end
    local index = math.floor(1 + (#contact_angles - 1) * p + 0.5)
    if index < 1 then index = 1 end
    if index > #contact_angles then index = #contact_angles end
    return contact_angles[index]
  end
  local contact_theta_mean = 0
  local contact_theta_sigma = 0
  local contact_speed_mean = 0
  local contact_speed_sigma = 0
  local contact_speed_rel_sigma = 0
  local contact_vperp_mean = 0
  local contact_vperp_sigma = 0
  local contact_vperp_rel_sigma = 0
  local contact_vz_mean = 0
  local contact_vz_sigma = 0
  local contact_vz_rel_sigma = 0
  if contact_angle_forward > 0 then
    contact_theta_mean = contact_theta_sum / contact_angle_forward
    contact_theta_sigma = math.sqrt(math.max(0, contact_theta2_sum / contact_angle_forward - contact_theta_mean * contact_theta_mean))
    contact_speed_mean = contact_speed_sum / contact_angle_forward
    contact_speed_sigma = math.sqrt(math.max(0, contact_speed2_sum / contact_angle_forward - contact_speed_mean * contact_speed_mean))
    if math.abs(contact_speed_mean) > 1e-30 then
      contact_speed_rel_sigma = contact_speed_sigma / math.abs(contact_speed_mean)
    end
    contact_vperp_mean = contact_vperp_sum / contact_angle_forward
    contact_vperp_sigma = math.sqrt(math.max(0, contact_vperp2_sum / contact_angle_forward - contact_vperp_mean * contact_vperp_mean))
    if math.abs(contact_vperp_mean) > 1e-30 then
      contact_vperp_rel_sigma = contact_vperp_sigma / math.abs(contact_vperp_mean)
    end
    contact_vz_mean = contact_vz_sum / contact_angle_forward
    contact_vz_sigma = math.sqrt(math.max(0, contact_vz2_sum / contact_angle_forward - contact_vz_mean * contact_vz_mean))
    if math.abs(contact_vz_mean) > 1e-30 then
      contact_vz_rel_sigma = contact_vz_sigma / math.abs(contact_vz_mean)
    end
  end
  print(string.format(
    "DETECTOR_CONTACT_ANGLE_SUMMARY count=%d forward=%d backward=%d theta_mean_deg=%.9g theta_sigma_deg=%.9g theta_p50_deg=%.9g theta_p90_deg=%.9g theta_p95_deg=%.9g theta_p99_deg=%.9g theta_max_deg=%.9g",
    contact_angle_count, contact_angle_forward, contact_angle_backward,
    contact_theta_mean, contact_theta_sigma, contact_percentile(0.50),
    contact_percentile(0.90), contact_percentile(0.95),
    contact_percentile(0.99), contact_theta_max
  ))
  print(string.format(
    "DETECTOR_CONTACT_SPEED_SUMMARY count=%d speed_mean=%.9g speed_sigma=%.9g speed_rel_sigma=%.9g speed_min=%.9g speed_max=%.9g vperp_mean=%.9g vperp_sigma=%.9g vperp_rel_sigma=%.9g vperp_min=%.9g vperp_max=%.9g vz_mean=%.9g vz_sigma=%.9g vz_rel_sigma=%.9g vz_min=%.9g vz_max=%.9g",
    contact_angle_forward, contact_speed_mean, contact_speed_sigma,
    contact_speed_rel_sigma, contact_speed_min, contact_speed_max,
    contact_vperp_mean, contact_vperp_sigma, contact_vperp_rel_sigma,
    contact_vperp_min, contact_vperp_max,
    contact_vz_mean, contact_vz_sigma, contact_vz_rel_sigma,
    contact_vz_min, contact_vz_max
  ))
end
