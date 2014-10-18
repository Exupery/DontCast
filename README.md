# DontCast
### World of Warcraft PvP addon
Warns a player when their current target has buffs or debuffs that eliminate (or significantly mitigate) incoming damage. [The default buff/debuff list is most relevant to casters - but the list can be easily modified to suit melee players]. Displays the name and icon of the buff/debuff, as well as a timer displaying a countdown of time remaining until the effect expires. Buffs and debuffs can be added and removed with the appropriate slash commands.

## Default Buffs/Debuffs
* Anti-Magic Shell
* Cloak of Shadows
* Cyclone
* Deterrence
* Diffuse Magic
* Dispersion
* Divine Shield
* Ice Block
* Smoke Bomb
* Spell Reflection
* Touch of Karma

## Commands
* /dontcast add NAME - adds the named buff or debuff
* /dontcast remove NAME - removes the named buff or debuff
* /dontcast threshold #.## - set the threshold for changing color of countdown text
* /dontcast show threshold - display the threshold color of countdown text changes
* /dontcast list - display what will trigger the warning
* /dontcast default - reverts to the default triggers
* /dontcast show - Shows the frame for repositioning
* /dontcast hide - Locks (and hides) the frame
* /dontcast center - Sets the position to center of screen
* /dontcast ? or /dontcast help - Prints the command list

## TODOs
* make icon/text resizable
* integrate with options UI
* customizable text colors