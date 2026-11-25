local addon = BaziUI
local ammo = {}
addon.HUDAmmo = ammo
local window, previewBand, lastBand
local worldReady, startup
local ammoSlot = GetInventorySlotInfo and GetInventorySlotInfo("AmmoSlot")
local previewNames = {[0] = "Normal", "Low", "Critical"}
local colors = {[0] = {1, 1, 1}, {1, 0.73, 0.22}, {1, 0.30, 0.18}}

function ammo.PlayWarningSound(key)
    if key == "raidWarning" and PlaySound then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    elseif key ~= "none" and addon.Chat and addon.Chat.Alerts then
        addon.Chat.Alerts.Preview(key)
    end
end

local function warn(cfg, band, count, testing)
    local critical = band == 2
    local message = critical and "Critical ammunition. Buy more soon!" or "Ammunition is running low."
    message = ("%s%s (%s remaining)"):format(testing and "[Preview] " or "", message, BreakUpLargeNumbers(count))
    if cfg.warning and UIErrorsFrame then UIErrorsFrame:AddMessage(message, unpack(colors[band])) end
    if cfg.chatWarning then addon:Print(message) end
    if cfg.sound then ammo.PlayWarningSound(critical and cfg.criticalSound or cfg.lowSound) end
end

local function sampleCount(cfg)
    if previewBand == 0 then return cfg.low + 1 end
    if previewBand == 1 then return cfg.low end
    return math.min(cfg.critical, cfg.low)
end

function ammo.Read()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" or not ammoSlot then return end
    local id = GetInventoryItemID("player", ammoSlot)
    if issecretvalue and issecretvalue(id) then return end
    if not id then return 0 end
    local countItem = C_Item and C_Item.GetItemCount or GetItemCount
    local count = countItem and countItem(id)
    if (not issecretvalue or not issecretvalue(count)) and type(count) == "number" then return count, id end
end

function ammo.Band(count, low, critical)
    return count <= math.min(critical, low) and 2 or count <= low and 1 or 0
end

local function showAmmoTooltip(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetInventoryItem("player", ammoSlot)
    GameTooltip:Show()
end

local function hideAmmoTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function makeWindow()
    local frame = CreateFrame("Frame", "BaziUIAmmo", UIParent)
    frame:EnableMouse(false)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetColorTexture(0.10, 0.065, 0.035, 0.83)
    local border = addon.Theme:CreateFrameBorder(frame, frame, frame)
    addon.Theme:AddDropShadow("HUD", frame, border)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("LEFT", 7, 0)
    local hover = CreateFrame("Frame", nil, frame)
    hover:SetAllPoints(frame.icon)
    hover:SetMouseClickEnabled(false)
    hover:SetScript("OnEnter", showAmmoTooltip)
    hover:SetScript("OnLeave", hideAmmoTooltip)
    hover:SetScript("OnHide", hideAmmoTooltip)
    frame.iconHover = hover
    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.label:SetPoint("LEFT", frame.icon, "RIGHT", 7, 0)
    frame.label:SetPoint("RIGHT", -7, 0)
    frame.label:SetJustifyH("LEFT")
    frame.label:SetWordWrap(false)
    return frame
end

function ammo.Refresh()
    if not addon.db then return end
    local cfg = addon.HUD.Settings("ammo")
    local _, class = UnitClass("player")
    local arranging = addon.Movers and addon.Movers.IsActive()
    if previewBand == nil and not arranging and (not cfg.enabled or class ~= "HUNTER" or not ammoSlot) then
        if window then window:Hide() end
        lastBand = nil
        return
    end
    local count, itemID
    if previewBand ~= nil then count = sampleCount(cfg)
    else count, itemID = ammo.Read() end
    count = count or (arranging and cfg.low + 1 or nil)
    if count == nil then return end
    local band = previewBand or ammo.Band(count, cfg.low, cfg.critical)
    if worldReady and previewBand == nil and not arranging then
        if band > (lastBand or 0) then warn(cfg, band, count) end
        lastBand = band
        if addon.SmartAlerts then addon.SmartAlerts.RefreshAmmo() end
    end
    window = window or makeWindow()
    window:SetShown(arranging or previewBand ~= nil or not cfg.onlyLow or band > 0)
    if not window:IsShown() then return end
    local hover = window.iconHover
    if hover.itemID ~= itemID then
        hover.itemID = itemID
        hover:SetMouseMotionEnabled(not not itemID)
        if GameTooltip:IsOwned(hover) then
            if itemID then showAmmoTooltip(hover) else hideAmmoTooltip(hover) end
        end
    end
    window:SetSize(cfg.width, cfg.height)
    local iconSize = math.min(cfg.iconSize, cfg.height - 8, cfg.width - 46)
    window.icon:SetSize(iconSize, iconSize)
    window:SetScale(cfg.scale / 100)
    local ratio = UIParent:GetEffectiveScale() / window:GetEffectiveScale()
    if not (addon.Movers and addon.Movers.IsDragging(window)) then
        window:ClearAllPoints()
        window:SetPoint("CENTER", UIParent, "CENTER", cfg.x * ratio, cfg.y * ratio)
    end
    local icon = itemID and GetInventoryItemTexture("player", ammoSlot) or 132382
    window.icon:SetTexture(icon)
    local typography = addon.Typography
    typography.Apply(window.label, "HUD:Ammo", typography.Path(addon.db.profile.font), 15, "OUTLINE", true)
    window.label:SetText(not itemID and previewBand == nil and not arranging and "No ammo" or BreakUpLargeNumbers(count))
    window.label:SetTextColor(unpack(colors[band]))
end

function ammo.Preview(cycle)
    local nextBand = cycle and ((previewBand or -1) + 1)
    previewBand = nextBand and previewNames[nextBand] and nextBand or nil
    ammo.Refresh()
    if previewBand and previewBand > 0 then
        local cfg = addon.HUD.Settings("ammo")
        warn(cfg, previewBand, sampleCount(cfg), true)
    end
    return previewNames[previewBand]
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "PLAYER_AMMO_CHANGED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" and not worldReady and not startup then
        -- Wait for the chat window to finish loading its tabs and history.
        startup = C_Timer.NewTimer(0.5, function()
            startup, worldReady = nil, true
            ammo.Refresh()
        end)
    end
    ammo.Refresh()
end)
