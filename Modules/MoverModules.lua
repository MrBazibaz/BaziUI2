local A, M = BaziUI, BaziUI.Movers
local function spec(label, frame, settings, apply, fields, options)
    options = options or {}
    options.label = label
    options.frame = type(frame) == "function" and frame or function() return _G[frame] end
    options.settings, options.apply, options.fields = settings, apply, fields
    M.Register(options)
end
local function profile(key) return function() return A.db.profile[key] end end
local function visible(frame) return frame and frame:IsVisible() and frame end
local function width(minimum, maximum) return {"width", "Width", minimum, maximum} end
local function height(minimum, maximum) return {"height", "Height", minimum, maximum} end
local scale = {"scale", "Scale %", 50, 175}

local dashboard = A.Dashboard
spec("Dashboard", dashboard.GetFrame, dashboard.Settings, dashboard.Render, {
    width(145, 550), {"maxHeight", "Maximum height", 90, 700}, scale, {"spacing", "Widget spacing", 0, 24},
    {"maxWidgets", "Widgets", 1, 15},
}, {canDrag = function() return not dashboard.Settings().locked end})

local bars = A.ActionBars
local function applyBars() bars:Apply() end
for index, def in ipairs(bars.bars) do
    local function settings() return bars:Settings().bars[def.key] end
    local function frame()
        local root = bars:Settings()
        if root.enabled and settings().visible then
            return index <= 8 and bars.GetOwnedMoverFrame(index) or _G[def.frame] or _G[def.fallback or def.frame]
        end
    end
    local fields = {scale}
    if index <= 8 then
        fields = {scale, {"buttonSize", "Button size", 12, 100}, {"buttons", "Buttons (0 = all)", 0, 12},
            {"rows", "Rows", 0, 12}, {"columns", "Columns (0 = auto)", 0, 12}, {"spacing", "Spacing", -15, 30}}
    elseif def.prefix then
        fields = {scale, {def.key == "pet" and "petButtonSize" or "nativeButtonSize", "Button size", 0, 100},
            {"rows", "Rows", 0, 12}, {"nativeSpacing", "Spacing", 0, 30}}
    end
    spec(def.title, frame, settings, applyBars, fields)
end
for _, reputation in ipairs({false, true}) do
    spec(reputation and "Reputation bar" or "Experience bar", function() return bars.GetExperienceMoverFrame(reputation) end,
        function() return bars:Settings().experience end, applyBars, {width(100, 1500), height(4, 60)},
        {y = reputation and "reputationY" or "y", scaled = true})
end

local unitFields = {{"barWidth", "Bar width", 100, 400}, {"hpHeight", "Health height", 12, 45},
    {"powerHeight", "Power height", 4, 30}, {"portraitSize", "Portrait size", 36, 90},
    {"portraitX", "Portrait X", -150, 150}, {"portraitY", "Portrait Y", -100, 100}}
local units = {{"player", "Player"}, {"target", "Target"}, {"focus", "Focus"}, {"pet", "Pet frame"}, {"targettarget", "Target of target"}}
for _, unit in ipairs(units) do
    spec(unit[2], "BaziUI_Unit_" .. unit[1], function() return A.UnitFrames.GetMoverSettings(unit[1]) end,
        function() A.UnitFrames:Refresh() end, unitFields, {scaled = true})
end
for _, group in ipairs({{"Party", "party", 4}, {"Raid", "raid", 40}, {"Boss", "boss", 5}}) do
    local name, key, count = unpack(group)
    local module = A[name .. "Frames"]
    local function settings()
        local root = A.db.profile.unitframes
        return root and root.groups and root.groups[key]
    end
    local function apply() module:Refresh() end
    local prefix = "BaziUI_" .. name .. "Exact_" .. key
    local function groupFrame()
        for i = 1, count do
            local frame = visible(_G[prefix .. i])
            if frame then return frame end
        end
    end
    local function related()
        local result = {}
        for i = 1, count do
            local frame = visible(_G[prefix .. i])
            if frame then result[#result + 1] = frame end
        end
        return result
    end
    spec(name .. " group", groupFrame, settings, apply,
        {{"spacing", "Spacing", 0, 80}, {"verticalSpacing", "Row spacing", 0, 80}, {"columns", "Columns", 1, 8},
            {"scale", "Scale %", 50, 175, 100}},
        {related = related, overlayWhenSelected = true, invertY = key == "raid", scaled = true})
    for index = 1, count do
        spec(name .. " " .. index, prefix .. index, function()
            local groupSettings = settings()
            return groupSettings and groupSettings.members and groupSettings.members[index]
        end, apply, unitFields, {x = "offsetX", y = "offsetY", scaled = true})
    end
end

local hud = A.HUD
for _, entry in ipairs({{"durability", "Durability", "DurabilityFrame"}, {"vehicle", "Vehicle exit", "MainMenuBarVehicleLeaveButton"},
    {"buffs", "Buffs", "BuffFrame"}, {"debuffs", "Debuffs", "DebuffFrame"}, {"ammo", "Hunter ammunition", "BaziUIAmmo"}}) do
    local key, label, frame = unpack(entry)
    local apply, fields, scaled = hud.RefreshNative, nil, true
    if key == "ammo" then
        apply, fields, scaled = A.HUDAmmo.Refresh, {width(55, 400), height(20, 150), scale, {"iconSize", "Icon size", 10, 80}}, false
    elseif key == "buffs" or key == "debuffs" then
        apply, fields = A.HUDAuras.Refresh, {{"size", "Icon size", 12, 70}, {"rows", "Rows", 1, 10}, {"columns", "Columns", 1, 20}}
    end
    spec(label, function() return hud.Settings(key).enabled and _G[frame] end,
        function() return hud.Settings(key) end, apply, fields, {scaled = scaled})
end
for _, entry in ipairs({{"player", "Player cast bar"}, {"target", "Target cast bar"}, {"breath", "Breath"}, {"fatigue", "Fatigue"}}) do
    local key = entry[1]
    local function attached()
        return (key == "player" or key == "target") and hud.Settings(key).attachToUnitFrame ~= false and A.UnitFrames.GetCastBarAnchor(key)
    end
    spec(entry[2], function() return A.CastBars.GetMoverFrame(key) end, function() return hud.Settings(key) end,
        A.CastBars.Refresh, {width(80, 800), height(12, 72), {"iconSize", "Icon size", 12, 70}},
        {saved = {"x", "y", "unitX", "unitY"}, scaled = true,
            position = function()
                local cfg = hud.Settings(key)
                if attached() then return cfg.unitX, cfg.unitY end
                return cfg.x, cfg.y
            end,
            setPosition = function(x, y)
                local cfg = hud.Settings(key)
                if attached() then cfg.unitX, cfg.unitY = x, y else cfg.x, cfg.y = x, y end
                local frame = A.CastBars.GetMoverFrame(key)
                if frame then frame.positionX = nil end
                A.CastBars.Refresh()
            end})
end

spec("Quest tracker", "BaziUIQuestTracker", A.QuestTracker.Settings, A.QuestTracker.RefreshPosition,
    {width(150, 700), {"maxHeight", "Maximum height", 80, 750}}, {
        saved = {"position"}, position = A.QuestTracker.GetPosition, setPosition = A.QuestTracker.SetCoordinates,
    })
spec("Quest timers", "BaziUIQuestTimers", A.QuestTracker.Settings, A.QuestTracker.RefreshTimers,
    {{"timerWidth", "Width", 130, 650}}, {x = "timerX", y = "timerY"})
for index = 1, 2 do
    spec(index == 1 and "Damage meter" or "Damage meter 2", index == 1 and "BaziUIDamageMeter" or "BaziUIDamageMeter2",
        function() return A.DamageMeter.Settings(index) end, A.DamageMeter.Refresh,
        {width(150, 660), {"rows", "Rows", 1, 20}, {"barHeight", "Row height", 10, 50}}, {scaled = true})
end

local function applyMinimap() A.Minimap:Apply() end
local function minimapPosition()
    local cfg, cluster = A.db.profile.minimap, _G.Minimap or _G.MinimapCluster
    if cfg.x and cfg.y then return cfg.x, cfg.y end
    local x, y
    if cluster then x, y = cluster:GetCenter() end
    local ratio = cluster and cluster:GetEffectiveScale() / UIParent:GetEffectiveScale() or 1
    return (x or 0) * ratio - UIParent:GetWidth() / 2, (y or 0) * ratio - UIParent:GetHeight() / 2
end
spec("Minimap", function() return A.db.profile.minimap.enabled and MinimapCluster end, profile("minimap"), applyMinimap,
    {{"mapScale", "Scale %", 70, 150, 100}, {"iconScale", "Icon scale %", 100, 250, 100}}, {position = minimapPosition, setPosition = function(x, y)
        local cfg = A.db.profile.minimap
        cfg.x, cfg.y = x, y
        applyMinimap()
    end})
spec("Minimap mail", function()
    local cluster = _G.MinimapCluster
    return cluster and (cluster.IndicatorFrame and cluster.IndicatorFrame.MailFrame or _G.MiniMapMailFrame)
end, profile("minimap"), applyMinimap, nil, {x = "mailX", y = "mailY", scaled = true, position = function()
    local cfg = A.db.profile.minimap
    return cfg.mailX or 40, cfg.mailY or 8
end})

local function worldConfig() A.db.profile.worldMap = A.db.profile.worldMap or {}; return A.db.profile.worldMap end
local function worldPosition()
    local stored = worldConfig().position
    if stored then return stored[3], stored[4] end
    local world = _G.WorldMapFrame
    if not world then return 0, 0 end
    local _, _, _, x, y = world:GetPoint(1)
    return x or 0, y or 0
end
spec("World map", "WorldMapFrame", worldConfig, A.Map.ApplyMoverPosition, nil, {
    saved = {"position"}, scaled = true, position = worldPosition,
    canDrag = function() return WorldMapFrame and not WorldMapFrame:IsMaximized() end,
    setPosition = function(x, y)
        local cfg = worldConfig()
        local stored, world = cfg.position, _G.WorldMapFrame
        local point, relative = "CENTER", "CENTER"
        if stored then point, relative = stored[1], stored[2]
        elseif world then point, _, relative = world:GetPoint(1) end
        cfg.position = {point or "CENTER", relative or "CENTER", x, y}
        A.Map.ApplyMoverPosition()
    end})

local chat = A.Chat
local function applyChat(cfg) chat.Resize.ApplyMoverLayout(cfg or chat.Resize.GetLayout()) end
spec("Chat", function() return DEFAULT_CHAT_FRAME end, function() return chat.Resize.GetLayout() end, applyChat,
    {width(220, 1300), height(65, 700)}, {
        x = "left", y = "top", scaled = true,
        setPosition = function(x, y)
            local cfg = chat.Resize.GetLayout()
            cfg.left, cfg.top = x, y
            chat.Resize.ApplyMoverLayout(cfg)
        end,
    })
spec("Friend notifications", function() return chat.Settings().friendToastPosition and chat.FriendToasts.GetMoverFrame() end,
    chat.Settings, chat.FriendToasts.Refresh, nil, {x = "friendToastX", y = "friendToastY", position = function()
        local cfg = chat.Settings()
        return cfg.friendToastX or -380, cfg.friendToastY or -205
    end})
spec("Whisper notification", chat.Whispers.GetMoverFrame, chat.Settings, chat.Whispers.ApplyMoverPosition, nil, {
    saved = {"whisperToastPos"}, scaled = true,
    position = function()
        local pos, toast = chat.Settings().whisperToastPos, chat.Whispers.GetMoverFrame()
        if pos then return pos.x, pos.y end
        return toast and toast:GetLeft() or 0, toast and toast:GetBottom() or 0
    end,
    setPosition = function(x, y)
        chat.Settings().whisperToastPos = {x = x, y = y}
        chat.Whispers.ApplyMoverPosition()
    end,
})

local dialogue = A.Dialogue
spec("NPC dialogue", function() return dialogue.GetMoverFrame(false) end, dialogue.Settings, dialogue.Refresh, {scale}, {scaled = true})
spec("Dialogue reader", function() return dialogue.GetMoverFrame(true) end, dialogue.Settings, dialogue.Refresh,
    {scale, {"readerMaxHeight", "Maximum height", 220, 600}}, {x = "readerX", y = "readerY", scaled = true})

local inventory = A.Inventory
spec("Bags / bank", "BaziUIInventory", inventory.Settings, inventory.UpdateWindows, {
    {"columns", "Bag columns", 4, 30}, {"bankColumns", "Bank columns", 4, 30}, {"guildColumns", "Guild columns", 4, 30},
    {"size", "Slot size", 18, 66},
})
local function applyLoot()
    inventory.ResetLootPosition()
    inventory.RefreshLoot()
    inventory.RefreshRolls()
    inventory.RefreshCleanup()
end
spec("Loot, Cleanup & Rolls", function()
    return visible(inventory.VisibleLoot()) or visible(inventory.GetRollMoverFrame()) or visible(inventory.GetCleanupMoverFrame())
end, inventory.Settings, applyLoot, {{"lootWidth", "Width", 345, 800}}, {x = "lootX", y = "lootY"})
spec("Tooltip anchor", function()
    return A.db.profile.tooltip.anchor ~= "mouse" and GameTooltip
end, profile("tooltip"), function() A.Tooltip:Apply() end, {{"scale", "Scale %", 50, 200, 100}}, {scaled = true})

local function nameplates() A.Nameplates:Apply() end
spec("Enemy nameplate", A.EnemyNameplates.GetMoverFrame, profile("nameplates"), nameplates,
    {{"enemyWidth", "Width", 70, 350}, {"enemyHeight", "Height", 8, 55},
        {"enemyScale", "Scale %", 50, 175, 100}},
    {x = "enemyPlateX", y = "enemyPlateY", scaled = true})
spec("Friendly marker", function() return A.Nameplates.GetMoverFrame(false) end, profile("nameplates"), nameplates,
    nil, {x = "friendlyX", y = "friendlyY", scaled = true, position = function()
        local cfg = A.db.profile.nameplates
        return cfg and cfg.friendlyX or 0, cfg and cfg.friendlyY or 20
    end})
spec("NPC nameplate text", function() return A.Nameplates.GetMoverFrame(true) end, profile("nameplates"), nameplates,
    nil, {x = "friendlyTextX", y = "friendlyTextY", scaled = true, bounds = function(marker) return marker.name end})
