-- Bazi UI tooltip presentation ONLY.
-- Intentionally does not change tooltip lines, item level, health bars,
-- padding, fonts or inspect hooks. Those belong to their stable modules.
local addon = BaziUI
addon.Tooltip = addon.Tooltip or {}
local T = addon.Tooltip
local tip = GameTooltip
local marker, backgroundFill, health, accentBorder
local tooltipEdges = {}
local nativeHealthAlpha, padded
local nativeOpacity = {}

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
    local center = tip.NineSlice and tip.NineSlice.Center
    if alpha == nil then
        if backgroundFill then backgroundFill:Hide() end
        for background, previous in pairs(nativeOpacity) do
            background:SetAlpha(previous)
            nativeOpacity[background] = nil
        end
        return
    end
    local function clear(background)
        if not background or not background.SetAlpha then return end
        if nativeOpacity[background] == nil then nativeOpacity[background] = background:GetAlpha() end
        background:SetAlpha(0)
    end
    clear(center)
    clear(tip.Background)
    if not backgroundFill then
        backgroundFill = tip:CreateTexture(nil, "BACKGROUND", nil, -8)
        backgroundFill:SetPoint("TOPLEFT", tip, "TOPLEFT", 3, -3)
        backgroundFill:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -3, 3)
    end
    backgroundFill:SetColorTexture(0.045, 0.029, 0.020, alpha)
    backgroundFill:Show()
end
local function hideOwnedHealth()
    if not health then return end
    health:Hide()
    local native = tip.StatusBar or _G.GameTooltipStatusBar
    if native and nativeHealthAlpha ~= nil then native:SetAlpha(nativeHealthAlpha) end
    nativeHealthAlpha = nil
    if padded and tip.SetPadding then pcall(tip.SetPadding, tip, 0, 0) end
    padded = nil
end

local function tooltipUnit()
    local ok, _, unit = pcall(tip.GetUnit, tip)
    if ok and type(unit) == "string" and (not issecretvalue or not issecretvalue(unit)) then return unit end
end

local function updateHealth()
    if not health or (tip.IsForbidden and tip:IsForbidden()) then return end
    local db = DB()
    local unit = tip:IsShown() and tooltipUnit()
    if not db or not db.enabled or not unit then hideOwnedHealth(); return end
    local mode = db.smart ~= false and "insideBottom" or db.healthBar
    if mode == "off" then hideOwnedHealth(); return end
    local font, size, flags = addon.TooltipFonts.GetDetailFont(db)
    if health.labelSize ~= size then
        health.percent:SetFont(font, size, flags)
        health:SetHeight(math.max(10, size + 2))
        if padded and tip.SetPadding then pcall(tip.SetPadding, tip, 0, 0); padded = nil end
        health.labelSize = size
    end
    local native = tip.StatusBar or _G.GameTooltipStatusBar
    local dead = UnitIsDeadOrGhost(unit)
    if (not issecretvalue or not issecretvalue(dead)) and dead == true then hideOwnedHealth(); return end
    local value
    local curve = CurveConstants and CurveConstants.ScaleTo100
    if UnitHealthPercent and curve then
        local ok, current = pcall(UnitHealthPercent, unit, false, curve)
        if ok then value = current end
    end
    if type(value) ~= "number" then
        local current, maximum = SafeNumber(UnitHealth(unit)), SafeNumber(UnitHealthMax(unit))
        if current and maximum and maximum > 0 then value = current / maximum * 100 end
    end
    if type(value) ~= "number" or not pcall(health.SetValue, health, value) then hideOwnedHealth(); return end
    if health.mode ~= mode then
        health:ClearAllPoints()
        if mode == "above" then
            health:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 9, 3)
            health:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -9, 3)
        elseif mode == "below" then
            health:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 9, -3)
            health:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", -9, -3)
        elseif mode == "insideTop" then
            health:SetPoint("TOPLEFT", tip, "TOPLEFT", 9, -7)
            health:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -9, -7)
        else
            health:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 9, 7)
            health:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -9, 7)
        end
        health.mode = mode
    end
    if mode == "insideBottom" and tip.SetPadding then
        local lastLine = _G["GameTooltipTextLeft" .. tip:NumLines()]
        local text = lastLine and lastLine:GetText()
        local compact = not (issecretvalue and issecretvalue(text))
            and (not canaccessvalue or canaccessvalue(text)) and text == "Shift for details"
        local padding = health:GetHeight() + (compact and 2 or 8)
        if padding ~= padded and pcall(tip.SetPadding, tip, 0, padding) then padded = padding end
    elseif padded and tip.SetPadding then
        pcall(tip.SetPadding, tip, 0, 0)
        padded = nil
    end
    if native then
        if nativeHealthAlpha == nil then nativeHealthAlpha = native:GetAlpha() end
        native:SetAlpha(0)
    end
    local formatted = pcall(health.percent.SetFormattedText, health.percent, "%.0f%%", value)
    if not formatted then health.percent:SetText("") end
    health:Show()
end

local function applyTooltipBorder(show)
    local slice = tip.NineSlice
    if show and not accentBorder then
        accentBorder = addon.Theme:RoundedCard(tip)
        accentBorder:SetPoint("TOPLEFT", 2, -2)
        accentBorder:SetPoint("BOTTOMRIGHT", -2, 2)
        accentBorder:SetFrameLevel(tip:GetFrameLevel())
    end
    if slice then
        for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
            "LeftEdge", "RightEdge", "TopEdge", "BottomEdge"}) do
            local edge = slice[key]
            if edge and show then
                if tooltipEdges[edge] == nil then tooltipEdges[edge] = edge:GetAlpha() end
                edge:SetAlpha(0)
            elseif edge and tooltipEdges[edge] then
                edge:SetAlpha(tooltipEdges[edge])
                tooltipEdges[edge] = nil
            end
        end
    end
    if accentBorder then accentBorder:SetShown(not not show) end
    if show then
        addon.Theme:PaintQuestCard(accentBorder)
        accentBorder:SetBackdropColor(0, 0, 0, 0)
        accentBorder:SetBackdropBorderColor(addon.Theme:AccentInk(0.34))
    end
end

function T:Apply()
    if not tip then return end
    local db = DB()
    if not db then return end
    if not db.enabled then
        tip:SetScale(1)
        tip:SetAlpha(1)
        ApplyBackgroundOpacity(nil)
        applyTooltipBorder(false)
        hideOwnedHealth()
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
    applyTooltipBorder(addon.Theme:UsesAccentStyle())
    updateHealth()
    if tip:IsShown() and addon.TooltipFonts then addon.TooltipFonts.Apply() end
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
    health = CreateFrame("StatusBar", nil, tip)
    health:EnableMouse(false)
    health:SetHeight(10)
    health:SetMinMaxValues(0, 100)
    health:SetStatusBarTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziHealthGradientRight.tga")
    health:SetStatusBarColor(0.39, 0.68, 0.35)
    local track = health:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.25, 0.17, 0.12, 0.8)
    health.percent = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    health.percent:SetPoint("CENTER")
    health:Hide()
    local elapsed = 0
    health:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        updateHealth()
    end)
    tip:HookScript("OnHide", hideOwnedHealth)
    pcall(tip.HookScript, tip, "OnTooltipCleared", hideOwnedHealth)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", ApplyAnchor)
    tip:HookScript("OnShow", function()
        T:Apply()
    end)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and TooltipDataProcessor.AllTypes then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip)
            if tooltip == tip and Allowed() then
                ApplyBackgroundOpacity(SafeNumber(DB().opacity, 1))
                applyTooltipBorder(addon.Theme:UsesAccentStyle())
                updateHealth()
            end
        end)
    end
    local equipment = CreateFrame("Frame")
    equipment:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    equipment:RegisterEvent("MODIFIER_STATE_CHANGED")
    equipment:SetScript("OnEvent", function(_, event, key)
        if event == "MODIFIER_STATE_CHANGED" then
            local db = DB()
            local adventure = addon.Adventure
            local itemShift
            if adventure and tip:IsShown() and tip.GetTooltipData then
                local data = adventure.Call(tip.GetTooltipData, tip)
                local kind = data and data.type
                if adventure.Read(kind) and Enum and Enum.TooltipDataType and kind == Enum.TooltipDataType.Item then
                    local cfg = adventure.Settings("alts")
                    itemShift = cfg.enabled and cfg.tooltip and cfg.shift
                end
            end
            if Allowed() and (key == "LSHIFT" or key == "RSHIFT") and tip:IsShown()
                and (itemShift or db.smart ~= false and tooltipUnit()) then
                if tip.RefreshDataNextUpdate then tip:RefreshDataNextUpdate()
                elseif tip.RefreshData then tip:RefreshData() end
            end
            return
        end
        if not tip:IsShown() or not tip.RefreshDataNextUpdate or not Enum or not Enum.TooltipDataType then return end
        local owner = tip:GetOwner()
        if owner and owner.baziInventorySlot then return end
        local data = tip.GetTooltipData and tip:GetTooltipData()
        if issecretvalue and issecretvalue(data) then return end
        local kind = data and data.type
        if kind and not (issecretvalue and issecretvalue(kind)) and Enum.TooltipDataType.Item == kind then
            tip:RefreshDataNextUpdate()
        end
    end)
    self:Apply()
end
