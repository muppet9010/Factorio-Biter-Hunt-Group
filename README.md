# Factorio-Biter-Hunt-Group

At a random configurable time, a group of biters will become enraged against a specific player. They will erupt from the ground around the player and hunt them relentlessly.


Detailed Explanation
-----------

The frequency of biter groups attacking is configurable with a lower and upper time range. There will be a time configurable GUI warning to all players shown that a group is incoming, but the targeted player won't be revealed. At the end of the warning time, the target player will be randomly selected from all players who are connected and alive (has a body or is in a vehicle). They will be listed in a small GUI and a chat message will be sent to all players with a link to their location so their demise can be watched. If there are no suitable players anywhere the biters will tunnel around spawn on the nauvis (default) surface and destroy everything.

Then the player will be surrounded in a circle by a configurable number of tunnelling biter effects at a configured range. After a configurable time, the tunnelling effects will finish and the biters will burst forth. They will be evolution appropriate with a configurable added evolution factor. They will pursue the targeted player ignoring all other distractions. Should the player enter or exit vehicles they will continue the pursuit.

The hunt will be over when either the biters are all killed (player wins) or the targeted player dies from any means (biters win). Should neither side die before the next hunt group starts it will be regarded as a draw. If the targeted player disconnects from the server they will be classed as losing. If the player loses then the biters will rampage towards spawn destroying everything they encounter. In all cases, the results are recorded within the mod for export later for external use (see commands). The result is also broadcast via in-game messages to all players.


Advised Other Mods
--------------

- Use "Extra Biter Control" mod and increase the pathfinder limits by at least a multiple of 5 to ensure all biters path to target quickly.

Commands
------------

- Command to trigger a biter hunting pack now: biters_attack_now
- Command to write out biter hunt group results as JSON: biters_write_out_hunt_group_results

Mod Compatibility
-------------

- Big Winter mod: When this mod is present the tunnelling graphics will be winter-themed (utilises the mod).
- Space Exploration mod: Only players on a planet with a body are valid targets for a biter hunt group. However, Space Exploration mod does break the detection of the winner between biter pack and targeted player as the mod prevents the player "dieing" in the vanilla Factorio sense.