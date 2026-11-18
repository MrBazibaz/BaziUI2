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
function T:SetEditAnchor(enabled)
    if marker then marker:SetShown(not not enabled) end
end
function T:EditAnchor()
    if marker then self:SetEditAnchor(not marker:IsShown()) end
end
local function AddLine(label, value)
    if value and value ~= "" then tip:AddDoubleLine(label, tostring(value), 1, 0.79, 0.43, 1, 1, 1) end
end
local function UpdateHealth()
    local db = DB()
    if not db or not health then return end
    local unit = UnitToken()
    local mode = db.healthBar
    if not db.enabled or not unit or mode == "off" then
        health:Hide()
        if mode == "off" and tip and tip.StatusBar then tip.StatusBar:Hide() end
        if mode == "off" and _G.GameTooltipStatusBar then _G.GameTooltipStatusBar:Hide() end
        return
    end
    -- Retail/Forever can return secret health numbers. Do not compare,
    -- stringify or do arithmetic on them in addon-tainted execution.
    -- Blizzard's native tooltip status bar already handles secret values.
    local native = _G.GameTooltipStatusBar or tip.StatusBar
    if not native then health:Hide(); return end
    health:Hide()
    native:ClearAllPoints()
    if mode == "above" then
        native:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 6, 2)
        native:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -6, 2)
    elseif mode == "below" then
        native:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 6, -2)
        native:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", -6, -2)
    elseif mode == "insideTop" then
        native:SetPoint("TOPLEFT", tip, "TOPLEFT", 6, -5)
        native:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -6, -5)
    else
        native:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 6, 5)
        native:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -6, 5)
    end
    native:Show()
    return
    --[[ Legacy custom bar positioning (unused while secret values are enabled).
    local max = UnitHealthMax(unit)
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
    if _G.GameTooltipStatusBar then _G.GameTooltipStatusBar:Hide() end
    ]]
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
        tip:SetOwner(parent or UIParent, "ANCHOR_NONE")
        -- Position is updated against the cursor while the tooltip is visible.
    else
        tip:SetOwner(parent or UIParent, "ANCHOR_NONE")
        tip:ClearAllPoints()
        tip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", db.x or -30, db.y or 130)
    end
end
-- Temporary tooltip positioning diagnostics. Toggle with /run BaziUI.Tooltip:ToggleDebug()
local debugEnabled = false
local debugElapsed = 0
local debugTicks = 0
local function DebugLine(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc55Bazi Tooltip DEBUG:|r " .. message) end
end
function T:ToggleDebug()
    debugEnabled = not debugEnabled
    debugElapsed = 0
    debugTicks = 0
    DebugLine(debugEnabled and "ON (hover an NPC or item for 3 seconds)" or "OFF")
    local db = DB()
    DebugLine("enabled=" .. tostring(db and db.enabled) ..
        " anchor=" .. tostring(db and db.anchor) ..
        " cursorPosition=" .. tostring(db and db.cursorPosition) ..
        " tooltipShown=" .. tostring(tip and tip:IsShown()))
    DebugLine("driver=" .. tostring(self.cursorDriver ~= nil) ..
        " shown=" .. tostring(self.cursorDriver and self.cursorDriver:IsShown()) ..
        " onUpdate=" .. tostring(self.cursorDriver and self.cursorDriver:GetScript("OnUpdate") ~= nil))
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
    -- Keep Blizzard's bar until a valid custom unit bar can be displayed.
    hooksecurefunc("GameTooltip_SetDefaultAnchor", Anchor)
    -- Tooltip script support varies by client. An unsupported script must not
    -- abort initialization before the cursor positioning driver is created.
    local function TryHookTooltipScript(scriptName, handler)
        local ok, err = pcall(function() tip:HookScript(scriptName, handler) end)
        if not ok then
            DebugLine("skipping unsupported " .. scriptName .. ": " .. tostring(err))
        end
    end
    TryHookTooltipScript("OnTooltipSetUnit", UnitContent)
    TryHookTooltipScript("OnTooltipSetItem", ItemContent)
    TryHookTooltipScript("OnTooltipSetSpell", SpellContent)
    tip:HookScript("OnShow", function()
        local db = DB()
        if not db then return end
        if not db.enabled then tip:Hide(); return end
        T:Apply()
        UpdateHealth()
    end)
    tip:HookScript("OnHide", function() health:Hide() end)
    -- Use an independent update frame. GameTooltip itself can be reanchored by
    -- Blizzard/other addons and its own update handler is not reliable here.
    local cursorDriver = CreateFrame("Frame", nil, UIParent)
    local elapsedHealth = 0
    self.cursorDriver = cursorDriver
    cursorDriver:Show()
    cursorDriver:SetScript("OnUpdate", function(_, elapsed)
        if debugEnabled then
            debugTicks = debugTicks + 1
            debugElapsed = debugElapsed + elapsed
            if debugElapsed >= 2 then
                debugElapsed = 0
                local current = DB()
                local mx, my = GetCursorPosition()
                local p, relativeTo, relativePoint, px, py = tip:GetPoint(1)
                DebugLine("ticks=" .. debugTicks ..
                    " mode=" .. tostring(current and current.anchor) ..
                    " shown=" .. tostring(tip:IsShown()) ..
                    " mouse=" .. math.floor(mx) .. "," .. math.floor(my) ..
                    " point=" .. tostring(p) ..
                    " relative=" .. tostring(relativePoint) ..
                    " offsets=" .. tostring(px) .. "," .. tostring(py))
                debugTicks = 0
            end
        end
        local db = DB()
        if db and db.enabled and db.anchor == "mouse" and tip:IsShown() then
            local uiScale = UIParent:GetEffectiveScale()
            local mx, my = GetCursorPosition()
            mx, my = mx / uiScale, my / uiScale
            local point = db.cursorPosition or "BOTTOMRIGHT"
            -- The selected point refers to the tooltip corner nearest the cursor.
            -- Anchor that exact point; using the opposite corner makes the
            -- placement look identical for several dropdown choices.
            local valid = {
                TOPLEFT = true, TOP = true, TOPRIGHT = true,
                LEFT = true, RIGHT = true,
                BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true
            }
            if not valid[point] then point = "BOTTOMRIGHT" end
            -- Use one stable anchor and calculate the tooltip offset explicitly.
            -- This avoids client-specific reanchoring of TOP/RIGHT points.
            local width = tip:GetWidth() * tip:GetEffectiveScale() / uiScale
            local height = tip:GetHeight() * tip:GetEffectiveScale() / uiScale
            local x = mx + 14
            local y = my + 14
            if point:find("RIGHT") then x = mx - width - 14
            elseif point == "TOP" or point == "BOTTOM" then x = mx - width / 2 end
            if point:find("TOP") then y = my - height - 14
            elseif point == "LEFT" or point == "RIGHT" then y = my - height / 2 end
            tip:ClearAllPoints()
            tip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
        end
        elapsedHealth = elapsedHealth + elapsed
        if elapsedHealth >= 0.15 then
            elapsedHealth = 0
            UpdateHealth()
        end
    end)
    self:Apply()
end
