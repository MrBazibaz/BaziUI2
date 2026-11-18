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
-- Keep the native bar (secret unit health values are not readable by addons).
-- Reapply only on mode changes; never accumulate tooltip padding.
local insideMode, insideTipHeight, insideFirstAnchor
local insideBottomPadded = false
local healthMode
-- Keep Blizzard's bar transparent while our overlay is active. Blizzard can
-- reapply alpha when changing units, so verify the state rather than caching it.
local function SetNativeBarHidden(hidden)
    -- Forever can expose distinct Blizzard status bars on these two fields.
    -- Preserve their values and anchors; suppress only their visual alpha.
    local native = _G.GameTooltipStatusBar
    local attached = tip and tip.StatusBar
    local desired = hidden and 0 or 1
    if native and native:GetAlpha() ~= desired then native:SetAlpha(desired) end
    if attached and attached ~= native and attached:GetAlpha() ~= desired then
        attached:SetAlpha(desired)
    end
end
local function ResetInsideSpacing()
    if insideBottomPadded then
        if tip.SetPadding then pcall(tip.SetPadding, tip, 0, 0) end
        insideBottomPadded = false
    end
    if insideFirstAnchor then
        local first = _G.GameTooltipTextLeft1
        if first then
            first:ClearAllPoints()
            first:SetPoint(unpack(insideFirstAnchor))
        end
        insideFirstAnchor = nil
    end
    if insideTipHeight then tip:SetHeight(insideTipHeight); insideTipHeight = nil end
    insideMode = nil
end
local function ApplyInsideSpacing(mode, native)
    if insideMode == mode then return end
    ResetInsideSpacing()
    if mode ~= "insideTop" and mode ~= "insideBottom" then return end
    insideMode = mode
    if mode == "insideBottom" then
        -- Reserve bottom space INSIDE the native tooltip frame, so the gold
        -- backdrop extends beneath the bar rather than the bar protruding.
        if tip.SetPadding then
            local ok = pcall(tip.SetPadding, tip, 0, 14)
            if ok then insideBottomPadded = true end
        end
        return
    end
    local first = _G.GameTooltipTextLeft1
    if not first then return end
    local point, relative, relativePoint, x, y = first:GetPoint(1)
    if not point then return end
    local barHeight = native:GetHeight()
    if not barHeight or barHeight <= 0 then barHeight = 7 end
    local extra = barHeight + 2
    insideTipHeight = tip:GetHeight()
    tip:SetHeight(insideTipHeight + extra)
    insideFirstAnchor = {point, relative, relativePoint, x, y}
    first:ClearAllPoints()
    first:SetPoint(point, relative, relativePoint, x, y - extra)
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
        return
    end
    -- Secret percentages may be passed directly to SetValue; never compare them.
    local modeChanged = healthMode ~= mode
    if modeChanged then
        healthMode = mode
        health:ClearAllPoints()
    end
    ApplyInsideSpacing(mode, health)
    local title = _G.GameTooltipTextLeft1
    local tipWidth = tip:GetWidth() or 0
    if mode == "above" or mode == "below" then
        if modeChanged or math.abs((health:GetWidth() or 0) - math.max(1, tipWidth - 12)) > 1 then
            health:SetWidth(math.max(1, tipWidth - 12))
        end
        if modeChanged then
            if mode == "above" then
                health:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 6, 2)
            else
                health:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 6, 0)
            end
        end
    else
        local titleWidth = title and title:GetStringWidth() or 0
        local inset = 10
        if title and title:GetLeft() and tip:GetLeft() then
            inset = math.max(6, title:GetLeft() - tip:GetLeft())
        end
        local barWidth = math.max(1, math.min(titleWidth - 4, tipWidth - inset - 6))
        if math.abs((health:GetWidth() or 0) - barWidth) > 1 then health:SetWidth(barWidth) end
        if modeChanged then
            if mode == "insideTop" then
                health:SetPoint("TOPLEFT", tip, "TOPLEFT", inset, -10)
            else
                health:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", inset, 6)
            end
        end
    end
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
    if db.itemLevel and link and GetDetailedItemLevelInfo then
        local ok, level = pcall(GetDetailedItemLevelInfo, link)
        if ok and Readable(level) and type(level) == "number" and level > 1 then
            local hasNative = false
            local lineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemLevel
            if lineType and data and type(data.lines) == "table" then
                for _, line in ipairs(data.lines) do
                    if Readable(line) and type(line) == "table" and line.type == lineType then
                        hasNative = true
                        break
                    end
                end
            end
            if not hasNative and not FindLine(_G.ITEM_LEVEL or "Item Level") then
                tip:AddLine(string.format("Item Level %d", level), 1, 0.82, 0.42)
            end
        end
    end
    if tip:IsShown() then tip:Show() end
end
local function SpellContent(_, data)
    local db = DB()
    if not db or not db.enabled or not db.ids then return end
    local id = data and data.id
    if not Readable(id) then _, id = tip:GetSpell() end
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
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType then
        local add = TooltipDataProcessor.AddTooltipPostCall
        add(Enum.TooltipDataType.Unit, UnitContent)
        add(Enum.TooltipDataType.Item, ItemContent)
        add(Enum.TooltipDataType.Spell, SpellContent)
        if Enum.TooltipDataType.UnitAura then
            add(Enum.TooltipDataType.UnitAura, SpellContent)
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
    tip:HookScript("OnHide", function() health:Hide(); healthMode = nil; ResetInsideSpacing() end)
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
