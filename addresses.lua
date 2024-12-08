if data.version.isExtreme() then
    return {
        unit_array_base_addr = 0x145D03C,
        building_array_base_addr = 0xF989B4,
        unit_melee_toggles_base = 0xB55C14,
        unit_jester_unfriendly_base = 0xB55994,
        unit_blessable_base = 0xB55AD4,
        towers_or_gates_base = 0x5B9980,
        unit_gold_jumplist_addr = 0x4F6584,
        tax_popularity_offset = 0x11F0BC0
    }
else
    return {
        unit_array_base_addr = 0x138854C,
        building_array_base_addr = 0xF98534,
        unit_melee_toggles_base = 0xB55A84,
        unit_jester_unfriendly_base = 0xB55800,
        unit_blessable_base = 0xB55940,
        towers_or_gates_base = 0x5B9980,
        unit_gold_jumplist_addr = 0x4F61F4,
        tax_popularity_offset = 0x115DF80
    }
end
