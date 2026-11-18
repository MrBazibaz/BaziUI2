local addon = BaziUI

addon.Options = addon.Options or {}

local optionsFrame
local contentFrame
local navButtons = {}
local pages = {}

local ASSET = "Interface\\AddOns\\BaziUI\\Assets\\"

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

    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(panel)
    fill:SetColorTexture(0.19, 0.105, 0.052, 0.97)
    local panelArt = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    panelArt:SetAllPoints(panel)
    panelArt:SetTexture(ASSET .. "Panels\\Panel_Dark.png")
    panelArt:SetAlpha(0.30)

    local accent = panel:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetColorTexture(0.76, 0.57, 0.29, 0.90)

    local topLine = panel:CreateTexture(nil, "BORDER")
    topLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    topLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    topLine:SetHeight(1)
    topLine:SetColorTexture(0.78, 0.59, 0.31, 0.45)
    return panel
end

local function CreateSlider(parent, labelText, description, minValue, maxValue, step, value, y, onValueChanged)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, y)
    row:SetHeight(54)
    local fill = row:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(row)
    fill:SetColorTexture(0.25, 0.125, 0.055, 0.96)
    local rowArt = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    rowArt:SetAllPoints(row)
    rowArt:SetTexture(ASSET .. "Panels\\Panel_Dark.png")
    rowArt:SetAlpha(0.20)
    local heading = CreateLabel(row, labelText, "GameFontNormal")
    heading:SetPoint("TOPLEFT", row, "TOPLEFT", 15, -10)
    heading:SetTextColor(1, 0.78, 0.39)
    local hint = CreateLabel(row, description, "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", row, "TOPLEFT", 15, -30)
    hint:SetTextColor(0.91, 0.78, 0.61, 1)
    local valueText = CreateLabel(row, "", "GameFontNormal")
    valueText:SetPoint("RIGHT", row, "RIGHT", -15, 0)
    valueText:SetTextColor(1, 0.81, 0.45)
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
    thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
    slider:SetThumbTexture(thumb)
    local progress = slider:CreateTexture(nil, "BORDER")
    progress:SetPoint("LEFT", track, "LEFT", 0, 0)
    progress:SetHeight(7)
    progress:SetTexture(ASSET .. "Sliders\\Slider_Fill_Gold.png")
    local function RefreshProgress(raw)
        local fraction = (raw - minValue) / (maxValue - minValue)
        progress:SetWidth(math.max(1, 115 * math.max(0, math.min(1, fraction))))
    end
    slider:SetScript("OnValueChanged", function(self, raw)
        local rounded = math.floor(raw / step + 0.5) * step
        valueText:SetText(string.format("%g", rounded))
        RefreshProgress(rounded)
        if onValueChanged then onValueChanged(rounded) end
    end)
    slider:SetValue(value)
    RefreshProgress(value)
    valueText:SetText(string.format("%g", value))
    return slider
end

local function ShowPage(pageName)
    for name, page in pairs(pages) do
        page:SetShown(name == pageName)
    end

    for name, button in pairs(navButtons) do
        button.baziActive = (name == pageName)
        button.baziRefresh()
    end
end

local function CreateGeneralPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.General = page
    local introPanel = CreatePanel(page, -10, 66)
    CreateSection(introPanel, "GENERAL SETTINGS", -14)
    local intro = CreateLabel(page, "Adjust the Bazi UI window and default text size.", "GameFontHighlightSmall")
    intro:SetParent(introPanel)
    intro:SetPoint("TOPLEFT", introPanel, "TOPLEFT", 22, -39)
    intro:SetTextColor(0.96, 0.82, 0.63, 1)

    local appearancePanel = CreatePanel(page, -88, 242)
    CreateSection(appearancePanel, "APPEARANCE", -14)
    local db = addon.db.profile
    CreateSlider(page, "WINDOW SCALE", "Size of the Bazi UI settings window", 0.70, 1.20, 0.01, db.uiScale, -142, function(value)
        db.uiScale = value
        if optionsFrame then optionsFrame:SetScale(value) end
    end)
    CreateSlider(page, "FONT SIZE", "Default text size for supported modules", 10, 20, 1, db.fontSize, -204, function(value)
        db.fontSize = value
    end)
    local note = CreateLabel(page, "Changes are saved automatically.", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -352)
    note:SetTextColor(0.90, 0.76, 0.55, 1)
    return page
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

local function CreateVersionHistoryPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages["Version History"] = page

    local panel = CreatePanel(page, -10, 200)
    CreateSection(panel, "VERSION HISTORY", -14)

    local current = CreateLabel(panel, "v0.1.1", "GameFontNormalLarge")
    current:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -56)
    current:SetTextColor(1, 0.81, 0.45)
    local currentNotes = CreateLabel(panel,
        "Quality of Life and Profiles, search, resize handles, and emblem alignment.",
        "GameFontHighlightSmall")
    currentNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -83)
    currentNotes:SetTextColor(0.92, 0.79, 0.65)

    local previous = CreateLabel(panel, "v0.1.0", "GameFontNormalLarge")
    previous:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -119)
    previous:SetTextColor(1, 0.81, 0.45)
    local previousNotes = CreateLabel(panel,
        "Original options menu with window scale, font size and module placeholders.",
        "GameFontHighlightSmall")
    previousNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -146)
    previousNotes:SetTextColor(0.92, 0.79, 0.65)
    return page
end

local function CreateNavigationButton(parent, name, label, y)
    -- Custom flat navigation: the active page gets purple, not every button.
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(170, 29)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, y)
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(button)
    -- Straight bronze edges to match the rectangular fill.
    local edges = {}
    for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local line = button:CreateTexture(nil, "ARTWORK")
        if edge == "TOP" then
            line:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            line:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
            line:SetHeight(1)
        elseif edge == "BOTTOM" then
            line:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
            line:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            line:SetHeight(1)
        elseif edge == "LEFT" then
            line:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            line:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
            line:SetWidth(1)
        else
            line:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
            line:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            line:SetWidth(1)
        end
        edges[#edges + 1] = line
    end
    local function TintEdges(r, g, b, a)
        for _, line in ipairs(edges) do line:SetColorTexture(r, g, b, a) end
    end
    local stripe = button:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    stripe:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    stripe:SetWidth(3)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", button, "LEFT", 17, 0)
    text:SetText(label)
    text:SetJustifyH("LEFT")
    button.baziActive = false
    button.baziHover = false
    button.baziRefresh = function()
        if button.baziActive then
            TintEdges(0.83, 0.63, 0.30, 0.88)
            fill:SetColorTexture(0.34, 0.17, 0.25, 0.98)
            stripe:SetColorTexture(0.83, 0.63, 0.30, 1)
            text:SetTextColor(1, 0.85, 0.55)
        elseif button.baziHover then
            TintEdges(0.72, 0.53, 0.31, 0.72)
            fill:SetColorTexture(0.28, 0.15, 0.085, 0.96)
            stripe:SetColorTexture(0.57, 0.42, 0.26, 0.8)
            text:SetTextColor(0.95, 0.87, 0.73)
        else
            TintEdges(0.50, 0.34, 0.19, 0.55)
            fill:SetColorTexture(0.18, 0.095, 0.05, 0.94)
            stripe:SetColorTexture(0.54, 0.35, 0.19, 0.75)
            text:SetTextColor(0.87, 0.74, 0.56)
        end
    end
    button:SetScript("OnEnter", function(self) self.baziHover = true; self.baziRefresh() end)
    button:SetScript("OnLeave", function(self) self.baziHover = false; self.baziRefresh() end)
    button:SetScript("OnClick", function() ShowPage(name) end)
    button.baziRefresh()
    navButtons[name] = button
end

function addon.Options:Open()
    if not optionsFrame then
        self:Create()
    end

    optionsFrame:Show()
    optionsFrame:Raise()
 end

function addon.Options:Create()
    local db = addon.db and addon.db.profile
    if not db then
        print("Bazi UI: Settings database is not initialized.")
        return
    end
    optionsFrame = CreateFrame("Frame", "BaziUIOptionsFrame", UIParent)
    -- Native bronze Blizzard frame, verified visually on Forever.
    local borderHost = CreateFrame("Frame", nil, optionsFrame, "ButtonFrameTemplate")
    borderHost:SetAllPoints(optionsFrame)
    borderHost:EnableMouse(false)
    for _, child in ipairs({borderHost:GetChildren()}) do
        if child ~= borderHost.NineSlice then
            child:Hide()
        end
    end
    for _, region in ipairs({borderHost:GetRegions()}) do
        region:Hide()
    end
    if borderHost.NineSlice then
        borderHost.NineSlice:Show()
    end
    -- Remove portrait-only art without touching the bronze NineSlice border.
    -- Forever's character frame inspection identifies 130924 as portrait trim.
    local function HidePortraitArt(frame, depth)
        if depth > 4 then return end
        for _, region in ipairs({frame:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                local texture = region:GetTexture()
                if texture == 130924 or texture == 626000 then
                    region:Hide()
                    region:SetAlpha(0)
                end
            end
        end
        for _, child in ipairs({frame:GetChildren()}) do
            HidePortraitArt(child, depth + 1)
        end
    end
    HidePortraitArt(borderHost, 0)

    -- The native portrait ring is part of the frame design. Keep it and
    -- insert the Bazi emblem in its centre (asset supplied in this repo).
    -- Put the emblem on a frame above the template artwork, not underneath it.
    -- Keep the emblem attached to the options window: a separate UIParent
    -- overlay did not render reliably on the Forever client.
    local emblemHost = CreateFrame("Frame", nil, borderHost.NineSlice or optionsFrame)
    emblemHost:SetSize(66, 66)
    -- The emblem graphic is slightly asymmetric inside its transparent image.
    -- A tiny optical correction centers the visible B over the native ring.
    emblemHost:SetPoint("CENTER", optionsFrame, "TOPLEFT", 24, -21)
    emblemHost:SetFrameStrata("FULLSCREEN_DIALOG")
    emblemHost:SetFrameLevel(math.max(borderHost:GetFrameLevel(), borderHost.NineSlice and borderHost.NineSlice:GetFrameLevel() or 0) + 30)
    emblemHost:EnableMouse(false)
    optionsFrame.baziEmblemHost = emblemHost
    local emblem = emblemHost:CreateTexture(nil, "OVERLAY")
    emblem:SetAllPoints(emblemHost)
    emblem:SetTexture(ASSET .. "Icons\\BaziUI_Emblem_256.png")
    optionsFrame.baziEmblem = emblem

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

    -- Same drag-to-resize interaction as the archived V7 implementation.
    -- Native NineSlice frame artwork remains untouched.
    local function ResizeGrip(anchor)
        local grip = CreateFrame("Button", nil, optionsFrame)
        grip:SetSize(35, 35)
        grip:SetPoint(anchor, optionsFrame, anchor, 0, 0)
        grip:SetFrameLevel(optionsFrame:GetFrameLevel() + 35)
        grip:EnableMouse(true)
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
        displayedAlpha = 1
        self:SetAlpha(1)
    end)
    optionsFrame:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        self:SetSize(900, 555)
    end)
    optionsFrame:SetScript("OnUpdate", function(self, elapsed)
        local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
        if speed > 0 then
            displayedAlpha = math.max(0.75, displayedAlpha - elapsed * (0.25 / fadeSeconds))
        else
            displayedAlpha = 1
        end
        if self:GetAlpha() ~= displayedAlpha then
            self:SetAlpha(displayedAlpha)
        end
    end)
    local backdrop = optionsFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    backdrop:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 2, -2)
    backdrop:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -2, 2)
    backdrop:SetColorTexture(0.12, 0.075, 0.044, 1)
    -- Use the native Blizzard bronze header, without an extra filled title band.
    -- Keep the native bronze title frame. A subtle custom divider on each
    -- side of the title adds detail without cutting through the lettering.
    for _, side in ipairs({"LEFT", "RIGHT"}) do
        local divider = optionsFrame:CreateTexture(nil, "ARTWORK")
        divider:SetSize(100, 3)
        divider:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Dividers\\Divider_Thin.png")
        divider:SetAlpha(0.65)
        if side == "LEFT" then
            divider:SetPoint("RIGHT", optionsFrame, "TOP", -80, -29)
        else
            divider:SetPoint("LEFT", optionsFrame, "TOP", 80, -29)
        end
    end

    optionsFrame:Hide()

    -- The title must render above the native top border, not underneath it.
    local titleHost = CreateFrame("Frame", nil, optionsFrame)
    titleHost:SetSize(180, 28)
    titleHost:SetPoint("BOTTOM", optionsFrame, "TOP", 0, -19)
    titleHost:SetFrameStrata("FULLSCREEN_DIALOG")
    titleHost:SetFrameLevel(borderHost:GetFrameLevel() + 31)
    local title = CreateLabel(titleHost, "Bazi UI", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleHost, "CENTER", 0, 0)
    title:SetJustifyH("CENTER")

    local close = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    -- Keep the close button inside the header border.
    close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -4, 2)
    close:SetFrameStrata("FULLSCREEN_DIALOG")
    close:SetFrameLevel(borderHost:GetFrameLevel() + 20)
    optionsFrame.baziClose = close

    local nav = CreateFrame("Frame", nil, optionsFrame)
    nav:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -49)
    local navBackground = nav:CreateTexture(nil, "BACKGROUND")
    navBackground:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, 10)
    navBackground:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, -4)
    navBackground:SetColorTexture(0.105, 0.063, 0.038, 0.96)
    nav:SetWidth(180)
    nav:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 12, 22)

    -- Small category search, kept entirely inside the existing sidebar.
    local search = CreateFrame("EditBox", nil, nav)
    search:SetPoint("TOPLEFT", nav, "TOPLEFT", 4, -2)
    search:SetSize(170, 20)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetTextInsets(27, 9, 0, 0)
    search:SetTextColor(0.96, 0.85, 0.66, 1)
    search:SetMaxLetters(50)
    local searchBackground = search:CreateTexture(nil, "BACKGROUND")
    searchBackground:SetAllPoints(search)
    searchBackground:SetColorTexture(0.10, 0.06, 0.04, 0.96)
    for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local line = search:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.67, 0.48, 0.26, 0.7)
        if edge == "TOP" then
            line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT"); line:SetHeight(1)
        elseif edge == "BOTTOM" then
            line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
        elseif edge == "LEFT" then
            line:SetPoint("TOPLEFT"); line:SetPoint("BOTTOMLEFT"); line:SetWidth(1)
        else
            line:SetPoint("TOPRIGHT"); line:SetPoint("BOTTOMRIGHT"); line:SetWidth(1)
        end
    end
    -- Hint must be a child of the EditBox: the previous sibling was hidden
    -- behind the edit box background, making the field appear empty.
    local searchIcon = search:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(15, 15)
    searchIcon:SetPoint("LEFT", search, "LEFT", 7, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(0.88, 0.73, 0.49, 0.9)
    local searchHint = CreateLabel(search, "Search...", "GameFontHighlightSmall")
    searchHint:SetPoint("LEFT", search, "LEFT", 27, 0)
    searchHint:SetTextColor(0.83, 0.72, 0.57, 0.9)
    local searchEmpty = CreateLabel(nav, "No matching categories", "GameFontHighlightSmall")
    searchEmpty:SetPoint("TOPLEFT", nav, "TOPLEFT", 9, -40)
    searchEmpty:SetTextColor(0.77, 0.65, 0.51)
    searchEmpty:Hide()
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    contentFrame = CreateFrame("Frame", nil, optionsFrame)
    contentFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 204, -49)
    contentFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 18)

    local separator = contentFrame:CreateTexture(nil, "BORDER")
    separator:SetColorTexture(0.72, 0.49, 0.25, 0.65)
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", -10, 0)
    separator:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", -10, 0)

    -- Scrollable categories, with a fixed footer and search box.
    local scrollFrame = CreateFrame("ScrollFrame", nil, nav)
    scrollFrame:SetPoint("TOPLEFT", nav, "TOPLEFT", 4, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -16, 53)
    scrollFrame:EnableMouseWheel(true)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(170, 377)
    scrollFrame:SetScrollChild(scrollChild)
    local scrollBar = CreateFrame("Slider", nil, nav)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetWidth(10)
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 3, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 3, 0)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(15)
    local barTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
    barTrack:SetAllPoints(scrollBar)
    barTrack:SetColorTexture(0.38, 0.27, 0.16, 0.85)
    local barThumb = scrollBar:CreateTexture(nil, "OVERLAY")
    barThumb:SetSize(8, 40)
    barThumb:SetColorTexture(0.88, 0.67, 0.37, 1)
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

    CreateNavigationButton(scrollChild, "General", "General", 0)
    CreateNavigationButton(scrollChild, "Quality of Life", "Quality of Life", -29)
    CreateNavigationButton(scrollChild, "Profiles", "Profiles", -58)
    CreateNavigationButton(scrollChild, "UnitFrames", "UnitFrames", -87)
    CreateNavigationButton(scrollChild, "Nameplates", "Nameplates", -116)
    CreateNavigationButton(scrollChild, "ActionBars", "ActionBars", -145)
    CreateNavigationButton(scrollChild, "Chat", "Chat", -174)
    CreateNavigationButton(scrollChild, "Quest", "Quest", -203)
    CreateNavigationButton(scrollChild, "Gathering", "Gathering", -232)
    CreateNavigationButton(scrollChild, "Minimap", "Minimap", -261)
    CreateNavigationButton(scrollChild, "Tooltip", "Tooltip", -290)
    CreateNavigationButton(scrollChild, "Combat", "Combat", -319)
    CreateNavigationButton(scrollChild, "BugTab", "BugTab", -348)

    local historyButton = CreateFrame("Button", nil, nav)
    historyButton:SetSize(170, 18)
    historyButton:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 4, 27)
    local historyLabel = CreateLabel(historyButton, "Version History  |  v" .. (addon.version or "0.1.1"), "GameFontHighlightSmall")
    historyLabel:SetPoint("LEFT", historyButton, "LEFT", 8, 0)
    historyLabel:SetTextColor(0.62, 0.58, 0.53)
    historyButton:SetScript("OnClick", function() ShowPage("Version History") end)
    historyButton:SetScript("OnEnter", function() historyLabel:SetTextColor(0.92, 0.80, 0.60) end)
    historyButton:SetScript("OnLeave", function() historyLabel:SetTextColor(0.62, 0.58, 0.53) end)
    local helpLabel = CreateLabel(nav, "Type /bazi help for commands", "GameFontHighlightSmall")
    helpLabel:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 12, 8)
    helpLabel:SetTextColor(0.64, 0.59, 0.53)

    local navigationOrder = {"General", "Quality of Life", "Profiles", "UnitFrames", "Nameplates", "ActionBars", "Chat", "Quest", "Gathering", "Minimap", "Tooltip", "Combat", "BugTab"}
    local function UpdateSearch()
        local query = string.lower(search:GetText() or "")
        local shown = 0
        searchHint:SetShown(query == "" and not search:HasFocus())
        for _, name in ipairs(navigationOrder) do
            local button = navButtons[name]
            if string.find(string.lower(name), query, 1, true) then
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -shown * 29)
                button:Show()
                shown = shown + 1
            else
                button:Hide()
            end
        end
        scrollChild:SetHeight(math.max(1, shown * 29))
        scrollBar:SetValue(0)
        RefreshScroll()
        searchEmpty:SetShown(shown == 0)
        historyButton:SetShown(query == "")
        helpLabel:SetShown(query == "")
    end
    search:SetScript("OnTextChanged", UpdateSearch)
    search:SetScript("OnEditFocusGained", UpdateSearch)
    search:SetScript("OnEditFocusLost", UpdateSearch)
    UpdateSearch()

    CreateGeneralPage()
    CreateVersionHistoryPage()
    CreatePlaceholderPage("Quality of Life", "Quality-of-life module settings will be added here.")
    CreatePlaceholderPage("Profiles", "Profile management is not implemented yet. Your current settings are preserved.")
    CreatePlaceholderPage("UnitFrames")
    CreatePlaceholderPage("Nameplates")
    CreatePlaceholderPage("ActionBars")
    CreatePlaceholderPage("Chat")
    CreatePlaceholderPage("Quest")
    CreatePlaceholderPage("Gathering")
    CreatePlaceholderPage("Minimap")
    CreatePlaceholderPage("Tooltip")
    CreatePlaceholderPage("Combat")
    CreatePlaceholderPage("BugTab")

    ShowPage("General")
end

function addon.Options:Initialize()
    -- Created on first open.
end
