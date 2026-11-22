--[[
  Single game values that Rebalancer changes inside the game's code: castle build range,
  building placement distances to enemy units, and stance behaviour.

  Every site is found by a signature that has to match exactly once in the game's code
  section. Before anything is written, the bytes around the value are checked (signature and
  related sites), and the value itself must still be the game's default. A setting is applied
  whole or not at all: when one of its sites cannot be verified, none of them is written and
  the log names the setting, the site and the reason.

  Nothing in here runs unless the balance file contains the setting: a missing key keeps the
  game's own value and nothing is scanned or written for it.
]]

local namespace = {}

local LOG_PREFIX = "[rebalancer] "

local function readBytes(address, count)
  local bytes = core.readBytes(address, count)
  local result = {}
  for index = 1, count do
    result[index] = bytes[index] & 0xFF
  end
  return result
end

local function readUnsigned(address, width)
  local bytes = readBytes(address, width)
  local value = 0
  for index = width, 1, -1 do
    value = (value << 8) | bytes[index]
  end
  return value
end

local function readSigned(address, width)
  local value = readUnsigned(address, width)
  local sign = 1 << (width * 8 - 1)
  if value >= sign then
    value = value - (sign << 1)
  end
  return value
end

local function encode(value, width)
  local bytes = {}
  for index = 1, width do
    bytes[index] = (value >> ((index - 1) * 8)) & 0xFF
  end
  return bytes
end

-- The game's code section, read from the executable's PE headers in memory. Both executables are
-- linked for 0x400000 without relocations (no DYNAMIC_BASE), so Windows can only load them there;
-- the headers have to confirm that, otherwise nothing is scanned.
local IMAGE_BASE = 0x400000
local codeFirst, codeEnd, codeProblem

local function readCodeSection()
  local unexpected = "the game executable is not loaded the way this check expects (headers at 0x400000)"
  if readUnsigned(IMAGE_BASE, 2) ~= 0x5A4D then                     -- "MZ"
    return nil, nil, unexpected
  end
  local offset = readUnsigned(IMAGE_BASE + 0x3C, 4)                 -- e_lfanew
  if offset < 0x40 or offset > 0x800 or readUnsigned(IMAGE_BASE + offset, 4) ~= 0x4550 then  -- "PE\0\0"
    return nil, nil, unexpected
  end
  local headers = IMAGE_BASE + offset
  local optional = headers + 0x18
  if readUnsigned(optional, 2) ~= 0x10B                             -- PE32
      or readUnsigned(optional + 0x1C, 4) ~= IMAGE_BASE             -- ImageBase
      or (readUnsigned(headers + 0x16, 2) & 1) == 0 then            -- relocations stripped
    return nil, nil, unexpected
  end
  local first = IMAGE_BASE + readUnsigned(optional + 0x14, 4)        -- BaseOfCode
  local size = readUnsigned(optional + 0x04, 4)                      -- SizeOfCode
  if size == 0 or first + size > IMAGE_BASE + readUnsigned(optional + 0x38, 4) then  -- SizeOfImage
    return nil, nil, "the game executable's code section is not where its headers say"
  end
  return first, first + size, nil
end

local function codeSection()
  if codeFirst == nil and codeProblem == nil then
    codeFirst, codeEnd, codeProblem = readCodeSection()
  end
  return codeFirst, codeEnd, codeProblem
end

-- Address of the call target of the `E8 rel32` at `address`, or nil if there is no such call.
local function callTarget(address)
  if readUnsigned(address, 1) ~= 0xE8 then
    return nil
  end
  return (address + 5 + readSigned(address + 1, 4)) & 0xFFFFFFFF
end

-- Finds `signature` exactly once between `from` and `to`.
local function scanOnce(signature, from, to)
  local ok, address = pcall(core.scanForAOB, signature, from, to)
  if not ok or type(address) ~= "number" or address < from or address >= to then
    return nil, "signature not found"
  end
  local again, other = pcall(core.scanForAOB, signature, address + 1, to)
  if again and type(other) == "number" and other > address and other < to then
    return nil, string.format("signature found more than once (0x%X and 0x%X)", address, other)
  end
  return address
end

--[[
  The sites. `signature` uses ? for bytes that differ between the executables and for the value
  itself (so a site is found again after it has been written). `value` is the offset of the
  value in the match, `width` its size in bytes, `default` the game's value (the same in
  Stronghold Crusader 1.41 and Crusader Extreme 1.41). `inside` limits the search to a window
  after another site, for sites that must lie in the same function.
]]
local SITES = {
  -- TileMapState::getCastleBuildRangeForMapSize: a switch on the map size returning the
  -- distance from the own keep (half of it from an ally's keep) within which castle parts may be
  -- placed. 400 is also the default case. Used by the placement check, the placement preview,
  -- the castle site check, player walls and moat/terrain placement alike.
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
  -- TileMapState::checkBuildingCanBePlacedHere, stockpile/granary/armoury case: enemy unit
  -- distance, checked only outside 1-player modes. `push radius` before the enemy-near check.
  storage_enemy_radius = {
    signature = "83 3D ? ? ? ? 00 0F 84 ? ? ? ? 33 DB 8B 4C 24 50 51 53 8B CE E8 ? ? ? ? "
      .. "8B 96 ? ? ? ? 8B 86 ? ? ? ? 8B 4C 24 40 6A ? 03 D5 52 03 C7 50 51 B9 ? ? ? ? E8",
    values = { radius = { value = 45, width = 1, default = 3, min = 0, max = 127 } },
    near_check = 58,
  },
  -- Same function, siege tent case (catapult, trebuchet, siege tower, ram, shield and the
  -- type-358 tent); skipped only in the map editor and the "Siege That" mode.
  siege_tent_enemy_radius = {
    signature = "A1 ? ? ? ? 83 F8 01 0F 84 ? ? ? ? 83 F8 06 0F 84 ? ? ? ? 33 DB 8B 44 24 50 50 "
      .. "53 8B CE E8 ? ? ? ? 8B 8E ? ? ? ? 8B 96 ? ? ? ? 8B 44 24 40 6A ? 03 CD 51 03 D7 52 50 "
      .. "B9 ? ? ? ? E8",
    values = { radius = { value = 55, width = 1, default = 3, min = 0, max = 127 } },
    near_check = 68,
  },
  -- TileMapState::validateWallPlacementAtTile, reached only from the AI's AIV building steps:
  -- enemy unit distance for each wall, crenel and stair tile the AI places.
  ai_wall_enemy_radius = {
    signature = "A9 81 00 30 60 75 ? 8B 4C 24 14 6A ? 53 55 51 B9 ? ? ? ? E8 ? ? ? ? 85 C0 75 ? "
      .. "8B 54 24 14 6A 02 53 55 52 B9",
    values = { radius = { value = 12, width = 1, default = 5, min = 0, max = 127 } },
    near_check = 21,
  },
  -- UnitsState::findNearestEnemyAndHeadTowardsIt: the search range of units in aggressive and
  -- defensive stance, in the game's distance units (8 per tile).
  stance_ranges = {
    signature = "83 E8 01 89 4C 24 38 74 0F 83 E8 01 75 12 C7 44 24 24 ? ? ? ? EB 08 "
      .. "C7 44 24 24 ? ? ? ?",
    values = {
      aggressive = { value = 18, width = 4, default = 200, min = 1, max = 3200 },
      defensive = { value = 28, width = 4, default = 40, min = 1, max = 127 },
    },
  },
  -- Same function: the range is compared with the defensive value to decide whether the
  -- distance is measured from the unit's guard position. Must follow the defensive range.
  defensive_stance_check = {
    signature = "8B 6C 24 24 85 ED 0F 84 ? ? ? ? 66 83 BC 37 ? ? ? ? 00 0F 8C ? ? ? ? "
      .. "0F B7 84 37 ? ? ? ? 66 85 C0 74 ? 83 7C 24 38 00 75 ? 83 FD ? 75",
    values = { defensive = { value = 49, width = 1, default = 40, min = 1, max = 127 } },
    inside = { site = "stance_ranges", window = 0x400 },
  },
  -- Same function: how many units may already go after one enemy before others ignore it
  -- (the count is only checked once it is above one).
  stance_units_per_enemy = {
    signature = "66 83 B9 ? ? ? ? 01 7E ? 0F B7 81 ? ? ? ? 0F BF D0 6B D2 32 03 EA 66 3D ? ? "
      .. "89 6C 24 10 7C",
    values = { count = { value = 27, width = 2, default = 3, min = 2, max = 1000 } },
    inside = { site = "stance_ranges", window = 0x600 },
  },
  -- TribesState::updateTribeCombatStanceBehavior: how far (tiles) melee units in aggressive
  -- stance look for an enemy building to attack.
  aggressive_melee_building_range = {
    signature = "0F BF 56 5C 3B DA 7C ? 8B 44 24 10 6A ? 50 B9 ? ? ? ? E8",
    values = { range = { value = 13, width = 1, default = 15, min = 1, max = 127 } },
  },
}

local resolved = {}   -- site name -> { address = match, problem = text }

local function checkSite(name, site, address)
  if site == SITES.castle_build_range then
    -- The size switch must send 160, 200, 300 and 400 to the four `mov eax, value` in order.
    local bytes = readUnsigned(address + 0x16, 4)
    local jumps = readUnsigned(address + 0x1D, 4)
    local cases = { [0] = 0x21, [40] = 0x27, [140] = 0x2D, [240] = 0x33 }
    for index, offset in pairs(cases) do
      local slot = readUnsigned(bytes + index, 1)
      if readUnsigned(jumps + slot * 4, 4) ~= address + offset then
        return "the map size switch does not lead to the expected values"
      end
    end
  elseif site == SITES.stance_units_per_enemy then
    -- Both instructions read the same unit field (units already chasing this enemy).
    if readUnsigned(address + 3, 4) ~= readUnsigned(address + 13, 4) then
      return "the counter field does not match"
    end
  end
  return nil
end

local function resolve(name)
  if resolved[name] ~= nil then
    return resolved[name].address, resolved[name].problem
  end
  local site = SITES[name]
  local from, to, problem = codeSection()
  if problem ~= nil then
    resolved[name] = { problem = problem }
    return nil, problem
  end
  if site.inside ~= nil then
    local base, baseProblem = resolve(site.inside.site)
    if base == nil then
      problem = site.inside.site .. ": " .. baseProblem
    else
      from, to = base, base + site.inside.window
    end
  end
  local address
  if problem == nil then
    address, problem = scanOnce(site.signature, from, to)
  end
  if address ~= nil then
    problem = checkSite(name, site, address)
    if problem ~= nil then
      address = nil
    end
  end
  resolved[name] = { address = address, problem = problem }
  return address, problem
end

-- The enemy-near check the three placement radii are passed to must be one and the same game
-- function, called on the same object.
local function checkNearCalls()
  local target, object
  for _, name in ipairs({ "storage_enemy_radius", "siege_tent_enemy_radius", "ai_wall_enemy_radius" }) do
    local address, problem = resolve(name)
    if address == nil then
      return name .. ": " .. problem
    end
    local call = address + SITES[name].near_check
    local this = readUnsigned(call - 4, 4)
    local callee = callTarget(call)
    if readUnsigned(call - 5, 1) ~= 0xB9 or callee == nil then
      return name .. ": no enemy-near check after the value"
    end
    if target == nil then
      target, object = callee, this
    elseif callee ~= target or this ~= object then
      return name .. ": the enemy-near check differs from the other placement sites"
    end
  end
  return nil
end

--[[
  Writes a group of values that belong together. `writes` is a list of
  { site = name, value = key, to = number, label = setting name, keep = true for a value that is
  only checked and stays the game's }. Every value is checked against its range and every site
  is resolved and checked first (plus `extraCheck`, which returns a problem text or nil); only
  then is anything written. Returns true when applied.
]]
function namespace.apply(setting, writes, extraCheck)
  local plan = {}
  for _, write in ipairs(writes) do
    local value = SITES[write.site].values[write.value]
    local wanted = math.tointeger(write.to)
    if wanted == nil or wanted < value.min or wanted > value.max then
      log(ERROR, string.format("%s%s not applied: %s must be a whole number from %d to %d, not %s",
        LOG_PREFIX, setting, write.label, value.min, value.max, tostring(write.to)))
      return false
    end
    write.to = wanted
    local address, problem = resolve(write.site)
    if address == nil then
      log(ERROR, string.format("%s%s not applied: %s: %s", LOG_PREFIX, setting, write.site, problem))
      return false
    end
    local at = address + value.value
    local current = readSigned(at, value.width)
    if current ~= value.default and current ~= write.to then
      log(ERROR, string.format("%s%s not applied: %s holds %d instead of the game's %d "
        .. "(changed by another module?)", LOG_PREFIX, setting, write.site, current, value.default))
      return false
    end
    plan[#plan + 1] = { at = at, width = value.width, to = write.to, label = write.label,
      default = value.default, current = current, keep = write.keep }
  end
  if extraCheck ~= nil then
    local problem = extraCheck()
    if problem ~= nil then
      log(ERROR, string.format("%s%s not applied: %s", LOG_PREFIX, setting, problem))
      return false
    end
  end
  for _, step in ipairs(plan) do
    if step.current ~= step.to then
      core.writeCodeBytes(step.at, encode(step.to, step.width))
    end
    if not step.keep then
      log(INFO, string.format("%s%s = %d (game default %d) at 0x%X", LOG_PREFIX, step.label, step.to,
        step.default, step.at))
    end
  end
  return true
end

local function default(site, value)
  return SITES[site].values[value].default
end

---------------------------------------------------------------------------------------------
-- The balance file sections. Keys that are left out keep the game's values.
---------------------------------------------------------------------------------------------

-- "building_placement": castle build range per map size and distances to enemy units.
function namespace.edit_building_placement(placement)
  local range = placement["castle_build_range"]
  if range ~= nil then
    local writes = {}
    for _, size in ipairs({ "map_160", "map_200", "map_300", "map_400" }) do
      if range[size] ~= nil then
        writes[#writes + 1] = { site = "castle_build_range", value = size, to = range[size],
          label = "building_placement.castle_build_range." .. size }
      end
    end
    if #writes > 0 then
      namespace.apply("building_placement.castle_build_range", writes)
    end
  end

  local radius = placement["enemy_unit_radius"]
  if radius ~= nil then
    for _, entry in ipairs({
      { "storage", "storage_enemy_radius" },
      { "siege_tents", "siege_tent_enemy_radius" },
      { "ai_walls", "ai_wall_enemy_radius" },
    }) do
      local key, site = entry[1], entry[2]
      if radius[key] ~= nil then
        local label = "building_placement.enemy_unit_radius." .. key
        namespace.apply(label, { { site = site, value = "radius", to = radius[key], label = label } },
          checkNearCalls)
      end
    end
  end
end

-- "stances": search ranges of the aggressive and defensive stance and what they go after.
function namespace.edit_stances(stances)
  local aggressive, defensive = stances["aggressive_range"], stances["defensive_range"]
  if aggressive ~= nil or defensive ~= nil then
    -- One group: the game tells the two stances apart by the defensive value, so the ranges must
    -- stay different and the defensive comparison must follow the defensive range.
    local newAggressive = aggressive or default("stance_ranges", "aggressive")
    local newDefensive = defensive or default("stance_ranges", "defensive")
    namespace.apply("stances.aggressive_range/defensive_range", {
      { site = "stance_ranges", value = "aggressive", to = newAggressive,
        label = "stances.aggressive_range", keep = aggressive == nil },
      { site = "stance_ranges", value = "defensive", to = newDefensive,
        label = "stances.defensive_range", keep = defensive == nil },
      { site = "defensive_stance_check", value = "defensive", to = newDefensive,
        label = "stances.defensive_range (stance check)", keep = defensive == nil },
    }, function()
      if math.tointeger(newAggressive) == math.tointeger(newDefensive) then
        return "aggressive_range and defensive_range must differ "
          .. "(the game tells the two stances apart by the defensive range)"
      end
      return nil
    end)
  end

  if stances["max_units_per_enemy"] ~= nil then
    namespace.apply("stances.max_units_per_enemy", { { site = "stance_units_per_enemy", value = "count",
      to = stances["max_units_per_enemy"], label = "stances.max_units_per_enemy" } })
  end

  if stances["aggressive_melee_building_range"] ~= nil then
    namespace.apply("stances.aggressive_melee_building_range", { { site = "aggressive_melee_building_range",
      value = "range", to = stances["aggressive_melee_building_range"],
      label = "stances.aggressive_melee_building_range" } })
  end
end

namespace.defaults = default

-- For tests: the site table and a way to forget resolved addresses.
namespace._sites = SITES
namespace._reset = function()
  resolved = {}
  codeFirst, codeEnd, codeProblem = nil, nil, nil
end

return namespace
