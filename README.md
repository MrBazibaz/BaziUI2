# Bazi UI

A modular World of Warcraft UI addon for the WoW Forever client.

## Visual design system

The in-game Blizzard Character Pane is the visual source of truth for BaziUI.

- All panels and windows must follow the Character Pane's existing palette, materials, borders, contrast, and overall visual language.
- Do not introduce a separate palette for individual modules. Spellbook, bags, quest log, minimap, and future modules should look like parts of the same interface.
- Interactive buttons use **Royal Purple** as the deliberate accent color. This is the primary exception to the Character Pane-derived palette.
- Do not guess or hard-code replacement panel colors from an unrelated palette. Sample or match the actual Character Pane artwork when implementing the theme.
- Preserve the familiar WoW layout and Blizzard character-pane identity; this is a coherent reskin, not a redesign of the interface.

### Design rule

> Character Pane defines the BaziUI visual identity. Royal Purple defines interactive buttons.

## Current foundation (0.1.0)

- /bazi and /bui open the configuration window.
- General page with initial UI scale and default font-size settings.
- Left-side navigation scaffold for planned modules.
- Theme tokens for the shared visual system and Royal Purple buttons.
- Saved global settings in BaziUIDB.

## Development notes

The current client build reported by the project owner is 1.60 / build 70938 / interface 16001. Compatibility must be tested in the actual WoW Forever client.

The initial options pages for modules other than General are navigation placeholders. No unit frames, nameplates, action bars, or other gameplay modules are implemented yet.

## License

License and third-party asset policy still need to be decided before public distribution.
