-- Bazi UI tooltip presentation ONLY.
-- Intentionally does not change tooltip lines, item level, health bars,
-- padding, fonts or inspect hooks. Those belong to their stable modules.
local addon = BaziUI
addon.Tooltip = addon.Tooltip or {}
local T = addon.Tooltip
local tip = GameTooltip
local marker

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
local function ApplyBackgroundOpacity(alpha)
    -- Set opacity on the artwork, never on GameTooltip itself: the latter
    -- fades text and the Blizzard status bar too.
    local regions = {tip:GetRegions()}
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(alpha)
        end
    end
    if tip.NineSlice then tip.NineSlice:SetAlpha(alpha) end
end
function T:Apply()
    if not tip then return end
    local db = DB()
    if not db then return end
    if not db.enabled then
        tip:SetScale(1)
        tip:SetAlpha(1)
        ApplyBackgroundOpacity(1)
        if marker then marker:Hide() end
        return
    end
    tip:SetScale(SafeNumber(db.scale, 1))
    if marker and not marker:IsShown() then
        marker:ClearAllPoints()
        marker:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
            SafeNumber(db.x, -30), SafeNumber(db.y, 130))
    end
    tip:SetAlpha(1)
    ApplyBackgroundOpacity(SafeNumber(db.opacity, 1))
end
function T:SetEditAnchor(enabled)
    if not marker then return end
    local db = DB()
    marker:SetShown(not not enabled and db and db.enabled and db.anchor ~= "mouse")
end
function T:EditAnchor()
    if marker then self:SetEditAnchor(not marker:IsShown()) end
end
function T:Initialize()
    if self.initialized then return end
    self.initialized = true
    marker = CreateFrame("Button", nil, UIParent)
    marker:SetSize(180, 36)
    marker:SetFrameStrata("DIALOG")
    marker:EnableMouse(true)
    marker:SetMovable(true)
    marker:RegisterForDrag("LeftButton")
    local bg = marker:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.24, 0.12, 0.05, 0.9)
    local label = marker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText("Bazi Tooltip Anchor")
    marker:SetScript("OnDragStart", function(self) self:StartMoving() end)
    marker:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local db = DB()
        if db then
            local right, bottom = self:GetRight(), self:GetBottom()
            local parentRight, parentBottom = UIParent:GetRight(), UIParent:GetBottom()
            if right and bottom and parentRight and parentBottom then
                db.x = math.floor(right - parentRight + 0.5)
                db.y = math.floor(bottom - parentBottom + 0.5)
            end
        end
    end)
    local db = DB()
    marker:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
        SafeNumber(db and db.x, -30), SafeNumber(db and db.y, 130))
    marker:Hide()
    hooksecurefunc("GameTooltip_SetDefaultAnchor", ApplyAnchor)
    tip:HookScript("OnShow", function()
        T:Apply()
    end)
    self:Apply()
end
