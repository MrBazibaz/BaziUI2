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
local mailFrame, mailState, mailQueued, placingMail
local positioningPreview, previewLayers = false, {}
local squareStrata = "DIALOG"
local foreground = {HIGH = true, DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true}

function MM:GetOverlayStrata()
    return square and squareStrata or map and map:GetFrameStrata() or "HIGH"
end

local function mapStrata()
    return square and squareStrata or previewLayers[map] or map:GetFrameStrata()
end

local function refreshMapLayers()
    if not square or not map or not cluster or InCombatLockdown() then return end
    local container = cluster.MinimapContainer
    cluster:SetFrameStrata(squareStrata)
    if container then container:SetFrameStrata(squareStrata) end
    map:SetFrameStrata(squareStrata)
    -- Markers can be frames owned by the minimap or the map container.
    for _, parent in pairs({map, container}) do
        for _, child in ipairs({parent:GetChildren()}) do
            local strata = child:GetFrameStrata()
            if strata ~= "DIALOG" and strata ~= "FULLSCREEN" and strata ~= "FULLSCREEN_DIALOG" and strata ~= "TOOLTIP" then
                child:SetFrameStrata(squareStrata)
            end
            if parent == map and child:GetFrameLevel() <= map:GetFrameLevel() then
                child:SetFrameLevel(map:GetFrameLevel() + 1)
            end
        end
    end
end

local function refreshPreviewLayer(active)
    if not active then
        for frame, strata in pairs(previewLayers) do frame:SetFrameStrata(strata) end
        wipe(previewLayers)
        return
    end
    local function raise(frame)
        if not frame then return end
        local strata = frame:GetFrameStrata()
        if not foreground[strata] then
            previewLayers[frame] = previewLayers[frame] or strata
            frame:SetFrameStrata("HIGH")
        end
    end
    -- The map, decorations, and header have independent strata.
    raise(map)
    raise(MM.Border)
    raise(MM.BronzeAbove)
    raise(MM.Header)
    raise(MM.HeaderSurround)
    raise(cluster and cluster.Tracking)
    raise(cluster and cluster.ZoneTextButton)
    raise(cluster and cluster.DielFrame)
    raise(_G.GameTimeFrame)
    raise(_G.TimeManagerClockButton)
    raise(mailFrame)
end
-- Track temporary minimap offsets used by node/quest hover scanners.
-- FlareUI preserves these offsets when applying its square layout.
local scanX, scanY = 0, 0
local function scanAway()
    return math.abs(scanX) > 0.01 or math.abs(scanY) > 0.01
end
local function watchScanOffsets()
    if not map or not map.AdjustPointsOffset or not hooksecurefunc then return end
    hooksecurefunc(map, "AdjustPointsOffset", function(_, dx, dy)
        if type(dx) ~= "number" or type(dy) ~= "number" then return end
        if issecretvalue and (issecretvalue(dx) or issecretvalue(dy)) then return end
        scanX, scanY = scanX + dx, scanY + dy
        if not scanAway() then scanX, scanY = 0, 0 end
    end)
end

local hidden = CreateFrame("Frame")
hidden:Hide()

local function db()
    return addon.db and addon.db.profile and addon.db.profile.minimap
end
local function safe(v)
    return not issecretvalue or not issecretvalue(v)
end

local function applyMail()
    local cfg = db()
    if not cfg or not mailFrame or InCombatLockdown() then return end
    placingMail = true
    if cfg.enabled and cfg.hideMail then
        if not mailState.hidden then
            mailState.alpha, mailState.mouse = mailFrame:GetAlpha(), mailFrame:IsMouseEnabled()
            mailState.hidden = true
        end
        mailFrame:SetAlpha(0)
        mailFrame:EnableMouse(false)
    elseif mailState.hidden then
        mailFrame:SetAlpha(mailState.alpha)
        mailFrame:EnableMouse(mailState.mouse)
        mailState.hidden = nil
    end
    if cfg.enabled and (cfg.mailX ~= nil or cfg.mailY ~= nil) then
        local anchor = square and MM.Border or map
        local x, y = cfg.mailX or 40, cfg.mailY or 8
        local point, parent, side, oldX, oldY = mailFrame:GetPoint(1)
        if point ~= "CENTER" or parent ~= anchor or side ~= "TOPLEFT" or x ~= oldX or y ~= oldY
            or mailFrame:GetNumPoints() ~= 1 then
            if not mailState.points then
                mailState.points = {}
                local count = mailFrame:GetNumPoints()
                for i = 1, safe(count) and type(count) == "number" and count or 0 do
                    mailState.points[i] = {mailFrame:GetPoint(i)}
                end
            end
            mailFrame:ClearAllPoints()
            mailFrame:SetPoint("CENTER", anchor, "TOPLEFT", x, y)
        end
    elseif mailState.points then
        mailFrame:ClearAllPoints()
        for _, point in ipairs(mailState.points) do mailFrame:SetPoint(unpack(point, 1, 5)) end
        mailState.points = nil
    end
    placingMail = false
end

local function initMail()
    if mailFrame then return end
    mailFrame = cluster and cluster.IndicatorFrame and cluster.IndicatorFrame.MailFrame or _G.MiniMapMailFrame
    if not mailFrame then return end
    mailState = {}
    local function queue()
        if mailQueued or placingMail or addon.Movers and addon.Movers.IsDragging(mailFrame) then return end
        mailQueued = true
        C_Timer.After(0, function()
            mailQueued = nil
            applyMail()
        end)
    end
    mailFrame:HookScript("OnShow", queue)
    hooksecurefunc(mailFrame, "SetPoint", queue)
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

local function updateBorder()
    if not MM.SlimBorder then return end
    local cfg = db()
    local slim = addon.Theme:UsesAccentStyle() or cfg and cfg.borderStyle == "slim"
    MM.SlimBorder:SetShown(slim)
    MM.BronzeBorder:SetShown(not slim)
    MM.BronzeAbove:SetShown(not slim)
    local shadow = MM.DropShadow
    local bounds = slim and MM.SlimBorder or MM.BronzeArt or MM.BronzeBorder
    if shadow and MM.ShadowBounds ~= bounds then
        shadow:SetShadowBounds(bounds)
        MM.ShadowBounds = bounds
    end
end

local function createArt()
    if MM.Border or not cluster or not NineSliceUtil then return end
    local holder = CreateFrame("Frame", nil, cluster)
    holder:EnableMouse(false)
    holder:SetSize(MAP_SIZE, MAP_SIZE)
    holder:SetPoint("CENTER", cluster, "CENTER")
    holder:SetFrameStrata(mapStrata())
    holder:SetFrameLevel(map:GetFrameLevel() + 2)
    local border = CreateFrame("Frame", nil, holder)
    border:EnableMouse(false)
    border:SetAllPoints(holder)
    border:SetFrameStrata("BACKGROUND")
    local above = CreateFrame("Frame", nil, holder)
    above:EnableMouse(false)
    above:SetAllPoints(holder)
    above:SetFrameStrata(mapStrata())
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
            MM.BronzeArt = texture
            for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner",
                "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"}) do
                if border[key] then border[key]:SetAlpha(0) end
            end
        end
    end
    local slim = addon.Theme:CreateFrameBorder(holder, holder, holder)
    slim:ClearAllPoints()
    slim:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -2)
    slim:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
    slim:SetFrameLevel(map:GetFrameLevel() + 2)
    slim:EnableMouse(false)
    MM.SlimBorder, MM.BronzeBorder, MM.BronzeAbove = slim, border, above
    MM.Border = holder
    MM.DropShadow = addon.Theme:AddDropShadow("Minimap", holder)
    updateBorder()
    map:HookScript("OnShow", function() holder:Show() end)
    map:HookScript("OnHide", function() holder:Hide() end)
    holder:SetShown(map:IsShown())
    -- The decorative frame must never intercept Blizzard quest-area hovers.
    -- Reassert after setup because other UI code may enable mouse input.
    holder:EnableMouse(false)
    holder:HookScript("OnShow", function(self)
        self:EnableMouse(false)
    end)
end
-- FlareUI's header approach: reuse Forever's own zone, tracking, calendar
-- and clock widgets; only their anchors and the shared plate are changed.
local HEADER_HEIGHT, HEADER_GAP, HEADER_SIDE = 19, 2, 9
local CLOCK_WIDTH, PLATE_INSET = 40, 6
local placingSun = false
local function placeSun()
    local cfg = db()
    local sun = cluster and cluster.DielFrame
    if not square or not MM.Border or not sun or placingSun or InCombatLockdown() then return end
    placingSun = true
    local container = cluster.MinimapContainer or cluster
    if sun:GetParent() ~= container then sun:SetParent(container) end
    if sun.SetFixedFrameStrata then sun:SetFixedFrameStrata(true) end
    sun:SetFrameStrata("FULLSCREEN")
    sun:SetFrameLevel(math.max(container:GetFrameLevel(), map:GetFrameLevel()) + 32)
    sun:SetScale(0.9)
    sun:ClearAllPoints()
    -- Keep the badge just inside the bottom corner of the map.
    sun:SetPoint("BOTTOMRIGHT", MM.Border, "BOTTOMRIGHT", 3, -3)
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
function MM:RefreshHeaderStyle()
    if not self.HeaderStyleFill then return end
    local custom = addon.Theme:UsesAccentStyle()
        or addon.Headers.Get("minimap", "color") ~= nil or addon.Headers.Get("minimap", "opacity") ~= nil
    self.HeaderArt:SetShown(not custom)
    self.HeaderWarmPlate:SetShown(not custom)
    self.HeaderSurroundArt:SetShown(not custom)
    self.HeaderBacking:SetShown(not custom)
    local zone = cluster.ZoneTextButton
    if zone.AddTexture then zone.AddTexture:SetShown(not custom) end
    self.HeaderStyleFill:SetShown(custom)
    self.HeaderStyleBorder:SetShown(custom)
    local alpha = (addon.Backgrounds.Get("minimap") or 78) / 100
    self.HeaderStyleFill:SetColorTexture(addon.Headers.Fill("minimap", 0.17, 0.095, 0.045, alpha))
end

local function headerLayout()
    if not square or not MM.Border or not cluster or not cluster.ZoneTextButton
        or not cluster.Tracking then return end
    local cfg = db()
    if not MM.Header then
        local header = CreateFrame("Frame", nil, cluster)
        header:SetHeight(HEADER_HEIGHT)
        header:SetFrameStrata(mapStrata())
        header:SetFrameLevel(map:GetFrameLevel() + 8)
        local art = header:CreateTexture(nil, "BACKGROUND")
        plate(art, header)
        MM.Header = header
        MM.HeaderArt = art
        -- Warm translucent backing above the terrain; Blizzard atlas supplies the gold edges.
        local warm = header:CreateTexture(nil, "BORDER")
        warm:SetAllPoints(header)
        warm:SetColorTexture(0.17, 0.095, 0.045, 1)
        warm:SetAlpha(0.78)
        addon.Backgrounds.Track("minimap", warm, 0.78)
        MM.HeaderWarmPlate = warm
        local zone = cluster.ZoneTextButton
        if zone.StateTexture then park(zone.StateTexture) end
        if zone.AddTexture then plate(zone.AddTexture, header) end
    end
    local header, tracking, calendar = MM.Header, cluster.Tracking, _G.GameTimeFrame
    -- One continuous, thin bronze border behind the entire top row.
    -- It includes the tracking and calendar cells, not only the central label.
    if not MM.HeaderSurround then
        local surround = CreateFrame("Frame", nil, cluster)
        surround:SetHeight(HEADER_HEIGHT + 2)
        surround:SetFrameStrata(mapStrata())
        surround:SetFrameLevel(map:GetFrameLevel() + 7)
        local backing = surround:CreateTexture(nil, "BACKGROUND")
        backing:SetAllPoints()
        backing:SetColorTexture(0.15, 0.075, 0.035, 0.76)
        addon.Backgrounds.Track("minimap", backing)
        MM.HeaderBacking = backing
        -- FlareUI's actual minimap header uses Forever's own sliced
        -- ui-hud-minimap-header-button atlas, NOT a full-window NineSlice.
        -- NineSlice's top/bottom edges have a minimum width and create
        -- dangling bars on a 21px header. Use one sliced plate instead.
        local art = surround:CreateTexture(nil, "ARTWORK")
        plate(art, surround)
        MM.HeaderSurroundArt = art
        MM.HeaderSurround = surround
        local fill = header:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", -1, 1)
        MM.HeaderStyleFill = fill
        MM.HeaderStyleBorder = addon.Theme:CreateFrameBorder(header, header, header)
    end
    local topLevel = map:GetFrameLevel() + 9
    for _, widget in ipairs({tracking, cluster.ZoneTextButton, calendar}) do
        widget:SetFrameStrata(mapStrata())
        widget:SetFrameLevel(topLevel)
    end
    tracking:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    if tracking.Background then tracking.Background:Hide() end
    if tracking.Button then
        tracking.Button:ClearAllPoints()
        tracking.Button:SetAllPoints(tracking)
        fitButtonArt(tracking.Button)
    end
    if calendar then
        calendar:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
        fitButtonArt(calendar)
        calendar:ClearAllPoints()
        calendar:SetPoint("TOPRIGHT", MM.Border, "TOPRIGHT", -HEADER_SIDE, -4)
    end
    local clock = _G.TimeManagerClockButton
    local ticker = _G.TimeManagerClockTicker
    local width = CLOCK_WIDTH
    if ticker and ticker.GetUnboundedStringWidth then
        width = math.max(width, math.ceil(ticker:GetUnboundedStringWidth() or 0) + 8)
    end
    tracking:ClearAllPoints()
    tracking:SetPoint("TOPLEFT", MM.Border, "TOPLEFT", HEADER_SIDE, -4)
    local surround = MM.HeaderSurround
    surround:ClearAllPoints()
    -- The central plate belongs only to zone/clock. The two side buttons
    -- have independent plates, so hiding either hides its border as well.
    surround:SetPoint("TOPLEFT", header, "TOPLEFT", -2, 1)
    surround:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 2, -1)
    header:ClearAllPoints()
    header:SetPoint("LEFT", tracking, "RIGHT", HEADER_GAP, 0)
    if calendar then header:SetPoint("RIGHT", calendar, "LEFT", -HEADER_GAP, 0)
    else header:SetPoint("RIGHT", MM.Border, "RIGHT", -HEADER_SIDE, 0) end
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
    if calendar and not MM.CalendarPlate then
        MM.CalendarPlate = calendar:CreateTexture(nil, "BACKGROUND", nil, -1)
        MM.CalendarPlate:SetAllPoints(calendar)
        plate(MM.CalendarPlate, calendar)
    end
    MM.TrackingPlate:SetShown(not cfg.hideTracking)
    if calendar then MM.CalendarPlate:SetShown(not cfg.hideCalendar) end
    local showHeader = not (cfg.hideZone and cfg.hideClock)
    header:SetShown(showHeader)
    MM.HeaderSurround:SetShown(showHeader)
    tracking:SetShown(not cfg.hideTracking)
    zone:SetShown(not cfg.hideZone)
    if calendar then calendar:SetShown(not cfg.hideCalendar) end
    if clock then clock:SetShown(not cfg.hideClock) end
    MM:RefreshHeaderStyle()
    refreshPreviewLayer(positioningPreview and cfg.enabled)
end
local function layout()
    if applying or not square or not map or not cluster then return end
    if InCombatLockdown and InCombatLockdown() and map.IsProtected and map:IsProtected() then
        return
    end
    applying = true
    refreshMapLayers()
    parkRoundArt()
    createArt()
    if cluster.MinimapContainer then cluster.MinimapContainer:SetScale(1) end
    cluster:SetSize(MAP_SIZE + FRAME_PAD * 2, MAP_SIZE + FRAME_PAD * 2)
    map:SetSize(MAP_SIZE - MAP_CROP * 2, MAP_SIZE - MAP_CROP * 2)
    map:ClearAllPoints()
    -- Preserve temporary offsets so external scanners can restore the map.
    map:SetPoint("CENTER", cluster, "CENTER", scanX, scanY)
    setSquareMask()
    headerLayout()
    placeSun()
    -- Header/layout updates can reactivate the decorative holder's mouse.
    -- This is the exact frame isolated by /bazidebug border.
    if MM.Border then MM.Border:EnableMouse(false) end
    if addon.MinimapButtons and addon.MinimapButtons.RefreshAddonButtons then
        addon.MinimapButtons.RefreshAddonButtons()
    end
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
        local scale = math.max(0.7, math.min(1.5, value))
        if cluster:GetScale() ~= scale then cluster:SetScale(scale) end
    end
end
local originalPoints
local positionPending, positionQueued, changingPosition
local function ownsPosition(cfg)
    return cfg and cfg.enabled and (cfg.x ~= nil or cfg.y ~= nil)
end

local originalClusterMouse
local function refreshClusterMouse()
    if not cluster then return end
    local cfg = db()
    if cfg and cfg.enabled and (square or ownsPosition(cfg)) then
        -- The layout container can extend beyond the map and cover world input.
        -- The minimap and its buttons receive input on their own frames.
        if not originalClusterMouse then
            originalClusterMouse = {enabled = cluster:IsMouseEnabled()}
            if cluster.IsMouseClickEnabled and cluster.IsMouseMotionEnabled
                and cluster.SetMouseClickEnabled and cluster.SetMouseMotionEnabled then
                originalClusterMouse.click = cluster:IsMouseClickEnabled()
                originalClusterMouse.motion = cluster:IsMouseMotionEnabled()
            end
        end
        cluster:EnableMouse(false)
    elseif originalClusterMouse then
        cluster:EnableMouse(originalClusterMouse.enabled)
        if originalClusterMouse.click ~= nil then
            cluster:SetMouseClickEnabled(originalClusterMouse.click)
            cluster:SetMouseMotionEnabled(originalClusterMouse.motion)
        end
        originalClusterMouse = nil
    end
end

local function applyPosition()
    local cfg = db()
    if not cfg or not cluster or not map then return end
    if InCombatLockdown() then positionPending = true; return end
    positionPending = false
    local positioned = ownsPosition(cfg)
    if not originalPoints then
        if not positioned then return end
        originalPoints = {}
        for index = 1, cluster:GetNumPoints() do originalPoints[index] = {cluster:GetPoint(index)} end
        if #originalPoints == 0 then originalPoints = nil; return end
    end
    if positioned then
        local dx, dy = 0, 0
        if not square then
            local mapX, mapY = map:GetCenter()
            local clusterX, clusterY = cluster:GetCenter()
            if mapX and clusterX then
                local relativeScale = map:GetEffectiveScale() / cluster:GetEffectiveScale()
                dx, dy = mapX * relativeScale - clusterX, mapY * relativeScale - clusterY
            end
        end
        local ratio = UIParent:GetEffectiveScale() / cluster:GetEffectiveScale()
        local x, y = (cfg.x or 0) * ratio - dx, (cfg.y or 0) * ratio - dy
        local point, relative, relativePoint, oldX, oldY = cluster:GetPoint(1)
        if cluster:GetNumPoints() == 1 and point == "CENTER" and relative == UIParent and relativePoint == "CENTER"
            and math.abs((oldX or 0) - x) < 0.01 and math.abs((oldY or 0) - y) < 0.01 then return end
        changingPosition = true
        cluster:ClearAllPoints()
        cluster:SetPoint("CENTER", UIParent, "CENTER", x, y)
        changingPosition = false
    else
        changingPosition = true
        cluster:ClearAllPoints()
        for _, anchor in ipairs(originalPoints) do cluster:SetPoint(unpack(anchor)) end
        changingPosition = false
        originalPoints = nil
    end
end

local function hideEditSelection()
    local selection = cluster and cluster.Selection
    if selection and ownsPosition(db()) and not InCombatLockdown() then selection:Hide() end
end

local function refreshPosition()
    if InCombatLockdown() then positionPending = true; return end
    changingPosition = true
    applyScales()
    changingPosition = false
    applyPosition()
    refreshClusterMouse()
    hideEditSelection()
    local cfg = db()
    refreshPreviewLayer(positioningPreview and cfg and cfg.enabled)
    if square and cfg and cfg.enabled then
        refreshMapLayers()
        placeSun()
    end
end

function MM:SetPositioningPreview(active)
    positioningPreview = active
    refreshPosition()
end

local function queuePosition()
    if changingPosition or positionQueued or addon.Movers and addon.Movers.IsDragging(cluster) then return end
    local cfg = db()
    if not originalClusterMouse and not (cfg and cfg.enabled and (square or ownsPosition(cfg))) then return end
    positionQueued = true
    C_Timer.After(0, function()
        positionQueued = false
        refreshPosition()
    end)
end

local positionEvents = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED",
    "UPDATE_EDIT_MODE_LAYOUTS", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do
    pcall(positionEvents.RegisterEvent, positionEvents, event)
end
positionEvents:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_TimeManager" then
            self:UnregisterEvent(event)
            queueLayout()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if positionPending then refreshPosition() end
        applyMail()
    else
        queuePosition()
        if event == "PLAYER_ENTERING_WORLD" and db() then initMail(); applyMail() end
    end
end)

function MM:Initialize()
    if self.initialized then return end
    self.initialized = true
    local cfg = db()
    if cluster and hooksecurefunc then
        hooksecurefunc(cluster, "SetPoint", queuePosition)
        hooksecurefunc(cluster, "ClearAllPoints", queuePosition)
        hooksecurefunc(cluster, "SetScale", queuePosition)
        if cluster.OnEditModeEnter then
            hooksecurefunc(cluster, "OnEditModeEnter", hideEditSelection)
        end
        if cluster.Selection and cluster.Selection.HookScript then
            cluster.Selection:HookScript("OnShow", hideEditSelection)
        end
    end
    if not cfg or not cfg.enabled or not map then return end
    square = cfg.style == "square"
    initMail()
    watchScanOffsets()
    if square then
        layout()
        if C_AddOns.IsAddOnLoaded("Blizzard_TimeManager") then
            queueLayout()
        else
            positionEvents:RegisterEvent("ADDON_LOADED")
        end
        if cluster and hooksecurefunc then
            hooksecurefunc(cluster, "SetSize", queueLayout)
            if cluster.UpdateMinimapConfig then
                hooksecurefunc(cluster, "UpdateMinimapConfig", queueLayout)
            end
        end
    end
    if hooksecurefunc then hooksecurefunc(map, "SetZoom", onZoom) end
    applyMail()
    refreshPosition()
    -- Blizzard's Edit Mode can reapply its own icon scale after login.
    -- Reassert the saved setting once the UI has settled.
    if C_Timer and C_Timer.After then
        C_Timer.After(1, refreshPosition)
        C_Timer.After(3, refreshPosition)
    end
end
function MM:Apply()
    -- Shape changes are applied on reload to avoid leaving Blizzard's artwork detached.
    -- Do not re-parent textures when the round style is active.
    if square then refreshMapLayers(); updateBorder(); headerLayout(); placeSun() end
    refreshPosition()
    applyMail()
end
