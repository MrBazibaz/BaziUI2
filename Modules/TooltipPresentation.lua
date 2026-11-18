-- Bazi UI tooltip presentation ONLY.
-- Intentionally does not change tooltip lines, item level, health bars,
-- padding, fonts or inspect hooks. Those belong to their stable modules.
local addon = BaziUI
addon.Tooltip = addon.Tooltip or {}
local T = addon.Tooltip
local tip = GameTooltip

local function DB()
    return addon.db and addon.db.profile and addon.db.profile.tooltip
end
local function Allowed()
    local db = DB()
    return db and db.enabled
end
local function SafeNumber(value, fallback)
    if type(value) ~= "number" then return fallback end
    if issecretvalue and issecretvalue(value) then return fallback end
    if canaccessvalue and not canaccessvalue(value) then return fallback end
    return value
end
local function CursorSide(db)
    return (db.cursorPosition == "RIGHT" or db.cursorPosition == "TOPRIGHT") and "ANCHOR_CURSOR_RIGHT" or "ANCHOR_CURSOR_LEFT"
end
local function ApplyAnchor(tooltip, owner)
    if tooltip ~= tip or not Allowed() then return end
    local db = DB()
    if not owner then return end
    if db.anchor == "mouse" then
        -- Native cursor anchor tracks movement without a custom OnUpdate.
        tooltip:SetOwner(owner, CursorSide(db))
    else
        tooltip:SetOwner(owner, "ANCHOR_NONE")
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
            SafeNumber(db.x, -30), SafeNumber(db.y, 130))
    end
end
function T:Apply()
    if not tip then return end
    local db = DB()
    if not db then return end
    if not db.enabled then
        tip:SetScale(1)
        tip:SetAlpha(1)
        return
    end
    tip:SetScale(SafeNumber(db.scale, 1))
    tip:SetAlpha(SafeNumber(db.opacity, 1))
end
function T:SetEditAnchor() end
function T:Initialize()
    if self.initialized then return end
    self.initialized = true
    hooksecurefunc("GameTooltip_SetDefaultAnchor", ApplyAnchor)
    tip:HookScript("OnShow", function()
        T:Apply()
    end)
    self:Apply()
end
