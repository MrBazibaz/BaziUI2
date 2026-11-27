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
    enabled = true,
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
local closeControl, displayControl, fullscreenControls
local initialFit = true
local initialViewport
local opacity, tick = 1, 0
local overlayTiles, outlines, markers = {}, {}, {}
local hiddenPins = setmetatable({}, {__mode = "k"})
local queued, explorationPin = false, nil
local skinQuestList
local skinQuestPins
local sidebarWidth, sidebarMaximized
local viewportNeedsLayout, previousMapStrata
local applyingChrome
local iconPath = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\"
local questArt = iconPath .. "Quest.tga"

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
    if key ~= "enabled" then map.Refresh() end
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
        local size = map.GetOption("pointSize") * (kind == "Arrow" and 1.25 or 1)
        button:SetSize(size, size)
        button:SetFrameLevel(level)
        local atlas = atlases[kind]
        button.icon:SetVertexColor(1, 1, 1)
        button.icon:SetDesaturated(false)
        if kind == "QuestOffer" then
            button.icon:SetTexture(questArt)
            button.icon:SetTexCoord(0, 1, 0, 1)
            button.icon:SetVertexColor(addon.Theme:Accent())
        elseif atlas and (not C_Texture or not C_Texture.GetAtlasInfo or C_Texture.GetAtlasInfo(atlas)) then
            button.icon:SetAtlas(atlas)
            if kind == "Arrow" then
                button.icon:SetDesaturated(true)
                button.icon:SetVertexColor(addon.Theme:Accent())
            end
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
    if readout then readout:SetTextColor(r, g, b) end
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
    addon.Typography.Apply(readout, "Map:Header", file, size, flags, true)
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
    -- Diagnostic: isolate canvas refresh from installed window chrome.
    if true then return end
    if queued or not border or not world:IsShown() then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        if not world:IsShown() then return end
        local mapID = world:GetMapID()
        if not mapID then return end
        local resized = fitViewport(mapID)
        if viewportNeedsLayout and not InCombatLockdown() then
            viewportNeedsLayout = nil
            if not resized and world.OnFrameSizeChanged then world:OnFrameSizeChanged() end
        end
        local config = {}
        for _, option in ipairs(map.options) do config[option[1]] = map.GetOption(option[1]) end
        drawExploration(mapID, config)
        drawPoints(mapID, config)
        sizeMarkers()
        refreshHeader(mapID)
        refreshReadout(mapID)
        -- Diagnostic isolation: leave Blizzard canvas quest pins untouched.
        -- Keep quest sidebar styling active to isolate the combat taint.
        skinQuestList()
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
    local alpha = moving and not world:IsMaximized() and math.max(0.75, opacity - elapsed * (0.25 / 0.65)) or 1
    if alpha ~= opacity then world:SetAlpha(alpha); opacity = alpha end
    if drag then
        if not IsMouseButtonDown("LeftButton") or not canMove() then
            drag = nil
        else
            local x, y = GetCursorPosition()
            local delta = ((x - drag.x) * drag.width - (y - drag.y) * drag.height)
                / (drag.width * drag.width + drag.height * drag.height)
            local scale = math.max(0.55, math.min(1.6, drag.scale * (1 + delta)))
            if scale ~= world:GetScale() then
                world:SetScale(scale)
                settings().scale = scale
                map.Refresh()
            end
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

map.ApplyMoverPosition = restorePosition

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

local function flatControl(button, iconName, size)
    if not button or not button.CreateTexture then return end
    if not button.baziMapIcon then
        button.baziMapSurface = addon.Theme:Surface(button, "Button", 10, "BACKGROUND", 1)
        local icon = button:CreateTexture(nil, "OVERLAY", nil, 5)
        icon:SetPoint("CENTER")
        icon:SetVertexColor(1, 0.83, 0.56)
        button.baziMapIcon = icon
        button:HookScript("OnEnter", function(self)
            addon.Theme:SetSurface(self.baziMapSurface, "ButtonHover", 10)
        end)
        button:HookScript("OnLeave", function(self)
            addon.Theme:SetSurface(self.baziMapSurface, "Button", 10)
        end)
    end
    local icon = button.baziMapIcon
    icon:SetTexture(iconPath .. iconName .. ".tga")
    icon:SetSize(size or 13, size or 13)
    icon:SetShown(true)
    for _, region in ipairs({button:GetRegions()}) do
        if region ~= icon and region ~= button.baziMapSurface and region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
end

local function silenceMapButtonArt(button)
    for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetHighlightTexture",
        "GetDisabledTexture", "GetCheckedTexture", "GetDisabledCheckedTexture"}) do
        local art = button[getter] and button[getter](button)
        if type(art) == "table" and art.SetAlpha then art:SetAlpha(0) end
    end
    for _, art in pairs({button.border, button.lit, button.glyph, button.bar, button.CheckMark}) do
        if type(art) == "table" and art.SetAlpha then art:SetAlpha(0) end
    end
end

local function paintMapPlayerControl(button, icon)
    flatControl(button, icon, 15)
    button.baziMapSurface:SetDrawLayer("ARTWORK", 3)
    silenceMapButtonArt(button)
end

local function updateMapCheck(box)
    silenceMapButtonArt(box)
    local checked
    if box.CheckMark then checked = box.CheckMark:IsShown()
    else checked = box:GetChecked() end
    if issecretvalue and issecretvalue(checked) then return end
    checked = checked == true or checked == 1
    addon.Theme:SetSurface(box.baziMapSurface, checked and "ButtonActive" or "Button", 10)
    box.baziMapIcon:SetShown(checked)
end

local function paintMapTrackingButton(box)
    if not box or not (box.CheckMark or box.GetChecked) then return end
    paintMapPlayerControl(box, "Check")
    updateMapCheck(box)
    if not box.baziMapTrackingHook then
        if box.CheckMark then
            hooksecurefunc(box.CheckMark, "SetShown", function() updateMapCheck(box) end)
        elseif box.SetChecked then
            hooksecurefunc(box, "SetChecked", updateMapCheck)
        end
        box:HookScript("OnLeave", updateMapCheck)
        box.baziMapTrackingHook = true
    end
end

local function mapPlaybackIcon(state)
    if state == "stop" then return "Stop" end
    if state == "pause" then return "Pause" end
    if state == "queue" or state == "queued" then return "Queue" end
    return "Play"
end

local function placeQuestTags(row, control, reservedWidth)
    reservedWidth = reservedWidth or 0
    if row.TagTexture then row.TagTexture:SetPoint("RIGHT", control, "LEFT", -4 - reservedWidth, 0) end
    local tag = row.TagText
    if tag and tag:IsShown() then
        tag:ClearAllPoints()
        tag:SetPoint("TOPRIGHT", control, "TOPLEFT", -6 - reservedWidth, -1)
        if row.Text then row.Text:SetPoint("RIGHT", tag, "LEFT", -4, 0) end
    end
end

local function paintMapPlayback(parent, rows)
    for _, button in ipairs({parent:GetChildren()}) do
        if button.MatchBox and button.SetState and button.glyph and button:IsShown() then
            local row = rows[button.questID or (button.soundData and button.soundData.questID)]
            if not row then
                local _, anchor = button:GetPoint()
                row = rows[anchor]
            end
            if row and row.Checkbox then
                button:ClearAllPoints()
                button:SetPoint("RIGHT", row.Checkbox, "LEFT", -4, 0)
                placeQuestTags(row, button)
                paintMapPlayerControl(button, mapPlaybackIcon(button.state))
                if not button.baziMapPlaybackHook then
                    hooksecurefunc(button, "SetState", function(self, state)
                        self.baziMapIcon:SetTexture(iconPath .. mapPlaybackIcon(state) .. ".tga")
                        silenceMapButtonArt(self)
                    end)
                    for _, script in ipairs({"OnEnter", "OnLeave", "OnEnable", "OnDisable"}) do
                        button:HookScript(script, function(self)
                            silenceMapButtonArt(self)
                            self.baziMapIcon:SetAlpha(self:IsEnabled() and 1 or 0.4)
                        end)
                    end
                    button.baziMapPlaybackHook = true
                end
                button.baziMapIcon:SetAlpha(button:IsEnabled() and 1 or 0.4)
            end
        end
    end
end

local function getMapObjectives(questID)
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}
    if not (GetNumQuestLeaderBoards and GetQuestLogLeaderBoard and C_QuestLog.GetLogIndexForQuestID) then return objectives end
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    if not index or index <= 0 then return objectives end
    local count = GetNumQuestLeaderBoards(index)
    if type(count) ~= "number" or count <= #objectives then return objectives end
    local legacy = {}
    for i = 1, count do
        local text, _, finished = GetQuestLogLeaderBoard(i, index)
        legacy[i] = objectives[i] or {text = text, finished = finished}
    end
    return legacy
end

local function mapObjectiveText(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return "" end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s*%-?%s*", "")
        :gsub("^•%s*", ""):gsub("%s+$", ""))
end

local function objectiveProgress(label, objectives)
    local have, need = label:match("(%d+)%s*/%s*(%d+)")
    have, need = tonumber(have), tonumber(need)
    if have and need and need > 0 then return math.min(1, have / need) end
    for _, objective in ipairs(objectives) do
        if label == mapObjectiveText(objective.text) then
            have, need = objective.numFulfilled, objective.numRequired
            if type(have) == "number" and type(need) == "number"
                and (not issecretvalue or not issecretvalue(have) and not issecretvalue(need)) and need > 0 then
                return math.max(0, math.min(1, have / need))
            end
        end
    end
end

local function questMarkerID(button)
    local id = button.GetQuestID and button:GetQuestID() or button.questID
    if type(id) == "number" and (not issecretvalue or not issecretvalue(id)) and id > 0 then return id end
end

local function paintQuestBadge(button, questID)
    local badge = button.baziQuestBadge
    local styles = POIButtonUtil and POIButtonUtil.Style
    local style = styles and button.GetStyle and button:GetStyle()
    if style and style ~= styles.QuestInProgress and style ~= styles.QuestComplete then questID = nil end
    if not questID then
        if badge then
            badge:Hide()
            for region, alpha in pairs(badge.originalAlpha) do region:SetAlpha(alpha) end
            wipe(badge.originalAlpha)
        end
        return
    end
    if not badge then
        badge = button:CreateTexture(nil, "ARTWORK", nil, 5)
        badge:SetAllPoints(button)
        badge.originalAlpha = {}
        button.baziQuestBadge = badge
        if button.UpdateButtonAlpha then
            hooksecurefunc(button, "UpdateButtonAlpha", function()
                if not badge:IsShown() or questMarkerID(button) ~= badge.questID then return end
                for region in pairs(badge.originalAlpha) do region:SetAlpha(0) end
            end)
        end
    end
    local ready = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID)
    if (not issecretvalue or not issecretvalue(ready)) and not ready and C_QuestLog.IsComplete then
        ready = C_QuestLog.IsComplete(questID)
    end
    local complete = styles and style == styles.QuestComplete
        or (not issecretvalue or not issecretvalue(ready)) and (ready == true or ready == 1)
    badge.questID = questID
    badge:SetTexture(iconPath .. (complete and "QuestTurnIn" or "QuestProgress") .. ".tga")
    badge:Show()
    for _, region in pairs({button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture()),
        button.PushedTexture or (button.GetPushedTexture and button:GetPushedTexture()), button.Display}) do
        if badge.originalAlpha[region] == nil then badge.originalAlpha[region] = region:GetAlpha() end
        region:SetAlpha(0)
    end
end

skinQuestPins = function()
    if not world.ExecuteOnAllPins or InCombatLockdown() then return end
    world:ExecuteOnAllPins(function(pin)
        local button = pin.POIButton or pin
        if not (button:IsObjectType("Button") or button.NormalTexture or button.baziQuestBadge) then return end
        local id = questMarkerID(button) or (button ~= pin and questMarkerID(pin))
        local index = id and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
        paintQuestBadge(button, type(index) == "number" and (not issecretvalue or not issecretvalue(index))
            and index > 0 and id or nil)
    end)
end

local function alignQuestCard(card, row, list, inset)
    local listLeft, listRight, rowLeft = list:GetLeft(), list:GetRight(), row:GetLeft()
    card:ClearAllPoints()
    if listLeft and listRight and rowLeft then
        card:SetPoint("TOPLEFT", row, "TOPLEFT", listLeft - rowLeft, -inset)
        card:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", listRight - rowLeft, inset)
    else
        card:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -inset)
        card:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, inset)
    end
end

local questListRows = setmetatable({}, {__mode = "k"})
local layingOutQuestList
local function decorateQuestRow(row, list, activeRows, playbackParents)
    if not row:IsShown() then return end
    local questID = row.questID or row.QuestID
    if type(questID) ~= "number" and row.GetElementData then
        local info = row:GetElementData()
        questID = type(info) == "table" and info.questID
    end
    if type(questID) ~= "number" and row.questLogIndex and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(row.questLogIndex)
        questID = info and info.questID
    end
    local display = questListRows[row]
    if type(questID) ~= "number" or (issecretvalue and issecretvalue(questID)) or questID <= 0 then
        if display then
            display.back:Hide()
        end
        return
    end
    if not display then
        local back = addon.Theme:RoundedCard(row)
        back:SetFrameLevel(row:GetFrameLevel())
        display = {back = back}
        questListRows[row] = display
    end
    alignQuestCard(display.back, row, list, 1)
    addon.Theme:PaintQuestCard(display.back)
    activeRows[questID], activeRows[row] = row, row
    playbackParents[row:GetParent()] = true
    if row.Checkbox then
        activeRows[row.Checkbox] = row
        row.Checkbox:ClearAllPoints()
        row.Checkbox:SetPoint("TOPRIGHT", display.back, "TOPRIGHT", -6, -5)
        placeQuestTags(row, row.Checkbox, 24)
        paintMapTrackingButton(row.Checkbox)
    end
    if row.POIButton then paintQuestBadge(row.POIButton, questID) end
    display.back:Show()
end

local objectiveBars = setmetatable({}, {__mode = "k"})
local function addMapProgress(list, rows)
    local pool = list.objectiveFramePool
    local contents = list.Contents
    if not (pool and pool.EnumerateActive and contents and contents.Layout) then return false end
    local config = addon.QuestTracker.Settings()
    local trackerFrame = _G.BaziUIQuestTracker or UIParent
    local thickness = config.progressThickness * trackerFrame:GetEffectiveScale() / list:GetEffectiveScale()
    local objectivesByQuest, active, metrics = {}, {}, {}
    local changed = false
    for objective in pool:EnumerateActive() do
        local id = objective.questID
        local row = id and rows[id]
        local label = objective.Text
        local bar = objectiveBars[objective]
        if row and label and objective:IsShown() then
            local textHeight = label:GetStringHeight()
            local metric = metrics[row] or {height = 1, bars = 0}
            metrics[row] = metric
            metric.height = metric.height + textHeight + 2
            local progress
            if config.progressBars then
                local objectives = objectivesByQuest[id]
                if not objectives then
                    objectives = getMapObjectives(id)
                    objectivesByQuest[id] = objectives
                end
                progress = objectiveProgress(mapObjectiveText(label:GetText()), objectives)
            end
            if progress then
                active[objective] = true
                if not bar then
                    bar = CreateFrame("StatusBar", nil, objective)
                    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                    bar:SetMinMaxValues(0, 1)
                    bar:EnableMouse(false)
                    local track = bar:CreateTexture(nil, "BACKGROUND")
                    track:SetAllPoints()
                    track:SetColorTexture(0.43, 0.41, 0.40, 0.47)
                    bar:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
                    objectiveBars[objective] = bar
                end
                local left, right = label:GetLeft(), questListRows[row].back:GetRight()
                bar:SetWidth(left and right and math.max(1, right - left - 6) or label:GetWidth())
                bar:SetHeight(thickness)
                bar:SetStatusBarColor(addon.Theme:Accent())
                bar:SetValue(progress)
                bar:Show()

                local extra = thickness + 4
                metric.height = metric.height + extra
                metric.bars = metric.bars + 1
                if math.abs(objective:GetHeight() - textHeight - extra) > 0.01 then
                    objective:SetHeight(textHeight + extra)
                    changed = true
                end
            end
        end
    end
    for objective, bar in pairs(objectiveBars) do
        if not active[objective] and bar:IsShown() then
            bar:Hide()
            if objective:IsShown() and objective.Text then
                objective:SetHeight(objective.Text:GetStringHeight())
                changed = true
            end
        end
    end
    for row, display in pairs(questListRows) do
        local metric = metrics[row]
        local hasBars = metric and metric.bars > 0
        if rows[row] and row.Text and metric and (hasBars or display.hasBars) then
            -- Native title padding and objective spacing are measured without scroll-relative positions.
            local target = 14 + row.Text:GetHeight() + metric.height
            if math.abs(target - row:GetHeight()) > 0.01 then row:SetHeight(target); changed = true end
        end
        display.hasBars = hasBars
    end
    return changed
end

local function paintMapCategory(row, list, names)
    if not row:IsShown() or row.questID or row.QuestID or row.Checkbox then return end
    local function isCategoryLabel(label)
        if not (label and label.GetText and label.SetTextColor) then return false end
        local text = label:GetText()
        if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return false end
        local name = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
        return names[name] == true
    end
    local text = row.Text or row.Title or row.HeaderText or (row.GetFontString and row:GetFontString())
    if not isCategoryLabel(text) then
        text = nil
        for _, region in ipairs({row:GetRegions()}) do
            if region:IsObjectType("FontString") and isCategoryLabel(region) then text = region; break end
        end
    end
    if not text then return end
    if not row.baziCategory then
        local card = addon.Theme:RoundedCard(row)
        card:SetFrameLevel(row:GetFrameLevel())
        row.baziCategory = card
    end
    local card = row.baziCategory
    alignQuestCard(card, row, list, 2)
    card:SetBackdropColor(addon.Headers.Fill("map", 0.20, 0.15, 0.105, 0.96))
    card:SetBackdropBorderColor(addon.Theme:AccentInk(0.24))
    for _, region in ipairs({row:GetRegions()}) do
        if region:IsObjectType("Texture") and region:GetWidth() > row:GetWidth() * 0.55 then region:SetAlpha(0) end
    end
    for _, region in pairs({row.NineSlice, row.Bg, row.Background}) do region:SetAlpha(0) end
    local font, size, flags = GameFontNormal:GetFont()
    addon.Typography.Apply(text, "Map:Header", font, size, flags, true)
    text:SetTextColor(addon.Headers.Text("map", 1, 0.82, 0.49))
    card:Show()
end

local function mapQuestScrollbar(list, scroll)
    return list.ScrollBar or scroll.ScrollBar or _G.QuestScrollFrameScrollBar
end

local function skinMapQuestScrollbar(bar, scroll)
    local track = bar.baziRail
    if not track then
        track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("TOP")
        track:SetPoint("BOTTOM")
        track:SetWidth(1)
        bar.baziRail = track
    end
    local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
    local range = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange()
    local available = range == nil or range > 0.5
    if thumb and range then addon.Theme:PaintScrollRail(track, thumb, bar:GetHeight(), range) end
    for _, region in ipairs({bar:GetRegions()}) do
        if region ~= track and region ~= thumb and region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    if not thumb then
        thumb = bar.Track and bar.Track.Thumb
        thumb = thumb and (thumb.Texture or thumb)
        if thumb and thumb.SetVertexColor then thumb:SetVertexColor(addon.Theme:Accent()) end
        local background = bar.Track and (bar.Track.Background or bar.Track.Bg)
        if background then background:SetAlpha(0) end
    end
    if thumb and thumb.SetAlpha then thumb:SetAlpha(available and 1 or 0) end
    track:SetColorTexture(addon.Theme:AccentInk(0.35))
    track:SetShown(available)
    local name = bar:GetName()
    for _, arrow in pairs({bar.ScrollUpButton, bar.ScrollDownButton, bar.Back, bar.Forward,
        name and _G[name .. "ScrollUpButton"], name and _G[name .. "ScrollDownButton"]}) do
        if type(arrow) == "table" and arrow.SetAlpha then
            if arrow.EnableMouse then arrow:EnableMouse(false) end
            arrow:SetAlpha(0)
        end
    end
end

skinQuestList = function()
    -- Diagnostic only: bypass native quest row styling and its scroll hooks.
    if true then return end
    local list = QuestScrollFrame or (QuestMapFrame and QuestMapFrame.QuestsFrame)
    if not list or not list:IsVisible() or InCombatLockdown() or layingOutQuestList then return end
    local scroll = list.ScrollFrame or list.ScrollBox or list
    local panel = list.baziQuestBackdrop
    if panel then addon.Theme:PaintWindowEdge(panel) end
    local bar = mapQuestScrollbar(list, scroll)
    if bar then skinMapQuestScrollbar(bar, scroll) end
    local activeRows, parents = {}, {[list] = true}
    local function rowStyle(row) decorateQuestRow(row, list, activeRows, parents) end
    local pool = list.titleFramePool or list.questTitleFramePool
    if pool and pool.EnumerateActive then
        for row in pool:EnumerateActive() do rowStyle(row) end
    elseif scroll.ForEachFrame then
        scroll:ForEachFrame(rowStyle)
    elseif scroll.GetScrollChild then
        local child = scroll:GetScrollChild()
        if child then
            for _, row in ipairs({child:GetChildren()}) do rowStyle(row) end
        end
    end
    layingOutQuestList = true
    if addMapProgress(list, activeRows) then
        list.Contents:Layout()
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    end
    layingOutQuestList = nil
    local names = {}
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.isHeader and info.title then names[info.title] = true end
    end
    for _, headers in pairs({list.headerFramePool, list.questHeaderFramePool, list.categoryFramePool}) do
        if headers.EnumerateActive then
            for row in headers:EnumerateActive() do paintMapCategory(row, list, names) end
        end
    end
    if scroll.GetScrollChild then
        local child = scroll:GetScrollChild()
        if child then parents[child] = true end
    end
    for parent in pairs(parents) do
        for _, row in ipairs({parent:GetChildren()}) do
            paintMapCategory(row, list, names)
            if row:IsObjectType("Button") and not row.Checkbox and not row.MatchBox
                and (row.GetQuestID or row.questID or row.baziQuestBadge) then
                local id = questMarkerID(row)
                paintQuestBadge(row, id and activeRows[id] and id or nil)
            end
        end
        paintMapPlayback(parent, activeRows)
    end
    for row, display in pairs(questListRows) do
        if not activeRows[row] then
            display.back:Hide()
        end
    end
end

local function hideQuestPanelArt(list, quest)
    local function decorative(region)
        local name = region:GetName()
        if not name then return false end
        name = name:lower()
        return name:find("border", 1, true) or name:find("nineslice", 1, true)
            or name:find("inset", 1, true) or name:find("background", 1, true) or name:match("bg$")
    end
    for _, root in ipairs({list, quest}) do
        for _, region in ipairs({root:GetRegions()}) do
            if region:IsObjectType("Texture") and (root == list or decorative(region)) then region:SetAlpha(0) end
        end
        for _, child in ipairs({root:GetChildren()}) do
            if child ~= list and child ~= list.baziQuestBackdrop and decorative(child) and not child:IsObjectType("Button") then
                child:SetAlpha(0)
            end
        end
        for _, region in pairs({root.NineSlice, root.Bg, root.Background, root.Inset, root.Border,
            root.BackgroundFrame, root.BorderFrame, root.QuestsFrameInset}) do region:SetAlpha(0) end
    end
    for _, region in pairs({_G.QuestScrollFrameBorder, _G.QuestScrollFrameInset, _G.QuestLogFrameInset,
        _G.QuestMapFrameQuestsFrameInset, _G.QuestScrollFrameBackground}) do region:SetAlpha(0) end
end

local function placeWindowControls(maximized)
    local parent = maximized and fullscreenControls or header
    for _, button in ipairs({closeControl, displayControl}) do
        if button:GetParent() ~= parent then button:SetParent(parent) end
        button:SetFrameStrata(parent:GetFrameStrata())
        button:SetFrameLevel(parent:GetFrameLevel() + 3)
    end
    fullscreenControls:SetShown(maximized and world:IsVisible())
end

local function applyChrome()
    if applyingChrome or InCombatLockdown() then return end
    applyingChrome = true
    local native = world.BorderFrame
    local maximized = world:IsMaximized()
    if maximized then
        local strata = world:GetFrameStrata()
        if strata ~= "FULLSCREEN_DIALOG" then
            previousMapStrata = strata
            world:SetFrameStrata("FULLSCREEN_DIALOG")
        end
        header:SetFrameStrata("FULLSCREEN_DIALOG")
        border:SetFrameStrata("FULLSCREEN_DIALOG")
        native:SetFrameStrata("FULLSCREEN_DIALOG")
    else
        if previousMapStrata then
            world:SetFrameStrata(previousMapStrata)
            previousMapStrata = nil
        end
        header:SetFrameStrata("HIGH")
        border:SetFrameStrata("HIGH")
        native:SetFrameStrata("HIGH")
    end
    -- The native border has its own mouse surface across the whole map.
    native:EnableMouse(false)
    if native.EnableMouseWheel then native:EnableMouseWheel(false) end
    for _, region in ipairs({native:GetRegions()}) do region:SetAlpha(0) end
    for _, region in pairs({native.NineSlice, native.PortraitContainer, native.TitleContainer, native.Bg, native.Tutorial}) do
        region:SetAlpha(0)
    end
    if native.Tutorial then native.Tutorial:EnableMouse(false) end
    if world.BlackoutFrame then
        world.BlackoutFrame:EnableMouse(false)
        world.BlackoutFrame:Hide()
    end
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
    local nativeDisplay = native.MaximizeMinimizeFrame
    if native.CloseButton then
        native.CloseButton:SetAlpha(0)
        native.CloseButton:EnableMouse(false)
    end
    if nativeDisplay then
        nativeDisplay:SetAlpha(0)
        for _, button in ipairs({nativeDisplay:GetChildren()}) do button:EnableMouse(false) end
    end
    displayControl:SetShown(maximized or (nativeDisplay ~= nil and nativeDisplay:IsShown()))
    flatControl(displayControl, maximized and "ChevronDown" or "ChevronUp")
    local list = QuestScrollFrame or (QuestMapFrame and QuestMapFrame.QuestsFrame)
    local quest = world.QuestLog or QuestMapFrame
    local questWidth = quest and quest:IsShown() and (world.questLogWidth or 333) or 0
    local canvas = world.ScrollContainer
    local mapLevel = math.max(world:GetFrameLevel(), canvas:GetFrameLevel())
    local chromeStrata = header:GetFrameStrata()
    header:SetFrameLevel(math.max(mapLevel, native:GetFrameLevel(), border:GetFrameLevel()) + 12)
    placeWindowControls(maximized)
    if quest then
        quest:SetFrameStrata(chromeStrata)
        quest:SetFrameLevel(mapLevel + 4)
        quest:SetAlpha(1)
    end
    if list then
        list:SetAlpha(1)
        if list ~= quest then
            list:SetFrameStrata(chromeStrata)
            list:SetFrameLevel(mapLevel + 6)
        end
    end
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    canvas:SetPoint("BOTTOMRIGHT", world, "BOTTOMRIGHT", -questWidth - 3, 22)
    if sidebarWidth ~= questWidth or sidebarMaximized ~= maximized then
        sidebarWidth, sidebarMaximized = questWidth, maximized
        viewportNeedsLayout = true
    end
    if list and questWidth > 0 then
        if not list.baziQuestBackdrop then
            local panel = addon.Theme:RoundedCard(list:GetParent())
            panel:SetFrameLevel(math.max(0, list:GetFrameLevel() - 1))
            panel:SetPoint("TOPLEFT", canvas, "TOPRIGHT", 2, 0)
            panel:SetPoint("BOTTOMRIGHT", world, "BOTTOMRIGHT", -4, 22)
            panel:SetBackdropColor(0.038, 0.031, 0.030, 1)
            addon.Theme:PaintWindowEdge(panel)
            addon.Backgrounds.Track("map", panel.fillTexture or panel, 1)
            list.baziQuestBackdrop = panel
        end
        list.baziQuestBackdrop:SetFrameStrata(chromeStrata)
        list.baziQuestBackdrop:SetFrameLevel(list:GetFrameLevel() - 1)
        list.baziQuestBackdrop:Show()
        hideQuestPanelArt(list, quest)
        local panel = list.baziQuestBackdrop
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", panel, "TOPRIGHT", 9 - questWidth, -5)
        list:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -18, 5)
        local scroll = list.ScrollFrame or list.ScrollBox or list
        local scrollBar = mapQuestScrollbar(list, scroll)
        if scrollBar then
            scrollBar:ClearAllPoints()
            scrollBar:SetWidth(8)
            scrollBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -8)
            scrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 8)
        end
        if not scroll.baziQuestSkinHook then
            if scroll.ForEachFrame and type(scroll.Update) == "function" then hooksecurefunc(scroll, "Update", skinQuestList)
            elseif scroll.GetScrollChild then
                scroll:HookScript("OnVerticalScroll", skinQuestList)
                scroll:HookScript("OnScrollRangeChanged", skinQuestList)
            end
            scroll.baziQuestSkinHook = true
        end
    elseif list and list.baziQuestBackdrop then
        list.baziQuestBackdrop:Hide()
    end
    local search, options = list and list.SearchBox, list and list.SettingsDropdown
    if search and options then
        options:ClearAllPoints()
        options:SetPoint("RIGHT", displayControl:IsShown() and displayControl or closeControl, "LEFT", -5, 0)
        options:SetSize(20, 20)
        options:SetFrameLevel(header:GetFrameLevel() + 3)
        flatControl(options, "Settings")
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
        flatControl(filter, "ChevronDown")
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
        flatControl(toggle.OpenButton, "Quest", 16)
        flatControl(toggle.CloseButton, "Quest", 16)
    end
    if continentButton then map.RefreshHeaderStyle() end
    grip:SetShown(canMove())
    applyingChrome = nil
end

local function install()
    if border or not WorldMapFrame or not addon.db or InCombatLockdown() then return end
    if map.GetOption("enabled") == false then return end
    world = WorldMapFrame
    if not world.BorderFrame or not world.ScrollContainer then return end
    -- Bazi's chrome and quest list need the same render order as the map canvas.
    if world.SetIsFrameBuffer then world:SetIsFrameBuffer(false) end

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
    -- Keep the fullscreen hit targets outside the map's panel and canvas.
    fullscreenControls = CreateFrame("Frame", nil, UIParent)
    fullscreenControls:SetAllPoints(header)
    fullscreenControls:SetFrameStrata("TOOLTIP")
    fullscreenControls:EnableMouse(false)
    fullscreenControls:Hide()
    closeControl = CreateFrame("Button", nil, header)
    closeControl:SetSize(20, 20)
    closeControl:SetPoint("RIGHT", header, "RIGHT", -5, 0)
    closeControl:EnableMouse(true)
    closeControl:RegisterForClicks("LeftButtonUp")
    closeControl:SetScript("OnClick", function() HideUIPanel(world) end)
    flatControl(closeControl, "Cross")
    displayControl = CreateFrame("Button", nil, header)
    displayControl:SetSize(20, 20)
    displayControl:SetPoint("RIGHT", closeControl, "LEFT", -3, 0)
    displayControl:EnableMouse(true)
    displayControl:RegisterForClicks("LeftButtonUp")
    displayControl:SetScript("OnClick", function()
        if world:IsMaximized() then world:HandleUserActionMinimizeSelf()
        else world:HandleUserActionMaximizeSelf() end
    end)
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

    local chromeQueued
    local function syncLayout()
        chromeQueued = nil
        if not world:IsShown() or InCombatLockdown() then return end
        if world:IsMaximized() then
            world:SetScale(1)
        else
            if sidebarMaximized then initialFit, initialViewport = false, nil end
            restorePosition()
        end
        applyChrome()
        if viewportNeedsLayout then
            local mapID = world:GetMapID()
            if mapID and fitViewport(mapID) then viewportNeedsLayout = nil end
        end
        map.Refresh()
    end
    local function queueLayout()
        if chromeQueued or applyingChrome then return end
        chromeQueued = true
        C_Timer.After(0, function() if chromeQueued then syncLayout() end end)
    end
    local function show()
        if GetCVar("mapFade") == "1" then SetCVar("mapFade", "0") end
        queueLayout()
    end
    world:HookScript("OnUpdate", update)
    world:HookScript("OnShow", show)
    world:HookScript("OnHide", function()
        fullscreenControls:Hide()
        sidebarWidth = nil
        drag, opacity = nil, 1
        initialViewport = nil
        world:SetAlpha(1)
    end)
    hooksecurefunc(world, "OnMapChanged", queueLayout)
    if BaseMapPoiPinMixin and BaseMapPoiPinMixin.OnAcquired then
        hooksecurefunc(BaseMapPoiPinMixin, "OnAcquired", function(pin)
            if map.GetOption("hideTowns") and pin.GetMap and pin:GetMap() == world then map.Refresh() end
        end)
    end
    if type(QuestLogQuests_Update) == "function" then
        hooksecurefunc("QuestLogQuests_Update", function()
            if world:IsShown() then skinQuestList() end
        end)
    end
    addZoneHover()
    hooksecurefunc(world, "OnCanvasSizeChanged", map.Refresh)
    world.ScrollContainer:HookScript("OnSizeChanged", map.Refresh)
    world:HookScript("OnSizeChanged", sizeMarkers)
    if world.OnCanvasScaleChanged then hooksecurefunc(world, "OnCanvasScaleChanged", sizeMarkers) end
    if world.UpdateSpacerFrameAnchoring then
        hooksecurefunc(world, "UpdateSpacerFrameAnchoring", queueLayout)
    end
    local quest = world.QuestLog or QuestMapFrame
    if quest then
        quest:HookScript("OnShow", queueLayout)
        quest:HookScript("OnHide", queueLayout)
    end
    if world.SynchronizeDisplayState then hooksecurefunc(world, "SynchronizeDisplayState", queueLayout) end
    if world.SetDisplayState then hooksecurefunc(world, "SetDisplayState", queueLayout) end
    world:RegisterEvent("PLAYER_REGEN_ENABLED")
    world:HookScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and world:IsShown() then syncLayout() end
    end)
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

