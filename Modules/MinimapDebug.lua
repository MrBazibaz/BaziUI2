-- Read-only minimap diagnostics. No layout or mouse settings are changed.
local addon = BaziUI
local function out(msg)
    if addon and addon.Print then addon:Print("[Minimap debug] " .. msg)
    else print("[BaziUI minimap debug] " .. msg) end
end
local function num(v)
    if type(v) ~= "number" then return tostring(v) end
    if issecretvalue and issecretvalue(v) then return "secret" end
    return string.format("%.1f", v)
end
local function name(frame)
    if not frame then return "nil" end
    local ok, value = pcall(function()
        return frame.GetName and frame:GetName()
    end)
    if ok and value then return value end
    return tostring(frame)
end
local function describe(frame, label)
    if not frame then out(label .. ": missing"); return end
    local ok, result = pcall(function()
        local x, y = frame:GetCenter()
        local scale = frame:GetEffectiveScale()
        local level = frame:GetFrameLevel()
        local mouse = frame.IsMouseEnabled and frame:IsMouseEnabled()
        return "center=" .. num(x) .. "," .. num(y)
            .. " scale=" .. num(scale) .. " level=" .. tostring(level)
            .. " mouse=" .. tostring(mouse)
    end)
    out(label .. " (" .. name(frame) .. "): " .. (ok and result or "unavailable"))
end
local function run()
    local map = _G.Minimap
    local cluster = _G.MinimapCluster
    local button = _G.BaziUIMinimapButton
    local cfg = addon and addon.db and addon.db.profile and addon.db.profile.minimap
    out("enabled=" .. tostring(cfg and cfg.enabled) .. " style=" .. tostring(cfg and cfg.style))
    describe(map, "Minimap")
    describe(cluster, "Cluster")
    describe(addon and addon.Minimap and addon.Minimap.Border, "Bazi border")
    describe(button, "Launcher")
    if button then
        local regions = {button:GetRegions()}
        for i, region in ipairs(regions) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                local texture = region.GetTexture and region:GetTexture()
                describe(region, "Launcher texture " .. i .. " " .. tostring(texture))
            end
        end
    end
    local x, y = GetCursorPosition()
    out("cursor physical=" .. num(x) .. "," .. num(y)
        .. " mapHover=" .. tostring(map and map:IsMouseOver())
        .. " tooltipShown=" .. tostring(GameTooltip and GameTooltip:IsShown()))
    if GetMouseFoci then
        local ok, frames = pcall(GetMouseFoci)
        if ok and type(frames) == "table" then
            for i = 1, math.min(#frames, 8) do
                out("mouse focus " .. i .. ": " .. name(frames[i]))
            end
        end
    elseif GetMouseFocus then
        local ok, frame = pcall(GetMouseFocus)
        if ok then out("mouse focus: " .. name(frame)) end
    end
end
SLASH_BAZIDEBUG1 = "/bazidebug"
SlashCmdList.BAZIDEBUG = function(arg)
    if arg ~= "minimap" then
        out("Usage: /bazidebug minimap")
        return
    end
    local ok, err = pcall(run)
    if not ok then out("Diagnostic error: " .. tostring(err)) end
end
