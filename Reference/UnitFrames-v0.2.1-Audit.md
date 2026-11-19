# Bazi UI v0.2.1 — Unit Frames integration audit

Source inspected: user-provided FlareUI(9).zip (2026-11-19). Target is ONLY the "FlareUI" frame style shown by the user, not Forever/Addon styles.

## Source files (must be evaluated as a system)
- Modules/UnitFrames.lua (5,871 lines): player, target, focus, pet, target-of-target, focus-target, castbar, portraits, health/power, auras, fonts.
- Modules/UnitFramesRing.lua: style selection/initialization and frame configuration.
- Modules/UnitFramesDoesItDie.lua: death/status helpers.
- Modules/PartyFrames.lua, RaidFrames.lua, BossFrames.lua, FlagCarriers.lua: independent group/battleground frame implementations.
- Modules/Visibility.lua: per-frame fading and visibility.
- Settings/Pages/UnitFrames.lua: source settings schema; two tabs (settings/fonts), shared main-unit switch, separate castbar/party/raid/boss/tot/tof/flag-carrier switches, colors, full names, simple pet, simple target-of, aura shape/swipe/timer, per-frame fonts.
- Settings/Fonts.lua, Settings/Registry.lua, Settings/EditModeLayout.lua, Libs/FlareEditMode, LibSharedMedia: dependencies, not safe to omit without replacements.

## Integration constraints
- Preserve current Bazi UI options, theme, minimap, tooltip, and existing approved artwork.
- Use modular files for unit frame runtime, frame-specific layouts, visibility, font settings, and Bazi UI settings tabs.
- Build the FlareUI style only; avoid copying other styles.
- Match frame appearance and behaviors, but do not copy FlareUI/Media/Art, Media/Bars, Media/Icons: excluded by FlareUI/LICENSE.txt.
- FlareUI-owned code is MIT licensed (copyright 2026 Malkkav); retain its copyright and license if source is reused.
- Avoid guessing Forever API names. Preserve protected-frame/combat rules.
- Toggles must respect reload requirements for frames created at login.
- Verify in-game each frame category and font setting before calling v0.2.1 finished.

## Implementation order
1. Resolve runtime dependencies and license/asset substitutions; define Bazi UI DB schema and migration.
2. Implement player/target/focus/pet/tot/tof and player cast bar in FlareUI style.
3. Integrate party/raid/boss/flag carriers.
4. Port all applicable FlareUI settings to Bazi UI styled subpages (Frames, Appearance, Visibility, Fonts, Position & Size); per-frame font editor and copy-to-all.
5. Test combat, reload, profile persistence, unit transitions, protected actions, and display scaling.

Status: audit only. No unit frame runtime or settings shipped yet.
