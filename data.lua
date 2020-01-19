require("utility/style-data")

local Utils = require("utility/utils")
local Constants = require("constants")

data.raw["character-corpse"]["character-corpse"].icon = Constants.AssetModName .. "/graphics/character-corpse.png"
data.raw["character-corpse"]["character-corpse"].icon_size = 180

data:extend(
    {
        {
            type = "explosion",
            name = "biter_hunt_group-biter_ground_rise_effect",
            animations = {
                filename = "__core__/graphics/empty.png",
                width = 1,
                height = 1,
                frame_count = 1
            },
            created_effect = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "create-particle",
                            repeat_count = 100,
                            entity_name = "stone-particle",
                            initial_height = 0.5,
                            speed_from_center = 0.03,
                            speed_from_center_deviation = 0.05,
                            initial_vertical_speed = 0.10,
                            initial_vertical_speed_deviation = 0.05,
                            offset_deviation = {{-0.2, -0.2}, {0.2, 0.2}}
                        }
                    }
                }
            }
        },
        {
            type = "trivial-smoke",
            name = "biter_hunt_group-biter_rise_smoke",
            flags = {"not-on-map"},
            show_when_smoke_off = true,
            animation = {
                width = 152,
                height = 120,
                line_length = 5,
                frame_count = 60,
                animation_speed = 0.25,
                filename = "__base__/graphics/entity/smoke/smoke.png"
            },
            affected_by_wind = false,
            color = {r = 0.66, g = 0.58, b = 0.49, a = 1},
            duration = 240,
            fade_away_duration = 30
        },
        {
            type = "simple-entity",
            name = "biter_hunt_group-biter_ground_movement",
            collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
            collision_maxk = {"object-layer", "player-layer", "water-tile"},
            selectable_in_game = false,
            pictures = Utils.DeepCopy(data.raw["simple-entity"]["sand-rock-big"].pictures),
            created_effect = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "create-trivial-smoke",
                            smoke_name = "biter_hunt_group-biter_rise_smoke",
                            repeat_count = 3,
                            offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
                            starting_frame_deviation = 10
                        }
                    }
                }
            }
        }
    }
)

if mods["BigWinter"] ~= nil then
    local biterGroundMovement = data.raw["simple-entity"]["biter_hunt_group-biter_ground_movement"]
    for _, picture in pairs(biterGroundMovement.pictures) do
        picture.filename = string.gsub(picture.filename, "__base__", "__BigWinter__")
    end
    local biterRiseSmoke = data.raw["trivial-smoke"]["biter_hunt_group-biter_rise_smoke"]
    biterRiseSmoke.color = {r = 223, g = 230, b = 242, a = 1}
end
