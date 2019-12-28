data:extend(
    {
        {
            name = "group_frequency_range_low_minutes",
            type = "int-setting",
            default_value = 20,
            minimum_value = 1,
            setting_type = "runtime-global",
            order = "1001"
        },
        {
            name = "group_frequency_range_high_minutes",
            type = "int-setting",
            default_value = 45,
            minimum_value = 1,
            setting_type = "runtime-global",
            order = "1002"
        },
        {
            name = "group_size",
            type = "int-setting",
            default_value = 80,
            minimum_value = 1,
            setting_type = "runtime-global",
            order = "1003"
        },
        {
            name = "group_evolution_bonus_percent",
            type = "int-setting",
            default_value = 10,
            minimum_value = 0,
            maximum_value = 100,
            setting_type = "runtime-global",
            order = "1004"
        },
        {
            name = "group_spawn_radius_from_target",
            type = "int-setting",
            default_value = 100,
            minimum_value = 1,
            maximum_value = 1000,
            setting_type = "runtime-global",
            order = "1005"
        },
        {
            name = "group_tunnelling_time_seconds",
            type = "int-setting",
            default_value = 3,
            minimum_value = 1,
            maximum_value = 10,
            setting_type = "runtime-global",
            order = "1006"
        },
        {
            name = "group_incomming_warning_seconds",
            type = "int-setting",
            default_value = 10,
            minimum_value = 0,
            maximum_value = 60,
            setting_type = "runtime-global",
            order = "1007"
        }
    }
)