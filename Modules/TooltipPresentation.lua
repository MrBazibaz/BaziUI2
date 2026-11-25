-- Bazi UI tooltip presentation ONLY.
-- Intentionally does not change tooltip lines, item level, health bars,
-- padding, fonts or inspect hooks. Those belong to their stable modules.
local addon = BaziUI
addon.Tooltip = addon.Tooltip or {}
local T = addon.Tooltip
local tip = GameTooltip
local marker, backgroundFill
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
    backgroundFill:SetColorTexture(0.035, 0.028, 0.049, alpha)
    backgroundFill:Show()
end
function T:Apply()
    if not tip then return end
    local db = DB()
    if not db then return end
    if not db.enabled then
        tip:SetScale(1)
        tip:SetAlpha(1)
        ApplyBackgroundOpacity(nil)
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
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and TooltipDataProcessor.AllTypes then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip)
            if tooltip == tip and Allowed() then ApplyBackgroundOpacity(SafeNumber(DB().opacity, 1)) end
        end)
    end
    local equipment = CreateFrame("Frame")
    equipment:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    equipment:RegisterEvent("MODIFIER_STATE_CHANGED")
    equipment:SetScript("OnEvent", function(_, event, key)
        if event == "MODIFIER_STATE_CHANGED" then
            if not (Allowed() and (key == "LSHIFT" or key == "RSHIFT") and tip:IsShown()) then return end
            local adventure = addon.Adventure
            local itemShift
            if adventure and tip:IsShown() and tip.GetTooltipData then
                local data = adventure.Call(tip.GetTooltipData, tip)
                local kind = data and data.type
                if adventure.Read(kind) and Enum and Enum.TooltipDataType and kind == Enum.TooltipDataType.Item then
                    for _, id in ipairs({"alts", "advisor"}) do
                        local cfg = adventure.Settings(id)
                        itemShift = itemShift or cfg.enabled and cfg.tooltip and cfg.shift
                    end
                end
            end
            if itemShift then
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
