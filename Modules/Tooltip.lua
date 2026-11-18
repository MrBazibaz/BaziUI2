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
-- FlareUI pattern: Blizzard's status bar owns secure values and must
-- never be moved. Our bar is independent and tooltip padding is conditional.
local healthMode
local padded = false
local function SafeToPad()
    if not tip or (tip.IsForbidden and tip:IsForbidden()) then return false end
    local width = tip:GetWidth()
    if issecretvalue and issecretvalue(width) then return false end
    if canaccessvalue and not canaccessvalue(width) then return false end
    for i = 1, tip:GetNumChildren() do
        local child = select(i, tip:GetChildren())
        if child and child.shownWidgetCount and issecretvalue
            and issecretvalue(child.shownWidgetCount) then return false end
    end
    return true
end
local function ResetInsideSpacing()
    if padded and tip.SetPadding then pcall(tip.SetPadding, tip, 0, 0) end
    padded = false
end
local function ApplyInsideSpacing(mode)
    if mode ~= "insideBottom" or not SafeToPad() or not tip.SetPadding then
        ResetInsideSpacing()
        return
    end
    if not padded then
        local ok = pcall(tip.SetPadding, tip, 0, 12)
        padded = ok
    end
end
local function SetNativeBarHidden(hidden)
    local native = _G.GameTooltipStatusBar
    local attached = tip and tip.StatusBar
    for _, bar in ipairs({native, attached}) do
        if bar then
            if hidden then
                bar:Hide()
            else
                bar:SetAlpha(1)
            end
        end
    end
end
local function UpdateHealth()
    local db = DB()
    if not db or not health then return end
    local unit = UnitToken()
    local mode = db.healthBar
    if not db.enabled or not unit or mode == "off" then
        ResetInsideSpacing()
        healthMode = nil
        health:Hide()
        SetNativeBarHidden(db.enabled and mode == "off")
        return
    end
    -- FlareUI approach: never reanchor Blizzard's native status bar.
    -- Its secure health values and layout belong to Blizzard.
    local native = _G.GameTooltipStatusBar or tip.StatusBar
    if not native then return end
    local guid = native.GetAttribute and native:GetAttribute("guid")
    if not guid or not UnitPercentHealthFromGUID then
        health:Hide()
        ResetInsideSpacing()
        return
    end
    local ok, value = pcall(UnitPercentHealthFromGUID, guid)
    if not ok or value == nil then
        health:Hide()
        ResetInsideSpacing()
        healthMode = nil
        return
    end
    -- Dead units should not reserve a health-bar row.
    local deadOK, dead = pcall(UnitIsDeadOrGhost, unit)
    if deadOK and (not issecretvalue or not issecretvalue(dead))
        and (not canaccessvalue or canaccessvalue(dead)) and dead then
        health:Hide()
        ResetInsideSpacing()
        healthMode = nil
        SetNativeBarHidden(true)
        return
    end
    -- Secret percentages may be passed directly to SetValue; never compare them.
    -- Unit-frame tooltips contain an extra Blizzard frame-settings hint.
    -- That hint occupies the bottom inset and cannot safely share it.
    local placement = mode
    if mode == "insideBottom" and not SafeToPad() then
        placement = "below"
    end
    local modeChanged = healthMode ~= placement
    if modeChanged then
        healthMode = placement
        health:ClearAllPoints()
    end
    ApplyInsideSpacing(placement)
    -- Anchor both ends to the frame instead of calculating widths/offsets.
    -- Tooltip font-string geometry can be secret on WoW Forever.
    if modeChanged then
        if placement == "above" then
            health:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 10, 2)
            health:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -10, 2)
        elseif placement == "below" then
            health:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 10, 0)
            health:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", -10, 0)
        elseif placement == "insideTop" then
            health:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -10)
            health:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -10, -10)
        else
            health:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 10, 6)
            health:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -10, 6)
        end
    end
    -- Do not manually resize GameTooltip on health ticks. Blizzard rebuilds
    -- its layout for unit changes; changing height here causes oscillation.
    -- pcall protects against secret-value restrictions on specific client builds.
    local setOK = pcall(health.SetValue, health, value)
    if not setOK then health:Hide(); return end
    SetNativeBarHidden(true)
    health:Show()

end

local function Readable(v)
    return v ~= nil and (not issecretvalue or not issecretvalue(v))
        and (not canaccessvalue or canaccessvalue(v))
end
local function FindLine(fragment)
    if not Readable(fragment) or type(fragment) ~= "string" then return false end
    for i = 2, tip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local value = line and line:GetText()
        if Readable(value) and type(value) == "string" and value:find(fragment, 1, true) then return true end
    end
    return false
end
local function RemoveLine(fragment, exact)
    if not Readable(fragment) or type(fragment) ~= "string" or fragment == "" then return end
    for i = 2, tip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local value = line and line:GetText()
        if Readable(value) and type(value) == "string"
            and ((exact and value == fragment) or (not exact and value:find(fragment, 1, true))) then
            line:SetText(nil)
            return
        end
    end
end
-- Reserve a real text row for the bar. Unlike SetPadding, this participates
-- in Blizzard's own tooltip height calculation and works with unit-frame hints.
-- FlareUI removes the frame-settings hint and its preceding blank line.
-- The hint is not unit data and otherwise occupies the health bar inset.
local function ScrubFrameHint()
    -- Unit-frame tooltips add a green hint that Blizzard places at the
    -- bottom, where our custom inside-bottom health bar belongs.
    -- The old equality check against UNIT_POPUP_RIGHT_CLICK never matched
    -- the actual "Right click for Frame Settings" text.
    for i = tip:NumLines(), 2, -1 do
        local line = _G["GameTooltipTextLeft" .. i]
        local value = line and line:GetText()
        if Readable(value) and type(value) == "string"
            and (value:find("Frame Settings", 1, true)
                or value:find("Right click for", 1, true)) then
            line:SetText("")
            line:Hide()
            -- The preceding empty separator is also unnecessary.
            local previous = _G["GameTooltipTextLeft" .. (i - 1)]
            local prior = previous and previous:GetText()
            if Readable(prior) and (prior == "" or prior == " ") then
                previous:SetText("")
                previous:Hide()
            end
        end
    end
end
local function UnitContent()
    local db = DB()
    if not db or not db.enabled then return end
    local unit = UnitToken()
    if not unit then return end
    if not db.guild then RemoveLine(GetGuildInfo(unit), false) end
    if db.hideFaction then
        RemoveLine(_G.FACTION_HORDE, true)
        RemoveLine(_G.FACTION_ALLIANCE, true)
    end
    if db.targetTarget then
        local target = unit .. "target"
        local ok, exists = pcall(UnitExists, target)
        if ok and Readable(exists) and exists then
            local name = UnitName(target)
            local prefix = (_G.TARGET or "Target") .. ": "
            if Readable(name) and type(name) == "string" and name ~= "" and not FindLine(prefix) then
                tip:AddLine(prefix .. name, 0.95, 0.80, 0.50)
            end
        end
    end
    if db.classNames then
        local ok, player = pcall(UnitIsPlayer, unit)
        if ok and Readable(player) and player then
            local _, class = UnitClass(unit)
            local color = Readable(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            local title = _G.GameTooltipTextLeft1
            if color and title then title:SetTextColor(color.r, color.g, color.b) end
        end
    end
    if addon.ItemLevel then addon.ItemLevel:OnUnit() end
    ScrubFrameHint()
    UpdateHealth()
end
local function ItemContent(_, data)
    local db = DB()
    if not db or not db.enabled then return end
    local _, link = tip:GetItem()
    if not Readable(link) then link = nil end
    if db.ids then
        local id = data and data.id
        if not Readable(id) then id = link and tonumber(link:match("item:(%d+)")) end
        if Readable(id) and type(id) == "number" and not FindLine("Item ID") then
            tip:AddDoubleLine(" ", "Item ID " .. id, 1, 1, 1, 0.6, 0.6, 0.6)
        end
    end
    if db.itemLevel then
        local id = data and data.id
        if not Readable(id) then id = link and tonumber(link:match("item:(%d+)")) end
        local level
        local getter = GetDetailedItemLevelInfo or (C_Item and C_Item.GetDetailedItemLevelInfo)
        if getter then
            local ok, result = pcall(getter, link or id)
            if ok and Readable(result) and type(result) == "number" then level = result end
        end
        if level and level > 1 and not FindLine("Item Level")
            and not FindLine("iLvl") then
            tip:AddLine(string.format("Item Level %d", level), 1, 0.82, 0.42)
        end
    end
    if tip:IsShown() then tip:Show() end
end
local function SpellContent(_, data)
    local db = DB()
    if not db or not db.enabled or not db.ids then return end
    local id = data and data.id
    if not Readable(id) then
        local _, spellID = tip:GetSpell()
        id = spellID
    end
    if Readable(id) and type(id) == "number" and not FindLine("Spell ID") then
        tip:AddDoubleLine(" ", "Spell ID " .. id, 1, 1, 1, 0.6, 0.6, 0.6)
        if tip:IsShown() then tip:Show() end
    end
end
-- Use Blizzard's cursor anchors instead of reanchoring GameTooltip each frame.
-- Native anchoring keeps the tooltip in the same coordinate system as its owner.
local cursorAnchors = {
    LEFT = "ANCHOR_CURSOR_RIGHT",
    RIGHT = "ANCHOR_CURSOR_LEFT",
}
local function Anchor(_, parent)
    local db = DB()
    if not db or not db.enabled then return end
    if db.anchor == "mouse" then
        local pos = db.cursorPosition
        local anchor = (pos == "LEFT" or pos == "TOPLEFT" or pos == "BOTTOMLEFT")
            and cursorAnchors.LEFT or cursorAnchors.RIGHT
        tip:SetOwner(parent or UIParent, anchor)
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
    health:SetMinMaxValues(0, 1)
    health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    health:SetStatusBarColor(0.28, 0.78, 0.35)
    health:Hide()
    -- Suppress native bar as soon as Blizzard shows it, before the next tick.

    hooksecurefunc("GameTooltip_SetDefaultAnchor", Anchor)
    -- Tooltip script support varies by client. An unsupported script must not
    -- abort initialization before the cursor positioning driver is created.
    local function TryHookTooltipScript(scriptName, handler)
        local ok, err = pcall(function() tip:HookScript(scriptName, handler) end)
        if not ok then
            DebugLine("skipping unsupported " .. scriptName .. ": " .. tostring(err))
        end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType then
        local add = TooltipDataProcessor.AddTooltipPostCall
        add(Enum.TooltipDataType.Unit, function(frame) if frame == tip then UnitContent() end end)
        add(Enum.TooltipDataType.Item, function(frame, data) if frame == tip then ItemContent(frame, data) end end)
        add(Enum.TooltipDataType.Spell, function(frame, data) if frame == tip then SpellContent(frame, data) end end)
        if Enum.TooltipDataType.UnitAura then
            add(Enum.TooltipDataType.UnitAura, function(frame, data) if frame == tip then SpellContent(frame, data) end end)
        end
        if TooltipDataProcessor.AddLinePreCall and Enum.TooltipDataLineType
            and Enum.TooltipDataLineType.UnitThreat then
            TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.UnitThreat, function()
                local db = DB()
                if db and db.enabled and not db.threat then return true end
            end)
        end
    else
        TryHookTooltipScript("OnTooltipSetUnit", UnitContent)
        TryHookTooltipScript("OnTooltipSetItem", ItemContent)
        TryHookTooltipScript("OnTooltipSetSpell", SpellContent)
    end
    tip:HookScript("OnShow", function()
        local db = DB()
        if not db then return end
        if not db.enabled then SetNativeBarHidden(false); return end
        T:Apply()
        UpdateHealth()
    end)
    tip:HookScript("OnHide", function()
        health:Hide()
        healthMode = nil
        ResetInsideSpacing()
        if addon.ItemLevel then addon.ItemLevel:ResetTooltipRow() end
    end)
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
        elapsedHealth = elapsedHealth + elapsed
        if elapsedHealth >= 0.15 then
            elapsedHealth = 0
            UpdateHealth()
        end
    end)
    self:Apply()
end
