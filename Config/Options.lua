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
    line:SetTexture(ASSET .. "Dividers\\Divider_Gem.png")
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
    panelArt:SetTexture(ASSET .. "Frames\\Panel_Dark_Tile.png")
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
    rowArt:SetTexture(ASSET .. "Frames\\Panel_Dark_Tile.png")
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
    thumb:SetTexture(ASSET .. "Sliders\\Gem_Handle.png")
    slider:SetThumbTexture(thumb)
    local progress = slider:CreateTexture(nil, "BORDER")
    progress:SetPoint("LEFT", track, "LEFT", 0, 0)
    progress:SetHeight(7)
    progress:SetTexture(ASSET .. "Sliders\\Slider_Fill.png")
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
    CreateSection(introPanel, "REALM CONFIGURATION", -14)
    local intro = CreateLabel(page, "Make Azeroth yours. Fine-tune your interface.", "GameFontHighlightSmall")
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

local function CreateNavigationButton(parent, name, label, y)
    -- Custom flat navigation: the active page gets purple, not every button.
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(170, 34)
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
    local emblemHost = CreateFrame("Frame", nil, optionsFrame)
    emblemHost:SetSize(48, 48)
    -- Measured portrait-corner atlas bounds: x=425.89..520.89, y=698.50..793.50.\n    -- Relative to options top-left, the actual centre is (+34.5, -31.5).\n    emblemHost:SetPoint("CENTER", optionsFrame, "TOPLEFT", 34.5, -31.5)
    emblemHost:SetFrameLevel(borderHost:GetFrameLevel() + 5)
    local emblem = emblemHost:CreateTexture(nil, "ARTWORK")
    emblem:SetAllPoints(emblemHost)
    emblem:SetTexture(ASSET .. "Icons\\BaziUI_Emblem_256.png")

    optionsFrame:SetSize(900, 555)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    -- Ease into 75% opacity during movement; restore instantly on stopping.
    local displayedAlpha = 1
    local fadeSeconds = 0.65
    optionsFrame:SetScript("OnShow", function(self)
        displayedAlpha = 1
        self:SetAlpha(1)
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
    local header = optionsFrame:CreateTexture(nil, "BORDER")
    header:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 3, -3)
    header:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -3, -3)
    header:SetHeight(48)
    header:SetColorTexture(0.22, 0.12, 0.065, 0.98)
    local headerLine = optionsFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 8, -56)
    headerLine:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -8, -56)
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.76, 0.55, 0.28, 0.75)
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

    local title = CreateLabel(optionsFrame, "Bazi UI", "GameFontNormal")
    title:SetPoint("TOP", optionsFrame, "TOP", 0, -27)
    title:SetFontObject("GameFontNormalLarge")
    title:SetJustifyH("CENTER")

    local close = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    -- Inset the close button from the outer metal edge into the header.\n    close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -13, -13)

    local nav = CreateFrame("Frame", nil, optionsFrame)
    nav:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -78)
    local navBackground = nav:CreateTexture(nil, "BACKGROUND")
    navBackground:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, 10)
    navBackground:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, -4)
    navBackground:SetColorTexture(0.105, 0.063, 0.038, 0.96)
    nav:SetSize(180, 430)

    contentFrame = CreateFrame("Frame", nil, optionsFrame)
    contentFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 204, -78)
    contentFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 18)

    local separator = contentFrame:CreateTexture(nil, "BORDER")
    separator:SetColorTexture(0.72, 0.49, 0.25, 0.65)
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", -10, 0)
    separator:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", -10, 0)

    CreateNavigationButton(nav, "General", "General", -8)
    CreateNavigationButton(nav, "UnitFrames", "UnitFrames", -45)
    CreateNavigationButton(nav, "Nameplates", "Nameplates", -82)
    CreateNavigationButton(nav, "ActionBars", "ActionBars", -119)
    CreateNavigationButton(nav, "Chat", "Chat", -156)
    CreateNavigationButton(nav, "Quest", "Quest", -193)
    CreateNavigationButton(nav, "Gathering", "Gathering", -230)
    CreateNavigationButton(nav, "Minimap", "Minimap", -267)
    CreateNavigationButton(nav, "Tooltip", "Tooltip", -304)
    CreateNavigationButton(nav, "Combat", "Combat", -341)
    CreateNavigationButton(nav, "BugTab", "BugTab", -378)

    CreateGeneralPage()
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
