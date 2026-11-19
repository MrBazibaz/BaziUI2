-- Minimap information: follows FlareUI's three-state visibility and stat stacking.
local addon = BaziUI
addon.MinimapInfo = addon.MinimapInfo or {}
local M = addon.MinimapInfo
local cluster = _G.MinimapCluster
local ticker, hoverTicker
local stats = {}
local fonts = {FRIZQT="Fonts\\FRIZQT__.TTF", ARIAL="Fonts\\ARIALN.TTF", MORPHEUS="Fonts\\MORPHEUS.TTF"}
local function db() return addon.db and addon.db.profile and addon.db.profile.minimap end
local function mode(key)
    local cfg = db()
    local value = cfg and cfg[key]
    return (value == "always" or value == "hover") and value or "off"
end
local function coords()
    return cluster and cluster.MinimapContainer and cluster.MinimapContainer.PlayerCoords
end
local function fontPath(config)
    if config.font ~= "GLOBAL" then return fonts[config.font] or fonts.FRIZQT end
    local global = addon.db and addon.db.profile and addon.db.profile.font
    if fonts[global] then return fonts[global] end
    local object = global and _G[global]
    if object and object.GetFont then
        local ok, path = pcall(object.GetFont, object)
        if ok and type(path) == "string" then return path end
    end
    return fonts.FRIZQT
end
local function applyFont(fs, config)
    if not fs or not config then return end
    local outline = config.outline
    if outline ~= "OUTLINE" and outline ~= "THICKOUTLINE" then outline = "" end
    pcall(fs.SetFont, fs, fontPath(config), config.size or 11, outline)
    if config.shadow then
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end
function M:ApplyFonts()
    local cfg = db()
    if not cfg or not cfg.enabled then return end
    applyFont(_G.MinimapZoneText, cfg.zoneFont)
    applyFont(_G.TimeManagerClockTicker, cfg.clockFont)
    local c = coords()
    if c then applyFont(c.CoordText, cfg.infoFont) end
    for _, fs in pairs(stats) do applyFont(fs, cfg.infoFont) end
end
local function update()
    if stats.fps then stats.fps:SetFormattedText("%.0f fps", GetFramerate()) end
    if stats.home and stats.world then
        local _, _, home, world = GetNetStats()
        stats.home:SetFormattedText("%d (h) ms", home or 0)
        stats.world:SetFormattedText("%d (w) ms", world or 0)
    end
end
local function refreshHover()
    local cfg = db()
    if not cfg then return end
    local over = cluster and cluster:IsMouseOver()
    local c = coords()
    if c then c:SetAlpha((not cfg.hideCoordinates and (cfg.coords == "always" or (cfg.coords == "hover" and over))) and 1 or 0) end
    local clock = _G.TimeManagerClockButton
    if clock and not cfg.hideClock then
        clock:SetAlpha((cfg.clock == "always" or (cfg.clock == "hover" and over)) and 1 or 0)
    end
    for _, key in ipairs({"fps","home","world"}) do
        local fs = stats[key]
        if fs then
            local m = mode(key == "fps" and "fps" or "latency")
            fs:SetAlpha(m == "always" or (m == "hover" and over) and 1 or 0)
        end
    end
end
local function makeStats()
    if stats.fps or not cluster then return end
    local holder = CreateFrame("Frame", nil, cluster)
    holder:SetAllPoints(cluster)
    holder:SetFrameLevel(cluster:GetFrameLevel() + 12)
    for _, key in ipairs({"fps","home","world"}) do
        local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("RIGHT")
        stats[key] = fs
    end
end
function M:Apply()
    local cfg = db()
    if not cfg or not cfg.enabled then return end
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "minimapShowPlayerCoords", (cfg.coords == "off" or cfg.hideCoordinates) and "0" or "1")
    end
    makeStats()
    local order = {}
    local fps, latency = mode("fps"), mode("latency")
    if fps ~= "off" and latency ~= "off" and fps == "always" and latency == "hover" then
        order = {stats.fps, stats.world, stats.home}
    else
        if latency ~= "off" then order[#order+1] = stats.world; order[#order+1] = stats.home end
        if fps ~= "off" then order[#order+1] = stats.fps end
    end
    for _, fs in pairs(stats) do fs:Hide() end
    local anchor = addon.Minimap and addon.Minimap.Border or cluster
    for i, fs in ipairs(order) do
        fs:ClearAllPoints()
        fs:SetPoint("RIGHT", anchor, "BOTTOMRIGHT", -14, 17 + (i-1)*14)
        fs:Show()
    end
    if #order > 0 then
        if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(1, update) end
    elseif ticker then ticker:Cancel(); ticker = nil end
    if not hoverTicker and C_Timer and C_Timer.NewTicker then
        hoverTicker = C_Timer.NewTicker(0.2, refreshHover)
    end
    self:ApplyFonts()
    update()
    refreshHover()
end
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if C_Timer and C_Timer.After then C_Timer.After(0.5, function() M:Apply() end) end
end)
