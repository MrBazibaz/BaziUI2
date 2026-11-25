local addon = BaziUI
local M = {}
addon.ActionBars = M

M.bars = {
    {key="bar1", title="Bar 1", frame="MainActionBar", prefix="ActionButton", count=12},
    {key="bar2", title="Bar 2", frame="MultiBarBottomLeft", prefix="MultiBarBottomLeftButton", count=12},
    {key="bar3", title="Bar 3", frame="MultiBarBottomRight", prefix="MultiBarBottomRightButton", count=12},
    {key="bar4", title="Bar 4", frame="MultiBarRight", prefix="MultiBarRightButton", count=12},
    {key="bar5", title="Bar 5", frame="MultiBarLeft", prefix="MultiBarLeftButton", count=12},
    {key="bar6", title="Bar 6", frame="MultiBar5", prefix="MultiBar5Button", count=12},
    {key="bar7", title="Bar 7", frame="MultiBar6", prefix="MultiBar6Button", count=12},
    {key="bar8", title="Bar 8", frame="MultiBar7", prefix="MultiBar7Button", count=12},
    {key="pet", title="Pet", frame="PetActionBar", prefix="PetActionButton", count=10},
    {key="stance", title="Stance", frame="StanceBar", prefix="StanceButton", count=10},
    {key="totem", title="Totem", frame="MultiCastActionBarFrame", prefix="MultiCastActionButton", count=12},
    {key="possess", title="Possess", frame="PossessActionBar", prefix="PossessButton", count=2},
    {key="micro", title="Micro Menu", frame="MicroMenuContainer", fallback="MicroMenu"},
    {key="bags", title="Bag Bar", frame="BagsBar"},
}

local defaults = {
    visible=true, scale=100, buttonSize=36, petButtonSize=0, nativeButtonSize=0, nativeSpacing=2, spacing=2, rows=0, columns=0, buttons=0, direction="default",
    empty=false, vanillaBackground=true, slotTint=false, x=0, y=0, border=true,
    font="general", textSize=12, hotkeys=true, macro=true, cooldownFont="general", cooldownSize=0,
    range=true, mana=true, unusable=true, cooldown=true, strength=100, proc=true, active=true,
}
local experienceDefaults = {
    enabled=false, width=360, height=16, x=0, y=-210, opacity=100,
    showText=true, textMode="both", font="general", textSize=12,
    segmented=false, showRested=true, showQuestXP=true, showQuestText=true,
    showReputation=false, reputationY=-232,
}
function M:Settings()
    local profile = addon.db.profile
    if not profile.actionbars then profile.actionbars = {enabled=false, autoRanks=false, gryphons=true, bars={}} end
    local db = profile.actionbars
    db.experience = db.experience or {}
    for key, value in pairs(experienceDefaults) do
        if db.experience[key] == nil then db.experience[key] = value end
    end
    if not db.bars then db.bars = {} end
    for _, def in ipairs(self.bars) do
        local settings = db.bars[def.key] or {}
        db.bars[def.key] = settings
        if not settings.spacingUsesSignedValues then
            if settings.spacing == -1 then settings.spacing = 2 end
            settings.spacingUsesSignedValues = true
        end
        if def.prefix and not settings.flareStatusColors then
            if settings.strength == 45 then settings.strength = 100 end
            settings.flareStatusColors = true
        end
        if def.prefix and settings.slotTint == nil then
            if settings.vanillaBackground ~= nil then
                settings.slotTint = settings.vanillaBackground
            end
            settings.vanillaBackground = false
        end
        for key, value in pairs(defaults) do
            if settings[key] == nil then settings[key] = value end
        end
    end
    return db
end

local function locked() return InCombatLockdown and InCombatLockdown() end
local function readable(value)
    return (not issecretvalue or not issecretvalue(value)) and (not canaccessvalue or canaccessvalue(value))
end

local frameStates, buttonStates, capsStates = {}, {}, {}
local accessoryArt, accessoryHooks = {}, {}
local hiddenParent, events, pendingLayout, statusTicker, statusIndex
local activeButtons = {}
local fonts = {friz="Fonts\\FRIZQT__.TTF", arial="Fonts\\ARIALN.TTF"}
local statusColors = {
    range={1, 0.25, 0.25}, mana={0.55, 0.65, 1}, unusable={0.72, 0.72, 0.72}, cooldown={1, 1, 1},
}
local cooldownWhite, cooldownYellow, cooldownOrange = {1, 1, 1}, {1, 0.86, 0.24}, {1, 0.49, 0.12}
local cooldownColorCurve
local unpack = unpack or table.unpack

function M.GetCountdownColor(remaining)
    if readable(remaining) and type(remaining) == "number" and remaining > 0 then
        if remaining < 2 then return cooldownOrange end
        if remaining < 5 then return cooldownYellow end
    end
    return cooldownWhite
end

local function getFrame(def)
    return _G[def.frame] or (def.fallback and _G[def.fallback])
end

local editSelections = setmetatable({}, {__mode = "k"})
local editBarNames = {StanceBar = true, PetActionBar = true, PossessActionBar = true}
local hiddenEditControls = {}
local editSettingsHook
local function syncEditControls(enabled)
    if locked() then return end
    local manager = EditModeManagerFrame
    local account = manager and manager.AccountSettings
    local controls = account and account.settingsCheckButtons
    if not controls then return end
    for name in pairs(editBarNames) do
        local control = controls[name]
        if control and enabled and control:IsShown() then
            hiddenEditControls[control] = true
            control:Hide()
        end
    end
    if not enabled then
        for control in pairs(hiddenEditControls) do
            control:Show()
            hiddenEditControls[control] = nil
        end
    end
    if editSettingsHook ~= account and hooksecurefunc and account.RefreshActionBarShown and account.ResetActionBarShown then
        editSettingsHook = account
        manager:HookScript("OnShow", function()
            C_Timer.After(0, function() syncEditControls(M:Settings().enabled) end)
        end)
    end
end

function M:SuppressEditSelection(frame, ownsBar)
    if not frame or not frame.Selection or not hooksecurefunc then return end
    local hide = editSelections[frame]
    if not hide then
        local queued
        hide = function()
            if queued or not ownsBar() or locked() then return end
            queued = true
            C_Timer.After(0, function()
                queued = false
                if ownsBar() and not locked() then frame.Selection:Hide() end
            end)
        end
        editSelections[frame] = hide
        if frame.HighlightSystem then hooksecurefunc(frame, "HighlightSystem", hide) end
        if frame.SetSelectionShown then
            hooksecurefunc(frame, "SetSelectionShown", function(_, shown) if shown then hide() end end)
        end
        if frame.OnEditModeEnter then hooksecurefunc(frame, "OnEditModeEnter", hide) end
    end
    if frame.Selection:IsShown() then hide() end
end

local function getButtons(def, frame)
    if frame.actionButtons and #frame.actionButtons > 0 then return frame.actionButtons end
    local buttons = {}
    for i = 1, def.count or 0 do
        local button = _G[def.prefix .. i]
        if button then buttons[#buttons + 1] = button end
    end
    return buttons
end

function M:CreateBarShadow(bar, condition)
    local shadow = addon.Theme:AddDropShadow("ActionBars", bar, nil, condition)
    if not shadow then return end
    shadow:SetShadowBounds(bar, 3)
    local shapes = addon.Chat.Shapes
    if shapes and shapes.Fill then
        local backing = shapes.Fill(shadow, "BACKGROUND", 1, 4)
        backing:SetPoint("TOPLEFT", shadow, "TOPLEFT")
        backing:SetPoint("BOTTOMRIGHT", shadow, "BOTTOMRIGHT")
        backing:SetColor(0.025, 0.018, 0.012, 1)
        backing:SetAlpha(0.48)
        addon.Backgrounds.Track("actionBars", backing, 0.48)
        shadow.baziBarBackground = backing
    end
    return shadow
end

local nativeShadows = {}
local function refreshNativeShadow(frame, state)
    local left, bottom, right, top
    local x, y = frame:GetLeft(), frame:GetBottom()
    if state.enabled and frame:IsShown() and x and y then
        local scale = frame:GetEffectiveScale()
        for _, button in ipairs(state.buttons) do
            local bx, by, width, height = button:GetRect()
            if button:IsShown() and bx and by and width and height then
                local ratio = button:GetEffectiveScale() / scale
                left = math.min(left or math.huge, bx * ratio)
                bottom = math.min(bottom or math.huge, by * ratio)
                right = math.max(right or -math.huge, (bx + width) * ratio)
                top = math.max(top or -math.huge, (by + height) * ratio)
            end
        end
    end
    state.hasBounds = left ~= nil
    if left then
        state.bounds:ClearAllPoints()
        state.bounds:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left - x, bottom - y)
        state.bounds:SetSize(right - left, top - bottom)
    end
    state.shadow:RefreshVisibility()
end

local function updateNativeShadow(frame, buttons, enabled)
    local state = nativeShadows[frame]
    if not state then
        state = {watched = {}}
        state.bounds = CreateFrame("Frame", nil, frame)
        state.bounds:SetAllPoints(frame)
        state.shadow = M:CreateBarShadow(frame, function() return state.hasBounds == true end)
        if not state.shadow then return end
        state.shadow:SetShadowBounds(state.bounds, 3)
        nativeShadows[frame] = state
        function state.Queue()
            if state.queued then return end
            state.queued = true
            C_Timer.After(0, function()
                state.queued = nil
                refreshNativeShadow(frame, state)
            end)
        end
        frame:HookScript("OnShow", state.Queue)
        frame:HookScript("OnSizeChanged", state.Queue)
    end
    state.buttons, state.enabled = buttons, enabled
    for _, button in ipairs(buttons) do
        if not state.watched[button] then
            state.watched[button] = true
            button:HookScript("OnShow", state.Queue)
            button:HookScript("OnHide", state.Queue)
            button:HookScript("OnSizeChanged", state.Queue)
        end
    end
    state.Queue()
end

local function anchors(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = {frame:GetPoint(i)} end
    return points
end

local function setVisible(frame, state, visible)
    if visible then
        if state.parent then frame:SetParent(state.parent); state.parent = nil end
    elseif not state.parent then
        state.parent = frame:GetParent()
        frame:SetParent(hiddenParent)
    end
end

local function enableNativeBar(def, settings)
    local number = tonumber(def.key:match("^bar([2-8])$"))
    if not number or not settings.visible or not (settings.empty or settings.visibilityRequested) then return end
    if not (Settings and Settings.GetSetting and Settings.GetValue and Settings.SetValue) then return end
    local key = "PROXY_SHOW_ACTIONBAR_" .. number
    if Settings.GetSetting(key) and Settings.GetValue(key) == false then
        Settings.SetValue(key, true)
    end
end

local function applyNativeRows(frame, state, buttons, settings)
    if not settings or (settings.rows == 0 and settings.nativeSpacing == defaults.nativeSpacing) then
        for button, points in pairs(state.buttonPoints or {}) do
            button:ClearAllPoints()
            for _, point in ipairs(points) do button:SetPoint(unpack(point)) end
        end
        state.buttonPoints = nil
        return
    end
    if #buttons == 0 then return end
    state.buttonPoints = state.buttonPoints or {}
    local columns = math.ceil(#buttons / math.max(1, settings.rows))
    local rows = math.ceil(#buttons / columns)
    local first = buttons[1]
    local scale = first:GetEffectiveScale() / frame:GetEffectiveScale()
    local dx = first:GetWidth() * scale + settings.nativeSpacing
    local dy = first:GetHeight() * scale + settings.nativeSpacing
    for index, button in ipairs(buttons) do
        state.buttonPoints[button] = state.buttonPoints[button] or anchors(button)
        local ratio = frame:GetEffectiveScale() / button:GetEffectiveScale()
        button:ClearAllPoints()
        button:SetPoint("CENTER", frame, "CENTER",
            ((index - 1) % columns - (columns - 1) / 2) * dx * ratio,
            ((rows - 1) / 2 - math.floor((index - 1) / columns)) * dy * ratio)
    end
end

local function applyLayout(frame, settings, enabled, def)
    local state = frameStates[frame]
    if not state then state = {}; frameStates[frame] = state end
    setVisible(frame, state, settings.visible)
    -- The pet bar's container can span several rows of empty world space.
    -- Its individual secure buttons keep their own mouse input.
    if enabled and def and def.key == "pet" then
        if not state.petMouse then
            state.petMouse = {enabled = frame:IsMouseEnabled()}
            if frame.IsMouseClickEnabled and frame.SetMouseClickEnabled and frame.IsMouseMotionEnabled and frame.SetMouseMotionEnabled then
                state.petMouse.click, state.petMouse.motion = frame:IsMouseClickEnabled(), frame:IsMouseMotionEnabled()
            end
        end
        frame:EnableMouse(false)
    elseif not enabled and state.petMouse then
        frame:EnableMouse(state.petMouse.enabled)
        if state.petMouse.click ~= nil then
            frame:SetMouseClickEnabled(state.petMouse.click)
            frame:SetMouseMotionEnabled(state.petMouse.motion)
        end
        state.petMouse = nil
    end
    if enabled then
        state.settingPosition = true
        state.points = state.points or anchors(frame)
        state.scale = state.scale or frame:GetScale()
        local first = frame.actionButtons and frame.actionButtons[1]
        if not first and def and def.prefix then first = _G[def.prefix .. "1"] end
        local containerScale = first and first.container and first.container:GetScale() or 1
        local sizeFactor = 1
        local buttonSize = def and def.key == "pet" and settings.petButtonSize or settings.nativeButtonSize
        if buttonSize > 0 and first then
            local width = first:GetWidth() * first:GetScale()
            if width > 0 then sizeFactor = buttonSize / width end
        end
        -- Edit Mode also scales the button containers inside the bar.
        local scale = settings.scale * sizeFactor / (100 * containerScale)
        if math.abs(frame:GetScale() - scale) > 0.001 then frame:SetScale(scale) end
        local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        local x, y = settings.x * ratio, settings.y * ratio
        local point, parent, relative, oldX, oldY = frame:GetPoint(1)
        if frame:GetNumPoints() ~= 1 or point ~= "CENTER" or parent ~= UIParent or relative ~= "CENTER"
            or math.abs((oldX or 0) - x) > 0.01 or math.abs((oldY or 0) - y) > 0.01 then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
        end
        if def and def.prefix then applyNativeRows(frame, state, getButtons(def, frame), settings) end
        state.settingPosition = nil
    elseif state.points then
        applyNativeRows(frame, state)
        frame:SetScale(state.scale)
        frame:ClearAllPoints()
        for _, point in ipairs(state.points) do frame:SetPoint(unpack(point)) end
        state.points, state.scale = nil, nil
    end
end

local function watchPetLayout(frame, def)
    local state = frameStates[frame]
    if state.watchingPetLayout then return end
    state.watchingPetLayout = true
    local function queue()
        if state.settingPosition or state.petLayoutQueued or addon.Movers and addon.Movers.IsDragging(frame) then return end
        state.petLayoutQueued = true
        C_Timer.After(0, function()
            state.petLayoutQueued = nil
            local db = M:Settings()
            if not db.enabled or not db.bars.pet.visible then return end
            if locked() then pendingLayout = true; return end
            applyLayout(frame, db.bars.pet, true, def)
        end)
    end
    frame:HookScript("OnShow", queue)
    hooksecurefunc(frame, "SetPoint", queue)
    hooksecurefunc(frame, "ClearAllPoints", queue)
    hooksecurefunc(frame, "SetAllPoints", queue)
end

local function fontString(state, region, wanted, size, fontKey, preserveFlags)
    if (type(region) ~= "table" and type(region) ~= "userdata") or not region.GetFont
        or (region.IsForbidden and region:IsForbidden()) then return end
    if not state.texts[region] then
        local file, height, flags = region:GetFont()
        state.texts[region] = {file, height, flags, alpha=not preserveFlags and region:GetAlpha() or nil}
    end
    local original = state.texts[region]
    local font = fonts[fontKey or state.settings.font] or original[1] or GameFontNormal:GetFont()
    local height = size > 0 and size or original[2]
    local flags = "OUTLINE"
    if preserveFlags then flags = original[3] end
    BaziUI.Typography.Apply(region, "ActionBars:Labels", font, height, flags, (fontKey or state.settings.font) == "general")
    if original.alpha ~= nil then region:SetAlpha(wanted and original.alpha or 0) end
end

local function maskSlot(button, inset, ...)
    if not button.CreateMaskTexture then return end
    local mask = button:CreateMaskTexture()
    mask:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    mask:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
    if mask.SetSnapToPixelGrid then mask:SetSnapToPixelGrid(false) end
    if mask.SetTexelSnappingBias then mask:SetTexelSnappingBias(0) end
    mask:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziActionSlotMask.tga")
    for _, texture in pairs({...}) do
        if texture.AddMaskTexture then texture:AddMaskTexture(mask) end
    end
end

local function decorateButton(button, state)
    if state.border then return end
    local slot = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    slot:SetAllPoints(button)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Background") then
        slot:SetAtlas("UI-HUD-ActionBar-IconFrame-Background", false)
    else
        slot:SetColorTexture(0.12, 0.09, 0.065, 0.88)
    end
    state.slot = slot
    if state.key == "pet" and not (button.SlotArt or button.SlotBackground) then
        -- SmallActionButtonTemplate may have no standalone slot art.
        local background = button:CreateTexture(nil, "BACKGROUND", nil, 0)
        background:SetAllPoints(button)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Background") then
            background:SetAtlas("UI-HUD-ActionBar-IconFrame-Background", false)
        else
            background:SetTexture("Interface\\Buttons\\UI-Quickslot")
        end
        background:Hide()
        state.petVanillaSlot = background
    end
    local border = CreateFrame("Frame", nil, button)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    border:SetFrameLevel(button:GetFrameLevel() + 2)
    border:EnableMouse(false)
    state.border = border
    if state.key:match("^bar%d+$") then
        maskSlot(button, 0.75, button.icon or button.Icon, button.SlotArt, button.SlotBackground, slot)
    else
        maskSlot(button, 0, slot, state.petVanillaSlot)
    end
    local active = button:CreateTexture(nil, "OVERLAY", nil, 5)
    local icon = button.icon or button.Icon or button
    active:SetAllPoints(icon)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Mouseover") then
        active:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", false)
    else
        active:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        active:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    end
    if button.commandName then
        active:ClearAllPoints()
        active:SetAllPoints(button)
        active:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziActionGold.tga")
        active:SetTexCoord(0, 1, 0, 1)
    end
    if button.commandName then
        active:SetDrawLayer("OVERLAY", 7)
        active:SetBlendMode("BLEND")
    else
        active:SetBlendMode("ADD")
    end
    if not button.commandName then active:SetVertexColor(1, 0.80, 0.18, 0.8) end
    active:Hide()
    state.active = active
    if state.key == "pet" or state.key == "stance" then
        local ok, proc = pcall(CreateFrame, "Frame", nil, button, "ActionButtonSpellAlertTemplate")
        if ok and proc and proc.ProcLoop then
            proc:SetPoint("CENTER", button, "CENTER")
            proc:SetSize(button:GetWidth() * 1.16, button:GetHeight() * 1.16)
            proc:SetAlpha(0.72)
            proc:SetFrameLevel(button:GetFrameLevel() + 4)
            proc:EnableMouse(false)
            proc:Hide()
            state.activeProc = proc
        end
    end
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame") then
        local nativeEdge
        if button.commandName then
            nativeEdge = button:CreateTexture(nil, "ARTWORK", nil, 4)
        else
            nativeEdge = border:CreateTexture(nil, "OVERLAY")
        end
        nativeEdge:SetAllPoints(button)
        nativeEdge:SetAtlas("UI-HUD-ActionBar-IconFrame", false)
        BaziUI.Theme:TrackBorderTexture(border, nativeEdge)
        if button.commandName and nativeEdge.SetSnapToPixelGrid and nativeEdge.SetTexelSnappingBias then
            for _, texture in pairs({nativeEdge, button.icon or button.Icon, button.SlotArt, button.SlotBackground, slot}) do
                if texture.SetSnapToPixelGrid and texture.SetTexelSnappingBias then
                    texture:SetSnapToPixelGrid(false)
                    texture:SetTexelSnappingBias(0)
                end
            end
        end
        state.nativeEdge = nativeEdge
    end
end

local function procAlert(button, state)
    local alert = button.SpellActivationAlert or button.spellAlert
    if not (alert and alert.GetAlpha and alert.SetAlpha) then return end
    if state.key == "pet" and alert.IsMouseEnabled and alert:IsMouseEnabled()
        and (not locked() or not alert:IsProtected()) then
        alert:EnableMouse(false)
    end
    if not state.settings.proc then
        if state.alert ~= alert then state.alert, state.alertAlpha = alert, alert:GetAlpha() end
        if alert:GetAlpha() ~= 0 then alert:SetAlpha(0) end
    elseif state.alert == alert then
        alert:SetAlpha(state.alertAlpha)
        state.alert, state.alertAlpha = nil, nil
    end
end

local function restoreStatus(state)
    if not state.statusIcon then return end
    local icon = state.statusIcon
    icon:SetVertexColor(unpack(state.statusBase))
    if icon.SetDesaturation then icon:SetDesaturation(state.statusGray or 0)
    elseif icon.SetDesaturated then icon:SetDesaturated(state.statusGray == 1) end
    state.statusIcon, state.statusBase, state.statusGray = nil, nil, nil
end

local function restoreIconPoints(state)
    if not state.insetIcon then return end
    state.insetIcon:ClearAllPoints()
    for _, point in ipairs(state.iconPoints) do state.insetIcon:SetPoint(unpack(point)) end
    state.insetIcon, state.iconPoints = nil, nil
end

local function restoreButton(state)
    state.settings = nil
    restoreIconPoints(state)
    if state.emptySlot then state.emptySlot:Hide() end
    if state.emptySlotEdge then state.emptySlotEdge:Hide() end
    if state.petVanillaSlot then state.petVanillaSlot:Hide() end
    if state.border then state.border:Hide(); state.slot:Hide(); state.active:Hide() end
    if state.nativeEdge then state.nativeEdge:Hide() end
    restoreStatus(state)
    if state.activeProc then state.activeProc.ProcLoop:Stop(); state.activeProc:Hide() end
    for region, original in pairs(state.texts) do
        BaziUI.Typography.Shadow(region)
        if original.alpha ~= nil then
            if original[1] then region:SetFont(original[1], original[2], original[3]) end
            region:SetAlpha(original.alpha)
        elseif original[1] then
            pcall(region.SetFont, region, original[1], original[2], original[3])
        end
    end
    for _, entry in pairs(state.cooldownColors or {}) do
        if entry.original then pcall(entry.text.SetTextColor, entry.text, unpack(entry.original)) end
    end
    state.cooldownColors = nil
    if state.alert then state.alert:SetAlpha(state.alertAlpha); state.alert, state.alertAlpha = nil, nil end
    if state.shine then state.shine:SetAlpha(state.shineAlpha); state.shine, state.shineAlpha = nil, nil end
    if state.checkedArt then
        state.checkedArt:SetAlpha(state.checkedAlpha)
        state.checkedArt, state.checkedAlpha = nil, nil
    end
    if state.normal then state.normal:SetAlpha(state.normalAlpha); state.normal, state.normalAlpha = nil, nil end
    for region, original in pairs(state.slotArt or {}) do
        region:SetShown(original.shown)
        region:SetAlpha(original.alpha)
    end
    state.slotArt = nil
    state.lastActive = nil
end

local function statusFor(button, settings, key, state)
    if key == "pet" and GetPetActionInfo and button.GetID then
        local id = button:GetID()
        local _, _, _, _, _, _, nameID, checksRange, inRange = GetPetActionInfo(id)
        if not readable(nameID) or not nameID then return end
        if settings.range and readable(checksRange) and checksRange and readable(inRange) and inRange == false then
            return "range"
        end
        local usable = GetPetActionSlotUsable and GetPetActionSlotUsable(id)
        if settings.unusable and readable(usable) and usable == false then return "unusable" end
        if settings.cooldown and GetPetActionCooldown then
            local start, duration = GetPetActionCooldown(id)
            if readable(start) and type(start) == "number" and start > 0
                and readable(duration) and type(duration) == "number" and duration > 2 then return "cooldown" end
        end
        return
    end
    local slot = button.action
    if not (readable(slot) and type(slot) == "number" and slot > 0) then return end
    local hasAPI = C_ActionBar and C_ActionBar.HasAction or HasAction
    local has = hasAPI and hasAPI(slot)
    if not (readable(has) and has) then return end
    local rangeAPI = C_ActionBar and C_ActionBar.IsActionInRange or IsActionInRange
    if settings.range then
        if state and state.rangeSlot == slot and state.outOfRange ~= nil then
            if state.outOfRange then return "range" end
        elseif rangeAPI then
            local ok, inRange = pcall(rangeAPI, slot)
            if ok and readable(inRange) and (inRange == false or inRange == 0) then return "range" end
        end
    end
    local usableAPI = C_ActionBar and C_ActionBar.IsUsableAction or IsUsableAction
    if usableAPI and (settings.mana or settings.unusable) then
        local ok, usable, mana = pcall(usableAPI, slot)
        if ok and readable(usable) and usable == false then
            if readable(mana) and mana then
                if settings.mana then return "mana" end
            elseif readable(mana) and settings.unusable then
                return "unusable"
            end
        end
    end
    if settings.cooldown and C_ActionBar and C_ActionBar.GetActionCooldown then
        local ok, cd = pcall(C_ActionBar.GetActionCooldown, slot)
        if ok and readable(cd) and cd and readable(cd.isActive) and cd.isActive then
            local gcd, remaining = cd.isOnGCD, cd.duration
            if readable(gcd) and (gcd == false
                or (gcd == nil and readable(remaining) and type(remaining) == "number" and remaining > 2)) then
                return "cooldown"
            end
        end
    end
end

local function paintStatus(button, state)
    local settings = state.settings
    if not settings or not button:IsVisible() then return end
    local kind = statusFor(button, settings, state.key, state)
    local color = kind and statusColors[kind]
    local icon = button.icon or button.Icon
    if state.statusIcon and state.statusIcon ~= icon then restoreStatus(state) end
    if not (icon and icon.GetVertexColor and color and settings.strength > 0) then
        restoreStatus(state)
        return
    end
    if not state.statusIcon then
        state.statusIcon = icon
        state.statusBase = {icon:GetVertexColor()}
        if icon.GetDesaturation then state.statusGray = icon:GetDesaturation()
        elseif icon.IsDesaturated then state.statusGray = icon:IsDesaturated() and 1 or 0 end
    end
    local strength = settings.strength / 100
    local r, g, b = 1 - strength * (1 - color[1]), 1 - strength * (1 - color[2]), 1 - strength * (1 - color[3])
    local oldR, oldG, oldB = icon:GetVertexColor()
    if oldR ~= r or oldG ~= g or oldB ~= b then icon:SetVertexColor(r, g, b, 1) end
    local gray = kind == "unusable" and strength * 0.45 or kind == "cooldown" and strength * 0.25 or 0
    if icon.SetDesaturation then
        if not icon.GetDesaturation or icon:GetDesaturation() ~= gray then icon:SetDesaturation(gray) end
    elseif icon.SetDesaturated then
        icon:SetDesaturated(gray >= 0.5)
    end
end

local function paintEmptySlot(button, state)
    local slot, settings = state.emptySlot, state.settings
    local edge = state.emptySlotEdge
    if edge then edge:Hide() end
    local showVanilla = state.key == "pet" and settings.vanillaBackground
    if not settings.empty and not showVanilla then slot:Hide(); return end
    if state.key == "pet" and state.emptyVanilla ~= settings.vanillaBackground then
        if settings.vanillaBackground then
            -- SlotArt is the textured empty tile. SlotBackground is only the underlay.
            local atlas = "ui-hud-actionbar-iconframe-slot"
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
                slot:SetAtlas(atlas, false)
            else
                slot:SetTexture("Interface\\Buttons\\UI-Quickslot")
            end
        else
            slot:SetColorTexture(0.12, 0.09, 0.065, 0.88)
        end
        state.emptyVanilla = settings.vanillaBackground
    end
    local hasAction
    if state.key == "pet" and GetPetActionInfo then
        local _, texture = GetPetActionInfo(state.index)
        if readable(texture) then hasAction = not not texture end
    elseif button.HasAction then
        hasAction = button:HasAction()
    end
    local limit = state.bar.numButtonsShowable
    local inLayout = state.key == "pet" or (readable(limit) and (type(limit) ~= "number" or state.index <= limit))
    if not inLayout or not readable(hasAction) or hasAction ~= false then slot:Hide(); return end

    local customLayout = state.key == "pet" and (settings.rows > 0 or settings.nativeSpacing ~= defaults.nativeSpacing)
    local anchor = not customLayout and button.container or button
    if anchor:GetNumPoints() > 0 and (customLayout or state.key ~= "pet" or not button.container or anchor:IsShown()) then
        if state.emptyAnchor ~= anchor then
            slot:ClearAllPoints()
            slot:SetAllPoints(anchor)
            state.emptyAnchor = anchor
        end
    elseif state.key == "pet" then
        -- A compact native bar can omit the anchors for its unused slots.
        local offset = 0
        for index = 1, state.index - 1 do
            local preceding = state.buttons[index]
            local container = preceding.container or preceding
            if container:GetNumPoints() == 0 or not container:IsShown() then offset = offset + 1 end
        end
        local size = button:GetWidth() * button:GetEffectiveScale() / state.bar:GetEffectiveScale()
        local padding = tonumber(state.bar.buttonPadding) or 2
        local vertical = state.bar.isHorizontal == false
        local distance = padding + offset * (size + padding)
        if state.emptyAnchor or state.emptySize ~= size or state.emptyDistance ~= distance or state.emptyVertical ~= vertical then
            slot:ClearAllPoints()
            slot:SetSize(size, size)
            if vertical then
                slot:SetPoint("TOP", state.bar, "BOTTOM", 0, -distance)
            else
                slot:SetPoint("LEFT", state.bar, "RIGHT", distance, 0)
            end
            state.emptyAnchor, state.emptySize, state.emptyDistance, state.emptyVertical = nil, size, distance, vertical
        end
    else
        slot:Hide()
        return
    end
    slot:Show()
    if edge then edge:SetShown(showVanilla == true and settings.border) end
end

local function paintCooldownColor(cooldown, button, state, isCharge)
    if not (cooldown and cooldown.GetCountdownFontString) then return end
    local entry = state.cooldownColors and state.cooldownColors[cooldown]
    if not cooldown:IsShown() or (cooldown.GetHideCountdownNumbers and cooldown:GetHideCountdownNumbers()) then
        if entry and entry.lastColor ~= cooldownWhite and pcall(entry.text.SetTextColor, entry.text, unpack(cooldownWhite)) then
            entry.lastColor = cooldownWhite
        end
        return
    end
    if not entry then
        local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
        if not ok or not text or (text.IsForbidden and text:IsForbidden()) then return end
        local readableColor, r, g, b, a = pcall(text.GetTextColor, text)
        entry = {text=text}
        if readableColor and readable(r) and readable(g) and readable(b) and readable(a) then entry.original = {r, g, b, a} end
        state.cooldownColors = state.cooldownColors or {}
        state.cooldownColors[cooldown] = entry
    end
    if not entry.text:IsShown() then return end

    local color = cooldownWhite
    local slot = button.action
    local hasSlot = readable(slot) and type(slot) == "number" and slot > 0
    local onGCD
    if not isCharge and hasSlot and C_ActionBar and C_ActionBar.GetActionCooldown then
        local ok, info = pcall(C_ActionBar.GetActionCooldown, slot)
        if ok and readable(info) and info and readable(info.isOnGCD) then onGCD = info.isOnGCD end
    end
    local hasTimes
    if cooldown.GetCooldownTimes then
        local ok, start, duration = pcall(cooldown.GetCooldownTimes, cooldown)
        if ok and readable(start) and readable(duration) and type(start) == "number" and type(duration) == "number" then
            hasTimes = true
            local elapsed = GetTime() - start / 1000
            local remaining = duration / 1000 - elapsed
            if elapsed >= 0.2 and (isCharge or onGCD == false or (onGCD == nil and duration > 1500)) then
                color = M.GetCountdownColor(remaining)
            end
        end
    end
    local getter = C_ActionBar and (isCharge and C_ActionBar.GetActionChargeDuration or not isCharge and C_ActionBar.GetActionCooldownDuration)
    if not hasTimes and not onGCD and cooldownColorCurve and getter and hasSlot then
        local ok, duration
        if isCharge then ok, duration = pcall(getter, slot)
        else ok, duration = pcall(getter, slot, true) end
        if ok and readable(duration) and duration and duration.EvaluateRemainingDuration then
            local evaluated, applied = pcall(function()
                local tint = duration:EvaluateRemainingDuration(cooldownColorCurve)
                if not tint then return false end
                entry.text:SetTextColor(tint:GetRGB())
                return true
            end)
            if evaluated and applied then entry.lastColor = nil; return end
        end
    end
    if color ~= entry.lastColor and pcall(entry.text.SetTextColor, entry.text, unpack(color)) then
        entry.lastColor = color
    end
end

local function ownedActionActive(button)
    local action = button.action
    if not readable(action) or type(action) ~= "number" or action <= 0 then return false end
    local isCurrentAction = C_ActionBar and C_ActionBar.IsCurrentAction
    if IsCurrentAction and IsCurrentAction ~= isCurrentAction then
        local current = IsCurrentAction(action)
        if readable(current) and (current == true or current == 1) then return true end
    end
    if isCurrentAction then
        local current = isCurrentAction(action)
        if readable(current) and current == true then return true end
    end
    local isCurrentSpell = C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
    if not (isCurrentSpell and button.GetSpellId) then return false end
    local ok, spell = pcall(button.GetSpellId, button)
    if not ok or not readable(spell) or type(spell) ~= "number" or spell <= 0 then return false end
    local valid, current = pcall(isCurrentSpell, spell)
    if valid and readable(current) and current == true then return true end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
    if not readable(name) or type(name) ~= "string" then return false end
    local found, byName = pcall(isCurrentSpell, name)
    return found and readable(byName) and byName == true
end

function M:ProbeQueuedAction()
    local button
    for _, candidate in ipairs(activeButtons) do
        if candidate.commandName and candidate:IsMouseOver() then button = candidate; break end
    end
    if not button then
        addon:Print("Hover a Bazi action button and run /bazi swingprobe.")
        return
    end
    if self.swingProbe then self.swingProbe:Cancel() end
    local last
    local function describe(value)
        return readable(value) and tostring(value) or "restricted"
    end
    addon:Print("Swing probe active for 8 seconds.")
    self.swingProbe = C_Timer.NewTicker(0.08, function()
        local action = button.action
        if not readable(action) or type(action) ~= "number" or action <= 0 then return end
        local ok, spell = pcall(button.GetSpellId, button)
        if not ok or not readable(spell) then spell = nil end
        local name = spell and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
        local current = C_ActionBar and C_ActionBar.IsCurrentAction and C_ActionBar.IsCurrentAction(action)
        local legacy = IsCurrentAction and IsCurrentAction(action)
        local isCurrentSpell = C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
        local _, spellCurrent = pcall(isCurrentSpell, spell)
        local _, nameCurrent = pcall(isCurrentSpell, name)
        local state = buttonStates[button]
        local message = ("%s [%s], slot %d, current %s, legacy %s, spell %s, name %s, checked %s, glow %s"):format(
            describe(name), describe(spell), action, describe(current), describe(legacy),
            describe(spellCurrent), describe(nameCurrent), describe(button:GetChecked()),
            describe(state and state.active:IsShown()))
        if message ~= last then addon:Print(message); last = message end
    end, 100)
end

local function paintActive(button, state)
    local settings = state.settings
    local autocast = false
    if state.key == "pet" then
        local overlay = button.AutoCastOverlay
        local shine = (overlay and overlay.Shine) or button.AutoCastShine
        local enabled
        if GetPetActionInfo and button.GetID then
            local _, _, _, _, _, value = GetPetActionInfo(state.index or button:GetID())
            enabled = value
        end
        if readable(enabled) and (enabled == true or enabled == 1) then autocast = true
        elseif shine and shine:IsShown() then autocast = overlay == nil or overlay:IsShown() end
        if shine and settings.active and autocast then
            if state.shine ~= shine then state.shine, state.shineAlpha = shine, shine:GetAlpha() end
            if shine:GetAlpha() ~= 0 then shine:SetAlpha(0) end
        elseif state.shine then
            state.shine:SetAlpha(state.shineAlpha)
            state.shine, state.shineAlpha = nil, nil
        end
    end
    local checked = button.GetChecked and button:GetChecked()
    local form = state.key == "stance" and GetShapeshiftForm and GetShapeshiftForm()
    local checkedActive = readable(checked) and checked == true
    if readable(form) and type(form) == "number" then checkedActive = form > 0 and form == state.index end
    local proc = state.activeProc
    local showProc = settings.active and proc and (autocast or (state.key == "stance" and checkedActive))
    local queued = settings.active and button.commandName and ownedActionActive(button)
    local active = settings.active and not showProc and (autocast or queued or checkedActive)
    if state.lastActive ~= active then
        state.active:SetShown(active)
        state.lastActive = active
    end
    if proc then
        if showProc and not proc:IsShown() then proc:Show(); proc.ProcLoop:Play()
        elseif not showProc and proc:IsShown() then proc.ProcLoop:Stop(); proc:Hide() end
    end
    local checkedArt = (showProc or active) and button.GetCheckedTexture and button:GetCheckedTexture()
    if checkedArt then
        if not state.checkedArt then state.checkedArt, state.checkedAlpha = checkedArt, checkedArt:GetAlpha() end
        if checkedArt:GetAlpha() ~= 0 then checkedArt:SetAlpha(0) end
    elseif state.checkedArt then
        state.checkedArt:SetAlpha(state.checkedAlpha)
        state.checkedArt, state.checkedAlpha = nil, nil
    end
end

local function paintButton(button, state)
    if not state.settings then return end
    if state.emptySlot then paintEmptySlot(button, state) end
    if not button:IsVisible() then return end
    paintCooldownColor(button.cooldown or button.Cooldown, button, state, false)
    paintCooldownColor(button.chargeCooldown, button, state, true)
    paintStatus(button, state)
    paintActive(button, state)
    procAlert(button, state)
end

local function applyButtonArt(button, state)
    local settings = state.settings
    local icon = button.commandName and (button.icon or button.Icon)
    if state.insetIcon and (state.insetIcon ~= icon or not settings.border) then restoreIconPoints(state) end
    if icon and settings.border and not state.insetIcon then
        state.insetIcon, state.iconPoints = icon, {}
        for i = 1, icon:GetNumPoints() do state.iconPoints[i] = {icon:GetPoint(i)} end
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1.5, -1.5)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1.5, 1.5)
    end
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal and (not normal.IsForbidden or not normal:IsForbidden()) then
        if state.normal ~= normal then
            if state.normal then state.normal:SetAlpha(state.normalAlpha) end
            state.normal, state.normalAlpha = normal, normal:GetAlpha()
        end
        normal:SetAlpha(settings.border and not state.nativeEdge and state.normalAlpha or 0)
    end
    state.border:SetShown(settings.border)
    if state.nativeEdge then state.nativeEdge:SetShown(settings.border) end
    state.slot:SetShown(settings.slotTint)
    if state.petVanillaSlot then state.petVanillaSlot:SetShown(settings.vanillaBackground) end
    local slotArt, slotBackground = button.SlotArt, button.SlotBackground
    if slotArt or slotBackground then
        state.slotArt = state.slotArt or {}
        for _, region in pairs({art = slotArt, background = slotBackground}) do
            if not state.slotArt[region] then
                state.slotArt[region] = {shown = region:IsShown(), alpha = region:GetAlpha()}
            end
            local show = settings.vanillaBackground and region == (slotArt or slotBackground)
            region:SetAlpha(show and 1 or 0)
            if show then region:Show() end
        end
    end
end

local queuedButtonUpdates = {}

local function queueButtonUpdate(button, state, update)
    if not state.settings then return end
    local pending = queuedButtonUpdates[update]
    if not pending then
        pending = {}
        queuedButtonUpdates[update] = pending
        C_Timer.After(0, function()
            queuedButtonUpdates[update] = nil
            for pendingButton, pendingState in pairs(pending) do
                if pendingState.settings then update(pendingButton, pendingState) end
            end
        end)
    end
    pending[button] = state
end

local function refreshButton(button, state)
    local settings = state.settings
    decorateButton(button, state)
    if (settings.empty or (state.key == "pet" and settings.vanillaBackground)) and not state.emptySlot
        and (state.key == "pet" or (button.container and state.key:match("^bar%d+$"))) then
        -- The container can be hidden by Edit Mode even when it has a slot anchor.
        local slot = state.bar:CreateTexture(nil, "ARTWORK")
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Background") then
            slot:SetAtlas("UI-HUD-ActionBar-IconFrame-Background", false)
        else
            slot:SetColorTexture(0.12, 0.09, 0.065, 0.88)
        end
        state.emptySlot = slot
        if state.key == "pet" then
            local edge = state.bar:CreateTexture(nil, "OVERLAY")
            edge:SetAllPoints(slot)
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame") then
                edge:SetAtlas("UI-HUD-ActionBar-IconFrame", false)
            else
                edge:SetTexture("Interface\\Buttons\\UI-Quickslot")
            end
            edge:Hide()
            state.emptySlotEdge = edge
        end
    end
    applyButtonArt(button, state)
    if not state.artHook and button.UpdateButtonArt and hooksecurefunc then
        hooksecurefunc(button, "UpdateButtonArt", function(self)
            queueButtonUpdate(self, state, applyButtonArt)
        end)
        state.artHook = true
    end
    local overlay = state.key == "pet" and button.AutoCastOverlay
    if overlay and overlay.UpdateShineAnim and state.autoHook ~= overlay and hooksecurefunc then
        hooksecurefunc(overlay, "UpdateShineAnim", function()
            queueButtonUpdate(button, state, paintButton)
        end)
        state.autoHook = overlay
    end
    fontString(state, button.HotKey or button.hotkey, settings.hotkeys, settings.textSize)
    fontString(state, button.Name or button.nameText, settings.macro, settings.textSize)
    fontString(state, button.Count or button.count, true, settings.textSize)
    if settings.cooldownSize > 0 or settings.cooldownFont ~= "general" or state.cooldownStyled then
        for _, cooldown in pairs({button.cooldown or button.Cooldown, button.chargeCooldown}) do
            if cooldown.GetCountdownFontString then
                local ok, countdown = pcall(cooldown.GetCountdownFontString, cooldown)
                if ok and countdown and pcall(fontString, state, countdown, true, settings.cooldownSize, settings.cooldownFont, true) then
                    state.cooldownStyled = true
                end
            end
        end
    end
    paintButton(button, state)
end

local function updateStatusTicker()
    if #activeButtons == 0 then
        if statusTicker then statusTicker:Cancel(); statusTicker = nil end
        return
    end
    if statusTicker or not (C_Timer and C_Timer.NewTicker) then return end
    statusIndex = 0
    statusTicker = C_Timer.NewTicker(0.075, function()
        local count = #activeButtons
        if count == 0 then return end
        for _ = 1, math.min(count, 12) do
            statusIndex = statusIndex % count + 1
            local button = activeButtons[statusIndex]
            paintButton(button, buttonStates[button])
        end
    end)
end

local function applyGryphons(show)
    local bar = getFrame(M.bars[1])
    if not bar then return end
    local caps = bar.EndCaps
    if not caps then return end
    if not show then
        if capsStates[caps] == nil then capsStates[caps] = caps:GetAlpha() end
        caps:SetAlpha(0)
    elseif capsStates[caps] ~= nil then
        caps:SetAlpha(capsStates[caps])
        capsStates[caps] = nil
    end
end

local function applyAccessoryBackground(frame, hide)
    local original = accessoryArt[frame]
    if not hide then
        if original then
            for region, alpha in pairs(original) do region:SetAlpha(alpha) end
            accessoryArt[frame] = nil
        end
        return
    end
    if not original then original = {}; accessoryArt[frame] = original end
    local function HideArt(region)
        if not region then return end
        if original[region] == nil then original[region] = region:GetAlpha() end
        region:SetAlpha(0)
    end
    HideArt(frame.BackgroundArt)
    HideArt(frame.BorderArt)
    for _, pool in ipairs({frame.HorizontalDividersPool or false, frame.VerticalDividersPool or false}) do
        if pool then for divider in pool:EnumerateActive() do HideArt(divider) end end
    end
    if not accessoryHooks[frame] and hooksecurefunc and frame.UpdateDividers then
        hooksecurefunc(frame, "UpdateDividers", function(self)
            if accessoryArt[self] then applyAccessoryBackground(self, true) end
        end)
        accessoryHooks[frame] = true
    end
end

function M:Apply()
    if locked() then pendingLayout = true; return end
    pendingLayout = false
    local db = self:Settings()
    if self.ApplyExperience then
        local ok, err = pcall(self.ApplyExperience, self, db.experience)
        if not ok and self.experienceError ~= err then addon:Print("Experience bar: " .. tostring(err)) end
        self.experienceError = not ok and err or nil
    end
    syncEditControls(db.enabled)
    if not db.enabled then self:DisableOwnedBars() end
    wipe(activeButtons)
    if not db.enabled then
        for _, state in pairs(nativeShadows) do
            state.enabled, state.hasBounds = false, false
            state.shadow:RefreshVisibility()
        end
        for frame in pairs(accessoryArt) do applyAccessoryBackground(frame, false) end
        for frame in pairs(frameStates) do applyLayout(frame, defaults, false) end
        for _, state in pairs(buttonStates) do
            if state.settings then restoreButton(state) end
        end
        applyGryphons(true)
        updateStatusTicker()
        return
    end
    for _, def in ipairs(self.bars) do
        local frame = getFrame(def)
        if frame and not (frame.IsForbidden and frame:IsForbidden()) then
            local settings = db.bars[def.key]
            local number = tonumber(def.key:match("^bar(%d+)$"))
            local buttons
            if number then
                if frameStates[frame] then applyLayout(frame, defaults, false) end
                buttons = self:ConfigureOwnedBar(number, settings)
                self:SuspendNativeBar(frame)
            else
                enableNativeBar(def, settings)
                applyLayout(frame, settings, true, def)
                if def.key == "pet" then watchPetLayout(frame, def) end
                if def.key == "pet" or def.key == "stance" or def.key == "possess" then
                    self:SuppressEditSelection(frame, function() return self:Settings().enabled end)
                end
                buttons = getButtons(def, frame)
                if def.prefix then updateNativeShadow(frame, buttons, settings.visible) end
            end
            if def.key == "micro" or def.key == "bags" then
                local holder = def.key == "micro" and (_G.MicroMenu or frame) or frame
                applyAccessoryBackground(holder, not settings.vanillaBackground)
            end
            for index, button in ipairs(buttons) do
                local state = buttonStates[button]
                if not state then state = {texts={}, key=def.key}; buttonStates[button] = state end
                state.settings, state.index, state.bar, state.buttons = settings, index, frame, buttons
                refreshButton(button, state)
                if settings.visible then activeButtons[#activeButtons + 1] = button end
            end
        end
    end
    applyGryphons(db.gryphons)
    updateStatusTicker()
end

local learned = {}
local rankScheduled, rankRunning
local function rankFor(spell)
    local subtext = C_Spell.GetSpellSubtext(spell)
    return readable(subtext) and type(subtext) == "string" and tonumber(subtext:match("(%d+)")) or nil
end

local function addRank(group, rank, id)
    if not group.bestRank or rank > group.bestRank then group.bestRank, group.bestSpell = rank, id end
    if not group.firstRank or rank < group.firstRank then group.firstRank = rank end
end

local function spellBookRanks(groups)
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skill = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if skill and not skill.offSpecID then
            for offset = 1, skill.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(skill.itemIndexOffset + offset, bank)
                local id = item and item.spellID
                local group = id and groups[C_Spell.GetSpellName(id)]
                if group and not learned[id] and C_SpellBook.IsSpellKnown(id, bank) then
                    local rank = rankFor(id)
                    if rank and rank < group.bestRank and (not group.previous or rank > group.previous) then group.previous = rank end
                end
            end
        end
    end
end

local function applyRanks()
    if rankRunning then return end
    rankScheduled = false
    local db = M:Settings()
    if not db.enabled or not db.autoRanks then wipe(learned); return end
    if not next(learned) or locked() then return end
    if GetCursorInfo() then return end
    if not (C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellName and C_Spell.PickupSpell
        and C_SpellBook and C_SpellBook.GetSpellBookItemInfo and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.IsSpellKnown
        and Enum and Enum.SpellBookSpellBank) then wipe(learned); return end
    local groups = {}
    for id in pairs(learned) do
        local name, rank = C_Spell.GetSpellName(id), rankFor(id)
        if name and rank then
            groups[name] = groups[name] or {}
            addRank(groups[name], rank, id)
        end
    end
    if next(groups) then
        spellBookRanks(groups)
        rankRunning = true
        for slot = 1, 180 do
            local kind, id = GetActionInfo(slot)
            local group = kind == "spell" and id and groups[C_Spell.GetSpellName(id)]
            local previous = group and math.max(group.previous or 0, group.firstRank - 1)
            if previous and previous > 0 and rankFor(id) == previous then
                local ok = pcall(C_Spell.PickupSpell, group.bestSpell)
                if ok and GetCursorInfo() == "spell" then
                    pcall(PlaceAction, slot)
                    ClearCursor()
                end
            end
        end
    end
    wipe(learned)
    rankRunning = false
end

local keybindWindow, pendingBindingRestore
local function createKeybindWindow()
    local window = addon.Theme:RoundedCard(UIParent)
    window:SetSize(402, 160)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    window:SetFrameStrata("DIALOG")
    window:SetBackdropColor(0.08, 0.06, 0.07, 0.98)
    addon.Theme:PaintWindowEdge(window)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -13)
    title:SetText("Bazi UI — Quick Keybind")
    local instructions = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    instructions:SetPoint("TOPLEFT", 15, -39)
    instructions:SetPoint("TOPRIGHT", -15, -39)
    instructions:SetText("Hover an action slot and press a key. Escape clears its primary binding.")
    local scope = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    scope:SetPoint("TOP", instructions, "BOTTOM", 0, -7)
    local output = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    output:SetPoint("TOP", scope, "BOTTOM", 0, -7)
    window.tooltip = CreateFrame("GameTooltip", "BaziUIQuickKeybindTooltip", UIParent, "GameTooltipTemplate")
    window.tooltip:SetFrameStrata("TOOLTIP")
    function window:SetOutputText(message) output:SetText(message) end
    function window:SetSelected(command, button)
        self.mouseOverButton = button
        output:SetText(command and (GetBindingName(command) or command) or "")
    end
    function window:HandleBindingInput(key)
        local handled, changed = M:BindHoveredOwnedButton(self, key)
        self.changed = self.changed or changed
        if not handled and key == "ESCAPE" then self:Hide() end
    end
    local save = addon.Theme:CreateButton(window, SAVE or "Save", 110, 28)
    save:SetPoint("BOTTOMRIGHT", window, "BOTTOM", -6, 13)
    save:SetScript("OnClick", function()
        if locked() then return end
        if window.changed then SaveBindings(window.bindingSet) end
        window.changed = nil
        window:Hide()
    end)
    local cancel = addon.Theme:CreateButton(window, CANCEL or "Cancel", 110, 28)
    cancel:SetPoint("BOTTOMLEFT", window, "BOTTOM", 6, 13)
    cancel:SetScript("OnClick", function() window:Hide() end)
    window:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    window:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    window:SetScript("OnKeyDown", function(self, key)
        M:UpdateOwnedBindingHover(self)
        self:HandleBindingInput(key)
    end)
    window:SetScript("OnShow", function(self)
        self.bindingSet = GetCurrentBindingSet()
        local character = Enum and Enum.BindingSet and Enum.BindingSet.Character or 2
        scope:SetText(self.bindingSet == character and "Character-specific bindings" or "Account-wide bindings")
        output:SetText(nil)
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        M:SetOwnedBindingMode(true, self)
        if GameTooltip and not GameTooltip:IsForbidden() then GameTooltip:Hide() end
    end)
    local elapsedSinceHover = 0
    window:SetScript("OnUpdate", function(self, elapsed)
        elapsedSinceHover = elapsedSinceHover + elapsed
        if elapsedSinceHover < 0.03 then return end
        elapsedSinceHover = 0
        M:UpdateOwnedBindingHover(self)
    end)
    window:SetScript("OnHide", function(self)
        self:EnableKeyboard(false)
        self:StopMovingOrSizing()
        if self.changed then
            if locked() then pendingBindingRestore = self.bindingSet else LoadBindings(self.bindingSet) end
        end
        self.changed = nil
        M:SetOwnedBindingMode(false)
        self.tooltip:Hide()
    end)
    window:Hide()
    return window
end

local function openQuickKeybind()
    if locked() then addon:Print("Quick Keybind is available after combat."); return end
    if not M:Settings().enabled then
        if not QuickKeybindFrame and C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_QuickKeybind")
        end
        if QuickKeybindFrame then QuickKeybindFrame:Show() end
        return
    end
    if not keybindWindow then keybindWindow = createKeybindWindow() end
    if BaziUIOptionsFrame then BaziUIOptionsFrame:Hide() end
    keybindWindow:Show()
end

local function registerQuickKeybind()
    local available = true
    for key, command in pairs(_G) do
        if type(key) == "string" and key:sub(1, 6) == "SLASH_"
            and type(command) == "string" and command:lower() == "/kb" then
            available = false
            break
        end
    end
    SLASH_BAZIQUICKBIND1 = "/bazikb"
    if available then SLASH_BAZIQUICKBIND2 = "/kb" end
    SlashCmdList.BAZIQUICKBIND = openQuickKeybind
end

function M:Initialize()
    if events then return end
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
        cooldownColorCurve = C_CurveUtil.CreateColorCurve()
        cooldownColorCurve:SetType(Enum.LuaCurveType.Step)
        cooldownColorCurve:AddPoint(0, CreateColor(unpack(cooldownWhite)))
        cooldownColorCurve:AddPoint(0.01, CreateColor(unpack(cooldownOrange)))
        cooldownColorCurve:AddPoint(2, CreateColor(unpack(cooldownYellow)))
        cooldownColorCurve:AddPoint(5, CreateColor(unpack(cooldownWhite)))
    end
    hiddenParent = CreateFrame("Frame", nil, UIParent)
    hiddenParent:Hide()
    events = CreateFrame("Frame")
    local talentAlert = _G.TalentMicroButtonAlert
    if talentAlert then
        local function placeTalentAlert(alert)
            local dock = _G.ChatAlertFrame or _G.GENERAL_CHAT_DOCK or _G.DEFAULT_CHAT_FRAME
            if not dock then return end
            if alert.Arrow then alert.Arrow:Hide() end
            alert:ClearAllPoints()
            local toast = _G.BNToastFrame
            local point, relative, side, x, y
            if toast then point, relative, side, x, y = toast:GetPoint(1) end
            if toast and toast:IsShown() then
                alert:SetPoint("BOTTOMLEFT", toast, "TOPLEFT", 0, 5)
            elseif point and relative then
                alert:SetPoint(point, relative, side, x, y)
            else
                alert:SetPoint("BOTTOMLEFT", dock, "TOPLEFT", 0, 10)
            end
        end
        talentAlert:HookScript("OnShow", placeTalentAlert)
        local toast = _G.BNToastFrame
        if toast then
            local function updateShownAlert()
                if talentAlert:IsShown() then placeTalentAlert(talentAlert) end
            end
            toast:HookScript("OnShow", updateShownAlert)
            toast:HookScript("OnHide", updateShownAlert)
        end
        if talentAlert:IsShown() then placeTalentAlert(talentAlert) end
    end
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_PET", "UPDATE_EDIT_MODE_LAYOUTS", "EDIT_MODE_LAYOUTS_UPDATED",
        "CURSOR_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SETTINGS_LOADED", "UPDATE_BINDINGS",
        "CURRENT_SPELL_CAST_CHANGED", "ACTIONBAR_UPDATE_STATE", "UPDATE_SHAPESHIFT_FORM"}) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, arg)
        if event == "UPDATE_SHAPESHIFT_FORM" then
            for _, button in ipairs(activeButtons) do
                local state = buttonStates[button]
                if state.key == "stance" and button:IsVisible() then queueButtonUpdate(button, state, paintActive) end
            end
        elseif event == "CURRENT_SPELL_CAST_CHANGED" or event == "ACTIONBAR_UPDATE_STATE" then
            for _, button in ipairs(activeButtons) do
                if button.commandName and button:IsVisible() then
                    queueButtonUpdate(button, buttonStates[button], paintActive)
                end
            end
        elseif event == "UPDATE_BINDINGS" then
            self:RefreshOwnedBindings()
        elseif event == "LEARNED_SPELL_IN_SKILL_LINE" then
            local db = self:Settings()
            if db.enabled and db.autoRanks and type(arg) == "number" then
                learned[arg] = true
                if not rankScheduled and C_Timer and C_Timer.After then
                    rankScheduled = true
                    C_Timer.After(0.25, applyRanks)
                end
            end
        elseif event == "CURSOR_CHANGED" then
            if not rankScheduled and next(learned) then applyRanks() end
        elseif event == "PLAYER_REGEN_DISABLED" then
            if keybindWindow and keybindWindow:IsShown() then keybindWindow:Hide() end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingBindingRestore then
                LoadBindings(pendingBindingRestore)
                pendingBindingRestore = nil
            end
            if pendingLayout then self:Apply() end
            self:RefreshOwnedBindings()
            if next(learned) then applyRanks() end
        elseif event == "UPDATE_EDIT_MODE_LAYOUTS" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
            if self:Settings().enabled then
                if C_Timer and C_Timer.After then C_Timer.After(0, function() self:Apply() end)
                else self:Apply() end
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "SETTINGS_LOADED" or event == "UNIT_PET" and arg == "player" then
            self:Apply()
        end
    end)
    if hooksecurefunc and ActionButton_ShowOverlayGlow then
        hooksecurefunc("ActionButton_ShowOverlayGlow", function(button)
            local state = buttonStates[button]
            if state then queueButtonUpdate(button, state, procAlert) end
        end)
    end
    if hooksecurefunc and ActionButton_UpdateRangeIndicator then
        hooksecurefunc("ActionButton_UpdateRangeIndicator", function(button, checksRange, inRange)
            local state = buttonStates[button]
            if not state or not state.settings then return end
            local slot = button.action
            if readable(slot) and type(slot) == "number" and readable(checksRange) and readable(inRange) then
                state.rangeSlot = slot
                state.outOfRange = checksRange == true and inRange == false
            else
                state.rangeSlot, state.outOfRange = nil, nil
            end
            queueButtonUpdate(button, state, paintStatus)
        end)
    end
    registerQuickKeybind()
    self:Apply()
end
