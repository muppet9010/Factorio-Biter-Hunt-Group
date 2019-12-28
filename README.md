# Factorio-Biter-Hunt-Group

At a random configurable time a group of biters will become enraged against a specific player. They will erupt from the ground around the player and hunt them relentlessly.




- Utilises Biter Hunting Packs as per settings of May 2019 mode, but with many logic improvements. With the addition that a hunted player disconnecting counts as a loss and the biters target spawn instead. Adds command to write out biter hunt group results as JSON: biters_write_out_hunt_group_results. Biter hunt groups will chase players as they switch vehicles and on foot correctly.

- Every 20-45 minutes 80 enemies will spawn in a 100 tile radius around a randomly targeted valid player. They will be evolution appropriate +10% and will individually target that player. There will be 3 seconds of dirt borrowing effect before each biter will come up. Should the targeted player die during this time the biters will continue to come up and target the spawn area on that surface. If no players are alive anywhere the biters will target spawn on the nauvis surface.
- A small GUI will give a 10 second warning for the next biter hunter group and when there is a current group show who is being targeted.
- The success of a biter hunt group vs the targeted player is broadcast in game chat using icons and stored for future modding use in an in-game persistent table. The winner is whoever lasts the longest out of the special biters and the targeted player after the biter hunt group targets the player, regardless of cause of death. Should neither have won by the next biter hunt group it is declared a draw.
- Command to trigger a biter hunting pack now: biters_attack_now

- Use "Extra Biter Control" mod and increase the pathfinder limits by at least a multiple of 5 to ensure all biters path to target quickly.

Mod Compatibility
-------------

- Big Winter mod: When this mod is present the tunneling graphics will be winter themed (utilises the mod).
- Space Exploration mod: Only players on a planet with a body are valid targets for a biter hunt group. However, Space Exploration mod does break the detection of winner between biter pack and targeted player as the mod prevents the player "dieing" in the vanilla Factorio sense.