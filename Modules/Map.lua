local addon = BaziUI
local data = addon.MapData
local map = {}
addon.Map = map

map.options = {
    {"reveal", "Show unexplored areas"},
    {"points", "Show points of interest"},
    {"levels", "Show zone levels"},
    {"coordinates", "Show coordinates"},
    {"hideTowns", "Hide town and city icons"},
    {"dungeons", "Show dungeon maps"},
    {"discovery", "Show discovery areas"},
    {"fishing", "Show fishing skill"},
    {"availableQuests", "Show available quests"},
}

local defaults = {
    reveal = true, points = true, levels = true, coordinates = true,
    hideTowns = false, dungeons = true, discovery = false, fishing = true, pointSize = 24,
}
map.pointOptions = {
    {"instances", "Show dungeons and raids"},
    {"flights", "Show flight points"},
    {"transport", "Show boats, zeppelins and trams"},
    {"portals", "Show portals"},
    {"crossings", "Show zone crossings"},
}
for _, option in ipairs(map.pointOptions) do defaults[option[1]] = true end
local world, header, border, grip, readout, drag
local questCount, continentButton, zoneButton
local initialFit = true
local initialViewport
local opacity, tick = 1, 0
local overlayTiles, outlines, markers = {}, {}, {}
local hiddenPins = setmetatable({}, {__mode = "k"})
local queued, explorationPin = false, nil

local function settings()
    local profile = addon.db.profile
    profile.worldMap = profile.worldMap or {}
    return profile.worldMap
end

function map.GetOption(key)
    local value = settings()[key]
    if value == nil then return defaults[key] end
    return value
end

function map.SetOption(key, enabled)
    settings()[key] = enabled
    map.Refresh()
end

local function headerColor()
    local chat = addon.Chat
    if chat and chat.active and chat.Skin and chat.Skin.DockHeaderColor then
        return chat.Skin.DockHeaderColor()
    end
    return 0.24, 0.17, 0.10, 0.95
end

local function canMove()
    return not InCombatLockdown() and not world:IsMaximized()
end

local function artSize(size)
    local rounded = 16
    while rounded < size do rounded = rounded * 2 end
    return rounded
end

local function drawExploration(mapID, config)
    for _, texture in ipairs(overlayTiles) do texture:Hide() end
    for _, outline in ipairs(outlines) do outline:Hide() end
    if not C_MapExplorationInfo or not world.EnumeratePinsByTemplate
        or not config.reveal and not config.discovery then return end
    local zones = data.overlays[C_Map.GetMapArtID(mapID)]
    local layers = C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[world.ScrollContainer:GetCurrentLayerIndex()]
    if not zones or not layer or not layer.tileWidth or not layer.tileHeight then return end

    local pin
    for candidate in world:EnumeratePinsByTemplate("MapExplorationPinTemplate") do pin = candidate; break end
    if not pin then return end
    if pin ~= explorationPin then
        explorationPin, overlayTiles, outlines = pin, {}, {}
    end
    local explored = {}
    for _, area in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
        local key = table.concat({area.textureWidth, area.textureHeight, area.offsetX, area.offsetY}, ":")
        explored[key] = true
    end

    local tile, areaIndex = 0, 0
    local stepX, stepY = layer.tileWidth, layer.tileHeight
    for _, area in ipairs(zones) do
        local width, height, x, y = unpack(area, 1, 4)
        local key = table.concat({width, height, x, y}, ":")
        if not explored[key] then
            if config.reveal then
                local file = 5
                for row = 0, height - 1, stepY do
                    for column = 0, width - 1, stepX do
                        local fileID = area[file]
                        file = file + 1
                        if fileID then
                            tile = tile + 1
                            local texture = overlayTiles[tile] or pin:CreateTexture(nil, "ARTWORK", nil, -1)
                            overlayTiles[tile] = texture
                            local w, h = math.min(stepX, width - column), math.min(stepY, height - row)
                            texture:ClearAllPoints()
                            texture:SetPoint("TOPLEFT", x + column, -y - row)
                            texture:SetSize(w, h)
                            texture:SetTexCoord(0, w / artSize(w), 0, h / artSize(h))
                            texture:SetTexture(fileID)
                            texture:SetVertexColor(0.55, 0.52, 0.50)
                            texture:Show()
                        end
                    end
                end
            end
            if config.discovery then
                areaIndex = areaIndex + 1
                local outline = outlines[areaIndex]
                if not outline then
                    outline = CreateFrame("Frame", nil, pin, "BackdropTemplate")
                    outline:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
                    outline:SetBackdropBorderColor(1, 0.79, 0.34, 0.8)
                    outlines[areaIndex] = outline
                end
                outline:ClearAllPoints()
                outline:SetPoint("TOPLEFT", x, -y)
                outline:SetSize(width, height)
                outline:Show()
            end
        end
    end
end

local townMaps = {[1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true}
local atlases = {
    Arrow = "Garr_LevelUpgradeArrow", Dungeon = "Dungeon", Dunraid = "Dungeon", Raid = "Raid",
    FlightA = "TaxiNode_Alliance", FlightH = "TaxiNode_Horde", FlightN = "TaxiNode_Neutral",
    TravelA = "Vehicle-TempleofKotmogu-CyanBall", TravelH = "Vehicle-TempleofKotmogu-CyanBall",
    TravelN = "Vehicle-TempleofKotmogu-CyanBall",
    PortalA = "MagePortalAlliance",
    QuestOffer = "QuestNormal",
}
local pointTypes = {
    Arrow = "crossings", Dungeon = "instances", Dunraid = "instances", Raid = "instances",
    FlightA = "flights", FlightH = "flights", FlightN = "flights",
    TravelA = "transport", TravelH = "transport", TravelN = "transport",
    PortalA = "portals",
}

local townIcons = {
    [0.35546875] = 0.001953125,
    [0.28515625] = 0.107421875,
    [0.42578125] = 0.107421875,
}

local function isTownIcon(pin)
    if pin.GetLinkedUIMapID and townMaps[pin:GetLinkedUIMapID()] then return true end
    local texture = pin.Texture
    if texture and texture:GetTexture() == 136441 then
        local left, top = texture:GetTexCoord()
        return townIcons[left] == top
    end
end

local function openFloors(owner, point)
    local floors = {}
    for _, id in ipairs(point[6] or {}) do
        local info = C_Map.GetMapInfo(id)
        local art = info and C_Map.GetMapArtLayers(id)
        if art and art[1] then floors[#floors + 1] = info end
    end
    if #floors == 1 then
        world:SetMapID(floors[1].mapID)
    elseif #floors > 1 and MenuUtil then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(point[4])
            for i, info in ipairs(floors) do
                root:CreateButton(string.format("%d. %s", i, info.name), function() world:SetMapID(info.mapID) end)
            end
        end)
    end
end

local function availableQuests(mapID)
    local points, seen = {}, {}
    if not (C_QuestLine and C_QuestLine.GetAvailableQuestLines and C_QuestLog and C_QuestLog.IsOnQuest
        and C_QuestLog.IsQuestFlaggedCompleted) then return points end
    local info = C_Map.GetMapInfo(mapID)
    if not info or info.mapType < 3 then return points end
    for _, quest in ipairs(C_QuestLine.GetAvailableQuestLines(mapID) or {}) do
        local id, x, y = quest.questID, quest.x, quest.y
        if id and not seen[id] and not quest.inProgress and not C_QuestLog.IsOnQuest(id)
            and not C_QuestLog.IsQuestFlaggedCompleted(id)
            and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            local name = quest.questName or C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
            if name then
                seen[id] = true
                points[#points + 1] = {"QuestOffer", x * 100, y * 100, name}
            end
        end
    end
    return points
end

local function drawPoints(mapID, config)
    for _, button in ipairs(markers) do button:Hide() end
    for pin, shown in pairs(hiddenPins) do
        pin:SetAlpha(shown)
        hiddenPins[pin] = nil
    end
    local info = C_Map.GetMapInfo(mapID)
    if config.hideTowns and info and info.mapType <= 2 and world.ExecuteOnAllPins then
        world:ExecuteOnAllPins(function(pin)
            if isTownIcon(pin) then
                hiddenPins[pin] = pin:GetAlpha()
                pin:SetAlpha(0)
            end
        end)
    end

    local canvas = world:GetCanvas()
    local manager = world.GetPinFrameLevelsManager and world:GetPinFrameLevelsManager()
    local level = manager and manager.GetValidFrameLevel and manager:GetValidFrameLevel("PIN_FRAME_LEVEL_TOPMOST", 1000)
    level = math.min((level or canvas:GetFrameLevel() + 1000) + 5, 9500)
    local count = 0
    local function marker(point)
        local kind = point[1]
        count = count + 1
        local button = markers[count]
        if not button then
            button = CreateFrame("Button", nil, canvas)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetAllPoints()
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.point[4])
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button:SetScript("OnClick", function(self)
                if InCombatLockdown() or self.point[1] == "QuestOffer" then return end
                if self.point[5] and C_Map.GetMapInfo(self.point[5]) then
                    world:SetMapID(self.point[5])
                elseif map.GetOption("dungeons") then
                    openFloors(self, self.point)
                end
            end)
            markers[count] = button
        end
        button.point = point
        local size = map.GetOption("pointSize")
        button:SetSize(size, size)
        button:SetFrameLevel(level)
        local atlas = atlases[kind]
        if atlas and (not C_Texture or not C_Texture.GetAtlasInfo or C_Texture.GetAtlasInfo(atlas)) then
            button.icon:SetAtlas(atlas)
        elseif kind == "QuestOffer" then
            button.icon:SetTexture(132048)
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
        end
        button:Show()
    end
    if config.points then
        for _, point in ipairs(data.points[mapID] or {}) do
            local category = pointTypes[point[1]]
            if category and map.GetOption(category) and not (config.hideTowns and townMaps[point[5]]) then
                marker(point)
            end
        end
    end
    if config.availableQuests then
        for _, point in ipairs(availableQuests(mapID)) do marker(point) end
    end
end

local function sizeMarkers()
    if not markers[1] or not world:IsShown() then return end
    local scale = world.GetCanvasScale and world:GetCanvasScale() or 1
    if not scale or scale <= 0 then return end
    local canvas = world:GetCanvas()
    if not canvas then return end
    local width, height = canvas:GetSize()
    for _, button in ipairs(markers) do
        if button:IsShown() then
            button:SetScale(1 / scale)
            -- WoW interprets anchor offsets in the marker's scaled units.
            button:ClearAllPoints()
            button:SetPoint("CENTER", canvas, "TOPLEFT",
                width * button.point[2] * scale / 100, -height * button.point[3] * scale / 100)
        end
    end
end

local function fitViewport(mapID)
    if InCombatLockdown() or world:IsMaximized() then return end
    local layers = C_Map.GetMapArtLayers(mapID)
    local art = layers and layers[1]
    if not art or not art.layerWidth or not art.layerHeight or art.layerHeight <= 0 then return end
    local viewportWidth, viewportHeight = world.ScrollContainer:GetSize()
    if viewportWidth <= 0 or viewportHeight <= 0 then return end
    local width = viewportHeight * art.layerWidth / art.layerHeight
    if math.abs(width - viewportWidth) > 1 then
        world:SetWidth(world:GetWidth() + width - viewportWidth)
        if world.OnFrameSizeChanged then world:OnFrameSizeChanged() end
        return true
    end
    return false
end

local function continentOf(mapID)
    if not mapID then return end
    local info = C_Map.GetMapInfo(mapID)
    while info and info.mapType > Enum.UIMapType.Continent and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    return info and info.mapType == Enum.UIMapType.Continent and info
end

function map.RefreshHeaderStyle()
    if not header then return end
    header.fill:SetColorTexture(addon.Headers.Fill("map", headerColor()))
    local r, g, b = addon.Headers.Text("map", 1, 0.82, 0.49)
    for _, button in ipairs({continentButton, zoneButton}) do button:GetFontString():SetTextColor(r, g, b) end
    if questCount then
        questCount:SetTextColor(r, g, b)
        local _, count = C_QuestLog.GetNumQuestLogEntries()
        local limits = Constants and Constants.QuestLogConsts
        local limit = limits and limits.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT or _G.MAX_QUEST_LOG_SIZE or 40
        if addon.Headers.Get("map", "text") then
            questCount:SetFormattedText("%d/%d", count or 0, limit)
        else
            questCount:SetFormattedText("|cfff8ead1%d|r/%d", count or 0, limit)
        end
    end
end

local function refreshHeader(mapID)
    map.RefreshHeaderStyle()
    local file, size, flags = GameFontNormalSmall:GetFont()
    addon.Typography.Apply(questCount, "Map:Header", file, size, flags, true)
    file, size, flags = GameFontNormal:GetFont()
    for _, button in ipairs({continentButton, zoneButton}) do
        addon.Typography.Apply(button:GetFontString(), "Map:Header", file, size, flags, true)
    end
    file, size, flags = GameFontHighlightSmall:GetFont()
    addon.Typography.Apply(readout, "Map:Coordinates", file, size, flags, true)
    continentButton:SetPoint("LEFT", questCount, "RIGHT", 13, 0)
    local continent = continentOf(mapID)
    local info = C_Map.GetMapInfo(mapID)
    local function label(button, caption)
        button:SetText(caption)
        button:SetWidth(math.min(210, button:GetFontString():GetStringWidth() + 8))
    end
    label(continentButton, continent and continent.name or "Continents")
    label(zoneButton, continent and info and info.mapID ~= continent.mapID and info.name or "Zones")
end

local function refreshReadout(mapID)
    local parts = {}
    if map.GetOption("coordinates") then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then parts[#parts + 1] = string.format("Player: %.1f, %.1f", pos.x * 100, pos.y * 100) end
        if world.ScrollContainer:IsMouseOver() then
            local x, y = world:GetNormalizedCursorPosition()
            if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                parts[#parts + 1] = string.format("Cursor: %.1f, %.1f", x * 100, y * 100)
            end
        end
    end
    readout:SetText(table.concat(parts, "    ·    "))
end

local function addZoneHover()
    for provider in pairs(world.dataProviders or {}) do
        if provider.Label and provider.Label.SetLabel and provider.Label.EvaluateLabels then
            provider.Label:HookScript("OnUpdate", function(label)
                if not world:IsCanvasMouseFocus() then return end
                local levels, fishing = map.GetOption("levels"), map.GetOption("fishing")
                if not levels and not fishing then return end
                local mapID = world:GetMapID()
                local x, y = world:GetNormalizedCursorPosition()
                if not mapID or not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end
                local zone = C_Map.GetMapInfoAtPosition(mapID, x, y)
                if not zone or zone.mapID == mapID then return end
                local range = levels and data.zoneLevels[zone.mapID]
                local skill = fishing and data.fishing[zone.mapID]
                if not range and not skill then return end
                local name = zone.name
                if range then
                    local level = UnitLevel("player")
                    local min, max = unpack(range)
                    local difficulty = level > max and GetQuestDifficultyColor(max - 2)
                        or GetQuestDifficultyColor(level < min and min or level + 2)
                    name = name .. string.format(" |cff%02x%02x%02x(%d–%d)|r",
                        math.floor(difficulty.r * 255), math.floor(difficulty.g * 255),
                        math.floor(difficulty.b * 255), min, max)
                end
                label:SetLabel(MAP_AREA_LABEL_TYPE.AREA_NAME, name, skill and ("Fishing: " .. skill) or nil)
                label:EvaluateLabels()
            end)
        end
    end
end

function map.Refresh()
    if queued or not border or not world:IsShown() then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        if not world:IsShown() then return end
        local mapID = world:GetMapID()
        if not mapID then return end
        fitViewport(mapID)
        local config = {}
        for _, option in ipairs(map.options) do config[option[1]] = map.GetOption(option[1]) end
        drawExploration(mapID, config)
        drawPoints(mapID, config)
        sizeMarkers()
        refreshHeader(mapID)
        refreshReadout(mapID)
    end)
end

local function settleInitialViewport()
    if not initialFit or InCombatLockdown() then return end
    local mapID = world:GetMapID()
    if not mapID then return end
    local changed = fitViewport(mapID)
    if changed == nil then return end
    local width, height = world.ScrollContainer:GetSize()
    local previous = initialViewport
    initialViewport = {mapID, width, height}
    if changed or not previous or previous[1] ~= mapID or previous[2] ~= width or previous[3] ~= height
        or world.AreDetailLayersLoaded and not world:AreDetailLayersLoaded() then return end
    initialFit, initialViewport = false, nil
    world:ResetZoom()
    map.Refresh()
end

local function update(_, elapsed)
    settleInitialViewport()
    local speed = GetUnitSpeed("player")
    local moving = type(speed) == "number" and (not issecretvalue or not issecretvalue(speed))
        and (not canaccessvalue or canaccessvalue(speed)) and speed > 0
    local alpha = moving and math.max(0.75, opacity - elapsed * (0.25 / 0.65)) or 1
    if alpha ~= opacity then world:SetAlpha(alpha); opacity = alpha end
    if drag then
        if not IsMouseButtonDown("LeftButton") or not canMove() then
            drag = nil
        else
            local x, y = GetCursorPosition()
            local delta = ((x - drag.x) * drag.width - (y - drag.y) * drag.height)
                / (drag.width * drag.width + drag.height * drag.height)
            local scale = math.max(0.55, math.min(1.6, drag.scale * (1 + delta)))
            if scale ~= world:GetScale() then world:SetScale(scale); settings().scale = scale end
        end
    end
    tick = tick + elapsed
    if tick >= 0.10 then
        tick = 0
        local mapID = world:GetMapID()
        if mapID then refreshReadout(mapID) end
    end
end

local function restorePosition()
    if not canMove() then return end
    local config = settings()
    if config.scale then world:SetScale(config.scale) end
    if config.position then
        local point, relativePoint, x, y = unpack(config.position)
        world:ClearAllPoints()
        world:SetPoint(point, UIParent, relativePoint, x, y)
    end
end

local function createMapMenu(parent, getChoices)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(22)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    button:SetFontString(text)
    button:SetNormalFontObject("GameFontNormal")
    button:SetHighlightFontObject("GameFontHighlight")
    text:SetTextColor(1, 0.82, 0.49)
    button:SetScript("OnClick", function(self)
        if InCombatLockdown() or not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            if root.SetScrollMode then root:SetScrollMode(320) end
            for _, info in ipairs(getChoices()) do
                root:CreateButton(info.name, function() world:SetMapID(info.mapID) end)
            end
        end)
    end)
    return button
end

local function mapChoices(continent)
    local choices, seen = {}, {}
    local function add(info)
        if info and not seen[info.name] then
            seen[info.name] = true
            choices[#choices + 1] = info
        end
    end
    if continent then
        add(continent)
        for _, info in ipairs(C_Map.GetMapChildrenInfo(continent.mapID, Enum.UIMapType.Zone) or {}) do add(info) end
    else
        add(C_Map.GetMapInfo(947))
        for _, root in ipairs({947, 946}) do
            for _, info in ipairs(C_Map.GetMapChildrenInfo(root, Enum.UIMapType.Continent) or {}) do add(info) end
        end
    end
    table.sort(choices, function(a, b) return a.name < b.name end)
    return choices
end

local function flatControl(button, glyph)
    if not button or button.baziMapIcon then return end
    if glyph == "×" then
        button.baziMapIcon = addon.Theme:CloseGlyph(button, 15)
        return
    end
    local icon = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    icon:SetText(glyph)
    icon:SetTextColor(1, 0.82, 0.49)
    icon:SetPoint("CENTER", 0, 0)
    button.baziMapIcon = icon
end

local function hideControlArt(button)
    if not button or not button.baziMapIcon then return end
    for _, region in ipairs({button:GetRegions()}) do
        if region ~= button.baziMapIcon and region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
end

local function applyChrome()
    if InCombatLockdown() then return end
    local native = world.BorderFrame
    for _, region in ipairs({native:GetRegions()}) do region:SetAlpha(0) end
    for _, region in pairs({native.NineSlice, native.PortraitContainer, native.TitleContainer, native.Bg, native.Tutorial}) do
        region:SetAlpha(0)
    end
    if native.Tutorial then native.Tutorial:EnableMouse(false) end
    if world.BlackoutFrame then world.BlackoutFrame:Hide() end
    for _, cvar in ipairs({"worldMapShowPlayerCoords", "worldMapShowCursorCoords"}) do
        if GetCVar(cvar) == "1" then SetCVar(cvar, "0") end
    end
    if world.TitleCanvasSpacerFrame then
        local spacer = world.TitleCanvasSpacerFrame
        for index = 1, spacer:GetNumPoints() do
            local point, relative, relativePoint, x = spacer:GetPoint(index)
            if point == "BOTTOMRIGHT" then
                spacer:SetPoint(point, relative, relativePoint, x, -30)
                break
            end
        end
    end
    if world.NavBar then world.NavBar:Hide() end
    local oldCount = _G.QuestLogCount
    if oldCount then oldCount:SetAlpha(0) end
    local close, maximize = native.CloseButton, native.MaximizeMinimizeFrame
    if close then
        close:ClearAllPoints()
        close:SetSize(20, 20)
        close:SetPoint("RIGHT", header, "RIGHT", -5, 0)
        close:SetFrameLevel(header:GetFrameLevel() + 3)
    end
    if close and maximize then
        maximize:ClearAllPoints()
        maximize:SetSize(20, 20)
        maximize:SetPoint("RIGHT", close, "LEFT", -3, 0)
        maximize:SetFrameLevel(header:GetFrameLevel() + 3)
        for _, button in ipairs({maximize:GetChildren()}) do
            button:SetFrameLevel(maximize:GetFrameLevel() + 1)
        end
        hideControlArt(maximize.MaximizeButton)
        hideControlArt(maximize.MinimizeButton)
    end
    hideControlArt(close)
    local list = QuestScrollFrame or (QuestMapFrame and QuestMapFrame.QuestsFrame)
    local quest = world.QuestLog or QuestMapFrame
    local questWidth = quest and quest:IsShown() and (world.questLogWidth or 333) or 0
    local canvas = world.ScrollContainer
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    canvas:SetPoint("BOTTOMRIGHT", world, "BOTTOMRIGHT", -questWidth - 3, 22)
    if list and questWidth > 0 then
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", canvas, "TOPRIGHT", 3, 0)
        -- The native scroll bar is anchored outside the list's right edge.
        list:SetPoint("BOTTOMRIGHT", world, "BOTTOMRIGHT", -27, 22)
    end
    local search, options = list and list.SearchBox, list and list.SettingsDropdown
    if search and options and maximize then
        options:ClearAllPoints()
        options:SetPoint("RIGHT", maximize, "LEFT", -5, 0)
        options:SetSize(20, 20)
        options:SetFrameLevel(header:GetFrameLevel() + 3)
        search:ClearAllPoints()
        search:SetPoint("LEFT", world.ScrollContainer, "TOPRIGHT", 7, 15)
        search:SetPoint("RIGHT", options, "LEFT", -7, 0)
        search:SetHeight(17)
        search:SetFrameLevel(header:GetFrameLevel() + 2)
    end
    local filter = world.WorldMapTrackingOptionsButton
    if filter then
        filter:ClearAllPoints()
        filter:SetPoint("TOPRIGHT", world.ScrollContainer, "TOPRIGHT", -5, -5)
    end
    local toggle = world.SidePanelToggle
    if not toggle then
        for _, frame in ipairs(world.overlayFrames or {}) do
            if frame.OpenButton and frame.CloseButton then toggle = frame; break end
        end
    end
    if toggle then
        toggle:ClearAllPoints()
        toggle:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -5, 4)
    end
    if continentButton then map.RefreshHeaderStyle() end
    grip:SetShown(canMove())
end

local function install()
    if border or not WorldMapFrame or not addon.db or InCombatLockdown() then return end
    world = WorldMapFrame
    if not world.BorderFrame or not world.ScrollContainer then return end

    local backing = world:CreateTexture(nil, "BACKGROUND", nil, -7)
    backing:SetPoint("TOPLEFT", 3, -3)
    backing:SetPoint("BOTTOMRIGHT", -3, 3)
    backing:SetColorTexture(0.095, 0.062, 0.043, 1)
    addon.Backgrounds.Track("map", backing)
    header = CreateFrame("Frame", nil, world)
    header:SetPoint("TOPLEFT", 3, -3)
    header:SetPoint("TOPRIGHT", -3, -3)
    header:SetHeight(26)
    header:SetFrameStrata("HIGH")
    header:SetFrameLevel(world.BorderFrame:GetFrameLevel() + 2)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header.fill = header:CreateTexture(nil, "BACKGROUND")
    header.fill:SetAllPoints()
    questCount = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    questCount:SetPoint("LEFT", 10, 0)
    continentButton = createMapMenu(header, function() return mapChoices() end)
    zoneButton = createMapMenu(header, function()
        local continent = continentOf(world:GetMapID()) or continentOf(C_Map.GetBestMapForUnit("player"))
        return continent and mapChoices(continent) or {}
    end)
    zoneButton:SetPoint("LEFT", continentButton, "RIGHT", 12, 0)
    for _, button in ipairs({continentButton, zoneButton}) do
        local divider = header:CreateTexture(nil, "ARTWORK")
        divider:SetSize(1, 11)
        divider:SetPoint("RIGHT", button, "LEFT", -4, 0)
        divider:SetColorTexture(0.82, 0.65, 0.47, 0.48)
    end
    local controls = world.BorderFrame
    flatControl(controls.CloseButton, "×")
    if controls.MaximizeMinimizeFrame then
        flatControl(controls.MaximizeMinimizeFrame.MaximizeButton, "^")
        flatControl(controls.MaximizeMinimizeFrame.MinimizeButton, "v")
    end
    world:SetMovable(true)
    world:SetClampedToScreen(true)
    header:SetScript("OnDragStart", function() if canMove() then world:StartMoving() end end)
    header:SetScript("OnDragStop", function()
        world:StopMovingOrSizing()
        world:SetUserPlaced(false)
        if canMove() then
            local point, _, relativePoint, x, y = world:GetPoint(1)
            settings().position = {point, relativePoint, x, y}
        end
    end)

    border = addon.Theme:CreateFrameBorder(world, world, world)
    border:SetFrameStrata("HIGH")
    border:EnableMouse(false)
    addon.Theme:AddDropShadow("Map", world, border)
    grip = CreateFrame("Button", nil, border)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    local slash = grip:CreateTexture(nil, "OVERLAY")
    slash:SetPoint("CENTER", 3, -3)
    slash:SetSize(13, 1.5)
    slash:SetColorTexture(0.9, 0.69, 0.38, 1)
    slash:SetRotation(math.pi / 4)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function()
        if not canMove() then return end
        local x, y = GetCursorPosition()
        local scale = world:GetEffectiveScale()
        drag = {x = x, y = y, scale = world:GetScale(), width = world:GetWidth() * scale, height = world:GetHeight() * scale}
        if drag.width <= 0 or drag.height <= 0 then drag = nil end
    end)
    grip:SetScript("OnDragStop", function() drag = nil end)

    local footer = CreateFrame("Frame", nil, border)
    footer:SetHeight(19)
    footer:SetPoint("BOTTOMLEFT", world, "BOTTOMLEFT", 3, 3)
    footer:SetPoint("BOTTOMRIGHT", world, "BOTTOMRIGHT", -3, 3)
    local footerFill = footer:CreateTexture(nil, "BACKGROUND")
    footerFill:SetAllPoints()
    footerFill:SetColorTexture(0.17, 0.114, 0.076, 1)
    readout = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    readout:SetPoint("LEFT", 5, 0)
    readout:SetPoint("RIGHT", -5, 0)
    readout:SetJustifyH("LEFT")
    readout:SetShadowColor(0, 0, 0, 1)
    readout:SetShadowOffset(1, -1)

    local function show()
        if GetCVar("mapFade") == "1" then SetCVar("mapFade", "0") end
        applyChrome()
        restorePosition()
        map.Refresh()
    end
    border:SetScript("OnUpdate", update)
    world:HookScript("OnShow", show)
    world:HookScript("OnHide", function()
        drag, opacity = nil, 1
        initialViewport = nil
        world:SetAlpha(1)
    end)
    hooksecurefunc(world, "OnMapChanged", map.Refresh)
    hooksecurefunc(world, "OnMapChanged", applyChrome)
    if BaseMapPoiPinMixin and BaseMapPoiPinMixin.OnAcquired then
        hooksecurefunc(BaseMapPoiPinMixin, "OnAcquired", function(pin)
            if map.GetOption("hideTowns") and pin.GetMap and pin:GetMap() == world then map.Refresh() end
        end)
    end
    addZoneHover()
    hooksecurefunc(world, "OnCanvasSizeChanged", map.Refresh)
    world.ScrollContainer:HookScript("OnSizeChanged", map.Refresh)
    world:HookScript("OnSizeChanged", sizeMarkers)
    if world.OnCanvasScaleChanged then hooksecurefunc(world, "OnCanvasScaleChanged", sizeMarkers) end
    if world.UpdateSpacerFrameAnchoring then
        hooksecurefunc(world, "UpdateSpacerFrameAnchoring", function()
            applyChrome()
            map.Refresh()
        end)
    end
    local quest = world.QuestLog or QuestMapFrame
    if quest then
        local function syncQuestLayout()
            C_Timer.After(0, function()
                if not world:IsShown() then return end
                applyChrome()
                map.Refresh()
            end)
        end
        quest:HookScript("OnShow", syncQuestLayout)
        quest:HookScript("OnHide", syncQuestLayout)
    end
    if world.SynchronizeDisplayState then
        hooksecurefunc(world, "SynchronizeDisplayState", function()
            applyChrome()
            if world:IsMaximized() then world:SetScale(1) else restorePosition() end
        end)
    end
    if world:IsShown() then show() else applyChrome() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("MAP_EXPLORATION_UPDATED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:SetScript("OnEvent", function(_, event, name)
    if event == "QUEST_LOG_UPDATE" then
        if border and addon.db and map.GetOption("availableQuests") then map.Refresh()
        elseif border and world:IsShown() and world:GetMapID() then refreshHeader(world:GetMapID()) end
    elseif event == "MAP_EXPLORATION_UPDATED" then
        map.Refresh()
    elseif event ~= "ADDON_LOADED" or name == "Blizzard_WorldMap" then
        install()
    end
end)

