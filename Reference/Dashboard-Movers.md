# Bazi UI Dashboard and Movers

## Using the features

Open **Movers** from the settings header or type `/bazi move`. The header button temporarily closes settings and restores them after **Apply** or **Cancel**. Drag an outlined, visible frame or choose it from the list and edit its coordinates, dimensions or layout settings. The arrows move one unit at a time and Shift moves ten. Hidden windows can be configured through the list. Open them through their usual controls to drag their real frames. Loot, Cleanup and Rolls share a single origin. Select a party, raid or boss group to move its visible members together.

Dashboard starts disabled and has six settings pages under **Dashboard**. Enable it or select a preview scenario in **General**. Automatic widgets appear when their data is relevant. Use **Widgets** to set priority, order among equal priorities, duration, visibility or pinning. Right-click a supported row to pin it. The **Tracking** tab accepts item IDs, links or items dragged from a bag. It also accepts recipe IDs and can read a selected recipe when the profession window exposes its data. Tracked material, item, supply and crafting goals are stored by character.

## Source files

| Area | Files |
| --- | --- |
| Dashboard runtime and presentation | `Modules/Dashboard.lua` |
| Quest, profession, combat skill and item providers | `Modules/DashboardProgress.lua` |
| Gathering, crafting, supplies, character status, session, reputation, dungeon, raid and PvP | `Modules/DashboardActivity.lua` |
| Nine preview scenarios | `Modules/DashboardPreview.lua` |
| Movers interface, drag and change handling | `Modules/Movers.lua` |
| Connections to live frames and saved module values | `Modules/MoverModules.lua` |
| Wiring and settings | `BaziUI.toc`, `Core/Bootstrap.lua`, `Core/Commands.lua`, `Config/Options.lua` |
| Shared data and frame accessors | Quest Tracker, Gathering, Inventory, Nameplates, UnitFrames, ActionBars, HUD, Minimap, Map, Dialogue and Chat modules |
| Standalone integration scenarios | `Tests/DashboardMovers.lua` |

## Data sources and fallbacks

- **Quests.** Reuses Bazi UI’s zone, quest map and watch-list queries. Detailed counts come from `C_QuestLog.GetQuestObjectives`. When map objective data is unavailable, the quest’s own zone is used, or a manually watched quest with no zone. An item icon requires a known item ID.
- **Skills.** Tries `C_SkillInfo`, legacy `GetSkillLineInfo` and `C_TradeSkillUI.GetProfessionInfoBySkillLineID`. A profession window opens only on user click if `C_TradeSkillUI.OpenTradeSkill` is present. Live skill fields and any training-rank availability still need Forever verification. There is no estimate of trainer availability.
- **Gathering.** Counts identifiable self-loot messages and reads the current bag count independently. Purchases and bag rearrangements do not increase the loot total. Skinning and nearby gathering use Bazi’s object detection. Rate and vendor value are labelled estimates. Messages with unrecognised formats do not contribute.
- **Crafting.** Accepts required reagents from `GetRecipeSchematic` or a selected legacy trade-skill recipe. Recipes with alternative required reagents are omitted until a specific material choice can be verified. The widget does not craft.
- **Supplies.** Reads free normal bag slots, lowest equipped durability, equipped hunter ammunition and any individually tracked item. Other class reagents or consumables can be added in Tracking with their own minimum.
- **Instances.** Boss kills require a successful `ENCOUNTER_END` or a matching native saved-instance record. A boss total requires a complete native encounter list. Temporary runs restart after leaving or reloading unless native saved encounter data is available. This avoids attributing kills to another fresh copy of the same dungeon. Wipes and attempts count paired encounter events in the current visit.
- **PvP and reputation.** PvP uses a personal scoreboard record where available. Unsupported personal metrics are omitted. Reputation uses the current standing and thresholds returned by the client, with a legacy faction API fallback.
- **Session and character.** Money changes are based on actual money events. AFK time can be excluded from estimated XP rates. Optional session persistence keeps aggregate counters, rather than a history of events. Played time is shown after the client supplies it, for example after `/played`.

Retail reference code is used as a signature reference only. The native APIs and events exposed by the user's Forever build have not been verified in an active client.

## Verification

Run `lua Tests/DashboardMovers.lua` from the repository root. The suite covers quest completion and zone transitions, profession and skill gains, simultaneous widgets, timeouts, loot and item counts, crafting goals, character isolation, critical supplies, reputation, dungeon attempts and wipes, preview, unsubscribe on disable and drag/cancel across combat. Syntax-check all Lua paths in the TOC before deployment.

In Forever, verify text wrapping and overlap at both configured resolutions, profile settings changes, protected frames when combat starts mid-drag, Loot stack and chat geometry after reopening, quest progress in a subzone, actual skill API fields, crafting and dungeon event availability, and scoreboard responses. Enable the dashboard and compare idle and burst-event frame time with it disabled. The runtime coalesces events, caches quest/faction/skill sources and uses one shared timer. Loot scans, large visible widget lists and numerous visible Movers outlines should be included in the performance check.
