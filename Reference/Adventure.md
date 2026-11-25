# Bazi UI progression modules

The three modules are disabled initially. Open **Progression** in Bazi UI settings to enable each independently. Their windows and previews are also available through **/bazi alerts**, **/bazi journey**, and **/bazi alts**. Previews use synthetic data in memory. The release version is unchanged.

## What ships

- **Smart Alerts** has persistent and expiring notifications, contextual warnings, de-duplication, a bounded session history, trigger toggles, thresholds, combat visibility, optional chat and sound, a Dashboard card, and a real Movers registration. With both destinations enabled, the standalone rail shows the highest-priority notification and Dashboard shows the remaining notifications. Supported triggers include durability, empty core slots, a fishing pole equipped in combat, observed temporary weapon enhancements expiring, hunter ammo and pet state, tracked supplies, full bags, quest readiness and timers, professions, tracked materials, talents, level, reputation, raid/dungeon boss success, loot and mail. Cleanup opens only via its existing loot workflow.
- **Journey** has an overview, searchable timeline, milestones, sessions, exploration, PvE, PvP, professions, records, and manual notes. It records observed visits, level/skill changes, turn-ins, rare loot milestones, learned recipes, reputation standings and confirmed supported instance events. Dashboard supplies XP, money, quests, deaths and loot counters. Recent sessions merge within five minutes of the last save. Timed records require observing both the entrance and a supported completion. XP and balance records use sessions at least 15 minutes long.
- **Alt Manager** has character, inventory, professions, crafting goals, economy, mail/auctions and lockout views. It keeps the latest bags and equipment snapshots, the last known bank snapshot, timestamps and separate totals for known unbound copies. It can enrich item tooltips with recorded ownership, recipe matches and alt crafting goals. A Dashboard widget can surface a relevant material when it is looted.

## Shared data and performance

`AdventureData.lua` coalesces snapshots for identity, inventory, equipment, skills, reputation and quest-related events. Dashboard continues supplying skill lines, reputation and player loot parsing. Journey consumes the same session counters. Alt Manager indexes bag and bank snapshots by item ID on demand, then releases indexes when snapshots are replaced. Smart Alerts polls for expiring effects and timed quests every 10 seconds while enabled. No full bag scans run per frame, and bank slots are read only while the bank is accessible.

New SavedVariables live under **BaziUIDB.adventure** (schema 1), with `characters` and `journals` keyed by character GUID. Display and feature settings live under **profile.adventure** with the rest of Bazi UI's character settings. Unknown future schemas are left untouched. Journals cap sessions at 120 and limit detailed history by age and entry count. History and offline character records have separate explicit clear controls.

## Forever verification

The client still needs to confirm API support, tooltip rebuilds on Shift, native dialog integrations, the alert and preview layouts, and relevant protected/combat behavior. The API records consulted describe Blizzard's client interface. Optional data can vary in Forever. [Container API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua) · [Item API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua) · [Trade skill API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua) · [Quest log API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)

- Trainer ranks, objective proximity, permanent enchants, class-wide reagent inference, auction outcome alerts, historical kills, hardest hits and healing events still need independently verified Forever data and are outside the current setup. General consumables can use Dashboard's tracked supplies.
- Journey does not import history from before installation. PvP wins need a native match result and player team. Dungeon completion needs a native completion event. The observed run record measures time since entry when Bazi UI witnessed the entry.
- Bank and other alt data reflect the last readable snapshots. Recipe matching depends on a readable open profession panel. Mail, lockouts and owned auctions depend on native events and readable client data.

## Test order

1. Open each preview while its live feature is off. Verify Smart Alerts in Movers, the Journey timeline and scrolling, and Alt Manager's Copper Ore search.
2. Enable Journey and Smart Alerts. Complete a quest, gain a skill point, and reload. Check that the session is retained once and the alerts are not duplicated.
3. Enable Alt Manager. Visit a bank on one character, close it, and inspect the same item from an alt. Check bank timestamps, missing-bank behavior and Shift.

Offline validation uses Lua 5.1 parsing of the manifest and the simulated checks in `Tests/Adventure.lua` and `Tests/DashboardMovers.lua`.
