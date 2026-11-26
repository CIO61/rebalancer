local constants = require("constants")
local templates = require("templates")

local building_names = constants.building_names
local unit_names = constants.unit_names
local military_ground_unit_names = constants.military_ground_unit_names
local resource_names = constants.resource_names
local namespace = {}

-- Game code and data the settings change. { aob, offset = n }: the first match plus n.
-- `after`, `skip`: the first match from that site's address plus skip. `from`: that site plus offset.
-- `read = d`: the site is the dword at that address plus d.
local SITES = {
  -- data the game code addresses; the unit tables are indexed from unit id 1
  unit_array_base = { "69 C9 90 04 00 00 6A 00 6A 00 81 C1 ? ? ? ? 68 90 04 00 00 51", offset = 12, read = 0 },
  building_array_base = { "69 C9 2C 03 00 00 6A 00 6A 00 81 C1 ? ? ? ? 68 2C 03 00 00 51", offset = 12, read = 0 },
  unit_melee_toggles_base = { "66 8B 14 85 ? ? ? ? 66 89 51 FE", offset = 4, read = 4 },
  unit_jester_unfriendly_base = { "83 3C 8D ? ? ? ? 00 75 75 3B 5C 24 1C", offset = 3, read = 4 },
  unit_blessable_base = { "83 3C 95 ? ? ? ? 00 75 57 8B 87 44 01 00 00", offset = 3, read = 4 },
  unit_allowed_on_walls_base = { "8B 14 95 ? ? ? ? 33 DB 81 FD 8F 01 00 00", offset = 3, read = 4 },
  unit_melee_immunity_base = { "8A 04 BD ? ? ? ? 88 86 40 09 00 00", offset = 3, read = 4 },
  towers_or_gates_base = { from = "crossbow_building_melee_addr", offset = -7, read = 0 },
  unit_gold_jumplist_addr = { from = "non_rax_unit_display_cost_func_addr", offset = 10, read = 0 },
  tax_popularity_offset = { from = "pop_report_addr", offset = 28, read = 0 },

  pop_gathering_addr = { "8B 0C 85 ? ? ? ? EB 2D 8B 4E F0" },
  scenario_pgr_base = { "EC FF FF FF F1 FF FF FF F4 FF FF FF F6 FF FF FF F7 FF FF FF F8 FF FF FF F9 FF FF FF FA FF FF FF FB FF FF FF FB FF FF FF 05 00 00 00 05 00 00 00" },
  scenario_pgr_crowded_base = { from = "scenario_pgr_base" },  -- the same AOB as scenario_pgr_base
  skirmish_pgr_base = { "F8 FF FF FF FA FF FF FF FB FF FF FF FC FF FF FF FD FF FF FF FD FF FF FF FE FF FF FF FE FF FF FF FF FF FF FF FF FF FF FF 0A 00 00 00 0C 00 00 00" },
  large_town_threshold_addr = { "83 BE ? ? ? ? 64 7E 09", offset = 6 },
  min_peasants_addr = { "83 FA 04 7E 3B", offset = 2 },
  pop_reset_population_limit_addr = { "83 F9 03 7F 1F", offset = 2 },
  pop_reset_popularity_limit_addr = { from = "pop_reset_population_limit_addr", offset = 10 },
  pop_reset_value_addr = { from = "pop_reset_population_limit_addr", offset = 25 },
  crowding_addr_1 = { "83 F8 64 7F 04 33 C0 EB 40 83 F8 78" },
  crowding_addr_2 = { "83 F8 64 7F 04 33 F6 EB 40 83 F8 78" },

  non_rax_unit_cost_func_addr = { "8B 44 24 04 83 F8 1E 55" },
  non_rax_unit_display_cost_func_addr = { "33 DB 83 F8 03 77 1A FF 24 85 ? ? ? ?" },

  ballista_damage_addr = { "66 83 F9 37 75 07 B9 32 00 00 00 EB 70 66 83 F9" },  -- 125 bytes (+14)
  mangonel_damage_addr = { "66 83 F9 37 75 0A B9 32 00 00 00 E9 51 01 00 00" },  -- 154 bytes

  unit_health_base = { "C4 09 00 00 C4 09 00 00 10 27 00 00 C4 09 00 00 10 27 00 00 88 13 00 00 10 27 00" },
  unit_arrow_dmg_base = { "98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 88 13 00 00 98 3A 00 00 98 3A 00 00 98 3A" },
  unit_xbow_dmg_base = { "98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 98 3A 00 00 88 13 00 00 98 3A 00 00 B8 0B 00 00" },
  unit_stone_dmg_base = { "00 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00 88 13 00 00", offset = 3 },
  unit_speed_base = { "01 00 00 00 01 00 00 00 02 00 00 00 03 00 00 00 01 00 00 00 01 00 00 00 02 00 00 00 02 00 00 00 03 00 00 00 01 00 00 00" },

  tunneller_building_melee_addr = { "B9 06 00 00 00 EB 39 0F BF 34 55 ? ? ? ? 3B F3 7F 0D 5F 5E 5D 66 89 98 ? ? ? ? 5B 59 C3 8B CE 69 C9 2C 03 00 00 0F BF 89 ? ? ? ? 8B 0C 8D ? ? ? ? F7 D9 1B C9 83 E1 F0 83 C1 14 0F BF A8", offset = 54 },
  archer_building_melee_addr = { "8B CF 69 C9 2C 03 00 00 0F BF 89 ? ? ? ? 8B 0C 8D ? ? ? ? F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", offset = 22 },  -- +6 +9
  crossbow_building_melee_addr = { "39 04 95 ? ? ? ? 0F 94 C0 33 FF 8D 44 00 02 8B D0 8B 44 24 10", offset = 10 },
  spearman_building_melee_addr = { "F7 D9 1B C9 83 E1 FB 83 C1 08 0F BF 90" },  -- +6 +9
  maceman_building_melee_addr = { "F7 D9 1B C9 83 E1 E1 83 C1 23 0F BF 98" },  -- +6 +9
  pikeman_building_melee_addr = { "F7 D9 1B C9 83 E1 F0 83 C1 14 0F BF A8", after = "tunneller_building_melee_addr", skip = 10 },  -- +6 +9
  swordsman_building_melee_addr = { "F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF 98" .. string.rep(" ?", 199) .. " 3B FD 74 6C 8B B8 ? ? ? ? 69 C9 BC 77 01 00" },  -- +6 +9
  knight_building_melee_addr = { "8D 8C CA D9 01 00 00 89 88 ? ? ? ? 39 A8" .. string.rep(" ?", 214) .. " F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF 98", offset = 229 },  -- +6 +9
  lord_building_melee_addr = { "F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF A8 ? ? ? ? 57" },
  arabbow_building_melee_addr = { "F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", after = "archer_building_melee_addr", skip = 10 },  -- +6 +9
  slave_building_melee_addr = { "0F BF 90 ? ? ? ? 8B 80 ? ? ? ? 6A 08" },  -- +14
  slinger_building_melee_addr = { "F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", after = "arabbow_building_melee_addr", skip = 10 },  -- +6 +9
  assassin_building_melee_addr = { "F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF A8", after = "lord_building_melee_addr", skip = 10 },  -- +6 +9
  firethrower_building_melee_addr = { "F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", after = "slinger_building_melee_addr", skip = 10 },  -- +6 +9
  horsearcher_building_melee_addr = { "F7 D9 1B C9 83 E1 FD 83 C1 04 0F BF 98", after = "firethrower_building_melee_addr", skip = 10 },  -- +6 +9
  arabsword_building_melee_addr = { "F7 D9 1B C9 83 E1 C0 83 C1 46 0F BF A8", after = "assassin_building_melee_addr", skip = 10 },  -- +6 +9
  monk_building_melee_addr = { "F7 D9 1B C9 83 E1 EF 83 C1 14 0F BF A8 ? ? ? ? 6A 01" },  -- +6 +9
  ram_damage_addr = { "55 6A 32 52 8B 90 ? ? ? ? 51 52" },  -- +3

  unit_power_levels_addr = { "05 00 00 00 0A 00 00 00 04 00 00 00 0A 00 00 00 0A 00 00 00" },
  eu_unit_gold_cost_base = { "0C 00 00 00 14 00 00 00 08 00 00 00 14 00 00 00" },
  ar_unit_gold_cost_base = { "4B 00 00 00 05 00 00 00 0C 00 00 00 3C 00 00 00" },
  unit_melee_dmg_base = { "8D 04 80 C1 E0 04 03 C2 66 83 F9 37 8B 04 85", offset = 15, read = 0x144 },  -- read as [(attacker * 80 + defender) * 4 + table], ids from 1

  -- building related addresses
  building_cost_base = { "06 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 06 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 03" },
  building_health_base = { "64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 64 00 00 00 2C" },
  building_population_base = { "0B 00 00 00 00 00 00 00 00 00 00 00 08 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00", offset = 12 },

  -- siege related addresses
  cat_collateral_addr = { "8B 1C 95 ? ? ? ? 8B CB BF 0A 00 00 00 81 E1 01 00 10 40 8B EF", offset = 10 },
  siege_projectile_func_addr = { "66 83 F9 03 75 0A BF 3C 00 00 00 8D 6F E2" },
  oneshot_threshold_addr = { "81 F9 20 4E 00 00 0F 8E F9 FD FF FF" },
  cat_primary_addr = { from = "siege_projectile_func_addr", offset = 23 },  -- integer
  treb_collateral_penalty_addr = { from = "siege_projectile_func_addr", offset = 13 },  -- byte
  treb_primary_addr = { from = "siege_projectile_func_addr", offset = 7 },  -- integer
  mango_primary_addr = { from = "siege_projectile_func_addr", offset = 36 },  -- integer

  -- resource related addresses
  resource_buy_base = { "14 00 00 00 4B 00 00 00 46 00 00 00 00 00 00 00 E1 00 00 00 64 00 00 00 64 00 00 00 73 00 00 00 28 00 00 00 28 00 00 00 28 00 00 00 28 00 00 00" },
  resource_sell_base = { "05 00 00 00 28 00 00 00 23 00 00 00 00 00 00 00 73 00 00 00 32 00 00 00 32 00 00 00 28 00 00 00 14 00 00 00 14 00 00 00 14 00 00 00 14 00 00 00" },

  woodcutter_func = { "6A 01 66 89 BE ? ? ? ? 6A 0C 89 96 ? ? ? ? 50" },
  quarry_grunt_func = { "6A 01 6A 08 55 C7 81 ? ? ? ? 00 00 00 00 E8" },
  ironminer_func = { "6A 01 8D 80 ? ? ? ? 6A 01 51 E8" },
  pitchman_func = { "6A 01 66 89 AE ? ? ? ? 6A 01 89 8E" },
  hunter_func = { "6A 01 66 89 BE ? ? ? ? 6A 06 89 8E ? ? ? ?" },
  apple_farmer_func = { "6A 01 6A 03 50 66 C7 86 ? ? ? ? 07 00 E8" },
  dairy_farmer_func = { "6A 01 66 89 BE ? ? ? ? 6A 03 89 96 ? ? ? ? 50 66 C7 86 ? ? ? ? 05 00" },
  hops_farmer_func = { "6A 01 74 04 6A 02 EB 02 6A 01 50 E8" },  -- hops farm yields 1 per delivery on scenario/castle builder mode, 2 on skirmish

  baker_func = { "53 C6 86 ? ? ? ? FE 6A 08 66 C7 86 ? ? ? ? 05 00" },  -- skirmish bonus is push ebx instead of push val
  wheatfarmer_func = { "53 66 89 BE ? ? ? ? 6A 02" },  -- skirmish bonus is push ebx instead of push val
  brewer_func = { "55 C6 86 ? ? ? ? FE 55 66 C7 86 ? ? ? ? 07 00 57 66 89 9E ? ? ? ? E8 ? ? ? ? 83 C4 0C 66 89 86 ? ? ? ? 57 B9 ? ? ? ? 66 89 AE ? ? ? ? E8 ? ? ? ? A1 ? ? ? ? 69 C0 90 04 00 00 5F" },  -- both produce amount and skirmish bonus is push ebp instead of push val

  fletcher_func = { "55 55 66 89 9E ? ? ? ? 50 66 C7 86 ? ? ? ? 06 00 E8" },
  poleturner_func = { "55 C6 86 ? ? ? ? FE 55 66 C7 86 ? ? ? ? 07 00", after = "brewer_func", skip = 16 },  -- exact same AOB as brewer func
  blacksmith_func = { "55 55 66 89 9E ? ? ? ? 50 66 C7 86 ? ? ? ? 07 00 E8" },
  tanner_func = { "53 53 50 66 89 AE ? ? ? ? E8 53 6C FD FF 66 89 86" },
  armourer_func = { "55 C6 86 ? ? ? ? FE 55 66 C7 86 ? ? ? ? 07 00 57 66 89 9E ? ? ? ? E8", after = "poleturner_func", skip = 16 },

  -- religion related addresses
  religion_addr_1 = { "83 F8 18 7F 04 33 C9 EB 2C 83 F8 31 7F 07 B9 32 00 00 00 EB 20 83 F8 4A 7F 07 B9 64 00 00 00 EB 14 33 C9 83 F8 5E 0F 9F C1 83 E9 01 83 E1 CE 81 C1 C8 00 00 00 83 BE" },
  religion_addr_2 = { "83 F8 18 7F 04 33 C0 EB 2E 83 F8 31 7F 07 B8 32 00 00 00 EB 22 83 F8 4A 7F 07 B8 64 00 00 00 EB 16 33 D2 83 F8 5E 0F 9F C2 83 EA 01 83 E2 CE 81 C2 C8 00 00 00 8B C2" },
  religion_addr_3 = { "83 F8 18 7F 04 33 F6 EB 2E 83 F8 31 7F 07 BE 32 00 00 00 EB 22 83 F8 4A 7F 07 BE 64 00 00 00 EB 16 33 D2 83 F8 5E 0F 9F C2 83 EA 01 83 E2 CE 81 C2 C8 00 00 00 8B F2 83 B9" },

  -- beer related addresses
  beer_addr_1 = { "83 FE 19 7D 04 33 C0 EB 2B 83 FE 32 7D 07 B8 32 00 00 00 EB 1F 83 FE 4B 7D 07 B8 64 00 00 00 EB 13 33 C0 83 FE 64 0F 9D C0 83 E8 01 83 E0 CE 05 C8 00 00 00 8B" },
  beer_addr_2 = { "83 F8 19 7D 04 33 F6 EB 2E 83 F8 32 7D 07 BE 32 00 00 00 EB 22 83 F8 4B 7D 07 BE 64 00 00 00 EB 16 33 C9 83 F8 64 0F 9D C1 83 E9 01 83 E1 CE 81 C1 C8 00 00 00 8B F1" },
  beer_addr_3 = { "83 F8 19 89 84 3E ? ? ? ? 7D 04 33 C0 EB 2E 83 F8 32 7D 07 B8 32 00 00 00 EB 22 83 F8 4B 7D 07 B8 64 00 00 00 EB 16 33 D2 83 F8 64 0F 9D C2 83 EA 01 83 E2 CE 81 C2 C8 00 00 00 8B C2" },
  beer_coverage_addr = { "7F 05 33 C0 C2 04 00 8B 89 ? ? ? ? 85 C9 7E F1 69 C0 B8 0B 00 00 99" },
  flagon_mul_addr = { "69 C0 2C 03 00 00 66 81 80 ? ? ? ? A0 00" },
  flagon_inn_display_addr = { "8D B6 ? ? ? ? 50 B8 67 66 66 66 F7 E9 C1 FA 06" },

  -- food related addresses
  food_addr_1 = { "BE 38 FF FF FF EB 49 8B 0D ? ? ? ? 69 C9 ? ? ? ? 8B 81 ? ? ? ? 83 F8 04 75 07 BE C8 00 00 00 EB 2B 83 F8 03 75 05 8D 70 61 EB 21 83 F8 02 75 04 33 F6 EB 18 3B C3 75 07 BE 9C FF FF FF EB 0D 85 C0 BE 38 FF FF FF 74 04" },
  food_addr_2 = { "BE 38 FF FF FF EB 3C 8B 88 ? ? ? ? 83 F9 04 75 07 BE C8 00 00 00 EB 2A 83 F9 03 75 05 8D 71 61 EB 20 83 F9 02 75 04 33 F6 EB 17 83 F9 01 75 05 8D 71 9B EB 0D 85 C9 BE 38 FF FF FF 74 04" },
  food_addr_3 = { "B9 38 FF FF FF EB 3F 8B 84 3E ? ? ? ? 85 C0 75 07 B9 38 FF FF FF EB 2D 83 F8 01 75 05 8D 48 9B EB 23 83 F8 02 75 04 33 C9 EB 1A 83 F8 04 75" },
  food_point_addr = { "0E 3B CD 74 25 B8 98 3A 00 00 99", offset = 6 },

  -- fear factor related addresses
  ff_addr_1 = { "8B 82 ? ? ? ? 83 F8 01 7C 05 6B C0 19 EB 0C 83 F8 FF 7F 05 6B C0 19" },
  ff_addr_2 = { "8B 81 ? ? ? ? 83 F8 01 7C 07 6B C0 19 8B F0 EB 0E 83 F8 FF 7F 07 6B C0 19" },
  ff_addr_3 = { "8B 84 3E ? ? ? ? 83 F8 01 7C 09 6B C0 19 89 44 24 1C EB 16 83 F8 FF 7F 09 6B C0 19" },
  productivity_addr = { "C7 01 96 00 00 00 EB 7A 83 F8 FC 7F 08 C7 01 8C 00 00 00 EB 6D 83 F8 FD 7F 08 C7 01" },
  ff_coverage_addr = { "C1 F9 04 83 C1 01 2B 46 F8" },
  combat_bonus_memory_addr = { "83 C0 14 0F AF 44 24 04 8D 0C 80 B8 1F 85 EB 51 F7 E9" },
  resting_factor_addr = { "69 F6 ? ? ? ? 66 83 86 ? ? ? ? 01", offset = 13 },

  positive_troop_combat_bonus_visual_addr = { "8D 96 A2 00 00 00 8D 0C 80" },
  negative_troop_combat_bonus_visual_addr = { "8D 96 98 00 00 00 8D 0C 80" },

  -- tax related addresses
  tax_addr = { "8B 44 24 08 83 C0 FF 0F AF 44 24 0C 99 2B C2 D1 F8" },
  bribe_addr = { "B8 05 00 00 00 2B 44 24 08 0F AF 44 24 0C 99" },
  neutral_level_addr_1 = { "83 F8 03 7D 12" },
  neutral_level_addr_2 = { "03 00 00 00 C7 86 E4" },
  neutral_level_addr_3 = { "83 F8 03 7E 16 8B 54 24 0C 52 50 8B 44 24 0C 50" },
  neutral_level_addr_4 = { "83 F8 03 7D 16 8B 54 24 0C 52 50" },
  keep_menu_addr = { "83 F8 03 7D 07 83 7C 24 10 00 7E 2B 85 C0 75 0A B8 AF 00 00 00 E9 86 00 00 00 83 F8 01 75 07 B8 7D 00 00 00 EB 7A 83 F8 02 75 07 B8 4B 00 00 00" },
  pop_report_addr = { "83 B8 ? ? ? ? 03 7D 11 83 7C 24 18 00 7F 0A BE 19 00 00 00 E9 ? ? ? ? 8B 80 ? ? ? ? 85 C0" },
  actual_effect_addr = { "83 F8 03 7D 0E 85 ED 7F 0A B8 19 00 00 00 E9 86 00 00" },
  multipliers_addr_base = { "69 C0 FA 00 00 00 8B C8 B8 1F 85 EB 51 F7 E9 C1 FA 05 8B C2 C1 E8 1F" },

  -- castle defence addresses
  pitch_ditch_costaddr = { "5D 66 C7 06 01 00", offset = 4 },
  killing_pit_dmg_addr = { "75 7D 81 86 ? ? ? ? B0 B9 FF FF", offset = 8 },
  dog_threshold_addr = { "E8 ? ? ? ? 83 3D ? ? ? ? 19 7D 0D", offset = 11 },
  fire_damage_code_addr = { "66 83 FF 37 75 07 B8 19 00 00 00 EB 21 66 83 FF 35 75 09" },

  -- leather_per_cow address
  leather_per_cow_address = { "53 6A 03 6A 03 6A 05 52 50" },

  -- range related addresses
  base_ranges_table_addr = { "36 00 00 00 4B 00 00 00 55 00 00 00 46 00 00 00 00 00 00 00 00 00 00 00 36" },
  proj_velocity_table_addr = { "7D 00 00 00 0A 00 00 00 1E 00 00 00 0F 00 00 00 64 00 00 00 64 00 00 00" },
  proj_archtype_table_addr = { "00 00 00 00 02 00 00 00 01 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00" },

  range_split_addr1 = { "8B 04 85 ? ? ? ? 0F AF C0 66 83 BC 37" },  -- (0x54B621)  -- patch size should be 7
  range_split_addr2 = { "BD 64 0B 00 00 E9 A2 00 00 00" },  -- (0x43595D)  -- patch size should be 5
  range_split_addr3 = { "BE 64 0B 00 00 E9 A5 00 00 00" },  -- (0x436339)  -- patch size should be 5
  range_split_addr4 = { "BE 64 0B 00 00 0F 87 52 01 00 00" },  -- (0x435E2C)  -- patch size should be 5
  range_split_addr5 = { "B8 64 0B 00 00 EB 25 B8" },  -- (0x4369B2)  -- patch size should be 5
  range_split_addr6 = { "BA 64 0B 00 00 EB 25 BA" },  -- (0x436AB9)  -- patch size should be 5
  range_split_addr7 = { "BD 39 1C 00 00 EB 7D BD" },  -- (0x435985)  -- patch size should be 5
  range_split_addr8 = { "BE 39 1C 00 00 E9 7D 00 00 00 BE" },  -- (0x436361)  -- patch size should be 5
  range_split_addr9 = { "B8 39 1C 00 00 EB 09 B8" },  -- (0x4369CE)  -- patch size should be 5
  range_split_addr10 = { "BA 39 1C 00 00 EB 09 BA" },  -- (0x436AD5)  -- patch size should be 5
  range_split_addr11 = { "83 E9 03 F7 D9 1B C9" },  -- (0x53D642)1 -- patch size should be 13
  range_split_addr12 = { "03 D1 83 FA 79 7E" },  -- (0x57770C)2 -- patch size should be 5

  scan_range_addr_archer = { "66 81 B8 ? ? ? ? 90 01 7F" },
  scan_range_addr_arabbow_1 = { "85 FF BD 90 01 00 00 7E 28 8B C3" },
  scan_range_addr_arabbow_2 = { "66 00 BD 90 01 00 00 66 39 AE ? ? ? ? 7C 27" },
  scan_range_addr_horse_archer = { "69 D2 90 04 00 00 66 81 BA ? ? ? ? B0 01" },
  scan_range_addr_xbow = { "0F B7 88 ? ? ? ? 66 81 F9 90 01", after = "scan_range_addr_archer", skip = 500 },
  scan_range_addr_xbow_2 = { "66 C7 86 ? ? ? ? 0A 00 66 81 BE ? ? ? ? 90 01" },
  scan_range_addr_slinger_1 = { "0F B7 88 ? ? ? ? 66 81 F9 90 01", after = "scan_range_addr_xbow", skip = 500 },
  scan_range_addr_slinger_2 = { "03 F9 81 FF E4 01 00 00 7E 17 C7 86 ? ? ? ? D8 FF FF FF" },
  scan_range_addr_slinger_3 = { "89 8E ? ? ? ? 66 C7 86 ? ? ? ? 66 00 BD 90 01 00 00" },
  scan_range_addr_firethrower_1 = { "0F B7 88 ? ? ? ? 66 81 F9 90 01", after = "scan_range_addr_slinger_1", skip = 500 },
  scan_range_addr_fbal_1 = { "66 C7 86 ? ? ? ? 03 00 66 81 BE ? ? ? ? A8 02" },
  scan_range_addr_fbal_2 = { "0F AF FA 03 DF 81 FB 64 0B" },
  scan_range_addr_mango = { "0F 85 E0 00 00 00 66 81 BE ? ? ? ? A8 02" },
  scan_range_addr_towerbal_1 = { "C3 5F 5E 5D C7 81 ? ? ? ? D8 FF FF FF 5B 83 C4 10 C3 66 81 BE ? ? ? ? A8 02", offset = 18 },
  scan_range_addr_towerbal_2 = { "C3 66 81 BE ? ? ? ? A8 02", after = "scan_range_addr_towerbal_1", skip = 250 },

  -- rally running addresses
  arabbow_rally_running_addr = { "66 89 AE ? ? ? ? 66 8B 8E ? ? ? ?" },
  slinger_rally_running_addr = { "66 89 86 ? ? ? ? 66 8B 96 ? ? ? ? 53 B9 ? ? ? ? 66 89 96 ? ? ? ? E8 ? ? ? ? 85 C0 0F 84 ? ? ? ? A1 ? ? ? ? 03 C3 99 B9 28 00 00 00 F7 F9 66 C7 86 ? ? ? ? 04 00 85 D2 75 74 66 81 BE ? ? ? ? B0" },
  assassin_rally_running_addr = { "66 89 86 ? ? ? ? 89 86 ? ? ? ? C7 86 ? ? ? ? 10 00 00 00 66 8B 96 ? ? ? ?" },
  firethrower_rally_running_addr = { "66 89 86 ? ? ? ? 66 8B 96 ? ? ? ? 53 B9 ? ? ? ? 66 89 96 ? ? ? ? E8", after = "assassin_rally_running_addr" },

  -- half siege ammo addresses
  siege_initial_ammo_addr = { "74 0E 66 C7 86 76 09 00 00 14 00", offset = 9 },
  reload_amount_addr = { "66 83 80 ? ? ? ? 14 8D 80 ? ? ? ? C3" },
  multi_reload_func_addr = { "0F BF 8E ? ? ? ? BF 14 00 00 00 2B F9 85 FF" },

  -- double iron pickup addresses
  iron_wait_addr = { "33 C9 39 88 ? ? ? ? 0F 94 C1 8D 4C 09 03" },
  iron_subtract_addr = { "FF 6A ? 8D 80 ? ? ? ? 6A ? 51 E8" },

  -- extreme-only settings
  height_advantage_addr = { "66 83 FB 14 75 0B 8B C1", offset = 4 },
  enemy_check_addr = { "83 BC 30 50 0A 00 00 00 8D 3C 30 74 6A 8B 87 50 0A 00 00", offset = 13 },
  minimap_unit_size_addr = { "7D 76 8B 5D 24 8B 55 E0 2B D8 83 EB 01 D1 EB 8D 34 02 83 C3 01", offset = 20 },
  flagon_cap_addr = { "5B C3 66 3D 90 01 0F 8D", offset = 4 },
  spearmen_run_addr = { "7E 3C 66 C7 86 ? ? ? ? FF FF 89 BE ? ? ? ? EB 32 66 39 BE ? ? ? ? 75 1C 66 39 BE ? ? ? ?" .. string.rep(" ?", 21) .. " 89 86 ? ? ? ? 66 89 BE ? ? ? ?" },  -- jle, and the run state at +56
}

-- Site addresses and the code this module inserts. Sites are found at load, before any module
-- writes, so a repeated or overlapping AOB gives the intended match. False: the site is not usable,
-- for the reason in `unusable`.
local at, unusable, matched = {}, {}, {}

local function find(name)
  if at[name] ~= nil then
    return at[name]
  end
  local site = SITES[name]
  local address
  if site.from ~= nil then
    local base = find(site.from)
    address = base and base + (site.offset or 0)
  elseif site.after == nil or find(site.after) then
    local start = site.after and at[site.after] + (site.skip or 0)
    local ok, result = pcall(core.AOBScan, site[1], start)
    matched[name] = ok and result
    address = ok and result and result + (site.offset or 0)
  end
  if address and site.read then
    address = core.readInteger(address) + site.read
  end
  at[name] = address or false
  if not address then
    unusable[name] = "not found"
  end
  return at[name]
end

for name in pairs(SITES) do
  find(name)
end

-- Drops the sites whose bytes another module changed after load. Runs once, before this module's
-- first write.
local checked = false
local function check_sites()
  if checked then
    return
  end
  checked = true
  for name, site in pairs(SITES) do
    local start = at[name] and matched[name]
    if start and core.scanForAOB(site[1], start) ~= start then
      at[name], unusable[name] = false, "changed by another module"
    end
  end
  for name, site in pairs(SITES) do
    if site.from ~= nil and at[name] and not at[site.from] then
      at[name], unusable[name] = false, unusable[site.from]
    end
  end
end

-- True if all named sites are usable; logs each unusable site once.
local function need(...)
  for _, name in ipairs({ ... }) do
    if not at[name] then
      if unusable[name] then
        log(WARNING, string.format("%s %s, the settings that change it are not applied", name, unusable[name]))
        unusable[name] = nil
      end
      return false
    end
  end
  return true
end

-- local scaling_code = templates.continuous_scaling_code
local scaling_code = templates.discrete_scaling_code

local archer_idx = table.find(unit_names, "European archer")
local arabbow_idx = table.find(unit_names, "Arabian archer")

local ballista_damage_table_addr = 0 -- defined when allocated.
local mangonel_damage_table_addr = 0 -- defined when allocated.
local catapult_damage_table_addr = 0 -- defined when allocated.
local trebuchet_damage_table_addr = 0 -- defined when allocated.
local tax_table_addr = 0 -- defined when allocated
local fire_damage_table_addr = 0 -- defined when allocated

local unit_melee_damage_offset_map = {}
unit_melee_damage_offset_map["Tunneler"] =             {site = "tunneller_building_melee_addr",   building = 9,  fortification = 6,                wall = -53}
unit_melee_damage_offset_map["European archer"] =      {site = "archer_building_melee_addr",      building = 9,  fortification = 6,                wall = -53}
unit_melee_damage_offset_map["European crossbowman"] = {site = "crossbow_building_melee_addr",    building = 4,  fortification = 2,                wall = -62}
unit_melee_damage_offset_map["European spearman"] =    {site = "spearman_building_melee_addr",    building = 9,  fortification = 6,                wall = -36}
unit_melee_damage_offset_map["European pikeman"] =     {site = "pikeman_building_melee_addr",     building = 9,  fortification = 6,                wall = -55}
unit_melee_damage_offset_map["European maceman"] =     {site = "maceman_building_melee_addr",     building = 9,  fortification = 6,                wall = -46}
unit_melee_damage_offset_map["European swordsman"] =   {site = "swordsman_building_melee_addr",   building = 9,  fortification = 6,                wall = -55}
unit_melee_damage_offset_map["European knight"] =      {site = "knight_building_melee_addr",      building = 9,  fortification = 6,                wall = -55}
unit_melee_damage_offset_map["Monk"] =                 {site = "monk_building_melee_addr",        building = 9,  fortification = 6,                wall = -52}
unit_melee_damage_offset_map["Lord"] =                 {site = "lord_building_melee_addr",        building = 9,  fortification = 6,                wall = -66}
unit_melee_damage_offset_map["Battering ram"] =        {site = "ram_damage_addr",                 building = 2,  fortification = "Not supported.", wall = "Not supported."}
unit_melee_damage_offset_map["Arabian archer"] =       {site = "arabbow_building_melee_addr",     building = 9,  fortification = 6,                wall = -44}
unit_melee_damage_offset_map["Arabian slave"] =        {site = "slave_building_melee_addr",       building = 14, fortification = "Not supported.", wall = "Not supported."}
unit_melee_damage_offset_map["Arabian slinger"] =      {site = "slinger_building_melee_addr",     building = 9,  fortification = 6,                wall = -53}
unit_melee_damage_offset_map["Arabian assassin"] =     {site = "assassin_building_melee_addr",    building = 9,  fortification = 6,                wall = -52}
unit_melee_damage_offset_map["Arabian horse archer"] = {site = "horsearcher_building_melee_addr", building = 9,  fortification = 6,                wall = -55}
unit_melee_damage_offset_map["Arabian swordsman"] =    {site = "arabsword_building_melee_addr",   building = 9,  fortification = 6,                wall = -55}
unit_melee_damage_offset_map["Arabian firethrower"] =  {site = "firethrower_building_melee_addr", building = 9,  fortification = 6,                wall = -53}

local resource_production_offset_map = {}
resource_production_offset_map["Wood"] =    {site = "woodcutter_func",             baseDelivery = 10,               skirmishBonus = 1}
resource_production_offset_map["Stone"] =   {site = "quarry_grunt_func",           baseDelivery = 3,                skirmishBonus = 1}
resource_production_offset_map["Iron"] =    {site = "ironminer_func",              baseDelivery = 9,                skirmishBonus = 1}
resource_production_offset_map["Pitch"] =   {site = "pitchman_func",               baseDelivery = 10,               skirmishBonus = 1}
resource_production_offset_map["Meat"] =    {site = "hunter_func",                 baseDelivery = 10,               skirmishBonus = 1}
resource_production_offset_map["Fruit"] =   {site = "apple_farmer_func",           baseDelivery = 3,                skirmishBonus = 1}
resource_production_offset_map["Cheese"] =  {site = "dairy_farmer_func",           baseDelivery = 10,               skirmishBonus = 1}
resource_production_offset_map["Hop"] =     {site = "hops_farmer_func",            baseDelivery = 5,                skirmishBonus = 1}
resource_production_offset_map["Bread"] =   {site = "baker_func",                  baseDelivery = 9,                skirmishBonus = 7}
resource_production_offset_map["Wheat"] =   {site = "wheatfarmer_func",            baseDelivery = 9,                skirmishBonus = 7}
resource_production_offset_map["Flour"] =   {                                      baseDelivery = "Not supported.", skirmishBonus = "Not supported."}
resource_production_offset_map["Beer"] =    {site = "brewer_func",                 baseDelivery = 8,                skirmishBonus = 6}
resource_production_offset_map["Bow"] =     {site = "custom_fletcher_code_addr",   baseDelivery = 36,               skirmishBonus = 34}
resource_production_offset_map["Xbow"] =    {site = "custom_fletcher_code_addr",   baseDelivery = 42,               skirmishBonus = 40}
resource_production_offset_map["Spear"] =   {site = "custom_poleturner_code_addr", baseDelivery = 38,               skirmishBonus = 36}
resource_production_offset_map["Pike"] =    {site = "custom_poleturner_code_addr", baseDelivery = 44,               skirmishBonus = 42}
resource_production_offset_map["Mace"] =    {site = "custom_blacksmith_code_addr", baseDelivery = 36,               skirmishBonus = 34}
resource_production_offset_map["Sword"] =   {site = "custom_blacksmith_code_addr", baseDelivery = 42,               skirmishBonus = 40}
resource_production_offset_map["Leather"] = {site = "tanner_func",                 baseDelivery = 8,                skirmishBonus = 6}
resource_production_offset_map["Armor"] =   {site = "armourer_func",               baseDelivery = 8,                skirmishBonus = 6}

local function extreme_only_feature_check(warning_message)
  if data.version.isExtreme() then
    return true
  end
  log(WARNING, warning_message)
  return false
end

local function reduce_height_advantage()
  if need("height_advantage_addr") then
    core.writeCodeSmallInteger(at.height_advantage_addr, 37008) -- Highground damage reduction for all units to 50%. {0x90, 0x90}
  end
end

local function increase_enemy_check_frequency()
  if need("enemy_check_addr") then
    -- Custom unit to closest enemy distance update rate cap (Set in gameticks, picked at random from 0 to this number, applies to all units
    core.writeCode(at.enemy_check_addr, {0xB8, core.itob(20), 0x90})
  end
end

local function increase_minimap_unit_size()
  if need("minimap_unit_size_addr") then
    core.writeCodeByte(at.minimap_unit_size_addr, 4) -- "Minimap unit size.",
  end
end

local function enable_spearmen_conditional_run()
  if not need("spearmen_run_addr", "unit_array_base") then
    return
  end
  core.writeCodeBytes(at.spearmen_run_addr, {0x7E, 0x36})
  core.insertCode(at.spearmen_run_addr + 56, 13, {
    0x66, 0x81, 0xBE, core.itob(at.unit_array_base + 0x2A6), 0xF0, 0x00,  -- Spearman running trigger range around enemy units * 8.
    0x7F, 0x16,
    0xC7, 0x86, core.itob(at.unit_array_base + 0x8), 0x81, 0x00, 0x00, 0x00,
    0x66, 0x89, 0x86, core.itob(at.unit_array_base + 0x2BE),
    core.jmpTo(at.spearmen_run_addr + 69),
  }, nil, "after")
end

local function enable_rebalance_features()
  check_sites()
  if not need("crossbow_building_melee_addr", "baker_func", "wheatfarmer_func", "brewer_func", "fletcher_func",
      "poleturner_func", "blacksmith_func", "tanner_func", "armourer_func", "tax_addr", "bribe_addr",
      "ballista_damage_addr", "mangonel_damage_addr", "non_rax_unit_display_cost_func_addr",
      "non_rax_unit_cost_func_addr", "ar_unit_gold_cost_base", "fire_damage_code_addr", "towers_or_gates_base",
      "unit_array_base", "building_array_base", "unit_gold_jumplist_addr") then
    return false
  end
  ballista_damage_table_addr = core.allocate(#unit_names*4)
  mangonel_damage_table_addr = core.allocate(#unit_names*4)
  catapult_damage_table_addr = core.allocate(#unit_names*4)
  trebuchet_damage_table_addr = core.allocate(#unit_names*4)
  fire_damage_table_addr = core.allocate(#unit_names*4)

  for index, name in ipairs(unit_names) do
    if name == "Lord" then
      core.writeInteger(fire_damage_table_addr + 4*index, 25)
    elseif name == "Fireman" then
      core.writeInteger(fire_damage_table_addr + 4*index, 1)
    elseif name == "Arabian firethrower" then
      core.writeInteger(fire_damage_table_addr + 4*index, 10)
    else
      core.writeInteger(fire_damage_table_addr + 4*index, 100)
    end
  end

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

   -- enable fully changing melee damage of xbows to buildings
  core.writeCodeBytes(at.crossbow_building_melee_addr-12, core.compile({ 
    0x8B, 0x04, 0x95, core.itob(at.towers_or_gates_base), -- mov eax,[edx*4+005B9980]
    0x3C, 0x01,                                        -- cmp al,01
    0x75, 0x04,                                        -- jne 0055CE06
    0x31, 0xC0,                                        -- xor eax,eax
    0x2C, 0x02,                                        -- sub al,02
    0x04, 0x04,                                        -- add al,04
    0x90                                               -- nop 
  }, at.crossbow_building_melee_addr-12)
  )

  -- enable skirmish bonus&delivery modification for bakers
  core.writeCodeByte(at.baker_func, 0x90)
  core.insertCode(at.baker_func, 8, {}, at.baker_func+6, "after")
  core.writeCodeBytes(at.baker_func+6, {0x6A, 0x00})

  -- enable skirmish bonus&delivery modification for wheat farmers
  core.writeCodeByte(at.wheatfarmer_func, 0x90)
  core.insertCode(at.wheatfarmer_func, 8, {}, at.wheatfarmer_func+6, "after")
  core.writeCodeBytes(at.wheatfarmer_func+6, {0x6A, 0x00})

  -- enable skirmish bonus&delivery modification for brewers
  core.writeCodeByte(at.brewer_func, 0x90)
  core.writeCodeByte(at.brewer_func+8, 0x90)
  core.insertCode(at.brewer_func, 9, {}, at.brewer_func+5, "after")
  core.writeCodeBytes(at.brewer_func+5, {0x6A, 0x01, 0x6A, 0x01})

  -- enable skirmish bonus&delivery modification for bows/xbows
  local custom_fletcher_code = {
    0x50,                                       -- push eax
    0x69, 0xC0, 0x90, 0x04, 0x00, 0x00,         -- imul eax,eax,00000490
    0x0F, 0xBF, 0x80, core.itob(at.unit_array_base+0x338),   -- movsx eax,word ptr [eax+0145D374]
    0x69, 0xC0, 0x2C, 0x03, 0x00, 0x00,         -- imul eax,eax,0000032C
    0x0F, 0xBF, 0x80, core.itob(at.building_array_base+0x28E),   -- movsx eax,word ptr [eax+00F98C42]
    0x83, 0xF8, 0x11,                           -- cmp eax, 11
    0x58,                                       -- pop eax
    0x75, 0x06,                                 -- jne 6bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
    0xEB, 0x04,                                 -- jmp 4bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
  }

  core.writeCodeBytes(at.fletcher_func, {0x90, 0x90})
  at.custom_fletcher_code_addr = core.insertCode(at.fletcher_func, 9, custom_fletcher_code, at.fletcher_func+9, "after")

  -- enable skirmish bonus&delivery modification for spears/pikes
  local custom_poleturner_code = {
    0x50,                                       -- push eax
    0x8B, 0xC7,                                 -- mov eax, edi
    0x69, 0xC0, 0x90, 0x04, 0x00, 0x00,         -- imul eax,eax,00000490
    0x0F, 0xBF, 0x80, core.itob(at.unit_array_base+0x338),   -- movsx eax,word ptr [eax+0145D374]
    0x69, 0xC0, 0x2C, 0x03, 0x00, 0x00,         -- imul eax,eax,0000032C
    0x0F, 0xBF, 0x80, core.itob(at.building_array_base+0x28E),   -- movsx eax,word ptr [eax+00F98C42]
    0x83, 0xF8, 0x13,                           -- cmp eax, 13
    0x58,                                       -- pop eax
    0x75, 0x06,                                 -- jne 6bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
    0xEB, 0x04,                                 -- jmp 4bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
  }
  core.writeCodeByte(at.poleturner_func, 0x90)
  core.writeCodeByte(at.poleturner_func+8, 0x90)
  at.custom_poleturner_code_addr = core.insertCode(at.poleturner_func, 9, custom_poleturner_code, at.poleturner_func+9, "after")

  -- enable skirmish bonus&delivery modification for maces/swords
  local custom_blacksmith_code = {
    0x50,                                       -- push eax
    0x69, 0xC0, 0x90, 0x04, 0x00, 0x00,         -- imul eax,eax,00000490
    0x0F, 0xBF, 0x80, core.itob(at.unit_array_base+0x338),   -- movsx eax,word ptr [eax+0145D374]
    0x69, 0xC0, 0x2C, 0x03, 0x00, 0x00,         -- imul eax,eax,0000032C
    0x0F, 0xBF, 0x80, core.itob(at.building_array_base+0x28E),   -- movsx eax,word ptr [eax+00F98C42]
    0x83, 0xF8, 0x11,                           -- cmp eax, 15
    0x58,                                       -- pop eax
    0x75, 0x06,                                 -- jne 6bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
    0xEB, 0x04,                                 -- jmp 4bytes
    0x6A, 0x01,                                 -- push 01
    0x6A, 0x01,                                 -- push 01
  }

  core.writeCodeBytes(at.blacksmith_func, {0x90, 0x90})
  at.custom_blacksmith_code_addr = core.insertCode(at.blacksmith_func, 9, custom_blacksmith_code, at.blacksmith_func+9, "after")

  -- enable skirmish bonus&delivery modification for tanners
  core.writeCodeBytes(at.tanner_func, {0x90, 0x90, 0x90})
  core.insertCode(at.tanner_func, 10, {}, at.tanner_func+5, "after")
  core.writeCodeBytes(at.tanner_func+5, {0x6A, 0x01, 0x6A, 0x01, 0x50})

  -- enable skirmish bonus&delivery modification for armourers
  core.writeCodeByte(at.armourer_func, 0x90)
  core.writeCodeByte(at.armourer_func+8, 0x90)
  core.insertCode(at.armourer_func, 9, {}, at.armourer_func+5, "after")
  core.writeCodeBytes(at.armourer_func+5, {0x6A, 0x01, 0x6A, 0x01})

  -- enable custom taxation multipliers
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
    0xE8, core.itob(custom_tax_addr - at.tax_addr-5),  -- call 40459B
    0xE8, core.itob(divby10_addr - at.tax_addr-10),  -- call 4045F9
    0xEB, 0x02,  -- jump over 2 bytes
    0x90, 0x90,
    0xC1, 0xF8, 0x03,  -- sar eax,03
    0x83, 0x3D, 0xF0, 0x4D, 0x35, 0x02, 0x00 -- cmp dword ptr [Stronghold_Crusader_Extreme.exe+1F54DF0],00
  }

  local bribe_jumpout_instructions = {
    0xE8, core.itob(custom_tax_addr - at.bribe_addr-5),  -- call 40459B
    0xE8, core.itob(divby10_addr - at.bribe_addr-10),  -- call 4045F9
    0x90,
    0xC1, 0xF8, 0x02  -- sar eax,02
  }

  core.writeCodeBytes(at.tax_addr, core.compile(tax_jumpout_instructions, at.tax_addr))
  core.writeCodeBytes(at.bribe_addr, core.compile(bribe_jumpout_instructions, at.bribe_addr))
  core.writeCodeBytes(custom_tax_addr, core.compile(custom_tax_instructions, custom_tax_addr))
  local default_tax_table = {"1.0", "0.8", "0.6", "0.0", "0.6", "0.8", "1.0", "1.2", "1.4", "1.6", "1.8", "2.0"}
  for idx, tax_val in ipairs(default_tax_table) do
    core.writeCodeSmallInteger(tax_table_addr+2*(idx-1), math.floor(tax_val*100))
  end

  -- enable per-unit damage definition for ballistas, catapults and trebuchets
  core.writeCodeBytes(at.ballista_damage_addr-14,
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
    }, at.ballista_damage_addr-14)
  )

  for i=57,124 do core.writeCodeByte(at.ballista_damage_addr+i, 0x90) end -- nop out remaining bytes

  -- enable per-unit damage definition for mangonels
  core.writeCodeBytes(at.mangonel_damage_addr,
    core.compile({
      0x49, -- sub ecx
      0x8B, 0x0C, 0x8D, core.itob(mangonel_damage_table_addr), 0x90, -- mov ecx, [ecx*4+ballista_damage_table_addr]  -- clear the nops later.
      0xE9, core.itob(339)  -- jmp 339 bytes forward
    }, at.mangonel_damage_addr)
  )
  for i=14,153,5 do core.writeCodeBytes(at.mangonel_damage_addr+i, {0xBB, 0,0,0,0}) end -- fill 140 bytes with trash

  -- enable unit display costs&actual costs to be read from same place
  core.writeCodeBytes(at.non_rax_unit_display_cost_func_addr+14,{
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
  core.writeCodeBytes(at.unit_gold_jumplist_addr, core.compile({
      core.itob(at.non_rax_unit_display_cost_func_addr + 14),
      core.itob(at.non_rax_unit_display_cost_func_addr + 18),
      core.itob(at.non_rax_unit_display_cost_func_addr + 22),
      core.itob(at.non_rax_unit_display_cost_func_addr + 26),
    },at.unit_gold_jumplist_addr)
  )

  core.writeCodeByte(at.non_rax_unit_cost_func_addr+6, 70)  -- compare unit id with arab bow

  core.writeCodeBytes(at.non_rax_unit_cost_func_addr+18, core.compile({
      0x7C, 0x10,
      0x50,
      0x83, 0xE8, 0x46,
      0xC1, 0xE0, 0x02,
      0x8B, 0xA8, core.itob(at.ar_unit_gold_cost_base),
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
    }, at.non_rax_unit_cost_func_addr+18
  ))

  core.writeCodeBytes(at.fire_damage_code_addr, core.compile({
    0x8B, 0x04, 0xBD, core.itob(fire_damage_table_addr),  -- mov ax,[edi*4+fire_damage_table_addr]
    0xBD, 0x01, 0x00, 0x00, 0x00,                         -- mov ebp,00000001
    0xEB, 0x25                                            -- jmp +24
  }, at.fire_damage_code_addr)
  )
  return true
end

local function edit_buildings(buildings)
  local address = 0
  for building, stats in pairs(buildings) do
    local cost = stats["cost"]
    local health = stats["health"]
    local housing = stats["housing"]
    local building_idx = table.find(building_names, building)-1
    if cost ~= nil and need("building_cost_base") then
      address = at.building_cost_base + 20 * building_idx
      core.writeInteger(address, cost[1])
      core.writeInteger(address+4, cost[2])
      core.writeInteger(address+8, cost[3])
      core.writeInteger(address+12, cost[4])
      core.writeInteger(address+16, cost[5])
    end

    if health ~= nil and need("building_health_base") then
      address = at.building_health_base + 4 * building_idx
      core.writeInteger(address, health)
    end

    if housing ~= nil and need("building_population_base") then
      address = at.building_population_base + 4 * building_idx
      core.writeInteger(address, housing)
    end
  end
end

local function edit_siege(siege)
  local default_ballista_damage = 10000
  local default_mangonel_damage = 30000
  local default_catapult_damage = 30000
  local default_trebuchet_damage = 30000
  if siege["catapultRockDamage"] ~= nil and need("cat_primary_addr") then core.writeCodeInteger(at.cat_primary_addr, siege["catapultRockDamage"]) end
  if siege["catapultRockCollateralDamage"] ~= nil and need("cat_collateral_addr") then core.writeCodeInteger(at.cat_collateral_addr, siege["catapultRockCollateralDamage"]) end
  if siege["trebuchetRockDamage"] ~= nil and need("treb_primary_addr") then core.writeCodeInteger(at.treb_primary_addr, siege["trebuchetRockDamage"]) end
  if siege["trebuchetRockCollateralPenalty"] ~= nil and need("treb_collateral_penalty_addr") then core.writeCodeByte(at.treb_collateral_penalty_addr, siege["trebuchetRockCollateralPenalty"]) end
  if siege["mangonelPebbleDamage"] ~= nil and need("mango_primary_addr") then core.writeCodeInteger(at.mango_primary_addr, siege["mangonelPebbleDamage"]) end
  if siege["defaultMangonelPebbleUnitDamage"] ~= nil then default_mangonel_damage = siege["defaultMangonelPebbleUnitDamage"] end
  if siege["defaultCatapultRockUnitDamage"] ~= nil then default_catapult_damage = siege["defaultCatapultRockUnitDamage"] end
  if siege["defaultTrebuchetRockUnitDamage"] ~= nil then default_trebuchet_damage = siege["defaultTrebuchetRockUnitDamage"] end
  if siege["defaultBallistaBoltUnitDamage"] ~= nil then default_ballista_damage = siege["defaultBallistaBoltUnitDamage"] end
  if siege["siegeProjectileOneShotThreshold"] ~= nil and need("oneshot_threshold_addr") then core.writeCodeInteger(at.oneshot_threshold_addr+2, siege["siegeProjectileOneShotThreshold"]) end
  if siege["enable_half_siege_ammo"] ~= nil and siege["enable_half_siege_ammo"] == true
      and need("siege_initial_ammo_addr", "reload_amount_addr", "multi_reload_func_addr") then
    core.writeCodeSmallInteger(at.siege_initial_ammo_addr, 10) -- "Catapult/Trebuchet initial stone.",     
    core.writeCodeByte(at.reload_amount_addr+7, 10) -- "Catapult stone reload amount.",             
    core.writeCodeByte(at.multi_reload_func_addr+8, 10) -- "Default max. ammunition amount.",             
    core.writeCodeByte(at.multi_reload_func_addr+20, 0) -- "Rounding extra stone cost.",       
    core.writeCodeBytes(at.multi_reload_func_addr+32, {0x90, 0x90})  -- "Shift left to divide instruction.",  nop-out
    core.writeCodeBytes(at.multi_reload_func_addr+121, {0x89, 0xC6, 0x90})
  end

  for index, name in ipairs(unit_names) do
    if name == "Lord"
    or name == "Catapult"
    or name == "Trebuchet"
    or name == "Mangonel"
    or name == "Siege tower"
    or name == "Battering ram"
    or name == "Portable shield"
    or name == "Tower ballista"
    or name == "Fire ballista" then  -- defaults are set once
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

local function edit_castle(castle)
  local ditch_per_pitch = castle["ditch_per_pitch"]
  local killing_pit_damage = castle["killing_pit_damage"]
  local dog_trigger_threshold = castle["dog_trigger_threshold"]
  local fire_damage = castle["fire_damage"]

  if ditch_per_pitch ~= nil and need("pitch_ditch_costaddr") then
    if ditch_per_pitch == 1 then -- 0
      core.writeCodeSmallInteger(at.pitch_ditch_costaddr, 0)
    elseif ditch_per_pitch == 2 then -- 3
      core.writeCodeSmallInteger(at.pitch_ditch_costaddr, 3)
    elseif ditch_per_pitch == 3 then -- 2
      core.writeCodeSmallInteger(at.pitch_ditch_costaddr, 2)
    elseif ditch_per_pitch == 4 then -- 1
      core.writeCodeSmallInteger(at.pitch_ditch_costaddr, 1)
    else
      log(WARNING, "Ditch per pitch can only be a value from 1 to 4.")
    end
  end

  if killing_pit_damage ~= nil and need("killing_pit_dmg_addr") then
    if killing_pit_damage > 0 then  -- force negative value
      killing_pit_damage = -killing_pit_damage
    end
    core.writeCodeInteger(at.killing_pit_dmg_addr, killing_pit_damage)
  end

  if dog_trigger_threshold ~= nil and need("dog_threshold_addr") then
    core.writeCodeByte(at.dog_threshold_addr, dog_trigger_threshold)
  end

  if fire_damage ~= nil then
    for index, name in ipairs(unit_names) do
      if name == "Lord"
      or name == "Fireman"
      or name == "Arabian firethrower" then -- defaults are set once
      else
        core.writeInteger(fire_damage_table_addr + 4*index, fire_damage)
      end
    end
  end
end

local function edit_units(units)
  local function get_unit_melee_dmg_address(attacker, defender)
    local attacker_idx = table.find(unit_names, attacker) - 1
    local defender_idx = table.find(unit_names, defender) - 1
    return at.unit_melee_dmg_base + defender_idx * 4 + attacker_idx * 16 + attacker_idx * (#unit_names - 1) * 4
  end
  local address = 0
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
    local fortificationDamage = stats["fortificationDamage"]
    local wallDamage = stats["wallDamage"]
    local powerLevel = stats["powerLevel"]
    local meleeEngage = stats["meleeEngage"]
    local notBlessable = stats["notBlessable"]
    local meleeImmunity = stats["meleeImmunity"]
    local allowedOnWalls = stats["allowedOnWalls"]
    local fireDamage = stats["fireDamage"]
    local jesterUnfriendly = stats["jesterUnfriendly"]

    local goldCost = stats["goldCost"]
    local speedLevel = stats["speedLevel"]
    local unit_military_idx = table.find(military_ground_unit_names, unit)
    local unit_idx_p1 = table.find(unit_names, unit)
    local unit_idx = unit_idx_p1-1

    if health ~= nil and need("unit_health_base") then core.writeInteger(at.unit_health_base + unit_idx * 4, health) end
    if arrowDamage ~= nil and need("unit_arrow_dmg_base") then core.writeInteger(at.unit_arrow_dmg_base + unit_idx * 4, arrowDamage) end
    if xbowDamage ~= nil and need("unit_xbow_dmg_base") then core.writeInteger(at.unit_xbow_dmg_base + unit_idx * 4, xbowDamage) end
    if stoneDamage ~= nil and need("unit_stone_dmg_base") then core.writeInteger(at.unit_stone_dmg_base + unit_idx * 4, stoneDamage) end
    if meleeEngage ~= nil and need("unit_melee_toggles_base") then core.writeInteger(at.unit_melee_toggles_base + 4*unit_idx, meleeEngage and 1 or 0) end
    if notBlessable ~= nil and need("unit_blessable_base") then core.writeInteger(at.unit_blessable_base + 4*unit_idx, notBlessable and 1 or 0) end
    if allowedOnWalls ~= nil and need("unit_allowed_on_walls_base") then core.writeInteger(at.unit_allowed_on_walls_base + 4*unit_idx, allowedOnWalls and 1 or 0) end
    if fireDamage ~= nil then core.writeInteger(fire_damage_table_addr + 4*unit_idx_p1, fireDamage) end
    if jesterUnfriendly ~= nil and need("unit_jester_unfriendly_base") then core.writeInteger(at.unit_jester_unfriendly_base + 4*unit_idx, jesterUnfriendly and 1 or 0) end
    if meleeImmunity ~= nil and need("unit_melee_immunity_base") then core.writeInteger(at.unit_melee_immunity_base + 4*unit_idx, meleeImmunity and 1 or 0) end
    if ballistaBoltDamage ~= nil then core.writeInteger(ballista_damage_table_addr + 4*unit_idx, ballistaBoltDamage) end
    if mangonelDamage ~= nil then core.writeInteger(mangonel_damage_table_addr + 4*unit_idx, mangonelDamage) end
    if catapultRockDamage ~= nil then core.writeInteger(catapult_damage_table_addr + 4*unit_idx, catapultRockDamage) end
    if trebuchetRockDamage ~= nil then core.writeInteger(trebuchet_damage_table_addr + 4*unit_idx, trebuchetRockDamage) end
    if speedLevel ~= nil and need("unit_speed_base") then core.writeInteger(at.unit_speed_base + unit_idx*4, speedLevel) end

    if baseMeleeDamage ~= nil and need("unit_melee_dmg_base") then
      for _, defender in ipairs(unit_names) do
        address = get_unit_melee_dmg_address(unit, defender)
        core.writeInteger(address, baseMeleeDamage)
      end
    end

    if meleeDamageVs ~= nil and need("unit_melee_dmg_base") then
      for defender, damage in pairs(meleeDamageVs) do
        address = get_unit_melee_dmg_address(unit, defender)
        core.writeInteger(address, damage)
      end
    end

    if powerLevel ~= nil then
      if unit_military_idx ~= nil and need("unit_power_levels_addr") then
        core.writeInteger(at.unit_power_levels_addr + 4*(unit_military_idx-1), powerLevel)
      end
    end

    if goldCost ~= nil then
      local is_arab_unit = unit_idx_p1 >= arabbow_idx and unit_idx_p1 <= table.find(unit_names, "Arabian firethrower")
      local is_other_trainable_unit = unit_idx_p1 == 5 or unit_idx_p1 == 29 or unit_idx_p1 == 30 or unit_idx_p1 == 37
      -- other trainable units are tunneller, laddermen, engineer or monk
      if unit_idx_p1 >= archer_idx and unit_idx_p1 <= table.find(unit_names, "European knight")
        and need("eu_unit_gold_cost_base") then
        local eu_unit_idx = unit_idx_p1 - archer_idx
        address = at.eu_unit_gold_cost_base + 4 * eu_unit_idx
        core.writeInteger(address, goldCost)
      end
      if is_arab_unit then
        local ar_unit_idx = unit_idx_p1 - arabbow_idx
        address = at.ar_unit_gold_cost_base + 4*ar_unit_idx
        core.writeInteger(address, goldCost)
      end  -- arab unit display cost

      if is_other_trainable_unit then
        if unit_idx_p1 == 30 then -- engineer cost
          core.writeCodeByte(at.non_rax_unit_display_cost_func_addr + 15, goldCost)
          core.writeCodeInteger(at.non_rax_unit_cost_func_addr+42, goldCost)
        elseif unit_idx_p1 == 29 then -- laddermen cost
          core.writeCodeByte(at.non_rax_unit_display_cost_func_addr + 19, goldCost)
          core.writeCodeInteger(at.non_rax_unit_cost_func_addr+54, goldCost)
        elseif unit_idx_p1 == 5 then -- tunnellor cost
          core.writeCodeByte(at.non_rax_unit_display_cost_func_addr + 23, goldCost)
          core.writeCodeInteger(at.non_rax_unit_cost_func_addr+66, goldCost)
        else -- monk cost (37)
          core.writeCodeByte(at.non_rax_unit_display_cost_func_addr + 27, goldCost)
          core.writeCodeInteger(at.non_rax_unit_cost_func_addr+78, goldCost)
        end
      end  -- other unit display cost

    end

    local melee = unit_melee_damage_offset_map[unit]
    if buildingDamage ~= nil and need(melee.site) then core.writeCodeByte(at[melee.site] + melee.building, buildingDamage) end

    if fortificationDamagePenalty ~= nil then
      log(ERROR, string.format("[%s] fortificationDamagePenalty is removed, update your config to use fortificationDamage instead.", unit))
    end

    if fortificationDamage ~= nil then
      if melee.fortification == "Not supported." then
        log(WARNING, string.format("[%s] fortificationDamage is not supported.", unit))
      elseif need(melee.site) then
        address = at[melee.site] + melee.fortification
        local fdp = core.readByte(at[melee.site] + melee.building) - fortificationDamage
        if unit == "European crossbowman" then
          core.writeCodeByte(address, fdp)  -- special case.
        else
          core.writeCodeByte(address, -fdp)
        end
      end
    end

    if wallDamage ~= nil then
      if melee.wall == "Not supported." then
        log(WARNING, string.format("[%s] wallDamage is not supported.", unit))
      elseif need(melee.site) then
        core.writeCodeByte(at[melee.site] + melee.wall, wallDamage)
      end
    end

  end
end

local function edit_resources(resources)
  local address = 0
  for res_name, attrs in pairs(resources) do
    local buy = attrs["buy"]
    local sell = attrs["sell"]
    local baseDelivery = attrs["baseDelivery"]
    local skirmishBonus = attrs["skirmishBonus"]
    local res_index = table.find(resource_names, res_name)-1
    local production = resource_production_offset_map[res_name]
    if buy ~= nil and need("resource_buy_base") then
      address = at.resource_buy_base + 4 * res_index
      core.writeInteger(address, buy)
    end

    if sell ~= nil and need("resource_sell_base") then
      address = at.resource_sell_base + 4 * res_index
      core.writeInteger(address, sell)
    end

    if baseDelivery ~= nil then
      if production.baseDelivery == "Not supported." then
        log(WARNING, string.format("%s  production cannot be modified.", res_name))
      elseif need(production.site) then
        core.writeCodeByte(at[production.site] + production.baseDelivery, baseDelivery)
      end
    end

    if skirmishBonus ~= nil then
      local sb = skirmishBonus and 1 or 0
      if production.skirmishBonus == "Not supported." then
        log(WARNING, string.format("%s  production cannot be modified.", res_name))
      elseif need(production.site) then
        core.writeCodeByte(at[production.site] + production.skirmishBonus, sb)
      end
    end
  end
end

local function edit_population(population)
  local gathering_rate_skirmish = population["gathering_rate_skirmish"]
  local gathering_rate_scenario_small_town = population["gathering_rate_scenario_small_town"]
  local gathering_rate_scenario_large_town = population["gathering_rate_scenario_large_town"]
  local large_town_threshold = population["large_town_threshold"]
  local civilian_upkeep = population["civilian_upkeep"]
  local minimum_population = population["minimum_population"]
  local reset_population_threshold = population["reset_population_threshold"]
  local reset_popularity_threshold = population["reset_popularity_threshold"]
  local reset_popularity_value = population["reset_popularity_value"]
  local crowding = population["crowding"]

  if gathering_rate_skirmish ~= nil and need("skirmish_pgr_base") then
    for pgr_index, value in ipairs(gathering_rate_skirmish) do
      core.writeInteger(at.skirmish_pgr_base + 4 * (pgr_index-1), value)
    end
  end
  if gathering_rate_scenario_small_town ~= nil and need("scenario_pgr_base") then
    for pgr_index, value in ipairs(gathering_rate_scenario_small_town) do
      core.writeInteger(at.scenario_pgr_base + 4 * (pgr_index-1), value)
    end
  end
  if gathering_rate_scenario_large_town ~= nil and need("scenario_pgr_crowded_base") then
    for pgr_index, value in ipairs(gathering_rate_scenario_large_town) do
      core.writeInteger(at.scenario_pgr_crowded_base + 4 * (pgr_index-1), value)
    end
  end
  if civilian_upkeep ~= nil and need("pop_gathering_addr") then
    local slower_gathering = civilian_upkeep["slower_gathering"]
    local minimum_gathering = civilian_upkeep["minimum_gathering"]
    local faster_leaving = civilian_upkeep["faster_leaving"]
    if minimum_gathering == nil then
      minimum_gathering = 4
    end
    if slower_gathering < 1 then
      log(WARNING, "Upkeep values must be between 1 and 5")
      slower_gathering = 1
    end
    if slower_gathering > 5 then
      log(WARNING, "Upkeep values must be between 1 and 5")
      slower_gathering = 5
    end
    if faster_leaving < 1 then
      log(WARNING, "Upkeep values must be between 1 and 5")
      faster_leaving = 1
    end
    if faster_leaving > 5 then
      log(WARNING, "Upkeep values must be between 1 and 5")
      faster_leaving = 5
    end

    local upkeep_code_bytes = core.assemble([[
      push eax
      mov eax, [esi+0x2110]
      cmp ecx, 0
      jl label_0
      shr eax, gather_factor
      cmp eax, ecx
      jg label_2
      jmp label_1
          label_0:
      shr eax, leave_factor
          label_1:
      sub ecx, eax
      jmp end_label
          label_2:
      mov ecx, minimum_gather
          end_label:
      pop eax
    ]],{
      leave_factor = 7-faster_leaving,
      minimum_gather = minimum_gathering,
      gather_factor = 7-slower_gathering
    },0)
    core.insertCode(at.pop_gathering_addr, 7, upkeep_code_bytes, at.pop_gathering_addr+7, "before")
  end
  if minimum_population ~= nil and need("min_peasants_addr") then
    core.writeCodeByte(at.min_peasants_addr, minimum_population)
  end
  if reset_population_threshold ~= nil and need("pop_reset_population_limit_addr") then
    core.writeCodeByte(at.pop_reset_population_limit_addr, reset_population_threshold)
  end
  if reset_popularity_threshold ~= nil and need("pop_reset_popularity_limit_addr") then
    core.writeCodeInteger(at.pop_reset_popularity_limit_addr, reset_popularity_threshold)
  end
  if reset_popularity_value ~= nil and need("pop_reset_value_addr") then
    core.writeCodeInteger(at.pop_reset_value_addr, reset_popularity_value)
  end
  if large_town_threshold ~= nil and need("large_town_threshold_addr") then
    core.writeCodeByte(at.large_town_threshold_addr, large_town_threshold)
  end
  if crowding ~= nil and need("crowding_addr_1", "crowding_addr_2") then
    local thresholds = crowding["thresholds"]
    local penalties = crowding["penalties"]
    if thresholds ~= nil then
      core.writeCodeByte(at.crowding_addr_1+15, thresholds[1])
      core.writeCodeByte(at.crowding_addr_1+29, thresholds[2])
      core.writeCodeInteger(at.crowding_addr_1+45, thresholds[3])
      core.writeCodeInteger(at.crowding_addr_1+64, thresholds[4])
      core.writeCodeInteger(at.crowding_addr_1+67, thresholds[5])

      core.writeCodeByte(at.crowding_addr_2+15, thresholds[1])
      core.writeCodeByte(at.crowding_addr_2+29, thresholds[2])
      core.writeCodeInteger(at.crowding_addr_2+45, thresholds[3])
      core.writeCodeInteger(at.crowding_addr_2+64, thresholds[4])
      core.writeCodeInteger(at.crowding_addr_2+67, thresholds[5])
    end
    if penalties ~= nil then
      core.writeCodeInteger(at.crowding_addr_1+2, penalties[1])
      core.writeCodeInteger(at.crowding_addr_1+11, penalties[2])
      core.writeCodeInteger(at.crowding_addr_1+22, penalties[3])
      core.writeCodeByte(at.crowding_addr_1+36, penalties[4]-penalties[5])
      core.writeCodeInteger(at.crowding_addr_1+52, penalties[5])

      core.writeCodeInteger(at.crowding_addr_2+2, penalties[1])
      core.writeCodeInteger(at.crowding_addr_2+11, penalties[2])
      core.writeCodeInteger(at.crowding_addr_2+22, penalties[3])
      core.writeCodeByte(at.crowding_addr_2+36, penalties[4]-penalties[5])
      core.writeCodeInteger(at.crowding_addr_2+52, penalties[5])
    end
  end

end

local function edit_religion(religion)
  local religion_thresholds = religion["thresholds"]
  local religion_bonuses = religion["bonuses"]
  local religion_multipliers = religion["multipliers"]
  local church_bonus = religion["church_bonus"]
  local cathedral_bonus = religion["cathedral_bonus"]
  if religion_thresholds ~= nil and need("religion_addr_1", "religion_addr_2", "religion_addr_3") then
    core.writeCodeByte(at.religion_addr_1 + 2, religion_thresholds[1])
    core.writeCodeByte(at.religion_addr_1 + 11, religion_thresholds[2])
    core.writeCodeByte(at.religion_addr_1 + 23, religion_thresholds[3])
    core.writeCodeByte(at.religion_addr_1 + 37, religion_thresholds[4])

    core.writeCodeByte(at.religion_addr_2 + 2, religion_thresholds[1])
    core.writeCodeByte(at.religion_addr_2 + 11, religion_thresholds[2])
    core.writeCodeByte(at.religion_addr_2 + 23, religion_thresholds[3])
    core.writeCodeByte(at.religion_addr_2 + 37, religion_thresholds[4])

    core.writeCodeByte(at.religion_addr_2 + 100, religion_thresholds[1]-1)
    core.writeCodeByte(at.religion_addr_2 + 115, religion_thresholds[2]-1)
    core.writeCodeByte(at.religion_addr_2 + 130, religion_thresholds[3]-1)
    core.writeCodeByte(at.religion_addr_2 + 145, religion_thresholds[4]-1)

    core.writeCodeInteger(at.religion_addr_2 + 107, religion_thresholds[1])
    core.writeCodeInteger(at.religion_addr_2 + 122, religion_thresholds[2])
    core.writeCodeInteger(at.religion_addr_2 + 137, religion_thresholds[3])
    core.writeCodeInteger(at.religion_addr_2 + 152, religion_thresholds[4])

    core.writeCodeByte(at.religion_addr_3 + 2, religion_thresholds[1]-1)
    core.writeCodeByte(at.religion_addr_3 + 11, religion_thresholds[2]-1)
    core.writeCodeByte(at.religion_addr_3 + 23, religion_thresholds[3]-1)
    core.writeCodeByte(at.religion_addr_3 + 37, religion_thresholds[4]-1)
  end
  if religion_bonuses ~= nil and need("religion_addr_1", "religion_addr_2", "religion_addr_3") then
    core.writeCodeInteger(at.religion_addr_1 + 15, religion_bonuses[1])
    core.writeCodeInteger(at.religion_addr_1 + 27, religion_bonuses[2])
    core.writeCodeByte(at.religion_addr_1 + 46, religion_bonuses[3]-religion_bonuses[4])
    core.writeCodeInteger(at.religion_addr_1 + 49, religion_bonuses[4])

    core.writeCodeInteger(at.religion_addr_2 + 15, religion_bonuses[1])
    core.writeCodeByte(at.religion_addr_2 + 27, religion_bonuses[2])
    core.writeCodeByte(at.religion_addr_2 + 46, religion_bonuses[3]-religion_bonuses[4])
    core.writeCodeInteger(at.religion_addr_2 + 49, religion_bonuses[4])

    core.writeCodeInteger(at.religion_addr_3 + 15, religion_bonuses[1])
    core.writeCodeInteger(at.religion_addr_3 + 27, religion_bonuses[2])
    core.writeCodeByte(at.religion_addr_3 + 46, religion_bonuses[3]-religion_bonuses[4])
    core.writeCodeByte(at.religion_addr_3 + 49, religion_bonuses[4])
  end
  if religion_multipliers ~= nil and need("religion_addr_1", "religion_addr_2", "religion_addr_3") then
    if religion_thresholds == nil then
      religion_thresholds = {25, 50, 75, 100} -- vanilla thresholds are 24 49 74 94
    end
    local assembled_code = core.assemble(scaling_code,{
      threshold_1 = religion_thresholds[1],
      threshold_2 = religion_thresholds[2],
      threshold_3 = religion_thresholds[3],
      threshold_4 = religion_thresholds[4],
      multiplier_1 = religion_multipliers[1],
      multiplier_2 = religion_multipliers[2],
      multiplier_3 = religion_multipliers[3],
      multiplier_4 = religion_multipliers[4]
    },0)
    assembled_code["n"] = nil
    -- at.religion_addr_1 (53 bytes) info:eax  target:ecx
    core.writeCodeByte(at.religion_addr_1, 0x50) -- push eax
    core.insertCode(at.religion_addr_1+1, 49, assembled_code)
    core.writeCodeBytes(at.religion_addr_1+50, {
      0x8B, 0xC8, -- mov ecx, eax
      0x58        -- pop eax
    })
    -- at.religion_addr_2 (55 bytes) info: eax  target: eax
    core.insertCode(at.religion_addr_2, 55, assembled_code)
    -- at.religion_addr_3 (55 bytes) info: eax  target: esi
    core.writeCodeByte(at.religion_addr_3, 0x50) -- push eax
    core.insertCode(at.religion_addr_3+1, 51, assembled_code)
    core.writeCodeBytes(at.religion_addr_3+52, {
      0x8B, 0xF0, -- mov esi, eax
      0x58        -- pop eax
    })
  end
  if church_bonus ~= nil and need("religion_addr_1", "religion_addr_2", "religion_addr_3") then
    core.writeCodeByte(at.religion_addr_1 + 64, church_bonus)
    core.writeCodeByte(at.religion_addr_2 + 448, church_bonus)
    core.writeCodeByte(at.religion_addr_3 + 66, church_bonus)
  end
  if cathedral_bonus ~= nil and need("religion_addr_1", "religion_addr_2", "religion_addr_3") then
    core.writeCodeByte(at.religion_addr_1 + 76, cathedral_bonus)
    core.writeCodeByte(at.religion_addr_2 + 463, cathedral_bonus)
    core.writeCodeByte(at.religion_addr_3 + 78, cathedral_bonus)
  end
end

local function edit_beer(beer)
  local beer_thresholds = beer["thresholds"]
  local beer_bonuses = beer["bonuses"]
  local beer_coverage = beer["coverage_per_inn"]
  local beer_flagons = beer["flagons_per_beer"]
  local beer_multipliers = beer["multipliers"]
  local beer_flagon_cap = beer["flagon_cap"]
  if beer_thresholds == nil then
    beer_thresholds = {25, 50, 75, 100}
  elseif need("beer_addr_1", "beer_addr_2", "beer_addr_3") then
    core.writeCodeByte(at.beer_addr_1 + 2, beer_thresholds[1])
    core.writeCodeByte(at.beer_addr_1 + 11, beer_thresholds[2])
    core.writeCodeByte(at.beer_addr_1 + 23, beer_thresholds[3])
    core.writeCodeByte(at.beer_addr_1 + 37, beer_thresholds[4])

    -- next level at: %## informative texts
    core.writeCodeByte(at.beer_addr_1 + 95+2, beer_thresholds[1])
    core.writeCodeInteger(at.beer_addr_1 + 95+6, beer_thresholds[1])

    core.writeCodeByte(at.beer_addr_1 + 95+14, beer_thresholds[2])
    core.writeCodeInteger(at.beer_addr_1 + 95+18, beer_thresholds[2])

    core.writeCodeByte(at.beer_addr_1 + 95+26, beer_thresholds[3])
    core.writeCodeInteger(at.beer_addr_1 + 95+30, beer_thresholds[3])

    core.writeCodeByte(at.beer_addr_1 + 95+38, beer_thresholds[4])
    core.writeCodeInteger(at.beer_addr_1 + 95+46, beer_thresholds[4])

    core.writeCodeByte(at.beer_addr_2 + 2 , beer_thresholds[1])
    core.writeCodeByte(at.beer_addr_2 + 11 , beer_thresholds[2])
    core.writeCodeByte(at.beer_addr_2 + 23 , beer_thresholds[3])
    core.writeCodeByte(at.beer_addr_2 + 37 , beer_thresholds[4])

    core.writeCodeByte(at.beer_addr_3 + 2, beer_thresholds[1])
    core.writeCodeByte(at.beer_addr_3 + 18, beer_thresholds[2])
    core.writeCodeByte(at.beer_addr_3 + 30, beer_thresholds[3])
    core.writeCodeByte(at.beer_addr_3 + 44, beer_thresholds[4])
  end
  if beer_bonuses ~= nil and need("beer_addr_1", "beer_addr_2", "beer_addr_3") then
    core.writeCodeByte(at.beer_addr_1 + 15, beer_bonuses[1])
    core.writeCodeByte(at.beer_addr_1 + 27, beer_bonuses[2])
    core.writeCodeByte(at.beer_addr_1 + 46, beer_bonuses[3]-beer_bonuses[4])
    core.writeCodeByte(at.beer_addr_1 + 48, beer_bonuses[4])

    core.writeCodeByte(at.beer_addr_2 + 15 , beer_bonuses[1])
    core.writeCodeByte(at.beer_addr_2 + 27 , beer_bonuses[2])
    core.writeCodeByte(at.beer_addr_2 + 46 , beer_bonuses[3]-beer_bonuses[4])
    core.writeCodeByte(at.beer_addr_2 + 49 , beer_bonuses[4])

    core.writeCodeByte(at.beer_addr_3 + 22, beer_bonuses[1])
    core.writeCodeByte(at.beer_addr_3 + 34, beer_bonuses[2])
    core.writeCodeByte(at.beer_addr_3 + 53, beer_bonuses[3]-beer_bonuses[4])
    core.writeCodeByte(at.beer_addr_3 + 56, beer_bonuses[4])
  end
  if beer_coverage ~= nil and need("beer_coverage_addr") then
    core.writeCodeInteger(at.beer_coverage_addr+19, beer_coverage*100)
  end
  if beer_flagons ~= nil and need("flagon_mul_addr", "flagon_inn_display_addr") then
    core.writeCodeSmallInteger(at.flagon_mul_addr+13, beer_flagons)
      core.writeCodeBytes(at.flagon_inn_display_addr+7, core.compile({
        0x31, 0xD2, -- xor edx, edx
        0x8B, 0xC1, -- mov eax, ecx
        0xB9, core.itob(beer_flagons), -- mov eax, val
        0xF7, 0xF1, -- div ecx
        0x50,   -- push eax
        0x90, 0x90, 0x90, 0x90, 0x90, 0x90
      }, at.flagon_inn_display_addr+7))
  end
  if beer_multipliers ~= nil and need("beer_addr_1", "beer_addr_2", "beer_addr_3") then
    local assembled_code = core.assemble(scaling_code,{
      threshold_1 = beer_thresholds[1],
      threshold_2 = beer_thresholds[2],
      threshold_3 = beer_thresholds[3],
      threshold_4 = beer_thresholds[4],
      multiplier_1 = beer_multipliers[1],
      multiplier_2 = beer_multipliers[2],
      multiplier_3 = beer_multipliers[3],
      multiplier_4 = beer_multipliers[4]
    },0)
    assembled_code["n"] = nil
    -- at.beer_addr_1 (52 bytes) info: esi target: eax
    core.writeCodeBytes(at.beer_addr_1, {
      0x56, -- push esi
      0x8B, 0xC6 -- mov eax esi
    })
    core.insertCode(at.beer_addr_1+3, 48, assembled_code)
    core.writeCodeBytes(at.beer_addr_1+51, {
      0x5E  -- pop esi
    })
    -- at.beer_addr_2 (55 bytes) info: eax target: esi
    core.writeCodeBytes(at.beer_addr_2, {
      0x50 -- push eax
    })
    core.insertCode(at.beer_addr_2+1, 51, assembled_code)
    core.writeCodeBytes(at.beer_addr_2+52, {
      0x8B, 0xF0, -- mov esi eax
      0x58 -- pop eax
    })
    -- at.beer_addr_3 (62 bytes) info: eax target: eax
    core.insertCode(at.beer_addr_3, 62, assembled_code)
  end
  if beer_flagon_cap ~= nil then
    if extreme_only_feature_check("Beer flagon cap editing is only available for SHC Extreme!") and need("flagon_cap_addr") then
      core.writeCodeSmallInteger(at.flagon_cap_addr, beer_flagon_cap)
    end
  end
end

local function edit_food(food)
  local ration_bonuses = food["ration_bonuses"]
  local variety_bonuses = food["variety_bonuses"]
  local food_value = food["food_value"]
  if ration_bonuses ~= nil and need("food_addr_1", "food_addr_2", "food_addr_3") then
      core.writeCodeInteger(at.food_addr_1 + 1, ration_bonuses[1])
      core.writeCodeInteger(at.food_addr_1 + 70, ration_bonuses[1])
      core.writeCodeInteger(at.food_addr_1 + 61, ration_bonuses[2])
      core.writeCodeByte(at.food_addr_1 + 44, ration_bonuses[3]-3)
      core.writeCodeInteger(at.food_addr_1 + 31, ration_bonuses[4])

      core.writeCodeInteger(at.food_addr_2 + 1, ration_bonuses[1])
      core.writeCodeInteger(at.food_addr_2 + 57, ration_bonuses[1])
      core.writeCodeByte(at.food_addr_2 + 51, ration_bonuses[2]-1)
      core.writeCodeByte(at.food_addr_2 + 32, ration_bonuses[3]-3)
      core.writeCodeInteger(at.food_addr_2 + 19, ration_bonuses[4])

      core.writeCodeInteger(at.food_addr_3 + 1, ration_bonuses[1])
      core.writeCodeInteger(at.food_addr_3 + 19, ration_bonuses[1])
      core.writeCodeByte(at.food_addr_3 + 32, ration_bonuses[2]-1)
      core.writeCodeInteger(at.food_addr_3 + 60, ration_bonuses[3])
      core.writeCodeInteger(at.food_addr_3 + 50, ration_bonuses[4])
  end
  if variety_bonuses ~= nil and need("food_addr_1", "food_addr_2", "food_addr_3") then
    core.writeCodeByte(at.food_addr_1 + 466, variety_bonuses[1]-2)
    core.writeCodeByte(at.food_addr_1 + 476, variety_bonuses[2]-3)
    core.writeCodeInteger(at.food_addr_1 + 485, variety_bonuses[3])

    core.writeCodeByte(at.food_addr_2 + 89, variety_bonuses[1])
    core.writeCodeByte(at.food_addr_2 + 99, variety_bonuses[2])
    core.writeCodeByte(at.food_addr_2 + 109, variety_bonuses[3])

    core.writeCodeByte(at.food_addr_3 + 84, variety_bonuses[1])
    core.writeCodeByte(at.food_addr_3 + 94, variety_bonuses[2])
    core.writeCodeByte(at.food_addr_3 + 104, variety_bonuses[3])
  end
  if food_value ~= nil and need("food_point_addr") then
    core.writeCodeInteger(at.food_point_addr, food_value)
    core.writeCodeInteger(at.food_point_addr+242, food_value)
  end
end

local function edit_fear_factor(fear_factor)
  local popularity_per_good_level = fear_factor["popularity_per_good_level"]
  local popularity_per_bad_level = fear_factor["popularity_per_bad_level"]
  local popularity_table = fear_factor["popularity_table"]
  local productivity = fear_factor["productivity"]
  local coverage = fear_factor["coverage"]
  local combat_bonus = fear_factor["combat_bonus"]
  local resting_factor = fear_factor["resting_factor"]

  if popularity_table ~= nil and need("ff_addr_1", "ff_addr_2", "ff_addr_3") then
    local pop_table_addr = core.allocate(11*4)

    for idx, pop_val in ipairs(popularity_table) do
      core.writeCodeInteger(pop_table_addr+4*(idx-1), pop_val)
    end

    core.insertCode(at.ff_addr_1+6, 22, core.assemble([[
      mov eax, [eax*4 + table_addr]
    ]], {
      table_addr=pop_table_addr+20
    }, 0))

    core.insertCode(at.ff_addr_2+6, 26, core.assemble([[
      mov eax, [eax*4 + table_addr]
      mov esi, eax
    ]], {
      table_addr=pop_table_addr+20
    }, 0))

    core.insertCode(at.ff_addr_3+7, 36, core.assemble([[
      mov eax, [eax*4 + table_addr]
      mov [esp+0x1C], eax
    ]], {
      table_addr=pop_table_addr+20
    }, 0))

  else
    if popularity_per_good_level ~= nil and need("ff_addr_1", "ff_addr_2", "ff_addr_3") then
      core.writeCodeByte(at.ff_addr_1 + 13, popularity_per_good_level)
      core.writeCodeByte(at.ff_addr_2 + 13, popularity_per_good_level)
      core.writeCodeByte(at.ff_addr_3 + 14, popularity_per_good_level)
    end
    if popularity_per_bad_level ~= nil and need("ff_addr_1", "ff_addr_2", "ff_addr_3") then
      core.writeCodeByte(at.ff_addr_1 + 23, popularity_per_bad_level)
      core.writeCodeByte(at.ff_addr_2 + 25, popularity_per_bad_level)
      core.writeCodeByte(at.ff_addr_3 + 28, popularity_per_bad_level)
    end
  end
  if productivity ~= nil and need("productivity_addr") then
    core.writeCodeInteger(at.productivity_addr + 2, productivity[1])
    core.writeCodeInteger(at.productivity_addr + 15, productivity[2])
    core.writeCodeInteger(at.productivity_addr + 28, productivity[3])
    core.writeCodeInteger(at.productivity_addr + 41, productivity[4])
    core.writeCodeInteger(at.productivity_addr + 54, productivity[5])
    core.writeCodeInteger(at.productivity_addr + 66, productivity[6])
    core.writeCodeInteger(at.productivity_addr + 79, productivity[7])
    core.writeCodeInteger(at.productivity_addr + 92, productivity[8])
    core.writeCodeInteger(at.productivity_addr + 105, productivity[9])
    core.writeCodeByte(at.productivity_addr + 124, productivity[10]-productivity[11])
    core.writeCodeByte(at.productivity_addr + 127, productivity[11])
  end
  if coverage ~= nil and need("ff_coverage_addr") then
    local custom_coverage_instructions = {
      0x85, 0xC9,  -- test ecx, ecx
      0x74, 0x01,  -- jn by one
      0x49,  -- dec ecx
      0xC1, 0xF9, coverage,  -- sar ecx, coverage_value
      0x41  -- inc ecx
    }
    core.insertCode(at.ff_coverage_addr, 6, custom_coverage_instructions)
  end
  if combat_bonus ~= nil and need("combat_bonus_memory_addr", "positive_troop_combat_bonus_visual_addr",
      "negative_troop_combat_bonus_visual_addr") then
    local damage_table_addr = core.allocate(11)
    local damage_table_visual_addr = core.allocate(11*4)

    local custom_combat_instructions = {
      0x8A, 0x88, core.itob(damage_table_addr+5),
      0x0F, 0xAF, 0x4C, 0x24, 0x04,             -- imul ecx,[esp+04]
      core.jmpTo(at.combat_bonus_memory_addr+11)   -- jmp 0053162B
    }

    core.writeCode(damage_table_addr, combat_bonus, true)
    for idx, multiplier in ipairs(combat_bonus) do
        core.writeInteger(damage_table_visual_addr+4*(idx-1), multiplier-100)
    end

    -- at.positive_troop_combat_bonus_visual_addr  -- target is ecx, src is eax
    core.writeCodeBytes(at.positive_troop_combat_bonus_visual_addr+6, {0x90, 0x90, 0x90})  -- nop out original eax*5 -> ecx
    -- at.negative_troop_combat_bonus_visual_addr  -- target is ecx, src is eax
    core.writeCodeBytes(at.negative_troop_combat_bonus_visual_addr+6, {0x90, 0x90, 0x90})  -- nop out original eax*5 -> ecx
    
    local visual_code_positive = core.assemble("mov ecx, [eax*4 + tcb_table_addr]", {tcb_table_addr=damage_table_visual_addr+ 20}, 0)
    local visual_code_negative = core.assemble("mov ecx, [eax*4 + tcb_table_addr]", {tcb_table_addr=damage_table_visual_addr+ 20}, 0)

    core.insertCode(at.positive_troop_combat_bonus_visual_addr, 6, visual_code_positive, at.positive_troop_combat_bonus_visual_addr+9, "before")
    core.insertCode(at.negative_troop_combat_bonus_visual_addr, 6, visual_code_negative, at.negative_troop_combat_bonus_visual_addr+9, "before")

    local custom_combat_addr = core.allocateCode(core.calculateCodeSize(custom_combat_instructions))

    local combat_jumpout_instructions = {
      0x31, 0xC9,                   -- xor ecx, ecx
      core.jmpTo(custom_combat_addr),
      0x90, 0x90, 0x90, 0x90        -- nop nop nop nop
    }

    core.writeCode(custom_combat_addr, custom_combat_instructions, true)
    core.writeCode(at.combat_bonus_memory_addr, combat_jumpout_instructions, true)
  end
  if resting_factor ~= nil and need("resting_factor_addr") then
    core.writeCodeByte(at.resting_factor_addr, resting_factor)
  end
end

local function edit_taxation(taxation)
  local tax_table = taxation["gold"]
  local pop_table = taxation["popularity"]
  local adv_multipliers = taxation["advantage_multiplier"]
  local neutral_level = 3
  if adv_multipliers ~= nil and need("multipliers_addr_base") then
    local human_big_ai_medium = adv_multipliers["human_big_ai_medium"]
    local ai_big = adv_multipliers["ai_big"]
    if human_big_ai_medium ~= nil then
      core.writeCodeInteger(at.multipliers_addr_base + 46, human_big_ai_medium)
    end
    if ai_big ~= nil then
      core.writeCodeInteger(at.multipliers_addr_base + 2, ai_big)
    end
  end

  -- the gold and popularity tables both depend on the neutral level
  if not need("neutral_level_addr_1", "neutral_level_addr_2", "neutral_level_addr_3", "neutral_level_addr_4") then
    return
  end
  if tax_table ~= nil then
    for idx, tax_val in ipairs(tax_table) do
      core.writeCodeSmallInteger(tax_table_addr+2*(idx-1), math.floor(tax_val*100))
      if math.floor(tax_val*100) == 0 then
        neutral_level = idx-1
      end
    end
  end
  core.writeCodeByte(at.neutral_level_addr_1 + 2, neutral_level)
  core.writeCodeByte(at.neutral_level_addr_2, neutral_level)
  core.writeCodeByte(at.neutral_level_addr_3 + 2, neutral_level)
  core.writeCodeByte(at.neutral_level_addr_4 + 2, neutral_level)
  if pop_table ~= nil and need("keep_menu_addr", "pop_report_addr", "tax_popularity_offset", "actual_effect_addr") then
    local pop_table_addr = at.keep_menu_addr + 31
    core.writeCodeBytes(at.keep_menu_addr, core.compile({  -- keep menu
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
    }, at.keep_menu_addr))
    for index, value in ipairs(pop_table) do
      core.writeCodeInteger(pop_table_addr + 4*(index-1), value)
    end
    -- 75 bytes are free in function

    core.writeCodeBytes(at.pop_report_addr + 6, core.compile({  -- pop report
      neutral_level,
      0x7D, 0x0E,
      0x83, 0x7C, 0x24, 0x18, 0x00,
      0x7F, 0x07,
      0xB8, neutral_level, 0x00, 0x00, 0x00,  -- mov eax,00000003
      0xEB, 0x06,                             -- jmp 0043EBDB
      0x8B, 0x80, core.itob(at.tax_popularity_offset),     -- mov eax,[eax+011F0BC0]
      0xC1, 0xE0, 0x02,                       -- shl eax,02
      0x8B, 0xB0, core.itob(pop_table_addr),     -- mov esi,[eax+0043B0BC]
      0xEB, 0x76                              -- jmp 0043EC5C
    }, at.pop_report_addr + 6))
    -- 118 bytes are free in function

    core.writeCodeBytes(at.actual_effect_addr + 2, core.compile({  -- actual effect
      neutral_level,
      0x7D, 0x06,
      0x85, 0xED,
      0x7F, 0x02,
      0xB0, neutral_level,
      0xC1, 0xE0, 0x02,
      0x8B, 0x80, core.itob(pop_table_addr),
      0xE9, 0x80, 0x00, 0x00, 0x00
    }, at.actual_effect_addr + 2))
    -- 128 bytes are free in function

  end

end

-- Siege ranges in tiles once a ranges block is applied, for getSiegeRanges.
local applied_siege_ranges

local function edit_ranges(ranges)
  local archer_range = ranges["archer_range"]
  local xbow_range = ranges["xbow_range"]
  local arabbow_range = ranges["arabbow_range"]
  local slinger_range = ranges["slinger_range"]
  local horse_archer_range = ranges["horse_archer_range"]
  local firethrower_range = ranges["firethrower_range"]
  local catapult_range = ranges["catapult_range"]
  local treb_range = ranges["treb_range"]
  local fbal_range = ranges["fbal_range"]
  local towerbal_range = ranges["towerbal_range"]
  local mangonel_range = ranges["mangonel_range"]

  if not need("unit_array_base", "base_ranges_table_addr", "range_split_addr1", "range_split_addr2", "range_split_addr3",
      "range_split_addr4", "range_split_addr5", "range_split_addr6", "range_split_addr7", "range_split_addr8",
      "range_split_addr9", "range_split_addr10", "range_split_addr11", "range_split_addr12",
      "scan_range_addr_archer", "scan_range_addr_arabbow_1", "scan_range_addr_arabbow_2",
      "scan_range_addr_horse_archer", "scan_range_addr_xbow", "scan_range_addr_xbow_2",
      "scan_range_addr_slinger_1", "scan_range_addr_slinger_2", "scan_range_addr_slinger_3",
      "scan_range_addr_firethrower_1", "scan_range_addr_fbal_1", "scan_range_addr_fbal_2",
      "scan_range_addr_mango", "scan_range_addr_towerbal_1", "scan_range_addr_towerbal_2") then
    return
  end

  -- load default values if not specified
  if archer_range == nil then archer_range = 54 end
  if xbow_range == nil then xbow_range = 54 end
  if arabbow_range == nil then arabbow_range = 54 end
  if slinger_range == nil then slinger_range = 22 end
  if horse_archer_range == nil then horse_archer_range = 54 end
  if firethrower_range == nil then firethrower_range = 11 end
  if catapult_range == nil then catapult_range = 75 end
  if treb_range == nil then treb_range = 85 end
  if fbal_range == nil then fbal_range = 54 end
  if towerbal_range == nil then towerbal_range = 85 end
  if mangonel_range == nil then mangonel_range = 70 end

  local mapping_1 ={archer_range=archer_range, xbow_range=xbow_range, arabbow_range=arabbow_range, horse_archer_range=horse_archer_range, fbal_range=fbal_range}
  local mapping_2 ={treb_range=treb_range, towerbal_range=towerbal_range}

  local code_1 = core.assemble(templates.range_split_asm1, {archer_range=archer_range, arabbow_range=arabbow_range, horse_archer_range=horse_archer_range, base_ranges=at.base_ranges_table_addr - 4}, 0)
  local code_2 = core.assemble(templates.range_split_asm2, mapping_1, 0)
  local code_3 = core.assemble(templates.range_split_asm3, mapping_1, 0)
  local code_4 = core.assemble(templates.range_split_asm4, {archer_range=archer_range, xbow_range=xbow_range, arabbow_range=arabbow_range, horse_archer_range=horse_archer_range, unit_type=at.unit_array_base + 0x8E}, 0)
  local code_5 = core.assemble(templates.range_split_asm5, mapping_1, 0)
  local code_6 = core.assemble(templates.range_split_asm6, mapping_1, 0)
  local code_7 = core.assemble(templates.range_split_asm7, mapping_2, 0)
  local code_8 = core.assemble(templates.range_split_asm8, mapping_2, 0)
  local code_9 = core.assemble(templates.range_split_asm9, mapping_2, 0)
  local code_10 = core.assemble(templates.range_split_asm10, mapping_2, 0)
  local code_11 = core.assemble(templates.range_split_asm11, {catapult_range=catapult_range, treb_range=treb_range}, 0)
  local code_12 = core.assemble(templates.range_split_asm12, {firethrower_range=firethrower_range}, 0)

  -- base ranges
  core.writeCodeInteger(at.base_ranges_table_addr + 24, xbow_range) -- "Crossbowman base range.",
  core.writeCodeInteger(at.base_ranges_table_addr + 144, fbal_range) -- "Fireballista base range.",
  core.insertCode(at.range_split_addr1, 7, code_1)

  -- manual control
  core.insertCode(at.range_split_addr2, 5, code_2)
  core.insertCode(at.range_split_addr3, 5, code_3)
  core.insertCode(at.range_split_addr4, 5, code_4)
  core.insertCode(at.range_split_addr5, 5, code_5)
  core.insertCode(at.range_split_addr6, 5, code_6)

  -- Trebuchets and Tower Ballistas
  core.insertCode(at.range_split_addr7, 5, code_7)
  core.insertCode(at.range_split_addr8, 5, code_8)
  core.insertCode(at.range_split_addr9, 5, code_9)
  core.insertCode(at.range_split_addr10, 5, code_10)

  core.insertCode(at.range_split_addr11, 13, code_11)

  -- slinger range addresses
  core.writeCodeInteger(at.base_ranges_table_addr + 128, slinger_range) -- also +136 can be relevant
  -- core.writeCodeInteger(at.base_ranges_table_addr + 136, slinger_range)
  core.writeCodeInteger(at.range_split_addr2 + 11, slinger_range*slinger_range)
  core.writeCodeInteger(at.range_split_addr4 + 126, slinger_range*slinger_range)
  core.writeCodeInteger(at.range_split_addr3 + 11, slinger_range*slinger_range)
  core.writeCodeInteger(at.range_split_addr5 + 8, slinger_range*slinger_range)
  core.writeCodeInteger(at.range_split_addr6 + 8, slinger_range*slinger_range)

  -- firethrower
  core.insertCode(at.range_split_addr12, 5, code_12)  -- allowing for 4-byte sized ranges
  core.writeCodeInteger(at.base_ranges_table_addr + 132, firethrower_range) -- also +140 can be relevant
  -- core.writeCodeInteger(at.base_ranges_table_addr + 140, firethrower_range)
  core.writeCodeInteger(at.range_split_addr2 + 21, firethrower_range*firethrower_range)
  core.writeCodeInteger(at.range_split_addr4 + 164, firethrower_range*firethrower_range)
  core.writeCodeInteger(at.range_split_addr3 + 21, firethrower_range*firethrower_range)
  core.writeCodeInteger(at.range_split_addr5 + 15, firethrower_range*firethrower_range)
  core.writeCodeInteger(at.range_split_addr6 + 15, firethrower_range*firethrower_range)

  -- catapult
  core.writeCodeInteger(at.base_ranges_table_addr + 4, catapult_range)
  core.writeCodeInteger(at.range_split_addr2 + 31, catapult_range*catapult_range)  -- also linked to cow throwing range
  core.writeCodeInteger(at.range_split_addr4 + 189, catapult_range*catapult_range)
  core.writeCodeInteger(at.range_split_addr3 + 31, catapult_range*catapult_range)  -- also linked to cow throwing range
  core.writeCodeInteger(at.range_split_addr5 - 650, catapult_range*catapult_range)  -- maybe find a new base address?
  core.writeCodeInteger(at.range_split_addr5 - 264, catapult_range*catapult_range)  -- maybe find a new base address?
  core.writeCodeInteger(at.range_split_addr5 + 22, catapult_range*catapult_range)
  core.writeCodeInteger(at.range_split_addr6 + 22, catapult_range*catapult_range)

  -- mangonel
  core.writeCodeInteger(at.base_ranges_table_addr + 12, mangonel_range)
  core.writeCodeInteger(at.range_split_addr2 + 48, mangonel_range*mangonel_range)
  core.writeCodeInteger(at.range_split_addr4 + 209, mangonel_range*mangonel_range)
  core.writeCodeInteger(at.range_split_addr3 + 51, mangonel_range*mangonel_range)
  core.writeCodeInteger(at.range_split_addr5 - 636, mangonel_range*mangonel_range)  -- maybe find a new base address?
  core.writeCodeInteger(at.range_split_addr5 - 250, mangonel_range*mangonel_range)  -- maybe find a new base address?
  core.writeCodeInteger(at.range_split_addr9 + 8, mangonel_range*mangonel_range)
  core.writeCodeInteger(at.range_split_addr10 + 8, mangonel_range*mangonel_range)

  -- trebuchet
  core.writeCodeInteger(at.base_ranges_table_addr + 8, treb_range)
  core.writeCodeInteger(at.range_split_addr4 + 199, treb_range*treb_range)
  core.writeCodeInteger(at.range_split_addr5 - 643, treb_range*treb_range)  -- maybe find a new base address?
  core.writeCodeInteger(at.range_split_addr5 - 257, treb_range*treb_range)  -- maybe find a new base address?

  -- towerbal
  core.writeCodeInteger(at.base_ranges_table_addr + 76, towerbal_range)
  core.writeCodeInteger(at.range_split_addr4 + 232, towerbal_range*towerbal_range)

  -- firebal
  core.writeCodeInteger(at.range_split_addr4 + 271, fbal_range*fbal_range)

  -- scan ranges
  core.writeCodeSmallInteger(at.scan_range_addr_archer + 7, (archer_range-4)*8)
  core.writeCodeSmallInteger(at.scan_range_addr_archer + 52, (archer_range-4)*8)
  core.writeCodeSmallInteger(at.scan_range_addr_archer + 74, archer_range*8)

  core.writeCodeInteger(at.scan_range_addr_arabbow_1 + 3, (arabbow_range-4)*8)
  core.writeCodeSmallInteger(at.scan_range_addr_arabbow_1 + 87, arabbow_range*8)
  core.writeCodeInteger(at.scan_range_addr_arabbow_2 + 3, (arabbow_range-4)*8)

  core.writeCodeSmallInteger(at.scan_range_addr_horse_archer + 13, horse_archer_range*8)
  core.writeCodeSmallInteger(at.scan_range_addr_horse_archer + 230, horse_archer_range*8)
  core.writeCodeSmallInteger(at.scan_range_addr_horse_archer + 661, horse_archer_range*8)

  core.writeCodeSmallInteger(at.scan_range_addr_xbow + 10, (xbow_range-4)*8)
  core.writeCodeSmallInteger(at.scan_range_addr_xbow + 32, xbow_range*8)
  core.writeCodeSmallInteger(at.scan_range_addr_xbow_2 + 16, (xbow_range-4)*8)

  core.writeCodeSmallInteger(at.scan_range_addr_slinger_1 + 10, (slinger_range+5)*8)
  core.writeCodeSmallInteger(at.scan_range_addr_slinger_1 + 32, (slinger_range+5)*8)
  core.writeCodeInteger(at.scan_range_addr_slinger_2 + 4, slinger_range*slinger_range)
  core.writeCodeInteger(at.scan_range_addr_slinger_3 + 16, (slinger_range+5)*8)

  core.writeCodeSmallInteger(at.scan_range_addr_firethrower_1 + 10, (firethrower_range+5)*8)
  core.writeCodeSmallInteger(at.scan_range_addr_firethrower_1 + 32, (firethrower_range+5)*8)

  core.writeCodeSmallInteger(at.scan_range_addr_fbal_1 + 16, towerbal_range*8) -- for some reason tied to towerbal range
  core.writeCodeSmallInteger(at.scan_range_addr_fbal_1 + 216, fbal_range*8)
  core.writeCodeInteger(at.scan_range_addr_fbal_2 + 7, fbal_range*fbal_range)
  core.writeCodeByte(at.scan_range_addr_fbal_1 + 73, fbal_range-2) -- ai range
  core.writeCodeByte(at.range_split_addr11-6, fbal_range-2) -- also ai range

  core.writeCodeSmallInteger(at.scan_range_addr_mango + 13, towerbal_range*8) -- for some reason tied to towerbal range
  core.writeCodeSmallInteger(at.scan_range_addr_mango + 237, towerbal_range*8) -- for some reason tied to towerbal range

  core.writeCodeSmallInteger(at.scan_range_addr_towerbal_1 + 8, towerbal_range*8)
  core.writeCodeSmallInteger(at.scan_range_addr_towerbal_2 + 8, towerbal_range*8)
  applied_siege_ranges = { catapult = catapult_range, trebuchet = treb_range, fire_ballista = fbal_range }
end

local function edit_projectiles(projectiles)
    local keyword_offset_map = {
     arrow = 0,
     catapult_rock = 4,
     trebuchet_rock = 8,
     mangonel_pebble = 12,
     crossbow_bolt = 24,
     towerbal_bolt = 76,
     cow = 88,
     slinger_stone = 128,
     firethrower_grenade = 132,
     firebal_bolt = 144
    }
    for key, offset in pairs(keyword_offset_map) do
      local projectile = projectiles[key]
      if projectile ~= nil then
        local velocity = projectile["velocity"]
        local arch_type = projectile["arch_type"]
        if velocity ~= nil and need("proj_velocity_table_addr") then
          core.writeCodeInteger(at.proj_velocity_table_addr+offset, velocity)
        end
        if arch_type ~= nil and need("proj_archtype_table_addr") then
          core.writeCodeInteger(at.proj_archtype_table_addr+offset, arch_type)
        end

      end
    end
end

local function edit_leather_per_cow(leather_per_cow)
  if not need("leather_per_cow_address") then
    return
  end
  core.writeCodeByte(at.leather_per_cow_address+2, leather_per_cow)
  core.writeCodeByte(at.leather_per_cow_address+4, leather_per_cow)
end

local function apply_rebalance_function(function_name, config_section)
  if config_section ~= nil then
    function_name(config_section)
  end
end

namespace.apply_rebalance = function(config)
  check_sites()
  apply_rebalance_function(edit_buildings, config["buildings"])
  apply_rebalance_function(edit_siege, config["siege"])  -- siege changes need to come before units, due to projectile damages on units
  apply_rebalance_function(edit_castle, config["castle"])  -- castle changes need to come before units, due to fire damages on units
  apply_rebalance_function(edit_units, config["units"])
  apply_rebalance_function(edit_resources, config["resources"])
  apply_rebalance_function(edit_population, config["population"])
  apply_rebalance_function(edit_religion, config["religion"])
  apply_rebalance_function(edit_beer, config["beer"])
  apply_rebalance_function(edit_food, config["food"])
  apply_rebalance_function(edit_fear_factor, config["fear_factor"])
  apply_rebalance_function(edit_taxation, config["taxation"])
  apply_rebalance_function(edit_ranges, config["ranges"])
  apply_rebalance_function(edit_projectiles, config["projectiles"])
  apply_rebalance_function(edit_leather_per_cow, config["leather_per_cow"])
  local value_sites = require("value_sites")
  apply_rebalance_function(value_sites.edit_building_placement, config["building_placement"])
  apply_rebalance_function(value_sites.edit_stances, config["stances"])

  if config["population_gathering_rate"] then
    log(ERROR, "population_gathering_rate is removed, use population section in the config instead.")
  end

  if config["enable_iron_double_pickup"] and need("iron_wait_addr", "iron_subtract_addr", "building_array_base") then
    core.writeCodeBytes(at.iron_wait_addr, core.compile({
      0x83, 0xB8, core.itob(at.building_array_base + 0x138), 0x01,
      0x0F, 0x9E, 0xC1,
      0x90
    }, at.iron_wait_addr)) 
    core.writeCodeByte(at.iron_subtract_addr, -2)
  end

  if config["disable_rally_runners"] and need("arabbow_rally_running_addr", "slinger_rally_running_addr",
      "assassin_rally_running_addr", "firethrower_rally_running_addr") then
    core.writeCodeBytes(at.arabbow_rally_running_addr, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90})
    core.writeCodeBytes(at.slinger_rally_running_addr, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90})
    core.writeCodeBytes(at.assassin_rally_running_addr, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90})
    core.writeCodeBytes(at.firethrower_rally_running_addr, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90})
  end

  if config["enable_spearmen_conditional_run"] then
    if extreme_only_feature_check("enable_spearmen_conditional_run is only available for SHC Extreme!") then
      enable_spearmen_conditional_run()
    end
  end

  if config["reduce_height_advantage"] then
    if extreme_only_feature_check("reduce_height_advantage is only available for SHC Extreme!") then
      reduce_height_advantage()
    end
  end

  if config["increase_enemy_check_frequency"] ~= nil then
    if extreme_only_feature_check("increase_enemy_check_frequency is only available for SHC Extreme!") then
      increase_enemy_check_frequency()
    end
  end

  if config["increase_minimap_unit_size"] ~= nil then
    if extreme_only_feature_check("increase_minimap_unit_size is only available for SHC Extreme!") then
      increase_minimap_unit_size()
    end
  end

end

namespace.enable = function(self, config)
  local file = io.open(config["balance_config_file_selector"], "rb")
---@diagnostic disable-next-line: need-check-nil
  local spec = file:read("*all")
---@diagnostic disable-next-line: undefined-global
  local rebalance_cfg = yaml.parse(spec)
  if enable_rebalance_features() then
    namespace.apply_rebalance(rebalance_cfg)
  else
    log(WARNING, "the balance file is not applied")
  end
end

namespace.disable = function(self, config)
end

-- The siege ranges this module applied, or nil when the game's own ranges apply.
namespace.getSiegeRanges = function(self)
  local r = applied_siege_ranges
  return r and { catapult = r.catapult, trebuchet = r.trebuchet, fire_ballista = r.fire_ballista }
end

return namespace, { public = { "getSiegeRanges" } }
