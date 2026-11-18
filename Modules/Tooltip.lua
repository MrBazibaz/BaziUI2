local addon = BaziUI
addon.Tooltip = addon.Tooltip or {}
local T = addon.Tooltip
local tip = GameTooltip
local pending = 0
local marker
local health
local function DB()
    return addon.db and addon.db.profile and addon.db.profile.tooltip
end
local function UnitToken()
    local _, unit = tip:GetUnit()
    return unit and UnitExists(unit) and unit or nil
end
local function SetFont(fontString, config)
    if not fontString or not config then return end
    local path = config.font == "FRIZQT" and "Fonts\\FRIZQT__.TTF"
        or config.font == "ARIAL" and "Fonts\\ARIALN.TTF"
        or config.font == "MORPHEUS" and "Fonts\\MORPHEUS.TTF"
        or "Fonts\\FRIZQT__.TTF"
    local outline = config.outline == "OUTLINE" and "OUTLINE"
        or config.outline == "THICKOUTLINE" and "THICKOUTLINE" or ""
    fontString:SetFont(path, config.size or 13, outline)
    if config.shadow then
        fontString:SetShadowColor(0, 0, 0, 0.9)
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowOffset(0, 0)
    end
end
function T:Apply()
    local db = DB()
    if not db then return end
    if tip then
        tip:SetScale(db.scale or 1)
        tip:SetAlpha(db.opacity or 1)
    end
    if marker then
        marker:ClearAllPoints()
        marker:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", db.x or -30, db.y or 130)
    end
    if tip and tip.NineSlice then tip.NineSlice:SetAlpha(db.opacity or 1) end
    for i = 1, 30 do
        local left = _G["GameTooltipTextLeft" .. i]
        local right = _G["GameTooltipTextRight" .. i]
        SetFont(left, i == 1 and db.titleFont or db.textFont)
        SetFont(right, db.textFont)
    end
end
function T:MarkReload()
    pending = pending + 1
    if addon.Options and addon.Options.RefreshReload then addon.Options:RefreshReload() end
end
function T:Pending() return pending end
function T:EditAnchor()
    if not marker then return end
    marker:SetShown(not marker:IsShown())
end
local function AddLine(label, value)
    if value and value ~= "" then tip:AddDoubleLine(label, tostring(value), 1, 0.79, 0.43, 1, 1, 1) end
end
local function UpdateHealth()
    local db = DB()
    if not db or not health then return end
    local unit = UnitToken()
    local mode = db.healthBar
    if not db.enabled or not unit or mode == "off" then health:Hide(); return end
    local max = UnitHealthMax(unit)
    if not max or max <= 0 then health:Hide(); return end
    health:SetMinMaxValues(0, max)
    health:SetValue(UnitHealth(unit))
    health:ClearAllPoints()
    if mode == "above" then
        health:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 6, 2)
        health:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -6, 2)
    elseif mode == "below" then
        health:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 6, -2)
        health:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", -6, -2)
    elseif mode == "insideTop" then
        health:SetPoint("TOPLEFT", tip, "TOPLEFT", 6, -5)
        health:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -6, -5)
    else
        health:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 6, 5)
        health:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -6, 5)
    end
    health:Show()
end
local function UnitContent()
    local db = DB()
    if not db or not db.enabled then return end
    local unit = UnitToken()
    if not unit then return end
    if db.guild then
        local guild = GetGuildInfo(unit)
        if guild then AddLine("Guild", guild) end
    end
    if db.targetTarget then
        local target = unit .. "target"
        if UnitExists(target) then AddLine("Target", UnitName(target)) end
    end
    if db.threat and UnitDetailedThreatSituation then
        local _, status, percent = UnitDetailedThreatSituation("player", unit)
        if status and percent then AddLine("Threat", string.format("%.0f%%", percent)) end
    end
    if db.classNames and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        local name = _G.GameTooltipTextLeft1
        if color and name then name:SetTextColor(color.r, color.g, color.b) end
    end
    if db.hideFaction then
        -- Faction line varies by client; leave Blizzard's unit text intact rather than deleting unrelated lines.
    end
    tip:Show()
    UpdateHealth()
end
local function ItemContent()
    local db = DB()
    if not db or not db.enabled then return end
    local _, link = tip:GetItem()
    if not link then return end
    local id = tonumber(link:match("item:(%d+)"))
    if db.ids and id then AddLine("Item ID", id) end
    if db.itemLevel then
        local level = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)
        if level then AddLine("Item Level", level) end
    end
    tip:Show()
end
local function SpellContent()
    local db = DB()
    if not db or not db.enabled or not db.ids then return end
    local _, id = tip:GetSpell()
    if id then AddLine("Spell ID", id); tip:Show() end
end
local function Anchor(_, parent)
    local db = DB()
    if not db or not db.enabled then return end
    if db.anchor == "mouse" then
        tip:SetOwner(parent or UIParent, "ANCHOR_CURSOR_RIGHT")
    else
        tip:SetOwner(parent or UIParent, "ANCHOR_NONE")
        tip:ClearAllPoints()
        tip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", db.x or -30, db.y or 130)
    end
end
function T:Initialize()
    if self.initialized then return end
    self.initialized = true
    marker = CreateFrame("Button", nil, UIParent)
    marker:SetSize(170, 34)
    marker:SetFrameStrata("TOOLTIP")
    marker:EnableMouse(true)
    marker:SetMovable(true)
    marker:RegisterForDrag("LeftButton")
    local bg = marker:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.24, 0.12, 0.05, 0.85)
    local label = marker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText("Bazi Tooltip Anchor")
    marker:SetScript("OnDragStart", function(self) self:StartMoving() end)
    marker:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local db = DB()
        if db then
            db.x = math.floor((self:GetRight() - UIParent:GetRight()) + 0.5)
            db.y = math.floor((self:GetBottom() - UIParent:GetBottom()) + 0.5)
        end
    end)
    marker:Hide()
    health = CreateFrame("StatusBar", nil, tip)
    health:SetHeight(7)
    health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    health:SetStatusBarColor(0.28, 0.78, 0.35)
    health:Hide()
    if _G.GameTooltipStatusBar then
        _G.GameTooltipStatusBar:HookScript("OnShow", function(self)
            local db = DB()
            if db and db.enabled and db.healthBar ~= "off" then self:Hide() end
        end)
    end
    hooksecurefunc("GameTooltip_SetDefaultAnchor", Anchor)
    tip:HookScript("OnTooltipSetUnit", UnitContent)
    tip:HookScript("OnTooltipSetItem", ItemContent)
    tip:HookScript("OnTooltipSetSpell", SpellContent)
    tip:HookScript("OnShow", function()
        local db = DB()
        if not db then return end
        if not db.enabled then tip:Hide(); return end
        T:Apply()
        UpdateHealth()
    end)
    tip:HookScript("OnHide", function() health:Hide() end)
    self:Apply()
end
