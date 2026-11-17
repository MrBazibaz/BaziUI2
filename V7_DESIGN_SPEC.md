# Bazi UI V7 — Reforged Interface

## Visual target
Recreate the approved concept image as closely as WoW Forever's UI API permits. The reference is a visual target, not a texture atlas to crop.

## Layout
- Header: B emblem, large Bazi UI title, version, Settings, Profiles, Import / Export, What's New, search field, close control.
- Left sidebar: narrow dark plum panel with small gold icons and grouped headings GENERAL, GAMEPLAY, INTERFACE.
- Main area: violet-tinted Realm Configuration illustrated banner, then Appearance section with compact setting rows.
- Controls: existing purple crystal handles, slim gold tracks, right-aligned numeric readouts, gold section dividers.
- Footer: gold/plum divider and automatic-save status.
- Color palette: near-black plum surfaces, restrained violet highlights, warm gold text and borders; avoid bright magenta.

## Implementation milestones
1. Build layout and reusable frame/button/section/row components using WoW Forever-supported Lua APIs.
2. Create individually exportable artwork assets (not screenshots/crops), including a seamless banner, panel borders and icons.
3. Wire existing categories and sliders to the new UI; preserve saved settings.
4. Implement top-level Profiles, Import / Export, What's New and Search functionality.
5. Add future Lueur integration as an original module with optional side controls.
6. Verify at different UI scales and in the actual client before merging to main.

## Safety
- All development on feature/v7-reforged-interface.
- Do not modify main until the user approves an in-game test.
- No nonfunctional controls presented as working.
- Do not copy FlareUI or Lueur assets or code without confirming compatible license/permission.
