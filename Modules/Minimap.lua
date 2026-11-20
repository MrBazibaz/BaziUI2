-- Bazi UI Minimap: square presentation adapted from FlareUI Modules/Minimap.lua.
-- Preserve Blizzard's round map when the square style is not selected.
local addon = BaziUI
addon.Minimap = addon.Minimap or {}
local MM = addon.Minimap
local map, cluster = _G.Minimap, _G.MinimapCluster
local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local MAP_SIZE, MAP_CROP, FRAME_PAD = 244, 4, 8
local BRONZE_OUT = {left = 9, right = 7, top = 11, bottom = 8}
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
    if _G.MinimapBackdrop then park(_G.MinimapBackdrop.StaticOverlayTexture) end
    if map then
        park(map.ZoomIn)
        park(map.ZoomOut)
        park(map.ZoomHitArea)
    end
end
local function setSquareMask()
    if not map or not map.SetMaskTexture then return end
    map:SetMaskTexture(SQUARE_MASK)
    if map.SetArchBlobRingScalar then map:SetArchBlobRingScalar(0) end
    -- Preserve Blizzard's quest-blob interaction. A zero scalar may suppress
    -- the quest hover hit region as well as the visual ring.
    if map.SetQuestBlobRingScalar then map:SetQuestBlobRingScalar(0) end
    if map.SetTaskBlobRingScalar then map:SetTaskBlobRingScalar(0) end
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
    holder:EnableMouse(false)
    holder:SetSize(MAP_SIZE, MAP_SIZE)
    holder:SetPoint("CENTER", cluster, "CENTER")
    holder:SetFrameStrata(map:GetFrameStrata())
    holder:SetFrameLevel(map:GetFrameLevel() + 2)
    local border = CreateFrame("Frame", nil, holder)
    border:EnableMouse(false)
    border:SetAllPoints(holder)
    border:SetFrameStrata("BACKGROUND")
    local above = CreateFrame("Frame", nil, holder)
    above:EnableMouse(false)
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
            if layout[key] then layout[key].x = (layout[key].x or 0) + (-6) end
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
            texture:SetPoint("TOPLEFT", border, "TOPLEFT", -BRONZE_OUT.left, BRONZE_OUT.top)
            texture:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", BRONZE_OUT.right, -BRONZE_OUT.bottom)
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
-- FlareUI's header approach: reuse Forever's own zone, tracking, calendar
-- and clock widgets; only their anchors and the shared plate are changed.
local HEADER_HEIGHT, HEADER_GAP, HEADER_SIDE = 19, 2, 9
local CLOCK_WIDTH, PLATE_INSET = 40, 6
local placingSun = false
local function placeSun()
    local cfg = db()
    local sun = cluster and cluster.DielFrame
    if not square or not MM.Border or not sun or placingSun then return end
    placingSun = true
    local container = cluster.MinimapContainer or cluster
    if sun:GetParent() ~= container then sun:SetParent(container) end
    sun:SetScale(0.9)
    sun:ClearAllPoints()
    -- In the top-right corner, clear of the header row's calendar button.
    sun:SetPoint("BOTTOMRIGHT", MM.Border, "BOTTOMRIGHT", 9, -9)
    sun:SetShown(not cfg.hideDayNight)
    placingSun = false
end
local function fitButtonArt(button)
    if not button then return end
    for _, key in ipairs({"StateTexture", "AddTexture"}) do
        local texture = button[key]
        if texture then texture:ClearAllPoints(); texture:SetAllPoints(button) end
    end
end
local function plate(texture, parent)
    if not texture then return end
    texture:SetAtlas("ui-hud-minimap-header-button")
    texture:ClearAllPoints()
    texture:SetAllPoints(parent)
    if texture.SetTextureSliceMargins then
        texture:SetTextureSliceMargins(6, 6, 6, 6)
        if Enum and Enum.UITextureSliceMode then
            texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end
end
local function headerLayout()
    if not square or not MM.Border or not cluster or not cluster.ZoneTextButton
        or not cluster.Tracking or not _G.GameTimeFrame then return end
    local cfg = db()
    if not MM.Header then
        local header = CreateFrame("Frame", nil, cluster)
        header:SetHeight(HEADER_HEIGHT)
        header:SetFrameStrata(map:GetFrameStrata())
        header:SetFrameLevel(map:GetFrameLevel() + 8)
        local art = header:CreateTexture(nil, "BACKGROUND")
        plate(art, header)
        MM.Header = header
        -- Warm translucent backing above the terrain; Blizzard atlas supplies the gold edges.
        local warm = header:CreateTexture(nil, "BORDER")
        warm:SetAllPoints(header)
        warm:SetColorTexture(0.17, 0.095, 0.045, 0.78)
        MM.HeaderWarmPlate = warm
        local zone = cluster.ZoneTextButton
        if zone.StateTexture then park(zone.StateTexture) end
        if zone.AddTexture then plate(zone.AddTexture, header) end
    end
    -- One continuous, thin bronze border behind the entire top row.
    -- It includes the tracking and calendar cells, not only the central label.
    if not MM.HeaderSurround then
        local surround = CreateFrame("Frame", nil, cluster)
        surround:SetHeight(HEADER_HEIGHT + 2)
        surround:SetFrameStrata(map:GetFrameStrata())
        surround:SetFrameLevel(map:GetFrameLevel() + 7)
        local backing = surround:CreateTexture(nil, "BACKGROUND")
        backing:SetAllPoints()
        backing:SetColorTexture(0.15, 0.075, 0.035, 0.76)
        -- FlareUI's actual minimap header uses Forever's own sliced
        -- ui-hud-minimap-header-button atlas, NOT a full-window NineSlice.
        -- NineSlice's top/bottom edges have a minimum width and create
        -- dangling bars on a 21px header. Use one sliced plate instead.
        local art = surround:CreateTexture(nil, "ARTWORK")
        plate(art, surround)
        MM.HeaderSurroundArt = art
        MM.HeaderSurround = surround
    end
    local header, tracking, calendar = MM.Header, cluster.Tracking, _G.GameTimeFrame
    local topLevel = map:GetFrameLevel() + 9
    for _, widget in ipairs({tracking, calendar, cluster.ZoneTextButton}) do
        widget:SetFrameStrata(map:GetFrameStrata())
        widget:SetFrameLevel(topLevel)
    end
    tracking:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    if tracking.Background then tracking.Background:Hide() end
    if tracking.Button then
        tracking.Button:ClearAllPoints()
        tracking.Button:SetAllPoints(tracking)
        fitButtonArt(tracking.Button)
    end
    calendar:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    fitButtonArt(calendar)
    local clock = _G.TimeManagerClockButton
    local ticker = _G.TimeManagerClockTicker
    local width = CLOCK_WIDTH
    if ticker and ticker.GetUnboundedStringWidth then
        width = math.max(width, math.ceil(ticker:GetUnboundedStringWidth() or 0) + 8)
    end
    tracking:ClearAllPoints()
    tracking:SetPoint("TOPLEFT", MM.Border, "TOPLEFT", HEADER_SIDE, -4)
    calendar:ClearAllPoints()
    calendar:SetPoint("TOPRIGHT", MM.Border, "TOPRIGHT", -HEADER_SIDE, -4)
    local surround = MM.HeaderSurround
    surround:ClearAllPoints()
    -- The central plate belongs only to zone/clock. The two side buttons
    -- have independent plates, so hiding either hides its border as well.
    surround:SetPoint("TOPLEFT", header, "TOPLEFT", -2, 1)
    surround:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 2, -1)
    header:ClearAllPoints()
    header:SetPoint("LEFT", tracking, "RIGHT", HEADER_GAP, 0)
    header:SetPoint("RIGHT", calendar, "LEFT", -HEADER_GAP, 0)
    local zone = cluster.ZoneTextButton
    zone:ClearAllPoints()
    zone:SetPoint("TOPLEFT", header, "TOPLEFT", HEADER_GAP, 0)
    zone:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -width, 0)
    if _G.MinimapZoneText then
        local label = _G.MinimapZoneText
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", zone, "TOPLEFT", PLATE_INSET, 0)
        label:SetPoint("BOTTOMRIGHT", zone, "BOTTOMRIGHT", 0, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    end
    if clock then
        clock:ClearAllPoints()
        clock:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
        clock:SetSize(width, HEADER_HEIGHT)
        if ticker then
            ticker:ClearAllPoints()
            ticker:SetPoint("RIGHT", clock, "RIGHT", -PLATE_INSET, 0)
        end
    end
    if not MM.TrackingPlate then
        MM.TrackingPlate = tracking:CreateTexture(nil, "BACKGROUND", nil, -1)
        MM.TrackingPlate:SetAllPoints(tracking)
        plate(MM.TrackingPlate, tracking)
    end
    if not MM.CalendarPlate then
        MM.CalendarPlate = calendar:CreateTexture(nil, "BACKGROUND", nil, -1)
        MM.CalendarPlate:SetAllPoints(calendar)
        plate(MM.CalendarPlate, calendar)
    end
    MM.TrackingPlate:SetShown(not cfg.hideTracking)
    MM.CalendarPlate:SetShown(not cfg.hideCalendar)
    local showHeader = not (cfg.hideZone and cfg.hideClock)
    header:SetShown(showHeader)
    MM.HeaderSurround:SetShown(showHeader)
    tracking:SetShown(not cfg.hideTracking)
    zone:SetShown(not cfg.hideZone)
    calendar:SetShown(not cfg.hideCalendar)
    if clock then clock:SetShown(not cfg.hideClock) end
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
    headerLayout()
    placeSun()
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
            local indoors = cfg.ignoreIndoorZoom and IsIndoors and IsIndoors()
            if cfg.enabled and map and not indoors
                and not (InCombatLockdown and InCombatLockdown()) then
                pcall(map.SetZoom, map, 0)
            end
        end)
    end
end
local function applyScales()
    local cfg = db()
    if not cfg or not cfg.enabled or not map then return end
    if map.SetIconScale then
        local value = tonumber(cfg.iconScale) or 1.5
        pcall(map.SetIconScale, map, math.max(1, math.min(2.5, value)))
    end
    if cluster and cluster.SetScale then
        local value = tonumber(cfg.mapScale) or 1
        cluster:SetScale(math.max(0.7, math.min(1.5, value)))
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
        if EventUtil and EventUtil.ContinueOnAddOnLoaded then
            EventUtil.ContinueOnAddOnLoaded("Blizzard_TimeManager", queueLayout)
        end
        if cluster and hooksecurefunc then
            hooksecurefunc(cluster, "SetSize", queueLayout)
            if cluster.UpdateMinimapConfig then
                hooksecurefunc(cluster, "UpdateMinimapConfig", queueLayout)
            end
        end
    end
    if hooksecurefunc then hooksecurefunc(map, "SetZoom", onZoom) end
    applyScales()
    -- Blizzard's Edit Mode can reapply its own icon scale after login.
    -- Reassert the saved setting once the UI has settled.
    if C_Timer and C_Timer.After then
        C_Timer.After(1, applyScales)
        C_Timer.After(3, applyScales)
    end
end
function MM:Apply()
    -- Shape changes are applied on reload to avoid leaving Blizzard's artwork detached.
    -- Do not re-parent textures when the round style is active.
    if square then headerLayout(); placeSun() end
    applyScales()
end
