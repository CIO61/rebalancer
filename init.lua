local constants = require("constants")
local addresses = require("addresses")

local building_names = constants.building_names
local unit_names = constants.unit_names
local military_ground_unit_names = constants.military_ground_unit_names
local resource_names = constants.resource_names
local pop_thresholds = constants.pop_thresholds
local namespace = {}

local function locate_aob(str)
  return core.AOBScan(str, 0x400000, 0x7FFFFF)
end

local scenario_pgr_base = locate_aob("EC FF FF FF F1 FF FF FF F4 FF FF FF F6 FF FF FF F7 FF FF FF F8 FF FF FF F9 FF FF FF FA FF FF FF FB FF FF FF FB FF FF FF 05 00 00 00 05 00 00 00")
local scenario_pgr_crowded_base = locate_aob("EC FF FF FF F1 FF FF FF F4 FF FF FF F6 FF FF FF F7 FF FF FF F8 FF FF FF F9 FF FF FF FA FF FF FF FB FF FF FF FB FF FF FF 05 00 00 00 05 00 00 00")
local skirmish_pgr_base = locate_aob("F8 FF FF FF FA FF FF FF FB FF FF FF FC FF FF FF FD FF FF FF FD FF FF FF FE FF FF FF FE FF FF FF FF FF FF FF FF FF FF FF 0A 00 00 00 0C 00 00 00")

local unit_array_base_addr = addresses.unit_array_base_addr
local building_array_base_addr = addresses.building_array_base_addr
local unit_melee_toggles_base = addresses.unit_melee_toggles_base
local unit_jester_unfriendly_base = addresses.unit_jester_unfriendly_base
local unit_blessable_base = addresses.unit_blessable_base
local towers_or_gates_base = addresses.towers_or_gates_base
local unit_gold_jumplist_addr = addresses.unit_gold_jumplist_addr
local tax_popularity_offset = addresses.tax_popularity_offset

local archer_idx = table.find(unit_names, "European archer")
local arabbow_idx = table.find(unit_names, "Arabian archer")

local ballista_damage_table_addr = 0 -- defined when allocated.
local mangonel_damage_table_addr = 0 -- defined when allocated.
local catapult_damage_table_addr = 0 -- defined when allocated.
local trebuchet_damage_table_addr = 0 -- defined when allocated.

local non_rax_unit_cost_func_addr = locate_aob("8B 44 24 04 83 F8 1E 55")
local non_rax_unit_display_cost_func_addr = locate_aob("33 DB 83 F8 03 77 1A FF 24 85 ? ? ? ?")

local ballista_damage_addr = locate_aob("66 83 F9 37 75 07 B9 32 00 00 00 EB 70 66 83 F9") -- 125 bytes (+14)
local mangonel_damage_addr = locate_aob("66 83 F9 37 75 0A B9 32 00 00 00 E9 51 01 00 00") -- 154 bytes

local unit_health_base = locate_aob("C4 09 00 00 C4 09 00 00 10 27 00 00 C4 09 00 00 10 27 00 00 88 13 00 00 10 27 00")
local unit_arrow_dmg_base = locate_aob("98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 88 13 00 00 98 3A 00 00 98 3A 00 00 98 3A")
local unit_xbow_dmg_base = locate_aob("98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 88 13 00 00 98 3A 00 00 B8 0B 00 00")
local unit_stone_dmg_base = locate_aob("88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00")
local unit_speed_base = locate_aob("01 00 00 00 01 00 00 00 02 00 00 00 03 00 00 00 01 00 00 00 01 00 00 00 02 00 00 00 02 00 00 00 03 00 00 00 01 00 00 00")

local tunneller_building_melee_addr = locate_aob("F7 D9 1B C9 83 E1 F0 83 C1 14 0F BF A8")
local archer_building_melee_addr =     locate_aob("F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98")  -- +6 +9
local crossbow_building_melee_addr = locate_aob("33 FF 8D 44 00 02 8B D0 8B 44 24 10")
local spearman_building_melee_addr =   locate_aob("F7 D9 1B C9 83 E1 FB 83 C1 08 0F BF 90")  -- +6 +9
local maceman_building_melee_addr =    locate_aob("F7 D9 1B C9 83 E1 E1 83 C1 23 0F BF 98")  -- +6 +9
local pikeman_building_melee_addr =  core.AOBScan("F7 D9 1B C9 83 E1 F0 83 C1 14 0F BF A8", tunneller_building_melee_addr+10, 0x7FFFFF)  -- +6 +9
local swordsman_building_melee_addr =  locate_aob("F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF 98")  -- +6 +9
local knight_building_melee_addr =   core.AOBScan("F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF 98", swordsman_building_melee_addr+10, 0x7FFFFF)  -- +6 +9
local lord_building_melee_addr =          locate_aob("F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF A8")
local arabbow_building_melee_addr =     core.AOBScan("F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", archer_building_melee_addr+10, 0x7FFFFF)  -- +6 +9
local slave_building_melee_addr =         locate_aob("0F BF 90 ? ? ? ? 8B 80 ? ? ? ? 6A 08")  -- +14
local slinger_building_melee_addr =     core.AOBScan("F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", arabbow_building_melee_addr+10, 0x7FFFFF)  -- +6 +9
local assassin_building_melee_addr =    core.AOBScan("F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF A8", lord_building_melee_addr+10, 0x7FFFFF)  -- +6 +9
local firethrower_building_melee_addr = core.AOBScan("F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", slinger_building_melee_addr+10, 0x7FFFFF)  -- +6 +9
local horsearcher_building_melee_addr = core.AOBScan("F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", firethrower_building_melee_addr+10, 0x7FFFFF)  -- +6 +9
local arabsword_building_melee_addr =   core.AOBScan("F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF A8", assassin_building_melee_addr+10, 0x7FFFFF)  -- +6 +9
local monk_building_melee_addr =          locate_aob("F7 D9 1B C9 83 E1 EF 83 C1 14 0F BF A8 ? ? ? ? 6A 01")  -- +6 +9
local ram_damage_addr = locate_aob("55 6A 32 52 8B 90 ? ? ? ? 51 52")  -- +3  

local unit_power_levels_addr = locate_aob("05 00 00 00 0A 00 00 00 04 00 00 00 0A 00 00 00 0A 00 00 00")
local eu_unit_gold_cost_base = locate_aob("0C 00 00 00 14 00 00 00 08 00 00 00 14 00 00 00")
local ar_unit_gold_cost_base = locate_aob("4B 00 00 00 05 00 00 00 0C 00 00 00 3C 00 00 00")
-- 16 bytes from last of one unit to start of next unit
local unit_melee_dmg_base = locate_aob("02 00 00 00 02 00 00 00 02 00 00 00 02 00 00 00 02 00 00 00 02 00 00 00 02 00 00 00 14 00 00 00") - 0x260

-- building related addresses
local building_cost_base = locate_aob("06 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 06 00 00 00 00 00 00 00")
local building_health_base = locate_aob("64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00")
local building_population_base = locate_aob("08 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")

-- siege related addresses
local cat_collateral_addr = locate_aob("8B 1C 95 ? ? ? ? 8B CB BF 0A 00 00 00 81 E1 01 00 10 40 8B EF")+10
local siege_projectile_func_addr = locate_aob("66 83 F9 03 75 0A BF 3C 00 00 00 8D 6F E2")
local oneshot_threshold_addr = locate_aob("81 F9 20 4E 00 00 0F 8E F9 FD FF FF")
local cat_primary_addr = siege_projectile_func_addr+23 -- integer
local treb_collateral_penalty_addr = siege_projectile_func_addr+13  -- byte
local treb_primary_addr = siege_projectile_func_addr+7 -- integer
local mango_primary_addr = siege_projectile_func_addr+36  -- integer

-- resource related addresses
local resource_buy_base = locate_aob("14 00 00 00 4B 00 00 00 46 00 00 00 00 00 00 00 E1 00 00 00 64 00 00 00 64 00 00 00 73 00 00 00 28 00 00 00 28 00 00 00 28 00 00 00 28 00 00 00")
local resource_sell_base = locate_aob("05 00 00 00 28 00 00 00 23 00 00 00 00 00 00 00 73 00 00 00 32 00 00 00 32 00 00 00 28 00 00 00 14 00 00 00 14 00 00 00 14 00 00 00 14 00 00 00")

local woodcutter_func = locate_aob("6A 01 66 89 BE ? ? ? ? 6A 0C 89 96 ? ? ? ? 50")
local quarry_grunt_func = locate_aob("6A 01 6A 08 55 C7 81 ? ? ? ? 00 00 00 00 E8")
local ironminer_func = locate_aob("6A 01 8D 80 ? ? ? ? 6A 01 51 E8")
local pitchman_func = locate_aob("6A 01 66 89 AE ? ? ? ? 6A 01 89 8E")
local hunter_func = locate_aob("6A 01 66 89 BE ? ? ? ? 6A 06 89 8E ? ? ? ?")
local apple_farmer_func = locate_aob("6A 01 6A 03 50 66 C7 86 ? ? ? ? 07 00 E8")
local dairy_farmer_func = locate_aob("6A 01 66 89 BE ? ? ? ? 6A 03 89 96 ? ? ? ? 50 66 C7 86 ? ? ? ? 05 00")
local hops_farmer_func = locate_aob("6A 01 74 04 6A 02 EB 02 6A 01 50 E8")  -- hops farm yields 1 per delivery on scenario/castle builder mode, 2 on skirmish

local baker_func = locate_aob("53 C6 86 ? ? ? ? FE 6A 08 66 C7 86 ? ? ? ? 05 00")  -- skirmish bonus is push ebx instead of push val
local wheatfarmer_func = locate_aob("53 66 89 BE ? ? ? ? 6A 02") -- skirmish bonus is push ebx instead of push val
local brewer_func = locate_aob("55 C6 86 ? ? ? ? FE 55 66 C7 86 ? ? ? ? 07 00") -- both produce amount and skirmish bonus is push ebp instead of push val

local fletcher_func = locate_aob("55 55 66 89 9E ? ? ? ? 50 66 C7 86 ? ? ? ? 06 00 E8")
local poleturner_func = core.AOBScan("55 C6 86 ? ? ? ? FE 55 66 C7 86 ? ? ? ? 07 00", brewer_func+16, 0x7FFFFFF)  -- exact same AOB as brewer func, must uniqueify! (works bc brewer is changed before this scan)
local blacksmith_func = locate_aob("55 55 66 89 9E ? ? ? ? 50 66 C7 86 ? ? ? ? 07 00 E8")  -- blacksmith has another call to calculategoodsproduced but its a mystery
local custom_fletcher_code_addr = 0  -- defined when inserted as code
local custom_poleturner_code_addr = 0  -- defined when inserted as code
local custom_blacksmith_code_addr = 0  -- defined when inserted as code
local tanner_func = locate_aob("53 53 50 66 89 AE ? ? ? ? E8 53 6C FD FF 66 89 86")
local armourer_func = core.AOBScan("55 C6 86 ? ? ? ? FE 55 66 C7 86 ? ? ? ? 07 00 57 66 89 9E ? ? ? ? E8", poleturner_func+16, 0x7FFFFFF)

-- religion related addresses
local religion_addr_1 = locate_aob("83 F8 18 7F 04 33 C9 EB 2C 83 F8 31 7F 07 B9 32 00 00 00 EB 20 83 F8 4A 7F 07 B9 64 00 00 00 EB 14 33 C9 83 F8 5E 0F 9F C1 83 E9 01 83 E1 CE 81 C1 C8 00 00 00 83 BE")
local religion_addr_2 = locate_aob("83 F8 18 7F 04 33 C0 EB 2E 83 F8 31 7F 07 B8 32 00 00 00 EB 22 83 F8 4A 7F 07 B8 64 00 00 00 EB 16 33 D2 83 F8 5E 0F 9F C2 83 EA 01 83 E2 CE 81 C2 C8 00 00 00 8B C2")
local religion_addr_3 = locate_aob("83 F8 18 7F 04 33 F6 EB 2E 83 F8 31 7F 07 BE 32 00 00 00 EB 22 83 F8 4A 7F 07 BE 64 00 00 00 EB 16 33 D2 83 F8 5E 0F 9F C2 83 EA 01 83 E2 CE 81 C2 C8 00 00 00 8B F2 83 B9")

-- beer related addresses
local beer_addr_1 = locate_aob("83 FE 19 7D 04 33 C0 EB 2B 83 FE 32 7D 07 B8 32 00 00 00 EB 1F 83 FE 4B 7D 07 B8 64 00 00 00 EB 13 33 C0 83 FE 64 0F 9D C0 83 E8 01 83 E0 CE 05 C8 00 00 00 8B")
local beer_addr_2 = locate_aob("83 F8 19 7D 04 33 F6 EB 2E 83 F8 32 7D 07 BE 32 00 00 00 EB 22 83 F8 4B 7D 07 BE 64 00 00 00 EB 16 33 C9 83 F8 64 0F 9D C1 83 E9 01 83 E1 CE 81 C1 C8 00 00 00 8B F1")
local beer_addr_3 = locate_aob("83 F8 19 89 84 3E ? ? ? ? 7D 04 33 C0 EB 2E 83 F8 32 7D 07 B8 32 00 00 00 EB 22 83 F8 4B 7D 07 B8 64 00 00 00 EB 16 33 D2 83 F8 64 0F 9D C2 83 EA 01 83 E2 CE 81 C2 C8 00 00 00 8B C2")
local beer_coverage_addr = locate_aob("7F 05 33 C0 C2 04 00 8B 89 ? ? ? ? 85 C9 7E F1 69 C0 B8 0B 00 00 99")

-- food related addresses
local food_addr_1 = locate_aob("BE 38 FF FF FF EB 49 8B 0D ? ? ? ? 69 C9 ? ? ? ? 8B 81 ? ? ? ? 83 F8 04 75 07 BE C8 00 00 00 EB 2B 83 F8 03 75 05 8D 70 61 EB 21 83 F8 02 75 04 33 F6 EB 18 3B C3 75 07 BE 9C FF FF FF EB 0D 85 C0 BE 38 FF FF FF 74 04")
local food_addr_2 = locate_aob("BE 38 FF FF FF EB 3C 8B 88 ? ? ? ? 83 F9 04 75 07 BE C8 00 00 00 EB 2A 83 F9 03 75 05 8D 71 61 EB 20 83 F9 02 75 04 33 F6 EB 17 83 F9 01 75 05 8D 71 9B EB 0D 85 C9 BE 38 FF FF FF 74 04")
local food_addr_3 = locate_aob("B9 38 FF FF FF EB 3F 8B 84 3E ? ? ? ? 85 C0 75 07 B9 38 FF FF FF EB 2D 83 F8 01 75 05 8D 48 9B EB 23 83 F8 02 75 04 33 C9 EB 1A 83 F8 04 75")

-- fear factor related addresses
local ff_addr_1 = locate_aob("8B 82 ? ? ? ? 83 F8 01 7C 05 6B C0 19 EB 0C 83 F8 FF 7F 05 6B C0 19")
local ff_addr_2 = locate_aob("8B 81 ? ? ? ? 83 F8 01 7C 07 6B C0 19 8B F0 EB 0E 83 F8 FF 7F 07 6B C0 19")
local ff_addr_3 = locate_aob("8B 84 3E ? ? ? ? 83 F8 01 7C 09 6B C0 19 89 44 24 1C EB 16 83 F8 FF 7F 09 6B C0 19")
local productivity_addr = locate_aob("C7 01 96 00 00 00 EB 7A 83 F8 FC 7F 08 C7 01 8C 00 00 00 EB 6D 83 F8 FD 7F 08 C7 01")
local ff_coverage_addr = locate_aob("C1 F9 04 83 C1 01 2B 46 F8")
local combat_bonus_memory_addr = locate_aob("83 C0 14 0F AF 44 24 04 8D 0C 80 B8 1F 85 EB 51 F7 E9")

-- tax related addresses
local tax_addr = locate_aob("8B 44 24 08 83 C0 FF 0F AF 44 24 0C 99 2B C2 D1 F8")
local bribe_addr = locate_aob("B8 05 00 00 00 2B 44 24 08 0F AF 44 24 0C 99")
local tax_table_addr = 0 -- defined when allocated
local neutral_level_addr_1 = locate_aob("83 F8 03 7D 12")
local neutral_level_addr_2 = locate_aob("03 00 00 00 C7 86")
local neutral_level_addr_3 = locate_aob("83 F8 03 7E 16 8B 54 24 0C 52 50 8B 44 24 0C 50")
local neutral_level_addr_4 = locate_aob("83 F8 03 7D 16 8B 54 24 0C 52 50")
local keep_menu_addr = locate_aob("83 F8 03 7D 07 83 7C 24 10 00 7E 2B 85 C0 75 0A B8 AF 00 00 00 E9 86 00 00 00 83 F8 01 75 07 B8 7D 00 00 00 EB 7A 83 F8 02 75 07 B8 4B 00 00 00")
local pop_report_addr = locate_aob("83 B8 ? ? ? ? 03 7D 11 83 7C 24 18 00 7F 0A BE 19 00 00 00 E9")
local actual_effect_addr = locate_aob("83 F8 03 7D 0E 85 ED 7F 0A B8 19 00 00 00 E9 86 00 00")
local multipliers_addr_base = locate_aob("69 C0 FA 00 00 00 8B C8 B8 1F 85 EB 51 F7 E9 C1 FA 05 8B C2 C1 E8 1F")

local function get_unit_melee_dmg_address(attacker, defender)
  local attacker_idx = table.find(unit_names, attacker) - 1
  local defender_idx = table.find(unit_names, defender) - 1
  return unit_melee_dmg_base + defender_idx * 4 + attacker_idx * 16 + attacker_idx * (#unit_names - 1) * 4
end

local function half_siege_ammo()
  local siege_initial_ammo_addr = locate_aob("74 0E 66 C7 86 76 09 00 00 14 00") + 9
  core.writeCodeSmallInteger(siege_initial_ammo_addr, 10) -- "Catapult/Trebuchet initial stone.",     
  local reload_amount_addr = locate_aob("66 83 80 ? ? ? ? 14 8D 80 ? ? ? ? C3")
  core.writeCodeByte(reload_amount_addr+7, 10) -- "Catapult stone reload amount.",             
  local multi_reload_func_addr = locate_aob("0F BF 8E ? ? ? ? BF 14 00 00 00 2B F9 85 FF")
  core.writeCodeByte(multi_reload_func_addr+8, 10) -- "Default max. ammunition amount.",             
  core.writeCodeByte(multi_reload_func_addr+20, 0) -- "Rounding extra stone cost.",       
  core.writeCodeBytes(multi_reload_func_addr+32, {0x90, 0x90})  -- "Shift left to divide instruction.",  nop-out
  core.writeCodeBytes(multi_reload_func_addr+121, {0x89, 0xC6, 0x90})
end

local function double_iron_pickup()
  local iron_wait_addr = locate_aob("33 C9 39 88 ? ? ? ? 0F 94 C1 8D 4C 09 03")
  core.writeCodeBytes(iron_wait_addr, core.compile({
    0x83, 0xB8, core.itob(building_array_base_addr + 0x138), 0x01,
    0x0F, 0x9E, 0xC1,
    0x90
  }, iron_wait_addr))
  local iron_subtract_addr = locate_aob("FF 6A ? 8D 80 ? ? ? ? 6A ? 51 E8")
  core.writeCodeByte(iron_subtract_addr, -2)
end

local function ascension_extras()
  core.writeCodeByte(0x400000 + 0x16FF92, 18) -- Unit power level required around a dog cage for it to trigger.   
  core.writeCodeByte(0x400000 + 0x149F67, 2) -- "Count path to positive fearfactor twice for resting.", 
  core.writeCodeByte(0x400000 + 0xB6FC0, 4) -- "Minimap unit size.", 

  core.writeCodeByte(0x400000 + 0x13D63C, 42) -- AI Fireballista building harass range.   
  core.writeCodeByte(0x400000 + 0x13D64E, 68) -- AI Cata and Trebuchet building harass range.   

  -- core.writeCodeByte(0x400000 + 0xE7F1A, 80) -- Assassin full uncloak range, part 1.
  -- core.writeCodeByte(0x400000 + 0xEA637, 80) -- Assassin full uncloak range, part 2.

  -- core.writeCodeInteger(0x400000 + 0xE847C, 120) -- Assassin partial uncloak range, part 1.
  -- core.writeCodeInteger(0x400000 + 0xEA5FF, 120) -- Assassin partial uncloak range, part 2.
  -- core.writeCodeInteger(0x400000 + 0xB6E88, 120) -- Assassin partial uncloak range, part 3.

  core.writeCodeSmallInteger(0x400000 + 0x132408, 37008) -- Highground damage reduction for all units to 50%. {0x90, 0x90}

  core.writeCodeInteger(0x400000 + 0x17A08A, 20) -- Custom unit to closest enemy distance update rate cap (Set in gameticks, picked at random from 0 to this number, applies to all units
  core.writeCodeByte(0x400000 + 0x17A089, 0xB8)  -- Custom unit to closest enemy distance update rate cap, code adjustment 1
  core.writeCodeByte(0x400000 + 0x17A08E, 0x90)  -- Custom unit to closest enemy distance update rate cap, code adjustment 2

  core.writeCodeSmallInteger(0x400000 + 0x141777, 120) -- Flagons per beer.   
  core.writeCodeSmallInteger(0x400000 + 0x1418A0, 400) -- Flagon threshold in an inn.   
  core.writeCodeInteger(0x400000 + 0x3B22C, 120) -- Flagons per beer, inn display value.
  core.writeCodeBytes(0x400000 + 0x3B227, {
    0x31, 0xD2, 0x8B, 0xC1, 0xB9
  })  -- Flagons per beer, inn display value, code adjustment 1.   
  core.writeCodeBytes(0x400000 + 0x3B230, {
    0xF7, 0xF1, 0x50, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90
  })  -- Flagons per beer, inn display value, code adjustment 2.  

  core.writeCodeSmallInteger(0x400000 + 0x1C14B, 3) -- Pitch ditch cost modifier. (2 per pitch instead of 4)

  core.writeCodeInteger(0x400000 + 0x1B635C, 40) -- "Archer base range.",
  core.writeCodeInteger(0x400000 + 0x1B6374, 40) -- "Crossbowman base range.",
  core.writeCodeInteger(0x400000 + 0x1B63EC, 40) -- "Fireballista base range.",

  core.writeCodeInteger(0x400000 + 0x3595E, 1600) -- "Archer, crossbowman and fireballista control range 1.",
  core.writeCodeInteger(0x400000 + 0x35E2D, 1600) -- "Archer and crossbowman control range 2.",
  core.writeCodeInteger(0x400000 + 0x35F3B, 1600) -- "Fireballista control range 2.",
  core.writeCodeInteger(0x400000 + 0x3633A, 1600) -- "Archer, crossbowman and fireballista control range 3.",
  core.writeCodeInteger(0x400000 + 0x369B3, 1600) -- "Archer, crossbowman and fireballista control range 4.",
  core.writeCodeInteger(0x400000 + 0x36ABA, 1600) -- "Archer, crossbowman and fireballista control range 5.",

  core.writeCodeInteger(0x400000 + 0x1B64FC, 125) -- "Archer projectile velocity.", 
  core.writeCodeInteger(0x400000 + 0x1B642C, 0) -- "Archer projectile arch type.",

  core.writeCodeInteger(0x400000 + 0x1B6514, 125) -- "Crossbowman projectile velocity.", 
  core.writeCodeInteger(0x400000 + 0x1B6444, 0) -- "Crossbowman projectile arch type.",

  core.writeCodeInteger(0x400000 + 0x1B658C, 125) -- "Fireballista projectile velocity.", 
  core.writeCodeInteger(0x400000 + 0x1B64BC, 0) -- "Fireballista projectile arch type.",

  local slinger_base_range = 18
  core.writeCodeInteger(0x400000 + 0x1B63DC, slinger_base_range) -- "Slinger base range.",           
  core.writeCodeInteger(0x400000 + 0x35968, slinger_base_range*slinger_base_range) -- "Slinger control range 1.",      
  core.writeCodeInteger(0x400000 + 0x35EAA, slinger_base_range*slinger_base_range) -- "Slinger control range 2.",      
  core.writeCodeInteger(0x400000 + 0x36344, slinger_base_range*slinger_base_range) -- "Slinger control range 3.",      
  core.writeCodeInteger(0x400000 + 0x369BA, slinger_base_range*slinger_base_range) -- "Slinger control range 4.",      
  core.writeCodeInteger(0x400000 + 0x36AC1, slinger_base_range*slinger_base_range) -- "Slinger control range 5.",      
  core.writeCodeInteger(0x400000 + 0x1B657C, 100) -- "Slinger projectile velocity.",  
  core.writeCodeInteger(0x400000 + 0x1B64AC, 0) -- "Slinger projectile arch type.", 

  local firethrower_base_range = 11
  core.writeCodeInteger(0x400000 + 0x1B63E0, firethrower_base_range) -- "Firethrower base range.",          
  core.writeCodeInteger(0x400000 + 0x35972, firethrower_base_range*firethrower_base_range) -- "Firethrower control range 1.",     
  core.writeCodeInteger(0x400000 + 0x35ED0, firethrower_base_range*firethrower_base_range) -- "Firethrower control range 2.",     
  core.writeCodeInteger(0x400000 + 0x3634E, firethrower_base_range*firethrower_base_range) -- "Firethrower control range 3.",     
  core.writeCodeInteger(0x400000 + 0x369C1, firethrower_base_range*firethrower_base_range) -- "Firethrower control range 4.",     
  core.writeCodeInteger(0x400000 + 0x36AC8, firethrower_base_range*firethrower_base_range) -- "Firethrower control range 5.",     
  core.writeCodeInteger(0x400000 + 0x1B6580, 80) -- "Firethrower projectile velocity.", 
  core.writeCodeInteger(0x400000 + 0x1B64B0, 0) -- "Firethrower projectile arch type.",

  local catapult_base_range = 57
  core.writeCodeInteger(0x400000 + 0x1B6360, catapult_base_range) -- "Catapult base range.",           
  core.writeCodeInteger(0x400000 + 0x3597C, catapult_base_range*catapult_base_range) -- "Catapult control range 1.",      
  core.writeCodeInteger(0x400000 + 0x35EE9, catapult_base_range*catapult_base_range) -- "Catapult control range 2.",      
  core.writeCodeInteger(0x400000 + 0x36358, catapult_base_range*catapult_base_range) -- "Catapult control range 3.",      
  core.writeCodeInteger(0x400000 + 0x36728, catapult_base_range*catapult_base_range) -- "Catapult control range 4.",      
  core.writeCodeInteger(0x400000 + 0x368AA, catapult_base_range*catapult_base_range) -- "Catapult control range 5.",      
  core.writeCodeInteger(0x400000 + 0x369C8, catapult_base_range*catapult_base_range) -- "Catapult control range 6.",      
  core.writeCodeInteger(0x400000 + 0x36ACF, catapult_base_range*catapult_base_range) -- "Catapult control range 7.",      
  core.writeCodeInteger(0x400000 + 0x1B6500, 10) -- "Catapult projectile velocity.",  
  core.writeCodeInteger(0x400000 + 0x1B6430, 2) -- "Catapult projectile arch type.", 

  core.writeCodeInteger(0x400000 + 0x1B6364, 68) -- "Trebuchet base range.",                         
  core.writeCodeInteger(0x400000 + 0x1B63A8, 68) -- "Tower ballista base range.",                    
  core.writeCodeInteger(0x400000 + 0x35986, 4624) -- "Trebuchet and tower ballista control range 1.", 
  core.writeCodeInteger(0x400000 + 0x35EF3, 4624) -- "Trebuchet control range 2.",                    
  core.writeCodeInteger(0x400000 + 0x35F14, 4624) -- "Tower ballista control range 2.",               
  core.writeCodeInteger(0x400000 + 0x36362, 4624) -- "Trebuchet and tower ballista control range 3.", 
  core.writeCodeInteger(0x400000 + 0x3672F, 4624) -- "Trebuchet control range 4.",                    
  core.writeCodeInteger(0x400000 + 0x368B1, 4624) -- "Trebuchet control range 5.",                    
  core.writeCodeInteger(0x400000 + 0x369CF, 4624) -- "Trebuchet and tower ballista control range 6.", 
  core.writeCodeInteger(0x400000 + 0x36AD6, 4624) -- "Trebuchet and tower ballista control range 7.", 
  core.writeCodeInteger(0x400000 + 0x1B6504, 30) -- "Trebuchet projectile velocity.",                
  core.writeCodeInteger(0x400000 + 0x1B6434, 1) -- "Trebuchet projectile arch type.",               
  core.writeCodeInteger(0x400000 + 0x1B6548, 170) -- "Tower ballista projectile velocity.",           
  core.writeCodeInteger(0x400000 + 0x1B6478, 0) -- "Tower ballista projectile arch type.",          

  local mango_base_range = 54
  core.writeCodeInteger(0x400000 + 0x1B6368, mango_base_range) -- "Mangonel base range.",
  core.writeCodeInteger(0x400000 + 0x3598D, mango_base_range*mango_base_range) -- "Mangonel control range 1.",
  core.writeCodeInteger(0x400000 + 0x35EFD, mango_base_range*mango_base_range) -- "Mangonel control range 2.",
  core.writeCodeInteger(0x400000 + 0x3636C, mango_base_range*mango_base_range) -- "Mangonel control range 3.",
  core.writeCodeInteger(0x400000 + 0x36736, mango_base_range*mango_base_range) -- "Mangonel control range 4.",
  core.writeCodeInteger(0x400000 + 0x368B8, mango_base_range*mango_base_range) -- "Mangonel control range 5.",
  core.writeCodeInteger(0x400000 + 0x369D6, mango_base_range*mango_base_range) -- "Mangonel control range 6.",
  core.writeCodeInteger(0x400000 + 0x36ADD, mango_base_range*mango_base_range) -- "Mangonel control range 7.",
  core.writeCodeInteger(0x400000 + 0x1B6508, 15) -- "Mangonel projectile velocity.",
  core.writeCodeInteger(0x400000 + 0x1B6438, 1) -- "Mangonel projectile arch type.",

  core.writeCodeInteger(0x400000 + 0x1B63B4, 60) -- "Projectile Range - cow", 
  core.writeCodeInteger(0x400000 + 0x3597C, 3600) -- "Manual Control Range - Catapult, Cow Throw", 
  core.writeCodeInteger(0x400000 + 0x36358, 3600) -- "Manual Control Range 2 - Catapult, Cow Throw", 

  core.writeCodeBytes(0x400000 + 0x170A97, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90})  -- no rally running for Arabian Archers
  core.writeCodeBytes(0x400000 + 0x1734A2, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90})  -- no rally running for Slingers
  core.writeCodeBytes(0x400000 + 0x174A49, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90})  -- no rally running for Assassins
  core.writeCodeBytes(0x400000 + 0x177012, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90})  -- no rally running for Fire Throwers
end

local function ai_ascension_extras()
  core.writeCodeByte(0x400000 + 0x1328DD, 184) -- Fire damage, code adjustment 1.   
  core.writeCodeByte(0x400000 + 0x1328E2, 144) -- Fire damage, code adjustment 2.   
  core.writeCodeInteger(0x400000 + 0x1328DE, 75) -- Fire damage. 
  ascension_extras()
end

local function enable_rebalance_features()
  ballista_damage_table_addr = core.allocate(#unit_names*4)
  mangonel_damage_table_addr = core.allocate(#unit_names*4)
  catapult_damage_table_addr = core.allocate(#unit_names*4)
  trebuchet_damage_table_addr = core.allocate(#unit_names*4)

  for index, name in ipairs(unit_names) do
    if name == "Lord" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 50)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 50)
    elseif name == "Catapult" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 2500)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 5000)
    elseif name == "Trebuchet" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 4000)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 5000)
    elseif name == "Mangonel" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 2000)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 500)
    elseif name == "Siege tower" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 20000)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 10000)
    elseif name == "Battering ram" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 20000)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 10000)
    elseif name == "Portable shield" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 500)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 1500)
    elseif name == "Tower ballista" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 2000)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 1000)
    elseif name == "Fire ballista" then
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 2000)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 1000)
    else
      core.writeInteger(ballista_damage_table_addr + 4*(index-1), 10000)
      core.writeInteger(mangonel_damage_table_addr + 4*(index-1), 30000)
    end
  end

  for index, name in ipairs(unit_names) do
    if name == "Lord" then
      core.writeInteger(catapult_damage_table_addr + 4*(index-1), 50)
      core.writeInteger(trebuchet_damage_table_addr + 4*(index-1), 50)
    else
      core.writeInteger(catapult_damage_table_addr + 4*(index-1), 30000)
      core.writeInteger(trebuchet_damage_table_addr + 4*(index-1), 30000)
    end
  end

  core.writeCodeBytes(crossbow_building_melee_addr-12, core.compile({  -- enables fully changing melee damage of xbows to buildings
    0x8B, 0x04, 0x95, core.itob(towers_or_gates_base), -- mov eax,[edx*4+005B9980]
    0x3C, 0x01,                                        -- cmp al,01
    0x75, 0x04,                                        -- jne 0055CE06
    0x31, 0xC0,                                        -- xor eax,eax
    0x2C, 0x02,                                        -- sub al,02
    0x04, 0x04,                                        -- add al,04
    0x90                                               -- nop 
  }, crossbow_building_melee_addr-12)
  )

  core.writeCodeByte(baker_func, 0x90)  -- nop out original push ebx
  core.insertCode(baker_func, 8, {}, baker_func+6, "after")
  core.writeCodeBytes(baker_func+6, {0x6A, 0x00})

  core.writeCodeByte(wheatfarmer_func, 0x90)  -- nop out original push ebx
  core.insertCode(wheatfarmer_func, 8, {}, wheatfarmer_func+6, "after")
  core.writeCodeBytes(wheatfarmer_func+6, {0x6A, 0x00})

  core.writeCodeByte(brewer_func, 0x90)  -- nop out original push ebp
  core.writeCodeByte(brewer_func+8, 0x90)  -- nop out original push ebp
  core.insertCode(brewer_func, 9, {}, brewer_func+5, "after")
  core.writeCodeBytes(brewer_func+5, {0x6A, 0x01, 0x6A, 0x01})

  local custom_fletcher_code = {
    0x50,                                       -- push eax
    0x69, 0xC0, 0x90, 0x04, 0x00, 0x00,         -- imul eax,eax,00000490
    0x0F, 0xBF, 0x80, core.itob(unit_array_base_addr+0x338),   -- movsx eax,word ptr [eax+0145D374]
    0x69, 0xC0, 0x2C, 0x03, 0x00, 0x00,         -- imul eax,eax,0000032C
    0x0F, 0xBF, 0x80, core.itob(building_array_base_addr+0x28E),   -- movsx eax,word ptr [eax+00F98C42]
    0x83, 0xF8, 0x11,                           -- cmp eax, 11
    0x58,                                       -- pop eax
    0x75, 0x06,                                 -- jne 6bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
    0xEB, 0x04,                                 -- jmp 4bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
  }

  core.writeCodeBytes(fletcher_func, {0x90, 0x90})
  custom_fletcher_code_addr = core.insertCode(fletcher_func, 9, custom_fletcher_code, fletcher_func+9, "after")

  local custom_poleturner_code = {
    0x50,                                       -- push eax
    0x8B, 0xC7,                                 -- mov eax, edi
    0x69, 0xC0, 0x90, 0x04, 0x00, 0x00,         -- imul eax,eax,00000490
    0x0F, 0xBF, 0x80, core.itob(unit_array_base_addr+0x338),   -- movsx eax,word ptr [eax+0145D374]
    0x69, 0xC0, 0x2C, 0x03, 0x00, 0x00,         -- imul eax,eax,0000032C
    0x0F, 0xBF, 0x80, core.itob(building_array_base_addr+0x28E),   -- movsx eax,word ptr [eax+00F98C42]
    0x83, 0xF8, 0x13,                           -- cmp eax, 13
    0x58,                                       -- pop eax
    0x75, 0x06,                                 -- jne 6bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
    0xEB, 0x04,                                 -- jmp 4bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
  }
  core.writeCodeByte(poleturner_func, 0x90)
  core.writeCodeByte(poleturner_func+8, 0x90)
  custom_poleturner_code_addr = core.insertCode(poleturner_func, 9, custom_poleturner_code, poleturner_func+9, "after")

  local custom_blacksmith_code = {
    0x50,                                       -- push eax
    0x69, 0xC0, 0x90, 0x04, 0x00, 0x00,         -- imul eax,eax,00000490
    0x0F, 0xBF, 0x80, core.itob(unit_array_base_addr+0x338),   -- movsx eax,word ptr [eax+0145D374]
    0x69, 0xC0, 0x2C, 0x03, 0x00, 0x00,         -- imul eax,eax,0000032C
    0x0F, 0xBF, 0x80, core.itob(building_array_base_addr+0x28E),   -- movsx eax,word ptr [eax+00F98C42]
    0x83, 0xF8, 0x11,                           -- cmp eax, 15
    0x58,                                       -- pop eax
    0x75, 0x06,                                 -- jne 6bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
    0xEB, 0x04,                                 -- jmp 4bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
  }

  core.writeCodeBytes(blacksmith_func, {0x90, 0x90})
  custom_blacksmith_code_addr = core.insertCode(blacksmith_func, 9, custom_blacksmith_code, blacksmith_func+9, "after")

  core.writeCodeBytes(tanner_func, {0x90, 0x90, 0x90})
  core.insertCode(tanner_func, 10, {}, tanner_func+5, "after")
  core.writeCodeBytes(tanner_func+5, {0x6A, 0x01, 0x6A, 0x01, 0x50})

  -- exact same AOB start as brewer AND poleturner!

  core.writeCodeByte(armourer_func, 0x90)
  core.writeCodeByte(armourer_func+8, 0x90)
  core.insertCode(armourer_func, 9, {}, armourer_func+5, "after")
  core.writeCodeBytes(armourer_func+5, {0x6A, 0x01, 0x6A, 0x01})

  tax_table_addr = core.allocate(12*2)
  local custom_tax_instructions = {
    0x8A, 0x44, 0x24, 0x0C,                          -- mov eax [esp+0C]
    0x66, 0x8B, 0x04, 0x45, core.itob(tax_table_addr),  -- mov ax,[eax*2+Stronghold_Crusader_Extreme.exe+45AD]
    0x0F, 0xAF, 0x44, 0x24, 0x10,                    -- imul eax,[esp+10]
    0xC3                                             -- return
  }

  local divby10_code = {
    0x52,
    0x51,
    0x8B, 0xC8,
    0xBA, 0x67, 0x66, 0x66, 0x66,
    0xF7, 0xEA,
    0xD1, 0xFA,
    0x8B, 0xC1,
    0xC1, 0xF8, 0x1F,
    0x29, 0xC2,
    0x8B, 0xC2,
    0x59,
    0x5A,
    0xC3,
  }

  local custom_tax_addr = core.allocateCode(18)
  local divby10_addr = core.allocateCode(25)
  core.writeCodeBytes(divby10_addr, divby10_code)
  local tax_jumpout_instructions = {
    0xE8, core.itob(custom_tax_addr - tax_addr-5),  -- call 40459B
    0xE8, core.itob(divby10_addr - tax_addr-10),  -- call 4045F9
    0xEB, 0x02,  -- jump over 2 bytes
    0x90, 0x90,
    0xC1, 0xF8, 0x03,  -- sar eax,03
    0x83, 0x3D, 0xF0, 0x4D, 0x35, 0x02, 0x00 -- cmp dword ptr [Stronghold_Crusader_Extreme.exe+1F54DF0],00
  }

  local bribe_jumpout_instructions = {
    0xE8, core.itob(custom_tax_addr - bribe_addr-5),  -- call 40459B
    0xE8, core.itob(divby10_addr - bribe_addr-10),  -- call 4045F9
    0x90,
    0xC1, 0xF8, 0x02  -- sar eax,02
  }

  core.writeCodeBytes(tax_addr, core.compile(tax_jumpout_instructions, tax_addr))
  core.writeCodeBytes(bribe_addr, core.compile(bribe_jumpout_instructions, bribe_addr))
  core.writeCodeBytes(custom_tax_addr, core.compile(custom_tax_instructions, custom_tax_addr))
  local default_tax_table = {"1.00", "0.8", "0.6", "0.0", "0.6", "0.8", "1.0", "1.2", "1.4", "1.6", "1.8", "2.0"}
  for idx, tax_val in ipairs(default_tax_table) do
    core.writeCodeSmallInteger(tax_table_addr+2*(idx-1), math.floor(tax_val*100))
  end

  core.writeCodeBytes(ballista_damage_addr-14,
    core.compile({
      0x75, 0x13,                                                     -- jne 005322D2
      0x0F, 0xB7, 0x8C, 0x3E, core.itob(0x6A2),                       -- movzx ecx,word ptr [esi+edi+000006A2]
      0x49,                                                           -- dec ecx
      0x8B, 0x0C, 0x8D, core.itob(ballista_damage_table_addr), 0x90,  -- mov ecx,[ecx*4+053FF2C0]  -- clear the nops later.
      0xEB, 0x76,                                                     -- jmp 00532348
      0x66, 0x83, 0xFB, 0x02,                                         -- cmp bx,02
      0x75, 0x13,                                                     -- jne 005322EB
      0x0F, 0xB7, 0x8C, 0x3E, core.itob(0x6A2),                       -- movzx ecx,word ptr [esi+edi+000006A2]
      0x49,                                                           -- dec ecx
      0x8B, 0x0C, 0x8D, core.itob(catapult_damage_table_addr), 0x90,  -- mov ecx,[ecx*4+053FF2C0]  -- clear the nops later.
      0xEB, 0x17,                                                     -- jmp 00532302
      0x66, 0x83, 0xFB, 0x03,                                         -- cmp bx,03
      0x75, 0x75,                                                     -- jne 00532366
      0x0F, 0xB7, 0x8C, 0x3E, core.itob(0x6A2),                       -- movzx ecx,word ptr [esi+edi+000006A2]
      0x49,                                                           -- dec ecx
      0x8B, 0x0C, 0x8D, core.itob(trebuchet_damage_table_addr), 0x90, -- mov ecx,[ecx*4+053FF2C0]  -- clear the nops later.
      0xEB, 0x7C,                                                     -- jmp 00532380
    }, ballista_damage_addr-14)
  )

  for i=57,124 do
    core.writeCodeByte(ballista_damage_addr+i, 0x90) -- nop out remaining bytes
  end

  core.writeCodeBytes(mangonel_damage_addr,
    core.compile({
      0x49, -- sub ecx
      0x8B, 0x0C, 0x8D, core.itob(mangonel_damage_table_addr), 0x90, -- mov ecx, [ecx*4+ballista_damage_table_addr]  -- clear the nops later.
      0xE9, core.itob(339)  -- jmp 339 bytes forward
    }, mangonel_damage_addr)
  )
  for i=14,153,5 do
    core.writeCodeBytes(mangonel_damage_addr+i, {0xBB, 0,0,0,0}) -- fill 140 bytes with trash
  end

  core.writeCodeBytes(non_rax_unit_display_cost_func_addr+14,{
    0xB3, 0x1E, -- mov bl, engineer_cost
    0xEB, 0x0F,
    0xB3, 0x04, -- mov bl, laddermen_cost
    0xEB, 0x0B,
    0xB3, 0x1E, -- mov bl, tunnellor_cost
    0xEB, 0x07,
    0xB3, 0x0A, -- mov bl, monk_cost
    0xEB, 0x03,
    0x90, 0x90, 0x90,
  })
  core.writeCodeBytes(unit_gold_jumplist_addr, core.compile({
      core.itob(non_rax_unit_display_cost_func_addr + 14),
      core.itob(non_rax_unit_display_cost_func_addr + 18),
      core.itob(non_rax_unit_display_cost_func_addr + 22),
      core.itob(non_rax_unit_display_cost_func_addr + 26),
    },unit_gold_jumplist_addr)
  )

  -- non_rax_unit_cost_func_addr
  core.writeCodeByte(non_rax_unit_cost_func_addr+6, 70)  -- compare unit id with arab bow

  core.writeCodeBytes(non_rax_unit_cost_func_addr+18, core.compile({
      0x7C, 0x10,
      0x50,
      0x83, 0xE8, 0x46,
      0xC1, 0xE0, 0x02,
      0x8B, 0xA8, core.itob(ar_unit_gold_cost_base),
      0x58,
      0xEB, 0x5A,
      0x83, 0xF8, 0x1E,
      0x75, 0x07,
      0xBD, 0x1E, 0x00, 0x00, 0x00,
      0xEB, 0x4E,
      0x83, 0xF8, 0x1D,
      0x75, 0x07,
      0xBD, 0x04, 0x00, 0x00, 0x00,
      0xEB, 0x42,
      0x83, 0xF8, 0x05,
      0x75, 0x07,
      0xBD, 0x1E, 0x00, 0x00, 0x00,
      0xEB, 0x36,
      0x83, 0xF8, 0x25,
      0x75, 0x07,
      0xBD, 0x0A, 0x00, 0x00, 0x00,
      0xEB, 0x2A
    }, non_rax_unit_cost_func_addr+18
  ))

end

namespace.enable = function(self, config)
  local file = io.open(config["balance_config_file_selector"], "rb")
  local spec = file:read("*all")
  local rebalance_cfg = yaml.parse(spec)
  enable_rebalance_features()
  namespace.apply_rebalance(rebalance_cfg)
end

namespace.apply_rebalance = function(config)
  local buildings = config["buildings"]
  local units = config["units"]
  local resources = config["resources"]
  local population_gathering_rate = config["population_gathering_rate"]
  local religion = config["religion"]
  local beer = config["beer"]
  local food = config["food"]
  local fear_factor = config["fear_factor"]
  local taxation = config["taxation"]
  local siege = config["siege"]
  local enable_ascension = config["enable_ascension"]
  local enable_ai_ascension = config["enable_ai_ascension"]
  local enable_iron_double_pickup = config["enable_iron_double_pickup"]
  local address = 0

  if buildings ~= nil then    
    for building, stats in pairs(buildings) do
      local cost = stats["cost"]
      local health = stats["health"]
      local housing = stats["housing"]
      local building_idx = table.find(building_names, building)-1
      if cost ~= nil then
        address = building_cost_base + 20 * building_idx
        core.writeInteger(address, cost[1])
        core.writeInteger(address+4, cost[2])
        core.writeInteger(address+8, cost[3])
        core.writeInteger(address+12, cost[4])
        core.writeInteger(address+16, cost[5])
      end

      if health ~= nil then
        address = building_health_base + 4 * building_idx
        core.writeInteger(address, health)
      end

      if housing ~= nil then
        address = building_population_base + 4 * building_idx
        core.writeInteger(address, housing)
      end
    end
  end

  -- siege changes need to come before units, due to projectile damages on units
  if siege ~= nil then
    local default_ballista_damage = 10000
    local default_mangonel_damage = 30000
    local default_catapult_damage = 30000
    local default_trebuchet_damage = 30000
    for key, val in pairs(siege) do
      if key == "catapultRockDamage" then
        core.writeCodeInteger(cat_primary_addr, val)
      elseif key == "catapultRockCollateralDamage" then
        core.writeCodeInteger(cat_collateral_addr, val)
      elseif key == "trebuchetRockDamage" then
        core.writeCodeInteger(treb_primary_addr, val)
      elseif key == "trebuchetRockCollateralPenalty" then
        core.writeCodeByte(treb_collateral_penalty_addr, val)
      elseif key == "mangonelPebbleDamage" then
        core.writeCodeInteger(mango_primary_addr, val)
      elseif key == "defaultMangonelPebbleUnitDamage" then
        default_mangonel_damage = val
      elseif key == "defaultCatapultRockUnitDamage" then
        default_catapult_damage = val
      elseif key == "defaultTrebuchetRockUnitDamage" then
        default_trebuchet_damage = val
      elseif key == "defaultBallistaBoltUnitDamage" then
        default_ballista_damage = val
      elseif key == "siegeProjectileOneShotThreshold" then
        core.writeCodeInteger(oneshot_threshold_addr+2, val)
      elseif key == "enable_half_siege_ammo" then
        if val ~= nil then
          half_siege_ammo()
        end
      end
    end

    for index, name in ipairs(unit_names) do
      if name == "Lord" then  -- defaults are set once
      elseif name == "Catapult" then  -- defaults are set once
      elseif name == "Trebuchet" then  -- defaults are set once
      elseif name == "Mangonel" then  -- defaults are set once
      elseif name == "Siege tower" then  -- defaults are set once
      elseif name == "Battering ram" then  -- defaults are set once
      elseif name == "Portable shield" then  -- defaults are set once
      elseif name == "Tower ballista" then  -- defaults are set once
      elseif name == "Fire ballista" then  -- defaults are set once
      else
        core.writeInteger(ballista_damage_table_addr + 4*(index-1), default_ballista_damage)
        core.writeInteger(mangonel_damage_table_addr + 4*(index-1), default_mangonel_damage)
      end
    end

    for index, name in ipairs(unit_names) do
      if name == "Lord" then  -- defaults are set once
      else
        core.writeInteger(catapult_damage_table_addr + 4*(index-1), default_catapult_damage)
        core.writeInteger(trebuchet_damage_table_addr + 4*(index-1), default_trebuchet_damage)
      end
    end

  end

  if units ~= nil then
    for unit, stats in pairs(units) do
      local health = stats["health"]
      local arrowDamage = stats["arrowDamage"]
      local xbowDamage = stats["xbowDamage"]
      local stoneDamage = stats["stoneDamage"]
      local ballistaBoltDamage = stats["ballistaBoltDamage"]
      local catapultRockDamage = stats["catapultRockDamage"]
      local trebuchetRockDamage = stats["trebuchetRockDamage"]
      local mangonelDamage = stats["mangonelDamage"]
      local baseMeleeDamage = stats["baseMeleeDamage"]
      local meleeDamageVs = stats["meleeDamageVs"]
      local buildingDamage = stats["buildingDamage"]
      local fortificationDamagePenalty = stats["fortificationDamagePenalty"]
      local wallDamage = stats["wallDamage"]
      local powerLevel = stats["powerLevel"]
      local meleeEngage = stats["meleeEngage"]
      local isBlessable = stats["isBlessable"]
      local jesterUnfriendly = stats["jesterUnfriendly"]

      local goldCost = stats["goldCost"]
      local speedLevel = stats["speedLevel"]
      local unit_military_idx = table.find(military_ground_unit_names, unit)
      local unit_idx_p1 = table.find(unit_names, unit)
      local unit_idx = unit_idx_p1-1

      if health ~= nil then core.writeInteger(unit_health_base + unit_idx * 4, health) end
      if arrowDamage ~= nil then core.writeInteger(unit_arrow_dmg_base + unit_idx * 4, arrowDamage) end
      if xbowDamage ~= nil then core.writeInteger(unit_xbow_dmg_base + unit_idx * 4, xbowDamage) end
      if stoneDamage ~= nil then core.writeInteger(unit_stone_dmg_base + unit_idx * 4, stoneDamage) end
      if meleeEngage ~= nil then core.writeInteger(unit_melee_toggles_base + 4*unit_idx, meleeEngage and 1 or 0) end
      if isBlessable ~= nil then core.writeInteger(unit_blessable_base + 4*unit_idx, isBlessable and 1 or 0) end
      if jesterUnfriendly ~= nil then core.writeInteger(unit_jester_unfriendly_base + 4*unit_idx, jesterUnfriendly and 1 or 0) end
      if ballistaBoltDamage ~= nil then core.writeInteger(ballista_damage_table_addr + 4*unit_idx, ballistaBoltDamage) end
      if mangonelDamage ~= nil then core.writeInteger(mangonel_damage_table_addr + 4*unit_idx, mangonelDamage) end
      if catapultRockDamage ~= nil then core.writeInteger(catapult_damage_table_addr + 4*unit_idx, catapultRockDamage) end
      if trebuchetRockDamage ~= nil then core.writeInteger(trebuchet_damage_table_addr + 4*unit_idx, trebuchetRockDamage) end
      if speedLevel ~= nil then core.writeInteger(unit_speed_base + unit_idx*4, speedLevel) end

      if baseMeleeDamage ~= nil then
        for _, defender in ipairs(unit_names) do
          address = get_unit_melee_dmg_address(unit, defender)
          core.writeInteger(address, baseMeleeDamage)
        end
      end

      if meleeDamageVs ~= nil then
        for defender, damage in pairs(meleeDamageVs) do
          address = get_unit_melee_dmg_address(unit, defender)
          core.writeInteger(address, damage)
        end
      end

      if powerLevel ~= nil then
        if unit_military_idx ~= nil then
          core.writeInteger(unit_power_levels_addr + 4*(unit_military_idx-1), powerLevel)
        end
      end

      if goldCost ~= nil then
        local is_arab_unit = unit_idx_p1 >= arabbow_idx and unit_idx_p1 <= table.find(unit_names, "Arabian firethrower")
        local is_other_trainable_unit = unit_idx_p1 == 5 or unit_idx_p1 == 29 or unit_idx_p1 == 30 or unit_idx_p1 == 37
        -- other trainable units are tunneller, laddermen, engineer or monk
        if unit_idx_p1 >= archer_idx and unit_idx_p1 <= table.find(unit_names, "European knight") then
          local eu_unit_idx = unit_idx_p1 - archer_idx
          address = eu_unit_gold_cost_base + 4 * eu_unit_idx
          core.writeInteger(address, goldCost)
        end
        if is_arab_unit then
          local ar_unit_idx = unit_idx_p1 - arabbow_idx
          address = ar_unit_gold_cost_base + 4*ar_unit_idx
          core.writeInteger(address, goldCost)
        end  -- arab unit display cost

        if is_other_trainable_unit then
          if unit_idx_p1 == 30 then -- engineer cost
            core.writeCodeByte(non_rax_unit_display_cost_func_addr + 15, goldCost)
            core.writeCodeInteger(non_rax_unit_cost_func_addr+42, goldCost)
          elseif unit_idx_p1 == 29 then -- laddermen cost
            core.writeCodeByte(non_rax_unit_display_cost_func_addr + 19, goldCost)
            core.writeCodeInteger(non_rax_unit_cost_func_addr+54, goldCost)
          elseif unit_idx_p1 == 5 then -- tunnellor cost
            core.writeCodeByte(non_rax_unit_display_cost_func_addr + 23, goldCost)
            core.writeCodeInteger(non_rax_unit_cost_func_addr+66, goldCost)
          else -- monk cost (37)
            core.writeCodeByte(non_rax_unit_display_cost_func_addr + 27, goldCost)
            core.writeCodeInteger(non_rax_unit_cost_func_addr+78, goldCost)
          end
        end  -- other unit display cost

      end

      if buildingDamage ~= nil then
        if unit == "Tunneler" then
          core.writeCodeByte(tunneller_building_melee_addr+9, buildingDamage)
        elseif unit == "European archer" then
          core.writeCodeByte(archer_building_melee_addr+9, buildingDamage)
        elseif unit == "European crossbowman" then
          core.writeCodeByte(crossbow_building_melee_addr+4, buildingDamage)
        elseif unit == "European spearman" then
          core.writeCodeByte(spearman_building_melee_addr+9, buildingDamage)
        elseif unit == "European pikeman" then
          core.writeCodeByte(pikeman_building_melee_addr+9, buildingDamage)
        elseif unit == "European maceman" then
          core.writeCodeByte(maceman_building_melee_addr+9, buildingDamage)
        elseif unit == "European swordsman" then
          core.writeCodeByte(swordsman_building_melee_addr+9, buildingDamage)
        elseif unit == "European knight" then
          core.writeCodeByte(knight_building_melee_addr+9, buildingDamage)
        elseif unit == "Monk" then
          core.writeCodeByte(monk_building_melee_addr+9, buildingDamage)
        elseif unit == "Lord" then
          core.writeCodeByte(lord_building_melee_addr+9, buildingDamage)
        elseif unit == "Battering ram" then
          core.writeCodeByte(ram_damage_addr+2, buildingDamage)
        elseif unit == "Arabian archer" then
          core.writeCodeByte(arabbow_building_melee_addr+9, buildingDamage)
        elseif unit == "Arabian slave" then
          core.writeCodeByte(slave_building_melee_addr+14, buildingDamage)
        elseif unit == "Arabian slinger" then
          core.writeCodeByte(slinger_building_melee_addr+9, buildingDamage)
        elseif unit == "Arabian assassin" then
          core.writeCodeByte(assassin_building_melee_addr+9, buildingDamage)
        elseif unit == "Arabian horse archer" then
          core.writeCodeByte(horsearcher_building_melee_addr+9, buildingDamage)
        elseif unit == "Arabian swordsman" then
          core.writeCodeByte(arabsword_building_melee_addr+9, buildingDamage)
        elseif unit == "Arabian firethrower" then
          core.writeCodeByte(firethrower_building_melee_addr+9, buildingDamage)
        end
      end

      if fortificationDamagePenalty ~= nil then
        if unit == "Tunneler" then
          core.writeCodeByte(tunneller_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "European archer" then
          core.writeCodeByte(archer_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "European crossbowman" then
          core.writeCodeByte(crossbow_building_melee_addr+2, fortificationDamagePenalty*-1)
        elseif unit == "European spearman" then
          core.writeCodeByte(spearman_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "European pikeman" then
          core.writeCodeByte(pikeman_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "European maceman" then
          core.writeCodeByte(maceman_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "European swordsman" then
          core.writeCodeByte(swordsman_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "European knight" then
          core.writeCodeByte(knight_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "Monk" then
          core.writeCodeByte(monk_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "Lord" then
          core.writeCodeByte(lord_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "Battering ram" then
          log(WARNING, "Battering ram fortificationDamagePenalty is not supported.")
        elseif unit == "Arabian archer" then
          core.writeCodeByte(arabbow_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "Arabian slave" then
          log(WARNING, "Arabian slave fortificationDamagePenalty is not supported.")
        elseif unit == "Arabian slinger" then
          core.writeCodeByte(slinger_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "Arabian assassin" then
          core.writeCodeByte(assassin_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "Arabian horse archer" then
          core.writeCodeByte(horsearcher_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "Arabian swordsman" then
          core.writeCodeByte(arabsword_building_melee_addr+6, fortificationDamagePenalty)
        elseif unit == "Arabian firethrower" then
          core.writeCodeByte(firethrower_building_melee_addr+6, fortificationDamagePenalty)
        end
      end

      if wallDamage ~= nil then
        if unit == "Tunneler" then
          core.writeCodeInteger(tunneller_building_melee_addr - 53, wallDamage)
        elseif unit == "European archer" then
          core.writeCodeInteger(archer_building_melee_addr - 53, wallDamage)
        elseif unit == "European crossbowman" then
          core.writeCodeInteger(crossbow_building_melee_addr-62, wallDamage)
        elseif unit == "European spearman" then
          core.writeCodeInteger(spearman_building_melee_addr - 36, wallDamage)
        elseif unit == "European pikeman" then
          core.writeCodeInteger(pikeman_building_melee_addr - 55, wallDamage)
        elseif unit == "European maceman" then
          core.writeCodeInteger(maceman_building_melee_addr - 46, wallDamage)
        elseif unit == "European swordsman" then
          core.writeCodeInteger(swordsman_building_melee_addr - 55, wallDamage)
        elseif unit == "European knight" then
          core.writeCodeInteger(knight_building_melee_addr - 55, wallDamage)
        elseif unit == "Monk" then
          core.writeCodeInteger(monk_building_melee_addr - 52, wallDamage)
        elseif unit == "Lord" then
          core.writeCodeInteger(lord_building_melee_addr - 66, wallDamage)
        elseif unit == "Battering ram" then
          log(WARNING, "Battering ram wallDamage is not supported.")
        elseif unit == "Arabian archer" then
          core.writeCodeInteger(arabbow_building_melee_addr - 44, wallDamage)
        elseif unit == "Arabian slave" then
          log(WARNING, "Arabian slave wallDamage is not supported.")
        elseif unit == "Arabian slinger" then
          core.writeCodeInteger(slinger_building_melee_addr - 53, wallDamage)
        elseif unit == "Arabian assassin" then
          core.writeCodeInteger(assassin_building_melee_addr - 52, wallDamage)
        elseif unit == "Arabian horse archer" then
          core.writeCodeInteger(horsearcher_building_melee_addr - 55, wallDamage)
        elseif unit == "Arabian swordsman" then
          core.writeCodeInteger(arabsword_building_melee_addr - 55, wallDamage) -- from 64
        elseif unit == "Arabian firethrower" then
          core.writeCodeInteger(firethrower_building_melee_addr - 53, wallDamage)
        end
      end

    end
  end

  if resources ~= nil then
    for res_name, attrs in pairs(resources) do
      local buy = attrs["buy"]
      local sell = attrs["sell"]
      local baseDelivery = attrs["baseDelivery"]
      local skirmishBonus = attrs["skirmishBonus"]
      local res_index = table.find(resource_names, res_name)-1
      if buy ~= nil then
        address = resource_buy_base + 4 * res_index
        core.writeInteger(address, buy)
      end
      if sell ~= nil then
        address = resource_sell_base + 4 * res_index
        core.writeInteger(address, sell)
      end


      if baseDelivery ~= nil then
        if res_name == "Wood" then
          core.writeCodeByte(woodcutter_func+10, baseDelivery)
        elseif res_name == "Stone" then
          core.writeCodeByte(quarry_grunt_func+3, baseDelivery)
        elseif res_name == "Iron" then
          core.writeCodeByte(ironminer_func+9, baseDelivery)
        elseif res_name == "Pitch" then
          core.writeCodeByte(pitchman_func+10, baseDelivery)
        elseif res_name == "Meat" then
          core.writeCodeByte(hunter_func+10, baseDelivery)
        elseif res_name == "Apple" then
          core.writeCodeByte(apple_farmer_func+3, baseDelivery)
        elseif res_name == "Cheese" then
          core.writeCodeByte(dairy_farmer_func+10, baseDelivery)
        elseif res_name == "Hop" then
          core.writeCodeByte(hops_farmer_func+5, baseDelivery)
        elseif res_name == "Bread" then
          core.writeCodeByte(baker_func+9, baseDelivery)
        elseif res_name == "Wheat" then
          core.writeCodeByte(wheatfarmer_func+9, baseDelivery)
        elseif res_name == "Flour" then
          log(WARNING, "Flour production cannot be modified.")
        elseif res_name == "Beer" then
          core.writeCodeByte(brewer_func+8, baseDelivery)
        elseif res_name == "Bow" then
          core.writeCodeByte(custom_fletcher_code_addr+36, baseDelivery)
        elseif res_name == "Xbow" then
          core.writeCodeByte(custom_fletcher_code_addr+42, baseDelivery)
        elseif res_name == "Spear" then
          core.writeCodeByte(custom_poleturner_code_addr+38, baseDelivery)
        elseif res_name == "Pike" then
          core.writeCodeByte(custom_poleturner_code_addr+44, baseDelivery)
        elseif res_name == "Mace" then
          core.writeCodeByte(custom_blacksmith_code_addr+36, baseDelivery)
        elseif res_name == "Sword" then
          core.writeCodeByte(custom_blacksmith_code_addr+42, baseDelivery)
        elseif res_name == "Leather" then
          core.writeCodeByte(tanner_func+8, baseDelivery)
        elseif res_name == "Armor" then
          core.writeCodeByte(armourer_func+8, baseDelivery)
        end
      end

      if skirmishBonus ~= nil then
        local sb = skirmishBonus and 1 or 0
        if res_name == "Wood" then
          core.writeCodeByte(woodcutter_func + 1, sb)
        elseif res_name == "Stone" then
          core.writeCodeByte(quarry_grunt_func+1, sb)
        elseif res_name == "Iron" then
          core.writeCodeByte(ironminer_func+1, sb)
        elseif res_name == "Pitch" then
          core.writeCodeByte(pitchman_func+1, sb)
        elseif res_name == "Meat" then
          core.writeCodeByte(hunter_func+1, sb)
        elseif res_name == "Apple" then
          core.writeCodeByte(apple_farmer_func+1, sb)
        elseif res_name == "Cheese" then
          core.writeCodeByte(dairy_farmer_func+1, sb)
        elseif res_name == "Hop" then
          core.writeCodeByte(hops_farmer_func+1, sb)
        elseif res_name == "Bread" then
          core.writeCodeByte(baker_func+7, sb)
        elseif res_name == "Wheat" then
          core.writeCodeByte(wheatfarmer_func+7, sb)
        elseif res_name == "Flour" then
          log(WARNING, "Flour production cannot be modified.")
        elseif res_name == "Beer" then
          core.writeCodeByte(brewer_func+6, sb)
        elseif res_name == "Bow" then
          core.writeCodeByte(custom_fletcher_code_addr+34, sb)
        elseif res_name == "Xbow" then
          core.writeCodeByte(custom_fletcher_code_addr+40, sb)
        elseif res_name == "Spear" then
          core.writeCodeByte(custom_poleturner_code_addr+36, sb)
        elseif res_name == "Pike" then
          core.writeCodeByte(custom_poleturner_code_addr+42, sb)
        elseif res_name == "Mace" then
          core.writeCodeByte(custom_blacksmith_code_addr+34, sb)
        elseif res_name == "Sword" then
          core.writeCodeByte(custom_blacksmith_code_addr+40, sb)
        elseif res_name == "Leather" then
          core.writeCodeByte(tanner_func+6, sb)
        elseif res_name == "Armor" then
          core.writeCodeByte(armourer_func+6, sb)
        end
      end
    end
  end

  if population_gathering_rate ~= nil then
    for pgr, data in pairs(population_gathering_rate) do
      if pgr == "Skirmish" then
        for threshold, value in pairs(data) do
          local pgr_index = table.find(pop_thresholds, threshold)-1
          address = skirmish_pgr_base + 4 * pgr_index
          core.writeInteger(address, value)
        end
      end
      if pgr == "Scenario_lt_100" then
        for threshold, value in pairs(data) do
          local pgr_index = table.find(pop_thresholds, threshold)-1
          address = scenario_pgr_base + 4 * pgr_index
          core.writeInteger(address, value)
        end
      end
      if pgr == "Scenario_gt_100" then
        for threshold, value in pairs(data) do
          local pgr_index = table.find(pop_thresholds, threshold)-1
          address = scenario_pgr_crowded_base + 4 * pgr_index
          core.writeInteger(address, value)
        end
      end
    end
  end

  if religion ~= nil then
    for key, val in pairs(religion) do
      if key == "thresholds" then
        core.writeCodeByte(religion_addr_1 + 2, val[1])
        core.writeCodeByte(religion_addr_1 + 11, val[2])
        core.writeCodeByte(religion_addr_1 + 23, val[3])
        core.writeCodeByte(religion_addr_1 + 37, val[4])

        core.writeCodeByte(religion_addr_2 + 2, val[1])
        core.writeCodeByte(religion_addr_2 + 11, val[2])
        core.writeCodeByte(religion_addr_2 + 23, val[3])
        core.writeCodeByte(religion_addr_2 + 37, val[4])

        core.writeCodeByte(religion_addr_2 + 100, val[1]-1)
        core.writeCodeByte(religion_addr_2 + 115, val[2]-1)
        core.writeCodeByte(religion_addr_2 + 130, val[3]-1)
        core.writeCodeByte(religion_addr_2 + 145, val[4]-1)

        core.writeCodeInteger(religion_addr_2 + 107, val[1])
        core.writeCodeInteger(religion_addr_2 + 122, val[2])
        core.writeCodeInteger(religion_addr_2 + 137, val[3])
        core.writeCodeInteger(religion_addr_2 + 152, val[4])

        core.writeCodeByte(religion_addr_3 + 2, val[1]-1)
        core.writeCodeByte(religion_addr_3 + 11, val[2]-1)
        core.writeCodeByte(religion_addr_3 + 23, val[3]-1)
        core.writeCodeByte(religion_addr_3 + 37, val[4]-1)
      end
      if key == "bonuses" then
        core.writeCodeInteger(religion_addr_1 + 15, val[1])
        core.writeCodeInteger(religion_addr_1 + 27, val[2])
        core.writeCodeByte(religion_addr_1 + 46, val[3]-val[4])
        core.writeCodeInteger(religion_addr_1 + 49, val[4])

        core.writeCodeInteger(religion_addr_2 + 15, val[1])
        core.writeCodeByte(religion_addr_2 + 27, val[2])
        core.writeCodeByte(religion_addr_2 + 46, val[3]-val[4])
        core.writeCodeInteger(religion_addr_2 + 49, val[4])

        core.writeCodeInteger(religion_addr_3 + 15, val[1])
        core.writeCodeInteger(religion_addr_3 + 27, val[2])
        core.writeCodeByte(religion_addr_3 + 46, val[3]-val[4])
        core.writeCodeByte(religion_addr_3 + 49, val[4])
        end
      if key == "church_bonus" then
        core.writeCodeByte(religion_addr_1 + 64, val)
        core.writeCodeByte(religion_addr_2 + 448, val)
        core.writeCodeByte(religion_addr_3 + 66, val)
      end
      if key == "cathedral_bonus" then
        core.writeCodeByte(religion_addr_1 + 76, val)
        core.writeCodeByte(religion_addr_2 + 463, val)
        core.writeCodeByte(religion_addr_3 + 78, val)
      end
    end
  end

  if beer ~= nil then
    for key, val in pairs(beer) do
      if key == "thresholds" then
        core.writeCodeByte(beer_addr_1 + 2, val[1])
        core.writeCodeByte(beer_addr_1 + 11, val[2])
        core.writeCodeByte(beer_addr_1 + 23, val[3])
        core.writeCodeByte(beer_addr_1 + 37, val[4])

        core.writeCodeByte(beer_addr_2 + 2 , val[1])
        core.writeCodeByte(beer_addr_2 + 11 , val[2])
        core.writeCodeByte(beer_addr_2 + 23 , val[3])
        core.writeCodeByte(beer_addr_2 + 37 , val[4])

        core.writeCodeByte(beer_addr_3 + 2, val[1])
        core.writeCodeByte(beer_addr_3 + 18, val[2])
        core.writeCodeByte(beer_addr_3 + 30, val[3])
        core.writeCodeByte(beer_addr_3 + 44, val[4])
      end
      if key == "bonuses" then
        core.writeCodeByte(beer_addr_1 + 15, val[1])
        core.writeCodeByte(beer_addr_1 + 27, val[2])
        core.writeCodeByte(beer_addr_1 + 46, val[3]-val[4])
        core.writeCodeByte(beer_addr_1 + 48, val[4])

        core.writeCodeByte(beer_addr_2 + 15 , val[1])
        core.writeCodeByte(beer_addr_2 + 27 , val[2])
        core.writeCodeByte(beer_addr_2 + 46 , val[3]-val[4])
        core.writeCodeByte(beer_addr_2 + 49 , val[4])

        core.writeCodeByte(beer_addr_3 + 22, val[1])
        core.writeCodeByte(beer_addr_3 + 34, val[2])
        core.writeCodeByte(beer_addr_3 + 53, val[3]-val[4])
        core.writeCodeByte(beer_addr_3 + 56, val[4])
      end
      if key == "coverage_per_inn" then
        core.writeCodeInteger(beer_coverage_addr+19, val*100)
      end
    end
  end

  if food ~= nil then
    for key, val in pairs(food) do
      if key == "ration_bonuses" then
        core.writeCodeInteger(food_addr_1 + 1, val[1])
        core.writeCodeInteger(food_addr_1 + 70, val[1])
        core.writeCodeInteger(food_addr_1 + 61, val[2])
        core.writeCodeByte(food_addr_1 + 44, val[3])
        core.writeCodeInteger(food_addr_1 + 31, val[4])

        core.writeCodeInteger(food_addr_2 + 1, val[1])
        core.writeCodeInteger(food_addr_2 + 57, val[1])
        core.writeCodeByte(food_addr_2 + 51, val[2]-1)
        core.writeCodeByte(food_addr_2 + 32, val[3]-3)
        core.writeCodeInteger(food_addr_2 + 19, val[4])

        core.writeCodeInteger(food_addr_3 + 1, val[1])
        core.writeCodeInteger(food_addr_3 + 19, val[1])
        core.writeCodeByte(food_addr_3 + 32, val[2]-1)
        core.writeCodeInteger(food_addr_3 + 60, val[3])
        core.writeCodeInteger(food_addr_3 + 50, val[4])

      end
      if key == "variety_bonuses" then
        core.writeCodeByte(food_addr_1 + 466, val[1]-2)
        core.writeCodeByte(food_addr_1 + 476, val[2]-3)
        core.writeCodeInteger(food_addr_1 + 485, val[3])

        core.writeCodeByte(food_addr_2 + 89, val[1])
        core.writeCodeByte(food_addr_2 + 99, val[2])
        core.writeCodeByte(food_addr_2 + 109, val[3])

        core.writeCodeByte(food_addr_3 + 84, val[1])
        core.writeCodeByte(food_addr_3 + 94, val[2])
        core.writeCodeByte(food_addr_3 + 104, val[3])
      end
    end
  end

  if fear_factor ~= nil then
    for key, val in pairs(fear_factor) do
      if key == "popularity_per_good_level" then
        core.writeCodeByte(ff_addr_1 + 13, val)
        core.writeCodeByte(ff_addr_2 + 13, val)
        core.writeCodeByte(ff_addr_3 + 14, val)
      end
      if key == "popularity_per_bad_level" then
        core.writeCodeByte(ff_addr_1 + 23, val)
        core.writeCodeByte(ff_addr_2 + 25, val)
        core.writeCodeByte(ff_addr_3 + 28, val)
      end
      if key == "productivity" then
        core.writeCodeInteger(productivity_addr + 2, val[1])
        core.writeCodeInteger(productivity_addr + 15, val[2])
        core.writeCodeInteger(productivity_addr + 28, val[3])
        core.writeCodeInteger(productivity_addr + 41, val[4])
        core.writeCodeInteger(productivity_addr + 54, val[5])
        core.writeCodeInteger(productivity_addr + 66, val[6])
        core.writeCodeInteger(productivity_addr + 79, val[7])
        core.writeCodeInteger(productivity_addr + 92, val[8])
        core.writeCodeInteger(productivity_addr + 105, val[9])
        core.writeCodeByte(productivity_addr + 124, val[10]-val[11])
        core.writeCodeByte(productivity_addr + 127, val[11])
      end
      if key == "coverage" then
        local custom_coverage_instructions = {
          0x85, 0xC9,  -- test ecx, ecx
          0x74, 0x01,  -- jn by one
          0x49,  -- dec ecx
          0xC1, 0xF9, val,  -- sar ecx, coverage_value
          0x41  -- inc ecx
        }
        core.insertCode(ff_coverage_addr, 6, custom_coverage_instructions)
      end
      if key == "combat_bonus" then
        local damage_table_addr = core.allocate(11)
        local custom_combat_instructions = {
          0x8A, 0x88, core.itob(damage_table_addr+5),
          0x0F, 0xAF, 0x4C, 0x24, 0x04,             -- imul ecx,[esp+04]
          core.jmpTo(combat_bonus_memory_addr+11)   -- jmp 0053162B
        }

        core.writeCode(damage_table_addr, val, true)
        local custom_combat_addr = core.allocateCode(core.calculateCodeSize(custom_combat_instructions))

        local combat_jumpout_instructions = {
          0x31, 0xC9,                   -- xor ecx, ecx
          core.jmpTo(custom_combat_addr),
          0x90, 0x90, 0x90, 0x90        -- nop nop nop nop
        }

        core.writeCode(custom_combat_addr, custom_combat_instructions, true)
        core.writeCode(combat_bonus_memory_addr, combat_jumpout_instructions, true)
      end
    end
  end

  if taxation ~= nil then
    local tax_table = taxation["gold"]
    local pop_table = taxation["popularity"]
    local adv_multipliers = taxation["advantage_multiplier"]
    local neutral_level = 3
    if tax_table ~= nil then
      for idx, tax_val in ipairs(tax_table) do
        core.writeCodeSmallInteger(tax_table_addr+2*(idx-1), math.floor(tax_val*100))
        if math.floor(tax_val*100) == 0 then
          neutral_level = idx-1
        end
      end
    end
    core.writeCodeByte(neutral_level_addr_1 + 2, neutral_level)
    core.writeCodeByte(neutral_level_addr_2, neutral_level)
    core.writeCodeByte(neutral_level_addr_3 + 2, neutral_level)
    core.writeCodeByte(neutral_level_addr_4 + 2, neutral_level)
    if pop_table ~= nil then
      local pop_table_addr = keep_menu_addr + 31
      core.writeCodeBytes(keep_menu_addr, core.compile({  -- keep menu
        0x83, 0xF8, neutral_level,
        0x7D, 0x09,                          -- jnl 0043B0AB
        0x83, 0x7C, 0x24, 0x10, 0x00,        -- cmp dword ptr [esp+10],00 { 0 }
        0x7F, 0x02,                          -- jle 0043B0AB
        0xB0, neutral_level,                 -- mov al,03 { 3 }
        0xC1, 0xE0, 0x02,                    -- shl eax,02 { 2 }
        0x8B, 0x80, core.itob(pop_table_addr),  -- mov eax,[eax+0043B0BC]
        0xE9, 0x84, 0x00, 0x00, 0x00,        -- jmp 0043B13D
        0x90,                                -- nop
        0x90,                                -- nop
        0x90                                 -- nop
      }, keep_menu_addr))
      for index, value in ipairs(pop_table) do
        core.writeCodeInteger(pop_table_addr + 4*(index-1), value)
      end
      -- 75 bytes are free in function

      core.writeCodeBytes(pop_report_addr + 6, core.compile({  -- pop report
        neutral_level,
        0x7D, 0x0E,
        0x83, 0x7C, 0x24, 0x18, 0x00,
        0x7F, 0x07,
        0xB8, neutral_level, 0x00, 0x00, 0x00,  -- mov eax,00000003
        0xEB, 0x06,                             -- jmp 0043EBDB
        0x8B, 0x80, core.itob(tax_popularity_offset),     -- mov eax,[eax+011F0BC0]
        0xC1, 0xE0, 0x02,                       -- shl eax,02
        0x8B, 0xB0, core.itob(pop_table_addr),     -- mov esi,[eax+0043B0BC]
        0xEB, 0x76                              -- jmp 0043EC5C
      }, pop_report_addr + 6))
      -- 118 bytes are free in function

      core.writeCodeBytes(actual_effect_addr + 2, core.compile({  -- actual effect
        neutral_level,
        0x7D, 0x06,
        0x85, 0xED,
        0x7F, 0x02,
        0xB0, neutral_level,
        0xC1, 0xE0, 0x02,
        0x8B, 0x80, core.itob(pop_table_addr),
        0xE9, 0x80, 0x00, 0x00, 0x00
      }, actual_effect_addr + 2))
      -- 128 bytes are free in function

    end

    if adv_multipliers ~= nil then
      local human_big_ai_medium = adv_multipliers["human_big_ai_medium"]
      local ai_big = adv_multipliers["ai_big"]
      if human_big_ai_medium ~= nil then
        core.writeCodeInteger(multipliers_addr_base + 46, human_big_ai_medium)
      end 
      if ai_big ~= nil then
        core.writeCodeInteger(multipliers_addr_base + 2, ai_big)
      end
    end

  end

  if enable_iron_double_pickup then
    double_iron_pickup()
  end

  if enable_ascension ~= nil then
    if data.version.isExtreme() then
      ascension_extras()
    else
      log(WARNING, "Ascension mode is only supported in SHC Extreme!")
    end
  end

  if enable_ai_ascension ~= nil then
    if data.version.isExtreme() then
      ai_ascension_extras()
    else
      log(WARNING, "AI Ascension mode is only supported in SHC Extreme!")
    end
  end

end

namespace.disable = function(self, config)
end

return namespace
