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
-- Inspect anonymous mouse focus frames without mutating them.
local function focusDetails(frame)
    if not frame then return "nil" end
    local function read(fn)
        local ok, value = pcall(fn)
        return ok and tostring(value) or "unavailable"
    end
    local chain, current = {}, frame
    for i = 1, 5 do
        if not current then break end
        local item = current
        local kind = read(function() return item.GetObjectType and item:GetObjectType() end)
        chain[#chain + 1] = name(item) .. "[" .. kind .. "]"
        local ok, parent = pcall(function() return item.GetParent and item:GetParent() end)
        if not ok or parent == item then break end
        current = parent
    end
    local mouse = read(function() return frame.IsMouseEnabled and frame:IsMouseEnabled() end)
    local level = read(function() return frame.GetFrameLevel and frame:GetFrameLevel() end)
    return table.concat(chain, " <- ") .. " mouse=" .. mouse .. " level=" .. level
end
-- Sample hover without opening chat. Prints changes and a summary after 10 seconds.
local sampler = CreateFrame("Frame")
local elapsed, remaining, previous, samples, hovered, tips = 0, 0, nil, 0, 0, 0
local function mouseFocusName()
    if GetMouseFoci then
        local ok, frames = pcall(GetMouseFoci)
        if ok and type(frames) == "table" and frames[1] then
            return focusDetails(frames[1])
        end
    end
    if GetMouseFocus then
        local ok, frame = pcall(GetMouseFocus)
        if ok then return focusDetails(frame) end
    end
    return "unknown"
end
local function stopHover()
    sampler:SetScript("OnUpdate", nil)
    out("Hover summary: samples=" .. samples .. " overMap=" .. hovered
        .. " tooltipShown=" .. tips)
end
local function startHover()
    if sampler:GetScript("OnUpdate") then stopHover() end
    elapsed, remaining, previous, samples, hovered, tips = 0, 10, nil, 0, 0, 0
    out("Hover sampling started (10 seconds). Move cursor over quest area NOW.")
    sampler:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        remaining = remaining - dt
        if elapsed >= 0.2 then
            elapsed = 0
            local map = _G.Minimap
            local over = map and map:IsMouseOver() or false
            local tip = GameTooltip and GameTooltip:IsShown() or false
            local focus = mouseFocusName()
            samples = samples + 1
            if over then hovered = hovered + 1 end
            if tip then tips = tips + 1 end
            local state = tostring(over) .. "/" .. tostring(tip) .. "/" .. focus
            if state ~= previous then
                out("hover map=" .. tostring(over) .. " tooltip=" .. tostring(tip)
                    .. " focus=" .. focus)
                previous = state
            end
        end
        if remaining <= 0 then stopHover() end
    end)
end

-- Marker overlays are debug-only and do not accept mouse input.
local marks = {}
local function clearMarks()
    for _, mark in ipairs(marks) do mark:Hide() end
    marks = {}
end
local function markCenter(target, color, label)
    if not target then return end
    local ok, x, y = pcall(function() return target:GetCenter() end)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then
        out(label .. ": center unavailable")
        return
    end
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetSize(16, 16)
    overlay:EnableMouse(false)
    overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    local horizontal = overlay:CreateTexture(nil, "OVERLAY")
    horizontal:SetColorTexture(color[1], color[2], color[3], 1)
    horizontal:SetSize(16, 2)
    horizontal:SetPoint("CENTER")
    local vertical = overlay:CreateTexture(nil, "OVERLAY")
    vertical:SetColorTexture(color[1], color[2], color[3], 1)
    vertical:SetSize(2, 16)
    vertical:SetPoint("CENTER")
    marks[#marks + 1] = overlay
    out(label .. " center=" .. num(x) .. "," .. num(y))
end
local function showMarks()
    clearMarks()
    local button = _G.BaziUIMinimapButton
    if not button then out("Launcher missing"); return end
    markCenter(button, {1, 1, 1}, "Button (white)")
    local regions = {button:GetRegions()}
    local colors = {{1, 0, 0}, {0, 1, 0}, {0, 0.5, 1}}
    for i, region in ipairs(regions) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local color = colors[#marks] or {1, 0, 1}
            markCenter(region, color, "Texture " .. i)
        end
    end
    out("Crosshairs mark texture geometry, not the visible painted pixels.")
    out("White=button; red=emblem; green=border; blue=highlight.")
    out("Use /bazidebug bounds for texture rectangles; /bazidebug clear to hide.")
end
local function showBounds()
    clearMarks()
    local button = _G.BaziUIMinimapButton
    if not button then out("Launcher missing"); return end
    local function outline(target, label, color)
        local ok, left, right, top, bottom = pcall(function()
            return target:GetLeft(), target:GetRight(), target:GetTop(), target:GetBottom()
        end)
        if not ok or type(left) ~= "number" or type(right) ~= "number"
            or type(top) ~= "number" or type(bottom) ~= "number" then
            out(label .. ": bounds unavailable"); return
        end
        local parent = CreateFrame("Frame", nil, UIParent)
        parent:SetFrameStrata("TOOLTIP")
        parent:SetFrameLevel(100)
        parent:SetSize(right - left, top - bottom)
        parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        parent:EnableMouse(false)
        local function edge(width, height, point)
            local t = parent:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(color[1], color[2], color[3], 1)
            t:SetSize(width, height)
            t:SetPoint(point)
        end
        edge(right - left, 1, "TOP")
        edge(right - left, 1, "BOTTOM")
        edge(1, top - bottom, "LEFT")
        edge(1, top - bottom, "RIGHT")
        marks[#marks + 1] = parent
        out(label .. " bounds=" .. num(left) .. "," .. num(bottom)
            .. " to " .. num(right) .. "," .. num(top))
    end
    outline(button, "Button", {1, 1, 1})
    local regions = {button:GetRegions()}
    local colors = {{1, 0, 0}, {0, 1, 0}, {0, 0.5, 1}}
    local count = 0
    for _, region in ipairs(regions) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            count = count + 1
            outline(region, "Texture " .. count, colors[count] or {1, 0, 1})
        end
    end
    out("Bounds show texture rectangles, not visible artwork pixels.")
end
SLASH_BAZIDEBUG1 = "/bazidebug"
SlashCmdList.BAZIDEBUG = function(arg)
    if arg == "hover" then startHover(); return end
    if arg == "marks" then showMarks(); return end
    if arg == "bounds" then showBounds(); return end
    if arg == "clear" then clearMarks(); stopHover(); return end
    if arg ~= "minimap" then
        out("Usage: /bazidebug minimap | hover | marks | bounds | clear")
        return
    end
    local ok, err = pcall(run)
    if not ok then out("Diagnostic error: " .. tostring(err)) end
end
