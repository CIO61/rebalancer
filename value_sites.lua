local namespace = {}

local IMAGE_BASE = 0x400000

local read = { [1] = core.readByte, [2] = core.readSmallInteger, [4] = core.readInteger }
local write = { [1] = core.writeCodeByte, [2] = core.writeCodeSmallInteger, [4] = core.writeCodeInteger }

-- `?` marks bytes that differ between the executables and the value itself, so a site is found
-- again after it was written. `inside`: search only this window after another site. `calls`: the
-- E8 call at this offset must reach that FUNCTIONS entry, with `mov ecx, <object>` before it.
local SITES = {
  -- getCastleBuildRangeForMapSize: distance from the own keep (half of it from an ally's keep)
  -- for castle parts, per map size; 400 is also the default case.
  castle_build_range = {
    signature = "8B 89 ? ? ? ? 8D 81 60 FF FF FF 3D F0 00 00 00 77 20 0F B6 80 ? ? ? ? "
      .. "FF 24 85 ? ? ? ? B8 ? ? ? ? C3 B8 ? ? ? ? C3 B8 ? ? ? ? C3 B8 ? ? ? ? C3",
    values = {
      map_160 = { value = 0x22, width = 4, default = 45, min = 1, max = 400 },
      map_200 = { value = 0x28, width = 4, default = 50, min = 1, max = 400 },
      map_300 = { value = 0x2E, width = 4, default = 60, min = 1, max = 400 },
      map_400 = { value = 0x34, width = 4, default = 70, min = 1, max = 400 },
    },
  },
  -- checkBuildingCanBePlacedHere, stockpile/granary/armoury case.
  storage_enemy_radius = {
    signature = "83 3D ? ? ? ? 00 0F 84 ? ? ? ? 33 DB 8B 4C 24 50 51 53 8B CE E8 ? ? ? ? "
      .. "8B 96 ? ? ? ? 8B 86 ? ? ? ? 8B 4C 24 40 6A ? 03 D5 52 03 C7 50 51 B9 ? ? ? ? E8",
    values = { radius = { value = 45, width = 1, default = 3, min = 0, max = 127 } },
    calls = { at = 58, fn = "enemy_near_check" },
  },
  -- Same function, siege tent case (fire ballista included).
  siege_tent_enemy_radius = {
    signature = "A1 ? ? ? ? 83 F8 01 0F 84 ? ? ? ? 83 F8 06 0F 84 ? ? ? ? 33 DB 8B 44 24 50 50 "
      .. "53 8B CE E8 ? ? ? ? 8B 8E ? ? ? ? 8B 96 ? ? ? ? 8B 44 24 40 6A ? 03 CD 51 03 D7 52 50 "
      .. "B9 ? ? ? ? E8",
    values = { radius = { value = 55, width = 1, default = 3, min = 0, max = 127 } },
    calls = { at = 68, fn = "enemy_near_check" },
  },
  -- validateWallPlacementAtTile, only reached from the AI's AIV building steps.
  ai_wall_enemy_radius = {
    signature = "A9 81 00 30 60 75 ? 8B 4C 24 14 6A ? 53 55 51 B9 ? ? ? ? E8 ? ? ? ? 85 C0 75 ? "
      .. "8B 54 24 14 6A 02 53 55 52 B9",
    values = { radius = { value = 12, width = 1, default = 5, min = 0, max = 127 } },
    calls = { at = 21, fn = "enemy_near_check" },
  },
  -- findNearestEnemyAndHeadTowardsIt, in the game's distance units (8 per tile).
  stance_ranges = {
    signature = "83 E8 01 89 4C 24 38 74 0F 83 E8 01 75 12 C7 44 24 24 ? ? ? ? EB 08 "
      .. "C7 44 24 24 ? ? ? ?",
    values = {
      aggressive = { value = 18, width = 4, default = 200, min = 1, max = 3200 },
      defensive = { value = 28, width = 4, default = 40, min = 1, max = 127 },
    },
  },
  -- Same function: a range equal to this value is measured from the unit's guard position.
  defensive_stance_check = {
    signature = "8B 6C 24 24 85 ED 0F 84 ? ? ? ? 66 83 BC 37 ? ? ? ? 00 0F 8C ? ? ? ? "
      .. "0F B7 84 37 ? ? ? ? 66 85 C0 74 ? 83 7C 24 38 00 75 ? 83 FD ? 75",
    values = { defensive = { value = 49, width = 1, default = 40, min = 1, max = 127 } },
    inside = { site = "stance_ranges", window = 0x400 },
  },
  -- Same function: the game only compares this count once more than one unit chases the enemy.
  stance_units_per_enemy = {
    signature = "66 83 B9 ? ? ? ? 01 7E ? 0F B7 81 ? ? ? ? 0F BF D0 6B D2 32 03 EA 66 3D ? ? "
      .. "89 6C 24 10 7C",
    values = { count = { value = 27, width = 2, default = 3, min = 2, max = 1000 } },
    inside = { site = "stance_ranges", window = 0x600 },
  },
  -- updateTribeCombatStanceBehavior, in tiles.
  aggressive_melee_building_range = {
    signature = "0F BF 56 5C 3B DA 7C ? 8B 44 24 10 6A ? 50 B9 ? ? ? ? E8",
    values = { range = { value = 13, width = 1, default = 15, min = 1, max = 127 } },
    calls = { at = 20, fn = "building_search" },
  },
}

local FUNCTIONS = {
  -- isEnemyTooCloseUnk(player, x, y, radius): distance squared < radius squared, so 0 never refuses.
  enemy_near_check = "8B 54 24 08 81 FA 8F 01 00 00 56 77 1E 8B 74 24 10 81 FE 8F 01 00 00 77 12 "
    .. "8B C6 69 C0 90 01 00 00 80 BC 10 ? ? ? ? 00 75 06 33 C0 5E C2 10 00 8B 44 24 14 53 55 "
    .. "8B E8 0F AF E8",
  -- aggressiveStanceTargetBuildingAtRange(unit, range)
  building_search = "83 EC 14 8B 44 24 18 69 C0 90 04 00 00 53 55 0F BF A8",
}

local code_section = nil
local resolved = {}
local functions = {}

local function find_code_section()
  local unexpected = "the game executable is not loaded the way this check expects (headers at 0x400000)"
  if core.readSmallInteger(IMAGE_BASE) ~= 0x5A4D then
    return { problem = unexpected }
  end
  local e_lfanew = core.readInteger(IMAGE_BASE + 0x3C)
  if e_lfanew < 0x40 or e_lfanew > 0x800 or core.readInteger(IMAGE_BASE + e_lfanew) ~= 0x4550 then
    return { problem = unexpected }
  end
  local file_header = IMAGE_BASE + e_lfanew + 4
  local optional_header = file_header + 0x14
  local relocations_stripped = (core.readSmallInteger(file_header + 0x12) & 1) ~= 0
  if core.readSmallInteger(optional_header) ~= 0x10B or core.readInteger(optional_header + 0x1C) ~= IMAGE_BASE
      or not relocations_stripped then
    return { problem = unexpected }
  end
  local base_of_code = IMAGE_BASE + core.readInteger(optional_header + 0x14)
  local size_of_code = core.readInteger(optional_header + 0x04)
  local size_of_image = core.readInteger(optional_header + 0x38)
  if base_of_code < IMAGE_BASE or size_of_code <= 0 or size_of_image <= 0
      or base_of_code + size_of_code > IMAGE_BASE + size_of_image then
    return { problem = "the game executable's code section is not where its headers say" }
  end
  return { first = base_of_code, stop = base_of_code + size_of_code }
end

local function get_code_section()
  if code_section == nil then
    code_section = find_code_section()
  end
  return code_section.first, code_section.stop, code_section.problem
end

-- The scanner checks `to` only between memory regions, so a match past it counts as none.
local function scan_once(signature, from, to)
  local address = core.scanForAOB(signature, from, to)
  if not address or address < from or address >= to then
    return nil, "signature not found (the game code there differs: another module changed it, "
      .. "or this game version is not supported)"
  end
  local other = core.scanForAOB(signature, address + 1, to)
  if other and other > address and other < to then
    return nil, string.format("signature found more than once (0x%X and 0x%X)", address, other)
  end
  return address
end

local function resolve_function(name)
  if functions[name] == nil then
    local from, to, problem = get_code_section()
    local address
    if problem == nil then
      address, problem = scan_once(FUNCTIONS[name], from, to)
    end
    functions[name] = { address = address, problem = problem }
  end
  return functions[name].address, functions[name].problem
end

local function check_site(site, address)
  if site == SITES.castle_build_range then
    -- The size switch must send 160, 200, 300 and 400 to the four `mov eax, value` in order.
    local byte_table = core.readInteger(address + 0x16)
    local jump_table = core.readInteger(address + 0x1D)
    local cases = { [0] = 0x21, [40] = 0x27, [140] = 0x2D, [240] = 0x33 }
    for index, offset in pairs(cases) do
      local slot = core.readByte(byte_table + index)
      if core.readInteger(jump_table + slot * 4) ~= address + offset then
        return "the map size switch does not lead to the expected values"
      end
    end
  elseif site == SITES.stance_units_per_enemy then
    if core.readInteger(address + 3) ~= core.readInteger(address + 13) then
      return "the counter field does not match"
    end
  end
  if site.calls ~= nil then
    local expected, problem = resolve_function(site.calls.fn)
    if expected == nil then
      return site.calls.fn .. ": " .. problem
    end
    local call = address + site.calls.at
    if core.readByte(call - 5) ~= 0xB9 or core.readByte(call) ~= 0xE8
        or call + 5 + core.readInteger(call + 1) ~= expected then
      return "the call after the value does not reach " .. site.calls.fn
    end
  end
  return nil
end

local function resolve(name)
  if resolved[name] ~= nil then
    return resolved[name].address, resolved[name].problem
  end
  local site = SITES[name]
  local from, to, problem = get_code_section()
  if problem == nil and site.inside ~= nil then
    local base, base_problem = resolve(site.inside.site)
    if base == nil then
      problem = site.inside.site .. ": " .. base_problem
    else
      from, to = base, base + site.inside.window
    end
  end
  local address
  if problem == nil then
    address, problem = scan_once(site.signature, from, to)
  end
  if address ~= nil then
    problem = check_site(site, address)
    if problem ~= nil then
      address = nil
    end
  end
  resolved[name] = { address = address, problem = problem }
  return address, problem
end

-- Writes all `writes` ({ site, value, to, label, keep }) or, if one can't be verified, none.
-- `keep` marks a value that is only checked and stays the game's. `check`, if given, runs once all
-- values are valid and returns a reason to refuse, or nil.
local function apply(setting, writes, check)
  local plan = {}
  for _, entry in ipairs(writes) do
    local value = SITES[entry.site].values[entry.value]
    local wanted = math.tointeger(entry.to)
    if wanted == nil or wanted < value.min or wanted > value.max then
      log(ERROR, string.format("%s not applied: %s must be a whole number from %d to %d, not %s",
        setting, entry.label, value.min, value.max, tostring(entry.to)))
      return false
    end
    local address, problem = resolve(entry.site)
    if address == nil then
      log(ERROR, string.format("%s not applied: %s: %s", setting, entry.site, problem))
      return false
    end
    local at = address + value.value
    local current = read[value.width](at)
    if current ~= value.default and current ~= wanted then
      log(ERROR, string.format("%s not applied: %s holds %d instead of the game's %d "
        .. "(changed by another module?)", setting, entry.site, current, value.default))
      return false
    end
    plan[#plan + 1] = { at = at, value = value, to = wanted, current = current, label = entry.label,
      keep = entry.keep }
  end
  local problem = check and check()
  if problem ~= nil then
    log(ERROR, string.format("%s not applied: %s", setting, problem))
    return false
  end
  for _, step in ipairs(plan) do
    if step.current ~= step.to then
      write[step.value.width](step.at, step.to)
    end
    if not step.keep then
      log(INFO, string.format("%s = %d (game default %d) at 0x%X", step.label, step.to,
        step.value.default, step.at))
    end
  end
  return true
end

local function default(site, value)
  return SITES[site].values[value].default
end

local function section(value, name, known)
  if value == nil then
    return nil
  end
  if type(value) ~= "table" then
    log(ERROR, string.format("%s not applied: it must be an object, not %s", name, type(value)))
    return nil
  end
  for key in pairs(value) do
    if not table.find(known, key) then
      log(WARNING, string.format("%s: unknown key '%s' ignored", name, tostring(key)))
    end
  end
  return value
end

function namespace.edit_building_placement(placement)
  placement = section(placement, "building_placement", { "castle_build_range", "enemy_unit_radius" })
  if placement == nil then
    return
  end
  local sizes = { "map_160", "map_200", "map_300", "map_400" }
  local range = section(placement["castle_build_range"], "building_placement.castle_build_range", sizes)
  if range ~= nil then
    local writes = {}
    for _, size in ipairs(sizes) do
      if range[size] ~= nil then
        writes[#writes + 1] = { site = "castle_build_range", value = size, to = range[size],
          label = "building_placement.castle_build_range." .. size }
      end
    end
    if #writes > 0 then
      apply("building_placement.castle_build_range", writes)
    end
  end

  local radius = section(placement["enemy_unit_radius"], "building_placement.enemy_unit_radius",
    { "storage", "siege_tents", "ai_walls" })
  if radius ~= nil then
    for _, entry in ipairs({
      { "storage", "storage_enemy_radius" },
      { "siege_tents", "siege_tent_enemy_radius" },
      { "ai_walls", "ai_wall_enemy_radius" },
    }) do
      local key, site = entry[1], entry[2]
      if radius[key] ~= nil then
        local label = "building_placement.enemy_unit_radius." .. key
        apply(label, { { site = site, value = "radius", to = radius[key], label = label } })
      end
    end
  end
end

function namespace.edit_stances(stances)
  stances = section(stances, "stances", { "aggressive_range", "defensive_range", "max_units_per_enemy",
    "aggressive_melee_building_range" })
  if stances == nil then
    return
  end
  local aggressive, defensive = stances["aggressive_range"], stances["defensive_range"]
  if aggressive ~= nil or defensive ~= nil then
    local new_aggressive, new_defensive = aggressive, defensive
    if new_aggressive == nil then
      new_aggressive = default("stance_ranges", "aggressive")
    end
    if new_defensive == nil then
      new_defensive = default("stance_ranges", "defensive")
    end
    apply("stances.aggressive_range/defensive_range", {
      { site = "stance_ranges", value = "aggressive", to = new_aggressive,
        label = "stances.aggressive_range", keep = aggressive == nil },
      { site = "stance_ranges", value = "defensive", to = new_defensive,
        label = "stances.defensive_range", keep = defensive == nil },
      { site = "defensive_stance_check", value = "defensive", to = new_defensive,
        label = "stances.defensive_range (stance check)", keep = defensive == nil },
    }, function()
      if math.tointeger(new_aggressive) == math.tointeger(new_defensive) then
        return "aggressive_range and defensive_range must differ "
          .. "(the game tells the two stances apart by the defensive range)"
      end
    end)
  end

  if stances["max_units_per_enemy"] ~= nil then
    apply("stances.max_units_per_enemy", { { site = "stance_units_per_enemy", value = "count",
      to = stances["max_units_per_enemy"], label = "stances.max_units_per_enemy" } })
  end

  if stances["aggressive_melee_building_range"] ~= nil then
    apply("stances.aggressive_melee_building_range", { { site = "aggressive_melee_building_range",
      value = "range", to = stances["aggressive_melee_building_range"],
      label = "stances.aggressive_melee_building_range" } })
  end
end

namespace.sites = SITES

return namespace
