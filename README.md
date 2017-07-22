# DontCast
### World of Warcraft PvP addon
Warns a player when their current target has buffs or debuffs that eliminate (or significantly mitigate) incoming damage. [The default buff/debuff list is most relevant to casters - but the list can be easily modified to suit melee players]. Displays the name and icon of the buff/debuff, as well as a timer displaying a countdown of time remaining until the effect expires. Buffs and debuffs can be added and removed with the appropriate slash commands.

## Default Buffs/Debuffs
* Anti-Magic Shell (Magical mode only)
* Aspect of the Turtle
* Blessing of Protection (Physical mode only)
* Blessing of Spellwarding (Magical mode only)
* Cloak of Shadows (Magical mode only)
* Cyclone
* Deterrence
* Die by the Sword (Physical mode only)
* Diffuse Magic (Magical mode only)
* Dispersion
* Divine Shield
* Ethereal Form (Physical mode only)
* Guardian of the Forgotten Queen
* Ice Block
* Imprison
* Nether Ward (Magical mode only)
* Netherwalk
* Paralysis
* Polymorph
* Riposte (Physical mode only)
* Shield of Vengeance
* Smoke Bomb
* Spell Reflection (Magical mode only)
* Temporal Shield
* Touch of Karma

Prior to version 1.3.7 any auras added to the default list (e.g. Dispersion in v1.1.3) would not be enabled for players updating to (or beyond) that DontCast version. This was changed in v1.3.7 (e.g. all players will now have Aspect of the Turtle enabled by default) but this required changing how auras are removed/disabled. As a result any players that prior to v1.3.7 disabled an aura (via `/dontcast remove`) that is on the default list will have that aura re-enabled. Auras disabled in v1.3.7 (or higher) will not be affected by future changes to the default list.

## Commands
* /dontcast add NAME - adds the named buff or debuff to the base list of auras (those that will show in either magical or physical mode)
* /dontcast addm NAME - adds the named buff or debuff for magical mode only
* /dontcast addp NAME - adds the named buff or debuff for physical mode only
* /dontcast remove NAME - removes the named buff or debuff
* /dontcast threshold #.## - set the threshold for changing color of countdown text
* /dontcast show threshold - display the threshold color of countdown text changes
* /dontcast list - display what will trigger the warning
* /dontcast default - reverts to the default triggers
* /dontcast show - Shows the addon and allows repositioning and resizing
* /dontcast hide - Hides (and locks) the addon
* /dontcast center - Sets the position to center of screen
* /dontcast config - Opens the options UI
* /dontcast ? or /dontcast help - Prints the command list

## TODOs
* customizable text colors
* integrate adding/removing auras via options UI
* set expiring soon threshold to a provided spell's cast-time
* add support for immunity effects not shown as aura on target player (e.g. Counterstrike Totem, Mass Spell Reflection)
