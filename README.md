# Factorio-Biter-Hunt-Group

At a random configurable time, a pack of biters will become enraged against a random specific player. They will erupt from the ground around the player and hunt them relentlessly. Multiple concurrent group configurations for packs are supported.


Detailed Explanation
-----------

The frequency of biter packs attacking is configurable with a lower and upper time range. There will be a time configurable GUI warning to all players shown that a pack is incoming, but the targeted player won't be revealed. At the end of the warning time, the target player will be randomly selected from either a list of configurable players or all players who are connected and alive (has a body or is in a vehicle). They will be listed in a small GUI and a chat message will be sent to all players with a link to their location so their demise can be watched. If there are no suitable players anywhere the biters will tunnel around spawn on the nauvis (default) surface and destroy everything. At this point the next pack will be scheduled for a configured random future time using the current settings.

The player/spawn will be surrounded in a circle by a configurable number of tunnelling biter effects at a configured range. After a configurable time, the tunnelling effects will finish and the biters will burst forth. They will be evolution appropriate with a configurable added evolution factor. They will pursue the targeted player ignoring all other distractions. Should the player enter or exit vehicles they will continue the pursuit.

The hunt will be over when either the biters are all killed (player wins) or the targeted player dies from any means (biters win). If the targeted player disconnects from the server they will be classed as losing. If the player loses then the biters will rampage towards spawn destroying everything they encounter. In all cases, the results are recorded within the mod for export later for external use (see commands). The result is also broadcast via in-game messages to all players. Note, as the next pack of a group is scheduled in the future when one targets a player it is possible to have multiple packs for a group alive at one time if they aren't dealt with.


Mutliple Group Configurations
---------------

The mod supports the simplier usage of a single group with packs behaving as covered in the Detailed Explanation above. In this case each mod setting should have just 1 setting entered in the natural way for numbers or text.

The mod also supports multiple groups to be configured and each have active packs simultaniously (N groups with N active packs). This means each group's packs follows the Detailed Explanation above with their own settings. This is configured by each mod setting accepting an array [] of values in JSON format. Each sequential item in the array being applied to a corrisponding group. Should any mod setting include an array entry for a group then that group will be generated.
Example, a mod setting with the value of [2,10,3] would create 3 groups each having their sequential values.

If a mod setting only has 1 value then it is taken as a global default value and applied to all groups. In the case of a mismatch of group quantity between multiple mod settings the mod's default settings are used when needed to avoid errors, i.e. one mod setting has 2 array entries ([1,2]) and another mod setting has 3 array entries ([1,2,3]). A group's ID is just its order in a mod setting array and may be needed for some commands.

The mod settings which take a list like "Players Targeted" expect an array or arrays when multiple groups have unique settings. i.e. [ ["player1", "player2"], ["player3"], [] ]. In this case group 1 would target players name "player1" and "player2", group 2 would only target "player3" and group 3 would target all players on the server.


Biter Quantity Formula Setting
--------------

This is a special setting really intended for use with the command "biters_hunt_group_add_biters". The formula is applied when a pack is spawned in the map and takes the number of biters to be created and applies the formula to it to get the final qunatity of biters. This allows for external integrations to add biters using the command in a simple fashion and then a scaling formula can be applied to it. The formula must be valid Lua written as a "return" line to be run within the mod. The biter count will be passed in as a Lua variable "biterCount". Default is blank/empty and the standard mutliple group configuration applies.
Example of multi group configuration: ["", "math.floor(biterCount * 2.5)"]


Advised Other Mods
--------------

- Use "Extra Biter Control" mod and increase the pathfinder limits by at least a multiple of 5 to ensure all biters path to target quickly.


Commands
------------

- Command to trigger all of the configured biter hunting groups to send their next scheduled pack to attack now is "biter_hunt_group_attack_now". If multiple groups are configured via settings then individual groups can be triggered by providing their sequential ID after the command, i.e: "biter_hunt_group_attack_now 1".
- Command to write out all of the biter hunt group's results as JSON: biter_hunt_group_write_out_results
- Command to add biters to the next pack for a group. Requires agruments for the group ID, the number of biters to add and if to reset the random timer (true/false). "biter_hunt_group_add_biters [groupId] [biterNumber]", i.e. biter_hunt_group_add_biters 1 5
- Command to reset a groups current scheduled pack's random timer. Requires argument for the group ID. "biter_hunt_group_reset_group_timer [groupId]", i.e. biter_hunt_group_reset_group_timer 1


Mod Compatibility
-------------

- Big Winter mod: When this mod is present the tunnelling graphics will be winter-themed (utilises the mod).
- Space Exploration mod: Only players on a planet with a body are valid targets for a biter hunt group. However, Space Exploration mod does break the detection of the winner between biter pack and targeted player as the mod prevents the player "dieing" in the vanilla Factorio sense.