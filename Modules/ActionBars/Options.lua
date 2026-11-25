local addon = BaziUI
addon.ActionBarsOptions = {}
local ASSET = "Interface\\AddOns\\BaziUI\\Assets\\"
local unpack = unpack or table.unpack

local function Label(parent, text, font)
    local obj = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    obj:SetText(text)
    return obj
end
local function Background(parent)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    addon.Theme:Paint(bg, "row", 0.94)
    local art = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetAllPoints()
    art:SetTexture(ASSET .. "Panels\\Panel_Dark.png")
    art:SetAlpha(0.20)
end
local function PanelArtwork(frame)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(frame)
    addon.Theme:Paint(fill, "panel", 0.97)
    local art = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetAllPoints(frame)
    art:SetTexture(ASSET .. "Panels\\Panel_Dark.png")
    art:SetAlpha(0.30)
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(3)
    accent:SetColorTexture(0.76, 0.57, 0.29, 0.90)
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(0.78, 0.59, 0.31, 0.45)
end

local function Row(parent, text, y, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    frame:SetHeight(height or 43)
    Background(frame)
    local title = Label(frame, text)
    title:SetPoint("LEFT", 13, 0)
    title:SetTextColor(1, 0.78, 0.39)
    return frame
end
local function Notify(key, db)
    local settings = addon.db.profile.actionbars
    local scope = db and settings and db == settings.experience and "ActionBars:Experience" or "ActionBars:Labels"
    if key == "font" or key == "cooldownFont" then addon.Typography.ModuleChanged(scope, "font") end
    if key == "textSize" or key == "cooldownSize" then addon.Typography.ModuleChanged(scope, "size") end
    addon.ActionBars:Apply()
end

local function NumberBox(parent, width, initial, commit, readSaved)
    local edit = CreateFrame("EditBox", nil, parent)
    edit:SetSize(width or 36, 19)
    edit:SetAutoFocus(false)
    edit:SetFontObject("GameFontNormal")
    edit:SetTextColor(1, 0.81, 0.45)
    edit:SetJustifyH("CENTER")
    edit:SetTextInsets(2, 2, 0, 0)
    edit:SetMaxLetters(7)
    -- Match the dark input fields and thin bronze outline used by Bazi UI.
    local fill = edit:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(edit)
    addon.Theme:Paint(fill, "field", 0.98)
    for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local border = edit:CreateTexture(nil, "ARTWORK")
        border:SetColorTexture(0.70, 0.50, 0.27, 0.85)
        if edge == "TOP" then
            border:SetPoint("TOPLEFT"); border:SetPoint("TOPRIGHT"); border:SetHeight(1)
        elseif edge == "BOTTOM" then
            border:SetPoint("BOTTOMLEFT"); border:SetPoint("BOTTOMRIGHT"); border:SetHeight(1)
        elseif edge == "LEFT" then
            border:SetPoint("TOPLEFT"); border:SetPoint("BOTTOMLEFT"); border:SetWidth(1)
        else
            border:SetPoint("TOPRIGHT"); border:SetPoint("BOTTOMRIGHT"); border:SetWidth(1)
        end
    end
    edit:SetText(tostring(initial))
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local function Commit()
        local n = tonumber(((edit:GetText() or ""):gsub(",", ".")))
        if n then commit(n) elseif readSaved then edit:SetText(readSaved()) end
    end
    edit:SetScript("OnEnterPressed", function()
        if not readSaved then Commit() end
        edit:ClearFocus()
    end)
    edit:SetScript("OnEditFocusLost", Commit)
    edit:SetScript("OnEscapePressed", function(self)
        if readSaved then self:SetText(readSaved()) end
        self:ClearFocus()
    end)
    return edit
end
local function Numeric(parent, title, y, db, key, low, high, step)
    local row = Row(parent, title, y)
    local function Clamp(v)
        return math.max(low, math.min(high, math.floor(v / step + 0.5) * step))
    end
    local box
    local function ReadSaved() return string.format("%g", db[key]) end
    box = NumberBox(row, 36, db[key], function(value)
        local saved = Clamp(value)
        local changed = saved ~= db[key]
        db[key] = saved
        box:SetText(ReadSaved())
        if changed then Notify(key, db) end
    end, ReadSaved)
    box:SetPoint("RIGHT", row, "RIGHT", -14, 0)

    -- Reuse the horizontal 21x24 step-button pattern from UnitFrames.
    -- Keep the compact value field at the far right.
    box:ClearAllPoints()
    box:SetPoint("RIGHT", row, "RIGHT", -65, 0)
    for i, delta in ipairs({1, -1}) do
        local button = CreateFrame("Button", nil, row)
        button:SetSize(21, 24)
        button:SetPoint("LEFT", box, "RIGHT", 5 + (i - 1) * 22, 0)
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        addon.Theme:Paint(bg, "panel", 1)
        local glyph = Label(button, delta == 1 and "+" or "-", "GameFontNormal")
        glyph:SetPoint("CENTER")
        button:SetScript("OnClick", function()
            db[key] = Clamp(db[key] + delta * step)
            box:SetText(string.format("%g", db[key]))
            Notify(key, db)
        end)
    end
    return row
end

local function Toggle(parent, title, y, db, key)
    local row = Row(parent, title, y)
    local check = addon.Theme:CreateCheckbox(row)
    check:SetPoint("RIGHT", row, "RIGHT", -16, 0)
    check:SetChecked(db[key])
    check:SetScript("OnClick", function(self)
        db[key] = not not self:GetChecked()
        if key == "visible" then db.visibilityRequested = true end
        Notify(key)
    end)
    return row
end
local function Dropdown(parent, title, y, db, key, choices)
    local row = Row(parent, title, y)
    -- Exact dimensions, fill, text alignment and menu geometry from
    -- Config/Options.lua's Minimap Select() control.
    local button = CreateFrame("Button", nil, row)
    button:SetSize(156, 24)
    button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    addon.Theme:Paint(fill, "field", 1)
    local caption = Label(button, "", "GameFontNormal")
    caption:SetPoint("CENTER")
    local arrow = Label(button, "v", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    local menu = CreateFrame("Frame", nil, button)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(button:GetFrameLevel() + 20)
    menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
    menu:SetSize(156, #choices * 24 + 4)
    local background = menu:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    addon.Theme:Paint(background, "field", 1)
    local function Refresh()
        for _, choice in ipairs(choices) do
            if db[key] == choice[1] then
                caption:SetText(choice[2])
                return
            end
        end
        caption:SetText("Select...")
    end
    for i, choice in ipairs(choices) do
        local item = CreateFrame("Button", nil, menu)
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * 24)
        item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i - 1) * 24)
        item:SetHeight(24)
        local text = Label(item, choice[2], "GameFontHighlightSmall")
        text:SetPoint("LEFT", 8, 0)
        item:SetScript("OnClick", function()
            db[key] = choice[1]
            Refresh()
            menu:Hide()
            Notify(key, db)
        end)
    end
    menu:Hide()
    button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    Refresh()
    return row
end

local function Heading(parent, title, y)
    local label = Label(parent, title, "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    label:SetTextColor(1, 0.79, 0.42)
end
local function ScrollPanel(main, topInset)
    topInset = topInset or 12
    local viewport = CreateFrame("ScrollFrame", nil, main)
    viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -topInset)
    viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -19, 10)
    if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
    viewport:EnableMouseWheel(true)
    local panel = CreateFrame("Frame", nil, viewport)
    panel:SetSize(500, 1)
    viewport:SetScrollChild(panel)
    viewport:SetScript("OnSizeChanged", function(self)
        panel:SetWidth(math.max(1, self:GetWidth()))
    end)
    local scrollbar = CreateFrame("Slider", nil, main)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetWidth(12)
    scrollbar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -topInset)
    scrollbar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 12)
    scrollbar:SetMinMaxValues(0, 1)
    scrollbar:SetValueStep(1)
    local track = scrollbar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    addon.Theme:Paint(track, "field", 0.9)
    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(14, 38)
    addon.Theme:StyleScrollThumb(thumb)
    scrollbar:SetThumbTexture(thumb)
    local syncing = false
    local function RefreshScroll()
        local limit = math.max(0, panel:GetHeight() - viewport:GetHeight())
        scrollbar:SetMinMaxValues(0, math.max(1, limit))
        scrollbar:SetShown(viewport:IsShown() and limit > 1)
        if not syncing then
            syncing = true
            scrollbar:SetValue(math.min(limit, viewport:GetVerticalScroll()))
            syncing = false
        end
    end
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if syncing then return end
        syncing = true
        viewport:SetVerticalScroll(value)
        syncing = false
    end)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        local limit = math.max(0, panel:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 36)))
        RefreshScroll()
    end)
    viewport:HookScript("OnVerticalScroll", RefreshScroll)
    viewport:HookScript("OnSizeChanged", RefreshScroll)
    viewport:HookScript("OnShow", RefreshScroll)
    viewport:HookScript("OnHide", function() scrollbar:Hide() end)
    return viewport, panel
end

local function TabButton(tabBar, name, width, selected, click)
    local b = CreateFrame("Button", nil, tabBar)
    b:SetSize(width, 29)
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
    b.accent = b:CreateTexture(nil, "OVERLAY")
    b.accent:SetPoint("TOPRIGHT"); b.accent:SetPoint("BOTTOMRIGHT")
    b.accent:SetWidth(3)
    b.label = Label(b, name)
    b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
    local function Refresh()
        local active = selected()
        addon.Theme:StyleSettingsTab(b, active)
        b.label:SetTextColor(active and 1 or 0.95, active and 0.85 or 0.80, active and 0.55 or 0.66)
        b.accent:SetColorTexture(active and 0.83 or 0.54, active and 0.63 or 0.37, active and 0.30 or 0.20, 1)
        for _, edge in ipairs(b.edges) do
            edge:SetColorTexture(active and 0.83 or 0.54, active and 0.63 or 0.37, active and 0.30 or 0.20, 0.95)
        end
    end
    b:SetScript("OnClick", click)
    b:SetScript("OnEnter", function()
        if not selected() then addon.Theme:StyleSettingsTab(b, false, true) end
    end)
    b:SetScript("OnLeave", Refresh)
    b.Refresh = Refresh
    return b
end

local fontChoices = {{"general", "Default"}, {"friz", "Friz Quadrata"}, {"arial", "Arial Narrow"}}

function addon.ActionBarsOptions:CreatePage(parent, createSlider)
    local module = addon.ActionBars
    local db = module:Settings()
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local header = CreateFrame("Frame", nil, page)
    header:SetPoint("TOPLEFT", 12, -8)
    header:SetPoint("TOPRIGHT", -12, -8)
    header:SetHeight(76)
    PanelArtwork(header)
    Heading(header, "ACTION BARS", -12)
    local enabled = addon.Theme:CreateCheckbox(header)
    enabled:SetSize(25, 25)
    enabled:SetPoint("TOPLEFT", 16, -41)
    enabled:SetChecked(db.enabled)
    local enabledLabel = Label(header, "Enable Action Bars", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    enabled:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() == true
        Notify()
    end)

    local main = CreateFrame("Frame", nil, page)
    main:SetPoint("TOPLEFT", 12, -100)
    main:SetPoint("BOTTOMRIGHT", -12, 8)
    PanelArtwork(main)
    local centerTabs = CreateFrame("Frame", nil, main)
    centerTabs:SetPoint("TOPLEFT", 10, -9)
    centerTabs:SetPoint("TOPRIGHT", -19, -9)
    centerTabs:SetHeight(29)
    local body = CreateFrame("Frame", nil, main)
    body:SetPoint("TOPLEFT", 0, -43)
    body:SetPoint("BOTTOMRIGHT")

    local right = CreateFrame("Frame", nil, page)
    right:SetPoint("TOPLEFT", main, "TOPRIGHT", 15, 0)
    right:SetPoint("BOTTOMLEFT", main, "BOTTOMRIGHT", 15, 0)
    right:SetWidth(132)
    right:SetFrameStrata("FULLSCREEN_DIALOG")
    local _, barList = ScrollPanel(right, 0)
    barList:SetHeight(29 * (#module.bars + 2))

    local activeBar, activeSection = "general", "layout"
    local panels, sideButtons, sectionButtons = {}, {}, {}
    local definitions = {}
    for _, def in ipairs(module.bars) do definitions[def.key] = def end
    local function list(parent, rows, settings)
        local y = -5
        for _, row in ipairs(rows) do
            local label, key, low, high, step, useSlider = unpack(row)
            if useSlider then
                createSlider(parent, label, "", low, high, step, settings[key], y, function(value)
                    settings[key] = value
                    module:ApplyExperience(settings)
                end, true, true)
            elseif type(low) == "table" then
                Dropdown(parent, label, y, settings, key, low)
            elseif low then
                Numeric(parent, label, y, settings, key, low, high, step)
            else
                Toggle(parent, label, y, settings, key)
            end
            y = y - 48
        end
        return y
    end
    local function makePanel()
        local viewport, panel = ScrollPanel(body)
        viewport:Hide()
        local y
        if activeBar == "general" then
            y = list(panel, {
                {"SHOW GRYPHONS", "gryphons"}, {"UPGRADE NEW SPELL RANKS", "autoRanks"},
            }, db)
            local note = Label(panel, "Layout changes made in combat apply when combat ends.", "GameFontHighlightSmall")
            note:SetPoint("TOPLEFT", 13, y - 8)
            local bindings = Label(panel, "/kb opens Quick Keybind. Hover a button, press a key, then confirm.", "GameFontHighlightSmall")
            bindings:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -8)
            y = y - 54
        elseif activeBar == "experience" then
            y = list(panel, {
                {"ENABLE EXPERIENCE BAR", "enabled"},
                {"BACKGROUND OPACITY (%)", "opacity", 0, 100, 1, true},
                {"WIDTH", "width", 80, 8000, 1}, {"HEIGHT", "height", 6, 64, 1},
                {"X OFFSET", "x", -1600, 1600, 1}, {"Y OFFSET", "y", -1000, 1000, 1},
                {"SEGMENTED BAR", "segmented"},
                {"SHOW RESTED XP", "showRested"}, {"SHOW COMPLETED QUEST XP", "showQuestXP"},
                {"SHOW TEXT", "showText"},
                {"SHOW QUEST XP IN TEXT", "showQuestText"},
                {"TEXT CONTENT", "textMode", {
                    {"both", "XP and percent"}, {"progress", "XP progress"},
                    {"percent", "Percent"}, {"remaining", "XP to level"},
                    {"questPercent", "Percent with quest XP"},
                }},
                {"FONT", "font", fontChoices}, {"TEXT SIZE", "textSize", 7, 32, 1},
                {"SHOW WATCHED REPUTATION BAR", "showReputation"},
                {"REPUTATION Y OFFSET", "reputationY", -1000, 1000, 1},
            }, db.experience)
        else
            local settings = db.bars[activeBar]
            if activeSection == "layout" then
                local rows = {
                    {"ENABLE BAR VISIBILITY", "visible"}, {"BUTTON SCALE (%)", "scale", 50, 160, 1},
                    {"X OFFSET", "x", -1600, 1600, 1}, {"Y OFFSET", "y", -1000, 1000, 1},
                }
                local def = definitions[activeBar]
                if def.key == "pet" or def.key:match("^bar%d+$") then
                    rows[#rows + 1] = {"SHOW EMPTY BUTTONS", "empty"}
                end
                if def.key == "pet" then
                    rows[#rows + 1] = {"BUTTON SIZE (0 = AUTO)", "petButtonSize", 0, 80, 1}
                end
                if def.prefix and not def.key:match("^bar%d+$") then
                    if def.key ~= "pet" then
                        rows[#rows + 1] = {"BUTTON SIZE (0 = AUTO)", "nativeButtonSize", 0, 80, 1}
                    end
                    rows[#rows + 1] = {"ROWS (0 = DEFAULT)", "rows", 0, def.count, 1}
                    rows[#rows + 1] = {"BUTTON SPACING", "nativeSpacing", -8, 40, 1}
                end
                if def.key:match("^bar%d+$") then
                    rows[#rows + 1] = {"BUTTON SIZE", "buttonSize", 16, 80, 1}
                    rows[#rows + 1] = {"BUTTON COUNT (0 = DEFAULT)", "buttons", 0, def.count, 1}
                    rows[#rows + 1] = {"ORIENTATION", "direction", {
                        {"default", "Default"}, {"horizontal", "Horizontal"}, {"vertical", "Vertical"},
                    }}
                    rows[#rows + 1] = {"COLUMNS (0 = DEFAULT)", "columns", 0, def.count, 1}
                    rows[#rows + 1] = {"ROWS (0 = DEFAULT)", "rows", 0, def.count, 1}
                    rows[#rows + 1] = {"BUTTON SPACING", "spacing", -8, 40, 1}
                end
                if def.prefix then
                    rows[#rows + 1] = {"SHOW VANILLA BUTTON BORDER", "border"}
                    rows[#rows + 1] = {"SHOW VANILLA SLOT BACKGROUND", "vanillaBackground"}
                    rows[#rows + 1] = {"SHOW SUBTLE SLOT TINT", "slotTint"}
                elseif def.key == "micro" or def.key == "bags" then
                    rows[#rows + 1] = {"SHOW ORIGINAL BACKGROUND", "vanillaBackground"}
                end
                y = list(panel, rows, settings)
            elseif activeSection == "text" then
                y = list(panel, {
                    {"FONT", "font", fontChoices}, {"TEXT SIZE", "textSize", 7, 32, 1},
                    {"COOLDOWN FONT", "cooldownFont", fontChoices},
                    {"COOLDOWN SIZE (0 = DEFAULT)", "cooldownSize", 0, 40, 1},
                    {"SHOW HOTKEY TEXT", "hotkeys"}, {"SHOW MACRO TEXT", "macro"},
                }, settings)
            else
                y = list(panel, {
                    {"COLOR OUT OF RANGE", "range"}, {"COLOR OUT OF MANA", "mana"},
                    {"DIM UNUSABLE", "unusable"}, {"DIM ON COOLDOWN", "cooldown"},
                    {"STATUS STRENGTH (%)", "strength", 0, 100, 1},
                    {"SHOW PROC GLOW", "proc"}, {"GOLD ACTIVE / PET AUTOCAST GLOW", "active"},
                }, settings)
            end
        end
        panel:SetHeight(-y + 12)
        return viewport
    end
    local function Refresh()
        local hasButtons = definitions[activeBar] and definitions[activeBar].prefix ~= nil
        centerTabs:SetShown(hasButtons == true)
        body:SetPoint("TOPLEFT", main, "TOPLEFT", 0, hasButtons and -43 or 0)
        local key = activeBar .. "/" .. activeSection
        if not panels[key] then panels[key] = makePanel() end
        for name, viewport in pairs(panels) do viewport:SetShown(name == key) end
        for _, button in ipairs(sideButtons) do button:Refresh() end
        for _, button in ipairs(sectionButtons) do button:Refresh() end
    end
    for i, item in ipairs({{"layout", "Layout"}, {"text", "Fonts"}, {"effects", "Effects"}}) do
        local key, title = item[1], item[2]
        local button = TabButton(centerTabs, title, 90, function() return activeSection == key end, function()
            activeSection = key
            Refresh()
        end)
        button:SetPoint("TOPLEFT", centerTabs, "TOPLEFT", (i - 1) * 92, 0)
        sectionButtons[i] = button
    end
    local function AddBar(i, key, title)
        local button = TabButton(barList, title, 96, function() return activeBar == key end, function()
            activeBar, activeSection = key, "layout"
            Refresh()
        end)
        button:SetPoint("TOPLEFT", barList, "TOPLEFT", 0, -(i - 1) * 29)
        sideButtons[i] = button
    end
    AddBar(1, "general", "General")
    for i, def in ipairs(module.bars) do AddBar(i + 1, def.key, def.title) end
    AddBar(#module.bars + 2, "experience", "Experience")
    function page:SelectSubpage(key)
        if key == "experience" or key == "general" or definitions[key] then
            activeBar, activeSection = key, "layout"
            Refresh()
        end
    end
    Refresh()
    return page
end
