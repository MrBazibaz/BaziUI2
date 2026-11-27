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
-- Rebuilt presentation layer. Blizzard owns map navigation, pins and layout.
local world, shell, title, coords, heading, top
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
function map.SetOption(key, value)
    settings()[key] = value
    if key ~= "enabled" then map.Refresh() end
end
local function canChange(frame)
    return not InCombatLockdown() or not frame:IsProtected()
end
function map.RefreshHeaderStyle()
    if not title then return end
    local chat = addon.Chat
    local r,g,b,a = 0.24,0.17,0.10,0.95
    if chat and chat.active and chat.Skin and chat.Skin.DockHeaderColor then
        r,g,b,a = chat.Skin.DockHeaderColor()
    end
    title:SetBackdropColor(r,g,b,a)
    if top then top:SetBackdropColor(r,g,b,a) end
end
local markers = {}
local questArt = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\Quest.tga"
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
    if InCombatLockdown() or not C_Map.OpenWorldMap then return end
    for _, id in ipairs(point[6] or {}) do
        if C_Map.GetMapInfo(id) then C_Map.OpenWorldMap(id); return end
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
    local canvas = world:GetCanvas()
    local level = math.min(canvas:GetFrameLevel() + 100, 9500)
    local count = 0
    local function marker(point)
        local kind = point[1]
        count = count + 1
        local button = markers[count]
        if not button then
            button = CreateFrame("Button", nil, canvas)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetAllPoints()
            button:SetScript("OnClick", function(self)
                if InCombatLockdown() or self.point[1] == "QuestOffer" then return end
                if self.point[5] and C_Map.GetMapInfo(self.point[5]) then
                    if C_Map.OpenWorldMap then C_Map.OpenWorldMap(self.point[5]) end
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


local lastMap, dirty, lastWidth, lastHeight, lastScale
local function refreshPoints()
    if not world or not world:IsShown() or InCombatLockdown() then return end
    local id = world:GetMapID()
    if not id then return end
    local canvas = world:GetCanvas()
    if not canvas then return end
    local w,h = canvas:GetSize()
    local scale = world:GetCanvasScale()
    if dirty or lastMap ~= id then
        local config = {}
        for _, option in ipairs(map.options) do config[option[1]] = map.GetOption(option[1]) end
        drawPoints(id, config)
        dirty, lastMap = false, id
        lastWidth = nil
    end
    if w ~= lastWidth or h ~= lastHeight or scale ~= lastScale then
        sizeMarkers()
        lastWidth,lastHeight,lastScale = w,h,scale
    end
end
function map.Refresh()
    dirty = true
    if not shell then return end
    title:SetShown(map.GetOption("coordinates") == true)
    map.RefreshHeaderStyle()
end
local function install()
    if shell or not addon.db or not map.GetOption("enabled") then return end
    world = WorldMapFrame
    if not world or not world.ScrollContainer or not canChange(world) then return end
    -- Own decorative frames only. Never replace native scripts or reanchor native regions.
    shell = CreateFrame("Frame", nil, world, "BackdropTemplate")
    shell:SetAllPoints(world)
    shell:SetFrameLevel(world:GetFrameLevel())
    shell:EnableMouse(false)
    addon.Theme:CreateFrameBorder(shell, shell, shell)
    -- Decorative strips are independent of Blizzard's interactive controls.
    top = CreateFrame("Frame", nil, shell, "BackdropTemplate")
    top:SetPoint("TOPLEFT", world, "TOPLEFT", 65, -5)
    top:SetPoint("TOPRIGHT", world, "TOPRIGHT", -70, -5)
    top:SetHeight(23)
    top:SetFrameLevel(world:GetFrameLevel() + 15)
    top:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    top:EnableMouse(false)
    addon.Theme:CreateFrameBorder(top, top, top)
    heading = top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("CENTER")
    heading:SetTextColor(1, 0.82, 0.42)
    heading:SetText("World Map")
    title = CreateFrame("Frame", nil, shell, "BackdropTemplate")
    title:SetPoint("BOTTOMLEFT", world.ScrollContainer, "BOTTOMLEFT", 6, 3)
    title:SetSize(185, 20)
    title:SetFrameLevel(world.ScrollContainer:GetFrameLevel() + 15)
    title:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    title:EnableMouse(false)
    addon.Theme:CreateFrameBorder(title, title, title)
    coords = title:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    coords:SetPoint("CENTER")
    coords:SetTextColor(1, 0.82, 0.42)
    -- Cover native button artwork with mouse-transparent decorative children.
    local function decorate(button, iconName)
        if not button then return end
        local face = CreateFrame("Frame", nil, shell)
        face:SetAllPoints(button)
        face:SetFrameLevel(button:GetFrameLevel() + 10)
        face:EnableMouse(false)
        addon.Theme:Surface(face, "Button", 10, "BACKGROUND", 1)
        local icon = face:CreateTexture(nil, "OVERLAY")
        icon:SetPoint("CENTER")
        icon:SetSize(13, 13)
        icon:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\" .. iconName .. ".tga")
        icon:SetVertexColor(1, 0.83, 0.56)
        return face
    end
    local native = world.BorderFrame
    local closeFace = native and decorate(native.CloseButton, "Cross")
    local display = native and native.MaximizeMinimizeFrame
    local maxFace = display and decorate(display.MaximizeButton, "ChevronUp")
    local minFace = display and decorate(display.MinimizeButton, "ChevronDown")
    local elapsed = 0
    shell:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.2 then return end
        elapsed = 0
        if closeFace then closeFace:SetShown(native.CloseButton:IsVisible()) end
        if maxFace then maxFace:SetShown(display.MaximizeButton:IsVisible()) end
        if minFace then minFace:SetShown(display.MinimizeButton:IsVisible()) end
        refreshPoints()
        local mapID = world:GetMapID()
        local info = mapID and C_Map.GetMapInfo(mapID)
        heading:SetText(info and info.name or "World Map")
        if not map.GetOption("coordinates") then return end
        local id = C_Map.GetBestMapForUnit("player")
        local pos = id and C_Map.GetPlayerMapPosition(id,"player")
        if pos then
            local x,y = pos:GetXY()
            coords:SetText(string.format("Player: %.1f, %.1f",x*100,y*100))
        else
            coords:SetText("Player: --")
        end
    end)
    map.Refresh()
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:SetScript("OnEvent", function(_,event,name)
    if event == "QUEST_LOG_UPDATE" then dirty = true; return end
    if event ~= "ADDON_LOADED" or name == "Blizzard_WorldMap" then install() end
end)
