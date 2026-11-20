# Bazi UI – Master Module Development Guidelines

**Project:** Bazi UI – World of Warcraft Forever  
**Repository:** https://github.com/MrBazibaz/BaziUI2  
**Purpose:** Keep every module visually and functionally consistent with approved Bazi UI implementations.

## 1. Core principle

**DO NOT REINVENT ANYTHING THAT ALREADY WORKS.**

Inspect existing, approved implementations before writing code. Reuse the actual patterns, assets and behavior rather than approximating their appearance or introducing generic Blizzard controls. Bazi UI is one coherent interface, not a collection of independently designed addons.

## 2. Reference modules are read-only

Inspect **Tooltip**, **UnitFrames**, **Minimap**, and their configuration implementations as appropriate. Other approved modules may also serve as references.

Allowed: read code, compare behavior, reuse artwork, copy proven implementations into the active module.

Forbidden without explicit approval: modify reference modules, refactor them, change shared systems that affect them, or include unrelated edits in a commit.

## 3. Scope and locked modules

Before every task identify:

- **ACTIVE MODULE:** [name]
- **ALLOWED FILES:** [paths]
- **REQUESTED CHANGES:** [details]
- **REFERENCE MODULES:** [read-only references]
- **LOCKED MODULES:** all others, including previously approved modules

Only edit explicitly authorized files. Completed modules are **LOCKED – APPROVED – DO NOT MODIFY** until the project owner explicitly unlocks them. This includes PartyFrames, BossFrames, RaidFrames and Friendly Player Nameplates whenever they are outside the active scope. A bug or improvement opportunity elsewhere is not permission to edit it.

If an out-of-scope change seems necessary, explain the reason and obtain permission **before editing or committing**.

## 4. Visual identity

Follow the established WoW-inspired **gold/bronze** artwork and **royal-purple** accents. Match approved backgrounds, borders, corners, typography, dimensions, spacing, states and alignment. Preserve locked outer borders, corners, window shadow, resize system and transparency behavior.

**Buttons:** reuse approved Bazi UI implementations for standard, toggle, reset, dropdown and +/- controls. Match shape, texture, border, hover, pressed and disabled states. Never substitute generic square or Blizzard buttons when an approved control exists.

**Scrollbars:** always use the approved **crystal thumb artwork**, track, proportions and behavior. No generic scrollbar designs.

**Settings layout:** copy proven section headers, spacing, label alignment, numeric input widths, grouping and responsive/resizable-window behavior. Avoid decorative panels and borders that the approved design does not use.

## 5. Coordinate and numeric controls

Every coordinate field, and applicable numeric fields, must:

- Be directly editable using the keyboard.
- Allow clicking to select the entire value and support Ctrl+A.
- Prefer automatically selecting all text on focus when the established implementation does.
- Apply valid values **live**, without closing the menu, switching tabs or reloading where technically possible.
- Reject or revert invalid values without corrupting settings.
- Display the actual current setting, including after updates.
- Have adjacent matching **− / + buttons** that use the established increment, respect limits and update both field and UI immediately.

Copy the working input and button behavior from the nearest approved module. Do not invent increments, bounds or a new editing interaction.

## 6. Preserve approved behavior

Never change unrelated positioning, sizes, artwork, visibility logic, saved variables, profile handling, control behavior or approved layout. Visual tasks must not silently alter functionality, and functional tasks must not redesign visuals.

Where the active module contains a working feature, prefer a small targeted patch over rewriting it.

## 7. Required workflow

### Step 1 – Inspect
Read the active module, relevant options/config files, and the closest read-only references. Identify the actual reusable functions, assets, anchors, masks and control patterns. Check the current repository state.

### Step 2 – Confirm scope before editing
Briefly explain which files will change, which approved implementation will be copied, what will remain untouched and any uncertainty. Ask before guessing when the requirement is ambiguous.

### Step 3 – Implement minimally
Make only the requested change in allowed files. Reuse established controls and artwork. Do not perform opportunistic cleanup or unrelated refactors.

### Step 4 – Verify before commit
Check Lua syntax where tooling permits, function/asset references, saved-setting behavior, live update wiring and the changed-file list. Compare against reference implementations. Never claim in-game success without an actual in-game test.

### Step 5 – Commit
Commit only in-scope files with a descriptive message. Provide the commit link/hash and an accurate change summary. Do not commit unrelated changes.

### Step 6 – Validate in-game
Wait for the owner's screenshot or test results. If something fails, inspect the current code and isolate the cause before changing values. Change one relevant variable at a time, not five speculative adjustments.

## 8. Artwork and deployment

Search existing Bazi UI assets before introducing new ones. Verify dimensions, transparency, client-compatible formats and exact runtime paths. Confirm assets are present **locally in the installed WoW addon**, not merely on GitHub.

The project's quick deployment script may **skip Assets**. Whenever a task adds or modifies artwork, explicitly require the **full deployment script** and a complete client restart where necessary. Check this before debugging missing textures.

## 9. Debugging

Before changing code, check:

1. Are we editing the correct active module?
2. Is the newest code installed locally?
3. Are required assets installed locally?
4. Does the current implementation match the reference?
5. Is the issue actually a texture, mask, anchor, layer, scale or state problem?

Use isolated, removable diagnostics if necessary. Do not hide a broken texture or anchor behind repeated arbitrary scaling changes.

## 10. Completion and locking

A module is complete only after visual approval, in-game functional verification, correct settings behavior and explicit owner confirmation. Mark it **LOCKED – APPROVED – DO NOT MODIFY**. Locked modules remain available as read-only references.

## 11. Non-negotiable rules

1. Copy what works; do not reinvent.
2. Never modify a module outside the active scope.
3. Never modify locked modules without explicit approval.
4. All buttons use approved Bazi UI styling.
5. All scrollbars use the crystal artwork.
6. Coordinate fields are editable, selectable, live-updating and have matching +/- controls.
7. Preserve existing visuals, behavior and saved settings.
8. Inspect first, verify before commit, validate in-game afterward.
9. Never confuse GitHub availability with local WoW installation.
10. Never claim something is tested in-game unless it has been tested there.

---

## Template for the next development task

**ACTIVE MODULE:** [MODULE NAME]  
**ALLOWED FILES:** [PATHS]  
**REQUESTED CHANGES:** [DESCRIPTION]  
**REFERENCE MODULES:** Tooltip, UnitFrames, Minimap and other relevant approved modules (READ ONLY)  
**LOCKED MODULES:** All other modules

**Required first response:** confirm the exact edit scope, existing code/assets to reuse, locked modules that will remain untouched and how the plan preserves the approved design. Do not modify or commit code until this inspection and scope confirmation are complete.

**FINAL PRINCIPLE: Copy what works. Preserve what is approved. Change only what is requested.**
