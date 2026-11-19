-- Bazi UI Minimap: square presentation adapted from FlareUI Modules/Minimap.lua.
-- Preserve Blizzard's round map when the square style is not selected.
local addon = BaziUI
addon.Minimap = addon.Minimap or {}
local MM = addon.Minimap
local map, cluster = _G.Minimap, _G.MinimapCluster
local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local MAP_SIZE, MAP_CROP, FRAME_PAD = 244, 4, 8
local timer, square, applying, refreshQueued
local hidden = CreateFrame("Frame")
hidden:Hide()

local function db()
    return addon.db and addon.db.profile and addon.db.profile.minimap
end
local function safe(v)
    return not issecretvalue or not issecretvalue(v)
end
local function park(frame)
    if frame and frame ~= hidden then
        if frame:GetParent() ~= hidden then frame:SetParent(hidden) end
        frame:Hide()
    end
end
local function parkRoundArt()
    park(_G.MinimapCompassTexture)
    park(_G.MinimapCompassTextureUnderlay)
    if map then
        park(map.ZoomIn)
        park(map.ZoomOut)
        park(map.ZoomHitArea)
    end
    if _G.MinimapBackdrop then park(_G.MinimapBackdrop.StaticOverlayTexture) end
end
local function setSquareMask()
    if not map or not map.SetMaskTexture then return end
    map:SetMaskTexture(SQUARE_MASK)
    _G.GetMinimapShape = function() return "SQUARE" end
    local hybrid = _G.HybridMinimap
    if hybrid and hybrid.CircleMask and hybrid.MapCanvas then
        hybrid.CircleMask:SetTexture(SQUARE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        hybrid.MapCanvas:SetMaskTexture(hybrid.CircleMask)
    end
end
local function createArt()
    if MM.Border or not cluster or not NineSliceUtil then return end
    local holder = CreateFrame("Frame", nil, cluster)
    holder:SetSize(MAP_SIZE, MAP_SIZE)
    holder:SetPoint("CENTER", cluster, "CENTER")
    holder:SetFrameStrata(map:GetFrameStrata())
    holder:SetFrameLevel(map:GetFrameLevel() + 2)
    local border = CreateFrame("Frame", nil, holder)
    border:SetAllPoints(holder)
    border:SetFrameStrata("BACKGROUND")
    local above = CreateFrame("Frame", nil, holder)
    above:SetAllPoints(holder)
    above:SetFrameStrata(map:GetFrameStrata())
    above:SetFrameLevel(map:GetFrameLevel() + 1)
    local source = NineSliceUtil.GetLayout("ButtonFrameTemplateNoPortrait")
    if source then
        local layout = {}
        for key, value in pairs(source) do
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do copy[k] = v end
                layout[key] = copy
            else
                layout[key] = value
            end
        end
        for _, key in ipairs({"TopLeftCorner", "BottomLeftCorner"}) do
            if layout[key] then layout[key].x = (layout[key].x or 0) - 6 end
        end
        for _, key in ipairs({"TopLeftCorner", "TopRightCorner"}) do
            if layout[key] then layout[key].y = (layout[key].y or 0) - 3 end
        end
        NineSliceUtil.ApplyLayout(border, layout)
        for _, key in ipairs({"BottomLeftCorner", "BottomRightCorner", "LeftEdge", "RightEdge", "BottomEdge"}) do
            if border[key] then border[key]:SetParent(above) end
        end
        local bronze = C_Texture and C_Texture.GetAtlasInfo
            and C_Texture.GetAtlasInfo("heavybronze-frame-basic")
        if bronze then
            local texture = above:CreateTexture(nil, "BORDER")
            texture:SetAtlas("heavybronze-frame-basic")
            texture:SetPoint("TOPLEFT", border, "TOPLEFT", -9, 11)
            texture:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 7, -8)
            for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner",
                "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"}) do
                if border[key] then border[key]:SetAlpha(0) end
            end
        end
    end
    MM.Border = holder
    map:HookScript("OnShow", function() holder:Show() end)
    map:HookScript("OnHide", function() holder:Hide() end)
    holder:SetShown(map:IsShown())
end
local function layout()
    if applying or not square or not map or not cluster then return end
    if InCombatLockdown and InCombatLockdown() and map.IsProtected and map:IsProtected() then
        return
    end
    applying = true
    parkRoundArt()
    createArt()
    if cluster.MinimapContainer then cluster.MinimapContainer:SetScale(1) end
    cluster:SetSize(MAP_SIZE + FRAME_PAD * 2, MAP_SIZE + FRAME_PAD * 2)
    map:SetSize(MAP_SIZE - MAP_CROP * 2, MAP_SIZE - MAP_CROP * 2)
    map:ClearAllPoints()
    map:SetPoint("CENTER", cluster, "CENTER")
    setSquareMask()
    applying = false
end
local function queueLayout()
    if refreshQueued or not C_Timer or not C_Timer.After then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if square then layout() end
    end)
end
local function onZoom(_, level)
    if timer then timer:Cancel(); timer = nil end
    local cfg = db()
    local delay = cfg and cfg.enabled and cfg.autoZoom or 0
    if safe(level) and type(level) == "number" and level > 0
        and type(delay) == "number" and delay > 0 and C_Timer and C_Timer.NewTimer then
        timer = C_Timer.NewTimer(delay, function()
            if cfg.enabled and map and not (InCombatLockdown and InCombatLockdown()) then
                pcall(map.SetZoom, map, 0)
            end
        end)
    end
end
function MM:Initialize()
    if self.initialized then return end
    self.initialized = true
    local cfg = db()
    if not cfg or not cfg.enabled or not map then return end
    square = cfg.style == "square"
    if square then
        layout()
        if cluster and hooksecurefunc then
            hooksecurefunc(cluster, "SetSize", queueLayout)
            if cluster.UpdateMinimapConfig then
                hooksecurefunc(cluster, "UpdateMinimapConfig", queueLayout)
            end
        end
    end
    if hooksecurefunc then hooksecurefunc(map, "SetZoom", onZoom) end
end
function MM:Apply()
    -- Shape changes are applied on reload to avoid leaving Blizzard's artwork detached.
    -- Do not re-parent textures when the round style is active.
end
