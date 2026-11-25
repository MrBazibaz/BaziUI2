local addon = BaziUI
local hud = addon.HUD
local auras = {}
addon.HUDAuras = auras
local frames = {buffs = "BuffFrame", debuffs = "DebuffFrame"}
local hooks, previews = {}, {}
local nativeButtons = setmetatable({}, {__mode = "k"})
local demo
local sampleIcons = {
    buffs = {135932, 135987, 136090, 136116, 132153, 136070},
    debuffs = {136067, 136118, 132156, 136133, 135914, 132152},
}
local anchors = {
    Below = {"TOP", "BOTTOM", 0, -2}, Above = {"BOTTOM", "TOP", 0, 2},
    Left = {"RIGHT", "LEFT", -3, 0}, Right = {"LEFT", "RIGHT", 3, 0}, Center = {"CENTER", "CENTER", 0, 0},
}

local function position(button, cfg, index, keepIconAnchors)
    local slot = index - 1
    local column, row
    if cfg.vertical then column, row = math.floor(slot / cfg.rows), slot % cfg.rows
    else column, row = slot % cfg.columns, math.floor(slot / cfg.columns) end
    local horizontalText = cfg.text == "Left" or cfg.text == "Right"
    local verticalText = cfg.text == "Below" or cfg.text == "Above"
    local dx = cfg.size + (horizontalText and cfg.fontSize * 3 + 6 or 5)
    local dy = cfg.size + (verticalText and cfg.fontSize + 5 or 5)
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER",
        cfg.x + column * dx * (cfg.left and -1 or 1),
        cfg.y + row * dy * (cfg.up and 1 or -1))
    button:SetSize(cfg.size, cfg.size)
    if not keepIconAnchors then
        button.Icon:ClearAllPoints()
        button.Icon:SetAllPoints(button)
    end
end

local function positionText(button, cfg, text)
    text = text or button.Duration
    if not text then return end
    local anchor = anchors[cfg.text] or anchors.Below
    text:ClearAllPoints()
    text:SetPoint(anchor[1], button.Icon, anchor[2], anchor[3], anchor[4])
    addon.Typography.Apply(text, "HUD:Aura",
        addon.Typography.Path(addon.db.profile.font), cfg.fontSize, "OUTLINE", true)
end

local function colorDuration(text, remaining)
    text:SetVertexColor(unpack(addon.ActionBars.GetCountdownColor(remaining)))
end

local function retarget(region, points)
    region:ClearAllPoints()
    for _, point in ipairs(points) do region:SetPoint(unpack(point, 1, 5)) end
end

local function getPoints(region)
    local points = {}
    local count = region:GetNumPoints()
    if (issecretvalue and issecretvalue(count)) or type(count) ~= "number" then return end
    for i = 1, count do
        local point, relative, anchor, x, y = region:GetPoint(i)
        if point then points[#points + 1] = {point, relative, anchor, x, y} end
    end
    return points
end

local function restore(button, state)
    if state.placed then
        button:SetScale(state.scale)
        button:SetSize(state.width, state.height)
        retarget(button, state.points)
        if state.iconPoints then retarget(button.Icon, state.iconPoints) end
        state.placed = nil
    end
    if state.hidden then
        button:SetAlpha(state.alpha)
        button:EnableMouse(state.mouse)
        state.hidden = nil
    end
    if state.label then
        state.label:Hide()
        button.Duration:SetAlpha(state.durationAlpha)
    end
    state.active = nil
end

local function styleButton(button, cfg, index, key)
    local state = nativeButtons[button]
    if not state then
        state = {key = key}
        if button.Duration then
            state.durationAlpha = button.Duration:GetAlpha()
            state.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall", 2)
        end
        nativeButtons[button] = state
    end
    if index > cfg.columns * cfg.rows or button.isExample then
        if not state.hidden then
            state.alpha, state.mouse = button:GetAlpha(), button:IsMouseEnabled()
            button:SetAlpha(0)
            button:EnableMouse(false)
            state.hidden = true
        end
        return
    end
    if state.hidden then
        button:SetAlpha(state.alpha)
        button:EnableMouse(state.mouse)
        state.hidden = nil
    end
    local _, relative = button:GetPoint()
    if not state.placed or relative ~= UIParent then
        local points, iconPoints = getPoints(button), getPoints(button.Icon)
        if not points and not state.placed then return end
        if points then state.points = points end
        if iconPoints then state.iconPoints = iconPoints end
    end
    if not state.placed then
        state.width, state.height, state.scale = button:GetWidth(), button:GetHeight(), button:GetScale()
    end
    button:SetScale(1)
    position(button, cfg, index, not state.iconPoints)
    state.placed, state.active = true, true
    if state.label then
        button.Duration:SetAlpha(0)
        positionText(button, cfg, state.label)
    end
end

local function applyNative(key)
    if not addon.db then return end
    local state = hooks[key]
    local frame = state and state.frame
    if not frame or not frame.auraFrames then return end
    if InCombatLockdown() then return end
    local cfg = hud.Settings(key)
    if not cfg.enabled then
        for button, original in pairs(nativeButtons) do
            if original.key == key then restore(button, original) end
        end
        state.applied = nil
        return
    end
    state.applied = true
    local index = 0
    local consolidated = frame.ConsolidatedBuffs
    if consolidated and consolidated.Icon and consolidated:IsShown()
        and not (InCombatLockdown() and consolidated:IsProtected()) then
        index = 1
        styleButton(consolidated, cfg, index, key)
    end
    for _, button in ipairs(frame.auraFrames) do
        if button.Icon and not button.isAuraAnchor and button:IsShown()
            and not (InCombatLockdown() and button:IsProtected()) then
            index = index + 1
            styleButton(button, cfg, index, key)
        end
    end
end

local function queueNative(key)
    local state = hooks[key]
    if not state or state.queued or not (state.enabled or state.applied) then return end
    state.queued = true
    C_Timer.After(0, function()
        state.queued = nil
        applyNative(key)
    end)
end

local durationUpdate = CreateFrame("Frame")
local elapsed = 0
durationUpdate:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    for button, state in pairs(nativeButtons) do
        if state.label and state.active and button:IsVisible() and not state.hidden then
            local visible = button.Duration:IsShown()
            state.label:SetShown(visible)
            if visible then
                state.label:SetText(button.Duration:GetText())
                colorDuration(state.label, button.timeLeft)
            end
        end
    end
end)

local function updatePreview(key, cfg)
    previews[key] = previews[key] or {}
    local buttons = previews[key]
    local count = demo and math.min(cfg.columns * cfg.rows, 20) or 0
    for index = 1, count do
        local button = buttons[index]
        if not button then
            button = CreateFrame("Frame", nil, UIParent)
            button:SetFrameStrata("HIGH")
            button:EnableMouse(false)
            button.Icon = button:CreateTexture(nil, "ARTWORK")
            button.Icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            button.Duration = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.border = addon.Theme:CreateFrameBorder(button, button, button)
            if key == "debuffs" then button.border:SetBackdropBorderColor(0.82, 0.2, 0.17, 1) end
            buttons[index] = button
        end
        local icons = sampleIcons[key]
        button.Icon:SetTexture(icons[(index - 1) % #icons + 1])
        local remaining = index % 3 == 2 and 3 or index % 3 == 0 and 1 or index * 120
        button.Duration:SetText(remaining < 60 and (remaining .. "s") or (remaining / 60 .. "m"))
        position(button, cfg, index)
        positionText(button, cfg)
        colorDuration(button.Duration, remaining)
        button:Show()
    end
    for index = count + 1, #buttons do buttons[index]:Hide() end
end

function auras.Refresh()
    if not addon.db then return end
    for key, name in pairs(frames) do
        local cfg, frame = hud.Settings(key), _G[name]
        if frame and frame.UpdateGridLayout and frame.UpdateAuraButtons then
            local state = hooks[key]
            if cfg.enabled and not state then
                state = {frame = frame}
                hooks[key] = state
                hooksecurefunc(frame, "UpdateGridLayout", function() queueNative(key) end)
                hooksecurefunc(frame, "UpdateAuraButtons", function() queueNative(key) end)
            end
            if state then state.enabled = cfg.enabled end
            queueNative(key)
        end
        updatePreview(key, cfg)
    end
end

function auras.TogglePreview()
    demo = not demo
    auras.Refresh()
    return demo
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "ADDON_LOADED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name == "Blizzard_BuffFrame" then C_Timer.After(0, auras.Refresh) end
end)
