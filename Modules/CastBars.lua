local addon = BaziUI
local hud = addon.HUD
local cast = {}
addon.CastBars = cast
local bars, native, hooked = {}, {}, {}
function cast.GetMoverFrame(key) return bars[key] end
local keys = {"player", "target", "breath", "fatigue"}
local mirrorKeys = {BREATH = "breath", EXHAUSTION = "fatigue"}
local mirrorLabels = {breath = "Breath", fatigue = "Fatigue"}
local icons = {player = 135812, target = 136048, breath = 136148, fatigue = 136106}
local colors = {player = {0.83, 0.58, 0.27}, target = {0.83, 0.58, 0.27},
    breath = {0.24, 0.58, 0.86}, fatigue = {0.77, 0.52, 0.23}}
local asset = "Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziHealthGradientRight.tga"
local openingWithoutText = 22810
local demo, refreshTiming

local function secret(value) return issecretvalue and issecretvalue(value) end

local function maskNative(frame, hidden)
    if not frame then return end
    if hidden then
        if native[frame] == nil then native[frame] = frame:GetAlpha() end
        if not hooked[frame] then
            hooked[frame] = true
            hooksecurefunc(frame, "SetAlpha", function(self)
                if native[self] ~= nil and self:GetAlpha() ~= 0 then self:SetAlpha(0) end
            end)
        end
        if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
    elseif native[frame] ~= nil then
        local alpha = native[frame]
        native[frame] = nil
        frame:SetAlpha(alpha)
    end
end

local function makeBar(key)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:EnableMouse(false)
    frame.fill = frame:CreateTexture(nil, "BACKGROUND")
    frame.fill:SetAllPoints()
    frame.status = CreateFrame("StatusBar", nil, frame)
    frame.status:SetStatusBarTexture(asset)
    frame.status:SetStatusBarColor(unpack(colors[key]))
    frame.status:SetPoint("TOPLEFT", 2, -2)
    frame.status:SetPoint("BOTTOMRIGHT", -2, 2)
    local border = addon.Theme:CreateFrameBorder(frame, frame, frame)
    border:SetFrameLevel(frame.status:GetFrameLevel() + 1)
    addon.Theme:AddDropShadow("HUD", frame, border)
    frame.icon = border:CreateTexture(nil, "ARTWORK")
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.name = border:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.name:SetJustifyH("LEFT")
    frame.name:SetWordWrap(false)
    frame.time = border:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.time:SetJustifyH("RIGHT")
    bars[key] = frame
    return frame
end

local function position(frame, key, cfg)
    local anchor
    if (key == "player" or key == "target") and cfg.attachToUnitFrame ~= false then
        anchor = addon.UnitFrames.GetCastBarAnchor(key)
    end
    local x, y = cfg.x, cfg.y
    if anchor then x, y = cfg.unitX, cfg.unitY end
    if frame.positionAnchor == anchor and frame.positionX == x and frame.positionY == y then return end
    frame.positionAnchor, frame.positionX, frame.positionY = anchor, x, y
    frame:ClearAllPoints()
    if anchor then frame:SetPoint("BOTTOM", anchor, "TOP", x, y)
    else frame:SetPoint("CENTER", UIParent, "CENTER", x, y) end
end

local function layout(key, cfg)
    local frame = bars[key] or makeBar(key)
    local opacity = (cfg.opacity or 65) / 100
    frame.fill:SetColorTexture(0.055, 0.041, 0.038, opacity)
    frame:SetSize(cfg.width, cfg.height)
    position(frame, key, cfg)
    frame.icon:ClearAllPoints()
    local nameInset = cfg.height + 2
    if key == "target" then
        if cfg.iconOnRight then frame.icon:SetPoint("LEFT", frame, "RIGHT", 5, 0)
        else frame.icon:SetPoint("RIGHT", frame, "LEFT", -5, 0) end
        nameInset = 6
    else
        frame.icon:SetPoint("LEFT", frame, "LEFT", 3, 0)
    end
    frame.icon:SetSize(cfg.height - 6, cfg.height - 6)
    frame.name:ClearAllPoints()
    frame.time:ClearAllPoints()
    frame.name:SetPoint("LEFT", frame, "LEFT", nameInset + (cfg.textX or 0), cfg.textY or 0)
    frame.time:SetPoint("RIGHT", frame, "RIGHT", -6, cfg.textY or 0)
    local remainingWidth = math.max(12, cfg.width - nameInset - 38 - (cfg.textX or 0))
    frame.name:SetWidth((cfg.textWidth or 0) > 0 and math.min(cfg.textWidth, remainingWidth) or remainingWidth)
    local file = addon.Typography.Path(addon.db.profile.font)
    addon.Typography.Apply(frame.name, "HUD:Bar", file, cfg.fontSize, "OUTLINE", true)
    addon.Typography.Apply(frame.time, "HUD:Bar", file, cfg.fontSize, "OUTLINE", true)
end

local function show(frame, name, icon, value, remaining)
    if not frame.normalProgress then
        frame.status:SetMinMaxValues(0, 1)
        frame.normalProgress = true
    end
    frame.status:SetValue(value)
    if secret(name) or frame.lastName ~= name then
        frame.name:SetText(name)
        frame.lastName = not secret(name) and name or nil
    end
    if secret(icon) or frame.lastIcon ~= icon then
        frame.icon:SetTexture(icon)
        frame.lastIcon = not secret(icon) and icon or nil
    end
    local tenth = math.floor(remaining * 10 + 0.5)
    if frame.lastTenth ~= tenth then
        frame.time:SetFormattedText("%.1f", remaining)
        frame.lastTenth = tenth
    end
    frame:Show()
end

local function updateCast(key, cfg)
    local frame = bars[key]
    if not cfg.enabled and not demo then if frame then frame:Hide() end; return false end
    if not frame then layout(key, cfg); frame = bars[key] end
    position(frame, key, cfg)
    if demo then
        show(frame, key == "player" and "Player cast" or "Target cast", icons[key], 0.62, 1.7)
        return cfg.enabled
    end
    local name, displayText, icon, startTime, endTime, _, _, _, spellID = UnitCastingInfo(key)
    local channel
    if not secret(name) and not name and not secret(displayText) and not displayText
        and not secret(endTime) and not endTime then
        name, displayText, icon, startTime, endTime = UnitChannelInfo(key)
        channel = true
    end
    if not secret(name) and not name and not secret(displayText) and not displayText
        and not secret(endTime) and not endTime then
        frame.duration = nil
        frame:Hide()
        return false
    end
    local label = displayText
    if not secret(label) and (not label or label == "") then label = name end
    local opening = not channel and not secret(spellID) and spellID == openingWithoutText
    if opening or (not secret(label) and (not label or label == "" or label == "Opening - No Text")) then
        label = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(3365)) or OPENING or "Opening"
    end
    if secret(startTime) or secret(endTime) then
        if refreshTiming or not frame.duration then
            local api = channel and _G.UnitChannelDuration or _G.UnitCastingDuration
            local timer = api and api(key)
            if not timer and channel and UnitEmpoweredChannelDuration then timer = UnitEmpoweredChannelDuration(key) end
            if not timer or not frame.status.SetTimerDuration or not Enum or not Enum.StatusBarTimerDirection
                or not Enum.StatusBarInterpolation then
                frame.duration = nil
                frame:Hide()
                return false
            end
            local direction = channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
            frame.status:SetMinMaxValues(0, 1)
            frame.status:SetTimerDuration(timer, Enum.StatusBarInterpolation.Immediate, direction)
            frame.duration = timer
        end
        frame.normalProgress, frame.lastName, frame.lastIcon, frame.lastTenth = nil, nil, nil, nil
        frame.icon:SetTexture(icon)
        frame.name:SetText(label)
        local remaining = frame.duration:GetRemainingDuration()
        if secret(remaining) or type(remaining) == "number" then frame.time:SetFormattedText("%.1f", remaining)
        else frame.time:SetText("") end
        frame:Show()
        return true
    end
    if type(endTime) ~= "number" or type(startTime) ~= "number" or endTime <= startTime then
        frame:Hide()
        return false
    end
    frame.duration = nil
    local remaining = math.max(0, endTime / 1000 - GetTime())
    local fraction = math.min(1, remaining / ((endTime - startTime) / 1000))
    show(frame, label, icon, channel and fraction or 1 - fraction, remaining)
    return true
end

local function updateMirrors()
    local seen = {}
    if GetMirrorTimerInfo and GetMirrorTimerProgress then
        for index = 1, MIRRORTIMER_NUMTIMERS or 3 do
            local name, value, limit, _, paused, label = GetMirrorTimerInfo(index)
            local key = not secret(name) and mirrorKeys[name]
            if key and not secret(limit) and type(limit) == "number" and limit > 0 then
                local cfg = hud.Settings(key)
                if cfg.enabled and not demo then
                    if not bars[key] then layout(key, cfg) end
                    if not paused or paused == 0 then value = GetMirrorTimerProgress(name) end
                    if not secret(value) and type(value) == "number" and value >= 0 then
                        show(bars[key], label or mirrorLabels[key], icons[key], math.min(1, value / limit), value / 1000)
                        seen[key] = true
                    end
                end
            end
        end
    end
    for _, key in pairs(mirrorKeys) do
        if demo then
            if not bars[key] then layout(key, hud.Settings(key)) end
            show(bars[key], mirrorLabels[key], icons[key], 0.67, 42)
        elseif bars[key] and not seen[key] then
            bars[key]:Hide()
        end
    end
    local container = _G.MirrorTimerContainer
    if container and container.mirrorTimers then
        for _, frame in ipairs(container.mirrorTimers) do maskNative(frame, seen[mirrorKeys[frame.timer]]) end
    end
end

local function tick(mirrors)
    if not addon.db then return end
    local player, target = hud.Settings("player"), hud.Settings("target")
    maskNative(_G.PlayerCastingBarFrame, player.enabled)
    if _G.CastingBarFrame ~= _G.PlayerCastingBarFrame then maskNative(_G.CastingBarFrame, player.enabled) end
    maskNative(_G.TargetFrameSpellBar or (_G.TargetFrame and _G.TargetFrame.spellbar), target.enabled)
    updateCast("player", player)
    updateCast("target", target)
    if mirrors and (demo or hud.Settings("breath").enabled or hud.Settings("fatigue").enabled or bars.breath or bars.fatigue) then
        updateMirrors()
    end
    refreshTiming = false
end

local controller = CreateFrame("Frame")
local elapsed = 0
local function onUpdate(_, delta)
    elapsed = elapsed + delta
    local mirrors = elapsed >= 0.035
    if mirrors then elapsed = 0 end
    tick(mirrors)
end
function cast.Refresh()
    if not addon.db then return end
    local needed = demo
    for _, key in ipairs(keys) do
        local cfg = hud.Settings(key)
        needed = needed or cfg.enabled
        if bars[key] or cfg.enabled or demo then layout(key, cfg) end
    end
    controller:SetScript("OnUpdate", needed and onUpdate or nil)
    refreshTiming = true
    tick(true)
end
function cast.TogglePreview()
    demo = not demo
    cast.Refresh()
    return demo
end
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE"}) do
    controller:RegisterEvent(event)
end
controller:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then C_Timer.After(0, cast.Refresh)
    elseif not unit or unit == "player" or unit == "target" then refreshTiming = true end
end)
