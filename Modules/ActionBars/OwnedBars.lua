local module = BaziUI.ActionBars

local pages = {1, 6, 5, 3, 4, 13, 14, 15}
local bars = {}
function module.GetOwnedMoverFrame(index) return bars[index] end
local nativeParents = {}
local nativeHolder
local bindingMode = false
local bindingSelection, bindingFrame
local normalMode = "[vehicleui][overridebar][possessbar][petbattle] special; normal"

local function bindingCommand(number, index)
    if number == 1 then return "ACTIONBUTTON" .. index end
    return "MULTIACTIONBAR" .. (number - 1) .. "BUTTON" .. index
end

local function assignBindings(bar)
    local slots = bar:GetAttribute("buttonCount")
    for index = 1, #bar.buttons do
        local first, second = GetBindingKey(bindingCommand(bar.number, index))
        bar:SetAttribute("firstKey" .. index, index <= slots and first or nil)
        bar:SetAttribute("secondKey" .. index, index <= slots and second or nil)
    end
    bar:Execute([[ self:RunAttribute("ApplyBindings") ]])
end

local function centerPressArt(button)
    local pushed = button:GetPushedTexture()
    if pushed then
        pushed:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziActionGold.tga")
        pushed:SetTexCoord(0, 1, 0, 1)
        pushed:SetDrawLayer("OVERLAY", 6)
        pushed:SetBlendMode("BLEND")
    end
    for _, texture in pairs({button:GetPushedTexture(), button:GetHighlightTexture(), button:GetCheckedTexture()}) do
        texture:ClearAllPoints()
        texture:SetAllPoints(button)
    end
end

local function selectOwnedBinding(frame, button)
    local previous = bindingSelection
    if previous ~= button then
        if previous then previous.baziBindingTarget.mark:SetAlpha(0.5) end
        bindingSelection = button
    end
    if button then
        if frame.mouseOverButton ~= button then
            frame:SetSelected(button.commandName, button)
            button:ShowBindingTooltip()
        end
        if previous ~= button then button.baziBindingTarget.mark:SetAlpha(1) end
    elseif previous and frame.mouseOverButton == previous then
        frame:SetSelected(nil, nil)
        frame.tooltip:Hide()
    end
end

local modifierKeys = {LSHIFT=true, RSHIFT=true, SHIFT=true, LCTRL=true, RCTRL=true, CTRL=true,
    LALT=true, RALT=true, ALT=true, LMETA=true, RMETA=true}
local mouseKeys = {MiddleButton="BUTTON3", Button4="BUTTON4", Button5="BUTTON5"}

function module:BindHoveredOwnedButton(frame, input)
    if not bindingMode or InCombatLockdown() or not SetBinding or type(input) ~= "string" then return false end
    local button = bindingSelection
    if not button then return false end
    if modifierKeys[input] or input == "UNKNOWN" then return true end

    local command = button.commandName
    local primary, secondary = GetBindingKey(command)
    local changed
    if input == "ESCAPE" then
        changed = primary and SetBinding(primary)
    else
        local key = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
            .. (IsShiftKeyDown() and "SHIFT-" or "") .. (mouseKeys[input] or input:upper())
        if key == primary then return true end
        if primary and not SetBinding(primary) then
            frame:SetOutputText("Could not replace the current binding.")
            return true
        end
        changed = key == secondary or SetBinding(key, command)
        if not changed and primary then SetBinding(primary, command) end
    end
    if changed then
        frame:SetOutputText(input == "ESCAPE" and (NOT_BOUND or "Not bound") or (KEY_BOUND or "Key bound"))
        button:ShowBindingTooltip()
    elseif input ~= "ESCAPE" then
        frame:SetOutputText("Could not bind this key.")
    end
    return true, changed
end

function module:UpdateOwnedBindingHover(frame)
    if not bindingMode or InCombatLockdown() then return end
    local candidate, level
    if not frame:IsMouseOver() then
        local cursorX, cursorY = GetCursorPosition()
        -- A separate frame can swallow mouse motion over the bar. Use the
        -- visible slot bounds so keyboard binding still follows the cursor.
        for _, bar in pairs(bars) do
            if bar:IsVisible() then
                local scale = bar:GetEffectiveScale()
                local x, y = cursorX / scale, cursorY / scale
                for _, button in ipairs(bar.buttons) do
                    local target = button.baziBindingTarget
                    if target:IsShown() then
                        local ok, left, bottom, width, height = pcall(target.GetRect, target)
                        if ok and left and x >= left and x < left + width and y >= bottom and y < bottom + height then
                            local priority = target:GetFrameLevel()
                            if not level or priority > level then candidate, level = button, priority end
                        end
                    end
                end
            end
        end
    end
    selectOwnedBinding(frame, candidate)
end

local function createBar(number)
    local library = LibStub("LibActionButton-1.0")
    local bar = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    module:CreateBarShadow(bar)
    bar:Hide()
    bar.number, bar.buttons = number, {}
    bar:SetAttribute("buttonCount", 12)
    bar:SetAttribute("ApplyBindings", [[
        self:ClearBindings()
        if self:GetAttribute("state-mode") ~= "normal" or not self:GetAttribute("enabled")
            or self:GetAttribute("bindingMode") then return end
        for index = 1, self:GetAttribute("buttonCount") do
            local buttonName = self:GetFrameRef("button" .. index):GetName()
            local first = self:GetAttribute("firstKey" .. index)
            local second = self:GetAttribute("secondKey" .. index)
            if first then self:SetBindingClick(false, first, buttonName, "Keybind") end
            if second then self:SetBindingClick(false, second, buttonName, "Keybind") end
        end
    ]])
    bar:SetAttribute("ApplyVisibility", [[
        if self:GetAttribute("state-mode") == "normal" and self:GetAttribute("enabled") then
            self:Show()
        else
            self:Hide()
        end
        self:RunAttribute("ApplyBindings")
    ]])
    bar:SetAttribute("_onstate-mode", [[ self:RunAttribute("ApplyVisibility") ]])
    bar:SetAttribute("_onstate-page", [[ self:ChildUpdate("state", newstate) ]])

    for index = 1, 12 do
        local command = bindingCommand(number, index)
        local button = library:CreateButton(index, "BaziActionBar" .. number .. "Button" .. index, bar, {
            keyBoundTarget = command,
            clickOnDown = GetCVarBool("ActionButtonUseKeyDown"),
            spellCastVFX = false,
        })
        button.commandName = command
        centerPressArt(button)
        function button:ShowBindingTooltip()
            if not bindingFrame then return end
            local tooltip = bindingFrame.tooltip
            tooltip:SetOwner(self.baziBindingTarget, "ANCHOR_TOP")
            tooltip:SetText(GetBindingName(self.commandName) or self.commandName)
            local key = GetBindingKey(self.commandName)
            tooltip:AddLine(key or NOT_BOUND or "Not bound", 1, 0.82, 0.49)
            tooltip:AddLine(key and (ESCAPE_TO_UNBIND or "Escape to unbind")
                or (PRESS_KEY_TO_BIND or "Press a key to bind"), 1, 1, 1)
            tooltip:Show()
        end
        -- LibActionButton can make an empty slot fully transparent.
        local target = CreateFrame("Button", nil, bar)
        target:SetAllPoints(button)
        target:SetFrameStrata("DIALOG")
        target:SetFrameLevel(button:GetFrameLevel() + 8)
        target:EnableMouse(true)
        local highlight = target:CreateTexture(nil, "OVERLAY")
        highlight:SetAllPoints()
        highlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        highlight:SetAlpha(0.5)
        target.mark = highlight
        target:RegisterForClicks("AnyUp")
        local function selectBinding()
            if bindingFrame then
                selectOwnedBinding(bindingFrame, button)
            end
        end
        target:SetScript("OnEnter", selectBinding)
        target:SetScript("OnClick", function(_, mouseButton)
            if not bindingFrame then return end
            selectBinding()
            if mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then
                bindingFrame:HandleBindingInput(mouseButton)
            end
        end)
        target:EnableMouseWheel(true)
        target:SetScript("OnMouseWheel", function(_, delta)
            if not bindingFrame then return end
            selectBinding()
            bindingFrame:HandleBindingInput(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
        end)
        target:SetShown(bindingMode)
        button.baziBindingTarget = target
        bar.buttons[index] = button
        bar:SetFrameRef("button" .. index, button)
        button:SetState(0, "action", (pages[number] - 1) * 12 + index)
        if number == 1 then
            for page = 1, 11 do
                button:SetState(page, "action", (page - 1) * 12 + index)
            end
        end
    end
    if number == 1 then
        RegisterStateDriver(bar, "page", "[bar:6]6;[bar:5]5;[bar:4]4;[bar:3]3;[bar:2]2;[bonusbar:5]11;[bonusbar:4]10;[bonusbar:3]9;[bonusbar:2]8;[bonusbar:1]7;1")
    end
    RegisterStateDriver(bar, "mode", normalMode)
    return bar
end

function module:ConfigureOwnedBar(number, settings)
    local bar = bars[number]
    if not bar then
        bar = createBar(number)
        bars[number] = bar
    end

    local count = settings.buttons > 0 and math.min(12, settings.buttons) or 12
    local vertical = settings.direction == "vertical"
        or (settings.direction == "default" and (number == 4 or number == 5))
    local rows = math.max(1, settings.rows)
    local columns = settings.columns > 0 and settings.columns
        or (vertical and math.min(rows, count) or math.ceil(count / rows))
    columns = math.min(count, columns)
    rows = math.ceil(count / columns)
    local spacing = settings.spacing
    local buttonSize = settings.buttonSize
    local pitch = buttonSize + spacing
    bar:SetSize(columns * pitch - spacing, rows * pitch - spacing)
    bar:SetScale(settings.scale / 100)
    bar:ClearAllPoints()
    local ratio = UIParent:GetEffectiveScale() / bar:GetEffectiveScale()
    bar:SetPoint("CENTER", UIParent, "CENTER", settings.x * ratio, settings.y * ratio)

    local config = {
        showGrid = settings.empty,
        keyBoundClickButton = "Keybind",
        clickOnDown = GetCVarBool("ActionButtonUseKeyDown"),
        outOfRangeColoring = "none",
        externalStatusColoring = true,
        spellCastVFX = false,
    }
    for index, button in ipairs(bar.buttons) do
        local column = vertical and math.floor((index - 1) / rows) or (index - 1) % columns
        local row = vertical and (index - 1) % rows or math.floor((index - 1) / columns)
        button:ClearAllPoints()
        button:SetSize(buttonSize, buttonSize)
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", column * pitch, -row * pitch)
        config.keyBoundTarget = button.commandName
        button:UpdateConfig(config)
        button:SetShown(index <= count)
        button.baziBindingTarget:SetShown(bindingMode and index <= count)
    end
    bar:SetAttribute("buttonCount", count)
    bar:SetAttribute("enabled", settings.visible)
    assignBindings(bar)
    bar:Execute([[ self:RunAttribute("ApplyVisibility") ]])
    return bar.buttons, bar
end

function module:DisableOwnedBars()
    for _, bar in pairs(bars) do
        bar:SetAttribute("enabled", false)
        bar:Execute([[ self:RunAttribute("ApplyVisibility") ]])
    end
    for frame, parent in pairs(nativeParents) do
        frame:SetParent(parent)
        nativeParents[frame] = nil
    end
end

function module:SuspendNativeBar(frame)
    if nativeParents[frame] then return end
    if not nativeHolder then
        nativeHolder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        nativeHolder:SetAllPoints(UIParent)
        nativeHolder:Hide()
        RegisterStateDriver(nativeHolder, "visibility", "[vehicleui][overridebar][possessbar][petbattle] show; hide")
    end
    nativeParents[frame] = frame:GetParent()
    frame:SetParent(nativeHolder)
end

function module:RefreshOwnedBindings()
    if InCombatLockdown() then return end
    for _, bar in pairs(bars) do
        bar:SetAttribute("bindingMode", bindingMode)
        assignBindings(bar)
    end
end

function module:SetOwnedBindingMode(enabled, frame)
    if not enabled and bindingFrame then selectOwnedBinding(bindingFrame, nil) end
    bindingFrame = enabled and frame or nil
    bindingMode = enabled
    for _, bar in pairs(bars) do
        for _, button in ipairs(bar.buttons) do
            button.baziBindingTarget:SetShown(enabled and button:IsShown())
        end
    end
    self:RefreshOwnedBindings()
end
