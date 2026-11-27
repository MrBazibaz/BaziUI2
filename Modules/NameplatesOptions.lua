-- Bazi UI Nameplates: isolated settings page.
local addon = BaziUI
addon.NameplatesOptions = addon.NameplatesOptions or {}
local ASSET = "Interface\\AddOns\\BaziUI\\Assets\\"

local defaults = {
    enabled = false, -- Vanilla nameplates until Bazi UI is explicitly enabled.
    friendlyIcon = "role", friendlyScope = "group", raidRoles = true,
    friendlyX = 0, friendlyY = 20, friendlySize = 28,
    friendlyTextX = 0, friendlyTextY = 0, friendlyTextSize = 20,
    petEnabled = true, petShowIcon = false, petIconVisibility = "always",
    npcEnabled = true, npcIcons = false, npcQuestMarkers = true,
}
local function Settings()
    local profile = addon.db and addon.db.profile
    if not profile then return nil end
    if type(profile.nameplates) ~= "table" then profile.nameplates = {} end
    for key, value in pairs(defaults) do
        if profile.nameplates[key] == nil then profile.nameplates[key] = value end
    end
    for key, value in pairs(addon.EnemyNameplates.defaults) do
        if profile.nameplates[key] == nil then profile.nameplates[key] = value end
    end
    return profile.nameplates
end
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
local function Notify(key)
    if key then
        local scope = key:match("^enemy") and "Nameplates:Enemy"
            or key:match("^friendly") and "Nameplates:Friendly" or "Nameplates:NPC"
        if key:match("Font$") then addon.Typography.ModuleChanged(scope, "font")
        elseif key == "friendlyTextSize" or key == "npcTextSize"
            or key:match("^enemy.*(Size)$") and (key:match("^enemyName") or key:match("^enemyHealth")
                or key:match("^enemyLevel") or key:match("^enemyCast") or key:match("^enemyDebuffTime")) then
            addon.Typography.ModuleChanged(scope, "size")
        end
    end
    if key and key:match("^enemy") then
        addon.EnemyNameplates:RefreshPreview()
        addon.Nameplates:ApplyEnemy()
    elseif addon.Nameplates then
        addon.Nameplates:Apply()
    end
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
        if changed or not key:match("^enemy") then Notify(key) end
    end, key:match("^enemy") and ReadSaved or nil)
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
            Notify(key)
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
            Notify(key)
        end)
    end
    menu:Hide()
    button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    Refresh()
    return row
end

local function Slider(parent, title, y, db, key, low, high, step)
    local row = Row(parent, title, y, 50)
    local box
    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(115, 18)
    slider:SetPoint("RIGHT", row, "RIGHT", -53, 0)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT")
    track:SetPoint("RIGHT", slider, "RIGHT")
    track:SetHeight(7)
    track:SetTexture(ASSET .. "Sliders\\Slider_Track.png")
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(24, 28)
    thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
    slider:SetThumbTexture(thumb)
    local fill = slider:CreateTexture(nil, "BORDER")
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetHeight(7)
    fill:SetTexture(ASSET .. "Sliders\\Slider_Fill_Gold.png")
    box = NumberBox(row, 36, db[key], function(value)
        slider:SetValue(math.max(low, math.min(high, value)))
    end)
    box:SetPoint("RIGHT", row, "RIGHT", -13, 0)
    slider:SetScript("OnValueChanged", function(_, value)
        local n = math.max(low, math.min(high, math.floor(value / step + 0.5) * step))
        local changed = n ~= db[key]
        db[key] = n
        if not box:HasFocus() then box:SetText(string.format("%g", n)) end
        fill:SetWidth(math.max(1, 115 * (n - low) / (high - low)))
        if changed then Notify(key) end
    end)
    slider:SetValue(db[key])
    return row
end
local function Heading(parent, title, y)
    local label = Label(parent, title, "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    label:SetTextColor(1, 0.79, 0.42)
end
local function ScrollPage(parent)
    local frame = CreateFrame("ScrollFrame", nil, parent)
    frame:SetPoint("TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", -18, 0)
    frame:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(610, 1300)
    frame:SetScrollChild(child)
    frame:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(math.max(1, w - 8))
    end)
    frame:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 45)))
    end)
    return frame, child
end
function addon.NameplatesOptions:CreatePage(parent)
    local db = Settings()
    if not db then return nil end
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    -- Match Minimap's two-panel structure and right-hand navigation.
    local headingPanel = CreateFrame("Frame", nil, page)
    headingPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -8)
    headingPanel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -8)
    headingPanel:SetHeight(76)
    PanelArtwork(headingPanel)
    local heading = Label(headingPanel, "NAMEPLATES", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 22, -12)
    heading:SetTextColor(1, 0.79, 0.42)
    -- Match Minimap's enable checkbox in the header.
    local enabled = addon.Theme:CreateCheckbox(headingPanel)
    enabled:SetSize(25, 25)
    enabled:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 16, -41)
    enabled:SetChecked(db.enabled)
    local enabledLabel = Label(headingPanel, "Enable Nameplates", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    enabled:SetScript("OnClick", function(self)
        db.enabled = not not self:GetChecked()
        Notify()
    end)

    local main = CreateFrame("Frame", nil, page)
    main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
    main:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    PanelArtwork(main)
    if main.SetClipsChildren then main:SetClipsChildren(true) end

    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", main, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 116)
    local tabButtons, tabPanels = {}, {}
    local activeTab = "Friendly"

    local function RefreshTabs()
        for name, button in pairs(tabButtons) do
            local selected = name == activeTab
            addon.Theme:Paint(button.fill, selected and "purple" or "panel", 0.98)
            button.label:SetTextColor(selected and 1 or 0.95,
                selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54,
                selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do
                edge:SetColorTexture(selected and 0.83 or 0.54,
                    selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95)
            end
        end
        for name, viewport in pairs(tabPanels) do viewport:SetShown(name == activeTab) end
        local available = math.max(120, page:GetHeight() - 110)
        main:ClearAllPoints()
        main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
        main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
        main:SetHeight(math.min(activeTab == "Friendly" and 600 or 650, available))
        local viewport = tabPanels[activeTab]
        if viewport then viewport:SetVerticalScroll(0) end
    end

    for i, name in ipairs({"Friendly", "Friendly Pet", "NPC", "Enemy"}) do
        local b = CreateFrame("Button", nil, tabBar)
        b:SetSize(108, 29)
        b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -(i - 1) * 29)
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
        b:SetScript("OnClick", function() activeTab = name; RefreshTabs() end)
        b:SetScript("OnEnter", function()
            if activeTab ~= name then addon.Theme:Paint(b.fill, "muted", 0.98) end
        end)
        b:SetScript("OnLeave", RefreshTabs)
        tabButtons[name] = b
    end

    local function NewTab(name, height)
        local viewport = CreateFrame("ScrollFrame", nil, main)
        viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -12)
        viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -19, 10)
        if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
        viewport:EnableMouseWheel(true)
        local panel = CreateFrame("Frame", nil, viewport)
        panel:SetSize(500, height)
        viewport:SetScrollChild(panel)
        viewport:SetScript("OnSizeChanged", function(self)
            panel:SetWidth(math.max(1, self:GetWidth()))
        end)
        local scrollbar = CreateFrame("Slider", nil, main)
        scrollbar:SetOrientation("VERTICAL")
        scrollbar:SetWidth(12)
        scrollbar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -12)
        scrollbar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 12)
        scrollbar:SetMinMaxValues(0, 1)
        scrollbar:SetValueStep(1)
        local track = scrollbar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints()
        addon.Theme:Paint(track, "field", 0.9)
        local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(14, 38)
        thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
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
        tabPanels[name] = viewport
        return panel
    end

    local friendly = NewTab("Friendly", 630)
    Dropdown(friendly, "ICON TYPE", -4, db, "friendlyIcon", {
        {"off", "Disabled"}, {"class", "Class Icon"}, {"role", "Role Icon"},
    })
    Dropdown(friendly, "SHOW ICONS FOR", -49, db, "friendlyScope", {
        {"all", "All Friendly Players"}, {"group", "Group Members Only"},
    })
    Toggle(friendly, "RAID: TANK AND HEALER ONLY", -94, db, "raidRoles")
    Heading(friendly, "ICON LAYOUT", -159)
    Slider(friendly, "ICON SIZE", -195, db, "friendlySize", 12, 64, 1)
    Numeric(friendly, "ICON X OFFSET", -255, db, "friendlyX", -300, 300, 1)
    Numeric(friendly, "ICON Y OFFSET", -303, db, "friendlyY", -300, 300, 1)
    Heading(friendly, "NAME AND GUILD TEXT", -355)
    Numeric(friendly, "TEXT X OFFSET", -390, db, "friendlyTextX", -300, 300, 1)
    Numeric(friendly, "TEXT Y OFFSET", -438, db, "friendlyTextY", -300, 300, 1)
    Slider(friendly, "TEXT FONT SIZE", -495, db, "friendlyTextSize", 6, 32, 1)
    local note = Label(friendly,
        "In raids: only tank and healer role icons. Class icons and DPS icons are hidden.",
        "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", friendly, "TOPLEFT", 14, -570)
    note:SetWidth(400)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.66, 0.63, 0.59, 1)

    local pet = NewTab("Friendly Pet", 540)
    Toggle(pet, "ENABLE FRIENDLY PET NAMEPLATES", -4, db, "petEnabled")
    Toggle(pet, "SHOW ICON ON MY PET", -52, db, "petShowIcon")
    Dropdown(pet, "MY PET ICON VISIBILITY", -100, db, "petIconVisibility", {
        {"always", "Always"}, {"combat", "Only in Combat"},
    })
    Heading(pet, "NAME AND OWNER TEXT", -166)
    local petNote = Label(pet,
        "Same blue-purple font, size and offsets as Friendly players.\nOwner shown below name in <Owner's Pet> format.\nOther players' pets never display an icon.",
        "GameFontHighlightSmall")
    petNote:SetPoint("TOPLEFT", pet, "TOPLEFT", 14, -209)
    petNote:SetWidth(450)
    petNote:SetJustifyH("LEFT")
    petNote:SetTextColor(0.66, 0.63, 0.59, 1)

    local npc = NewTab("NPC", 460)
    Toggle(npc, "ENABLE FRIENDLY NPC NAMEPLATES", -4, db, "npcEnabled")
    Toggle(npc, "ENABLE NPC ICONS", -52, db, "npcIcons")
    Toggle(npc, "SHOW NPC QUEST MARKERS", -100, db, "npcQuestMarkers")
    Heading(npc, "NAME TEXT", -168)
    local npcNote = Label(npc,
        "Same name layout as Friendly players, with green text.\nService and quest icons require reliable client identification;\nunknown NPC types remain text-only.",
        "GameFontHighlightSmall")
    npcNote:SetPoint("TOPLEFT", npc, "TOPLEFT", 14, -213)
    npcNote:SetWidth(450)
    npcNote:SetJustifyH("LEFT")
    npcNote:SetTextColor(0.66, 0.63, 0.59, 1)

    local enemy = NewTab("Enemy", 2885)
    -- Same bronze action button as UnitFrames' indicator preview.
    local previewButton = CreateFrame("Button", nil, headingPanel)
    previewButton:SetSize(170, 27)
    previewButton:SetPoint("BOTTOMRIGHT", headingPanel, "BOTTOMRIGHT", -14, 12)
    local previewFill = previewButton:CreateTexture(nil, "BACKGROUND")
    previewFill:SetAllPoints()
    addon.Theme:Paint(previewFill, "panel", 0.98)
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local edge = previewButton:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(0.72, 0.52, 0.27, 0.95)
        if side == "TOP" then
            edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
        elseif side == "BOTTOM" then
            edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
        elseif side == "LEFT" then
            edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
        else
            edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
        end
    end
    local previewText = Label(previewButton, "Preview enemy nameplate", "GameFontNormal")
    previewText:SetPoint("CENTER")
    previewText:SetTextColor(1, 0.79, 0.42)
    previewButton:SetScript("OnEnter", function() addon.Theme:Paint(previewFill, "muted", 0.98) end)
    previewButton:SetScript("OnLeave", function() addon.Theme:Paint(previewFill, "panel", 0.98) end)
    local previewOn = false
    local function SetPreview(shown)
        previewOn = shown
        addon.EnemyNameplates:SetPreview(shown and db or nil)
        previewText:SetText(shown and "Stop preview" or "Preview enemy nameplate")
    end
    previewButton:Hide()
    previewButton:SetScript("OnClick", function() SetPreview(not previewOn) end)
    tabPanels.Enemy:HookScript("OnShow", function() previewButton:Show() end)
    tabPanels.Enemy:HookScript("OnHide", function()
        previewButton:Hide()
        if previewOn then SetPreview(false) end
    end)
    local y = -12
    local fontChoices = {
        {"general", "General (Default)"}, {"friz", "Friz Quadrata"}, {"arial", "Arial Narrow"},
    }
    local anchorChoices = {
        {"DEFAULT", "Default"}, {"CENTER", "Center"},
        {"TOPLEFT", "Top left"}, {"TOP", "Top"}, {"TOPRIGHT", "Top right"},
        {"LEFT", "Left"}, {"RIGHT", "Right"},
        {"BOTTOMLEFT", "Bottom left"}, {"BOTTOM", "Bottom"}, {"BOTTOMRIGHT", "Bottom right"},
    }
    local function Section(title)
        Heading(enemy, title, y)
        y = y - 36
    end
    local function Check(title, key)
        Toggle(enemy, title, y, db, key)
        y = y - 48
    end
    local function Number(title, key, low, high, step)
        Numeric(enemy, title, y, db, key, low, high, step or 1)
        y = y - 48
    end
    local function Offsets(key, prefix)
        prefix = prefix or ""
        Number(prefix .. "X OFFSET", key .. "X", -300, 300)
        Number(prefix .. "Y OFFSET", key .. "Y", -300, 300)
    end
    local function TextOptions(key, positionKey)
        positionKey = positionKey or key
        Dropdown(enemy, "FONT", y, db, key .. "Font", fontChoices)
        y = y - 48
        Number("FONT SIZE (0 = GENERAL)", key .. "Size", 0, 32)
        Dropdown(enemy, "TEXT ANCHOR", y, db, positionKey .. "Anchor", anchorChoices)
        y = y - 48
        Offsets(positionKey, positionKey ~= key and "TEXT " or nil)
    end
    Section("HEALTH BAR")
    Check("ENABLE ENEMY NAMEPLATES", "enemyEnabled")
    Number("HEALTH WIDTH", "enemyWidth", 80, 300)
    Number("HEALTH HEIGHT", "enemyHeight", 6, 45)
    Number("NAMEPLATE SCALE", "enemyScale", 0.5, 2, 0.05)
    Offsets("enemyPlate")
    Check("HIGHLIGHT CURRENT TARGET", "enemyTarget")
    Number("TARGET GLOW WIDTH (0 = OFF)", "enemyTargetGlowWidth", 0, 24)
    Check("GRAY OUT TAGGED MOBS", "enemyTapped")
    Check("SHOW HEALTH PERCENT", "enemyHealth")
    TextOptions("enemyHealth")
    Section("RANGE")
    Check("FADE OUT-OF-RANGE ENEMIES", "enemyRange")
    Number("OUT-OF-RANGE OPACITY (%)", "enemyRangeAlpha", 15, 100)
    Number("RANGE SPELL ID (0 = AUTO)", "enemyRangeSpell", 0, 999999)
    Section("NAME")
    Check("SHOW NAME", "enemyName")
    TextOptions("enemyName")
    Check("SHOW OPPOSING FACTION BADGE", "enemyFaction")
    Number("FACTION BADGE SIZE", "enemyFactionSize", 8, 150)
    Number("FACTION BADGE X OFFSET", "enemyFactionX", -1000, 1000)
    Number("FACTION BADGE Y OFFSET", "enemyFactionY", -300, 300)
    Section("COMBO POINTS")
    Check("SHOW COMBO POINTS ON TARGETS", "enemyCombo")
    Dropdown(enemy, "COMBO POINT STYLE", y, db, "enemyComboStyle", {
        {"orb", "Gold orb"}, {"square", "Gold square"}, {"star", "Star"},
        {"skull", "Skull"}, {"moon", "Moon"}, {"goldGem", "Gold gem"},
        {"diamond", "Bazi diamond"}, {"dagger", "Bazi dagger"}, {"claw", "Bazi claw"},
        {"silverGem", "Silver gem"}, {"plumGem", "Plum gem"},
        {"venom", "Venom drop"}, {"runestone", "Runestone"}, {"ember", "Ember"},
        {"thorn", "Jade thorn"}, {"eye", "Watcher eye"}, {"crescent", "Silver crescent"},
        {"steelKnife", "Steel knife"},
    })
    y = y - 48
    Number("COMBO POINT SIZE", "enemyComboSize", 6, 40)
    Offsets("enemyCombo", "COMBO POINT ")
    Section("LEVEL")
    Check("SHOW LEVEL", "enemyLevel")
    TextOptions("enemyLevel")
    Section("ELITE / RARE")
    Check("SHOW DRAGON AROUND LEVEL", "enemyClassification")
    Number("DRAGON SIZE", "enemyClassificationIconSize", 10, 80)
    Offsets("enemyClassification")
    Section("QUEST OBJECTIVE")
    Check("SHOW QUEST ICON", "enemyQuest")
    Dropdown(enemy, "QUEST ICON STYLE", y, db, "enemyQuestStyle", {
        {"glow", "Gold exclamation"}, {"atlas", "Blizzard icon"},
    })
    y = y - 48
    Number("ICON SIZE", "enemyQuestSize", 8, 48)
    Offsets("enemyQuest")
    Section("THREAT")
    Check("COLOR HEALTH BY THREAT", "enemyThreat")
    Dropdown(enemy, "THREAT ROLE", y, db, "enemyThreatRole", {
        {"auto", "Auto"}, {"damage", "DPS / Healer"}, {"tank", "Tank"},
    })
    y = y - 48
    Number("DPS / HEALER WARNING (%)", "enemyThreatWarning", 1, 99)
    Section("COLORS")
    for _, option in ipairs(addon.EnemyNameplates.colorOptions) do
        local key, title = option[1], option[2]
        Heading(enemy, title, y)
        local swatch = addon.Theme:CreateColorSwatch(enemy, function()
            return addon.EnemyNameplates:GetColor(db, key)
        end, function(color)
            db.enemyColors = db.enemyColors or {}
            db.enemyColors[key] = color
            Notify()
            if previewOn then addon.EnemyNameplates:SetPreview(db, key) end
        end)
        swatch:SetPoint("TOPRIGHT", enemy, "TOPRIGHT", -25, y)
        y = y - 36
    end
    Section("DEBUFFS")
    Check("SHOW MY DEBUFFS", "enemyDebuffs")
    Check("SHOW DEBUFF STACKS", "enemyDebuffStacks")
    Number("ICON SIZE", "enemyDebuffSize", 8, 48)
    Offsets("enemyDebuff")
    Section("DEBUFF TIMER")
    Check("SHOW DEBUFF TIMER", "enemyDebuffTimer")
    TextOptions("enemyDebuffTime")
    Section("RAID MARKER")
    Check("SHOW RAID MARKER", "enemyRaid")
    Number("ICON SIZE", "enemyRaidSize", 8, 48)
    Offsets("enemyRaid")
    Section("CASTBAR")
    Check("SHOW CASTBAR", "enemyCastbar")
    Number("CASTBAR HEIGHT", "enemyCastHeight", 6, 35)
    Number("CASTBAR WIDTH (0 = HEALTH WIDTH)", "enemyCastWidth", 0, 300)
    Offsets("enemyCast", "BAR ")
    TextOptions("enemyCast", "enemyCastText")
    Section("CAST TIME")
    Check("SHOW REMAINING CAST TIME", "enemyCastTimer")
    TextOptions("enemyCastTime")
    enemy:SetHeight(-y + 12)

    function page:SelectSubpage(name)
        if tabButtons[name] then activeTab = name; RefreshTabs() end
    end
    page:HookScript("OnShow", RefreshTabs)
    page:HookScript("OnSizeChanged", RefreshTabs)
    RefreshTabs()
    return page
end
