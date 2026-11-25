local addon = BaziUI
local hud = {}
addon.HUD = hud

local defaults = {
    ammo = {x = 330, y = -80, scale = 100, width = 104, height = 35, iconSize = 23,
        low = 200, critical = 50, sound = true, lowSound = "raidWarning", criticalSound = "raidWarning",
        warning = true, chatWarning = true},
    durability = {x = 205, y = -195},
    vehicle = {x = 210, y = -230},
    buffs = {x = 430, y = 245, size = 32, rows = 4, columns = 10, fontSize = 11, text = "Below", left = true},
    debuffs = {x = 430, y = 145, size = 32, rows = 3, columns = 10, fontSize = 11, text = "Below", left = true},
    player = {x = 0, y = -155, unitX = 0, unitY = 4, width = 260, height = 22, fontSize = 13},
    target = {x = 260, y = -215, unitX = 0, unitY = 4, width = 200, height = 20, fontSize = 12},
    breath = {x = 0, y = 145, width = 225, height = 20, fontSize = 12},
    fatigue = {x = 0, y = 116, width = 225, height = 20, fontSize = 12},
}
function hud.Settings(key)
    local profile = addon.db.profile
    profile.hud = profile.hud or {}
    local root = profile.hud
    root[key] = root[key] or {}
    local cfg = root[key]
    for field, value in pairs(defaults[key]) do
        if cfg[field] == nil then cfg[field] = value end
    end
    return cfg
end

local warningParts = {"Head", "Shoulders", "Chest", "Hands", "Waist", "Legs", "Feet", "Wrists"}
local native = setmetatable({}, {__mode = "k"})
local preview, queued, pending, moving
local vehiclePreview
local function place(frame, cfg)
    if addon.Movers and addon.Movers.IsDragging(frame) then return end
    local point, parent, relative, x, y = frame:GetPoint(1)
    if frame:GetNumPoints() == 1 and point == "CENTER" and parent == UIParent
        and relative == "CENTER" and x == cfg.x and y == cfg.y then return end
    moving = true
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
    moving = false
end

local function queue()
    if queued or moving then return end
    queued = true
    C_Timer.After(0, function() queued = false; hud.RefreshNative() end)
end

local function refreshFrame(frame, key)
    if not frame then return end
    local cfg = hud.Settings(key)
    local active = cfg.enabled or key == "durability" and preview
    local state = native[frame]
    if active and not state then
        state = {}
        native[frame] = state
        hooksecurefunc(frame, "SetPoint", function()
            if not addon.Movers or not addon.Movers.IsDragging(frame) then queue() end
        end)
        frame:HookScript("OnShow", queue)
        if frame.OnEditModeEnter then hooksecurefunc(frame, "OnEditModeEnter", queue) end
        if frame.OnEditModeExit then hooksecurefunc(frame, "OnEditModeExit", queue) end
        if frame.UpdateShownState then hooksecurefunc(frame, "UpdateShownState", queue) end
    end
    if not state then return end
    if active then
        if not state.points then
            state.points = {}
            for i = 1, frame:GetNumPoints() do state.points[i] = {frame:GetPoint(i)} end
            state.alpha = frame:GetAlpha()
        end
        place(frame, cfg)
        addon.ActionBars:SuppressEditSelection(frame, function()
            return hud.Settings(key).enabled or key == "durability" and preview
        end)
        local hiddenByEdit = frame.isInEditMode and not (key == "durability" and (frame.shouldShow or preview)
            or key == "vehicle" and frame.CanExitVehicle and frame:CanExitVehicle())
        if hiddenByEdit and not state.editHidden then
            state.editHidden = true
            frame:SetAlpha(0)
        elseif not hiddenByEdit and state.editHidden then
            state.editHidden = nil
            frame:SetAlpha(state.alpha or 1)
        end
    elseif state.points then
        moving = true
        frame:ClearAllPoints()
        for _, anchor in ipairs(state.points) do frame:SetPoint(unpack(anchor, 1, 5)) end
        moving = false
        if state.editHidden then frame:SetAlpha(state.alpha or 1) end
        state.points, state.editHidden = nil, nil
    end
end

function hud.RefreshNative()
    if not addon.db then return end
    if vehiclePreview and vehiclePreview:IsShown() then place(vehiclePreview, hud.Settings("vehicle")) end
    if InCombatLockdown() then pending = true; return end
    pending = false
    refreshFrame(_G.DurabilityFrame, "durability")
    refreshFrame(_G.MainMenuBarVehicleLeaveButton, "vehicle")
    refreshFrame(_G.OverrideActionBar and _G.OverrideActionBar.LeaveButton, "vehicle")
    if preview and _G.DurabilityFrame then
        for _, part in ipairs(warningParts) do
            local texture = _G["Durability" .. part]
            if texture then texture:SetVertexColor(1, 0.81, 0.12, 1); texture:Show() end
        end
        if not DurabilityFrame:IsShown() then DurabilityFrame:Show() end
    end
end

function hud.PreviewVehicle(show)
    if show == nil then show = not (vehiclePreview and vehiclePreview:IsShown()) end
    if not show then
        if vehiclePreview then vehiclePreview:Hide() end
        return false
    end
    if not vehiclePreview then
        local source = _G.MainMenuBarVehicleLeaveButton or (_G.OverrideActionBar and _G.OverrideActionBar.LeaveButton)
        local art = source and source:GetNormalTexture()
        vehiclePreview = CreateFrame("Frame", nil, UIParent)
        vehiclePreview:SetFrameStrata("FULLSCREEN_DIALOG")
        vehiclePreview:EnableMouse(false)
        local width, height = 32, 32
        if source then width, height = source:GetSize() end
        vehiclePreview:SetSize(math.max(1, width), math.max(1, height))
        local icon = vehiclePreview:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        local atlas = art and art:GetAtlas()
        if atlas then icon:SetAtlas(atlas)
        else
            icon:SetTexture(art and art:GetTexture() or "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
            if art then icon:SetTexCoord(art:GetTexCoord()) end
        end
    end
    place(vehiclePreview, hud.Settings("vehicle"))
    vehiclePreview:Show()
    return true
end

function hud.PreviewDurability()
    if InCombatLockdown() then return preview end
    if not DurabilityFrame and C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_DurabilityFrame")
    end
    if not DurabilityFrame then return end
    preview = not preview
    if not preview and DurabilityFrame.SetAlerts then DurabilityFrame:SetAlerts() end
    hud.RefreshNative()
    return preview
end

local watcher = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "UPDATE_INVENTORY_ALERTS", "UPDATE_VEHICLE_ACTIONBAR", "EDIT_MODE_LAYOUTS_UPDATED"}) do
    watcher:RegisterEvent(event)
end
watcher:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_DurabilityFrame" and name ~= "Blizzard_ActionBar" then return end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    queue()
end)
