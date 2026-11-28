local addon = BaziUI

addon.Options = addon.Options or {}

local optionsFrame
local contentFrame
local shadowToggle
local shadowPages = {General = true, ["Quality of Life"] = true, ActionBars = true, BugTab = true, Chat = true, Combat = true, Map = true,
    Dialogue = true, HUD = true, Inventory = true, Minimap = true, Nameplates = true, Quest = true, Tooltip = true, UnitFrames = true}
local navButtons = {}
local headerButtons = {}
local pages = {}
local pageFactories = {}

local ASSET = "Interface\\AddOns\\BaziUI\\Assets\\"
local NAV_ICONS = {
    General = 0, Profiles = 3, ["Quality of Life"] = 1, UnitFrames = 2,
    Nameplates = 3, ActionBars = 4, Chat = 5, Quest = 6, Gathering = 7,
    Dialogue = 5, Dashboard = 2, ["Smart Alerts"] = 1, ["Buff Reminders"] = 1, Journey = 6, ["Alt Manager"] = 4, HUD = 2, Inventory = 6, Minimap = 8, Tooltip = 9, Combat = 10, BugTab = 11,
}
local MAP_ICON = ASSET .. "Settings\\Map.png"

local function CreateSettingsIcon(parent, index, size)
    local icon = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    local x, y = index % 4, math.floor(index / 4)
    icon:SetTexture(ASSET .. "Settings\\Icons.png")
    icon:SetTexCoord(x / 4, (x + 1) / 4, y / 4, (y + 1) / 4)
    icon:SetSize(size, size)
    return icon
end

local function CreateLabel(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetText(text)
    return label
end

local function CreateDivider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(ASSET .. "Dividers\\Divider_Gold.png")
    line:SetVertexColor(0.90, 0.72, 0.49, 0.8)
    line:SetHeight(8)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, y)
    return line
end

local function CreateSection(parent, text, y)
    local heading = CreateLabel(parent, text, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    heading:SetTextColor(1, 0.79, 0.42, 1)
    return heading
end

local function CreatePanel(parent, top, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, top)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, top)
    panel:SetHeight(height)

    panel.surface = addon.Theme:Surface(panel, "Card", 15)
    return panel
end

local function CreateSlider(parent, labelText, description, minValue, maxValue, step, value, y, onValueChanged, compact, skipInitialCallback, iconIndex, help)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, y)
    row:SetHeight(compact and 34 or 54)
    addon.Theme:Surface(row, "Row", 12)
    local heading = CreateLabel(row, labelText, "GameFontNormal")
    heading:SetPoint("TOPLEFT", row, "TOPLEFT", 15, compact and -4 or -10)
    heading:SetTextColor(1, 0.78, 0.39)
    local hint = CreateLabel(row, description, "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", row, "TOPLEFT", 15, compact and -19 or -30)
    hint:SetTextColor(0.91, 0.78, 0.61, 1)
    if iconIndex then
        local badge = row:CreateTexture(nil, "ARTWORK")
        badge:SetSize(34, 34)
        badge:SetPoint("LEFT", 10, 0)
        addon.Theme:SetSurface(badge, "Button", 10)
        local icon = type(iconIndex) == "number" and CreateSettingsIcon(row, iconIndex, 25)
            or CreateLabel(row, iconIndex, "GameFontNormalLarge")
        icon:SetPoint("CENTER", badge)
        heading:SetPoint("TOPLEFT", row, "TOPLEFT", 54, -10)
        hint:SetPoint("TOPLEFT", row, "TOPLEFT", 54, -30)
    end
    local valueText
    local valueBox
    if true then -- All numeric sliders support direct keyboard entry.
        valueBox = CreateFrame("EditBox", nil, row)
        valueBox:SetSize(36, 19)
        valueBox:SetPoint("RIGHT", row, "RIGHT", -13, 0)
        valueBox:SetAutoFocus(false)
        valueBox:SetFontObject("GameFontNormal")
        valueBox:SetTextColor(1, 0.81, 0.45)
        valueBox:SetJustifyH("CENTER")
        valueBox:SetMaxLetters(5)
        valueBox:SetTextInsets(2, 2, 0, 0)
        addon.Theme:Surface(valueBox, "Field", 9)
        valueText = valueBox
    else
        valueText = CreateLabel(row, "", "GameFontNormal")
        valueText:SetPoint("RIGHT", row, "RIGHT", -15, 0)
        valueText:SetTextColor(1, 0.81, 0.45)
    end
    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(115, 18)
    slider:SetPoint("RIGHT", row, "RIGHT", -53, 0)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(7)
    track:SetTexture(ASSET .. "Sliders\\Slider_Track.png")
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(24, 28)
    thumb:SetTexture(ASSET .. "Settings\\Diamond.png")
    slider:SetThumbTexture(thumb)
    local progress = slider:CreateTexture(nil, "BORDER")
    progress:SetPoint("LEFT", track, "LEFT", 0, 0)
    progress:SetHeight(7)
    progress:SetTexture(ASSET .. "Sliders\\Slider_Fill_Gold.png")
    local function RefreshProgress(raw)
        local fraction = (raw - minValue) / (maxValue - minValue)
        progress:SetWidth(math.max(1, 115 * math.max(0, math.min(1, fraction))))
    end
    local initializing = skipInitialCallback
    slider:SetScript("OnValueChanged", function(self, raw)
        local rounded = math.floor(raw / step + 0.5) * step
        if not valueBox or not valueBox:HasFocus() then
            valueText:SetText(string.format("%g", rounded))
        end
        RefreshProgress(rounded)
        if onValueChanged and not initializing then onValueChanged(rounded) end
    end)
    slider:SetValue(value)
    initializing = false
    if valueBox then
        if labelText == "WINDOW SCALE" then
            slider:SetScript("OnMouseUp", function()
                if optionsFrame and addon.db and addon.db.profile then
                    optionsFrame:SetScale(addon.db.profile.uiScale)
                end
            end)
        end
        local committing = false
        local function CommitValue()
            if committing then return end
            committing = true
            local input = valueBox:GetText() or ""
            local number = tonumber((input:gsub(",", ".")))
            if number then
                number = math.max(minValue, math.min(maxValue, number))
                number = math.floor(number / step + 0.5) * step
                -- SetValue updates the slider thumb and its OnValueChanged
                -- callback persists the new value to the profile.
                slider:SetValue(number)
                -- Force the saved value even when the slider was already there.
                if onValueChanged then onValueChanged(number) end
                if labelText == "WINDOW SCALE" and optionsFrame then
                    optionsFrame:SetScale(number)
                end
            end
            valueBox:SetText(string.format("%g", slider:GetValue()))
            valueBox:ClearFocus()
            committing = false
        end
        valueBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        valueBox:SetScript("OnEnterPressed", CommitValue)
        valueBox:SetScript("OnEditFocusLost", function()
            if not committing then CommitValue() end
        end)
        valueBox:SetScript("OnEscapePressed", function(self)
            self:SetText(string.format("%g", slider:GetValue()))
            self:ClearFocus()
        end)
    end
    RefreshProgress(value)
    valueText:SetText(string.format("%g", value))
    slider.valueBox = valueBox
    slider.heading = heading
    local explanation = help or (description ~= "" and description or nil)
        or ("Range %g to %g, in steps of %g. Drag the slider or type an exact value."):format(minValue, maxValue, step)
    addon.Theme:SettingsHelp(slider, labelText, explanation, heading)
    if valueBox then addon.Theme:SettingsHelp(valueBox, labelText, explanation) end
    function slider:DisplayValue(current)
        initializing = true
        self:SetValue(current)
        valueText:SetText(string.format("%g", self:GetValue()))
        initializing = false
    end
    return slider
end

local function ShowPage(pageName, subpage)
    -- Build each settings page only when first selected. Existing page builders
    -- and module behavior remain unchanged; created pages are cached.
    if not pages[pageName] and pageFactories[pageName] then
        pageFactories[pageName]()
    end
    for name, page in pairs(pages) do
        page:SetShown(name == pageName)
    end

    local page = pages[pageName]
    if subpage and page and page.SelectSubpage then page:SelectSubpage(subpage) end
    if shadowToggle then
        shadowToggle.key = pageName
        shadowToggle:SetShown(shadowPages[pageName] == true)
        shadowToggle:SetChecked(addon.Theme:IsDropShadowEnabled(pageName))
    end

    for name, button in pairs(navButtons) do
        button.baziActive = (name == pageName)
        button.baziRefresh()
    end
    for name, button in pairs(headerButtons) do
        local topPage = pageName == "Profiles" and subpage == "Export" and "Export" or pageName
        local active = name == topPage or (name == "General" and not headerButtons[topPage])
        addon.Theme:SetButtonActive(button, active)
    end
end

local function CreateGridControls(page, db)
    local spacing = addon.LayoutGrid.Spacing()
    local check = addon.Theme:CreateCheckbox(page)
    check:SetSize(22, 22)
    check:SetPoint("TOPRIGHT", page, "TOPRIGHT", -19, -12)
    local label = CreateLabel(page, "Grid", "GameFontHighlight")
    label:SetPoint("RIGHT", check, "LEFT", -4, 0)
    local value = CreateLabel(page, tostring(spacing), "GameFontNormalSmall")
    value:SetWidth(24)
    value:SetPoint("RIGHT", label, "LEFT", -7, 0)
    for i, delta in ipairs({-4, 4}) do
        local button = CreateFrame("Button", nil, page)
        button:SetSize(21, 22)
        button:SetPoint("RIGHT", value, "LEFT", -2 - (i - 1) * 22, 0)
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        addon.Theme:Paint(fill, "panel", 1)
        local glyph = CreateLabel(button, delta < 0 and "+" or "−")
        glyph:SetPoint("CENTER")
        button:SetScript("OnClick", function()
            spacing = math.max(8, math.min(80, spacing + delta))
            db.gridSpacing = spacing
            value:SetText(tostring(spacing))
            addon.LayoutGrid.Refresh()
        end)
    end
    page:HookScript("OnShow", function()
        check:SetChecked(addon.LayoutGrid.IsShown())
        spacing = addon.LayoutGrid.Spacing()
        value:SetText(tostring(spacing))
    end)
    check:SetChecked(addon.LayoutGrid.IsShown())
    check:SetScript("OnClick", function(self)
        if self:GetChecked() then addon.LayoutGrid.Show("settings", true)
        else addon.LayoutGrid.Hide() end
    end)
end

local function CreateTypographyPanel(parent, top, updateHeight, updateGeneralSize)
    local typography = addon.Typography
    local profile = addon.db.profile
    local panel = CreatePanel(parent, top, 240)
    CreateSection(panel, "Fonts", -14)
    local preview = CreateLabel(panel, "The quick brown fox  0123456789", "GameFontHighlight")
    preview:SetPoint("TOPLEFT", 22, -49)
    preview:SetPoint("TOPRIGHT", -22, -49)
    preview:SetJustifyH("CENTER")

    local outlines = {{"module", "Module"}, {"general", "General"}, {"", "None"}, {"OUTLINE", "Thin"}, {"THICKOUTLINE", "Thick"}}
    local shadows = {{"module", "Module"}, {"general", "General"}, {"on", "On"}, {"off", "Off"}}
    local families = {{"module", "Module font"}, {"general", "General"}}
    for _, entry in ipairs(typography.choices) do families[#families + 1] = entry end

    local function updatePreview()
        typography.Apply(preview, "GeneralPreview", typography.Path(profile.font), profile.fontSize, "", true)
    end

    local function picker(row, previous, width, choices, read, write)
        local dropdown = addon.Theme:CreateSettingsDropdown(row)
        dropdown:SetSize(width, 23)
        if previous then dropdown:SetPoint("RIGHT", previous, "LEFT", -5, 0)
        else dropdown:SetPoint("RIGHT", -3, 0) end
        local function showSelection()
            local current = read()
            for _, entry in ipairs(choices) do
                if entry[1] == current then dropdown:SetText(entry[2]); return end
            end
        end
        dropdown:SetupMenu(function(_, root)
            for _, entry in ipairs(choices) do
                local value, caption = unpack(entry)
                root:CreateRadio(caption, function() return read() == value end, function()
                    write(value)
                    showSelection()
                end)
            end
        end)
        showSelection()
        return dropdown
    end

    local function sizeControl(row, previous, read, write, minimum)
        local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        box:SetSize(44, 21)
        box:SetAutoFocus(false)
        box:SetMaxLetters(4)
        box:SetJustifyH("CENTER")
        box:SetTextInsets(0, 0, 0, 0)
        local plus = addon.Theme:CreateButton(row, "+", 21, 21)
        local minus = addon.Theme:CreateButton(row, "-", 21, 21)
        plus:SetPoint("RIGHT", previous, "LEFT", -6, 0)
        box:SetPoint("RIGHT", plus, "LEFT", -2, 0)
        minus:SetPoint("RIGHT", box, "LEFT", -2, 0)
        local function showValue()
            local size = read()
            box:SetText(size == 0 and "Auto" or tostring(size))
        end
        local function commit(value)
            if minimum == 0 and type(value) == "string" and value:lower() == "auto" then value = 0 end
            value = tonumber(value)
            if value then write(math.max(minimum, math.min(40, math.floor(value + 0.5)))) end
            showValue()
        end
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        box:SetScript("OnEnterPressed", function(self) commit(self:GetText()); self:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(self) showValue(); self:ClearFocus() end)
        box:SetScript("OnEditFocusLost", function(self) commit(self:GetText()) end)
        plus:SetScript("OnClick", function() commit(read() + 1) end)
        minus:SetScript("OnClick", function() commit(read() - 1) end)
        showValue()
        return minus, showValue
    end

    local function fontRow(label, key, group)
        local row = CreateFrame("Frame", nil, panel)
        row:SetHeight(31)
        local text = CreateLabel(row, label, "GameFontHighlight")
        text:SetPoint("LEFT", group and 14 or 0, 0)
        local values
        if group then values = typography.Values(key) end
        local function get(field)
            if values then return values[field] end
            if field == "font" then return profile.font end
            if field == "size" then return profile.fontSize end
            if field == "outline" then return profile.generalFontOutline end
            return profile.generalFontShadow
        end
        local function set(field, value)
            if field == "size" and value == get(field) then return end
            if value == "module" or field == "size" and value == 0 then value = nil end
            if values then
                values[field] = value
                if field == "font" or field == "size" then typography.ModuleChanged(key, field, true) end
            elseif field == "font" then profile.font = value
            elseif field == "size" then profile.fontSize = value
            elseif field == "outline" then profile.generalFontOutline = value
            else profile.generalFontShadow = value end
            if not values and (field == "font" or field == "size") then typography.GeneralChanged(field) end
            typography.Refresh(group)
            updatePreview()
            if not group and field == "size" and updateGeneralSize then updateGeneralSize() end
        end
        local shadowChoices = group and shadows or {shadows[1], shadows[3], shadows[4]}
        local edgeChoices = group and outlines or {outlines[1], outlines[3], outlines[4], outlines[5]}
        local shadow = picker(row, nil, 78, shadowChoices, function() return get("shadow") or "module" end,
            function(value) set("shadow", value) end)
        local outline = picker(row, shadow, 84, edgeChoices, function() return get("outline") or "module" end,
            function(value) set("outline", value) end)
        local size, refreshSize = sizeControl(row, outline, function() return get("size") or 0 end,
            function(value) set("size", value) end, group and 0 or 8)
        row.RefreshSize = refreshSize
        picker(row, size, 118, group and families or typography.choices,
            function() return get("font") or "module" end, function(value) set("font", value) end)
        return row
    end

    local general = fontRow("General")
    local groups = {}
    local function place(row, y)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -y)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -15, -y)
    end
    local function layout()
        place(general, 93)
        local y = 148
        for _, entry in ipairs(groups) do
            place(entry.heading, y)
            y = y + 31
            for _, row in ipairs(entry.rows) do
                row:SetShown(entry.open)
                if entry.open then place(row, y); y = y + 31 end
            end
        end
        panel:SetHeight(y + 12)
        updateHeight(y + 20)
    end

    local labels = CreateLabel(panel, "Font                   Size              Outline          Shadow", "GameFontHighlightSmall")
    labels:SetPoint("TOPRIGHT", -27, -77)
    local hint = CreateLabel(panel, "Auto uses the parent or module size. Enter a number to set a custom size.", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 18, -127)
    for _, spec in ipairs(typography.groups) do
        local key, caption, parts = unpack(spec)
        local heading = CreateFrame("Button", nil, panel)
        heading:SetHeight(29)
        local label = CreateLabel(heading, "+  " .. caption)
        label:SetPoint("LEFT", 2, 0)
        local entry = {heading = heading, open = false, rows = {fontRow("Module defaults", key, key)}}
        for _, part in ipairs(parts or {}) do
            entry.rows[#entry.rows + 1] = fontRow(part[2], key .. ":" .. part[1], key)
        end
        heading:SetScript("OnClick", function()
            entry.open = not entry.open
            label:SetText((entry.open and "-  " or "+  ") .. caption)
            layout()
        end)
        groups[#groups + 1] = entry
    end
    updatePreview()
    layout()
    function panel:RefreshCommonText()
        general.RefreshSize()
        updatePreview()
    end
    return panel
end

local function CreateBackgroundPanel(parent, top, updateHeight)
    local panel = CreatePanel(parent, top, 130)
    local backgrounds = addon.Backgrounds
    CreateSection(panel, "Backgrounds", -14)
    local profile = addon.db.profile
    local rows, current = {}, {}
    local function refreshRows()
        for index, option in ipairs(current) do
            local row = rows[index]
            row.text:SetText(option[1])
            if not row.box:HasFocus() then row.box:SetText(("%g"):format(option[2]())) end
        end
    end
    local function apply(value, option)
        local updates = {}
        for _, destination in ipairs(option and {option} or current) do
            local callback = destination[3](value)
            if callback then updates[callback] = true end
        end
        for callback in pairs(updates) do callback() end
        refreshRows()
    end
    CreateSlider(panel, "ALL BACKGROUNDS (%)", "Set all window backgrounds to the same opacity.",
        0, 100, 1, profile.allBackgroundOpacity or 100, -53, function(value)
            profile.allBackgroundOpacity = value
            apply(value)
        end, false, true)

    local function configure()
        current = backgrounds.Options()
        for index in ipairs(current) do
            if not rows[index] then
                local row = CreateFrame("Frame", nil, panel)
                row:SetHeight(29)
                local y = -119 - (index - 1) * 29
                row:SetPoint("TOPLEFT", 28, y)
                row:SetPoint("TOPRIGHT", -28, y)
                local label = CreateLabel(row, "", "GameFontHighlight")
                label:SetPoint("LEFT")
                local percent = CreateLabel(row, "%", "GameFontHighlightSmall")
                percent:SetPoint("RIGHT", -9, 0)
                local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                box:SetPoint("RIGHT", percent, "LEFT", -9, 0)
                box:SetSize(43, 22)
                box:SetNumeric(true)
                box:SetAutoFocus(false)
                box:SetMaxLetters(3)
                box:SetTextInsets(0, 0, 0, 0)
                box:SetJustifyH("CENTER")
                box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                box:SetScript("OnEscapePressed", function(self)
                    self:SetText(("%g"):format(current[index][2]()))
                    self:ClearFocus()
                end)
                box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                box:SetScript("OnEditFocusLost", function(self)
                    local option = current[index]
                    if not option then return end
                    local value = tonumber(self:GetText())
                    if value and value ~= option[2]() then apply(math.min(100, value), option) end
                    self:SetText(("%g"):format(option[2]()))
                end)
                rows[index] = {frame = row, text = label, box = box}
            end
        end
        for index, row in ipairs(rows) do row.frame:SetShown(current[index] ~= nil) end
        refreshRows()
        local height = 131 + #current * 29
        panel:SetHeight(height)
        updateHeight(height + 8)
    end
    panel:SetScript("OnShow", configure)
    return panel
end

local function CreateHeadersPanel(parent, top, updateHeight)
    local panel = CreatePanel(parent, top, 175)
    local headers, theme = addon.Headers, addon.Theme
    local current, rows = {}, {}
    CreateSection(panel, "Headers", -14)
    local function refreshRows()
        for index, entry in ipairs(current) do
            local row, key = rows[index], entry[1]
            row.label:SetText(entry[2])
            if not row.opacity:HasFocus() then row.opacity:SetText(tostring(headers.DisplayValue(key, "opacity"))) end
            row.fill:Refresh()
            row.text:Refresh()
            row.reset:SetEnabled(headers.Get(key, "opacity") ~= nil
                or headers.Get(key, "color") ~= nil or headers.Get(key, "text") ~= nil)
        end
    end
    local function update(property, value, entry)
        local targets = entry and {entry} or headers.Options(true)
        if not entry then headers.Set("all", property, value) end
        for _, target in ipairs(targets) do headers.Set(target[1], property, value) end
        headers.Refresh(targets)
        refreshRows()
    end
    local master = CreateSlider(panel, "ALL HEADER OPACITY (%)", "", 0, 100, 1,
        headers.Get("all", "opacity") or 100, -48, function(value) update("opacity", value) end, true, true)

    local function colorSwatch(owner, property, getEntry)
        return theme:CreateColorSwatch(owner, function()
            local entry = getEntry and getEntry()
            if entry then return headers.DisplayValue(entry[1], property) end
            return headers.Get("all", property) or headers.DisplayValue("settings", property)
        end, function(value)
            update(property, value, getEntry and getEntry())
        end, function()
            local entry = getEntry and getEntry()
            local targets = entry and {entry} or headers.Options(true)
            local prior = {}
            for index, target in ipairs(targets) do prior[index] = headers.Get(target[1], property) end
            local priorMaster = headers.Get("all", property)
            return function()
                if not entry then headers.Set("all", property, priorMaster) end
                for index, target in ipairs(targets) do headers.Set(target[1], property, prior[index]) end
                headers.Refresh(targets)
                refreshRows()
            end
        end)
    end
    local masterColors = {}
    for index, option in ipairs({{"color", "All header backgrounds"}, {"text", "All header text"}}) do
        local label = CreateLabel(panel, option[2], "GameFontHighlight")
        local x = index == 1 and 32 or 255
        label:SetPoint("TOPLEFT", x, -98)
        local swatch = colorSwatch(panel, option[1])
        swatch:SetPoint("LEFT", label, "RIGHT", 10, 0)
        masterColors[index] = swatch
    end
    CreateDivider(panel, -127)

    local columns = {{"Opacity", -196}, {"Fill", -139}, {"Text", -91}}
    for _, column in ipairs(columns) do
        local title = CreateLabel(panel, column[1], "GameFontHighlightSmall")
        title:SetPoint("TOPRIGHT", column[2], -139)
    end
    local function configure()
        current = headers.Options()
        for index in ipairs(current) do
            if not rows[index] then
                local row = CreateFrame("Frame", nil, panel)
                row:SetHeight(31)
                local y = -157 - (index - 1) * 31
                row:SetPoint("TOPLEFT", 28, y)
                row:SetPoint("TOPRIGHT", -24, y)
                local label = CreateLabel(row, "", "GameFontHighlight")
                label:SetPoint("LEFT")
                local function entry() return current[index] end
                local reset = theme:CreateButton(row, "Reset", 54, 22)
                reset:SetPoint("RIGHT")
                reset:SetScript("OnClick", function()
                    local target = entry()
                    for _, property in ipairs({"opacity", "color", "text"}) do headers.Set(target[1], property, nil) end
                    headers.Refresh({target})
                    refreshRows()
                end)
                local text = colorSwatch(row, "text", entry)
                text:SetPoint("RIGHT", reset, "LEFT", -12, 0)
                local fill = colorSwatch(row, "color", entry)
                fill:SetPoint("RIGHT", text, "LEFT", -14, 0)
                local percent = CreateLabel(row, "%", "GameFontHighlightSmall")
                percent:SetPoint("RIGHT", fill, "LEFT", -12, 0)
                local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                box:SetPoint("RIGHT", percent, "LEFT", -6, 0)
                box:SetSize(43, 22)
                box:SetNumeric(true)
                box:SetMaxLetters(3)
                box:SetAutoFocus(false)
                box:SetJustifyH("CENTER")
                box:SetTextInsets(0, 0, 0, 0)
                box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                box:SetScript("OnEscapePressed", function(self)
                    self:SetText(tostring(headers.DisplayValue(entry()[1], "opacity")))
                    self:ClearFocus()
                end)
                box:SetScript("OnEditFocusLost", function(self)
                    local target = entry()
                    if not target then return end
                    local value = tonumber(self:GetText())
                    if value and value ~= headers.DisplayValue(target[1], "opacity") then
                        update("opacity", math.min(100, value), target)
                    end
                    self:SetText(tostring(headers.DisplayValue(target[1], "opacity")))
                end)
                rows[index] = {frame = row, label = label, opacity = box, fill = fill, text = text, reset = reset}
            end
        end
        for index, row in ipairs(rows) do row.frame:SetShown(current[index] ~= nil) end
        master:DisplayValue(headers.Get("all", "opacity") or 100)
        for _, swatch in ipairs(masterColors) do swatch:Refresh() end
        refreshRows()
        local height = 169 + #current * 31
        panel:SetHeight(height)
        updateHeight(height + 8)
    end
    panel:SetScript("OnShow", configure)
    return panel
end


local function CreateGeneralPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.General = page
    local content, _, scrollbar = addon.Inventory.Scroll(page, -3, 5)
    local introPanel = CreatePanel(content, -8, 88)
    addon.Theme:SetSurface(introPanel.surface, "Hero", 15)
    local heroArt = introPanel:CreateTexture(nil, "BACKGROUND", nil, 2)
    heroArt:SetPoint("TOPLEFT", introPanel, "TOP", -100, -2)
    heroArt:SetPoint("BOTTOMRIGHT", -3, 3)
    heroArt:SetTexture(ASSET .. "Settings\\Realm.png")
    local blend = introPanel:CreateMaskTexture()
    blend:SetAllPoints(heroArt)
    blend:SetTexture(ASSET .. "Settings\\HeroMask.png", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    heroArt:AddMaskTexture(blend)
    local heroIcon = CreateSettingsIcon(introPanel, 12, 40)
    heroIcon:SetPoint("LEFT", 16, 0)
    local heroTitle = CreateLabel(introPanel, "Adjust to your heart’s content", "GameFontNormalHuge")
    heroTitle:SetPoint("TOPLEFT", introPanel, "TOPLEFT", 66, -18)
    heroTitle:SetTextColor(1, 0.81, 0.45)
    heroTitle:SetShadowOffset(1, -1)
    local intro = CreateLabel(introPanel, "Fine-tune your interface.", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", introPanel, "TOPLEFT", 67, -51)
    intro:SetTextColor(0.96, 0.82, 0.63, 1)

    local appearancePanel = CreatePanel(content, -112, 275)
    local appearance = CreateSection(appearancePanel, "Appearance", -14)
    appearance:SetPoint("TOPLEFT", appearancePanel, "TOPLEFT", 61, -14)
    local appearanceIcon = CreateSettingsIcon(appearancePanel, 13, 29)
    appearanceIcon:SetPoint("TOPLEFT", 18, -8)
    CreateDivider(appearancePanel, -38)
    local db = addon.db.profile
    CreateGridControls(appearancePanel, db)
    local windowScale = CreateSlider(appearancePanel, "WINDOW SCALE", "Size of the Bazi UI settings window", 0.70, 1.50, 0.01, db.uiScale, -53, function(value)
        db.uiScale = value
        -- Apply scale on mouse release so the slider does not move under the cursor.
    end, nil, nil, 14)
    windowScale.heading:SetText("Window Scale")
    local fonts
    local appearanceSize = CreateSlider(appearancePanel, "Font Size", "Default text size for supported modules", 8, 40, 1,
        db.fontSize or 14, -113, function(value)
            if value == db.fontSize then return end
            db.fontSize = value
            addon.Typography.GeneralChanged("size")
            addon.Typography.Refresh()
            if fonts then fonts:RefreshCommonText() end
        end, nil, true, "Aa")
    local accentLabel = CreateLabel(appearancePanel, "Accent Color", "GameFontNormal")
    accentLabel:SetPoint("TOPLEFT", 29, -184)
    local accentPicker = addon.Theme:CreateColorSwatch(appearancePanel, function()
        return {addon.Theme:Accent()}
    end, function(color)
        db.accentColor = color
        addon.Theme:RefreshInterfaceStyle()
        for _, section in ipairs({"Quest", "Combat", "Inventory", "Map", "Dialogue"}) do
            addon.Typography.Refresh(section)
        end
        local chat = addon.Chat
        if chat and chat.active then
            chat.Tabs.RefreshQuestAccent()
            chat.Lines.Refresh()
            if chat.Header and chat.Header.Relayout then chat.Header.Relayout() end
        end
    end)
    accentPicker:SetPoint("TOPRIGHT", -29, -178)
    local function refreshStyle()
        addon.Theme:RefreshInterfaceStyle()
        addon.Headers.Refresh(addon.Headers.Options(true))
        addon.Minimap:Apply()
        addon.Map.Refresh()
        if addon.Tooltip then addon.Tooltip:Apply() end
    end
    local style = addon.Theme:CreateSettingsDropdown(appearancePanel)
    style:SetSize(170, 26)
    style:SetPoint("TOPLEFT", 120, -218)
    CreateLabel(appearancePanel, "Border style", "GameFontNormal"):SetPoint("TOPLEFT", 29, -222)
    local styles = {{"gold", "Gold"}, {"accent", "Accent color"}}
    style:SetupMenu(function(_, root)
        for _, entry in ipairs(styles) do
            local key, label = unpack(entry)
            root:CreateRadio(label, function() return (db.borderStyle or "gold") == key end, function()
                db.borderStyle = key
                style:SetText(label)
                refreshStyle()
            end)
        end
    end)
    style:SetText(db.borderStyle == "accent" and "Accent color" or "Gold")
    local classText = addon.Theme:CreateCheckbox(appearancePanel)
    classText:SetSize(24, 24)
    classText:SetPoint("TOPLEFT", 316, -218)
    classText:SetChecked(db.classHeaderText == true)
    classText:SetScript("OnClick", function(self)
        db.classHeaderText = not not self:GetChecked()
        refreshStyle()
    end)
    CreateLabel(appearancePanel, "Class-colored header text", "GameFontHighlight"):SetPoint("LEFT", classText, "RIGHT", 6, 0)
    local guidance = CreatePanel(content, -400, 108)
    CreateSection(guidance, "Guides and activity", -12)
    local guides = addon.Theme:CreateCheckbox(guidance)
    guides:SetSize(24, 24)
    guides:SetPoint("TOPLEFT", 24, -36)
    guides:SetChecked(db.firstUseGuides ~= false)
    CreateLabel(guidance, "Show first-use guides", "GameFontHighlight"):SetPoint("LEFT", guides, "RIGHT", 6, 0)
    addon.Theme:SettingsHelp(guides, "Show first-use guides", "Turn this off to hide all guides. Turn it back on to show every guide again, including ones you dismissed.")
    guides:SetScript("OnClick", function(self)
        addon.Inventory.SetFirstUseGuidesEnabled(not not self:GetChecked())
    end)
    local exitScope = addon.Theme:CreateSettingsDropdown(guidance)
    exitScope:SetSize(174, 26)
    exitScope:SetPoint("TOPLEFT", 142, -69)
    CreateLabel(guidance, "Logout activity", "GameFontNormal"):SetPoint("TOPLEFT", 29, -74)
    local scopes = {{"today", "Today"}, {"session", "Current session"}, {"off", "Off"}}
    exitScope:SetupMenu(function(_, root)
        for _, entry in ipairs(scopes) do
            local key, label = unpack(entry)
            root:CreateRadio(label, function() return addon.ActivityStats.ExitScope() == key end, function()
                addon.ActivityStats.SetExitScope(key)
                exitScope:SetText(label)
            end)
        end
    end)
    for _, entry in ipairs(scopes) do
        if addon.ActivityStats.ExitScope() == entry[1] then exitScope:SetText(entry[2]); break end
    end
    addon.Theme:SettingsHelp(exitScope, "Logout activity", "Chooses which activity report appears when you log out or exit the game.")
    local top = -567
    local buttons = CreatePanel(content, -518, 39)
    local fontsButton = addon.Theme:CreateButton(buttons, "Fonts", 125, 27)
    fontsButton:SetPoint("LEFT", 14, 0)
    local backgroundsButton = addon.Theme:CreateButton(buttons, "Backgrounds", 125, 27)
    backgroundsButton:SetPoint("LEFT", fontsButton, "RIGHT", 8, 0)
    local headersButton = addon.Theme:CreateButton(buttons, "Headers", 125, 27)
    headersButton:SetPoint("LEFT", backgroundsButton, "RIGHT", 8, 0)
    local function updateHeight(height) content:SetHeight(-top + height) end
    fonts = CreateTypographyPanel(content, top, function(height)
        content.fontsHeight = height
        if not content.selectedSection or content.selectedSection == "Fonts" then updateHeight(height) end
    end, function() appearanceSize:DisplayValue(db.fontSize or 14) end)
    local backgrounds = CreateBackgroundPanel(content, top, updateHeight)
    local headers = CreateHeadersPanel(content, top, updateHeight)
    backgrounds:Hide()
    headers:Hide()
    function page:SelectSubpage(name)
        if content.selectedSection ~= name then scrollbar:SetValue(0) end
        content.selectedSection = name
        fonts:SetShown(name == "Fonts")
        backgrounds:SetShown(name == "Backgrounds")
        headers:SetShown(name == "Headers")
        if name == "Fonts" then updateHeight(content.fontsHeight) end
        addon.Theme:SetButtonActive(fontsButton, name == "Fonts")
        addon.Theme:SetButtonActive(backgroundsButton, name == "Backgrounds")
        addon.Theme:SetButtonActive(headersButton, name == "Headers")
    end
    fontsButton:SetScript("OnClick", function() page:SelectSubpage("Fonts") end)
    backgroundsButton:SetScript("OnClick", function() page:SelectSubpage("Backgrounds") end)
    headersButton:SetScript("OnClick", function() page:SelectSubpage("Headers") end)
    page:SelectSubpage("Fonts")
    return page
end

local function CreateBugTabPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.BugTab = page
    local bugs = addon.BugTab
    local db = bugs.Settings()
    local theme = addon.Theme
    local header = CreatePanel(page, -8, 91)
    CreateSection(header, "LUA ERRORS", -14)

    local function checkbox(key, label, x)
        local check = addon.Theme:CreateCheckbox(header)
        check:SetSize(25, 25)
        check:SetPoint("TOPLEFT", x, -51)
        check:SetChecked(db[key] ~= false)
        CreateLabel(check, label, "GameFontHighlight"):SetPoint("LEFT", check, "RIGHT", 5, 0)
        check:SetScript("OnClick", function(self) db[key] = not not self:GetChecked() end)
    end
    checkbox("audio", "Notification sound", 16)
    checkbox("chat", "Chat notice", 190)

    local function dropdown(parent, width, provider, read, write)
        local button = addon.Theme:CreateSettingsDropdown(parent)
        button:SetSize(width, 28)
        local function update()
            for _, entry in ipairs(provider()) do
                if entry[1] == read() then
                    button:SetText(entry[2])
                    break
                end
            end
        end
        button:SetupMenu(function(_, root)
            if root.SetScrollMode then root:SetScrollMode(280) end
            for _, entry in ipairs(provider()) do
                root:CreateRadio(entry[2], function() return entry[1] == read() end, function()
                    write(entry[1])
                    update()
                end)
            end
        end)
        update()
        return button, update
    end

    local preview = theme:CreateButton(header, "Preview sound", 114, 26)
    preview:SetPoint("TOPRIGHT", -18, -50)
    preview:SetScript("OnClick", bugs.PreviewSound)
    local sounds = dropdown(header, 140, bugs.SoundChoices, bugs.SelectedSound,
        function(value) db.sound = value end)
    sounds:SetPoint("RIGHT", preview, "LEFT", -10, 0)

    local logs = CreatePanel(page, -115, 380)
    logs:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 12, 12)
    CreateSection(logs, "ERROR LOG", -14)
    local source = false
    local function addons()
        local entries, seen = {{false, "All addons"}}, {}
        for _, entry in ipairs(db.logs) do seen[entry.source] = true end
        local names = {}
        for name in pairs(seen) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do entries[#entries + 1] = {name, name} end
        return entries
    end

    local function crystal(parent)
        local bar = CreateFrame("Slider", nil, parent)
        bar:SetOrientation("VERTICAL")
        bar:SetWidth(14)
        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints()
        addon.Theme:Paint(track, "field", 0.9)
        local thumb = bar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(14, 38)
        addon.Theme:StyleScrollThumb(thumb)
        bar:SetThumbTexture(thumb)
        return bar
    end

    local popup = CreateFrame("Frame", nil, page, "BackdropTemplate")
    popup:SetPoint("CENTER", page, "CENTER")
    popup:SetPoint("LEFT", page, "LEFT", 28, 0)
    popup:SetPoint("RIGHT", page, "RIGHT", -28, 0)
    popup:SetHeight(255)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:EnableMouse(true)
    popup:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
    popup:SetBackdropBorderColor(0.76, 0.57, 0.29)
    theme:TrackWindowBorder(popup)
    theme:AddDropShadow("BugTab", popup)
    local opaque = popup:CreateTexture(nil, "BACKGROUND")
    opaque:SetPoint("TOPLEFT", 3, -3)
    opaque:SetPoint("BOTTOMRIGHT", -3, 3)
    addon.Theme:Paint(opaque, "window", 1)
    addon.Backgrounds.Track("bugReport", opaque)
    popup:Hide()
    page:HookScript("OnHide", function() popup:Hide() end)
    local reportHeader = popup:CreateTexture(nil, "BACKGROUND", nil, 1)
    reportHeader:SetPoint("TOPLEFT", 3, -3)
    reportHeader:SetPoint("TOPRIGHT", -3, -3)
    reportHeader:SetHeight(39)
    local reportTitle = CreateSection(popup, "LUA ERROR", -14)
    local function styleReportHeader()
        local headers = addon.Headers
        reportHeader:SetShown(theme:UsesAccentStyle() or headers.Get("bugReport", "color") ~= nil
            or headers.Get("bugReport", "opacity") ~= nil)
        local r, g, b = unpack(theme.colors.window)
        reportHeader:SetColorTexture(headers.Fill("bugReport", r, g, b, 1))
        reportTitle:SetTextColor(headers.Text("bugReport", 1, 0.78, 0.39))
    end
    addon.Headers.RegisterRefresh("bugReport", styleReportHeader)
    styleReportHeader()
    local close = theme:CreateButton(popup, "Close", 70, 25)
    close:SetPoint("BOTTOMRIGHT", -15, 12)
    close:SetScript("OnClick", function() popup:Hide() end)
    local copyHint = CreateLabel(popup, "Ctrl+C to copy report", "GameFontHighlightSmall")
    copyHint:SetPoint("BOTTOMLEFT", 22, 19)
    local report = CreateFrame("ScrollFrame", nil, popup)
    report:SetPoint("TOPLEFT", 22, -46)
    report:SetPoint("BOTTOMRIGHT", -40, 47)
    local edit = CreateFrame("EditBox", nil, report)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetHeight(1)
    report:SetScrollChild(edit)
    report:SetScript("OnSizeChanged", function(_, width) edit:SetWidth(math.max(1, width)) end)
    edit:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup:SetScript("OnHide", function() edit:ClearFocus() end)
    local reportBar = crystal(popup)
    reportBar:Hide()
    reportBar:SetPoint("TOPLEFT", report, "TOPRIGHT", 7, 0)
    reportBar:SetPoint("BOTTOMLEFT", report, "BOTTOMRIGHT", 7, 0)
    reportBar:SetScript("OnValueChanged", function(_, value) report:SetVerticalScroll(value) end)
    report:SetScript("OnScrollRangeChanged", function(_, _, limit)
        reportBar:SetMinMaxValues(0, math.max(1, limit))
        reportBar:SetShown(limit > 0)
        reportBar:SetValue(math.min(limit, reportBar:GetValue()))
    end)
    report:EnableMouseWheel(true)
    report:SetScript("OnMouseWheel", function(_, delta)
        reportBar:SetValue(math.max(0, math.min(report:GetVerticalScrollRange(), reportBar:GetValue() - delta * 30)))
    end)
    local reportText
    local function openReport(entry)
        reportText = bugs.Report(entry)
        edit:ClearFocus()
        edit:SetText(reportText)
        edit:SetCursorPosition(0)
        popup:Show()
        reportBar:SetValue(0)
        report:SetVerticalScroll(0)
        edit:SetFocus()
        edit:HighlightText()
    end
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(reportText) end
    end)

    local visible, rows = {}, {}
    local list = CreateFrame("Frame", nil, logs)
    list:SetPoint("TOPLEFT", 18, -50)
    list:SetPoint("TOPRIGHT", -38, -50)
    list:SetPoint("BOTTOMLEFT", logs, "BOTTOMLEFT", 18, 46)
    local bar = crystal(logs)
    bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
    bar:SetValueStep(1)
    local empty = CreateLabel(list, "No Lua errors recorded.", "GameFontHighlight")
    empty:SetPoint("TOPLEFT", 4, -6)
    local rowCount = 0
    local function renderRows()
        local offset = math.floor(bar:GetValue() + 0.5)
        for i, row in ipairs(rows) do
            local entry = i <= rowCount and visible[offset + i] or nil
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then
                row.caption:SetText(("%s  ·  %s  ·  ×%d  ·  %s"):format(
                    date("%Y-%m-%d %H:%M:%S", entry.time), entry.source,
                    entry.count, entry.message:match("^[^\n]*")):gsub("|", "||"))
            end
        end
    end
    local function addRow(i)
        local row = CreateFrame("Frame", nil, list)
        row:SetHeight(26)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 31)
        row:SetPoint("RIGHT", list, "RIGHT")
        local fill = row:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        addon.Theme:Paint(fill, "row", 0.75)
        local copy = theme:CreateButton(row, "Copy", 64, 26)
        copy:SetPoint("RIGHT")
        copy:SetScript("OnClick", function() openReport(row.entry) end)
        row.caption = CreateLabel(row, "", "GameFontHighlightSmall")
        row.caption:SetPoint("LEFT", 11, 0)
        row.caption:SetPoint("RIGHT", copy, "LEFT", -10, 0)
        row.caption:SetJustifyH("LEFT")
        row.caption:SetWordWrap(false)
        rows[i] = row
    end
    bar:SetScript("OnValueChanged", renderRows)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(math.max(0, math.min(#visible - rowCount, bar:GetValue() - delta)))
    end)

    local updateFilter
    local function refresh()
        rowCount = math.max(1, math.floor(list:GetHeight() / 31))
        for i = #rows + 1, rowCount do addRow(i) end
        visible = {}
        for _, entry in ipairs(db.logs) do
            if not source or source == entry.source then
                visible[#visible + 1] = entry
            end
        end
        if source and #visible == 0 then source = false; return refresh() end
        local limit = math.max(0, #visible - rowCount)
        bar:SetMinMaxValues(0, math.max(1, limit))
        bar:SetValue(math.min(limit, bar:GetValue()))
        bar:SetShown(limit > 0)
        empty:SetShown(#visible == 0)
        updateFilter()
        renderRows()
    end
    local filter
    filter, updateFilter = dropdown(logs, 180, addons, function() return source end, function(value)
        source = value
        bar:SetValue(0)
        refresh()
    end)
    filter:SetPoint("TOPRIGHT", -18, -10)
    local test = theme:CreateButton(logs, "Test Lua error", 115, 26)
    test:SetPoint("RIGHT", filter, "LEFT", -10, 0)
    test:SetScript("OnClick", function()
        source = false
        bar:SetValue(0)
        bugs.TestError()
    end)
    StaticPopupDialogs.BAZI_CLEAR_BUG_LOG = {
        text = "Clear all saved Lua errors?",
        button1 = "Clear", button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function()
            bugs.Clear()
            popup:Hide()
            source = false
            bar:SetValue(0)
            refresh()
        end,
    }
    local clear = theme:CreateButton(logs, "Clear log", 96, 25)
    clear:SetPoint("BOTTOMRIGHT", -18, 12)
    clear:SetScript("OnClick", function()
        if #db.logs > 0 then StaticPopup_Show("BAZI_CLEAR_BUG_LOG") end
    end)
    local revision
    page:SetScript("OnUpdate", function()
        if revision ~= bugs.revision then
            revision = bugs.revision
            refresh()
        end
    end)
    logs:SetScript("OnSizeChanged", refresh)
    page:SetScript("OnShow", refresh)
    refresh()
end

local function CreateInventoryPage()
    local inventory = addon.Inventory
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Inventory = page
    local db = inventory.Settings()
    local header = CreatePanel(page, -8, 76)
    CreateSection(header, "INVENTORY", -14)
    local function update(key, value)
        if key == "fontSize" or key == "emptyFontSize" then addon.Typography.ModuleChanged("Inventory:Items", "size") end
        if key == "capacityFontSize" then addon.Typography.ModuleChanged("Inventory:Capacity", "size") end
        if key == "cleanupFontSize" then addon.Typography.ModuleChanged("Inventory:Cleanup", "size") end
        db[key] = value
        inventory.UpdateWindows()
        if key == "showAmmoCapacity" or key == "showReagentCapacity" then
            addon.Dashboard.Invalidate("supplies")
            addon.Dashboard.Invalidate("status")
        end
    end
    local function check(parent, key, label, x, y)
        local button = addon.Theme:CreateCheckbox(parent)
        button:SetSize(25, 25)
        button:SetPoint("TOPLEFT", x, y)
        button:SetChecked(db[key])
        CreateLabel(button, label, "GameFontHighlight"):SetPoint("LEFT", button, "RIGHT", 5, 0)
        button:SetScript("OnClick", function(self) update(key, not not self:GetChecked()) end)
    end
    check(header, "enabled", "Enable Inventory", 16, -42)
    local panel = CreatePanel(page, -101, 330)
    panel:SetPoint("BOTTOMLEFT", 12, 10)
    local sections, tabs = {}, {}
    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", panel, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 145)
    function page:SelectSubpage(name)
        for key, section in pairs(sections) do
            local selected = key:lower() == name:lower()
            section:SetShown(selected)
            addon.Theme:StyleSettingsTab(tabs[key], selected)
            tabs[key].label:SetTextColor(1, selected and 0.85 or 0.80, selected and 0.55 or 0.66)
        end
    end
    for i, name in ipairs({"Bags", "Categories", "Cleanup", "Loot", "Rolls"}) do
        local tab = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        tab:SetSize(108, 29)
        tab:SetPoint("TOPLEFT", 0, -(i - 1) * 29)
        tab:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        tab:SetBackdropBorderColor(0.54, 0.37, 0.20, 0.95)
        tab.fill = tab:CreateTexture(nil, "BACKGROUND")
        tab.fill:SetAllPoints()
        tab.label = CreateLabel(tab, name, "GameFontNormal")
        tab.label:SetPoint("LEFT", 9, 0)
        tab:SetScript("OnClick", function() page:SelectSubpage(name) end)
        tabs[name] = tab
        local host = CreateFrame("Frame", nil, panel)
        host:SetAllPoints()
        sections[name] = host
    end
    local function slider(parent, label, key, min, max, y, stepper)
        local control = CreateSlider(parent, label, "", min, max, 1, db[key], y,
            function(value) update(key, value) end, true, true)
        parent:HookScript("OnShow", function() control:DisplayValue(db[key]) end)
        if stepper then
            local row = control:GetParent()
            control:ClearAllPoints()
            control:SetPoint("RIGHT", row, "RIGHT", -110, 0)
            control.valueBox:ClearAllPoints()
            control.valueBox:SetPoint("RIGHT", row, "RIGHT", -68, 0)
            for i, delta in ipairs({-1, 1}) do
                local button = inventory.Button(row, delta == 1 and "+" or "-", 22,
                    function() control:SetValue(math.max(min, math.min(max, control:GetValue() + delta))) end)
                button:SetPoint("RIGHT", i == 1 and -40 or -16, 0)
            end
        end
    end
    local function action(parent, label, callback, y)
        local button = inventory.Button(parent, label, 130, callback)
        button:SetPoint("TOPRIGHT", -15, y or -49)
    end

    local bags = inventory.Scroll(sections.Bags, -12, 8)
    bags:SetHeight(720)
    action(bags, "Open inventory", function() inventory.OpenBags() end, -183)
    local bagChecks = {
        {"locked", "Lock windows"}, {"growUp", "Grow upwards"}, {"emptyTop", "Empty slots at top"},
        {"removeBorder", "Remove border"}, {"hideIcons", "Hide icons"}, {"quality", "Item quality"},
        {"junk", "Grey out junk items"}, {"unusable", "Mark unusable equipment in red"},
        {"flash", "Flash new items"}, {"merchant", "Auto-open at vendors"}, {"bank", "Auto-open at bank"},
        {"auction", "Auto-open at auction house"}, {"guild", "Auto-open at guild bank"},
        {"hideKeyCount", "Hide empty keyring count"}, {"bagsOnAlt", "Show bag buttons only with Alt"},
        {"hideEmptyCategory", "Hide Empty bag category"},
        {"showAmmoCapacity", "Show quiver or ammo bag"}, {"showReagentCapacity", "Show reagent bag"},
    }
    for i, spec in ipairs(bagChecks) do
        check(bags, spec[1], spec[2], (i % 2 == 1) and 12 or 223, -4 - math.floor((i - 1) / 2) * 26)
    end
    for i, spec in ipairs({
        {"BAG COLUMNS", "columns", 4, 30}, {"BANK COLUMNS", "bankColumns", 4, 30},
        {"GUILD BANK COLUMNS", "guildColumns", 4, 30}, {"ICON SIZE", "size", 20, 52},
        {"ICON FONT SIZE", "fontSize", 8, 22}, {"EMPTY SLOT COUNT SIZE", "emptyFontSize", 8, 26},
        {"CAPACITY TEXT SIZE", "capacityFontSize", 8, 24},
        {"BACKGROUND OPACITY (%)", "opacity", 0, 100},
        {"X OFFSET", "x", -2000, 2000, true}, {"Y OFFSET", "y", -1200, 1200, true},
    }) do
        slider(bags, spec[1], spec[2], spec[3], spec[4], -213 - (i - 1) * 47, spec[5])
    end
    local categories = sections.Categories
    CreateSection(categories, "BAG CATEGORIES", -14)
    local input = CreateFrame("EditBox", nil, categories, "InputBoxTemplate")
    input:SetAutoFocus(false)
    input:SetSize(175, 24)
    input:SetMaxLetters(32)
    input:SetPoint("TOPLEFT", 24, -50)
    local status = CreateLabel(categories, "", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 23, -83)
    local categoryList = inventory.Scroll(categories, -108, 12)
    local categoryRows = {}
    local refreshCategories
    local function move(from, to)
        inventory.MoveCategory(from, to)
        refreshCategories()
    end
    refreshCategories = function()
        for i, name in ipairs(db.categories) do
            local row = categoryRows[i]
            if not row then
                local index = i
                row = inventory.Button(categoryList, "", 145, function()
                    local kind, id = GetCursorInfo()
                    if kind ~= "item" or not id then return end
                    db.assignments[id] = db.categories[index]
                    ClearCursor()
                    inventory.RefreshBags()
                end)
                row:SetPoint("TOPLEFT", 12, -(i - 1) * 28)
                row:RegisterForDrag("LeftButton")
                row:SetScript("OnDragStart", function() end)
                row:SetScript("OnDragStop", function()
                    for target, button in ipairs(categoryRows) do
                        if button:IsMouseOver() then move(index, target); break end
                    end
                end)
                row:SetScript("OnReceiveDrag", row:GetScript("OnClick"))
                local up = inventory.Button(row, "^", 27, function() move(index, index - 1) end)
                up:SetPoint("LEFT", row, "RIGHT", 5, 0)
                local down = inventory.Button(row, "v", 27, function() move(index, index + 1) end)
                down:SetPoint("LEFT", up, "RIGHT", 3, 0)
                row.up, row.down = up, down
                categoryRows[i] = row
            end
            row:SetText(name)
            row.up:SetEnabled(i > 1)
            row.down:SetEnabled(i < #db.categories)
        end
        categoryList:SetHeight(math.max(1, #db.categories * 28))
    end
    local function addCategory()
        local value = input:GetText():match("^%s*(.-)%s*$")
        local lower = value:lower()
        if value == "" or lower == "empty" or lower == "recent" or value:find("|", 1, true) then
            status:SetText("Enter a category name other than Recent or Empty.")
            return
        end
        for _, name in ipairs(db.categories) do
            if name:lower() == lower then status:SetText("That category already exists."); return end
        end
        db.categories[#db.categories + 1] = value
        input:SetText("")
        input:ClearFocus()
        status:SetText("")
        refreshCategories()
        inventory.RefreshBags()
    end
    input:SetScript("OnEnterPressed", addCategory)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local add = inventory.Button(categories, "Add category", 105, addCategory)
    add:SetPoint("LEFT", input, "RIGHT", 8, 0)
    categories:HookScript("OnShow", refreshCategories)
    local cleanup = inventory.Scroll(sections.Cleanup, -4, 8)
    cleanup:SetHeight(225)
    check(cleanup, "cleanup", "Enable bag cleanup", 20, -50)
    slider(cleanup, "MAXIMUM ITEM QUALITY TO DELETE (0–4)", "maxDeleteQuality", 0, 4, -85)
    slider(cleanup, "BACKGROUND OPACITY (%)", "cleanupOpacity", 0, 100, -132)
    slider(cleanup, "TEXT SIZE (0 = GENERAL)", "cleanupFontSize", 0, 20, -179)
    local loot = sections.Loot
    check(loot, "lootSkin", "Style the loot window", 20, -16)
    slider(loot, "BACKGROUND OPACITY (%)", "lootOpacity", 0, 100, -52)
    slider(loot, "LOOT STACK WIDTH", "lootWidth", 345, 800, -99, true)
    slider(loot, "LOOT X OFFSET", "lootX", -2000, 2000, -146, true)
    slider(loot, "LOOT Y OFFSET", "lootY", -1200, 1200, -193, true)
    local placement = inventory.Button(loot, "Toggle layout preview", 160, inventory.ToggleLootPreview)
    placement:SetPoint("TOPRIGHT", -15, -16)
    local rolls = inventory.Scroll(sections.Rolls, -4, 8)
    rolls:SetHeight(385)
    check(rolls, "rolls", "Enable loot rolls", 20, -50)
    check(rolls, "openRoll", "Open on roll", 20, -78)
    check(rolls, "rollGlow", "Glow on hovered button", 20, -106)
    check(rolls, "rollTips", "Roll button tooltip", 20, -134)
    check(rolls, "rollAnimations", "Animations", 20, -162)
    action(rolls, "Toggle roll test", function() inventory.ToggleRolls(true) end)
    local openRolls = inventory.Button(rolls, "Toggle loot rolls", 130, function() inventory.ToggleRolls(false) end)
    openRolls:SetPoint("TOPRIGHT", -15, -79)
    check(rolls, "hideRollGuide", "Hide Need, Greed and Pass guide", 20, -190)
    slider(rolls, "BACKGROUND OPACITY (%)", "rollOpacity", 0, 100, -224)
    page:SelectSubpage("Bags")
end

local function CreatePlaceholderPage(name, description)
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages[name] = page

    local placeholderPanel = CreatePanel(page, -12, 130)
    CreateSection(placeholderPanel, name, -14)
    CreateDivider(placeholderPanel, -48)

    local message = CreateLabel(page, description or "Settings for this module will appear here.", "GameFontHighlight")
    message:SetParent(placeholderPanel)
    message:SetPoint("TOPLEFT", placeholderPanel, "TOPLEFT", 22, -76)
    message:SetTextColor(0.96, 0.82, 0.63, 1)

    return page
end

local hudOptions = {
    {"durability", "Durability"}, {"vehicle", "Leave Vehicle"}, {"buffs", "Buffs"}, {"debuffs", "Debuffs"},
    {"player", "Player Cast"}, {"target", "Target Cast"}, {"breath", "Breath"}, {"fatigue", "Fatigue"},
    {"ammo", "Hunter Ammo"},
}

local function CreateHUDPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.HUD = page
    local menu = CreatePanel(page, -8, 105)
    local views, tabs = {}, {}
    local auraPreview, castPreview, durabilityPreview, vehiclePreview
    local function refreshLabels()
        for key, view in pairs(views) do
            if view.preview then
                local state = key == "durability" and durabilityPreview or key == "vehicle" and vehiclePreview or view.auras and auraPreview
                    or view.cast and castPreview
                local text = view.ammoPreview and ("Preview: " .. view.ammoPreview)
                    or state and "Stop preview" or view.previewText
                view.preview:SetText(text)
            end
        end
    end
    local function makeView(key, titleText, index)
        local host = CreateFrame("Frame", nil, page)
        host:SetPoint("TOPLEFT", 0, -122)
        host:SetPoint("BOTTOMRIGHT")
        host:Hide()
        local content = addon.Inventory.Scroll(host, -5, 7)
        local panel = CreatePanel(content, 0, 350)
        CreateSection(panel, titleText, -14)
        local cfg = addon.HUD.Settings(key)
        local isAura = key == "buffs" or key == "debuffs"
        local isAmmo = key == "ammo"
        local isCast = index > 4 and not isAmmo
        local view = {frame = host, auras = isAura, cast = isCast}
        views[key] = view
        local apply = isAmmo and addon.HUDAmmo.Refresh or isAura and addon.HUDAuras.Refresh
            or isCast and addon.CastBars.Refresh or addon.HUD.RefreshNative

        local function toggle(label, field, x, y)
            local check = addon.Theme:CreateCheckbox(panel)
            check:SetSize(24, 24)
            check:SetPoint("TOPLEFT", x, y)
            local text = CreateLabel(panel, label, "GameFontHighlight")
            text:SetPoint("LEFT", check, "RIGHT", 5, 0)
            check:SetChecked(cfg[field] == true)
            check:SetScript("OnClick", function(self) cfg[field] = not not self:GetChecked(); apply() end)
            return check
        end
        toggle("Enable " .. titleText, "enabled", 24, -43)
        local previewToggle
        if isAmmo then
            view.previewText = "Preview ammunition"
            previewToggle = function() view.ammoPreview = addon.HUDAmmo.Preview(true) end
            host:HookScript("OnHide", function() view.ammoPreview = addon.HUDAmmo.Preview(false); refreshLabels() end)
        elseif key == "durability" then
            view.previewText = "Preview durability"
            previewToggle = function() durabilityPreview = addon.HUD.PreviewDurability() end
        elseif key == "vehicle" then
            view.previewText = "Preview exit button"
            previewToggle = function() vehiclePreview = addon.HUD.PreviewVehicle() end
            host:HookScript("OnHide", function()
                vehiclePreview = addon.HUD.PreviewVehicle(false)
                refreshLabels()
            end)
        elseif isAura then
            view.previewText = "Preview buffs and debuffs"
            previewToggle = function() auraPreview = addon.HUDAuras.TogglePreview() end
        elseif isCast then
            view.previewText = "Preview cast bars and timers"
            previewToggle = function() castPreview = addon.CastBars.TogglePreview() end
        end
        if previewToggle then
            view.preview = addon.Theme:CreateButton(panel, view.previewText, 193, 25)
            view.preview:SetPoint("TOPRIGHT", -24, -43)
            view.preview:SetScript("OnClick", function() previewToggle(); refreshLabels() end)
        end
        local y = -81
        local function numeric(label, field, min, max, default, stepper, unitField, unitLabel)
            local function setting()
                if unitField and cfg.attachToUnitFrame ~= false then return unitField end
                return field
            end
            local slider = CreateSlider(panel, label, "", min, max, 1, cfg[setting()] or default, y,
                function(value)
                    cfg[setting()] = value
                    if field == "fontSize" then addon.Typography.ModuleChanged(isAura and "HUD:Aura" or "HUD:Bar", "size") end
                    apply()
                end, true, true)
            if stepper then
                local row = slider:GetParent()
                slider:ClearAllPoints()
                slider:SetPoint("RIGHT", row, "RIGHT", -110, 0)
                slider.valueBox:ClearAllPoints()
                slider.valueBox:SetPoint("RIGHT", row, "RIGHT", -66, 0)
                for i, delta in ipairs({-1, 1}) do
                    local button = addon.Theme:CreateButton(row, delta == 1 and "+" or "-", 22, 22)
                    button:SetPoint("RIGHT", row, "RIGHT", i == 1 and -39 or -13, 0)
                    button:SetScript("OnClick", function()
                        slider:SetValue(math.max(min, math.min(max, slider:GetValue() + delta)))
                    end)
                end
            end
            local function refresh()
                local activeField = setting()
                slider.heading:SetText(activeField == unitField and unitLabel or label)
                slider:DisplayValue(cfg[activeField] or default)
            end
            host:HookScript("OnShow", refresh)
            refresh()
            y = y - 44
            return refresh
        end

        if key == "player" or key == "target" then
            local check = toggle("Attach above unit frame", "attachToUnitFrame", 24, y)
            check:SetChecked(cfg.attachToUnitFrame ~= false)
            y = y - 33
            local refreshX = numeric("X OFFSET FROM CENTER", "x", -2200, 2200, 0, true,
                "unitX", "X OFFSET FROM UNIT FRAME")
            local refreshY = numeric("Y OFFSET FROM CENTER", "y", -1400, 1400, 0, true,
                "unitY", "Y OFFSET FROM UNIT FRAME")
            check:HookScript("OnClick", function()
                refreshX()
                refreshY()
            end)
        else
            numeric("X OFFSET FROM CENTER", "x", -2200, 2200, 0, true)
            numeric("Y OFFSET FROM CENTER", "y", -1400, 1400, 0, true)
        end
        if isAmmo then
            numeric("WIDTH", "width", 70, 320, 104, true)
            numeric("HEIGHT", "height", 22, 100, 35, true)
            numeric("ICON SIZE", "iconSize", 10, 80, 23, true)
            numeric("SCALE (%)", "scale", 65, 200, 100)
            numeric("LOW AMMUNITION", "low", 1, 1500, 200)
            numeric("CRITICAL AMMUNITION", "critical", 0, 500, 50)
            toggle("Only show when low", "onlyLow", 24, y)
            toggle("Play sound", "sound", 240, y)
            y = y - 32
            toggle("Show warning text", "warning", 24, y)
            toggle("Show warnings in chat", "chatWarning", 240, y)
            y = y - 36
            local sounds = {{"raidWarning", "Raid warning"}, {"none", "No sound"}}
            for _, sound in ipairs(addon.Chat.Alerts.SOUNDS) do
                sounds[#sounds + 1] = {sound.key, sound.label or sound.file}
            end
            for _, setting in ipairs({{"Low ammunition sound", "lowSound"}, {"Critical ammunition sound", "criticalSound"}}) do
                local label, field = unpack(setting)
                CreateLabel(panel, label, "GameFontHighlight"):SetPoint("TOPLEFT", 26, y - 3)
                local choice = addon.Theme:CreateSettingsDropdown(panel)
                choice:SetSize(180, 27)
                choice:SetPoint("TOPRIGHT", -35, y)
                local function selectedSound()
                    return addon.HUD.Settings("ammo")[field]
                end
                local function refreshSound()
                    local chosen = selectedSound()
                    for _, sound in ipairs(sounds) do
                        if chosen == sound[1] then choice:SetText(sound[2]); return end
                    end
                    choice:SetText(chosen or sounds[1][2])
                end
                choice:SetupMenu(function(_, root)
                    for _, sound in ipairs(sounds) do
                        local soundKey, name = unpack(sound)
                        root:CreateRadio(name, function() return selectedSound() == soundKey end, function()
                            addon.HUD.Settings("ammo")[field] = soundKey
                            refreshSound()
                            addon.HUDAmmo.PlayWarningSound(soundKey)
                        end)
                    end
                end)
                choice:HookScript("OnShow", refreshSound)
                refreshSound()
                y = y - 39
            end
        elseif isAura then
            numeric("ICON SIZE", "size", 14, 64, 32)
            numeric("COLUMNS", "columns", 1, 24, 10, true)
            numeric("ROWS", "rows", 1, 16, 4, true)
            numeric("TEXT SIZE", "fontSize", 8, 25, 11)
            CreateLabel(panel, "Duration text position", "GameFontHighlight"):SetPoint("TOPLEFT", 26, y - 3)
            local choice = addon.Theme:CreateSettingsDropdown(panel)
            choice:SetSize(165, 27)
            choice:SetPoint("TOPRIGHT", -35, y)
            choice:SetupMenu(function(_, root)
                for _, position in ipairs({"Below", "Above", "Left", "Right", "Center"}) do
                    root:CreateRadio(position, function() return cfg.text == position end, function()
                        cfg.text = position
                        choice:SetText(position)
                        apply()
                    end)
                end
            end)
            choice:SetText(cfg.text)
            y = y - 41
            toggle("Fill columns first", "vertical", 24, y)
            toggle("Grow left", "left", 205, y)
            toggle("Grow upward", "up", 340, y)
            y = y - 33
        elseif isCast then
            numeric("WIDTH", "width", 80, 800, 225, true)
            numeric("HEIGHT", "height", 12, 72, 20, true)
            numeric("TEXT SIZE", "fontSize", 8, 36, 12)
            numeric("TEXT WIDTH (0 = AUTO)", "textWidth", 0, 700, 0)
            numeric("TEXT X OFFSET", "textX", -120, 180, 0, true)
            numeric("TEXT Y OFFSET", "textY", -90, 90, 0, true)
            numeric("BACKGROUND OPACITY (%)", "opacity", 0, 100, 65)
            if key == "target" then
                toggle("Icon on right side", "iconOnRight", 24, y)
                y = y - 33
            end
        end
        panel:SetHeight(-y + 3)
        content:SetHeight(-y + 15)
    end
    function page:SelectSubpage(key)
        local view = views[key]
        if not view then return end
        for name, item in pairs(views) do
            item.frame:SetShown(name == key)
            addon.Theme:SetButtonActive(tabs[name], name == key)
        end
        refreshLabels()
    end
    for index, entry in ipairs(hudOptions) do
        local key, titleText = unpack(entry)
        local tab = addon.Theme:CreateButton(menu, titleText, 114, 26)
        tab:SetPoint("TOPLEFT", 15 + ((index - 1) % 4) * 121, -8 - math.floor((index - 1) / 4) * 31)
        tab:SetScript("OnClick", function() page:SelectSubpage(key) end)
        tabs[key] = tab
        makeView(key, titleText, index)
    end
    page:SelectSubpage("durability")
end

local function CreateDialoguePage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Dialogue = page
    local content = addon.Inventory.Scroll(page, 0, 5)
    content:SetHeight(561)
    local panel = CreatePanel(content, -8, 543)
    local dialogue, cfg = addon.Dialogue, addon.Dialogue.Settings()
    CreateSection(panel, "NPC and quest dialogs", -14)
    local function toggle(label, key, y)
        local check = addon.Theme:CreateCheckbox(panel)
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", 27, y)
        check:SetChecked(cfg[key] == true)
        local text = CreateLabel(panel, label, "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 6, 0)
        check:SetScript("OnClick", function(self) cfg[key] = not not self:GetChecked(); dialogue.Refresh() end)
    end
    toggle("Enable Bazi UI dialogue style", "enabled", -51)
    toggle("Tint quests added in Forever", "tint", -83)
    toggle("Compact reader grows upward", "readerGrowUp", -108)
    for index, entry in ipairs({{"BACKGROUND OPACITY (%)", "opacity", 0, 100}, {"WINDOW SCALE (%)", "scale", 75, 160}}) do
        local label, key, min, max = unpack(entry)
        local slider = CreateSlider(panel, label, "", min, max, 1, cfg[key], -140 - (index - 1) * 43,
            function(value) cfg[key] = value; dialogue.Refresh() end, true, true)
        page:HookScript("OnShow", function() slider:DisplayValue(cfg[key]) end)
    end
    local positions = {
        {"NPC WINDOW X", "x"}, {"NPC WINDOW Y", "y"},
        {"COMPACT READER X", "readerX"}, {"COMPACT READER Y", "readerY"},
    }
    for index, entry in ipairs(positions) do
        local label, key = unpack(entry)
        local slider = CreateSlider(panel, label, "From screen center", -2200, 2200, 1, cfg[key], -228 - (index - 1) * 43,
            function(value) cfg[key] = value; dialogue.Refresh() end, true, true)
        page:HookScript("OnShow", function() slider:DisplayValue(cfg[key]) end)
    end
    CreateSlider(panel, "NPC OPTION TEXT SIZE", "", 10, 28, 1, cfg.optionFontSize, -405,
        function(value)
            cfg.optionFontSize = value
            if addon.Typography.ModuleChanged then addon.Typography.ModuleChanged("Dialogue:Options", "size") end
            dialogue.Refresh()
        end, true, true)
    local readerHeight = CreateSlider(panel, "COMPACT READER MAX HEIGHT", "", 220, 600, 1, cfg.readerMaxHeight, -448,
        function(value) cfg.readerMaxHeight = value; dialogue.Refresh() end, true, true)
    page:HookScript("OnShow", function() readerHeight:DisplayValue(cfg.readerMaxHeight) end)
    local showDialogue = addon.Theme:CreateButton(panel, "Preview NPC window", 165, 25)
    showDialogue:SetPoint("TOPLEFT", 26, -494)
    showDialogue:SetScript("OnClick", function() dialogue.Preview("main") end)
    local showReader = addon.Theme:CreateButton(panel, "Preview compact reader", 176, 25)
    showReader:SetPoint("LEFT", showDialogue, "RIGHT", 8, 0)
    showReader:SetScript("OnClick", function() dialogue.Preview("reader") end)
    page:HookScript("OnHide", function() dialogue.Preview(nil) end)
end

local function CreateProfilesPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Profiles = page
    local database = addon.Database
    local content, _, profileScroll = addon.Inventory.Scroll(page, -3, 5)
    content:SetHeight(533)
    local selected = "template:" .. database:DefaultProfile()
    local selectedLabel = database:DefaultProfile()
    local managed = database:DefaultProfile()
    local active = CreatePanel(content, -8, 156)
    CreateSection(active, "Profiles", -14)
    CreateDivider(active, -48)

    local function label(parent, caption, y)
        local text = CreateLabel(parent, caption, "GameFontHighlight")
        text:SetPoint("TOPLEFT", 22, y)
        return text
    end
    local function templates()
        local items = {}
        for _, name in ipairs(database:ListProfiles()) do items[#items + 1] = {name, name} end
        return items
    end
    local function dropdown(parent, y, choices, read, write)
        local control = addon.Theme:CreateSettingsDropdown(parent)
        control:SetSize(190, 28)
        control:SetPoint("TOPRIGHT", -22, y)
        control:SetupMenu(function(_, root)
            local items = choices()
            if #items > 10 and root.SetScrollMode then root:SetScrollMode(260) end
            for _, item in ipairs(items) do
                local key, caption = item[1], item[2]
                root:CreateRadio(caption, function() return read() == key end, function() write(key, caption) end)
            end
        end)
        return control
    end

    local activeLabel = label(active, "", -66)
    label(active, "Copy from", -99)
    local copy = addon.Theme:CreateButton(active, "Copy profile", 130, 25)
    copy:SetPoint("TOPRIGHT", -22, -120)
    local copyHint = "Copies settings into this character's profile and reloads the UI."
    local copyHelp = label(active, copyHint, -125)
    local chooser
    chooser = dropdown(active, -93, function() return database:CopySources() end,
        function() return selected end, function(key, caption)
            selected, selectedLabel = key, caption
            chooser:SetText(caption)
            copyHelp:SetText(copyHint)
        end)
    StaticPopupDialogs.BAZI_COPY_PROFILE = {
        text = 'Replace this character\'s settings with a copy of "%s"?',
        button1 = "Copy profile", button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, key)
            local _, reason = database:CopyProfile(key)
            if reason then copyHelp:SetText(reason) end
        end,
    }
    copy:SetScript("OnClick", function() StaticPopup_Show("BAZI_COPY_PROFILE", selectedLabel, nil, selected) end)

    local defaults = CreatePanel(content, -173, 94)
    CreateSection(defaults, "New characters", -14)
    label(defaults, "Starting template", -47)
    local defaultChooser
    defaultChooser = dropdown(defaults, -41, templates, function() return database:DefaultProfile() end, function(name)
        database:SetDefaultProfile(name)
        defaultChooser:SetText(database:DefaultProfile())
    end)
    label(defaults, "Each new character gets a profile under its own name.", -69)

    local create = CreatePanel(content, -276, 112)
    CreateSection(create, "Create template", -14)
    label(create, "Template name", -52)
    local name = CreateFrame("EditBox", nil, create, "InputBoxTemplate")
    name:SetSize(170, 25)
    name:SetPoint("LEFT", create, "TOPLEFT", 133, -58)
    name:SetAutoFocus(false)
    name:SetMaxLetters(48)
    name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local feedback = label(create, "", -87)
    feedback:SetPoint("RIGHT", create, "RIGHT", -22, 0)
    feedback:SetJustifyH("LEFT")
    local refresh
    local function createProfile(copyCurrent)
        local created, errorText = database:CreateProfile(name:GetText(), copyCurrent)
        if not created then feedback:SetText(errorText); return end
        selected, selectedLabel = "template:" .. created, created
        managed = created
        name:SetText("")
        name:ClearFocus()
        refresh()
        feedback:SetText('Saved "' .. created .. '" as a template.')
    end
    name:SetScript("OnEnterPressed", function() createProfile(true) end)
    local blank = addon.Theme:CreateButton(create, "Create blank", 118, 25)
    blank:SetPoint("TOPRIGHT", -22, -46)
    blank:SetScript("OnClick", function() createProfile(false) end)
    local save = addon.Theme:CreateButton(create, "Save current settings", 150, 25)
    save:SetPoint("RIGHT", blank, "LEFT", -8, 0)
    save:SetScript("OnClick", function() createProfile(true) end)

    local manage = CreatePanel(content, -397, 128)
    CreateSection(manage, "Saved templates", -14)
    label(manage, "Template", -52)
    local manageChooser
    manageChooser = dropdown(manage, -46, templates, function() return managed end, function(value)
        managed = value
        refresh()
    end)
    local delete = addon.Theme:CreateButton(manage, "Delete", 80, 25)
    delete:SetPoint("TOPRIGHT", -22, -85)
    local export = addon.Theme:CreateButton(manage, "Export addon defaults", 154, 25)
    export:SetPoint("RIGHT", delete, "LEFT", -8, 0)
    StaticPopupDialogs.BAZI_DELETE_PROFILE_TEMPLATE = {
        text = 'Delete the saved template "%s"? Character profiles will keep their settings.',
        button1 = DELETE, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, value)
            if not database:DeleteProfile(value) then return end
            if selected == "template:" .. value then selected, selectedLabel = "template:Default", "Default" end
            if managed == value then managed = "Default" end
            refresh()
        end,
    }
    delete:SetScript("OnClick", function()
        StaticPopup_Show("BAZI_DELETE_PROFILE_TEMPLATE", managed, nil, managed)
    end)

    local exportWindow = CreateFrame("Frame", nil, page, "BackdropTemplate")
    exportWindow:SetSize(570, 350)
    exportWindow:SetPoint("CENTER")
    exportWindow:SetFrameStrata("FULLSCREEN_DIALOG")
    exportWindow:EnableMouse(true)
    exportWindow:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
    local r, g, b = unpack(addon.Theme.colors.window)
    exportWindow:SetBackdropColor(r, g, b, 1)
    exportWindow:SetBackdropBorderColor(unpack(addon.Theme.colors.frameBorder))
    addon.Theme:TrackWindowBorder(exportWindow)
    CreateSection(exportWindow, "Export addon defaults", -14)
    label(exportWindow, "Ctrl+C to copy. Save the text as Config/DefaultProfile.lua in the addon.", -46)
    local scroll = CreateFrame("ScrollFrame", nil, exportWindow, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -72)
    scroll:SetPoint("BOTTOMRIGHT", -36, 48)
    local output = CreateFrame("EditBox", nil, scroll)
    output:SetMultiLine(true)
    output:SetAutoFocus(false)
    output:SetFontObject(GameFontHighlightSmall)
    output:SetHeight(1)
    scroll:SetScrollChild(output)
    scroll:SetScript("OnSizeChanged", function(_, width) output:SetWidth(math.max(1, width)) end)
    output:SetScript("OnEscapePressed", function() exportWindow:Hide() end)
    exportWindow:SetScript("OnHide", function() output:ClearFocus() end)
    local closeExport = addon.Theme:CreateButton(exportWindow, "Close", 74, 24)
    closeExport:SetPoint("BOTTOMRIGHT", -18, 14)
    closeExport:SetScript("OnClick", function() exportWindow:Hide() end)
    exportWindow:Hide()
    export:SetScript("OnClick", function()
        local code = database:ExportDefaults(managed)
        if not code then return end
        exportWindow:Show()
        output:SetText(code)
        output:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
        output:SetFocus()
        output:HighlightText()
    end)

    refresh = function()
        activeLabel:SetText("Character profile  ·  " .. database:ActiveProfile())
        chooser:SetText(selectedLabel)
        defaultChooser:SetText(database:DefaultProfile())
        manageChooser:SetText(managed)
        delete:SetEnabled(managed ~= "Default")
    end
    page:SetScript("OnShow", refresh)
    function page:SelectSubpage(name)
        if name == "Export" then
            C_Timer.After(0, function()
                if page:IsShown() then profileScroll:SetValue(select(2, profileScroll:GetMinMaxValues())) end
            end)
        end
    end
    refresh()
    return page
end



local function CreateUnitFramesPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.UnitFrames = page
    local db = addon.db.profile.unitframes
    local activeTab = "General"
    local tabButtons, tabPanels = {}, {}
    local syncControls = {}

    local headingPanel = CreatePanel(page, -8, 76)
    CreateSection(headingPanel, "UNIT FRAMES", -12)
    local enabled = addon.Theme:CreateCheckbox(headingPanel)
    enabled:SetSize(25, 25)
    enabled:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 16, -41)
    -- Set the initial state immediately: OnShow is not guaranteed to fire
    -- when this page is constructed while already visible.
    enabled:SetChecked(db.enabled ~= false)
    local enabledLabel = CreateLabel(headingPanel, "Enable Unit Frames", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    enabled:SetScript("OnClick", function(self)
        db.enabled = not not self:GetChecked()
        if addon.UnitFrames then addon.UnitFrames:Refresh() end
    end)

    local copyControls = {}
    local copyDropdowns = {}
    local copyHeader = CreateFrame("Frame", nil, headingPanel)
    copyHeader:SetPoint("TOPRIGHT", headingPanel, "TOPRIGHT", -16, -8)
    copyHeader:SetSize(360, 52)
    local main = CreatePanel(page, -100, 400)
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
    main:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    if main.SetClipsChildren then main:SetClipsChildren(true) end

    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", main, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 261)
    local BuildTab
    local function RefreshTabs()
        copyHeader:SetShown(activeTab ~= "General")
        for _,dropdown in ipairs(copyDropdowns) do dropdown:Hide() end
        for name, controls in pairs(copyControls) do controls:SetShown(name == activeTab) end
        for name, button in pairs(tabButtons) do
            local selected = name == activeTab
            addon.Theme:StyleSettingsTab(button, selected)
            button.label:SetTextColor(selected and 1 or 0.95,
                selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54,
                selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do
                edge:SetColorTexture(selected and 0.83 or 0.54,
                    selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95)
            end
        end
        for name, panel in pairs(tabPanels) do panel:SetShown(name == activeTab) end
        if syncControls[activeTab] then syncControls[activeTab]() end
    end
    for i, name in ipairs({"General", "Player", "Target", "Focus", "Pet", "Target of Target", "Boss", "Party", "Raid"}) do
        local button = CreateFrame("Button", nil, tabBar)
        button:SetSize(108, 29)
        button:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -(i-1)*29)
        button.fill = button:CreateTexture(nil, "BACKGROUND")
        button.fill:SetAllPoints()
        button.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = button:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            button.edges[#button.edges+1] = edge
        end
        button.accent = button:CreateTexture(nil, "OVERLAY")
        button.accent:SetPoint("TOPRIGHT"); button.accent:SetPoint("BOTTOMRIGHT")
        button.accent:SetWidth(3)
        button.label = CreateLabel(button, name, "GameFontNormal")
        button.label:SetPoint("LEFT", button, "LEFT", 12, 0)
        button:SetScript("OnClick", function()
            if not tabPanels[name] then BuildTab(name) end
            activeTab = name
            RefreshTabs()
        end)
        button:SetScript("OnEnter", function()
            if activeTab ~= name then addon.Theme:Paint(button.fill, "muted", 0.98) end
        end)
        button:SetScript("OnLeave", RefreshTabs)
        tabButtons[name] = button
    end

    function page:SelectSubpage(name)
        if tabButtons[name] then tabButtons[name]:Click() end
    end

    local tabKeys = {Player = "player", Target = "target", Focus = "focus", Pet = "pet",
        ["Target of Target"] = "targettarget", Boss = "boss", Party = "party", Raid = "raid"}
    BuildTab = function(name)
        local key = tabKeys[name]
        local function CreateTabSlider(parent, title, description, min, max, step, value, y, onChange, compact)
            return CreateSlider(parent, title, description, min, max, step, value, y, onChange, compact, key ~= "raid")
        end
        local viewport = CreateFrame("ScrollFrame", nil, main)
        viewport:Hide()
        viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -12)
        viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 10)
        viewport:EnableMouseWheel(true)
        local panel = CreateFrame("Frame", nil, viewport)
        panel:SetHeight(name == "General" and 480 or 490)
        panel:SetWidth(500)
        viewport:SetScrollChild(panel)
        viewport:SetScript("OnSizeChanged", function(self) panel:SetWidth(math.max(1, self:GetWidth())) end)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta*36)))
        end)
        tabPanels[name] = viewport
        if name == "General" then
            CreateSection(panel, "VISIBLE UNIT FRAMES", -12)
            CreateDivider(panel, -45)
            for i, item in ipairs({{"Player","player"},{"Target","target"},{"Focus","focus"},{"Pet","pet"},{"Target of Target","targettarget"}}) do
                local check = addon.Theme:CreateCheckbox(panel)
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60-(i-1)*36)
                local label = CreateLabel(panel, item[1], "GameFontHighlight")
                label:SetPoint("LEFT", check, "RIGHT", 5, 0)
                local key = item[2]
                check:SetScript("OnClick", function(self)
                    db[key] = not not self:GetChecked()
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end)
                page:HookScript("OnShow", function() check:SetChecked(db[key] == true) end)
                check:SetChecked(db[key] == true)
            end
            db.groups = db.groups or {}
            local function enableGroup(kind, caption, y)
                db.groups[kind] = db.groups[kind] or {}
                local opt = db.groups[kind]
                local check = addon.Theme:CreateCheckbox(panel)
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT",panel,"TOPLEFT",16,y)
                local label = CreateLabel(panel,caption,"GameFontHighlight")
                label:SetPoint("LEFT",check,"RIGHT",5,0)
                check:SetChecked(opt.enabled == true)
                check:SetScript("OnClick",function(self)
                    opt.enabled = self:GetChecked() == true
                    if addon.GroupFrames then addon.GroupFrames:Refresh() end
                end)
                page:HookScript("OnShow",function() check:SetChecked(opt.enabled == true) end)
            end
            enableGroup("boss","Enable Boss",-240)
            enableGroup("party","Enable Party",-276)
            enableGroup("raid","Enable Raid",-312)
            local move = addon.Theme:CreateCheckbox(panel)
            move:SetSize(25,25)
            move:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -358)
            local moveLabel = CreateLabel(panel, "Move UnitFrames", "GameFontHighlight")
            moveLabel:SetPoint("LEFT", move, "RIGHT", 5, 0)
            move:SetScript("OnClick", function(self)
                local enabled=self:GetChecked()==true
                if not addon.UnitFrames:SetMoveMode(enabled) then
                    self:SetChecked(addon.UnitFrames:IsMoveMode())
                    addon:Print("Cannot move unit frames during combat.")
                    return
                end
                for _,module in ipairs({addon.BossFrames,addon.PartyFrames,addon.RaidFrames}) do
                    if module and module.SetMoveMode then module:SetMoveMode(enabled) end
                end
            end)
            local function syncMoveMode() move:SetChecked(addon.UnitFrames:IsMoveMode()) end
            page:HookScript("OnShow", syncMoveMode)
            syncMoveMode()
        elseif (key == "party" or key == "boss") or key == "raid" or key == "boss" then
            db.groups = db.groups or {}
            db.groups[key] = db.groups[key] or {}
            local opt = db.groups[key]
            local function refreshGroup()
                if addon.GroupFrames then addon.GroupFrames:Refresh() end
                if key=="boss" and addon.BossFrames then addon.BossFrames:Refresh() end
                if key=="raid" and addon.RaidFrames then addon.RaidFrames:Refresh() end
            end
            local selectedMember = 1
            local memberRefreshers = {}
            local function memberSettings()
                opt.members = opt.members or {}
                opt.members[selectedMember] = opt.members[selectedMember] or {}
                return opt.members[selectedMember]
            end
            local function memberValue(field,default)
                local member=memberSettings()
                if member[field] ~= nil then return member[field] end
                if opt[field] ~= nil then return opt[field] end
                return default
            end
            local function refreshMemberControls()
                for _,refresh in ipairs(memberRefreshers) do refresh() end
            end
            local sourceKind, sourceIndex = "player", 1
            local memberCount = key=="raid" and 40 or (key=="party" and 4 or 5)
            local function headerButton(parent,label,x,width)
                local button=CreateFrame("Button",nil,parent)
                button:SetSize(width,28)
                button:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-4)
                local fill=button:CreateTexture(nil,"BACKGROUND")
                fill:SetAllPoints()
                fill:SetColorTexture(.24,.12,.06,.98)
                local edges={}
                for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
                    local line=button:CreateTexture(nil,"OVERLAY")
                    line:SetColorTexture(.72,.53,.29,.9)
                    if side=="TOP" then line:SetPoint("TOPLEFT");line:SetPoint("TOPRIGHT");line:SetHeight(1)
                    elseif side=="BOTTOM" then line:SetPoint("BOTTOMLEFT");line:SetPoint("BOTTOMRIGHT");line:SetHeight(1)
                    elseif side=="LEFT" then line:SetPoint("TOPLEFT");line:SetPoint("BOTTOMLEFT");line:SetWidth(1)
                    else line:SetPoint("TOPRIGHT");line:SetPoint("BOTTOMRIGHT");line:SetWidth(1) end
                    edges[#edges+1]=line
                end
                local caption=CreateLabel(button,label,"GameFontNormal")
                caption:SetPoint("CENTER")
                return button,caption
            end
            local memberButton,memberText=headerButton(copyHeader,"",0,104)
            local sourceButton,sourceText=headerButton(copyHeader,"",110,112)
            local copyButton=headerButton(copyHeader,"Copy settings",228,128)
            local applyButton=headerButton(headingPanel,"Apply to all",16,125)
            applyButton:ClearAllPoints()
            applyButton:SetPoint("TOPRIGHT",headingPanel,"TOPRIGHT",-388,-10)
            local sourceChoices={{"Player","player",1},{"Target","target",1},{"Focus","focus",1},{"Pet","pet",1},{"Target of Target","targettarget",1}}
            for _,kind in ipairs({"party","boss","raid"}) do
                local count=kind=="raid" and 40 or kind=="party" and 4 or 5
                for index=1,count do
                    sourceChoices[#sourceChoices+1]={string.upper(kind:sub(1,1))..kind:sub(2).." "..index,kind,index}
                end
            end
            local sourceCursor=1
            local function refreshHeader()
                memberText:SetText(key:sub(1,1):upper()..key:sub(2).." "..selectedMember.." / "..memberCount.."  v")
                sourceText:SetText("From: "..sourceChoices[sourceCursor][1].."  v")
            end
            -- Scrollable selection lists: never cycle through 40+ frames.
            local function makeDropdown(trigger,items,onSelect)
                local visible=math.min(9,#items)
                local popup=CreateFrame("Frame",nil,copyHeader)
                popup:SetSize(185,visible*26+8)
                popup:SetPoint("TOPLEFT",trigger,"BOTTOMLEFT",0,-3)
                popup:SetFrameStrata("FULLSCREEN_DIALOG")
                popup:SetFrameLevel(trigger:GetFrameLevel()+25)
                popup:EnableMouse(true)
                local bg=popup:CreateTexture(nil,"BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(.13,.075,.035,.98)
                local border=CreateFrame("Frame",nil,popup,"BackdropTemplate")
                border:SetAllPoints()
                border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
                border:SetBackdropBorderColor(.76,.56,.29,1)
                addon.Theme:TrackWindowBorder(border)
                local offset=1
                local entries={}
                local function redraw()
                    for i,entry in ipairs(entries) do
                        local item=items[offset+i-1]
                        entry:SetShown(item~=nil)
                        if item then entry.text:SetText(item.label) end
                    end
                end
                for i=1,visible do
                    local entry=CreateFrame("Button",nil,popup)
                    entry:SetSize(173,25)
                    entry:SetPoint("TOPLEFT",popup,"TOPLEFT",6,-4-(i-1)*26)
                    local highlight=entry:CreateTexture(nil,"BACKGROUND")
                    highlight:SetAllPoints()
                    highlight:SetColorTexture(.32,.17,.09,.95)
                    highlight:Hide()
                    entry:SetScript("OnEnter",function() highlight:Show() end)
                    entry:SetScript("OnLeave",function() highlight:Hide() end)
                    entry.text=CreateLabel(entry,"","GameFontNormal")
                    entry.text:SetPoint("LEFT",entry,"LEFT",7,0)
                    entry:SetScript("OnClick",function()
                        local item=items[offset+i-1]
                        if item then onSelect(item);popup:Hide() end
                    end)
                    entries[i]=entry
                end
                popup:EnableMouseWheel(true)
                popup:SetScript("OnMouseWheel",function(_,delta)
                    offset=math.max(1,math.min(math.max(1,#items-visible+1),offset-delta))
                    redraw()
                end)
                popup:Hide()
                trigger:SetScript("OnClick",function()
                    local open=not popup:IsShown()
                    for _,other in ipairs(copyDropdowns) do other:Hide() end
                    if open then offset=1;redraw();popup:Show() end
                end)
                copyDropdowns[#copyDropdowns+1]=popup
                return popup
            end
            local memberItems={}
            for i=1,memberCount do
                memberItems[i]={label=key:sub(1,1):upper()..key:sub(2).." "..i,index=i}
            end
            local sourceItems={}
            for i,choice in ipairs(sourceChoices) do
                sourceItems[i]={label=choice[1],index=i}
            end
            local memberPopup=makeDropdown(memberButton,memberItems,function(item)
                selectedMember=item.index
                refreshHeader()
                refreshMemberControls()
            end)
            local sourcePopup=makeDropdown(sourceButton,sourceItems,function(item)
                sourceCursor=item.index
                sourceKind,sourceIndex=sourceChoices[sourceCursor][2],sourceChoices[sourceCursor][3]
                refreshHeader()
            end)
            copyButton:SetScript("OnClick",function()
                if addon.GroupFrames then addon.GroupFrames:CopyMember(key,sourceKind,sourceIndex,selectedMember) end
                refreshMemberControls()
            end)
            applyButton:SetScript("OnClick",function()
                if addon.GroupFrames then addon.GroupFrames:ApplyToAll(key,selectedMember) end
            end)
            refreshHeader()
            copyControls[name]={SetShown=function(_,shown) memberButton:SetShown(shown);sourceButton:SetShown(shown);copyButton:SetShown(shown);applyButton:SetShown(shown) end}
            local root = panel
            local sections = {}
            local sectionButtons = {}
            local function selectSection(selected)
                for label, canvas in pairs(sections) do canvas:SetShown(label == selected) end
                for label, button in pairs(sectionButtons) do
                    addon.Theme:Paint(button.fill, label == selected and "purple" or "panel", 1)
                end
                root:SetHeight((key=="party" or key=="boss") and (selected=="Layout" and 1350 or selected=="Indicators" and 1350 or selected=="Bar Text" and 820 or selected=="Buffs / Debuffs" and 1230 or 580) or (key=="raid" and selected=="Layout" and 1350 or 610))
                viewport:SetVerticalScroll(0)
            end
            for i, label in ipairs({"Layout","Indicators","Bar Text","Fonts","Buffs / Debuffs"}) do
                local button = CreateFrame("Button",nil,root)
                button:SetSize(94,30)
                button:SetPoint("TOPLEFT",root,"TOPLEFT",12+(i-1)*96,-5)
                local bg=button:CreateTexture(nil,"BACKGROUND")
                bg:SetAllPoints()
                local title=CreateLabel(button,label,"GameFontNormal")
                title:SetPoint("CENTER")
                title:SetTextColor(1,0.82,0.52)
                button:SetScript("OnClick",function() selectSection(label) end)
                button.fill=bg
                sectionButtons[label] = button
                local canvas = CreateFrame("Frame",nil,root)
                canvas:SetPoint("TOPLEFT",root,"TOPLEFT",0,-48)
                canvas:SetPoint("TOPRIGHT",root,"TOPRIGHT",0,-48)
                canvas:SetHeight(540)
                canvas:Hide()
                sections[label] = canvas
            end
            panel = sections.Layout
            CreateSection(panel, string.upper(key) .. " LAYOUT", -12)
            CreateDivider(panel,-45)
            local function toggle(label, field, x, y)
                local check = addon.Theme:CreateCheckbox(panel)
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
                local caption = CreateLabel(panel,label,"GameFontHighlight")
                caption:SetPoint("LEFT",check,"RIGHT",5,0)
                check:SetChecked(opt[field] == true)
                check:SetScript("OnClick",function(self)
                    opt[field] = self:GetChecked() == true
                    refreshGroup()
                end)
                page:HookScript("OnShow",function() check:SetChecked(opt[field] == true) end)
            end
            toggle("Show when solo","showSolo",16,-62)
            local function setting(label,field,default,min,max,step,x,y,shared)
                local syncing=false
                local function current()
                    if shared then return tonumber(opt[field]) or default end
                    return tonumber(memberValue(field,default)) or default
                end
                local row = CreateTabSlider(panel,string.upper(label),label,min,max,step,current(),y,function(value)
                    if syncing then return end
                    if shared then opt[field]=value else memberSettings()[field]=value end
                    refreshGroup()
                end,false)
                local function refresh()
                    syncing=true
                    row:SetValue(current())
                    syncing=false
                end
                memberRefreshers[#memberRefreshers+1]=refresh
                page:HookScript("OnShow",refresh)
            end
            if (key=="party" or key=="boss") then
                local function nudge(label,field,x,y)
                    local caption=CreateLabel(panel,label,"GameFontNormal")
                    caption:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
                    local value=CreateLabel(panel,"0","GameFontHighlight")
                    value:SetPoint("LEFT",caption,"RIGHT",20,0)
                    local function redraw() value:SetText(tostring(tonumber(memberValue(field,0)) or 0)) end
                    for step,dx in pairs({[-1]=155,[1]=187}) do
                        local button=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
                        button:SetSize(29,24)
                        button:SetPoint("TOPLEFT",panel,"TOPLEFT",x+dx,y+5)
                        button:SetText(step<0 and "-" or "+")
                        button:SetScript("OnClick",function()
                            memberSettings()[field]=(tonumber(memberValue(field,0)) or 0)+step
                            redraw()
                            refreshGroup()
                        end)
                    end
                    memberRefreshers[#memberRefreshers+1]=redraw
                    redraw()
                end
            end
            if (key=="party" or key=="boss") then
                -- One full-width row per control, matching Player's layout.
                setting("HP / Mana Width","width",190,80,360,5,16,-125)
                setting("HP Height","hpHeight",23,12,45,1,16,-205)
                setting("Mana / Power Height","powerHeight",9,4,30,1,16,-285)
                setting("Portrait Size","portraitSize",60,36,90,1,16,-365)
                setting("Portrait X","portraitX",0,-40,40,1,16,-445)
                setting("Portrait Y","portraitY",0,-40,40,1,16,-525)
            else
                setting("Frame width","width",key~="raid" and 190 or 110,80,360,5,16,-125)
                setting("Frame height","height",key~="raid" and 48 or 30,22,90,1,270,-190)
                setting("Spacing","spacing",8,0,40,1,16,-255,true)
                setting("Name font size (0 hides)","nameFontSize",11,0,22,1,270,-320)
            end
            if key=="raid" then
                setting("Vertical spacing","verticalSpacing",8,0,80,1,270,-580,true)
                setting("Columns","columns",5,1,8,1,16,-385,true)
                setting("Horizontal offset","x",-380,-700,700,10,270,-450,true)
                setting("Vertical offset","y",-250,-500,500,10,16,-515,true)
                -- Raid group anchor: same dark/gold dropdown interaction as Tooltip.
                local choices={
                    {"TOPLEFT","Right / Down"},
                    {"TOPRIGHT","Left / Down"},
                    {"BOTTOMLEFT","Right / Up"},
                    {"BOTTOMRIGHT","Left / Up"},
                }
                local title=CreateLabel(panel,"GROUP ANCHOR","GameFontNormal")
                title:SetPoint("TOPLEFT",panel,"TOPLEFT",270,-655)
                title:SetTextColor(1,.79,.42)
                local anchorButton=CreateFrame("Button",nil,panel)
                anchorButton:SetSize(195,27)
                anchorButton:SetPoint("TOPLEFT",panel,"TOPLEFT",270,-677)
                local bg=anchorButton:CreateTexture(nil,"BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(.12,.07,.045,1)
                local border=anchorButton:CreateTexture(nil,"BORDER")
                border:SetPoint("TOPLEFT");border:SetPoint("TOPRIGHT");border:SetHeight(1)
                border:SetColorTexture(.75,.55,.29,1)
                local arrow=CreateLabel(anchorButton,"v","GameFontHighlightSmall")
                arrow:SetPoint("RIGHT",anchorButton,"RIGHT",-7,0)
                local valueText=CreateLabel(anchorButton,"","GameFontNormal")
                valueText:SetPoint("CENTER")
                valueText:SetTextColor(1,.79,.42)
                local menu=CreateFrame("Frame",nil,panel)
                menu:SetSize(195,#choices*24+4)
                menu:SetPoint("TOPLEFT",anchorButton,"BOTTOMLEFT",0,-2)
                menu:SetFrameStrata("FULLSCREEN_DIALOG")
                menu:SetFrameLevel(anchorButton:GetFrameLevel()+25)
                local menuBg=menu:CreateTexture(nil,"BACKGROUND")
                menuBg:SetAllPoints()
                menuBg:SetColorTexture(.12,.07,.045,1)
                local function redrawAnchor()
                    local selected=opt.anchor or "TOPLEFT"
                    for _,choice in ipairs(choices) do
                        if choice[1]==selected then valueText:SetText(choice[2]);return end
                    end
                    valueText:SetText("Right / Down")
                end
                for i,choice in ipairs(choices) do
                    local item=CreateFrame("Button",nil,menu)
                    item:SetPoint("TOPLEFT",menu,"TOPLEFT",2,-2-(i-1)*24)
                    item:SetPoint("TOPRIGHT",menu,"TOPRIGHT",-2,-2-(i-1)*24)
                    item:SetHeight(24)
                    local fill=item:CreateTexture(nil,"BACKGROUND")
                    fill:SetAllPoints()
                    fill:SetColorTexture(.12,.07,.045,1)
                    local itemText=CreateLabel(item,choice[2],"GameFontHighlightSmall")
                    itemText:SetPoint("LEFT",item,"LEFT",8,0)
                    item:SetScript("OnEnter",function() fill:SetColorTexture(.34,.18,.11,1) end)
                    item:SetScript("OnLeave",function() fill:SetColorTexture(.12,.07,.045,1) end)
                    item:SetScript("OnClick",function()
                        opt.anchor=choice[1]
                        menu:Hide()
                        redrawAnchor()
                        refreshGroup()
                    end)
                end
                anchorButton:SetScript("OnClick",function() menu:SetShown(not menu:IsShown()) end)
                page:HookScript("OnHide",function() menu:Hide() end)
                page:HookScript("OnShow",redrawAnchor)
                menu:Hide()
                redrawAnchor()
                -- Move the entire raid group, independently of per-member offsets.
                local function groupCoordinate(label,field,y)
                    local title=CreateLabel(panel,label,"GameFontNormal")
                    title:SetPoint("TOPLEFT",panel,"TOPLEFT",16,y)
                    title:SetTextColor(1,.79,.42)
                    local edit=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
                    edit:SetSize(76,24)
                    edit:SetPoint("TOPLEFT",panel,"TOPLEFT",16,y-22)
                    edit:SetAutoFocus(false)
                    edit:SetMaxLetters(9)
                    edit:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
                    local function current() return tonumber(opt[field]) or 0 end
                    local function redraw()
                        if not edit:HasFocus() then edit:SetText(tostring(current())) end
                    end
                    local function apply(value)
                        if InCombatLockdown and InCombatLockdown() then redraw();return end
                        if value==nil then redraw();return end
                        opt[field]=math.floor(value)
                        edit:ClearFocus()
                        redraw()
                        refreshGroup()
                    end
                    edit:SetScript("OnEnterPressed",function(self) apply(tonumber(self:GetText())) end)
                    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus();redraw() end)
                    edit:SetScript("OnEditFocusLost",redraw)
                    for i,delta in ipairs({1,-1}) do
                        local button=CreateFrame("Button",nil,panel)
                        button:SetSize(22,13)
                        button:SetPoint("TOPLEFT",edit,"TOPRIGHT",4,-(i-1)*13)
                        local bg=button:CreateTexture(nil,"BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(.23,.12,.065,1)
                        local buttonText=CreateLabel(button,delta==1 and "+" or "-","GameFontNormalSmall")
                        buttonText:SetPoint("CENTER")
                        buttonText:SetTextColor(1,.79,.42)
                        button:SetScript("OnClick",function() apply(current()+delta) end)
                    end
                    memberRefreshers[#memberRefreshers+1]=redraw
                    redraw()
                end
                groupCoordinate("RAID GROUP X","x",-755)
                groupCoordinate("RAID GROUP Y","y",-805)
                panel:SetHeight(1250)
                -- Explicit scroll control for Raid Layout, including when child controls capture the wheel.
                local function scrollRaid(delta)
                    local limit=math.max(0,root:GetHeight()-viewport:GetHeight())
                    viewport:SetVerticalScroll(math.max(0,math.min(limit,viewport:GetVerticalScroll()-delta*48)))
                end
                panel:EnableMouseWheel(true)
                panel:SetScript("OnMouseWheel",function(_,delta) scrollRaid(delta) end)
                local scrollUp=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
                scrollUp:SetSize(26,25)
                scrollUp:SetPoint("TOPRIGHT",main,"TOPRIGHT",-15,-52)
                scrollUp:SetText("▲")
                scrollUp:SetScript("OnClick",function() scrollRaid(1) end)
                local scrollDown=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
                scrollDown:SetSize(26,25)
                scrollDown:SetPoint("BOTTOMRIGHT",main,"BOTTOMRIGHT",-15,20)
                scrollDown:SetText("▼")
                scrollDown:SetScript("OnClick",function() scrollRaid(-1) end)
                page:HookScript("OnShow",function()
                    local shown=activeTab=="Raid"
                    scrollUp:SetShown(shown)
                    scrollDown:SetShown(shown)
                end)
            end
            local function groupRefresh()
                refreshGroup()
            end
            local function groupSlider(canvas,title,hint,field,min,max,default,y)
                local syncing=false
                local slider = CreateTabSlider(canvas,title,hint,min,max,1,memberValue(field,default),y,function(value)
                    if syncing then return end
                    if value ~= memberValue(field,default) and (field == "fontSize" or field:match("FontSize$")) then
                        addon.Typography.ModuleChanged("UnitFrames", "size")
                    end
                    memberSettings()[field] = value
                    groupRefresh()
                end,false)
                local function refresh()
                    syncing=true
                    slider:SetValue(memberValue(field,default))
                    syncing=false
                end
                memberRefreshers[#memberRefreshers+1]=refresh
                page:HookScript("OnShow",refresh)
            end
            local partyDropdown
            if (key=="party" or key=="boss") then
                -- Same compact edit field and stacked +/- controls as Player.
                local function coordinate(canvas,label,field,x,y,default)
                    local title=CreateLabel(canvas,label,"GameFontNormal")
                    title:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y)
                    title:SetTextColor(1,.79,.42)
                    local edit=CreateFrame("EditBox",nil,canvas,"InputBoxTemplate")
                    edit:SetSize(76,24)
                    edit:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y-22)
                    edit:SetAutoFocus(false)
                    edit:SetMaxLetters(9)
                    edit:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
                    local function current() return tonumber(memberValue(field,default or 0)) or (default or 0) end
                    local function redraw()
                        if not edit:HasFocus() then edit:SetText(tostring(current())) end
                    end
                    local function apply(value)
                        if not value then redraw();return end
                        memberSettings()[field]=math.floor(value)
                        edit:ClearFocus()
                        redraw()
                        groupRefresh()
                    end
                    edit:SetScript("OnEnterPressed",function(self) apply(tonumber(self:GetText())) end)
                    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus();redraw() end)
                    for i,delta in ipairs({1,-1}) do
                        local button=CreateFrame("Button",nil,canvas)
                        button:SetSize(22,13)
                        button:SetPoint("TOPLEFT",edit,"TOPRIGHT",4,-(i-1)*13)
                        local bg=button:CreateTexture(nil,"BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(.23,.12,.065,1)
                        local text=CreateLabel(button,delta==1 and "+" or "-","GameFontNormalSmall")
                        text:SetPoint("CENTER")
                        text:SetTextColor(1,.79,.42)
                        button:SetScript("OnClick",function() apply(current()+delta) end)
                    end
                    memberRefreshers[#memberRefreshers+1]=redraw
                    redraw()
                end
                -- Matching the dark-gold dropdown design already used by Player/Tooltip.
                partyDropdown = function(canvas,label,field,choices,x,y,width,default)
                    width=width or 170
                    local title=CreateLabel(canvas,label,"GameFontNormal")
                    title:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y)
                    title:SetTextColor(1,.79,.42)
                    local button=CreateFrame("Button",nil,canvas)
                    button:SetSize(width,27)
                    button:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y-22)
                    local bg=button:CreateTexture(nil,"BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(.12,.07,.045,1)
                    local border=button:CreateTexture(nil,"BORDER")
                    border:SetPoint("TOPLEFT");border:SetPoint("TOPRIGHT");border:SetHeight(1)
                    border:SetColorTexture(.75,.55,.29,1)
                    local arrow=CreateLabel(button,"v","GameFontHighlightSmall")
                    arrow:SetPoint("RIGHT",button,"RIGHT",-7,0)
                    local valueText=CreateLabel(button,"","GameFontNormal")
                    valueText:SetPoint("CENTER")
                    valueText:SetTextColor(1,.79,.42)
                    local menu=CreateFrame("Frame",nil,canvas)
                    menu:SetSize(width,#choices*24+4)
                    menu:SetPoint("TOPLEFT",button,"BOTTOMLEFT",0,-2)
                    menu:SetFrameStrata("FULLSCREEN_DIALOG")
                    menu:SetFrameLevel(button:GetFrameLevel()+25)
                    local menuBg=menu:CreateTexture(nil,"BACKGROUND")
                    menuBg:SetAllPoints()
                    menuBg:SetColorTexture(.12,.07,.045,1)
                    local function redraw()
                        local value=memberValue(field,default or choices[1][1])
                        for _,choice in ipairs(choices) do
                            if choice[1]==value then valueText:SetText(choice[2]);return end
                        end
                        valueText:SetText("Custom")
                    end
                    for i,choice in ipairs(choices) do
                        local item=CreateFrame("Button",nil,menu)
                        item:SetPoint("TOPLEFT",menu,"TOPLEFT",2,-2-(i-1)*24)
                        item:SetPoint("TOPRIGHT",menu,"TOPRIGHT",-2,-2-(i-1)*24)
                        item:SetHeight(24)
                        local fill=item:CreateTexture(nil,"BACKGROUND")
                        fill:SetAllPoints()
                        fill:SetColorTexture(.12,.07,.045,1)
                        local itemText=CreateLabel(item,choice[2],"GameFontHighlightSmall")
                        itemText:SetPoint("LEFT",item,"LEFT",8,0)
                        item:SetScript("OnEnter",function() fill:SetColorTexture(.34,.18,.11,1) end)
                        item:SetScript("OnLeave",function() fill:SetColorTexture(.12,.07,.045,1) end)
                        item:SetScript("OnClick",function()
                            memberSettings()[field]=choice[1]
                            menu:Hide()
                            redraw()
                            groupRefresh()
                        end)
                    end
                    button:SetScript("OnClick",function() menu:SetShown(not menu:IsShown()) end)
                    menu:Hide()
                    memberRefreshers[#memberRefreshers+1]=function() menu:Hide();redraw() end
                    redraw()
                end
                local function anchorButton(canvas,label,field,x,y)
                    partyDropdown(canvas,label,field,{{"LEFT","Left"},{"CENTER","Center"},{"RIGHT","Right"},{"HIDDEN","Hidden"}},x,y,190,"CENTER")
                end
                partyDropdown(sections.Layout,"BAR GRADIENT DARK SIDE","gradientDirection",{{"RIGHT","Right"},{"LEFT","Left"}},260,-730,190,"RIGHT")
                partyDropdown(sections.Layout,"PORTRAIT SIDE","portraitSide",{{"LEFT","Left"},{"RIGHT","Right"}},16,-730,190,selectedMember<=2 and "LEFT" or "RIGHT")
                if key~="boss" then coordinate(sections.Indicators,"ROLE PORTRAIT X","roleX",16,-910)
                coordinate(sections.Indicators,"ROLE PORTRAIT Y","roleY",260,-910)
                -- Existing profiles may store 1.5 instead of 150; normalize on edit.
                local roleSetting=memberSettings()
                if tonumber(roleSetting.rolePortraitScale) and tonumber(roleSetting.rolePortraitScale)<=5 then
                    roleSetting.rolePortraitScale=math.floor(roleSetting.rolePortraitScale*100+0.5)
                end
                coordinate(sections.Indicators,"ROLE SCALE %","rolePortraitScale",16,-995,150) end
                coordinate(sections.Layout,"FRAME X","offsetX",16,-670)
                coordinate(sections.Layout,"FRAME Y","offsetY",260,-670)
                coordinate(sections["Bar Text"],"NAME X","nameX",16,-470)
                coordinate(sections["Bar Text"],"NAME Y","nameY",260,-470)
                coordinate(sections["Bar Text"],"HP TEXT X","hpTextX",16,-560)
                coordinate(sections["Bar Text"],"HP TEXT Y","hpTextY",260,-560)
                coordinate(sections["Bar Text"],"POWER TEXT X","powerTextX",16,-650)
                coordinate(sections["Bar Text"],"POWER TEXT Y","powerTextY",260,-650)
                anchorButton(sections["Bar Text"],"Name anchor","nameAnchor",20,-310)
                anchorButton(sections["Bar Text"],"HP anchor","hpTextAnchor",270,-310)
                anchorButton(sections["Bar Text"],"Power anchor","powerTextAnchor",20,-385)
                for i,item in ipairs({{"PVP","pvp"},{"LEADER","leader"},{"RAID","raid"},{"ROLE","role"},{"CLASSIFICATION","classification"}}) do
                    coordinate(sections.Indicators,item[1].." X",item[2].."X",16,-430-(i-1)*90)
                    coordinate(sections.Indicators,item[1].." Y",item[2].."Y",260,-430-(i-1)*90)
                end
                local canvas=sections.Layout
                local check=addon.Theme:CreateCheckbox(canvas)
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT",canvas,"TOPLEFT",16,-810)
                local label=CreateLabel(canvas,"Show castbar","GameFontHighlight")
                label:SetPoint("LEFT",check,"RIGHT",5,0)
                local function syncCast() check:SetChecked(memberValue("showPartyCast",true)~=false) end
                check:SetScript("OnClick",function(self)
                    memberSettings().showPartyCast=self:GetChecked()==true
                    groupRefresh()
                end)
                memberRefreshers[#memberRefreshers+1]=syncCast
                syncCast()
                -- Castbar positioning is separate from cast spell text positioning.
                coordinate(canvas,"CASTBAR X","partyCastX",16,-860)
                coordinate(canvas,"CASTBAR Y","partyCastY",260,-860)
                coordinate(canvas,"CASTBAR WIDTH","partyCastWidth",16,-950,190)
                coordinate(canvas,"CASTBAR HEIGHT","partyCastHeight",260,-950,13)
                coordinate(canvas,"CAST TEXT X","partyCastTextX",16,-1040)
                coordinate(canvas,"CAST TEXT Y","partyCastTextY",260,-1040)
                groupSlider(sections.Fonts,"CASTBAR TEXT SIZE","Cast spell name font size","partyCastFontSize",0,24,10,-425)
            end
            panel=sections.Indicators
            if (key=="party" or key=="boss") then panel:SetHeight(1250) end
            CreateSection(panel,"INDICATORS",-12)
            CreateDivider(panel,-45)
            local function groupToggle(canvas,label,field,y)
                local check=addon.Theme:CreateCheckbox(canvas)
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT",canvas,"TOPLEFT",20,y)
                local text=CreateLabel(canvas,label,"GameFontHighlight")
                text:SetPoint("LEFT",check,"RIGHT",5,0)
                local default = field ~= "firstNameOnly"
                check:SetChecked(memberValue(field,default) == true)
                check:SetScript("OnClick",function(self) memberSettings()[field]=self:GetChecked()==true;groupRefresh() end)
                local function refresh() check:SetChecked(memberValue(field,default) == true) end
                memberRefreshers[#memberRefreshers+1]=refresh
                page:HookScript("OnShow",refresh)
            end
            if (key~="party" and key~="boss") then groupToggle(panel,"Show names","showName",-75) end
            if (key~="party" and key~="boss") then groupToggle(panel,"Show power bar","showPower",-115) end
            groupToggle(panel,"PvP indicator","showPvP",-155)
            groupToggle(panel,"Group leader indicator","showLeader",-195)
            groupToggle(panel,"Raid target marker","showRaidMarker",-235)
            groupToggle(panel,"Role indicator","showRole",-275)
            groupToggle(panel,"Classification indicator","showClassification",-315)
            groupToggle(panel,"Level label","showLevel",-355)
            groupToggle(panel,"First name only","firstNameOnly",-395)
            panel=sections["Bar Text"]
            CreateSection(panel,"BAR TEXT",-12)
            CreateDivider(panel,-45)
            if (key=="party" or key=="boss") then
                groupToggle(panel,"Show names","showName",-245)
                local function textMode(label,field,y)
                    partyDropdown(panel,label.." TEXT",field,{
                        {"","Hidden"},
                        {"{current}","Current"},
                        {"{current} / {max}","Current / Max"},
                        {"{percent}","Percent"},
                        {"{current} ({percent})","Current (Percent)"}
                    },20,y,220,"{current} / {max}")
                end
                textMode("Health","hpText",-75)
                textMode("Power","powerText",-155)
            else
                groupToggle(panel,"Show health percentage","showHealthPercent",-75)
                groupToggle(panel,"Show power percentage","showPowerPercent",-115)
            end
            groupToggle(panel,"Incoming Healing","incomingHealing",-285)
            panel=sections.Fonts
            CreateSection(panel,"FONTS",-12)
            CreateDivider(panel,-45)
            if (key~="party" and key~="boss") then groupSlider(panel,"NAME FONT SIZE","Size of the unit name (0 hides it)","fontSize",0,22,11,-65) end
            if (key=="party" or key=="boss") then
                groupSlider(panel,"NAME FONT SIZE","Name text (0 hides)","nameFontSize",0,22,11,-65)
                groupSlider(panel,"HP FONT SIZE","HP value text","hpFontSize",0,24,12,-155)
                groupSlider(panel,"POWER FONT SIZE","Power value text","powerFontSize",0,24,11,-245)
                groupSlider(panel,"LEVEL FONT SIZE","Size of the level label","levelFontSize",0,22,11,-335)
            end
            panel=sections["Buffs / Debuffs"]
            CreateSection(panel,"BUFFS / DEBUFFS",-12)
            CreateDivider(panel,-45)
            if (key=="party" or key=="boss") then
                local function auraSettings(kind,x)
                    local label=CreateLabel(panel,string.upper(kind),"GameFontNormal")
                    label:SetPoint("TOPLEFT",panel,"TOPLEFT",x,kind=="buffs" and -65 or -460)
                    local check=addon.Theme:CreateCheckbox(panel)
                    check:SetSize(25,25)
                    check:SetPoint("TOPLEFT",panel,"TOPLEFT",x,kind=="buffs" and -100 or -495)
                    local text=CreateLabel(panel,"Enable "..kind,"GameFontHighlight")
                    text:SetPoint("LEFT",check,"RIGHT",5,0)
                    local function aura()
                        local member=memberSettings()
                        local field="aura_"..kind
                        member[field]=member[field] or {}
                        return member[field]
                    end
                    local function refresh()
                        check:SetChecked(aura().enabled==true)
                    end
                    check:SetScript("OnClick",function(self)
                        aura().enabled=self:GetChecked()==true
                        groupRefresh()
                    end)
                    memberRefreshers[#memberRefreshers+1]=refresh
                    page:HookScript("OnShow",refresh)
                    refresh()
                    local function auraSlider(title,field,default,min,max,y)
                        local syncing=false
                        local slider=CreateTabSlider(panel,title,title,min,max,1,tonumber(aura()[field]) or default,y,function(value)
                            if syncing then return end
                            aura()[field]=value
                            groupRefresh()
                        end,false)
                        local function sync()
                            syncing=true
                            slider:SetValue(tonumber(aura()[field]) or default)
                            syncing=false
                        end
                        memberRefreshers[#memberRefreshers+1]=sync
                        page:HookScript("OnShow",sync)
                    end
                    auraSlider(string.upper(kind).." SIZE","size",24,12,48,kind=="buffs" and -155 or -550)
                    auraSlider(string.upper(kind).." COUNT","count",12,1,40,kind=="buffs" and -220 or -615)
                    auraSlider(string.upper(kind).." X","x",0,-250,250,kind=="buffs" and -285 or -680)
                    auraSlider(string.upper(kind).." Y","y",kind=="buffs" and 32 or -58,-250,250,kind=="buffs" and -350 or -745)
                end
                auraSettings("buffs",18)
                auraSettings("debuffs",18)
                panel:SetHeight(1160)
                root:SetHeight(1230)
            else
                local note=CreateLabel(panel,"Aura containers for this group type are not yet implemented.","GameFontHighlight")
                note:SetPoint("TOPLEFT",panel,"TOPLEFT",18,-72)
            end
            selectSection("Layout")
        else
            db.frames = db.frames or {}
            local own = db.frames[key] or {}
            db.frames[key] = own
            local refreshers = {}
            -- Compact subnavigation: each category has its own canvas.
            local rootPanel = panel
            local groups = {}
            for _, category in ipairs({"Layout", "Indicators", "Bar Text", "Fonts", "Buffs / Debuffs"}) do
                local canvas = CreateFrame("Frame", nil, rootPanel)
                canvas:SetPoint("TOPLEFT", rootPanel, "TOPLEFT", 0, -49)
                canvas:SetPoint("TOPRIGHT", rootPanel, "TOPRIGHT", 0, -49)
                canvas:SetHeight(category == "Indicators" and (name == "Pet" and 930 or 590) or (category == "Buffs / Debuffs" and 510 or (category == "Bar Text" and name == "Target" and 690 or 520)))
                canvas:Hide()
                groups[category] = canvas
            end
            local activeGroup = "Layout"
            local groupButtons = {}
            local function selectGroup(category)
                activeGroup = category
                for label, canvas in pairs(groups) do canvas:SetShown(label == category) end
                for label, button in pairs(groupButtons) do
                    addon.Theme:Paint(button.fill, label == category and "purple" or "panel", 1)
                end
                rootPanel:SetHeight(category == "Indicators" and (name == "Pet" and 950 or 610) or (category == "Buffs / Debuffs" and 550 or (category == "Bar Text" and name == "Target" and 730 or (category == "Layout" and 540 or 490))))
                viewport:SetVerticalScroll(0)
            end
            for i, category in ipairs({"Layout", "Indicators", "Bar Text", "Fonts", "Buffs / Debuffs"}) do
                local button = CreateFrame("Button", nil, rootPanel)
                button:SetSize(94, 30)
                button:SetPoint("TOPLEFT", rootPanel, "TOPLEFT", 12 + (i-1)*(96), -5)
                button.fill = button:CreateTexture(nil, "BACKGROUND")
                button.fill:SetAllPoints()
                local text = CreateLabel(button, category, "GameFontNormal")
                text:SetPoint("CENTER")
                text:SetTextColor(1, 0.81, 0.46)
                button:SetScript("OnClick", function() selectGroup(category) end)
                groupButtons[category] = button
            end
            panel = groups.Layout
            local settings = {
                {"barWidth","HP / MANA WIDTH","Width of health and resource bars",100,400},
                {"hpHeight","HP HEIGHT","Health bar height",12,45},
                {"powerHeight","MANA / POWER HEIGHT","Resource bar height",4,30},
                {"portraitSize","PORTRAIT SIZE","Portrait and ring size",36,90},
                {"portraitX","PORTRAIT X","Horizontal portrait offset",-80,80},
                {"portraitY","PORTRAIT Y","Vertical portrait offset",-80,80},
            }
            for i, setting in ipairs(settings) do
                local settingKey, title, hint, low, high = unpack(setting)
                local initial = own[settingKey]
                if initial == nil then initial = db[settingKey] or 0 end
                local slider = CreateTabSlider(panel, title, hint, low, high, 1, initial,
                    -12-(i-1)*53, function(value)
                        own[settingKey] = value
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, false)
                refreshers[#refreshers+1] = function()
                    local value = own[settingKey]
                    if value == nil then value = db[settingKey] or 0 end
                    slider:SetValue(value)
                end
            end
            local flip = addon.Theme:CreateCheckbox(panel)
            flip:SetSize(25, 25)
            flip:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -330)
            local flipLabel = CreateLabel(panel, "Flip portrait horizontally", "GameFontHighlight")
            flipLabel:SetPoint("LEFT", flip, "RIGHT", 5, 0)
            flip:SetScript("OnClick", function(self)
                own.flipPortrait = self:GetChecked() == true
                if addon.UnitFrames then addon.UnitFrames:Refresh() end
            end)
            refreshers[#refreshers+1] = function() flip:SetChecked(own.flipPortrait == true) end
            local healing = addon.Theme:CreateCheckbox(panel)
            healing:SetSize(25, 25)
            healing:SetPoint("TOPLEFT", panel, "TOPLEFT", 260, -330)
            local healingLabel = CreateLabel(panel, "Incoming Healing", "GameFontHighlight")
            healingLabel:SetPoint("LEFT", healing, "RIGHT", 5, 0)
            healing:SetChecked(own.incomingHealing ~= false)
            healing:SetScript("OnClick", function(self)
                own.incomingHealing = self:GetChecked() == true
                if addon.UnitFrames then addon.UnitFrames:Refresh() end
            end)
            refreshers[#refreshers+1] = function() healing:SetChecked(own.incomingHealing ~= false) end
            syncControls[name] = function()
                for _, refresh in ipairs(refreshers) do refresh() end
            end
            -- Center-relative pixel coordinates, independent for each unit.
            local function coordField(axis, offset)
                local title = CreateLabel(panel, "FRAME " .. string.upper(axis), "GameFontNormal")
                title:SetPoint("TOPLEFT", panel, "TOPLEFT", offset, -385)
                title:SetTextColor(1, 0.79, 0.42)
                local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                edit:SetSize(82, 26)
                edit:SetPoint("TOPLEFT", panel, "TOPLEFT", offset, -406)
                edit:SetAutoFocus(false)
                edit:SetNumeric(false)
                edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                local function commit(self)
                    local value = tonumber(self:GetText())
                    if value and addon.UnitFrames then
                        local x = own.x
                        local y = own.y
                        local defaults = {player={-260,-180}, target={260,-180}, focus={260,-250}, pet={-260,-250}}
                        x = x or defaults[key][1]
                        y = y or defaults[key][2]
                        if axis == "x" then x = value else y = value end
                        addon.UnitFrames:SetPosition(key, x, y)
                    end
                    self:ClearFocus()
                    self:SetText(tostring(own[axis] or 0))
                end
                -- Pixel nudges, placed immediately to the right of each coordinate field.
                local function nudgeButton(delta, yOffset, glyph)
                    local button = CreateFrame("Button", nil, panel)
                    button:SetSize(20, 13)
                    button:SetPoint("TOPLEFT", edit, "TOPRIGHT", 5, -yOffset)
                    local background = button:CreateTexture(nil, "BACKGROUND")
                    background:SetAllPoints()
                    addon.Theme:Paint(background, "field", 0.98)
                    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    label:SetPoint("CENTER", button, "CENTER", 0, 0)
                    label:SetText(glyph)
                    label:SetTextColor(1, 0.78, 0.36)
                    button:SetScript("OnEnter", function()
                        addon.Theme:Paint(background, "muted", 1)
                    end)
                    button:SetScript("OnLeave", function()
                        addon.Theme:Paint(background, "field", 0.98)
                    end)
                    button:SetScript("OnClick", function()
                        if not addon.UnitFrames then return end
                        local defaults = {player={-260,-180}, target={260,-180}, focus={260,-250}, pet={-260,-250}}
                        local x = own.x or defaults[key][1]
                        local y = own.y or defaults[key][2]
                        if axis == "x" then x = x + delta else y = y + delta end
                        if addon.UnitFrames:SetPosition(key, x, y) then
                            edit:SetText(tostring(own[axis]))
                            edit:ClearFocus()
                        end
                    end)
                end
                nudgeButton(1, 0, "+")
                nudgeButton(-1, 13, "-")
                edit:SetScript("OnEnterPressed", commit)
                edit:SetScript("OnEscapePressed", function(self)
                    self:ClearFocus()
                    self:SetText(tostring(own[axis] or 0))
                end)
                edit:SetScript("OnEditFocusLost", function(self)
                    self:SetText(tostring(own[axis] or 0))
                end)
                refreshers[#refreshers+1] = function()
                    if not edit:HasFocus() then edit:SetText(tostring(own[axis] or 0)) end
                end
                return edit
            end
            local xField = coordField("x", 20)
            local yField = coordField("y", 140)
            local previousSync = syncControls[name]
            syncControls[name] = function()
                previousSync()
                xField:SetText(tostring(own.x or ({player=-260,target=260,focus=260,pet=-260})[key]))
                yField:SetText(tostring(own.y or ({player=-180,target=-180,focus=-250,pet=-250})[key]))
            end
            local choices = {}
            for _, candidate in ipairs({"Player","Target","Focus","Pet"}) do
                if candidate ~= name then choices[#choices+1] = candidate end
            end
            local function styleButton(button, title)
                local bg = button:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                addon.Theme:Paint(bg, "panel", 0.98)
                for _, edgeName in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
                    local edge = button:CreateTexture(nil, "BORDER")
                    edge:SetColorTexture(0.72, 0.52, 0.27, 0.95)
                    if edgeName == "TOP" then
                        edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
                    elseif edgeName == "BOTTOM" then
                        edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
                    elseif edgeName == "LEFT" then
                        edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
                    else
                        edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
                    end
                end
                local label = CreateLabel(button, title, "GameFontNormal")
                label:SetPoint("CENTER")
                label:SetTextColor(1, 0.79, 0.42)
                button:SetScript("OnEnter", function() addon.Theme:Paint(bg, "muted", 0.98) end)
                button:SetScript("OnLeave", function() addon.Theme:Paint(bg, "panel", 0.98) end)
                return label
            end
            local source = choices[1]
            local copyGroup = CreateFrame("Frame", nil, copyHeader)
            copyGroup:SetAllPoints(copyHeader)
            copyControls[name] = copyGroup
            local selector = CreateFrame("Button", nil, copyGroup)
            selector:SetSize(172, 28)
            selector:SetParent(copyGroup)
            selector:ClearAllPoints()
            selector:SetPoint("TOPLEFT", copyGroup, "TOPLEFT", 0, -3)
            local selectorText = styleButton(selector, "From: " .. source .. "  v")
            local dropdown = CreateFrame("Frame", nil, panel)
            dropdown:SetParent(copyGroup)
            dropdown:SetSize(172, #choices * 27)
            dropdown:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -2)
            dropdown:SetFrameStrata("DIALOG")
            dropdown:SetFrameLevel(selector:GetFrameLevel() + 20)
            dropdown:Hide()
            for i, candidate in ipairs(choices) do
                local option = CreateFrame("Button", nil, dropdown)
                option:SetSize(172, 27)
                option:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, -(i-1)*27)
                styleButton(option, candidate)
                option:SetScript("OnClick", function()
                    source = candidate
                    selectorText:SetText("From: " .. source .. "  v")
                    dropdown:Hide()
                end)
            end
            selector:SetScript("OnClick", function() dropdown:SetShown(not dropdown:IsShown()) end)
            local copy = CreateFrame("Button", nil, panel)
            copy:SetParent(copyGroup)
            copy:ClearAllPoints()
            copy:SetSize(166, 28)
            copy:SetPoint("LEFT", selector, "RIGHT", 10, 0)
            styleButton(copy, "Copy settings")
            copy:SetScript("OnClick", function()
                dropdown:Hide()
                if addon.UnitFrames and addon.UnitFrames:CopyLayout(string.lower(source), key) then
                    syncControls[name]()
                end
            end)

            do
                panel = groups["Buffs / Debuffs"]
                -- Shared aura editor grid: three aligned columns, consistent row spacing.\n                -- Previews never modify real auras.
                local function auraPreviewControls(kind, top)
                    local title = CreateLabel(panel, string.upper(name .. " " .. kind), "GameFontNormal")
                    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top)
                    local check = addon.Theme:CreateCheckbox(panel)
                    check:SetSize(24, 24)
                    check:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top - 24)
                    local label = CreateLabel(panel, "Preview " .. kind, "GameFontHighlight")
                    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
                    check:SetScript("OnClick", function(self)
                        if addon.UnitFrames then addon.UnitFrames:SetAuraPreview(key, kind, self:GetChecked() == true) end
                    end)
                    local opt = own["aura_" .. kind] or {}
                    if opt.enabled == nil then opt.enabled = name ~= "Player" end
                    own["aura_" .. kind] = opt
                    local enable = addon.Theme:CreateCheckbox(panel)
                    enable:SetSize(24,24)
                    enable:SetPoint("TOPLEFT", panel, "TOPLEFT", 235, top - 24)
                    local enableLabel = CreateLabel(panel, "Enable " .. kind, "GameFontHighlight")
                    enableLabel:SetPoint("LEFT", enable, "RIGHT", 4, 0)
                    enable:SetChecked(opt.enabled)
                    enable:SetScript("OnClick", function(self)
                        opt.enabled = self:GetChecked() == true
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end)
                    local fields = {
                        {"size", "SIZE", 12, 48, 24}, {"count", "COUNT", 0, 40, 12},
                        {"perRow", "PER ROW", 1, 20, 6}, {"spacing", "GAP", 0, 20, 2},
                        {"x", "X", -250, 250, 0}, {"y", "Y", -250, 250, kind == "buffs" and 32 or -58},
                        {"durationFontSize", "NUMBER FONT", 0, 24, 12}, {"unitFontSize", "UNIT FONT", 0, 24, 7}, {"stackFontSize", "STACK FONT", 0, 24, 11},
                    }
                    for i, spec in ipairs(fields) do
                        local x = 20 + ((i-1) % 3) * 165
                        local y = top - 58 - math.floor((i-1)/3)*40
                        local caption = CreateLabel(panel, spec[2], "GameFontNormalSmall")
                        caption:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                        edit:SetSize(65, 22)
                        edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y-17)
                        edit:SetAutoFocus(false)
                        edit:SetText(tostring(opt[spec[1]] == nil and spec[5] or opt[spec[1]]))
                        local function apply(value)
                            local n = tonumber(value)
                            if not n then n = opt[spec[1]] end
                            if n == nil then n = spec[5] end
                            opt[spec[1]] = math.max(spec[3], math.min(spec[4], math.floor(n)))
                            edit:SetText(tostring(opt[spec[1]]))
                            if addon.UnitFrames then addon.UnitFrames:Refresh() end
                        end
                        for j, delta in ipairs({1, -1}) do
                            local button = CreateFrame("Button", nil, panel)
                            button:SetSize(18, 11)
                            button:SetPoint("TOPLEFT", edit, "TOPRIGHT", 4, -(j-1)*11)
                            local background = button:CreateTexture(nil, "BACKGROUND")
                            background:SetAllPoints()
                            addon.Theme:Paint(background, "panel", 1)
                            local glyph = CreateLabel(button, delta == 1 and "+" or "-", "GameFontNormalSmall")
                            glyph:SetPoint("CENTER")
                            button:SetScript("OnClick", function()
                                apply((opt[spec[1]] == nil and spec[5] or opt[spec[1]]) + delta)
                            end)
                        end
                        edit:SetScript("OnEnterPressed", function(self)
                            local value = tonumber(self:GetText()) or spec[5]
                            opt[spec[1]] = math.max(spec[3], math.min(spec[4], math.floor(value)))
                            self:SetText(tostring(opt[spec[1]]))
                            self:ClearFocus()
                            if addon.UnitFrames then addon.UnitFrames:Refresh() end
                        end)
                    end
                    if key == "target" and kind == "debuffs" then
                        local mine = addon.Theme:CreateCheckbox(panel)
                        mine:SetSize(24, 24)
                        mine:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top - 219)
                        local mineLabel = CreateLabel(panel, "Show only my debuffs (requires /reload)", "GameFontHighlight")
                        mineLabel:SetPoint("LEFT", mine, "RIGHT", 4, 0)
                        mine:SetChecked(opt.onlyMine == true)
                        mine:SetScript("OnClick", function(self)
                            opt.onlyMine = self:GetChecked() == true
                        end)
                    end
                    local function direction(field, x)
                        local button = CreateFrame("Button", nil, panel)
                        button:SetSize(190, 24)
                        button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, top-190)
                        local bg = button:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints()
                        addon.Theme:Paint(bg, "panel", 1)
                        local text = CreateLabel(button, "", "GameFontNormalSmall")
                        text:SetPoint("CENTER")
                        local function refresh()
                            text:SetText(field .. ": " .. (opt[field] or (field == "horizontal" and "right" or "down")))
                        end
                        button:SetScript("OnClick", function()
                            local current = opt[field] or (field == "horizontal" and "right" or "down")
                            opt[field] = field == "horizontal" and (current == "right" and "left" or "right")
                                or (current == "down" and "up" or "down")
                            refresh()
                            if addon.UnitFrames then addon.UnitFrames:Refresh() end
                        end)
                        refresh()
                    end
                    direction("horizontal", 20)
                    direction("vertical", 255)
                    viewport:HookScript("OnHide", function()
                        check:SetChecked(false)
                        if addon.UnitFrames then addon.UnitFrames:SetAuraPreview(key, kind, false) end
                    end)
                end
                auraPreviewControls("buffs", -20)
                auraPreviewControls("debuffs", -245)
            end
            panel = groups.Indicators
            -- Independent per-unit indicators, text templates and fonts.
            local function optionCheck(field, caption, x, y)
                local check = addon.Theme:CreateCheckbox(panel)
                check:SetSize(24, 24)
                check:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                local label = CreateLabel(panel, caption, "GameFontHighlight")
                label:SetPoint("LEFT", check, "RIGHT", 4, 0)
                check:SetScript("OnClick", function(self)
                    own[field] = self:GetChecked() == true
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end)
                refreshers[#refreshers+1] = function()
                    if field == "firstNameOnly" then check:SetChecked(own[field] == true)
                    else check:SetChecked(own[field] ~= false) end
                end
            end
            local preview = CreateFrame("Button", nil, panel)
            preview:SetSize(170, 27)
            preview:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -11)
            local previewText = styleButton(preview, "Preview indicators")
            local previewOn = false
            local function stopPreview()
                if not previewOn then return end
                previewOn = false
                previewText:SetText("Preview indicators")
                if addon.UnitFrames then addon.UnitFrames:SetIndicatorPreview(false) end
            end
            preview:SetScript("OnClick", function()
                previewOn = not previewOn
                previewText:SetText(previewOn and "Stop preview" or "Preview indicators")
                if addon.UnitFrames then addon.UnitFrames:SetIndicatorPreview(previewOn) end
            end)
            viewport:HookScript("OnHide", stopPreview)
            local indicators = CreateLabel(panel, "INDICATORS", "GameFontNormalLarge")
            indicators:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -16)
            indicators:SetTextColor(1, 0.79, 0.42)
            optionCheck("showPvP", "PvP flag", 20, -58)
            optionCheck("showLeader", "Group leader", 230, -58)
            optionCheck("showRaidMarker", "Raid marker", 20, -98)
            optionCheck("showRole", "Group / raid role", 230, -98)
            optionCheck("showClassification", name == "Target" and "Elite / boss" or "Elite / rare", 20, -138)

            optionCheck("showName", "Show name", 230, -138)
            optionCheck("firstNameOnly", "First name only", 230, name == "Pet" and -204 or -174)
            if name == "Pet" then
                optionCheck("showHappiness", "Pet happiness", 20, -174)
                optionCheck("showPetXP", "Pet XP bar", 230, -174)
                optionCheck("showPetCast", "Pet castbar", 20, -204)
            end
            local iconSpecs = {
                {"pvp", "PvP flag"}, {"leader", "Group leader"},
                {"raid", "Raid marker"}, {"role", "Group / raid role"},
                {"classification", "Elite / rare"}
            }
            if name == "Pet" then iconSpecs[#iconSpecs + 1] = {"happiness", "Pet happiness"} end
            local function indicatorField(kind, field, x, y, caption)
                own[field] = own[field] or {}
                local label = CreateLabel(panel, caption, "GameFontNormalSmall")
                label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                label:SetTextColor(1, 0.79, 0.42)
                local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                edit:SetSize(43, 22)
                edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y - 19)
                edit:SetAutoFocus(false)
                local function current()
                    return own[field][kind] or (field == "indicatorSize" and (kind == "classification" and 64 or 17) or 0)
                end
                local function apply(value)
                    local n = math.floor(tonumber(value) or current())
                    if field == "indicatorSize" then n = math.max(10, math.min(kind == "classification" and 120 or 48, n))
                    else n = math.max(-250, math.min(250, n)) end
                    own[field][kind] = n
                    edit:SetText(tostring(n))
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end
                edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                edit:SetScript("OnEnterPressed", function(self) apply(self:GetText()); self:ClearFocus() end)
                edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText(tostring(current())) end)
                edit:SetScript("OnEditFocusLost", function(self) self:SetText(tostring(current())) end)
                edit:SetText(tostring(current()))
                for i, delta in ipairs({1, -1}) do
                    local button = CreateFrame("Button", nil, panel)
                    button:SetSize(18, 12)
                    button:SetPoint("TOPLEFT", edit, "TOPRIGHT", 3, -(i-1)*12)
                    local bg = button:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    addon.Theme:Paint(bg, "panel", 1)
                    local t = CreateLabel(button, delta == 1 and "+" or "-", "GameFontNormalSmall")
                    t:SetPoint("CENTER")
                    button:SetScript("OnClick", function() apply(current() + delta) end)
                end
                refreshers[#refreshers+1] = function()
                    if not edit:HasFocus() then edit:SetText(tostring(current())) end
                end
            end
            for i, spec in ipairs(iconSpecs) do
                local rowY = (name == "Pet" and -240 or -200) - (i-1)*65
                local title = CreateLabel(panel, spec[2], "GameFontNormal")
                title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, rowY)
                title:SetTextColor(1, 0.79, 0.42)
                indicatorField(spec[1], "indicatorSize", 215, rowY, "SIZE")
                indicatorField(spec[1], "indicatorX", 310, rowY, "X")
                indicatorField(spec[1], "indicatorY", 405, rowY, "Y")
            end
            if name == "Pet" then
                local function petBarControl(prefix, title, top)
                    local heading = CreateLabel(panel, title, "GameFontNormal")
                    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top)
                    heading:SetTextColor(1, 0.79, 0.42)
                    for i, spec in ipairs({
                        {"Width", "WIDTH", 40, 400, 160},
                        {"Height", "HEIGHT", 4, 40, prefix == "petXP" and 9 or 13},
                        {"X", "X", -250, 250, 0},
                        {"Y", "Y", -250, 250, 0},
                        {"FontSize", "FONT", 0, 28, 10},
                    }) do
                        local field = prefix .. spec[1]
                        local x = 20 + (i-1) * 96
                        local caption = CreateLabel(panel, spec[2], "GameFontNormalSmall")
                        caption:SetPoint("TOPLEFT", panel, "TOPLEFT", x, top - 23)
                        caption:SetTextColor(1, 0.79, 0.42)
                        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                        edit:SetSize(47, 22)
                        edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x, top - 42)
                        edit:SetAutoFocus(false)
                        local function current() return tonumber(own[field]) or spec[5] end
                        local function apply(value)
                            own[field] = math.max(spec[3], math.min(spec[4], math.floor(tonumber(value) or current())))
                            edit:SetText(tostring(own[field]))
                            if addon.UnitFrames then addon.UnitFrames:Refresh() end
                        end
                        edit:SetScript("OnEnterPressed", function(self) apply(self:GetText()); self:ClearFocus() end)
                        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText(tostring(current())) end)
                        edit:SetScript("OnEditFocusLost", function(self) self:SetText(tostring(current())) end)
                        for j, delta in ipairs({1, -1}) do
                            local btn = CreateFrame("Button", nil, panel)
                            btn:SetSize(18, 12)
                            btn:SetPoint("TOPLEFT", edit, "TOPRIGHT", 3, -(j-1)*12)
                            local bg = btn:CreateTexture(nil, "BACKGROUND")
                            bg:SetAllPoints()
                            addon.Theme:Paint(bg, "panel", 1)
                            local glyph = CreateLabel(btn, delta == 1 and "+" or "-", "GameFontNormalSmall")
                            glyph:SetPoint("CENTER")
                            btn:SetScript("OnClick", function() apply(current() + delta) end)
                        end
                        refreshers[#refreshers+1] = function()
                            if not edit:HasFocus() then edit:SetText(tostring(current())) end
                        end
                    end
                end
                petBarControl("petCast", "PET CASTBAR", -640)
                -- Toggle a stationary castbar for layout work even when the pet cannot cast.
                local castPreview = CreateFrame("Button", nil, panel)
                castPreview:SetSize(125, 24)
                castPreview:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -681)
                local castPreviewText = styleButton(castPreview, "Preview castbar")
                local castPreviewOn = false
                local function stopCastPreview()
                    if not castPreviewOn then return end
                    castPreviewOn = false
                    castPreviewText:SetText("Preview castbar")
                    if addon.UnitFrames then addon.UnitFrames:SetPetCastPreview(false) end
                end
                castPreview:SetScript("OnClick", function()
                    castPreviewOn = not castPreviewOn
                    castPreviewText:SetText(castPreviewOn and "Stop preview" or "Preview castbar")
                    if addon.UnitFrames then addon.UnitFrames:SetPetCastPreview(castPreviewOn) end
                end)
                viewport:HookScript("OnHide", stopCastPreview)

                -- Pet XP ring rotation: independent of segment width, sweep and
                -- portrait size. Numeric entry and +/- adjust by one degree.
                local rotationSlider = CreateTabSlider(panel, "PET XP RING ROTATION",
                    "Rotate the XP segments around the portrait (degrees)",
                    -180, 180, 1, tonumber(own.petXPRotation) or 0, -735,
                    function(value)
                        own.petXPRotation = value
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, true)
                -- Reserve room after the numeric value for the step buttons.
                local rotationRow = rotationSlider:GetParent()
                rotationSlider:ClearAllPoints()
                rotationSlider:SetPoint("RIGHT", rotationRow, "RIGHT", -111, 0)
                rotationSlider.valueBox:ClearAllPoints()
                rotationSlider.valueBox:SetPoint("RIGHT", rotationRow, "RIGHT", -71, 0)
                for i, delta in ipairs({1, -1}) do
                    local btn = CreateFrame("Button", nil, rotationRow)
                    btn:SetSize(21, 24)
                    btn:SetPoint("LEFT", rotationSlider.valueBox, "RIGHT", 5 + (i-1)*22, 0)
                    local bg = btn:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    addon.Theme:Paint(bg, "panel", 1)
                    local glyph = CreateLabel(btn, delta == 1 and "+" or "-", "GameFontNormal")
                    glyph:SetPoint("CENTER")
                    btn:SetScript("OnClick", function()
                        local nextValue = math.max(-180, math.min(180,
                            (tonumber(own.petXPRotation) or 0) + delta))
                        rotationSlider:SetValue(nextValue)
                    end)
                end
                refreshers[#refreshers+1] = function()
                    local value = tonumber(own.petXPRotation) or 0
                    if math.abs(rotationSlider:GetValue() - value) > 0.01 then
                        rotationSlider:SetValue(value)
                    end
                end
                local xpColorLabel = CreateLabel(panel, "CURRENT PET XP COLOR", "GameFontNormal")
                xpColorLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -847)
                local xpColor = addon.Theme:CreateColorSwatch(panel, function()
                    return own.petXPColor or addon.Theme.colors.experience
                end, function(color)
                    own.petXPColor = color
                    addon.UnitFrames:Refresh()
                end)
                xpColor:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -30, -842)
                refreshers[#refreshers + 1] = function() xpColor:Refresh() end
                local radiusSlider = CreateTabSlider(panel, "PET XP RING RADIUS",
                    "Move XP segments inward (-) or outward (+), in pixels",
                    -10, 10, 0.5, tonumber(own.petXPRadiusOffset) or 0, -785,
                    function(value)
                        own.petXPRadiusOffset = value
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, true)
                local radiusRow = radiusSlider:GetParent()
                radiusSlider:ClearAllPoints()
                radiusSlider:SetPoint("RIGHT", radiusRow, "RIGHT", -111, 0)
                radiusSlider.valueBox:ClearAllPoints()
                radiusSlider.valueBox:SetPoint("RIGHT", radiusRow, "RIGHT", -71, 0)
                for i, delta in ipairs({1, -1}) do
                    local btn = CreateFrame("Button", nil, radiusRow)
                    btn:SetSize(21, 24)
                    btn:SetPoint("LEFT", radiusSlider.valueBox, "RIGHT", 5 + (i-1)*22, 0)
                    local bg = btn:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    addon.Theme:Paint(bg, "panel", 1)
                    local glyph = CreateLabel(btn, delta == 1 and "+" or "-", "GameFontNormal")
                    glyph:SetPoint("CENTER")
                    btn:SetScript("OnClick", function()
                        local nextValue = math.max(-10, math.min(10,
                            (tonumber(own.petXPRadiusOffset) or 0) + delta * 0.5))
                        radiusSlider:SetValue(nextValue)
                    end)
                end
                refreshers[#refreshers+1] = function()
                    local value = tonumber(own.petXPRadiusOffset) or 0
                    if math.abs(radiusSlider:GetValue() - value) > 0.01 then
                        radiusSlider:SetValue(value)
                    end
                end
            end
            panel = groups["Bar Text"]
            local barTitle = CreateLabel(panel, "BAR TEXT", "GameFontNormalLarge")
            barTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -15)
            barTitle:SetTextColor(1, 0.79, 0.42)
            local function textField(field, caption, y)
                local label = CreateLabel(panel, caption, "GameFontNormal")
                label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
                label:SetTextColor(1, 0.79, 0.42)
                local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                edit:SetSize(280, 26)
                edit:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, y + 4)
                edit:SetAutoFocus(false)
                edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                edit:SetScript("OnEnterPressed", function(self)
                    own[field] = self:GetText()
                    self:ClearFocus()
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end)
                edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText(own[field] or "") end)
                refreshers[#refreshers+1] = function()
                    if not edit:HasFocus() then edit:SetText(own[field] or "") end
                end
            end
            textField("hpText", "HP text", -55)
            textField("powerText", "Mana / Power text", -97)
            local hint = CreateLabel(panel, "Variables: {current}  {max}  {percent}   |   Blank = hidden", "GameFontHighlightSmall")
            hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -138)
            hint:SetTextColor(0.90, 0.75, 0.55)
            -- Separate text offsets for HP and Power, with one-pixel nudges.
            local function offsetEditor(field, caption, x, y)
                local title = CreateLabel(panel, caption, "GameFontNormal")
                title:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                title:SetTextColor(1, 0.79, 0.42)
                local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                edit:SetSize(76, 24)
                edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y - 22)
                edit:SetAutoFocus(false)
                edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                local function apply(value)
                    own[field] = math.max(-300, math.min(300, math.floor(value)))
                    edit:SetText(tostring(own[field]))
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end
                edit:SetScript("OnEnterPressed", function(self)
                    local value = tonumber(self:GetText())
                    if value then apply(value) end
                    self:ClearFocus()
                end)
                edit:SetScript("OnEscapePressed", function(self)
                    self:ClearFocus()
                    self:SetText(tostring(own[field] or 0))
                end)
                for i, delta in ipairs({1, -1}) do
                    local button = CreateFrame("Button", nil, panel)
                    button:SetSize(22, 13)
                    button:SetPoint("TOPLEFT", edit, "TOPRIGHT", 4, -(i-1)*13)
                    local bg = button:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    addon.Theme:Paint(bg, "panel", 1)
                    local label = CreateLabel(button, delta == 1 and "+" or "-", "GameFontNormalSmall")
                    label:SetPoint("CENTER")
                    label:SetTextColor(1, 0.79, 0.42)
                    button:SetScript("OnClick", function() apply((own[field] or 0) + delta) end)
                end
                refreshers[#refreshers+1] = function()
                    if not edit:HasFocus() then edit:SetText(tostring(own[field] or 0)) end
                end
            end
            offsetEditor("hpTextX", "HP TEXT X", 20, -180)
            offsetEditor("hpTextY", "HP TEXT Y", 180, -180)
            offsetEditor("powerTextX", "POWER TEXT X", 20, -250)
            offsetEditor("powerTextY", "POWER TEXT Y", 180, -250)
            -- Styled dropdown shared by font, colors and bar text anchors.
            local function unitDropdown(field, caption, choices, x, y, width)
                local label = CreateLabel(panel, caption, "GameFontNormal")
                label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                label:SetTextColor(1, 0.79, 0.42)
                local button = CreateFrame("Button", nil, panel)
                button:SetSize(width or 145, 27)
                button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y - 22)
                local bg = button:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                addon.Theme:Paint(bg, "field", 1)
                local border = button:CreateTexture(nil, "BORDER")
                border:SetPoint("TOPLEFT"); border:SetPoint("TOPRIGHT"); border:SetHeight(1)
                border:SetColorTexture(0.75, 0.55, 0.29)
                local arrow = CreateLabel(button, "v", "GameFontHighlightSmall")
                arrow:SetPoint("RIGHT", button, "RIGHT", -7, 0)
                local text = CreateLabel(button, "", "GameFontNormal")
                text:SetPoint("CENTER")
                text:SetTextColor(1, 0.79, 0.42)
                local menu = CreateFrame("Frame", nil, panel)
                menu:SetSize(width or 145, #choices * 24 + 4)
                local menuBg = menu:CreateTexture(nil, "BACKGROUND")
                menuBg:SetAllPoints()
                addon.Theme:Paint(menuBg, "field", 1)
                menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
                menu:SetFrameStrata("FULLSCREEN_DIALOG")
                menu:SetFrameLevel(button:GetFrameLevel() + 25)
                menu:Hide()
                local function refresh()
                    local current = own[field] or choices[1][1]
                    for _, choice in ipairs(choices) do
                        if choice[1] == current then text:SetText(choice[2]); return end
                    end
                    text:SetText(choices[1][2])
                end
                for i, choice in ipairs(choices) do
                    local item = CreateFrame("Button", nil, menu)
                    item:SetSize((width or 145) - 4, 24)
                    item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2-(i-1)*24)
                    local fill = item:CreateTexture(nil, "BACKGROUND")
                    fill:SetAllPoints()
                    addon.Theme:Paint(fill, "field", 1)
                    local captionText = CreateLabel(item, choice[2], "GameFontNormal")
                    captionText:SetPoint("CENTER")
                    captionText:SetTextColor(1, 0.79, 0.42)
                    item:SetScript("OnEnter", function() addon.Theme:Paint(fill, "muted", 1) end)
                    item:SetScript("OnLeave", function() addon.Theme:Paint(fill, "field", 1) end)
                    item:SetScript("OnClick", function()
                        own[field] = choice[1]
                        if field == "fontFace" then addon.Typography.ModuleChanged("UnitFrames", "font") end
                        menu:Hide()
                        refresh()
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end)
                end
                button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
                refreshers[#refreshers+1] = function() menu:Hide(); refresh() end
            end
            unitDropdown("gradientDirection", "BAR GRADIENT DARK SIDE", {{"RIGHT","Right"},{"LEFT","Left"}}, 20, -405, 170)
            if key == "target" then
                local threatToggle = addon.Theme:CreateCheckbox(panel)
                threatToggle:SetSize(24,24)
                threatToggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -468)
                local threatLabel = CreateLabel(panel, "Show aggro threat %", "GameFontHighlight")
                threatLabel:SetPoint("LEFT", threatToggle, "RIGHT", 5, 0)
                threatToggle:SetScript("OnClick", function(self)
                    own.showThreat = self:GetChecked() == true
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end)
                refreshers[#refreshers+1] = function() threatToggle:SetChecked(own.showThreat ~= false) end
                local previewToggle = addon.Theme:CreateCheckbox(panel)
                previewToggle:SetSize(24, 24)
                previewToggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 265, -468)
                local previewLabel = CreateLabel(panel, "Preview Threat (75%)", "GameFontHighlight")
                previewLabel:SetPoint("LEFT", previewToggle, "RIGHT", 5, 0)
                previewToggle:SetScript("OnClick", function(self)
                    own.previewThreat = self:GetChecked() == true
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end)
                refreshers[#refreshers+1] = function()
                    previewToggle:SetChecked(own.previewThreat == true)
                end
                offsetEditor("threatX", "THREAT X", 20, -505)
                offsetEditor("threatY", "THREAT Y", 180, -505)
                local portraitThreat = addon.Theme:CreateCheckbox(panel)
                portraitThreat:SetSize(24, 24)
                portraitThreat:SetPoint("TOPLEFT", 20, -548)
                CreateLabel(panel, "Show threat on portrait", "GameFontHighlight"):SetPoint("LEFT", portraitThreat, "RIGHT", 5, 0)
                portraitThreat:SetScript("OnClick", function(self)
                    own.threatOnPortrait = not not self:GetChecked()
                    addon.UnitFrames:Refresh()
                end)
                refreshers[#refreshers+1] = function() portraitThreat:SetChecked(own.threatOnPortrait == true) end
                -- Reuse the existing styled numeric slider with live value updates.
                local threatSize = CreateTabSlider(panel, "THREAT FONT SIZE", "Aggro percentage text size",
                    7, 40, 1, own.threatFontSize or 14, -578, function(value)
                        own.threatFontSize = value
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, false)
                refreshers[#refreshers+1] = function()
                    threatSize:SetValue(own.threatFontSize or 14)
                end
            end
            unitDropdown("hpTextAnchor", "HP TEXT ANCHOR", {{"RIGHT","Right"},{"CENTER","Center"},{"LEFT","Left"}}, 355, -180, 130)
            unitDropdown("powerTextAnchor", "POWER TEXT ANCHOR", {{"RIGHT","Right"},{"CENTER","Center"},{"LEFT","Left"}}, 355, -250, 130)
            unitDropdown("hpFontColor", "HP FONT COLOR", {{"gold","Gold"},{"white","White"},{"class","Class Color"}}, 20, -335, 150)
            unitDropdown("powerFontColor", "POWER FONT COLOR", {{"gold","Gold"},{"white","White"},{"class","Class Color"}}, 200, -335, 150)
            panel = groups.Fonts
            local fontTitle = CreateLabel(panel, "FONT", "GameFontNormalLarge")
            fontTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -15)
            fontTitle:SetTextColor(1, 0.79, 0.42)
            unitDropdown("fontFace", "FONT FAMILY", {{"general","General (Default)"},{"friz","Friz Quadrata"},{"arial","Arial Narrow"}}, 20, -42, 190)
            local fontSlider = CreateTabSlider(panel, "FONT SIZE", "Name, HP and Power text", 8, 28, 1,
                own.fontSize or 12, -116, function(v)
                    if v ~= (own.fontSize or 12) then addon.Typography.ModuleChanged("UnitFrames", "size") end
                    own.fontSize = v
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end, false)
            refreshers[#refreshers+1] = function() fontSlider:SetValue(own.fontSize or 12) end
            for i, spec in ipairs({
                {"nameFontSize", "NAME SIZE"},
                {"hpFontSize", "HP TEXT SIZE"},
                {"powerFontSize", "POWER TEXT SIZE"},
            }) do
                local field = spec[1]
                local slider = CreateTabSlider(panel, spec[2], "Independent text size", 8, 28, 1,
                    own[field] or own.fontSize or 12, -176 - (i-1)*57, function(v)
                        local scope = field == "nameFontSize" and "Name" or field == "hpFontSize" and "Health" or "Power"
                        if v ~= (own[field] or own.fontSize or 12) then addon.Typography.ModuleChanged("UnitFrames:" .. scope, "size") end
                        own[field] = v
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, false)
                refreshers[#refreshers+1] = function()
                    slider:SetValue(own[field] or own.fontSize or 12)
                end
            end

            local levelSlider = CreateTabSlider(panel, "LEVEL TEXT SIZE", "Level number only; badge ring stays fixed", 8, 28, 1,
                own.levelFontSize or 12, -355, function(v)
                    if v ~= (own.levelFontSize or 12) then addon.Typography.ModuleChanged("UnitFrames:Level", "size") end
                    own.levelFontSize = v
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end, false)
            refreshers[#refreshers+1] = function() levelSlider:SetValue(own.levelFontSize or 12) end
            offsetEditor("levelTextX", "LEVEL TEXT X", 20, -435)
            offsetEditor("levelTextY", "LEVEL TEXT Y", 180, -435)

            panel = groups.Layout
            local note = CreateLabel(copyGroup, "Copies appearance only; position is preserved.", "GameFontHighlightSmall")
            note:SetTextColor(0.91, 0.78, 0.61, 1)
            note:SetPoint("TOPLEFT", copyGroup, "TOPLEFT", 0, -35)
            panel = rootPanel
            selectGroup("Layout")
        end
    end
    BuildTab("General")
    page:HookScript("OnShow", function()
        enabled:SetChecked(db.enabled ~= false)
        RefreshTabs()
    end)
    RefreshTabs()
    return page
end

local function CreateQoLPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages["Quality of Life"] = page
    local panel = CreatePanel(page, -12, 340)
    CreateSection(panel, "QUALITY OF LIFE", -14)
    CreateDivider(panel, -48)
    local toggle = addon.Theme:CreateCheckbox(panel)
    toggle:SetSize(25,25)
    toggle:SetPoint("TOPLEFT",panel,"TOPLEFT",18,-72)
    toggle:SetChecked(addon.db.profile.qol.characterItemLevel)
    local label = CreateLabel(panel,"Character Item Level","GameFontHighlight")
    label:SetPoint("LEFT",toggle,"RIGHT",6,0)
    local description = CreateLabel(panel,
        "Show equipped item levels and average ilvl in the character window.",
        "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT",panel,"TOPLEFT",22,-115)
    description:SetTextColor(0.84,0.73,0.59)
    toggle:SetScript("OnClick",function(self)
        addon.db.profile.qol.characterItemLevel = not not self:GetChecked()
        if addon.ItemLevel then addon.ItemLevel:RefreshCharacter() end
    end)
    local tracking = addon.Theme:CreateCheckbox(panel)
    tracking:SetSize(25, 25)
    tracking:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -152)
    tracking:SetChecked(addon.db.profile.qol.restoreGatheringTracking)
    local trackingLabel = CreateLabel(panel, "Restore Gathering Tracking After Resurrection", "GameFontHighlight")
    trackingLabel:SetPoint("LEFT", tracking, "RIGHT", 6, 0)
    local trackingHint = CreateLabel(panel,
        "Turn Find Herbs or Find Minerals back on after resurrection.",
        "GameFontHighlightSmall")
    trackingHint:SetPoint("TOPLEFT", tracking, "BOTTOMLEFT", 4, -5)
    trackingHint:SetTextColor(0.84, 0.73, 0.59)
    tracking:SetScript("OnClick", function(self)
        addon.db.profile.qol.restoreGatheringTracking = not not self:GetChecked()
    end)

    local soundsPanel = CreatePanel(page, -12, 340)
    soundsPanel:Hide()
    soundsPanel:ClearAllPoints()
    soundsPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12)
    soundsPanel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -12)
    soundsPanel:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    CreateSection(soundsPanel, "SOUNDS", -14)
    CreateDivider(soundsPanel, -48)
    local function SoundCheck(title, descriptionText, key, y)
        local check = addon.Theme:CreateCheckbox(soundsPanel)
        check:SetSize(25, 25)
        check:SetPoint("TOPLEFT", soundsPanel, "TOPLEFT", 18, y)
        check:SetChecked(addon.db.profile.qol[key])
        local caption = CreateLabel(soundsPanel, title, "GameFontHighlight")
        caption:SetPoint("LEFT", check, "RIGHT", 6, 0)
        local hint = CreateLabel(soundsPanel, descriptionText, "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 4, -5)
        hint:SetTextColor(0.84, 0.73, 0.59)
        check:SetScript("OnClick", function(self)
            addon.db.profile.qol[key] = not not self:GetChecked()
            if addon.QoLSounds then addon.QoLSounds:Apply() end
        end)
    end
    SoundCheck("Mute Character Error Speech",
        "Silence character voice errors, such as not enough mana.",
        "muteErrorSpeech", -72)
    SoundCheck("Mute Failed Spell Sounds",
        "Silence the sound played when a spell or ability fails.",
        "muteFailedSpellSounds", -152)
    SoundCheck("Hide Combat Error Text",
        "Hide text for failed abilities, such as out of range, not ready, or not enough rage.",
        "hideCombatErrors", -232)
    local automation = CreatePanel(page, -12, 354)
    automation:Hide()
    CreateSection(automation, "AUTOMATION", -14)
    CreateDivider(automation, -48)
    for index, option in ipairs(addon.QoLAutomation.options) do
        local key, caption = unpack(option)
        local check = addon.Theme:CreateCheckbox(automation)
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", 18, -61 - (index - 1) * 27)
        check:SetChecked(addon.db.profile.qol[key])
        local text = CreateLabel(automation, caption, "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 6, 0)
        check:SetScript("OnClick", function(self)
            addon.db.profile.qol[key] = not not self:GetChecked()
            if key == "trainAll" then addon.QoLAutomation.RefreshTrainer() end
        end)
    end
    -- Same right-side tabs used by Minimap and Tooltip.
    local resize = addon.WindowResize
    local resizePanel = CreatePanel(page, -12, 420)
    resizePanel:Hide()
    resizePanel:ClearAllPoints()
    resizePanel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12)
    resizePanel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -12)
    resizePanel:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    CreateSection(resizePanel, "RESIZE OPTIONS", -14)
    local help = CreateLabel(resizePanel, "Enable scaling, set a size, and choose whether corners can be dragged.", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", resizePanel, "TOPLEFT", 22, -47)
    help:SetTextColor(0.89, 0.73, 0.52)
    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", resizePanel, "TOPRIGHT", 25, 0)
    tabBar:SetSize(108, 116)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    local tabs = {}
    local active = "General"
    local function selectTab(name)
        active = name
        panel:SetShown(name == "General")
        resizePanel:SetShown(name == "Resize Options")
        soundsPanel:SetShown(name == "Sounds")
        automation:SetShown(name == "Automation")
        for key, button in pairs(tabs) do
            local selected = key == name
            addon.Theme:StyleSettingsTab(button, selected)
            button.label:SetTextColor(selected and 1 or 0.95, selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54, selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do edge:SetColorTexture(selected and 0.83 or 0.54, selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95) end
        end
    end
    for i, name in ipairs({"General", "Resize Options", "Sounds", "Automation"}) do
        local tab = CreateFrame("Button", nil, tabBar)
        tab:SetSize(108, 29)
        tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -(i-1)*29)
        tab.fill = tab:CreateTexture(nil, "BACKGROUND")
        tab.fill:SetAllPoints()
        tab.text = CreateLabel(tab, name, "GameFontNormal")
        tab.text:SetPoint("CENTER")
        tab.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = tab:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            tab.edges[#tab.edges+1] = edge
        end
        tab.accent = tab:CreateTexture(nil, "OVERLAY")
        tab.accent:SetPoint("TOPRIGHT"); tab.accent:SetPoint("BOTTOMRIGHT"); tab.accent:SetWidth(3)
        tab.label = tab.text
        tab.text:ClearAllPoints()
        tab.text:SetPoint("LEFT", tab, "LEFT", 12, 0)
        tab:SetScript("OnClick", function() selectTab(name) end)
        tab:SetScript("OnEnter", function() if active ~= name then addon.Theme:Paint(tab.fill, "muted", 0.98) end end)
        tab:SetScript("OnLeave", function() selectTab(active) end)
        tabs[name] = tab
    end
    local viewport = CreateFrame("ScrollFrame", nil, resizePanel)
    viewport:SetPoint("TOPLEFT", resizePanel, "TOPLEFT", 12, -75)
    viewport:SetPoint("BOTTOMRIGHT", resizePanel, "BOTTOMRIGHT", -30, 12)
    viewport:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, viewport)
    content:SetWidth(700)
    content:SetHeight(#resize.windows * 57 + 10)
    viewport:SetScrollChild(content)
    viewport:SetScript("OnSizeChanged", function(self)
        content:SetWidth(math.max(200, self:GetWidth()))
    end)
    local scrollbar = CreateFrame("Slider", nil, resizePanel)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetWidth(14)
    scrollbar:SetPoint("TOPRIGHT", resizePanel, "TOPRIGHT", -10, -75)
    scrollbar:SetPoint("BOTTOMRIGHT", resizePanel, "BOTTOMRIGHT", -10, 12)
    local track = scrollbar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    addon.Theme:Paint(track, "field", 0.9)
    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(14, 38)
    addon.Theme:StyleScrollThumb(thumb)
    scrollbar:SetThumbTexture(thumb)
    local sync = false
    local function refreshScroll()
        local limit = math.max(0, content:GetHeight() - viewport:GetHeight())
        scrollbar:SetMinMaxValues(0, math.max(1, limit))
        scrollbar:SetShown(limit > 1)
        if not sync then
            sync = true
            scrollbar:SetValue(math.min(limit, viewport:GetVerticalScroll()))
            sync = false
        end
    end
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if sync then return end
        sync = true
        viewport:SetVerticalScroll(value)
        sync = false
    end)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        local limit = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 45)))
        refreshScroll()
    end)
    viewport:HookScript("OnVerticalScroll", refreshScroll)
    viewport:HookScript("OnSizeChanged", refreshScroll)
    resizePanel:HookScript("OnShow", function() resize:Refresh(); refreshScroll() end)
    for i, window in ipairs(resize.windows) do
        local key = window.key
        local cfg = resize:GetSetting(key)
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -6 - (i-1)*57)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, -6 - (i-1)*57)
        row:SetHeight(51)
        local fill = row:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        addon.Theme:Paint(fill, "row", 0.65)
        local check = addon.Theme:CreateCheckbox(row)
        check:SetSize(24,24)
        check:SetPoint("LEFT", row, "LEFT", 8, 0)
        check:SetChecked(cfg.enabled)
        local label = CreateLabel(row, window.label, "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 5, 0)
        label:SetTextColor(1, 0.8, 0.47)
        -- Editable window position (UIParent bottom-left coordinates).
        local coordinateBoxes = {}
        local function selectAllOnDoubleClick(edit)
            local lastClick = 0
            edit:HookScript("OnMouseDown", function(self, button)
                if button ~= "LeftButton" then return end
                local now = GetTime()
                if now - lastClick < 0.35 then
                    self:SetFocus()
                    self:HighlightText()
                end
                lastClick = now
            end)
        end
        for index, axis in ipairs({"X", "Y"}) do
            local offset = index == 1 and -257 or -158
            local coordLabel = CreateLabel(row, axis .. ":", "GameFontNormalSmall")
            coordLabel:SetPoint("RIGHT", row, "RIGHT", offset, 0)
            coordLabel:SetTextColor(0.96, 0.78, 0.53)
            local edit = CreateFrame("EditBox", nil, row)
            edit:SetSize(63, 24)
            edit:SetPoint("LEFT", coordLabel, "RIGHT", 5, 0)
            edit:SetAutoFocus(false)
            edit:SetNumeric(false)
            edit:SetMaxLetters(6)
            edit:SetFontObject("GameFontNormal")
            edit:SetTextColor(1, 0.81, 0.45)
            edit:SetJustifyH("CENTER")
            local background = edit:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints()
            addon.Theme:Paint(background, "field", 0.95)
            selectAllOnDoubleClick(edit)
            coordinateBoxes[axis] = edit
        end
        local function refreshCoordinates()
            local x, y = resize:GetPosition(key)
            if not coordinateBoxes.X:HasFocus() then
                coordinateBoxes.X:SetText(x and tostring(x) or "")
            end
            if not coordinateBoxes.Y:HasFocus() then
                coordinateBoxes.Y:SetText(y and tostring(y) or "")
            end
        end
        local function saveCoordinates()
            local x = tonumber(coordinateBoxes.X:GetText())
            local y = tonumber(coordinateBoxes.Y:GetText())
            if x and y then resize:SetPosition(key, x, y) end
            coordinateBoxes.X:ClearFocus()
            coordinateBoxes.Y:ClearFocus()
            refreshCoordinates()
        end
        for _, edit in pairs(coordinateBoxes) do
            edit:SetScript("OnEnterPressed", saveCoordinates)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refreshCoordinates() end)
        end
        local drag = addon.Theme:CreateCheckbox(row)
        drag:SetSize(23,23)
        drag:SetPoint("RIGHT", row, "RIGHT", -342, 0)
        drag:SetChecked(cfg.draggable ~= false)
        drag:SetEnabled(cfg.enabled)
        local dragLabel = CreateLabel(row, "Drag", "GameFontNormalSmall")
        dragLabel:SetPoint("RIGHT", drag, "LEFT", -4, 0)
        dragLabel:SetTextColor(0.96, 0.78, 0.53)
        local reset = CreateFrame("Button", nil, row)
        reset:SetSize(51, 24)
        reset:SetPoint("RIGHT", row, "RIGHT", -267, 0)
        local resetBg = reset:CreateTexture(nil, "BACKGROUND")
        resetBg:SetAllPoints()
        resetBg:SetColorTexture(0.17, 0.085, 0.045, 0.95)
        local resetLabel = CreateLabel(reset, "Reset", "GameFontNormalSmall")
        resetLabel:SetPoint("CENTER")
        resetLabel:SetTextColor(1, 0.81, 0.45)
        reset:SetScript("OnClick", function()
            if resize:ResetPosition(key) then
                refreshCoordinates()
            end
        end)
        local valueBox = CreateFrame("EditBox", nil, row)
        valueBox:SetSize(48, 24)
        valueBox:SetPoint("RIGHT", row, "RIGHT", -27, 0)
        valueBox:SetAutoFocus(false)
        valueBox:SetNumeric(true)
        valueBox:SetMaxLetters(3)
        valueBox:SetFontObject("GameFontNormal")
        valueBox:SetTextColor(1, 0.81, 0.45)
        valueBox:SetJustifyH("CENTER")
        selectAllOnDoubleClick(valueBox)
        local bg = valueBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        addon.Theme:Paint(bg, "field", 0.95)
        local percent = CreateLabel(row, "%", "GameFontNormal")
        percent:SetPoint("LEFT", valueBox, "RIGHT", 3, 0)
        percent:SetTextColor(0.95, 0.77, 0.47)
        local function updateText()
            local setting = resize:GetSetting(key)
            if setting and not valueBox:HasFocus() then
                valueBox:SetText(tostring(math.floor((setting.scale or 1)*100+0.5)))
            end
        end
        check:SetScript("OnClick", function(self)
            local setting = resize:GetSetting(key)
            setting.enabled = not not self:GetChecked()
            drag:SetEnabled(setting.enabled)
            reset:SetEnabled(setting.enabled)
            resize:Refresh()
            refreshCoordinates()
        end)
        drag:SetScript("OnClick", function(self)
            local setting = resize:GetSetting(key)
            setting.draggable = not not self:GetChecked()
            resize:Refresh()
        end)
        local function commit()
            local value = tonumber(valueBox:GetText())
            if value then resize:SetScale(key, value) end
            valueBox:ClearFocus()
            updateText()
        end
        valueBox:SetScript("OnEnterPressed", commit)
        valueBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); updateText() end)
        valueBox:SetScript("OnEditFocusLost", updateText)
        resizePanel:HookScript("OnShow", function()
            local setting = resize:GetSetting(key)
            check:SetChecked(setting.enabled)
            drag:SetChecked(setting.draggable ~= false)
            drag:SetEnabled(setting.enabled)
            reset:SetEnabled(setting.enabled)
            updateText()
            refreshCoordinates()
        end)
        reset:SetEnabled(cfg.enabled)
        updateText()
        refreshCoordinates()
    end
    selectTab("General")
    function page:SelectSubpage(name) if tabs[name] then selectTab(name) end end
    page:HookScript("OnShow", function() selectTab("General") end)
    return page
end

local function CreateMinimapPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Minimap = page
    page:HookScript("OnShow", function() addon.Minimap:SetPositioningPreview(true) end)
    page:HookScript("OnHide", function() addon.Minimap:SetPositioningPreview(false) end)
    local db = addon.db.profile.minimap
    db.borderStyle = db.borderStyle or "bronze"
    local activeTab = "General"
    local tabButtons = {}
    local tabPanels = {}

    local headingPanel = CreatePanel(page, -8, 76)
    CreateSection(headingPanel, "MINIMAP", -12)
    local enabled = addon.Theme:CreateCheckbox(headingPanel)
    enabled:SetSize(25, 25)
    enabled:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 16, -41)
    enabled:SetChecked(db.enabled)
    local enabledLabel = CreateLabel(headingPanel, "Enable Minimap", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    enabled:SetScript("OnClick", function(self)
        db.enabled = not not self:GetChecked()
        if addon.Minimap then addon.Minimap:Apply() end
    end)

    local main = CreatePanel(page, -100, 400)
    -- Reserve a separate strip outside the content panel for protruding tabs.
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
    main:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    if main.SetClipsChildren then main:SetClipsChildren(true) end
    -- Text tabs use the same bronze borders and plum selection as categories.
    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", main, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 145)

    local function RefreshTabs()
        for name, button in pairs(tabButtons) do
            local selected = name == activeTab
            addon.Theme:StyleSettingsTab(button, selected)
            button.label:SetTextColor(selected and 1 or 0.95,
                selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54,
                selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do
                edge:SetColorTexture(selected and 0.83 or 0.54,
                    selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95)
            end
        end
        for name, panel in pairs(tabPanels) do panel:SetShown(name == activeTab) end
        -- Fit each tab's background to its content, without escaping the window.
        local heights = {General = 430, ["Map Info"] = 352, Buttons = 265, Visibility = 335, Fonts = 545}
        local available = math.max(120, page:GetHeight() - 110)
        main:ClearAllPoints()
        main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
        main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
        main:SetHeight(math.min(heights[activeTab] or 430, available))
        local viewport = tabPanels[activeTab]
        if viewport then viewport:SetVerticalScroll(0) end
    end

    page:SetScript("OnSizeChanged", function() RefreshTabs() end)

    for i, name in ipairs({"General", "Map Info", "Buttons", "Visibility", "Fonts"}) do
        local b = CreateFrame("Button", nil, tabBar)
        b:SetSize(108, 29)
        b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -((i - 1) * 29))
        b.fill = b:CreateTexture(nil, "BACKGROUND")
        b.fill:SetAllPoints()
        b.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = b:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            b.edges[#b.edges + 1] = edge
        end
        -- Mirror the navigation accent: right edge for the right-side tabs.
        b.accent = b:CreateTexture(nil, "OVERLAY")
        b.accent:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
        b.accent:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        b.accent:SetWidth(3)
        b.label = CreateLabel(b, name, "GameFontNormal")
        b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
        b:SetScript("OnClick", function() activeTab = name; RefreshTabs() end)
        b:SetScript("OnEnter", function()
            if activeTab ~= name then addon.Theme:StyleSettingsTab(b, false, true) end
        end)
        b:SetScript("OnLeave", RefreshTabs)
        tabButtons[name] = b
    end

    local function NewTab(name)
        local viewport = CreateFrame("ScrollFrame", nil, main)
        viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -12)
        viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 10)
        if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
        viewport:EnableMouseWheel(true)
        local panel = CreateFrame("Frame", nil, viewport)
        panel:SetHeight(({General = 505, ["Map Info"] = 320, Buttons = 300, Visibility = 283, Fonts = 535})[name] or 400)
        panel:SetWidth(math.max(1, viewport:GetWidth()))
        viewport:SetScrollChild(panel)
        viewport:SetScript("OnSizeChanged", function(self)
            panel:SetWidth(math.max(1, self:GetWidth()))
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(self:GetVerticalScroll(), limit))
        end)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 36)))
        end)
        if name == "Fonts" then
            local bar = CreateFrame("Slider", nil, main)
            bar:SetOrientation("VERTICAL")
            bar:SetWidth(12)
            bar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -12)
            bar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 12)
            bar:SetMinMaxValues(0, 1)
            bar:SetValueStep(1)
            local track = bar:CreateTexture(nil, "BACKGROUND")
            track:SetAllPoints()
            addon.Theme:Paint(track, "field", 0.9)
            local thumb = bar:CreateTexture(nil, "OVERLAY")
            thumb:SetSize(14, 38)
            addon.Theme:StyleScrollThumb(thumb)
            bar:SetThumbTexture(thumb)
            viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -19, 10)
            local syncing = false
            local function RefreshScroll()
                local limit = math.max(0, panel:GetHeight() - viewport:GetHeight())
                bar:SetMinMaxValues(0, math.max(1, limit))
                bar:SetShown(limit > 1)
                if not syncing then
                    syncing = true
                    bar:SetValue(math.min(limit, viewport:GetVerticalScroll()))
                    syncing = false
                end
            end
            bar:SetScript("OnValueChanged", function(_, value)
                if syncing then return end
                syncing = true
                viewport:SetVerticalScroll(value)
                syncing = false
            end)
            viewport:HookScript("OnVerticalScroll", RefreshScroll)
            viewport:HookScript("OnSizeChanged", RefreshScroll)
            viewport:HookScript("OnShow", RefreshScroll)
        end
        tabPanels[name] = viewport
        return panel
    end
    function page:SelectSubpage(name)
        if tabButtons[name] then activeTab = name; RefreshTabs() end
    end

    local general = NewTab("General")
    local mapInfo = NewTab("Map Info")
    local buttons = NewTab("Buttons")
    local visibility = NewTab("Visibility")
    local fonts = NewTab("Fonts")

    local function SimpleRow(parent, title, y)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(43)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        addon.Theme:Paint(bg, "row", 0.9)
        local label = CreateLabel(row, title, "GameFontNormal")
        label:SetPoint("LEFT", row, "LEFT", 14, 0)
        label:SetTextColor(1, 0.78, 0.39)
        return row
    end
    local function Toggle(parent, title, y, key)
        local row = SimpleRow(parent, title, y)
        local check = addon.Theme:CreateCheckbox(row)
        check:SetPoint("RIGHT", row, "RIGHT", -15, 0)
        check:SetChecked(db[key])
        check:SetScript("OnClick", function(self)
            db[key] = not not self:GetChecked()
            if addon.Minimap then addon.Minimap:Apply() end
            if addon.MinimapInfo then addon.MinimapInfo:Apply() end
            if addon.MinimapButtons then addon.MinimapButtons:Apply() end
        end)
    end
    local function Select(parent, title, y, key, values)
        local row = SimpleRow(parent, title, y)
        local button = CreateFrame("Button", nil, row)
        button:SetSize(156, 24)
        button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        addon.Theme:Paint(fill, "field", 1)
        local text = CreateLabel(button, "", "GameFontNormal")
        text:SetPoint("CENTER")
        local arrow = CreateLabel(button, "v", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", -6, 0)
        local menu = CreateFrame("Frame", nil, button)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(button:GetFrameLevel() + 20)
        menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
        menu:SetSize(156, #values * 24 + 4)
        local background = menu:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        addon.Theme:Paint(background, "field", 1)
        local function display()
            for _, choice in ipairs(values) do
                if db[key] == choice[1] then text:SetText(choice[2]); return end
            end
            text:SetText("Select...")
        end
        for i, choice in ipairs(values) do
            local item = CreateFrame("Button", nil, menu)
            item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * 24)
            item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i - 1) * 24)
            item:SetHeight(24)
            local label = CreateLabel(item, choice[2], "GameFontHighlightSmall")
            label:SetPoint("LEFT", 8, 0)
            item:SetScript("OnClick", function()
                db[key] = choice[1]
                display()
                menu:Hide()
                if addon.Minimap then addon.Minimap:Apply() end
            end)
        end
        menu:Hide()
        button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
        display()
    end
    Select(general, "MAP SHAPE (RELOAD)", -4, "style",
        {{"round", "Round"}, {"square", "Square"}})
    Select(general, "AUTO ZOOM OUT", -49, "autoZoom",
        {{0, "Off"}, {5, "5 seconds"}, {10, "10 seconds"}, {30, "30 seconds"}})
    local indoorCheck = addon.Theme:CreateCheckbox(general)
    indoorCheck:SetSize(25, 25)
    indoorCheck:SetPoint("TOPLEFT", general, "TOPLEFT", 16, -96)
    indoorCheck:SetChecked(db.ignoreIndoorZoom)
    local indoorLabel = CreateLabel(general, "Ignore Indoors", "GameFontHighlight")
    indoorLabel:SetPoint("LEFT", indoorCheck, "RIGHT", 7, 0)
    indoorLabel:SetTextColor(1, 0.78, 0.39)
    indoorCheck:SetScript("OnClick", function(self)
        db.ignoreIndoorZoom = not not self:GetChecked()
    end)
    CreateSlider(general, "MINIMAP ICON SCALE",
        "Scale player and tracking icons.",
        1.0, 2.5, 0.1, db.iconScale, -143, function(value)
            db.iconScale = value
            if addon.Minimap then addon.Minimap:Apply() end
        end)
    CreateSlider(general, "MINIMAP WINDOW SCALE",
        "Resize the entire minimap and its frame.",
        0.7, 1.5, 0.05, db.mapScale, -206, function(value)
            db.mapScale = value
            if addon.Minimap then addon.Minimap:Apply() end
        end)
    for index, axis in ipairs({"x", "y"}) do
        local slider = CreateSlider(general, axis:upper() .. " OFFSET", "From screen center",
            -3000, 3000, 1, db[axis] or 0, -272 - (index - 1) * 58, function(value)
                db[axis] = value
                addon.Minimap:Apply()
            end, true, true)
        local previous = slider
        for _, step in ipairs({1, -1}) do
            local button = addon.Theme:CreateButton(general, step > 0 and "+" or "-", 24, 22)
            button:SetPoint("RIGHT", previous, "LEFT", -4, 0)
            button:SetScript("OnClick", function() slider:SetValue(slider:GetValue() + step) end)
            previous = button
        end
    end
    Select(general, "SQUARE MAP BORDER", -382, "borderStyle", {{"bronze", "Classic bronze"}, {"slim", "Slim Bazi"}})
    local note = CreateLabel(general,
        "Map shape and Enable Minimap require /reload to restore Blizzard's map safely.",
        "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", general, "TOPLEFT", 12, -443)
    note:SetWidth(340)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.66, 0.63, 0.59, 1)
    local function Planned(parent, title, description)
        local heading = CreateLabel(parent, title, "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 14, -12)
        local label = CreateLabel(parent, description, "GameFontHighlight")
        label:SetPoint("TOPLEFT", 14, -49)
        label:SetWidth(350)
        label:SetJustifyH("LEFT")
    end
    local modes = {{"off", "Never"}, {"hover", "On Mouseover"}, {"always", "Always"}}
    Select(mapInfo, "COORDINATES", -4, "coords", modes)
    Select(mapInfo, "FPS", -49, "fps", modes)
    Select(mapInfo, "LATENCY", -94, "latency", modes)
    Select(mapInfo, "CLOCK", -139, "clock", modes)
    local mapHint = CreateLabel(mapInfo,
        "Coordinates stay below the map. FPS and latency appear at its lower-right edge.",
        "GameFontHighlightSmall")
    mapHint:SetPoint("TOPLEFT", mapInfo, "TOPLEFT", 14, -200)
    mapHint:SetWidth(340)
    mapHint:SetJustifyH("LEFT")
    mapHint:SetTextColor(0.66, 0.63, 0.59, 1)
    Toggle(buttons, "MIDDLE CLICK MICRO MENU", -4, "microMenu")
    Toggle(buttons, "HIDE ADDON BUTTONS UNTIL HOVER", -49, "hideAddonButtons")
    Toggle(buttons, "SHOW BAZI UI MINIMAP BUTTON", -94, "showMinimapButton")
    local buttonsHint = CreateLabel(buttons,
        "Middle-click opens the micro menu outside combat.",
        "GameFontHighlightSmall")
    buttonsHint:SetPoint("TOPLEFT", buttons, "TOPLEFT", 14, -148)
    buttonsHint:SetWidth(345)
    buttonsHint:SetJustifyH("LEFT")
    buttonsHint:SetTextColor(0.66, 0.63, 0.59, 1)
    for index, axis in ipairs({"X", "Y"}) do
        local key = "mail" .. axis
        CreateSlider(buttons, "MAIL ICON " .. axis, "Offset from the minimap’s top left.", -300, 350, 1,
            db[key] or (axis == "X" and 40 or 8), -185 - (index - 1) * 51, function(value)
                db[key] = value
                addon.Minimap:Apply()
            end, true, true)
    end
    Toggle(visibility, "HIDE DAY / NIGHT", -4, "hideDayNight")
    Toggle(visibility, "HIDE TRACKING", -49, "hideTracking")
    Toggle(visibility, "HIDE ZONE LOCATION", -94, "hideZone")
    Toggle(visibility, "HIDE CLOCK", -139, "hideClock")
    Toggle(visibility, "HIDE CALENDAR", -184, "hideCalendar")
    Toggle(visibility, "HIDE MAIL ICON", -229, "hideMail")
    local fontChoices = {{"GLOBAL", "Global"}, {"FRIZQT", "Friz Quadrata"},
        {"ARIAL", "Arial Narrow"}, {"MORPHEUS", "Morpheus"}}
    local outlineChoices = {{"NONE", "None"}, {"OUTLINE", "Outline"},
        {"THICKOUTLINE", "Thick"}}
    local function FontGroup(title, y, key)
        local cfg = db[key]
        local scope = key == "zoneFont" and "Minimap:Zone" or key == "clockFont" and "Minimap:Clock" or "Minimap:Info"
        -- Separate the three font settings visually without changing control positions.
        local groupBack = fonts:CreateTexture(nil, "BACKGROUND")
        groupBack:SetPoint("TOPLEFT", fonts, "TOPLEFT", 6, y + 12)
        groupBack:SetPoint("TOPRIGHT", fonts, "TOPRIGHT", -6, y + 12)
        groupBack:SetHeight(172)
        addon.Theme:Paint(groupBack, "panel", 0.52)
        -- Thin bronze outline around each separate font category.
        local edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = fonts:CreateTexture(nil, "BORDER")
            edge:SetColorTexture(0.68, 0.46, 0.24, 0.85)
            if side == "TOP" then
                edge:SetPoint("TOPLEFT", groupBack, "TOPLEFT")
                edge:SetPoint("TOPRIGHT", groupBack, "TOPRIGHT")
                edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT", groupBack, "BOTTOMLEFT")
                edge:SetPoint("BOTTOMRIGHT", groupBack, "BOTTOMRIGHT")
                edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT", groupBack, "TOPLEFT")
                edge:SetPoint("BOTTOMLEFT", groupBack, "BOTTOMLEFT")
                edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT", groupBack, "TOPRIGHT")
                edge:SetPoint("BOTTOMRIGHT", groupBack, "BOTTOMRIGHT")
                edge:SetWidth(1)
            end
            edges[#edges + 1] = edge
        end
        local heading = CreateLabel(fonts, title, "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", fonts, "TOPLEFT", 14, y)
        heading:SetTextColor(1, 0.79, 0.42)
        -- A per-group proxy table lets Select use the same controls as General.
        -- The selection is copied into the real font configuration immediately.
        local function fontSelect(label, offset, field, choices)
            local row = CreateFrame("Frame", nil, fonts)
            row:SetPoint("TOPLEFT", fonts, "TOPLEFT", 0, offset)
            row:SetPoint("TOPRIGHT", fonts, "TOPRIGHT", 0, offset)
            row:SetHeight(28)
            local rowLabel = CreateLabel(row, label, "GameFontNormal")
            rowLabel:SetPoint("LEFT", row, "LEFT", 14, 0)
            rowLabel:SetTextColor(1, 0.78, 0.39)
            local b = CreateFrame("Button", nil, row)
            b:SetSize(156, 24)
            b:SetPoint("RIGHT", row, "RIGHT", -14, 0)
            local bg = b:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            addon.Theme:Paint(bg, "field", 1)
            local txt = CreateLabel(b, "", "GameFontNormal")
            txt:SetPoint("CENTER")
            local menu = CreateFrame("Frame", nil, b)
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetFrameLevel(b:GetFrameLevel() + 20)
            menu:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
            menu:SetSize(156, #choices * 24 + 4)
            local fill = menu:CreateTexture(nil, "BACKGROUND")
            fill:SetAllPoints()
            addon.Theme:Paint(fill, "field", 1)
            local function refresh()
                for _, choice in ipairs(choices) do
                    if cfg[field] == choice[1] then txt:SetText(choice[2]); break end
                end
            end
            for i, choice in ipairs(choices) do
                local item = CreateFrame("Button", nil, menu)
                item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2-(i-1)*24)
                item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2-(i-1)*24)
                item:SetHeight(24)
                local label = CreateLabel(item, choice[2], "GameFontHighlightSmall")
                label:SetPoint("LEFT", 8, 0)
                item:SetScript("OnClick", function()
                    cfg[field] = choice[1]
                    if field == "font" then addon.Typography.ModuleChanged(scope, "font") end
                    refresh()
                    menu:Hide()
                    if addon.MinimapInfo then addon.MinimapInfo:ApplyFonts() end
                end)
            end
            menu:Hide()
            b:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
            refresh()
        end
        fontSelect("FONT", y-20, "font", fontChoices)
        fontSelect("OUTLINE", y-49, "outline", outlineChoices)
        CreateSlider(fonts, "SIZE", "Text size", 8, 30, 1, cfg.size, y-79, function(value)
            if value ~= cfg.size then addon.Typography.ModuleChanged(scope, "size") end
            cfg.size = value
            if addon.MinimapInfo then addon.MinimapInfo:ApplyFonts() end
        end, true)
        local shadow = addon.Theme:CreateCheckbox(fonts)
        shadow:SetPoint("TOPLEFT", fonts, "TOPLEFT", 14, y-130)
        shadow:SetChecked(cfg.shadow)
        local label = CreateLabel(fonts, "Shadow", "GameFontNormal")
        label:SetPoint("LEFT", shadow, "RIGHT", 6, 0)
        label:SetTextColor(1, 0.79, 0.42)
        shadow:SetScript("OnClick", function(self)
            cfg.shadow = not not self:GetChecked()
            if addon.MinimapInfo then addon.MinimapInfo:ApplyFonts() end
        end)
    end
    FontGroup("ZONE TEXT", -10, "zoneFont")
    FontGroup("CLOCK", -185, "clockFont")
    FontGroup("INFO TEXT", -360, "infoFont")
    fonts:SetHeight(535)
    RefreshTabs()
    return page
end

local function CreateMapPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Map = page
    local panel = CreatePanel(page, -8, 392)
    local heading = CreateSection(panel, "MAP", -14)
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 50, -14)
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("RIGHT", heading, "LEFT", -8, 0)
    icon:SetTexture(MAP_ICON)
    local map = addon.Map
    local enabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enabled:SetSize(22, 22)
    enabled:SetPoint("TOPLEFT", 20, -47)
    enabled:SetChecked(not map.GetOption("stockDebug"))
    local enabledLabel = CreateLabel(enabled, "Enable Map Module", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    addon.Theme:SettingsHelp(enabled, "Enable Map Module", "Requires /reload to apply.", enabledLabel)
    enabled:SetScript("OnClick", function(self)
        SlashCmdList.BAZIMAPSTOCK(self:GetChecked() and "off" or "on")
    end)

    for index, option in ipairs(map.options) do
        local key, caption = unpack(option)
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        checkbox:SetSize(22, 22)
        checkbox:SetPoint("TOPLEFT", 20, -77 - (index - 1) * 26)
        checkbox:SetChecked(map.GetOption(key))
        local label = CreateLabel(checkbox, caption, "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        addon.Theme:SettingsHelp(checkbox, caption, nil, label)
        checkbox:SetScript("OnClick", function(self) map.SetOption(key, not not self:GetChecked()) end)
    end
    local points = CreateLabel(panel, "POINTS OF INTEREST", "GameFontNormal")
    points:SetPoint("TOPLEFT", 250, -77)
    for index, option in ipairs(map.pointOptions) do
        local key, caption = unpack(option)
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        checkbox:SetSize(22, 22)
        checkbox:SetPoint("TOPLEFT", 248, -98 - (index - 1) * 26)
        checkbox:SetChecked(map.GetOption(key))
        local label = CreateLabel(checkbox, caption, "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        addon.Theme:SettingsHelp(checkbox, caption, "Controls whether this type of marker appears on the world map.", label)
        checkbox:SetScript("OnClick", function(self) map.SetOption(key, not not self:GetChecked()) end)
    end

    CreateSlider(panel, "POINT OF INTEREST SIZE", "", 12, 44, 1, map.GetOption("pointSize"), -305, function(value)
        map.SetOption("pointSize", value)
    end, true, true)

    local note = CreateLabel(panel, "Drag the map by its header and scale it from the lower-right corner.", "GameFontHighlightSmall")
    note:SetPoint("BOTTOMLEFT", 22, 25)
end

local function CreateTooltipPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Tooltip = page
    local db = addon.db.profile.tooltip
    local activeTab = "General"
    local tabButtons = {}
    local tabPanels = {}

    local headingPanel = CreatePanel(page, -8, 76)
    CreateSection(headingPanel, "TOOLTIP", -12)
    local enabled = addon.Theme:CreateCheckbox(headingPanel)
    enabled:SetSize(25, 25)
    enabled:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 16, -41)
    enabled:SetChecked(db.enabled)
    local enabledLabel = CreateLabel(headingPanel, "Enable Tooltip", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    enabled:SetScript("OnClick", function(self)
        db.enabled = not not self:GetChecked()
        if addon.Tooltip then addon.Tooltip:Apply() end
    end)

    local main = CreatePanel(page, -100, 400)
    -- Reserve a separate strip outside the content panel for protruding tabs.
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
    main:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    if main.SetClipsChildren then main:SetClipsChildren(true) end
    -- Text tabs use the same bronze borders and plum selection as categories.
    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", main, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 87)

    local function RefreshTabs()
        for name, button in pairs(tabButtons) do
            local selected = name == activeTab
            addon.Theme:StyleSettingsTab(button, selected)
            button.label:SetTextColor(selected and 1 or 0.95,
                selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54,
                selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do
                edge:SetColorTexture(selected and 0.83 or 0.54,
                    selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95)
            end
        end
        for name, panel in pairs(tabPanels) do panel:SetShown(name == activeTab) end
    end

    for i, name in ipairs({"General", "Contents", "Fonts"}) do
        local b = CreateFrame("Button", nil, tabBar)
        b:SetSize(108, 29)
        b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -((i - 1) * 29))
        b.fill = b:CreateTexture(nil, "BACKGROUND")
        b.fill:SetAllPoints()
        b.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = b:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            b.edges[#b.edges + 1] = edge
        end
        -- Mirror the navigation accent: right edge for the right-side tabs.
        b.accent = b:CreateTexture(nil, "OVERLAY")
        b.accent:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
        b.accent:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        b.accent:SetWidth(3)
        b.label = CreateLabel(b, name, "GameFontNormal")
        b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
        b:SetScript("OnClick", function() activeTab = name; RefreshTabs() end)
        b:SetScript("OnEnter", function()
            if activeTab ~= name then addon.Theme:Paint(b.fill, "muted", 0.98) end
        end)
        b:SetScript("OnLeave", RefreshTabs)
        tabButtons[name] = b
    end

    local function NewTab(name)
        local viewport = CreateFrame("ScrollFrame", nil, main)
        viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -12)
        viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 10)
        if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
        viewport:EnableMouseWheel(true)
        local panel = CreateFrame("Frame", nil, viewport)
        panel:SetHeight(name == "Fonts" and 490 or (name == "Contents" and 420 or 390))
        panel:SetWidth(math.max(1, viewport:GetWidth()))
        viewport:SetScrollChild(panel)
        viewport:SetScript("OnSizeChanged", function(self)
            panel:SetWidth(math.max(1, self:GetWidth()))
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(self:GetVerticalScroll(), limit))
        end)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 36)))
        end)
        if name == "Fonts" then
            local bar = CreateFrame("Slider", nil, main)
            bar:SetOrientation("VERTICAL")
            bar:SetWidth(12)
            bar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -12)
            bar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 12)
            bar:SetMinMaxValues(0, 1)
            bar:SetValueStep(1)
            local track = bar:CreateTexture(nil, "BACKGROUND")
            track:SetAllPoints()
            addon.Theme:Paint(track, "field", 0.9)
            local thumb = bar:CreateTexture(nil, "OVERLAY")
            thumb:SetSize(14, 38)
            addon.Theme:StyleScrollThumb(thumb)
            bar:SetThumbTexture(thumb)
            viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -19, 10)
            local syncing = false
            local function RefreshScroll()
                local limit = math.max(0, panel:GetHeight() - viewport:GetHeight())
                bar:SetMinMaxValues(0, math.max(1, limit))
                bar:SetShown(limit > 1)
                if not syncing then
                    syncing = true
                    bar:SetValue(math.min(limit, viewport:GetVerticalScroll()))
                    syncing = false
                end
            end
            bar:SetScript("OnValueChanged", function(_, value)
                if syncing then return end
                syncing = true
                viewport:SetVerticalScroll(value)
                syncing = false
            end)
            viewport:HookScript("OnVerticalScroll", RefreshScroll)
            viewport:HookScript("OnSizeChanged", RefreshScroll)
            viewport:HookScript("OnShow", RefreshScroll)
        end
        tabPanels[name] = viewport
        return panel
    end
    function page:SelectSubpage(name)
        if tabButtons[name] then activeTab = name; RefreshTabs() end
    end

    local general = NewTab("General")
    local contents = NewTab("Contents")
    local fonts = NewTab("Fonts")

    local function Row(parent, text, y, description)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(description and 55 or 42)
        local fill = row:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        -- Font categories already have a single framed background.
        -- Avoid opaque per-control rows that visually cut through the border.
        if parent == fonts then
            addon.Theme:Paint(fill, "row", 0)
        else
            addon.Theme:Paint(fill, "row", 0.90)
        end
        local label = CreateLabel(row, text, "GameFontNormal")
        label:SetPoint("TOPLEFT", row, "TOPLEFT", 14, description and -10 or -12)
        label:SetTextColor(1, 0.78, 0.39)
        if description then
            local hint = CreateLabel(row, description, "GameFontHighlightSmall")
            hint:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -30)
            hint:SetTextColor(0.91, 0.78, 0.61)
        end
        return row, label
    end
    local function Update() if addon.Tooltip then addon.Tooltip:Apply() end end
    local function Choice(parent, text, y, getValue, setValue, choices)
        local row = Row(parent, text, y)
        local button = CreateFrame("Button", nil, row)
        button:SetSize(154, 23)
        button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        addon.Theme:Paint(fill, "field", 1)
        local border = button:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT"); border:SetPoint("TOPRIGHT"); border:SetHeight(1)
        border:SetColorTexture(0.75, 0.55, 0.29)
        local label = CreateLabel(button, "", "GameFontNormal")
        label:SetPoint("CENTER", button, "CENTER", -5, 0)
        local arrow = CreateLabel(button, "v", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        local menu = CreateFrame("Frame", nil, button)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(button:GetFrameLevel() + 20)
        menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
        menu:SetSize(154, #choices * 24 + 4)
        local bg = menu:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        addon.Theme:Paint(bg, "field", 1)
        local function Display()
            for _, choice in ipairs(choices) do
                if choice[1] == getValue() then label:SetText(choice[2]); return end
            end
            label:SetText("Select...")
        end
        for i, choice in ipairs(choices) do
            local option = CreateFrame("Button", nil, menu)
            option:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i-1)*24)
            option:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i-1)*24)
            option:SetHeight(24)
            local t = CreateLabel(option, choice[2], "GameFontHighlightSmall")
            t:SetPoint("LEFT", option, "LEFT", 8, 0)
            option:SetScript("OnEnter", function() t:SetTextColor(1, 0.78, 0.39) end)
            option:SetScript("OnLeave", function() t:SetTextColor(1, 1, 1) end)
            option:SetScript("OnClick", function()
                setValue(choice[1]); Display(); menu:Hide(); Update()
            end)
        end
        menu:Hide()
        button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
        Display()
        return row
    end
    local function Number(parent, text, y, getValue, setValue, min, max, step)
        local row = Row(parent, text, y)
        local edit = CreateFrame("EditBox", nil, row)
        edit:SetSize(42, 20)
        edit:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        edit:SetAutoFocus(false)
        edit:SetFontObject("GameFontNormal")
        edit:SetTextColor(1, 0.81, 0.45)
        edit:SetJustifyH("CENTER")
        local bg = edit:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        addon.Theme:Paint(bg, "field", 1)
        local slider = CreateFrame("Slider", nil, row)
        slider:SetOrientation("HORIZONTAL")
        slider:SetSize(115, 18)
        slider:SetPoint("RIGHT", edit, "LEFT", -10, 0)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        local track = slider:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(7)
        track:SetTexture(ASSET .. "Sliders\\Slider_Track.png")
        local progress = slider:CreateTexture(nil, "ARTWORK")
        progress:SetTexture("Interface\\Buttons\\WHITE8X8")
        progress:SetVertexColor(0.94, 0.67, 0.25)
        progress:SetHeight(3)
        progress:SetPoint("LEFT", slider, "LEFT", 0, 0)
        local function RefreshProgress(value)
            local fraction = math.max(0, math.min(1, (value - min) / (max - min)))
            progress:SetWidth(math.max(0.1, 12 + 91 * fraction))
        end
        local thumb = slider:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(24, 28)
        addon.Theme:StyleScrollThumb(thumb)
        slider:SetThumbTexture(thumb)
        local function Commit(v)
            v = tonumber(v)
            if not v then v = getValue() end
            v = math.max(min, math.min(max, v))
            v = math.floor(v / step + 0.5) * step
            v = tonumber(string.format("%.3f", v))
            setValue(v); slider:SetValue(v); RefreshProgress(v); edit:SetText(string.format("%g", v)); Update()
        end
        local syncing
        slider:SetScript("OnValueChanged", function(_, value)
            local v = tonumber(string.format("%.3f", math.floor(value / step + 0.5) * step))
            RefreshProgress(v)
            if not edit:HasFocus() then edit:SetText(string.format("%g", v)) end
            if not syncing then setValue(v); Update() end
        end)
        slider:SetValue(getValue())
        RefreshProgress(getValue())
        edit:SetText(string.format("%g", getValue()))
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        edit:SetScript("OnEnterPressed", function(self)
            Commit((self:GetText() or ""):gsub(",", ".")); self:ClearFocus()
        end)
        edit:SetScript("OnEscapePressed", function(self)
            self:SetText(string.format("%g", getValue())); self:ClearFocus()
        end)
        edit:SetScript("OnEditFocusLost", function(self)
            Commit((self:GetText() or ""):gsub(",", "."))
        end)
        row:HookScript("OnShow", function()
            syncing = true
            slider:SetValue(getValue())
            edit:SetText(string.format("%g", getValue()))
            syncing = false
        end)
        return row
    end
    local function Check(parent, text, y, getValue, setValue)
        local row = Row(parent, text, y)
        local b = addon.Theme:CreateCheckbox(row)
        b:SetSize(25, 25)
        b:SetPoint("RIGHT", row, "RIGHT", -19, 0)
        b:SetChecked(getValue())
        b:SetScript("OnClick", function(self)
            setValue(not not self:GetChecked()); Update()
        end)
    end
    local anchorRow, anchorRowLabel = Row(general, "EDIT ANCHOR POSITION", -54)
    local editAnchor = addon.Theme:CreateCheckbox(anchorRow)
    editAnchor:SetSize(25, 25)
    editAnchor:SetPoint("RIGHT", anchorRow, "RIGHT", -19, 0)
    local anchorText = CreateLabel(anchorRow, "Edit Position", "GameFontHighlight")
    anchorText:SetPoint("RIGHT", editAnchor, "LEFT", -8, 0)
    local cursorChoice
    local function RefreshAnchorMode()
        local isMouse = db.anchor == "mouse"
        editAnchor:SetShown(not isMouse)
        anchorText:SetShown(not isMouse)
        anchorRowLabel:SetShown(not isMouse)
        if isMouse then
            if not cursorChoice then
                cursorChoice = Choice(general, "CURSOR POSITION", -54,
                    function()
                        local p = db.cursorPosition
                        return (p == "TOPLEFT" or p == "LEFT" or p == "BOTTOMLEFT") and "LEFT" or "RIGHT"
                    end,
                    function(v) db.cursorPosition = v end,
                    {{"LEFT", "Left"}, {"RIGHT", "Right"}})
            end
            cursorChoice:Show()
        elseif cursorChoice then
            cursorChoice:Hide()
        end
        if isMouse and addon.Tooltip then addon.Tooltip:SetEditAnchor(false) end
        if isMouse then editAnchor:SetChecked(false) end
    end
    Choice(general, "ANCHOR POINT", -4, function() return db.anchor end,
        function(v) db.anchor = v; RefreshAnchorMode() end,
        {{"corner", "Static"}, {"mouse", "Mouse Cursor"}})
    editAnchor:SetScript("OnClick", function(self)
        if addon.Tooltip then addon.Tooltip:SetEditAnchor(not not self:GetChecked()) end
    end)
    RefreshAnchorMode()
    Number(general, "SCALE", -104, function() return db.scale end,
        function(v) db.scale = v end, 0.5, 1.5, 0.01)
    Number(general, "BACKGROUND OPACITY", -154, function() return db.opacity end,
        function(v) db.opacity = v end, 0, 1, 0.01)

    local contentOptions = {
        {"GUILD NAME", "guild"}, {"THREAT", "threat"}, {"SHOW IDS", "ids"},
        {"SHOW ITEM LEVEL", "itemLevel"}, {"CLASS COLORED NAMES", "classNames"},
        {"SHOW TARGET'S TARGET", "targetTarget"}, {"HIDE FACTION", "hideFaction"},
        {"SMART TOOLTIPS (SHIFT FOR DETAILS)", "smart"}
    }
    for i, entry in ipairs(contentOptions) do
        local key = entry[2]
        local y = -4 - (i-1)*43
        if entry[3] then
            Choice(contents, entry[1], y, function() return db[key] end,
                function(v) db[key] = v end, entry[3])
        else
            Check(contents, entry[1], y, function() return db[key] end,
                function(v) db[key] = v end)
        end
    end

    Number(contents, "HEALTH BAR PERCENT TEXT SIZE", -352, function() return db.healthPercentSize or 10 end,
        function(value) db.healthPercentSize = value end, 7, 24, 1)

    local function FontGroup(config, offset, title)
        local scope = title == "TITLE TEXT" and "Tooltip:Title" or "Tooltip:Body"
        local groupBack = fonts:CreateTexture(nil, "BACKGROUND")
        groupBack:SetPoint("TOPLEFT", fonts, "TOPLEFT", 6, offset + 12)
        groupBack:SetPoint("TOPRIGHT", fonts, "TOPRIGHT", -6, offset + 12)
        groupBack:SetHeight(232)
        addon.Theme:Paint(groupBack, "panel", 0.52)
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = fonts:CreateTexture(nil, "BORDER")
            edge:SetColorTexture(0.68, 0.46, 0.24, 0.85)
            if side == "TOP" then
                edge:SetPoint("TOPLEFT", groupBack, "TOPLEFT")
                edge:SetPoint("TOPRIGHT", groupBack, "TOPRIGHT")
                edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT", groupBack, "BOTTOMLEFT")
                edge:SetPoint("BOTTOMRIGHT", groupBack, "BOTTOMRIGHT")
                edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT", groupBack, "TOPLEFT")
                edge:SetPoint("BOTTOMLEFT", groupBack, "BOTTOMLEFT")
                edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT", groupBack, "TOPRIGHT")
                edge:SetPoint("BOTTOMRIGHT", groupBack, "BOTTOMRIGHT")
                edge:SetWidth(1)
            end
        end
        local titleLabel = CreateLabel(fonts, title, "GameFontNormalLarge")
        titleLabel:SetPoint("TOPLEFT", fonts, "TOPLEFT", 14, offset)
        titleLabel:SetTextColor(1, 0.79, 0.42)
        Choice(fonts, "FONT", offset-30, function() return config.font end,
            function(v) config.font = v; addon.Typography.ModuleChanged(scope, "font"); addon.TooltipFonts.Apply() end,
            {{"GLOBAL", "Global"}, {"FRIZQT", "Friz Quadrata"}, {"ARIAL", "Arial Narrow"}, {"MORPHEUS", "Morpheus"}})
        Choice(fonts, "OUTLINE", offset-78, function() return config.outline end,
            function(v) config.outline = v; if BaziUI.TooltipFonts then BaziUI.TooltipFonts.Apply() end end,
            {{"NONE", "None"}, {"OUTLINE", "Outline"}, {"THICKOUTLINE", "Thick Outline"}})
        Number(fonts, "SIZE", offset-126, function() return config.size end,
            function(v) config.size = v; addon.Typography.ModuleChanged(scope, "size"); addon.TooltipFonts.Apply() end, 8, 30, 1)
        Check(fonts, "SHADOW", offset-174, function() return config.shadow end,
            function(v) config.shadow = v; if BaziUI.TooltipFonts then BaziUI.TooltipFonts.Apply() end end)
    end
    FontGroup(db.titleFont, -4, "TITLE TEXT")
    FontGroup(db.textFont, -248, "BODY TEXT")
    fonts:SetHeight(490)
    RefreshTabs()
    return page
end

local function CreateGatheringPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Gathering = page
    local module = addon.Gathering
    local db = module:Settings()
    local header = CreatePanel(page, -8, 76)
    CreateSection(header, "GATHERING", -12)
    local function checkbox(parent, label, checked, OnClick)
        local check = addon.Theme:CreateCheckbox(parent)
        check:SetSize(25, 25)
        check:SetChecked(checked)
        check:SetScript("OnClick", function(self) OnClick(not not self:GetChecked()) end)
        local text = CreateLabel(parent, label, "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 5, 0)
        return check, text
    end
    checkbox(header, "Enable Gathering", db.enabled, function(value)
        db.enabled = value
        module:Apply()
    end):SetPoint("TOPLEFT", 16, -41)

    local function CreateBindingButton(parent, interact, label, y)
        local bindButton = addon.Theme:CreateButton(parent, "", 144, 24)
        bindButton:SetPoint("TOPRIGHT", -14, y)
        local bindLabel = CreateLabel(parent, label, "GameFontNormal")
        bindLabel:SetPoint("RIGHT", bindButton, "LEFT", -9, 0)
        bindLabel:SetTextColor(1, 0.79, 0.42)

        local capture = CreateFrame("Button", nil, parent)
        capture:SetAllPoints(UIParent)
        capture:SetFrameStrata("FULLSCREEN_DIALOG")
        capture:RegisterForClicks("AnyUp")
        capture:Hide()
        local conflictKey
        local function bindingContext()
            local get = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
            if interact == "INTERACTTARGET" and get then return get(interact) end
        end
        local function refreshBinding()
            if capture:IsShown() then return end
            local key = GetBindingKey(interact, nil, bindingContext())
            bindButton:SetText(key and GetBindingText(key) or "Bind key")
        end
        local function stopBinding()
            conflictKey = nil
            capture:EnableKeyboard(false)
            capture:Hide()
            refreshBinding()
        end
        bindButton:SetScript("OnClick", function()
            if capture:IsShown() then stopBinding(); return end
            if InCombatLockdown() then addon:Print("Change gathering keybindings after combat."); return end
            capture:Show()
            capture:EnableKeyboard(true)
            capture:SetPropagateKeyboardInput(false)
            bindButton:SetText("Press a key")
        end)
        local modifier = {LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true}
        local function bindKey(key)
            if key == "ESCAPE" or InCombatLockdown() then stopBinding(); return end
            if modifier[key] or key == "UNKNOWN" then return end
            if IsShiftKeyDown() then key = "SHIFT-" .. key end
            if IsControlKeyDown() then key = "CTRL-" .. key end
            if IsAltKeyDown() then key = "ALT-" .. key end

            local context = bindingContext()
            local first, second = GetBindingKey(interact, nil, context)
            if key == first or key == second then stopBinding(); return end
            local owner = GetBindingAction(key, nil, context)
            if module.Fishing and ((interact == module.Fishing.binding and owner == "INTERACTTARGET")
                or (interact == "INTERACTTARGET" and owner == module.Fishing.binding)) then
                addon:Print("Choose separate keys for Gathering and Fishing.")
                return
            end
            if owner and owner ~= "" and owner ~= interact and conflictKey ~= key then
                conflictKey = key
                bindButton:SetText("Press again to replace")
                addon:Print("That key is bound to " .. (_G["BINDING_NAME_" .. owner] or owner) .. ". Press it again to replace it.")
                return
            end
            local function assign(binding)
                local target = interact:match("^CLICK ([^:]+):LeftButton$")
                if target then return SetBindingClick(binding, target, "LeftButton") end
                return SetBinding(binding, interact, context)
            end
            if first and not SetBinding(first, nil, context) then stopBinding(); return end
            if not assign(key) then
                if first then assign(first) end
                addon:Print("The key could not be bound.")
            else
                local save = SaveBindings or AttemptToSaveBindings
                if save then save(GetCurrentBindingSet()) end
            end
            stopBinding()
        end
        capture:SetScript("OnKeyDown", function(_, key) bindKey(key) end)
        capture:SetScript("OnClick", function(_, mouse)
            local number = mouse == "MiddleButton" and "3" or mouse:match("^Button(%d+)$")
            if number then bindKey("BUTTON" .. number)
            else stopBinding() end
        end)
        capture:RegisterEvent("UPDATE_BINDINGS")
        capture:RegisterEvent("PLAYER_REGEN_DISABLED")
        capture:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then stopBinding()
            else refreshBinding() end
        end)
        parent:HookScript("OnShow", refreshBinding)
        parent:HookScript("OnHide", stopBinding)
        refreshBinding()
    end
    CreateBindingButton(header, "INTERACTTARGET", "Interact key", -9)

    local fishingDefinition = {"fishing", "Fishing"}
    local bobberDefinition
    for _, def in ipairs(module.categories) do
        if def[1] == "bobber" then bobberDefinition = def; break end
    end
    local body = CreatePanel(page, -100, 393)
    local tabs = CreateFrame("Frame", nil, body)
    tabs:SetPoint("TOPLEFT", 16, -16)
    tabs:SetPoint("TOPRIGHT", -16, -16)
    tabs:SetHeight(30)
    local panels, buttons = {}, {}
    local activeCategory, previewAnchor, worldPreview
    local previewOn = false
    local previewButton = addon.Theme:CreateButton(header, "Preview effect", 144, 25)
    previewButton:SetPoint("BOTTOMRIGHT", -14, 12)
    local fishingView = addon.Theme:CreateButton(header, "Bobber effect", 144, 25)
    fishingView:SetPoint("RIGHT", previewButton, "LEFT", -8, 0)
    fishingView:Hide()
    local function RefreshWorldPreview()
        if not previewOn then return end
        local key = activeCategory[1]
        local color = module.professionSpells[key] and module.professionPreviewColor
        worldPreview:Display(previewAnchor, db.categories[key], activeCategory[3], color)
    end
    local function SetPreview(shown)
        previewOn = shown
        previewButton:SetText(shown and "Stop preview" or "Preview effect")
        addon.Theme:SetButtonActive(previewButton, shown)
        if not shown then
            if previewAnchor then previewAnchor:Hide() end
            return
        end
        if not previewAnchor then
            previewAnchor = CreateFrame("Frame", nil, UIParent)
            previewAnchor:SetSize(1, 1)
            previewAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -55)
            previewAnchor:SetFrameStrata("FULLSCREEN_DIALOG")
            worldPreview = module:CreateEffect(previewAnchor)
        end
        previewAnchor:Show()
        RefreshWorldPreview()
    end
    previewButton:SetScript("OnClick", function() SetPreview(not previewOn) end)
    page:HookScript("OnHide", function() if previewOn then SetPreview(false) end end)

    local function BuildFishingPanel()
        local panel = CreateFrame("Frame", nil, body)
        panel:SetPoint("TOPLEFT", 0, -48)
        panel:SetPoint("BOTTOMRIGHT")
        local fishing = module.Fishing
        local cfg = db.fishing
        CreateBindingButton(panel, fishing.binding, "Cast / reel key", -10)
        local controls = {
            {"Enable Fishing", "enabled"}, {"Auto-loot fish", "autoLoot"},
            {"Hide friendly nameplates and NPC names", "quietNames"},
            {"Enhance fishing sounds", "focusAudio"},
            {"Hide the bobber's interaction icon", "hideBobberIcon"},
        }
        for index, control in ipairs(controls) do
            local key = control[2]
            checkbox(panel, control[1], cfg[key], function(value)
                cfg[key] = value
                fishing:Apply()
            end):SetPoint("TOPLEFT", 20, -9 - (index - 1) * 27)
        end
        CreateSlider(panel, "FISHING VOLUME (%)", "Used when Enhance fishing sounds is enabled.",
            0, 100, 5, cfg.volume, -150, function(value)
                cfg.volume = value
                fishing:Apply()
            end, true, true)
        return panel
    end
    local function BuildPanel(def)
        if def == fishingDefinition then return BuildFishingPanel() end
        local cfg = db.categories[def[1]]
        local panel = CreateFrame("Frame", nil, body)
        panel:SetPoint("TOPLEFT", 0, -48)
        panel:SetPoint("BOTTOMRIGHT")
        local tile = CreateFrame("Frame", nil, panel)
        tile:SetSize(105, 108)
        tile:SetPoint("TOPRIGHT", -19, -8)
        tile:SetClipsChildren(true)
        local sample = CreateLabel(tile, def[3], "GameFontNormal")
        sample:SetPoint("TOP", 0, -7)
        local layers = {}
        local function updateThumbnail()
            local effect = module.vendor.EFFECTS[cfg.effect] or module.vendor.EFFECTS.beam
            for _, layer in ipairs(layers) do layer:Hide() end
            for index, spec in ipairs(effect.icon) do
                local file, width, height, x, y, alpha, core = unpack(spec)
                local layer = layers[index]
                if not layer then
                    layer = tile:CreateTexture(nil, "ARTWORK", nil, index - 8)
                    layer:SetBlendMode("ADD")
                    layers[index] = layer
                end
                layer:SetTexture(ASSET .. "Gathering\\Lueur\\" .. file .. ".tga")
                layer:SetSize(width * 60, height * 60)
                layer:SetPoint("CENTER", tile, "CENTER", x * 60, y * 60 - 10)
                local mix = core and 0.6 or 0
                layer:SetVertexColor(cfg.r + (1 - cfg.r) * mix, cfg.g + (1 - cfg.g) * mix,
                    cfg.b + (1 - cfg.b) * mix, alpha)
                layer:Show()
            end
        end
        local label = def == bobberDefinition and "Highlight fishing bobber" or "Highlight " .. def[2]
        local highlight, highlightLabel = checkbox(panel, label, cfg.enabled, function(value)
            cfg.enabled = value
            if def == bobberDefinition then module.Fishing:Apply()
            else module:Apply() end
        end)
        highlight:SetPoint("TOPLEFT", 20, -11)
        local nameCheck = checkbox(panel, "Show object name", cfg.showName, function(value)
            cfg.showName = value
            RefreshWorldPreview()
            module:Apply()
        end)
        nameCheck:SetPoint("LEFT", highlightLabel, "RIGHT", 16, 0)
        local effectLabel = CreateLabel(panel, "EFFECT", "GameFontNormalSmall")
        effectLabel:SetPoint("TOPLEFT", 24, -35)
        effectLabel:SetTextColor(1, 0.79, 0.42)
        local effect = CreateFrame("Button", nil, panel)
        effect:SetSize(145, 27)
        effect:SetPoint("TOPLEFT", 24, -51)
        local fill = effect:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        addon.Theme:Paint(fill, "field", 1)
        local border = effect:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT")
        border:SetPoint("TOPRIGHT")
        border:SetHeight(1)
        border:SetColorTexture(0.75, 0.55, 0.29)
        local arrow = CreateLabel(effect, "v", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", -7, 0)
        local caption = CreateLabel(effect, "", "GameFontNormal")
        caption:SetPoint("CENTER")
        caption:SetTextColor(1, 0.79, 0.42)
        local function nameEffect(key)
            return key == "sparkle" and "Sparkles" or key:gsub("^%l", string.upper)
        end
        caption:SetText(nameEffect(cfg.effect))
        local menu = CreateFrame("Frame", nil, panel)
        menu:SetPoint("TOPLEFT", effect, "BOTTOMLEFT", 0, -2)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(effect:GetFrameLevel() + 25)
        menu:EnableMouse(true)
        menu:Hide()
        local menuBg = menu:CreateTexture(nil, "BACKGROUND")
        menuBg:SetAllPoints()
        addon.Theme:Paint(menuBg, "field", 1)
        local order = module.vendor.EFFECT_ORDER
        local visible, offset, entries = math.min(7, #order), 1, {}
        menu:SetSize(159, visible * 24 + 4)
        local function refreshEntries()
            for index, entry in ipairs(entries) do
                local key = order[offset + index - 1]
                entry.label:SetText(nameEffect(key))
                entry.label:SetTextColor(1, key == cfg.effect and 0.92 or 0.79, 0.42)
            end
        end
        for index = 1, visible do
            local item = CreateFrame("Button", nil, menu)
            item:SetSize(141, 24)
            item:SetPoint("TOPLEFT", 2, -2 - (index - 1) * 24)
            item.label = CreateLabel(item, "", "GameFontNormal")
            item.label:SetPoint("CENTER")
            local hover = item:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            addon.Theme:Paint(hover, "muted", 0.8)
            item:SetScript("OnClick", function()
                cfg.effect = order[offset + index - 1]
                caption:SetText(nameEffect(cfg.effect))
                menu:Hide()
                updateThumbnail()
                RefreshWorldPreview()
                module:Apply()
            end)
            entries[index] = item
        end
        local scroll = CreateFrame("Slider", nil, menu)
        scroll:SetOrientation("VERTICAL")
        scroll:SetWidth(10)
        scroll:SetPoint("TOPRIGHT", -2, -5)
        scroll:SetPoint("BOTTOMRIGHT", -2, 5)
        scroll:SetMinMaxValues(1, #order - visible + 1)
        scroll:SetValueStep(1)
        scroll:SetObeyStepOnDrag(true)
        local track = scroll:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints()
        track:SetColorTexture(0.20, 0.12, 0.06, 1)
        local thumb = scroll:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(14, 22)
        addon.Theme:StyleScrollThumb(thumb)
        scroll:SetThumbTexture(thumb)
        scroll:SetScript("OnValueChanged", function(_, value)
            offset = math.floor(value + 0.5)
            refreshEntries()
        end)
        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseWheel", function(_, delta)
            scroll:SetValue(offset - delta)
        end)
        panel:HookScript("OnHide", function() menu:Hide() end)
        effect:SetScript("OnClick", function()
            if menu:IsShown() then menu:Hide(); return end
            for index, key in ipairs(order) do
                if key == cfg.effect then scroll:SetValue(math.min(index, #order - visible + 1)); break end
            end
            refreshEntries()
            menu:Show()
        end)
        local color = addon.Theme:CreateButton(panel, "Color", 75, 24)
        color:SetPoint("LEFT", effect, "RIGHT", 8, 0)
        local swatch = color:CreateTexture(nil, "OVERLAY")
        swatch:SetSize(8, 8)
        swatch:SetPoint("RIGHT", -7, 0)
        local function setColor(r, g, b)
            cfg.r, cfg.g, cfg.b = r, g, b
            local example = module.professionSpells[def[1]] and module.professionPreviewColor
            if example then sample:SetTextColor(example.r, example.g, example.b)
            else sample:SetTextColor(r, g, b) end
            swatch:SetColorTexture(r, g, b)
            updateThumbnail()
            RefreshWorldPreview()
        end
        setColor(cfg.r, cfg.g, cfg.b)
        color:SetScript("OnClick", function()
            local picker = ColorPickerFrame
            if not (picker and picker.SetupColorPickerAndShow) then return end
            local r, g, b = cfg.r, cfg.g, cfg.b
            picker:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                swatchFunc = function() setColor(picker:GetColorRGB()) end,
                cancelFunc = function() setColor(r, g, b) end,
            })
        end)
        for index, control in ipairs({
            {"SIZE", "size", 30, 240}, {"INTENSITY (%)", "intensity", 0, 150},
            {"Y OFFSET", "y", -100, 100},
            {"NAME SIZE", "nameSize", 8, 36},
            {"NAME X OFFSET", "nameX", -150, 150},
            {"NAME Y OFFSET", "nameY", -150, 150},
        }) do
            local key = control[2]
            local slider = CreateSlider(panel, control[1], "", control[3], control[4], 1, cfg[key],
                -123 - 36 * (index - 1), function(value)
                    if key == "nameSize" and cfg[key] ~= value then addon.Typography.ModuleChanged("Gathering", "size") end
                    cfg[key] = value
                    RefreshWorldPreview()
                end, true, true)
            if index > 3 then
                local previous = slider
                for _, step in ipairs({1, -1}) do
                    local button = addon.Theme:CreateButton(panel, step > 0 and "+" or "-", 24, 22)
                    button:SetPoint("RIGHT", previous, "LEFT", -4, 0)
                    button:SetScript("OnClick", function() slider:SetValue(slider:GetValue() + step) end)
                    previous = button
                end
            end
        end
        return panel
    end
    local function Select(def)
        if def == fishingDefinition and previewOn then SetPreview(false) end
        previewButton:SetShown(def ~= fishingDefinition)
        fishingView:SetShown(def == fishingDefinition or def == bobberDefinition)
        fishingView:SetText(def == bobberDefinition and "Fishing settings" or "Bobber effect")
        activeCategory = def
        for _, panel in pairs(panels) do panel:Hide() end
        local key = def[1]
        if not panels[key] then panels[key] = BuildPanel(def) end
        panels[key]:Show()
        for id, button in pairs(buttons) do
            local selected = id == key or (def == bobberDefinition and id == "fishing")
            addon.Theme:StyleSettingsTab(button, selected)
        end
        RefreshWorldPreview()
    end
    fishingView:SetScript("OnClick", function()
        Select(activeCategory == bobberDefinition and fishingDefinition or bobberDefinition)
    end)
    local definitions = {}
    for _, def in ipairs(module.categories) do
        if def ~= bobberDefinition then definitions[#definitions + 1] = def end
    end
    definitions[#definitions + 1] = fishingDefinition
    for index, def in ipairs(definitions) do
        local button = CreateFrame("Button", nil, tabs)
        button:SetSize(67, 30)
        button:SetPoint("LEFT", tabs, "LEFT", (index - 1) * 69, 0)
        button.fill = button:CreateTexture(nil, "BACKGROUND")
        button.fill:SetAllPoints()
        local label = CreateLabel(button, def[2], "GameFontNormal")
        label:SetPoint("CENTER")
        label:SetTextColor(1, 0.81, 0.46)
        button:SetScript("OnClick", function() Select(def) end)
        buttons[def[1]] = button
    end
    function page:SelectSubpage(key)
        if key == "bobber" then Select(bobberDefinition); return end
        for _, def in ipairs(definitions) do
            if def[1] == key then Select(def); return end
        end
    end
    Select(module.categories[1])
end

local function CreateQuestPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Quest = page
    local tracker = addon.QuestTracker
    local db = tracker.Settings()
    local header = CreatePanel(page, -8, 76)
    CreateSection(header, "QUEST TRACKER", -14)
    local function set(key, value)
        db[key] = value
        if key == "headerFont" or key == "questFont" then
            addon.Typography.ModuleChanged(key == "headerFont" and "Quest:Header" or "Quest:Objectives", "font")
        elseif key == "headerSize" or key == "questSize" then
            addon.Typography.ModuleChanged(key == "headerSize" and "Quest:Header" or "Quest:Objectives", "size")
        end
        tracker.Refresh()
        if key == "progressThickness" or key == "progressBars" then addon.Map.Refresh() end
    end
    local function checkbox(parent, key, label, x, y)
        local check = addon.Theme:CreateCheckbox(parent)
        check:SetSize(25, 25)
        check:SetPoint("TOPLEFT", x, y)
        check:SetChecked(db[key])
        local caption = CreateLabel(check, label, "GameFontHighlight")
        caption:SetPoint("LEFT", check, "RIGHT", 5, 0)
        check:SetScript("OnClick", function(self) set(key, not not self:GetChecked()) end)
    end
    checkbox(header, "enabled", "Enable Quest Tracker", 16, -41)

    local panel = CreatePanel(page, -103, 330)
    local tabs, sections = {}, {}
    function page:SelectSubpage(selected)
        for name, body in pairs(sections) do
            body:SetShown(name == selected)
            local active = name == selected
            addon.Theme:Paint(tabs[name].fill, active and "purple" or "panel", 1)
        end
    end
    for i, label in ipairs({"Appearance", "Tracking", "Layout", "Fonts", "Timers"}) do
        local tab = CreateFrame("Button", nil, panel)
        tab:SetSize(101, 30)
        tab:SetPoint("TOPLEFT", 18 + (i - 1) * 103, -14)
        tab.fill = tab:CreateTexture(nil, "BACKGROUND")
        tab.fill:SetAllPoints()
        local caption = CreateLabel(tab, label, "GameFontNormal")
        caption:SetPoint("CENTER")
        caption:SetTextColor(1, 0.81, 0.46)
        tab:SetScript("OnClick", function() page:SelectSubpage(label) end)
        local body = CreateFrame("Frame", nil, panel)
        body:SetPoint("TOPLEFT", 0, -55)
        body:SetPoint("BOTTOMRIGHT")
        tabs[label], sections[label] = tab, body
    end

    local function picker(body, key, label, entries, y)
        local text = CreateLabel(body, label, "GameFontNormal")
        text:SetPoint("TOPLEFT", 38, y - 7)
        text:SetTextColor(1, 0.79, 0.42)
        local button = addon.Theme:CreateSettingsDropdown(body)
        button:SetPoint("TOPRIGHT", -38, y)
        button:SetSize(178, 27)
        local face = CreateFrame("Frame", nil, button)
        face:SetAllPoints()
        face:SetFrameLevel(button:GetFrameLevel() + 2)
        face:EnableMouse(false)
        local fill = face:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        addon.Theme:Paint(fill, "field", 1)
        local edge = face:CreateTexture(nil, "BORDER")
        edge:SetPoint("TOPLEFT")
        edge:SetPoint("TOPRIGHT")
        edge:SetHeight(1)
        edge:SetColorTexture(0.75, 0.55, 0.29)
        local arrow = CreateLabel(face, "v", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", -7, 0)
        local caption = CreateLabel(face, "", "GameFontNormal")
        caption:SetPoint("CENTER")
        caption:SetTextColor(1, 0.79, 0.42)
        local function showChoice(entry)
            caption:SetText(entry[2])
            button:SetText(entry[2])
        end
        button:SetupMenu(function(_, root)
            for _, entry in ipairs(entries) do
                root:CreateRadio(entry[2], function() return db[key] == entry[1] end, function()
                    set(key, entry[1])
                    showChoice(entry)
                end)
                if db[key] == entry[1] then showChoice(entry) end
            end
        end)
        for _, entry in ipairs(entries) do
            if db[key] == entry[1] then showChoice(entry); break end
        end
    end

    local function swatch(body, key, label, y, fallback)
        local color = addon.Theme:CreateColorSwatch(body, function()
            return (key == "headerColor" and addon.Headers.Get("quest", "color")) or db[key] or fallback
        end, function(value)
            if key == "headerColor" and addon.Headers.Get("quest", "color") then
                addon.Headers.Set("quest", "color", value)
                tracker.RefreshHeader()
            else
                set(key, value)
            end
        end)
        color:HookScript("OnShow", color.Refresh)
        color:SetPoint("TOPRIGHT", -38, y)
        local text = CreateLabel(body, label, "GameFontNormal")
        text:SetPoint("TOPLEFT", 38, y - 5)
        text:SetTextColor(1, 0.79, 0.42)
    end

    local look = sections.Appearance
    picker(look, "skin", "TRACKER SKIN", {{"Modern", "Modern"}, {"Classic", "Classic"}, {"Minimal", "Minimal"}}, -8)
    CreateSlider(look, "ZONE HEADER SIZE", "", 9, 28, 1, db.zoneSize or 13, -42,
        function(value) set("zoneSize", value) end, true, true)
    swatch(look, "border", "BORDER COLOR (MODERN / CLASSIC)", -73)
    swatch(look, "headerColor", "HEADER COLOR", -104, {0.15, 0.15, 0.19})
    checkbox(look, "matchChatHeader", "Match chat header", 30, -133)
    local function currentHeaderOpacity() return addon.Headers.Get("quest", "opacity") or db.opacity end
    local headerOpacity = CreateSlider(look, "HEADER OPACITY (%)", "Used when Match chat header is off or General sets an override",
        0, 100, 1, currentHeaderOpacity(), -165, function(value)
            if addon.Headers.Get("quest", "opacity") ~= nil then
                addon.Headers.Set("quest", "opacity", value)
                tracker.RefreshHeader()
            else
                set("opacity", value)
            end
        end, true, true)
    look:HookScript("OnShow", function() headerOpacity:DisplayValue(currentHeaderOpacity()) end)
    checkbox(look, "showReadyCount", "Show ready quest count in header", 30, -204)
    checkbox(look, "showReadyXP", "Show ready quest XP in header", 30, -232)
    local backgroundOpacity = CreateSlider(look, "BACKGROUND OPACITY (%)", "", 0, 100, 1,
        db.backgroundOpacity, -262, function(value) set("backgroundOpacity", value) end, true, true)
    look:HookScript("OnShow", function() backgroundOpacity:DisplayValue(db.backgroundOpacity) end)

    local tracking = sections.Tracking
    picker(tracking, "sort", "SORT QUESTS", {{"distance", "Nearest first"}, {"level", "Quest level"},
        {"progress", "Most progress"}, {"log", "Watch order"}}, -8)
    checkbox(tracking, "showLevels", "Show quest levels and difficulty colors", 30, -50)
    checkbox(tracking, "showDistance", "Show distance when available", 30, -80)
    checkbox(tracking, "groupZones", "Group by quest-log zone in Modern", 30, -110)
    checkbox(tracking, "progressBars", "Show objective bars in Modern", 30, -140)
    checkbox(tracking, "readyFirst", "Ready for turn-in first", 30, -167)
    checkbox(tracking, "hideCompleted", "Hide completed quests", 30, -194)
    checkbox(tracking, "showItems", "Show quest item buttons", 30, -221)
    checkbox(tracking, "itemsLeft", "Quest item buttons on the left", 30, -248)
    CreateSlider(tracking, "OBJECTIVE BAR THICKNESS", "", 1, 10, 1,
        db.progressThickness, -280, function(value) set("progressThickness", value) end, true, true)

    local layout = sections.Layout
    checkbox(layout, "growUp", "Grow upwards", 30, -7)
    checkbox(layout, "locked", "Lock tracker position", 30, -36)
    local function steppedSlider(parent, label, key, minimum, maximum, y, inheritSize, read, write)
        local slider = CreateSlider(parent, label, "", minimum, maximum, 1,
            read and read() or db[key] or minimum, y, write or function(value) set(key, value) end, true, true)
        local row = slider:GetParent()
        slider:ClearAllPoints()
        slider:SetPoint("RIGHT", row, "RIGHT", -110, 0)
        slider.valueBox:ClearAllPoints()
        slider.valueBox:SetPoint("RIGHT", row, "RIGHT", -68, 0)
        for i, delta in ipairs({-1, 1}) do
            local button = CreateFrame("Button", nil, row)
            button:SetSize(22, 23)
            button:SetPoint("RIGHT", row, "RIGHT", i == 1 and -40 or -16, 0)
            local glyph = CreateLabel(button, delta == 1 and "+" or "-", "GameFontNormal")
            glyph:SetPoint("CENTER")
            button:SetScript("OnClick", function()
                local value = slider:GetValue()
                if inheritSize and value == 0 then value = addon.db.profile.fontSize or 14 end
                slider:SetValue(math.max(minimum, math.min(maximum, value + delta)))
            end)
        end
        return slider
    end
    steppedSlider(layout, "TRACKER WIDTH", "width", 175, 650, -78)
    steppedSlider(layout, "MAXIMUM QUEST LIST HEIGHT", "maxHeight", 60, 1000, -124)
    local syncingPosition = false
    local xSlider = steppedSlider(layout, "TRACKER X FROM LEFT", nil, -100, math.ceil(UIParent:GetWidth()), -170,
        false, function() return (tracker.GetPosition()) end, function(value)
            if not syncingPosition then tracker.SetPosition("x", value) end
        end)
    local ySlider = steppedSlider(layout, "TRACKER Y FROM BOTTOM", nil, -100, math.ceil(UIParent:GetHeight()), -216,
        false, function() local _, y = tracker.GetPosition(); return y end, function(value)
            if not syncingPosition then tracker.SetPosition("y", value) end
        end)
    tracker.OnPositionChanged = function()
        local x, y = tracker.GetPosition()
        syncingPosition = true
        xSlider:DisplayValue(math.floor(x + 0.5))
        ySlider:DisplayValue(math.floor(y + 0.5))
        syncingPosition = false
    end
    layout:HookScript("OnShow", tracker.OnPositionChanged)
    local fonts = sections.Fonts
    local choices = {{"general", "General (Default)"}, {"FRIZQT", "Friz Quadrata"},
        {"ARIAL", "Arial Narrow"}, {"MORPHEUS", "Morpheus"}}
    picker(fonts, "headerFont", "HEADER FONT", choices, -8)
    steppedSlider(fonts, "HEADER SIZE (0 = GENERAL)", "headerSize", 0, 30, -49, true)
    picker(fonts, "questFont", "QUEST FONT", choices, -98)
    steppedSlider(fonts, "QUEST SIZE (0 = GENERAL)", "questSize", 0, 30, -139, true)
    local timers = sections.Timers
    checkbox(timers, "showTimers", "Show timed quests", 30, -9)
    local previewTimer = addon.Theme:CreateButton(timers, "Preview timer", 130, 26)
    previewTimer:SetPoint("TOPRIGHT", -25, -9)
    previewTimer:SetScript("OnClick", function(self)
        self:SetText(tracker.ToggleTimerPreview() and "Stop preview" or "Preview timer")
    end)
    timers:HookScript("OnHide", function()
        tracker.ToggleTimerPreview(false)
        previewTimer:SetText("Preview timer")
    end)
    steppedSlider(timers, "TIMER WIDTH", "timerWidth", 145, 550, -53)
    steppedSlider(timers, "TIMER BAR HEIGHT", "timerHeight", 16, 48, -99)
    steppedSlider(timers, "TIMER BACKGROUND OPACITY (%)", "timerOpacity", 0, 100, -145)
    local timerHint = CreateLabel(timers, "Drag the timer to save its position.", "GameFontHighlightSmall")
    timerHint:SetPoint("TOPLEFT", 30, -197)
    page:SelectSubpage("Appearance")
end

local function CreateCombatPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Combat = page

    local meter = addon.DamageMeter
    local function buildWindow(index)
        local host = CreateFrame("Frame", nil, page)
        host:SetAllPoints()
        local db = meter.Settings(index)
        local heading = CreatePanel(host, -8, 76)
        CreateSection(heading, "DAMAGE METER", -14)

        local function checkbox(parent, key, label, x, y, settings)
            settings = settings or db
            local check = addon.Theme:CreateCheckbox(parent)
            check:SetSize(25, 25)
            check:SetPoint("TOPLEFT", x, y)
            check:SetChecked(settings[key])
            check:HookScript("OnShow", function(self) self:SetChecked(settings[key]) end)
            local text = CreateLabel(check, label, "GameFontHighlight")
            text:SetPoint("LEFT", check, "RIGHT", 5, 0)
            check:SetScript("OnClick", function(self)
                settings[key] = not not self:GetChecked()
                meter.Refresh()
            end)
        end
        checkbox(heading, "enabled", index == 1 and "Enable Damage Meter" or "Enable second meter", 16, -41)
        local reset = addon.Theme:CreateButton(heading, "Reset meter", 118, 25)
        reset:SetPoint("BOTTOMRIGHT", -18, 12)
        reset:SetScript("OnClick", meter.ConfirmReset)
        local preview = addon.Theme:CreateButton(heading, "Preview meter", 118, 25)
        preview:SetPoint("RIGHT", reset, "LEFT", -8, 0)
        local function refreshPreview()
            preview:SetText(meter.IsPreview(index) and "Stop preview" or "Preview meter")
        end
        preview:SetScript("OnClick", function()
            meter.SetPreview(index, not meter.IsPreview(index))
            refreshPreview()
        end)
        host:HookScript("OnShow", refreshPreview)

        local panel = CreatePanel(page, -103, 325)
        local tabs = {}
        function host:SelectSubpage(selected)
            for name, spec in pairs(tabs) do
                local active = name == selected
                spec.body:SetShown(active)
                addon.Theme:Paint(spec.fill, active and "purple" or "panel", 1)
            end
        end
        for i, name in ipairs({"Appearance", "Layout", "Fonts", "Header", "Reset"}) do
            local tab = CreateFrame("Button", nil, panel)
            tab:SetSize(102, 30)
            tab:SetPoint("TOPLEFT", 18 + (i - 1) * 104, -14)
            local fill = tab:CreateTexture(nil, "BACKGROUND")
            fill:SetAllPoints()
            local text = CreateLabel(tab, name, "GameFontNormal")
            text:SetPoint("CENTER")
            text:SetTextColor(1, 0.81, 0.46)
            tab:SetScript("OnClick", function() host:SelectSubpage(name) end)
            local body = CreateFrame("Frame", nil, panel)
            body:SetPoint("TOPLEFT", 0, -55)
            body:SetPoint("BOTTOMRIGHT")
            tabs[name] = {body = body, fill = fill}
        end

        local function dropdown(parent, label, y, key, entries)
            local text = CreateLabel(parent, label, "GameFontNormal")
            text:SetPoint("TOPLEFT", 38, y - 7)
            text:SetTextColor(1, 0.79, 0.42)
            local button = CreateFrame("Button", nil, parent)
            button:SetSize(178, 27)
            button:SetPoint("TOPRIGHT", -38, y)
            local fill = button:CreateTexture(nil, "BACKGROUND")
            fill:SetAllPoints()
            addon.Theme:Paint(fill, "field", 1)
            local border = button:CreateTexture(nil, "BORDER")
            border:SetPoint("TOPLEFT")
            border:SetPoint("TOPRIGHT")
            border:SetHeight(1)
            border:SetColorTexture(0.75, 0.55, 0.29)
            local arrow = CreateLabel(button, "v", "GameFontHighlightSmall")
            arrow:SetPoint("RIGHT", -7, 0)
            local value = CreateLabel(button, "", "GameFontNormal")
            value:SetPoint("CENTER")
            value:SetTextColor(1, 0.79, 0.42)
            local function update()
                for _, entry in ipairs(entries) do
                    if entry[1] == db[key] then value:SetText(entry[2]); return end
                end
                value:SetText(entries[1][2])
            end
            button:SetScript("OnClick", function(owner)
                MenuUtil.CreateContextMenu(owner, function(_, menu)
                    for _, entry in ipairs(entries) do
                        menu:CreateRadio(entry[2], function() return db[key] == entry[1] end, function()
                            if key == "mode" then meter.SetMode(entry[1], index)
                            else
                                db[key] = entry[1]
                                if key == "font" or key == "headerFont" then
                                    addon.Typography.ModuleChanged(key == "font" and "Combat:Rows" or "Combat:Header", "font")
                                end
                                meter.Refresh()
                            end
                            update()
                        end)
                    end
                end)
            end)
            parent:HookScript("OnShow", update)
            update()
            return update
        end

        local function slider(parent, label, key, minimum, maximum, y, steppers)
            local control = CreateSlider(parent, label, "", minimum, maximum, 1, db[key], y,
                function(value)
                    db[key] = value
                    if key == "fontSize" or key == "headerFontSize" then
                        addon.Typography.ModuleChanged(key == "fontSize" and "Combat:Rows" or "Combat:Header", "size")
                    end
                    meter.Refresh()
                end, true, true)
            if key == "opacity" then
                parent:HookScript("OnShow", function() control:DisplayValue(db[key]) end)
            end
            if not steppers then return end
            local row = control:GetParent()
            control:ClearAllPoints()
            control:SetPoint("RIGHT", row, "RIGHT", -110, 0)
            control.valueBox:ClearAllPoints()
            control.valueBox:SetPoint("RIGHT", row, "RIGHT", -68, 0)
            for i, delta in ipairs({-1, 1}) do
                local button = CreateFrame("Button", nil, row)
                button:SetSize(22, 23)
                button:SetPoint("RIGHT", row, "RIGHT", i == 1 and -40 or -16, 0)
                local text = CreateLabel(button, delta == 1 and "+" or "-", "GameFontNormal")
                text:SetPoint("CENTER")
                button:SetScript("OnClick", function()
                    local current = control:GetValue()
                    if (key == "fontSize" or key == "headerFontSize") and current == 0 then current = addon.db.profile.fontSize or 14 end
                    control:SetValue(math.max(minimum, math.min(maximum, current + delta)))
                end)
            end
        end

        local look = tabs.Appearance.body
        local modes = {}
        local supported = Enum and Enum.DamageMeterType
        for _, entry in ipairs(meter.modes) do
            if supported and supported[entry[1]] ~= nil then modes[#modes + 1] = entry end
        end
        if #modes == 0 then modes = {meter.modes[1]} end
        dropdown(look, "METER TYPE", -7, "mode", modes)
        dropdown(look, "GRADIENT", -48, "gradient", {{"Left", "Left"}, {"Right", "Right"}})
        checkbox(look, "header", "Show header", 30, -86)
        checkbox(look, "showRanks", "Show rank before player names", 30, -114)
        checkbox(look, "hoverSpells", "Show spells on hover", 30, -142)
        slider(look, "BAR AREA BACKGROUND OPACITY (%)", "opacity", 0, 100, -179)
        checkbox(look, "showAmount", "Amount", 30, -225)
        checkbox(look, "showRate", "DPS / HPS", 142, -225)
        checkbox(look, "showPercent", "Percent", 268, -225)

        local layout = tabs.Layout.body
        slider(layout, "VISIBLE ROWS", "rows", 1, 25, -3, true)
        slider(layout, "BAR HEIGHT", "barHeight", 12, 52, -47, true)
        slider(layout, "WINDOW WIDTH", "width", 160, 820, -91, true)
        slider(layout, "X OFFSET FROM CENTER", "x", -math.ceil(UIParent:GetWidth()), math.ceil(UIParent:GetWidth()), -135, true)
        slider(layout, "Y OFFSET FROM CENTER", "y", -math.ceil(UIParent:GetHeight()), math.ceil(UIParent:GetHeight()), -179, true)

        local fonts = tabs.Fonts.body
        dropdown(fonts, "FONT", -7, "font", {{"general", "General (Default)"}, {"FRIZQT", "Friz Quadrata"},
            {"ARIAL", "Arial Narrow"}, {"MORPHEUS", "Morpheus"}})
        slider(fonts, "TEXT SIZE (0 = GENERAL)", "fontSize", 0, 30, -48, true)
        dropdown(fonts, "OUTLINE", -94, "outline", {{"", "None"}, {"OUTLINE", "Outline"},
            {"THICKOUTLINE", "Thick outline"}})
        local updateTextColor = dropdown(fonts, "TEXT COLOR", -135, "textColorMode", {{"class", "Muted class color"},
            {"white", "White"}, {"custom", "Custom color"}})
        local swatch = addon.Theme:CreateColorSwatch(fonts, function() return db.textColor end, function(color)
            db.textColor = color
            db.textColorMode = "custom"
            updateTextColor()
            meter.Refresh()
        end)
        swatch:SetPoint("TOPRIGHT", -38, -177)
        local colorLabel = CreateLabel(fonts, "CUSTOM TEXT COLOR", "GameFontNormal")
        colorLabel:SetPoint("TOPLEFT", 38, -182)
        colorLabel:SetTextColor(1, 0.79, 0.42)

        local headerOptions = tabs.Header.body
        dropdown(headerOptions, "HEADER FONT", -7, "headerFont", {{"general", "General (Default)"},
            {"FRIZQT", "Friz Quadrata"}, {"ARIAL", "Arial Narrow"}, {"MORPHEUS", "Morpheus"}})
        slider(headerOptions, "HEADER SIZE (0 = GENERAL)", "headerFontSize", 0, 30, -48, true)
        dropdown(headerOptions, "HEADER OUTLINE", -94, "headerOutline", {{"", "None"}, {"OUTLINE", "Outline"},
            {"THICKOUTLINE", "Thick outline"}})
        local key = index == 2 and "meter2" or "meter"
        local headerColor = addon.Theme:CreateColorSwatch(headerOptions, function()
            return addon.Headers.Get(key, "text") or db.headerTextColor
        end, function(color)
            if addon.Headers.Get(key, "text") then addon.Headers.Set(key, "text", color)
            else db.headerTextColor = color end
            meter.RefreshHeader()
        end)
        headerColor:HookScript("OnShow", headerColor.Refresh)
        headerColor:SetPoint("TOPRIGHT", -38, -139)
        local headerColorLabel = CreateLabel(headerOptions, "HEADER TEXT COLOR", "GameFontNormal")
        headerColorLabel:SetPoint("TOPLEFT", 38, -144)
        headerColorLabel:SetTextColor(1, 0.79, 0.42)

        local resets = tabs.Reset.body
        checkbox(resets, "resetOnGroup", "Reset when joining a group", 30, -8, meter.Settings())
        checkbox(resets, "resetOnDungeon", "Reset when entering a dungeon", 30, -40, meter.Settings())
        checkbox(resets, "resetOnRaid", "Reset when entering a raid", 30, -72, meter.Settings())
        checkbox(resets, "resetOnPvP", "Reset when entering an arena or battleground", 30, -104, meter.Settings())
        host:SelectSubpage("Appearance")
        return host
    end

    local panels = {}
    local active = 1
    local selectors = {}
    local add
    local function selectWindow(index)
        if not panels[index] then panels[index] = buildWindow(index) end
        active = index
        local hasSecondWindow = meter.HasSecondWindow()
        for id, panel in pairs(panels) do panel:SetShown(id == index) end
        selectors[1]:ClearAllPoints()
        selectors[1]:SetPoint("RIGHT", hasSecondWindow and selectors[2] or add, "LEFT", -10, 0)
        for id, button in ipairs(selectors) do
            button:SetShown(id == 1 or hasSecondWindow)
            addon.Theme:SetButtonActive(button, id == index)
        end
        add:SetShown(not hasSecondWindow)
    end
    for i = 1, 2 do
        local button = addon.Theme:CreateButton(page, "Window " .. i, 90, 24)
        if i == 2 then
            button:SetPoint("TOPRIGHT", page, "TOPRIGHT", -18, -17)
        end
        button:SetScript("OnClick", function() selectWindow(i) end)
        button:SetFrameLevel(page:GetFrameLevel() + 10)
        selectors[i] = button
    end
    add = addon.Theme:CreateButton(page, "Add second meter", 136, 24)
    add:SetPoint("TOPRIGHT", page, "TOPRIGHT", -18, -17)
    add:SetFrameLevel(page:GetFrameLevel() + 10)
    add:SetScript("OnClick", function()
        meter.AddWindow()
        selectWindow(2)
    end)
    function page:SelectSubpage(name)
        panels[active]:SelectSubpage(name)
    end
    selectWindow(1)
    page:HookScript("OnHide", function()
        for index in pairs(panels) do
            if meter.IsPreview(index) then meter.SetPreview(index, false) end
        end
    end)
end

local function CreateVersionHistoryPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages["Version History"] = page

    local panel = CreatePanel(page, -10, 458)
    CreateSection(panel, "VERSION HISTORY", -14)

    local current = CreateLabel(panel, "v" .. (addon.version or "0.2.1"), "GameFontNormalLarge")
    current:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -56)
    current:SetTextColor(1, 0.81, 0.45)
    local currentNotes = CreateLabel(panel,
        "Live module movers with drag locks, and quick keybinding for Bazi action bars.",
        "GameFontHighlightSmall")
    currentNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -83)
    currentNotes:SetTextColor(0.92, 0.79, 0.65)
    local extraNotes = CreateLabel(panel,
        "Contextual Dashboard, Smart Alerts, Journey, Alt Manager and loot upgrades.",
        "GameFontHighlightSmall")
    extraNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -103)
    extraNotes:SetTextColor(0.92, 0.79, 0.65)

    local lastVersion = CreateLabel(panel, "v1.1.3", "GameFontNormalLarge")
    lastVersion:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -142)
    lastVersion:SetTextColor(1, 0.81, 0.45)
    local lastNotes = CreateLabel(panel,
        "Portable quest tracker positions, smoother cast bars, and fixes for auras, bags, fonts and tooltips.",
        "GameFontHighlightSmall")
    lastNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -169)
    lastNotes:SetTextColor(0.92, 0.79, 0.65)
    local lastExtraNotes = CreateLabel(panel,
        "Available quest markers, quest reward values, and automatic cleanup of finished loot rolls.",
        "GameFontHighlightSmall")
    lastExtraNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -189)
    lastExtraNotes:SetTextColor(0.92, 0.79, 0.65)

    local appearance = CreateLabel(panel, "v1.1.2", "GameFontNormalLarge")
    appearance:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -220)
    appearance:SetTextColor(1, 0.81, 0.45)
    local appearanceNotes = CreateLabel(panel,
        "New settings artwork, rounded controls, and matching inventory scrollbars and close buttons.",
        "GameFontHighlightSmall")
    appearanceNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -247)
    appearanceNotes:SetTextColor(0.92, 0.79, 0.65)

    local meterVersion = CreateLabel(panel, "v0.8.1", "GameFontNormalLarge")
    meterVersion:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -279)
    meterVersion:SetTextColor(1, 0.81, 0.45)
    local meterNotes = CreateLabel(panel,
        "Damage and healing meters with automatic fight switching, spell breakdowns and dual windows.",
        "GameFontHighlightSmall")
    meterNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -306)
    meterNotes:SetTextColor(0.92, 0.79, 0.65)

    local previous = CreateLabel(panel, "v0.1.2", "GameFontNormalLarge")
    previous:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -339)
    previous:SetTextColor(1, 0.81, 0.45)
    local previousNotes = CreateLabel(panel,
        "Tooltip development: positioning, appearance and content controls.",
        "GameFontHighlightSmall")
    previousNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -366)
    previousNotes:SetTextColor(0.92, 0.79, 0.65)

    local original = CreateLabel(panel, "v0.1.0", "GameFontNormalLarge")
    original:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -399)
    original:SetTextColor(1, 0.81, 0.45)
    local originalNotes = CreateLabel(panel,
        "Original options menu, settings and module placeholders.",
        "GameFontHighlightSmall")
    originalNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -426)
    originalNotes:SetTextColor(0.92, 0.79, 0.65)
    return page
end

local function CreateNavigationButton(parent, name, label, y, onSelect)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(164, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    local panel = addon.Theme:Surface(button, "ButtonActive", 10)
    local iconIndex = NAV_ICONS[name]
    if name == "Map" then
        local icon = button:CreateTexture(nil, "ARTWORK", nil, 2)
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture(MAP_ICON)
    elseif iconIndex then
        local icon = CreateSettingsIcon(button, iconIndex, 21)
        icon:SetPoint("LEFT", 8, 0)
    end
    local font = onSelect and "GameFontNormalSmall" or "GameFontNormal"
    local labelRegion = CreateLabel(button, label, font)
    labelRegion:SetPoint("LEFT", button, "LEFT", (iconIndex or name == "Map") and 36 or 9, 0)
    labelRegion:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    labelRegion:SetJustifyH("LEFT")
    labelRegion:SetWordWrap(false)
    button.baziRefresh = function()
        local active, hover = button.baziActive, button.baziHover
        panel:SetShown(active or hover)
        if active or hover then addon.Theme:SetSurface(panel, active and "ButtonActive" or "Button", 10) end
        if active then labelRegion:SetTextColor(1, 0.92, 0.80)
        elseif hover then labelRegion:SetTextColor(1, 0.83, 0.60)
        else labelRegion:SetTextColor(0.90, 0.83, 0.75) end
    end
    button:SetScript("OnEnter", function(self) self.baziHover = true; self.baziRefresh() end)
    button:SetScript("OnLeave", function(self) self.baziHover = false; self.baziRefresh() end)
    button:SetScript("OnClick", onSelect or function() ShowPage(name) end)
    button.baziRefresh()
    if not onSelect then navButtons[name] = button end
    return button
end

function addon.Options:Open()
    if not optionsFrame then
        self:Create()
    end

    optionsFrame:Show()
    optionsFrame:Raise()
 end

function addon.Options:OpenModule(page, subpage)
    self:Open()
    ShowPage(page, subpage)
end

function addon.Options:OpenChat()
    self:Open()
    ShowPage("Chat")
end

function addon.Options:OpenBugTab()
    self:Open()
    ShowPage("BugTab")
end

function addon.Options:OpenMovers(selected)
    if addon.Movers.Open(true, selected) and optionsFrame then optionsFrame:Hide() end
end

function addon.Options:CreateDashboardPage()
    local D = addon.Dashboard
    local cfg = D.Settings()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Dashboard = page
    local content, _, scrollBar = addon.Inventory.Scroll(page, 0, 4)
    local tabs, sections = {}, {}
    local function selectTab(name)
        for key, entry in pairs(sections) do
            entry:SetShown(name == key)
            addon.Theme:SetButtonActive(tabs[key], name == key)
        end
        content:SetHeight(sections[name]:GetHeight() + 54)
        scrollBar:SetValue(0)
    end
    function page:SelectSubpage(name) if sections[name] then selectTab(name) end end
    local names = {"General", "Widgets", "Appearance", "Fonts", "Behaviour", "Tracking", "Session", "Alerts"}
    for index, name in ipairs(names) do
        local button = addon.Theme:CreateButton(content, name, 68, 25)
        button:SetPoint("TOPLEFT", 12 + 72 * (index - 1), -8)
        button:SetScript("OnClick", function() selectTab(name) end)
        tabs[name] = button
        sections[name] = CreatePanel(content, -43, 300)
        CreateSection(sections[name], name, -13)
    end
    local help = {
        ["Enable Dashboard"] = "Shows the Dashboard in game. Configure which information it can display under Widgets.",
        ["Grow upward"] = "Keeps the bottom edge in place as cards are added and places the title below the cards.",
        ["Lock position"] = "Prevents dragging the Dashboard header during normal play. Use Movers to reposition it while locked.",
        ["Automatic context detection"] = "Uses recent activity, nearby quest objectives and low supplies to choose when supported widgets appear.",
        ["Enabled"] = "Allows the selected widget to appear when its visibility conditions are met.",
        ["Pin widget"] = "Keeps the widget eligible when idle and sorts it ahead of unpinned widgets. Quests still require a confirmed objective area.",
        ["Hide completed goals"] = "Hides finished entries in widgets that track a target quantity or crafting goal.",
        ["Keep completed quest objectives"] = "Keeps finished objectives visible while you remain in the quest's objective area.",
        ["Show border"] = "Controls the outer Dashboard window border. The cards keep their own outlines.",
        ["Show Dashboard title and close button"] = "Shows the entire window header. Turn this off for a shorter panel with only the widget cards.",
        ["Show widget headers"] = "Shows the name above each widget's rows, such as Professions or Reputation.",
        ["Show this widget's header"] = "Shows the selected card's title when widget headers are enabled under Appearance.",
        ["Automatically hide inactive widgets"] = "Hides widgets that report no relevant activity when their visibility is set to Automatic.",
        ["Hide maxed combat skills"] = "Hides combat skills that have reached their current cap. Pinned or recently changed skills can still appear.",
        ["Fade in when the dashboard opens"] = "Plays a short fade when Dashboard becomes visible.",
        ["Hide XP and loot in Everything"] = "Moves experience, your looted items and looted money out of the main chat while Recent activity is enabled and a Loot tab is open. You can still read those messages in Loot.",
        ["Show clickable quest items"] = "Shows usable quest items beside Local objectives or above Dashboard while you are inside their objective area.",
        ["Show this event in chat"] = "Prints a chat message when this event occurs. It does not replay old notices.",
        ["Enable this reminder"] = "Shows the reminder and allows its action-bar glow, chat message and sound. Right-click a reminder in game to turn it off.",
        ["Show this spell in chat"] = "Prints a message when this reminder appears if chat is enabled for Class buff or weapon reminder above.",
        ["Play sound for this spell"] = "Plays the sound selected for Class buff or weapon reminder above. Choose Silent there to mute all class reminder sounds.",
        ["X POSITION"] = "Sets the horizontal offset from the center of the screen. Positive values move the left edge right.",
        ["Y POSITION"] = "Sets the vertical offset from the center of the screen. Positive values move the anchored edge up.",
        ["MAXIMUM VISIBLE WIDGETS"] = "Caps the number of displayed cards. Pinned widgets appear first, followed by higher priority.",
        ["COMPLETED OBJECTIVE TIME (SECONDS)"] = "Sets how long a newly completed objective stays highlighted in its quest area.",
    }
    local function update() D.Refresh() end
    local function toggle(panel, y, label, read, write)
        local check = addon.Theme:CreateCheckbox(panel)
        check:SetSize(22, 22)
        check:SetPoint("TOPLEFT", 25, y)
        local text = CreateLabel(panel, label, "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 7, 0)
        addon.Theme:SettingsHelp(check, label, help[label], text)
        check:SetChecked(read())
        check:SetScript("OnClick", function(self) write(self:GetChecked() == true); update() end)
        return function() check:SetChecked(read()) end
    end
    local function flag(panel, y, label, key)
        return toggle(panel, y, label, function() return cfg[key] == true end, function(value) cfg[key] = value end)
    end
    local function slider(panel, y, label, key, min, max)
        local row = CreateSlider(panel, label, "", min, max, 1, cfg[key], y, function(value)
            cfg[key] = value; update()
        end, true, true, nil, help[label])
        page:HookScript("OnShow", function() row:DisplayValue(cfg[key]) end)
        return row
    end
    local function dropdown(panel, y, choices, read, write)
        local control = addon.Theme:CreateSettingsDropdown(panel)
        control:SetSize(205, 25)
        control:SetPoint("TOPRIGHT", -24, y)
        local function entries() return type(choices) == "function" and choices() or choices end
        local function sync()
            local value = read()
            for _, entry in ipairs(entries()) do if value == entry[1] then control:SetText(entry[2]); return end end
            control:SetText("Select")
        end
        control:SetupMenu(function(_, root)
            local menu = entries()
            if #menu > 10 and root.SetScrollMode then root:SetScrollMode(250) end
            for _, entry in ipairs(menu) do
                root:CreateRadio(entry[2], function() return read() == entry[1] end, function()
                    write(entry[1])
                    sync()
                end)
            end
        end)
        sync()
        return sync
    end
    local function action(panel, label, x, y, width, callback)
        local button = addon.Theme:CreateButton(panel, label, width, 26)
        button:SetPoint("TOPLEFT", x, y)
        button:SetScript("OnClick", callback)
        return button
    end
    local general = sections.General
    general:SetHeight(491)
    page:HookScript("OnShow", flag(general, -47, "Enable Dashboard", "enabled"))
    flag(general, -72, "Grow upward", "growUp")
    flag(general, -97, "Lock position", "locked")
    flag(general, -122, "Automatic context detection", "context")
    action(general, "Move Dashboard", 25, -149, 150, function()
        if addon.Options.OpenMovers then addon.Options:OpenMovers("Dashboard") end
    end)
    local chosenScenario = "mixed"
    dropdown(general, -149, D.scenarios, function() return chosenScenario end, function(value)
        chosenScenario = value
        if D.IsPreview() then D.Preview(value) end
    end)
    action(general, "Toggle preview", 183, -149, 142, function()
        if D.IsPreview() then D.Preview(nil) else D.Preview(chosenScenario) end
    end)
    for index, item in ipairs({
        {"WIDTH", "width", 145, 550}, {"MAXIMUM HEIGHT", "maxHeight", 90, 700}, {"SCALE (%)", "scale", 50, 175},
        {"X POSITION", "x", -2000, 2000}, {"Y POSITION", "y", -1400, 1400}, {"WIDGET SPACING", "spacing", 0, 24},
        {"MAXIMUM VISIBLE WIDGETS", "maxWidgets", 1, 15},
    }) do slider(general, -186 - (index - 1) * 41, unpack(item)) end

    local widgets = sections.Widgets
    widgets:SetHeight(388)
    local chosen = D.widgets[1].id
    local choices, controls = {}, {}
    for _, widget in ipairs(D.widgets) do choices[#choices + 1] = {widget.id, widget.label} end
    local function selected() return D.WidgetSettings(chosen) end
    local function syncWidget()
        for _, refresh in ipairs(controls) do refresh() end
    end
    dropdown(widgets, -42, choices, function() return chosen end, function(value) chosen = value; syncWidget() end)
    for index, item in ipairs({
        {"Enabled", "enabled"}, {"Pin widget", "pinned"}, {"Hide completed goals", "hideCompleted"},
        {"Keep completed quest objectives", "keepCompleted"},
    }) do
        local key = item[2]
        controls[#controls + 1] = toggle(widgets, -75 - (index - 1) * 25, item[1],
            function() return selected()[key] == true end, function(value) selected()[key] = value end)
    end
    controls[#controls + 1] = toggle(widgets, -175, "Show this widget's header",
        function() return selected().showHeader ~= false end, function(value) selected().showHeader = value end)
    local modeText = CreateLabel(widgets, "Visibility", "GameFontNormal")
    modeText:SetPoint("TOPLEFT", 27, -205)
    controls[#controls + 1] = dropdown(widgets, -199, D.modes, function() return selected().mode end, function(value)
        selected().mode = value; update()
    end)
    for index, item in ipairs({
        {"PRIORITY", "priority", 0, 150}, {"ORDER (TIE BREAK)", "order", 1, #D.widgets},
        {"ACTIVITY DURATION (SECONDS)", "duration", 5, 600}, {"WIDGET BACKGROUND (%)", "background", 0, 100},
    }) do
        local label, key, minimum, maximum = unpack(item)
        local row = CreateSlider(widgets, label, "", minimum, maximum, 1, selected()[key], -231 - (index - 1) * 37,
            function(value) selected()[key] = value; update() end, true, true)
        controls[#controls + 1] = function() row:DisplayValue(selected()[key]) end
    end

    local appearance = sections.Appearance
    appearance:SetHeight(359)
    flag(appearance, -43, "Show border", "border")
    flag(appearance, -68, "Show Dashboard title and close button", "showHeader")
    flag(appearance, -93, "Show widget headers", "headers")
    local accent = addon.Theme:CreateColorSwatch(appearance, function()
        return cfg.accent or {addon.Theme:Accent()}
    end, function(color) cfg.accent = color; D.Render() end)
    accent:SetPoint("TOPLEFT", 27, -122)
    local accentLabel = CreateLabel(appearance, "Dashboard accent", "GameFontNormal")
    accentLabel:SetPoint("LEFT", accent, "RIGHT", 9, 0)
    for index, item in ipairs({
        {"BACKGROUND OPACITY (%)", "opacity", 0, 100}, {"PROGRESS BAR HEIGHT", "barHeight", 1, 12},
        {"ICON SIZE", "iconSize", 8, 32}, {"ROW SPACING", "rowSpacing", 0, 18}, {"BASE TEXT SIZE", "fontSize", 8, 25},
    }) do slider(appearance, -153 - (index - 1) * 39, unpack(item)) end

    local fonts = sections.Fonts
    local typography = addon.Typography
    fonts:SetHeight(404)
    local choices = {{"module", "Default"}}
    for _, choice in ipairs(typography.choices) do choices[#choices + 1] = choice end
    for index, entry in ipairs({{"Window title", "Title"}, {"Widget titles", "Header"},
        {"Row labels", "Body"}, {"Values and counts", "Value"}}) do
        local key, y = "Dashboard:" .. entry[2], -44 - (index - 1) * 87
        local function get(field) return typography.Values(key)[field] end
        local function set(field, value)
            typography.Values(key)[field] = value
            typography.ModuleChanged(key, field, true)
            typography.Refresh("Dashboard")
        end
        local label = CreateLabel(fonts, entry[1], "GameFontNormal")
        label:SetPoint("TOPLEFT", 25, y - 4)
        local sync = dropdown(fonts, y, choices, function() return get("font") or "module" end, function(value)
            set("font", value ~= "module" and value or nil)
        end)
        local size = CreateSlider(fonts, "SIZE (0 = DEFAULT)", "", 0, 40, 1, get("size") or 0, y - 30,
            function(value) set("size", value > 0 and value or nil) end, true, true)
        fonts:HookScript("OnShow", function() sync(); size:DisplayValue(get("size") or 0) end)
    end

    local behaviour = sections.Behaviour
    behaviour:SetHeight(333)
    flag(behaviour, -44, "Automatically hide inactive widgets", "autoHide")
    flag(behaviour, -70, "Hide maxed combat skills", "hideMaxed")
    dropdown(behaviour, -44, {{"always", "Any combat state"}, {"hide", "Hide during combat"}, {"only", "Combat only"}},
        function() return cfg.combat end, function(value) cfg.combat = value; update() end)
    slider(behaviour, -100, "COMPLETED OBJECTIVE TIME (SECONDS)", "completedDuration", 0, 120)
    for index, item in ipairs({{"FREE SLOT WARNING", "slots", 0, 20, 3},
        {"DURABILITY WARNING (%)", "durability", 0, 100, 20}}) do
        local label, key, minimum, maximum, default = unpack(item)
        CreateSlider(behaviour, label, "", minimum, maximum, 1, cfg.thresholds[key] or default, -141 - 39 * (index - 1),
            function(value) cfg.thresholds[key] = value; update() end, true, true)
    end
    flag(behaviour, -228, "Fade in when the dashboard opens", "fade")
    flag(behaviour, -254, "Hide XP and loot in Everything", "hideActivityChat")
    flag(behaviour, -281, "Show clickable quest items", "showQuestItems")
    dropdown(behaviour, -281, {{"left", "Quest items on left"}, {"right", "Quest items on right"}, {"top", "Centered above Dashboard"}},
        function() return cfg.questItemSide end, function(value) cfg.questItemSide = value; update() end)

    local tracking = sections.Tracking
    tracking:SetHeight(284)
    local function input(panel, x, y, width, hint)
        local caption = CreateLabel(panel, hint, "GameFontNormalSmall")
        caption:SetPoint("TOPLEFT", x, y)
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(width, 24)
        box:SetPoint("TOPLEFT", x, y - 18)
        box:SetAutoFocus(false)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        box:SetScript("OnReceiveDrag", function(self)
            local kind, id = GetCursorInfo()
            if kind == "item" and type(id) == "number" then self:SetText(tostring(id)); ClearCursor() end
        end)
        return box
    end
    local id = input(tracking, 25, -51, 245, "Item ID, link or drag from your bags")
    local target = input(tracking, 290, -51, 90, "Quantity")
    target:SetText("1")
    local recipe = input(tracking, 25, -145, 245, "Recipe ID or spell link")
    local amount = input(tracking, 290, -145, 90, "Crafting quantity")
    amount:SetText("1")
    local function announce(ok, message)
        addon:Print(ok and "Dashboard tracking saved." or message or "Enter a valid item and quantity.")
    end
    action(tracking, "Track item", 25, -98, 120, function() announce(D.TrackItem(id:GetText(), target:GetText())) end)
    action(tracking, "Track as supply", 154, -98, 145, function() announce(D.TrackSupply(id:GetText(), target:GetText())) end)
    action(tracking, "Track material", 308, -98, 145, function() announce(D.TrackMaterial(id:GetText())) end)
    action(tracking, "Track recipe", 25, -193, 120, function() announce(D.TrackRecipe(recipe:GetText(), amount:GetText())) end)
    action(tracking, "Track selected recipe", 154, -193, 175, function() announce(D.TrackSelectedRecipe(amount:GetText())) end)
    local pinHint = CreateLabel(tracking, "Right-click a quest objective, profession, skill or faction row to track it.", "GameFontHighlightSmall")
    pinHint:SetPoint("TOPLEFT", 25, -238)

    local session = sections.Session
    session:SetHeight(351)
    flag(session, -46, "Exclude AFK time from rate estimates", "afk")
    flag(session, -71, "Keep counters across reloads and logouts", "persistSession")
    action(session, "Reset session counters", 25, -103, 173, function() D.ResetSession() end)
    CreateSection(session, "Character status rows", -153)
    for index, entry in ipairs({{"gold", "Money"}, {"bags", "Free bag slots"}, {"durability", "Durability"}, {"fps", "FPS"},
        {"latency", "Latency"}, {"zone", "Zone"}, {"coordinates", "Coordinates"}, {"mail", "New mail"}, {"rested", "Rested XP"},
        {"played", "Time played"}}) do
        local key = entry[1]
        local parent = session
        if index > 5 then
            parent = CreateFrame("Frame", nil, session)
            parent:SetPoint("TOPLEFT", 245, 0)
            parent:SetSize(210, 310)
        end
        toggle(parent, -185 - ((index - 1) % 5) * 26, entry[2],
            function() return cfg.status[key] ~= false end, function(value) cfg.status[key] = value end)
    end

    local alerts = sections.Alerts
    alerts:SetHeight(192)
    local smart = addon.SmartAlerts
    local selectedEvent = "upgrade"
    local events = {{"dashboardXP", "Experience gained"}, {"dashboardLoot", "Items looted"},
        {"dashboardMoney", "Money looted"}, {"dashboardCraft", "Items crafted"}}
    for _, rule in ipairs(smart.rules) do events[#events + 1] = {rule[1], rule[2]} end
    local sounds = {{"none", "Silent"}}
    for _, sound in ipairs(smart.SoundChoices()) do sounds[#sounds + 1] = sound end
    local function preference() return D.NotificationSettings(selectedEvent) end
    local function label(text, y)
        CreateLabel(alerts, text, "GameFontNormal"):SetPoint("TOPLEFT", 25, y)
    end
    label("Event", -47)
    label("Notification sound", -86)
    local refreshSound = dropdown(alerts, -80, sounds, function() return preference().sound end, function(key)
        preference().sound = key
        if key ~= "none" then smart.PlaySound(key) end
    end)
    local refreshChat = toggle(alerts, -115, "Show this event in chat",
        function() return preference().chat == true end, function(value) preference().chat = value end)
    dropdown(alerts, -41, events, function() return selectedEvent end, function(key)
        selectedEvent = key
        refreshSound()
        refreshChat()
    end)
    local hint = CreateLabel(alerts, "These settings apply to Dashboard activity and embedded Smart Alerts.", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 25, -156)

    selectTab("General")
end

function addon.Options:CreateBuffRemindersPage()
    local D, smart = addon.Dashboard, addon.SmartAlerts
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages["Buff Reminders"] = page
    local content = addon.Inventory.Scroll(page, 0, 4)
    content:SetHeight(392)
    local alerts = CreatePanel(content, -8, 372)
    CreateSection(alerts, "Buff Reminders", -13)
    local help = {
        ["Enable Dashboard"] = "Shows the Dashboard in game. Configure which information it can display under Widgets.",
        ["Grow upward"] = "Keeps the bottom edge in place as cards are added and places the title below the cards.",
        ["Lock position"] = "Prevents dragging the Dashboard header during normal play. Use Movers to reposition it while locked.",
        ["Automatic context detection"] = "Uses recent activity, nearby quest objectives and low supplies to choose when supported widgets appear.",
        ["Enabled"] = "Allows the selected widget to appear when its visibility conditions are met.",
        ["Pin widget"] = "Keeps the widget eligible when idle and sorts it ahead of unpinned widgets. Quests still require a confirmed objective area.",
        ["Hide completed goals"] = "Hides finished entries in widgets that track a target quantity or crafting goal.",
        ["Keep completed quest objectives"] = "Keeps finished objectives visible while you remain in the quest's objective area.",
        ["Show border"] = "Controls the outer Dashboard window border. The cards keep their own outlines.",
        ["Show Dashboard title and close button"] = "Shows the entire window header. Turn this off for a shorter panel with only the widget cards.",
        ["Show widget headers"] = "Shows the name above each widget's rows, such as Professions or Reputation.",
        ["Show this widget's header"] = "Shows the selected card's title when widget headers are enabled under Appearance.",
        ["Automatically hide inactive widgets"] = "Hides widgets that report no relevant activity when their visibility is set to Automatic.",
        ["Hide maxed combat skills"] = "Hides combat skills that have reached their current cap. Pinned or recently changed skills can still appear.",
        ["Fade in when the dashboard opens"] = "Plays a short fade when Dashboard becomes visible.",
        ["Hide XP and loot in Everything"] = "Moves experience, your looted items and looted money out of the main chat while Recent activity is enabled and a Loot tab is open. You can still read those messages in Loot.",
        ["Show clickable quest items"] = "Shows usable quest items beside Local objectives or above Dashboard while you are inside their objective area.",
        ["Show this event in chat"] = "Prints a chat message when this event occurs. It does not replay old notices.",
        ["Enable this reminder"] = "Shows the reminder and allows its action-bar glow, chat message and sound. Right-click a reminder in game to turn it off.",
        ["Show this spell in chat"] = "Prints a message when this reminder appears if chat is enabled for the notification settings above.",
        ["Play sound for this spell"] = "Plays the sound selected for Class buff or weapon reminder above. Choose Silent there to mute all class reminder sounds.",
        ["X POSITION"] = "Sets the horizontal offset from the center of the screen. Positive values move the left edge right.",
        ["Y POSITION"] = "Sets the vertical offset from the center of the screen. Positive values move the anchored edge up.",
        ["MAXIMUM VISIBLE WIDGETS"] = "Caps the number of displayed cards. Pinned widgets appear first, followed by higher priority.",
        ["COMPLETED OBJECTIVE TIME (SECONDS)"] = "Sets how long a newly completed objective stays highlighted in its quest area.",
    }
    local function update() D.Refresh() end
    local function toggle(panel, y, label, read, write)
        local check = addon.Theme:CreateCheckbox(panel)
        check:SetSize(22, 22)
        check:SetPoint("TOPLEFT", 25, y)
        local text = CreateLabel(panel, label, "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 7, 0)
        addon.Theme:SettingsHelp(check, label, help[label], text)
        check:SetChecked(read())
        check:SetScript("OnClick", function(self) write(self:GetChecked() == true); update() end)
        return function() check:SetChecked(read()) end
    end
    local function dropdown(panel, y, choices, read, write)
        local control = addon.Theme:CreateSettingsDropdown(panel)
        control:SetSize(205, 25)
        control:SetPoint("TOPRIGHT", -24, y)
        local function entries() return type(choices) == "function" and choices() or choices end
        local function sync()
            local value = read()
            for _, entry in ipairs(entries()) do if value == entry[1] then control:SetText(entry[2]); return end end
            control:SetText("Select")
        end
        control:SetupMenu(function(_, root)
            local menu = entries()
            if #menu > 10 and root.SetScrollMode then root:SetScrollMode(250) end
            for _, entry in ipairs(menu) do
                root:CreateRadio(entry[2], function() return read() == entry[1] end, function()
                    write(entry[1])
                    sync()
                end)
            end
        end)
        sync()
        return sync
    end

    local function label(text, y)
        CreateLabel(alerts, text, "GameFontNormal"):SetPoint("TOPLEFT", 25, y)
    end
    local function preference() return D.NotificationSettings("classBuffReminder") end
    local sounds = {{"none", "Silent"}}
    for _, sound in ipairs(smart.SoundChoices()) do sounds[#sounds + 1] = sound end
    label("Default class sound", -47)
    dropdown(alerts, -41, sounds, function() return smart.ClassBuffSound() end, function(key)
        smart.SetClassBuffSound(key)
        if key ~= "none" then smart.PlaySound(key) end
    end)
    toggle(alerts, -78, "Show this event in chat", function() return preference().chat == true end,
        function(value) preference().chat = value end)
    CreateSection(alerts, "Class Buff and Weapon Reminders", -115)
    label("Category", -157)
    label("Spell or effect", -193)
    local category = "all"
    local categories = {{"all", "All reminders"}, {"class", "Class Buffs"}, {"weapon", "Weapon Imbues & Poisons"},
        {"temporary", "Temporary Weapon Enhancements"}, {"gathering", "Gathering & Fishing Enhancements"}}
    local function filteredChoices()
        return smart.BuffReminderChoices(category)
    end
    local selectedBuff, buffLabel
    local function currentBuff()
        local choices = filteredChoices()
        for _, entry in ipairs(choices) do if entry[1] == selectedBuff then return selectedBuff end end
        selectedBuff, buffLabel = nil, nil
        if choices[1] then selectedBuff, buffLabel = choices[1][1], choices[1][2] end
        return selectedBuff
    end
    local function buffToggle(y, title, field)
        return toggle(alerts, y, title, function() local key = currentBuff(); return key ~= nil and smart.BuffReminderOption(key, field) end,
            function(value) smart.SetBuffReminderOption(currentBuff(), field, value, buffLabel) end)
    end
    local syncEnabled = buffToggle(-222, "Enable this reminder", "enabled")
    local syncChat = buffToggle(-249, "Show this spell in chat", "chat")
    local syncCombat = buffToggle(-276, "Combat only", "combatOnly")
    local individualSounds = {{"default", "Class default"}, {"none", "Disabled"}}
    for _, sound in ipairs(smart.SoundChoices()) do individualSounds[#individualSounds + 1] = sound end
    label("Reminder sound", -309)
    local syncSound = dropdown(alerts, -303, individualSounds, function()
        return smart.BuffReminderSound(currentBuff())
    end, function(key)
        if not currentBuff() then return end
        smart.SetBuffReminderSound(currentBuff(), key, buffLabel)
        local preview = key == "default" and smart.ClassBuffSound() or key
        if preview and preview ~= "none" then smart.PlaySound(preview) end
    end)
    local syncBuff = dropdown(alerts, -186, filteredChoices, currentBuff, function(key)
        selectedBuff, buffLabel = key, nil
        for _, entry in ipairs(filteredChoices()) do if entry[1] == key then buffLabel = entry[2]; break end end
        syncEnabled(); syncChat(); syncCombat(); syncSound()
    end)
    local function syncBuffOptions()
        syncBuff(); syncEnabled(); syncChat(); syncCombat(); syncSound()
    end
    dropdown(alerts, -150, categories, function() return category end, function(key)
        category, selectedBuff, buffLabel = key, nil, nil
        syncBuffOptions()
    end)
    alerts:HookScript("OnShow", syncBuffOptions)
    addon.Adventure.On("buffReminderSettings", function() if alerts:IsVisible() then syncBuffOptions() end end)
end

function addon.Options:Create()
    local db = addon.db and addon.db.profile
    if not db then
        print("Bazi UI: Settings database is not initialized.")
        return
    end
    optionsFrame = CreateFrame("Frame", "BaziUIOptionsFrame", UIParent)
    optionsFrame.baziSettingsHelpRoot = true
    if UISpecialFrames then table.insert(UISpecialFrames, optionsFrame:GetName()) end
    local border = CreateFrame("Frame", nil, optionsFrame)
    border:SetAllPoints()
    border:EnableMouse(false)
    border:SetFrameLevel(optionsFrame:GetFrameLevel() + 4)
    addon.Theme:Surface(border, "WindowRim", 33, "OVERLAY")

    -- Always open at the default dimensions, regardless of the last resize.
    optionsFrame:SetSize(900, 555)
    optionsFrame:SetResizable(true)
    -- WoW Forever may expose SetResizeBounds instead of the legacy
    -- SetMinResize / SetMaxResize methods. Never call an absent API.
    if optionsFrame.SetResizeBounds then
        optionsFrame:SetResizeBounds(760, 350, 1500, 1000)
    else
        if optionsFrame.SetMinResize then
            optionsFrame:SetMinResize(760, 350)
        end
        if optionsFrame.SetMaxResize then
            optionsFrame:SetMaxResize(1500, 1000)
        end
    end
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)

    local function ResizeGrip(anchor)
        local grip = CreateFrame("Button", nil, optionsFrame)
        grip:SetSize(35, 35)
        grip:SetPoint(anchor, optionsFrame, anchor, 0, 0)
        grip:SetFrameLevel(optionsFrame:GetFrameLevel() + 35)
        grip:EnableMouse(true)
        for i = 0, 0 do
            local stroke = grip:CreateTexture(nil, "OVERLAY")
            stroke:SetColorTexture(0.90, 0.69, 0.38, 0.95)
            stroke:SetSize(13 - i * 4, 1.5)
            local offset = 10 + i * 5
            stroke:SetPoint("CENTER", grip, "BOTTOMLEFT",
                anchor == "BOTTOMLEFT" and offset or (35 - offset), offset)
            if stroke.SetRotation then
                stroke:SetRotation(anchor == "BOTTOMLEFT" and -math.pi / 4 or math.pi / 4)
            end
        end
        grip:RegisterForDrag("LeftButton")
        grip:SetScript("OnDragStart", function()
            if not InCombatLockdown or not InCombatLockdown() then
                optionsFrame:StartSizing(anchor)
            end
        end)
        grip:SetScript("OnDragStop", function()
            optionsFrame:StopMovingOrSizing()
            -- Resize applies only to the current opening of the window.
        end)
        return grip
    end
    ResizeGrip("BOTTOMLEFT")
    ResizeGrip("BOTTOMRIGHT")
    -- Ease into 75% opacity during movement; restore instantly on stopping.
    local displayedAlpha = 1
    local fadeSeconds = 0.65
    optionsFrame:SetScript("OnShow", function(self)
        self:SetSize(900, 555)
        -- Saved scale must be reapplied after /reload and on every open.
        local profile = addon.db and addon.db.profile
        local savedScale = profile and tonumber(profile.uiScale) or 1
        self:SetScale(math.max(0.70, math.min(1.50, savedScale)))
        displayedAlpha = 1
        self:SetAlpha(1)
    end)
    optionsFrame:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        if addon.Dashboard.IsPreview() then addon.Dashboard.Preview(nil) end
        if not InCombatLockdown or not InCombatLockdown() then
            self:SetSize(900, 555)
        end
    end)
    optionsFrame:SetScript("OnUpdate", function(self, elapsed)
        local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
        if type(speed) == "number" and (not issecretvalue or not issecretvalue(speed))
            and (not canaccessvalue or canaccessvalue(speed)) and speed > 0 then
            displayedAlpha = math.max(0.75, displayedAlpha - elapsed * (0.25 / fadeSeconds))
        else
            displayedAlpha = 1
        end
        if self:GetAlpha() ~= displayedAlpha then
            self:SetAlpha(displayedAlpha)
        end
    end)
    local backdrop = addon.Theme:Surface(optionsFrame, "Base", 19, "BACKGROUND", 1)
    addon.Backgrounds.Track("settings", backdrop)
    local header = optionsFrame:CreateTexture(nil, "BACKGROUND", nil, 2)
    header:SetPoint("TOPLEFT", 8, -7)
    header:SetPoint("TOPRIGHT", -8, -7)
    header:SetHeight(52)
    local headerArt = optionsFrame:CreateTexture(nil, "BACKGROUND", nil, 3)
    headerArt:SetAllPoints(header)
    addon.Theme:SetSurface(headerArt, "Card", 15)

    local line = optionsFrame:CreateTexture(nil, "BACKGROUND", nil, 4)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
    line:SetHeight(1)
    addon.Theme:Paint(line, "gold", 0.48)

    local brandLayer = CreateFrame("Frame", nil, optionsFrame)
    brandLayer:SetAllPoints()
    brandLayer:SetFrameLevel(border:GetFrameLevel() + 1)
    brandLayer:EnableMouse(false)
    local emblem = brandLayer:CreateTexture(nil, "OVERLAY")
    emblem:SetSize(91, 91)
    emblem:SetPoint("LEFT", header, "LEFT", -5, 0)
    emblem:SetTexture(ASSET .. "Icons\\BaziUI_Emblem_256.png")
    optionsFrame.baziEmblem = emblem

    local title = CreateLabel(optionsFrame, "Bazi UI", "GameFontNormalHuge")
    title:SetPoint("LEFT", emblem, "RIGHT", 4, 0)
    local function styleSettingsHeader()
        local headers, colors = addon.Headers, addon.Theme.colors
        local r, g, b = unpack(colors.window)
        header:SetColorTexture(headers.Fill("settings", r, g, b, 1))
        headerArt:SetShown(not addon.Theme:UsesAccentStyle() and headers.Get("settings", "color") == nil
            and headers.Get("settings", "opacity") == nil)
        title:SetTextColor(headers.Text("settings", unpack(colors.headerText)))
    end
    addon.Headers.RegisterRefresh("settings", styleSettingsHeader)
    styleSettingsHeader()
    local version = CreateLabel(optionsFrame, "v" .. (addon.version or "0.1.1"), "GameFontHighlightSmall")
    version:SetPoint("LEFT", title, "RIGHT", 7, 0)
    version:SetTextColor(0.71, 0.65, 0.69)

    local close = addon.Theme:CreateButton(optionsFrame, "X", 29, 29)
    close:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    close:SetFrameLevel(optionsFrame:GetFrameLevel() + 20)
    close:SetScript("OnClick", function() optionsFrame:Hide() end)
    optionsFrame.baziClose = close
    local previous
    for _, tab in ipairs({{"General", "Settings", 79}, {"Movers", "Movers", 79}, {"Export", "Export", 76}, {"Version History", "What's New", 91}}) do
        local pageName, caption, width = unpack(tab)
        local button = addon.Theme:CreateButton(optionsFrame, caption, width, 29)
        if previous then button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        else button:SetPoint("LEFT", header, "LEFT", 199, 0) end
        button:SetScript("OnClick", function()
            if pageName == "Movers" then self:OpenMovers()
            elseif pageName == "Export" then ShowPage("Profiles", "Export") else ShowPage(pageName) end
        end)
        headerButtons[pageName] = button
        previous = button
    end
    optionsFrame:Hide()

    local nav = CreateFrame("Frame", nil, optionsFrame)
    nav:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -60)
    local navBackground = addon.Theme:Surface(nav, "Sidebar", 16)
    navBackground:ClearAllPoints()
    navBackground:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 8, -62)
    navBackground:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMLEFT", 194, 10)
    nav:SetWidth(180)
    nav:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 12, 22)

    local search = CreateFrame("EditBox", nil, optionsFrame)
    search:SetPoint("RIGHT", close, "LEFT", -12, 0)
    search:SetSize(184, 27)
    optionsFrame:HookScript("OnSizeChanged", function(_, width)
        search:SetWidth(math.min(184, math.max(142, width - 612)))
    end)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetTextInsets(27, 9, 0, 0)
    search:SetTextColor(0.96, 0.85, 0.66, 1)
    search:SetMaxLetters(50)
    addon.Theme:Surface(search, "Field", 10)
    -- Hint must be a child of the EditBox: the previous sibling was hidden
    -- behind the edit box background, making the field appear empty.
    local searchIcon = search:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(15, 15)
    searchIcon:SetPoint("LEFT", search, "LEFT", 7, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(0.88, 0.73, 0.49, 0.9)
    local searchHint = CreateLabel(search, "Search settings...", "GameFontHighlightSmall")
    searchHint:SetPoint("LEFT", search, "LEFT", 27, 0)
    searchHint:SetTextColor(0.83, 0.72, 0.57, 0.9)
    local searchEmpty = CreateLabel(nav, "No matching settings", "GameFontHighlightSmall")
    searchEmpty:SetPoint("TOPLEFT", nav, "TOPLEFT", 14, -14)
    searchEmpty:SetTextColor(0.77, 0.65, 0.51)
    searchEmpty:Hide()
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    contentFrame = CreateFrame("Frame", nil, optionsFrame)
    contentFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 200, -60)
    contentFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 39)
    addon.Theme:AddSettingsDropShadow(optionsFrame)
    shadowToggle = addon.Theme:CreateCheckbox(optionsFrame)
    shadowToggle:SetSize(16, 16)
    shadowToggle:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -24, 12)
    local shadowLabel = CreateLabel(shadowToggle, "Drop shadow", "GameFontHighlightSmall")
    shadowLabel:SetPoint("RIGHT", shadowToggle, "LEFT", -4, 0)
    shadowToggle:SetScript("OnClick", function(self)
        addon.Theme:SetDropShadowEnabled(self.key, not not self:GetChecked())
    end)

    local separator = contentFrame:CreateTexture(nil, "BORDER")
    separator:SetColorTexture(0.72, 0.49, 0.25, 0.52)
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 190, -56)
    separator:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 190, 10)

    local footerLine = optionsFrame:CreateTexture(nil, "ARTWORK")
    footerLine:SetTexture(ASSET .. "Branding\\BaziUI_Underline.png")
    footerLine:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 211, 25)
    footerLine:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -27, 25)
    footerLine:SetHeight(16)
    local saveNote = CreateLabel(optionsFrame, "Changes are saved automatically.", "GameFontHighlightSmall")
    saveNote:SetPoint("BOTTOMLEFT", 232, 14)
    saveNote:SetTextColor(0.91, 0.76, 0.59)
    local noteIcon = CreateSettingsIcon(optionsFrame, 15, 14)
    noteIcon:SetPoint("RIGHT", saveNote, "LEFT", -6, 0)

    -- Scrollable categories, with a fixed footer and search box.
    local scrollFrame = CreateFrame("ScrollFrame", nil, nav)
    scrollFrame:SetPoint("TOPLEFT", nav, "TOPLEFT", 14, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -2, 53)
    scrollFrame:EnableMouseWheel(true)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(164, 377)
    scrollFrame:SetScrollChild(scrollChild)
    local scrollBar = CreateFrame("Slider", nil, nav)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetWidth(10)
    scrollBar:SetPoint("TOPLEFT", nav, "TOPLEFT", 2, -8)
    scrollBar:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 2, 53)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(15)
    local barTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
    barTrack:SetAllPoints(scrollBar)
    barTrack:SetColorTexture(0.20, 0.12, 0.11, 0.27)
    local barThumb = scrollBar:CreateTexture(nil, "OVERLAY")
    barThumb:SetSize(14, 38)
    addon.Theme:StyleScrollThumb(barThumb)
    scrollBar:SetThumbTexture(barThumb)
    local function RefreshScroll()
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollBar:SetShown(maxScroll > 0)
        if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
        scrollFrame:SetVerticalScroll(scrollBar:GetValue())
    end
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollBar:EnableMouse(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        scrollBar:SetValue(math.max(0, scrollBar:GetValue() - delta * 38))
    end)
    scrollFrame:SetScript("OnSizeChanged", RefreshScroll)

    local navigationGroups = {
        {"General", {"General", "Profiles", "Quality of Life", "UnitFrames", "Nameplates"}},
        {"Gameplay", {"ActionBars", "Chat", "Quest", "Dialogue", "Gathering", "HUD", "Inventory"}},
        {"Interface", {"Map", "Minimap", "Tooltip", "Combat", "BugTab"}},
    }
    navigationGroups[#navigationGroups + 1] = {"Progression", {"Dashboard", "Smart Alerts", "Buff Reminders", "Journey", "Alt Manager"}}
    for _, group in ipairs(navigationGroups) do
        group.heading = CreateLabel(scrollChild, group[1]:upper(), "GameFontNormalSmall")
        group.heading:SetTextColor(unpack(addon.Theme.colors.headerText))
        group.rule = scrollChild:CreateTexture(nil, "ARTWORK")
        group.rule:SetPoint("LEFT", group.heading, "RIGHT", 9, 0)
        group.rule:SetSize(math.max(1, 135 - group.heading:GetStringWidth()), 1)
        addon.Theme:Paint(group.rule, "gold", 0.40)
        for _, name in ipairs(group[2]) do
            CreateNavigationButton(scrollChild, name, name, 0)
        end
    end

    local historyButton = CreateFrame("Button", nil, nav)
    historyButton:SetSize(170, 18)
    historyButton:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 4, 27)
    local historyLabel = CreateLabel(historyButton, "Version History", "GameFontHighlightSmall")
    historyLabel:SetPoint("LEFT", historyButton, "LEFT", 8, 0)
    historyLabel:SetTextColor(0.62, 0.58, 0.53)
    local footerVersion = CreateLabel(historyButton, "v" .. addon.version, "GameFontHighlightSmall")
    footerVersion:SetPoint("RIGHT", historyButton, "RIGHT", -7, 0)
    footerVersion:SetTextColor(0.91, 0.76, 0.59)
    historyButton:SetScript("OnClick", function() ShowPage("Version History") end)
    historyButton:SetScript("OnEnter", function() historyLabel:SetTextColor(0.92, 0.80, 0.60) end)
    historyButton:SetScript("OnLeave", function() historyLabel:SetTextColor(0.62, 0.58, 0.53) end)
    local helpLabel = CreateLabel(nav, "Type /bazi help for commands", "GameFontHighlightSmall")
    helpLabel:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 12, 8)
    helpLabel:SetTextColor(0.64, 0.59, 0.53)

    local searchResults = {}
    local function index(pageName, label, subpage, keywords)
        local path = pageName .. " → " .. label
        searchResults[#searchResults + 1] = {
            path = path, haystack = (path .. " " .. (keywords or "")):lower(),
            open = function() ShowPage(pageName, subpage or label) end,
        }
    end
    index("General", "Fonts", "Fonts", "typeface font family size outline shadow")
    index("General", "Backgrounds", "Backgrounds", "window opacity transparency")
    index("General", "Headers", "Headers", "header title opacity color text")
    index("General", "Guides and activity", "Fonts", "today session exit statistics first-use guides tutorial tooltips")
    index("Profiles", "Character profiles", nil, "create copy switch default new character save settings")
    index("Dashboard", "Smart widgets", nil, "quest professions gathering skills crafting supplies reputation dungeon raid pvp")
    index("Buff Reminders", "Class buff reminders", nil, "lightning shield weapon imbue poison mute chat sound spell")
    index("Smart Alerts", "Smart Alerts", nil, "notifications thresholds durability ammo history")
    index("Journey", "Journey", nil, "journal timeline sessions milestones records")
    index("Alt Manager", "Alt Manager", nil, "account inventory bank gold professions")
    index("ActionBars", "Experience", "experience", "exp xp rested quest reputation status bar opacity transparency")
    for _, bar in ipairs(addon.ActionBars.bars) do index("ActionBars", bar.title, bar.key) end
    for _, name in ipairs({"Player", "Target", "Focus", "Pet", "Target of Target", "Boss", "Party", "Raid"}) do
        index("UnitFrames", name)
    end
    for _, name in ipairs({"Friendly", "Friendly Pet", "NPC", "Enemy"}) do index("Nameplates", name) end
    for _, name in ipairs({"Map Info", "Buttons", "Visibility", "Fonts"}) do index("Minimap", name) end
    index("Minimap", "Mail icon position", "Buttons", "envelope letter offset coordinates")
    index("Minimap", "Mail icon visibility", "Visibility", "show hide envelope letter")
    for _, name in ipairs({"Contents", "Fonts"}) do index("Tooltip", name) end
    for _, name in ipairs({"Resize Options", "Sounds", "Automation"}) do index("Quality of Life", name) end
    for _, def in ipairs(addon.Gathering.categories) do index("Gathering", def[2], def[1]) end
    index("Combat", "Appearance", "damage meter", "combat dps hps healing reset damage gradient")
    index("Combat", "Layout", "layout", "damage meter rows height width position coordinates")
    index("Combat", "Fonts", "fonts", "damage meter font size outline text color")
    index("Combat", "Header", "header", "damage meter title font size color outline")
    index("Combat", "Reset", "reset", "damage meter group dungeon raid arena battleground")
    index("Quest", "Appearance", "appearance", "quest tracker skin modern classic minimal opacity accent border")
    index("Quest", "Tracking", "tracking", "quest level distance progress sort zone objectives")
    index("Quest", "Layout", "layout", "quest size width height position grow upwards")
    index("Quest", "Fonts", "fonts", "quest font header size typography general")
    index("Quest", "Timers", "Timers", "timed quest countdown preview move opacity")
    for _, entry in ipairs(hudOptions) do
        index("HUD", entry[2], entry[1], "position size coordinates preview")
    end
    index("Dialogue", "NPC and quest dialogs", nil, "gossip forever tint background opacity")
    index("Chat", "Appearance", "appearance", "theme border background opacity fade")
    index("Chat", "Fonts", "fonts", "timestamps separator spacing")
    index("Chat", "Channels", "channels", "ads badges class icons player names")
    index("Chat", "Alerts", "alerts", "audio sound whispers mentions")
    index("Chat", "Layout", "layout", "position edit box coordinates history")
    index("Gathering", "Fishing", "fishing", "bobber cast reel autoloot")
    index("Inventory", "Bags", "bags", "backpack bank guild sorting search categories")
    index("Inventory", "Categories", "categories", "add create bag categories")
    index("Inventory", "Cleanup", "cleanup", "delete cheapest item protected ignore")
    index("Inventory", "Loot", "loot", "items loot window background opacity transparency")
    index("Inventory", "Rolls", "rolls", "loot need greed pass history")

    local function matches(haystack, query)
        for word in query:gmatch("%S+") do
            if not haystack:find(word, 1, true) then return false end
        end
        return true
    end

    local firstMatch
    local function UpdateSearch()
        local query = (search:GetText() or ""):lower():match("^%s*(.-)%s*$")
        local shown, height = 0, 0
        firstMatch = nil
        searchHint:SetShown(query == "" and not search:HasFocus())
        local function place(button)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -height)
            button:Show()
            shown = shown + 1
            height = height + 27
            firstMatch = firstMatch or button
        end
        for _, group in ipairs(navigationGroups) do
            group.heading:SetShown(query == "")
            group.rule:SetShown(query == "")
            if query == "" then
                group.heading:ClearAllPoints()
                group.heading:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -height - 5)
                height = height + 25
            end
            for _, name in ipairs(group[2]) do
                local button = navButtons[name]
                if matches(name:lower(), query) then place(button)
                else button:Hide() end
            end
        end
        for _, result in ipairs(searchResults) do
            if query ~= "" and matches(result.haystack, query) then
                if not result.button then
                    result.button = CreateNavigationButton(scrollChild, nil, result.path, 0, function()
                        search:ClearFocus()
                        result.open()
                    end)
                end
                place(result.button)
            elseif result.button then
                result.button:Hide()
            end
        end
        scrollChild:SetHeight(math.max(1, height))
        scrollBar:SetValue(0)
        RefreshScroll()
        searchEmpty:SetShown(shown == 0)
        historyButton:SetShown(query == "")
        helpLabel:SetShown(query == "")
    end
    search:SetScript("OnEnterPressed", function(self)
        if firstMatch and (self:GetText() or ""):find("%S") then firstMatch:Click() end
        self:ClearFocus()
    end)
    search:SetScript("OnTextChanged", UpdateSearch)
    search:SetScript("OnEditFocusGained", UpdateSearch)
    search:SetScript("OnEditFocusLost", UpdateSearch)
    UpdateSearch()

    -- Only General is built for the initial /bazi open. All other pages are
    -- created on first selection, then retained for the rest of the session.
    pageFactories.General = CreateGeneralPage
    pageFactories["Version History"] = CreateVersionHistoryPage
    pageFactories["Quality of Life"] = CreateQoLPage
    pageFactories.Profiles = CreateProfilesPage
    pageFactories.UnitFrames = CreateUnitFramesPage
    pageFactories.Nameplates = function()
        if addon.NameplatesOptions and addon.NameplatesOptions.CreatePage then
            pages.Nameplates = addon.NameplatesOptions:CreatePage(contentFrame)
        else
            CreatePlaceholderPage("Nameplates")
        end
    end
    pageFactories.ActionBars = function()
        pages.ActionBars = addon.ActionBarsOptions:CreatePage(contentFrame, CreateSlider)
    end
    pageFactories.Chat = function()
        pages.Chat = addon.Chat.CreatePage(contentFrame, CreateSlider, function(frame)
            local art = CreatePanel(frame, 0, 1)
            art:ClearAllPoints()
            art:SetAllPoints(frame)
            art:SetFrameLevel(frame:GetFrameLevel())
        end)
    end
    pageFactories.Quest = CreateQuestPage
    pageFactories.HUD = CreateHUDPage
    pageFactories.Dialogue = CreateDialoguePage
    pageFactories.Gathering = CreateGatheringPage
    pageFactories.Minimap = CreateMinimapPage
    pageFactories.Map = CreateMapPage
    pageFactories.Tooltip = CreateTooltipPage
    pageFactories.Combat = CreateCombatPage
    pageFactories.BugTab = CreateBugTabPage
    pageFactories.Inventory = CreateInventoryPage
    pageFactories.Dashboard = function() self:CreateDashboardPage() end
    pageFactories["Buff Reminders"] = function() self:CreateBuffRemindersPage() end
    for title, kind in pairs({["Smart Alerts"] = "alerts", Journey = "journey", ["Alt Manager"] = "alts"}) do
        local name, module = title, kind
        pageFactories[name] = function()
            local page = CreateFrame("Frame", nil, contentFrame)
            page:SetAllPoints(contentFrame)
            pages[name] = page
            addon.AdventureUI.Settings(module, page, {panel = CreatePanel, section = CreateSection, label = CreateLabel, slider = CreateSlider})
        end
    end

    ShowPage("General")
end

function addon.Options:Initialize()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local panel = CreateFrame("Frame")
    local title = CreateLabel(panel, "Bazi UI", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(148, 26)
    open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    open:SetText("Open Bazi UI")
    open:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel)
        addon.Options:Open()
    end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Bazi UI")
    Settings.RegisterAddOnCategory(category)
end
