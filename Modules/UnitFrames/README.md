# UnitFrames

Planned layout:

- `Init.lua` - module entry point.
- `Master.lua` - coordinates creation and registration; does not contain every frame's implementation.
- `Player.lua`, `Target.lua`, etc. - individual unit frame layouts.
- `Elements/` - reusable components such as health, power, name, portrait, castbar and auras.

Each frame should compose shared elements rather than reimplement them.
