local addon = BaziUI

addon.Theme = addon.Theme or {}

local ASSET = "Interface\\AddOns\\BaziUI\\Assets\\"

addon.Theme.colors = {
    window = {0.071, 0.055, 0.079},
    panel = {0.115, 0.087, 0.128},
    row = {0.155, 0.113, 0.166},
    field = {0.066, 0.048, 0.072},
    sidebar = {0.088, 0.065, 0.097},
    muted = {0.27, 0.19, 0.28},
    header = {0.20, 0.12, 0.19},
    headerText = {1, 0.82, 0.49},
    hudBody = {0.054, 0.039, 0.059},
    purple = { 0.34, 0.17, 0.25, 1 },
    purpleHover = { 0.43, 0.23, 0.34, 1 },
    purplePressed = { 0.26, 0.12, 0.19, 1 },
    purpleDisabled = { 0.21, 0.14, 0.17, 0.82 },
    experience = { 101 / 255, 0, 203 / 255 },
    gold = { 0.83, 0.63, 0.30, 1 },
    goldHover = { 1.00, 0.79, 0.42, 1 },
    goldPressed = { 0.60, 0.42, 0.18, 1 },
}

function addon.Theme:Paint(texture, role, alpha)
    local color = self.colors[role]
    texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

function addon.Theme:CreateCheckbox(parent)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetNormalTexture(ASSET .. "Controls\\Checkbox_Empty.png")
    check:SetCheckedTexture(ASSET .. "Controls\\Checkbox_Checked.png")
    check:SetDisabledCheckedTexture(ASSET .. "Controls\\Checkbox_Disabled.png")
    return check
end

local function Tint(texture, color)
    if texture and color then
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    end
end

function addon.Theme:ApplyWindow(frame)
    -- Warm the existing Blizzard dialog art without replacing its border.
    local warmth = frame:CreateTexture(nil, "ARTWORK", nil, -7)
    warmth:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    warmth:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    warmth:SetColorTexture(0.36, 0.21, 0.09, 0.23)
    frame.baziWarmth = warmth
    -- Forever's UIPanelDialogTemplate creates eight named border textures
    -- directly on the options frame, all in the OVERLAY layer (file ID 251963).
    -- Target those exact regions rather than backdrop or unrelated UI art.
    local pieces = {
        "TopLeft", "TopRight", "Top", "BottomLeft",
        "BottomRight", "Bottom", "Left", "Right",
    }
    local frameName = frame:GetName()
    if frameName then
        for _, suffix in ipairs(pieces) do
            local region = _G[frameName .. suffix]
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                if region.SetDesaturated then region:SetDesaturated(true) end
                region:SetVertexColor(0.95, 0.72, 0.35, 1)
            end
        end
    end
end

addon.Theme.colors.frameBorder = {0.62, 0.49, 0.30}

local dropShadows = {}

function addon.Theme:IsDropShadowEnabled(key)
    local profile = addon.db and addon.db.profile
    return not profile or not profile.dropShadows or profile.dropShadows[key] ~= false
end

function addon.Theme:SetDropShadowEnabled(key, enabled)
    local profile = addon.db.profile
    profile.dropShadows = profile.dropShadows or {}
    profile.dropShadows[key] = enabled
    for _, frame in ipairs(dropShadows[key] or {}) do frame:RefreshVisibility() end
    if key == "Chat" and addon.Chat and addon.Chat.Skin and addon.Chat.Skin.RefreshDropShadow then
        addon.Chat.Skin.RefreshDropShadow()
    end
end

local function registerDropShadow(key, frame, condition)
    function frame:RefreshVisibility()
        self:SetShown(addon.Theme:IsDropShadowEnabled(key) and (not condition or condition()))
    end
    frame:RefreshVisibility()
    dropShadows[key] = dropShadows[key] or {}
    table.insert(dropShadows[key], frame)
end

function addon.Theme:AddDropShadow(key, parent, bounds, condition)
    local chat = addon.Chat
    if not chat or not chat.Skin or not chat.Skin.BoxShadow then return end
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    frame:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1))
    function frame:SetShadowBounds(target, padding)
        local pixel = PixelUtil and PixelUtil.ConvertPixelsToUIForRegion(1, self) or 1
        local inset = 2 * pixel - (padding or 0)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", target, "TOPLEFT", inset, -inset)
        self:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -inset, inset)
    end
    frame:SetShadowBounds(bounds or parent)
    local shadow = chat.Skin.BoxShadow(frame, "bazi", "BACKGROUND")
    frame:SetScript("OnSizeChanged", function(_, width, height) shadow:Layout(width, height) end)
    frame:HookScript("OnShow", function() shadow:Layout(frame:GetSize()) end)
    registerDropShadow(key, frame, condition)
    shadow:Layout(frame:GetSize())
    return frame
end

function addon.Theme:AddPortraitDropShadow(anchor, rim)
    local frame = CreateFrame("Frame", nil, anchor)
    frame:EnableMouse(false)
    frame:SetFrameLevel(math.max(0, anchor:GetParent():GetFrameLevel() - 1))
    function frame:FitPortrait()
        local width, height = rim:GetSize()
        self:SetSize(width * 78 / 62, height * 79 / 62)
        self:SetPoint("CENTER", rim, "CENTER", 0, -height * 1.5 / 62)
    end
    frame:FitPortrait()
    local shadow = frame:CreateTexture(nil, "BACKGROUND")
    shadow:SetAllPoints()
    shadow:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Textures\\PortraitShadow.tga")
    registerDropShadow("UnitFrames", frame)
    return frame
end

function addon.Theme:CreateFrameBorder(parent, top, bottom)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", top, "TOPLEFT")
    border:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT")
    border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
    border:SetBackdropBorderColor(unpack(self.colors.frameBorder))
    return border
end

local settingsArt = ASSET .. "Settings\\"

function addon.Theme:SetSurface(texture, name, margin)
    if not texture then return end
    texture:SetTexture(settingsArt .. name .. ".png")
    local mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
    if margin and mode and texture.SetTextureSliceMargins and texture.SetTextureSliceMode then
        texture:SetTextureSliceMargins(margin, margin, margin, margin)
        texture:SetTextureSliceMode(mode)
    end
end

function addon.Theme:Surface(parent, name, margin, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
    texture:SetAllPoints(parent)
    self:SetSurface(texture, name, margin)
    return texture
end

function addon.Theme:AddSettingsDropShadow(parent)
    local shadow = CreateFrame("Frame", nil, parent)
    shadow:EnableMouse(false)
    shadow:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1))
    shadow:SetPoint("TOPLEFT", parent, "TOPLEFT", -14, 14)
    shadow:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 14, -14)
    self:Surface(shadow, "WindowShadow", 43)
    registerDropShadow("General", shadow)
end

function addon.Theme:StyleScrollThumb(thumb)
    thumb:SetSize(8, 24)
    thumb:SetTexture(settingsArt .. "Scroll.png")
end

function addon.Theme:StyleSettingsTab(button, active, hover)
    self:SetSurface(button.fill, active and "ButtonActive" or hover and "ButtonHover" or "Button", 10)
    if button.accent then button.accent:SetAlpha(0) end
    for _, edge in ipairs(button.edges or {}) do edge:SetAlpha(0) end
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(0, 0, 0, 0) end
end

function addon.Theme:CreateSettingsDropdown(parent)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    for _, region in ipairs({dropdown:GetRegions()}) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    self:Surface(dropdown, "Field", 9)
    local arrow = dropdown:CreateTexture(nil, "OVERLAY", nil, 2)
    arrow:SetSize(13, 13)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture(ASSET .. "Icons\\Icon_Down.png")
    return dropdown
end

function addon.Theme:CloseGlyph(button, size)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    icon:SetTexture(settingsArt .. "CloseGlyph.png")
    return icon
end

function addon.Theme:CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 142, height or 28)
    local close = label == "×" or label == "X"
    local margin = 10
    button:SetNormalTexture(self:Surface(button, close and "Close" or "Button", margin))
    local pressed = self:Surface(button, "ButtonPress", margin)
    pressed:SetVertexColor(0.72, 0.61, 0.67)
    button:SetPushedTexture(pressed)
    button:SetPushedTextOffset(0, -1)
    button:SetDisabledTexture(self:Surface(button, "ButtonDisabled", margin))
    -- Keep hover artwork below the caption. The native HIGHLIGHT layer draws over text.
    local hover = self:Surface(button, "ButtonHover", margin, "ARTWORK", 1)
    hover:SetAlpha(0.72)
    hover:Hide()
    button.baziHoverArt = hover
    button:HookScript("OnEnter", function(self)
        hover:SetShown(self:IsEnabled() and self:GetButtonState() ~= "PUSHED")
    end)
    button:HookScript("OnLeave", function() hover:Hide() end)
    button:HookScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then hover:Hide() end
    end)
    button:HookScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" then hover:SetShown(self:IsEnabled() and self:IsMouseOver()) end
    end)
    button:HookScript("OnDisable", function() hover:Hide() end)
    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", 6, 0)
    text:SetPoint("RIGHT", -6, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    button:SetFontString(text)
    local owner = parent
    while owner and owner ~= _G.BaziUIOptionsFrame do owner = owner:GetParent() end
    button:SetNormalFontObject(owner and GameFontHighlight or GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetDisabledFontObject(GameFontDisable)
    button:SetText(close and "" or label)
    text:SetDrawLayer("OVERLAY", 1)
    if close then self:CloseGlyph(button, 17) end
    return button
end

function addon.Theme:SetButtonActive(button, active)
    if not button then return end
    button.isActive = active
    self:SetSurface(button:GetNormalTexture(), active and "ButtonActive" or "Button", 10)
    if button.baziHoverArt then button.baziHoverArt:SetAlpha(active and 0.40 or 0.72) end
end

function addon.Theme:SkinGameMenu()
    local frame = _G.GameMenuFrame
    if not frame then return end
    -- Forever may nest menu buttons inside child frames. Walk a bounded tree.
    local function Scan(parent, depth)
        if depth > 3 then return end
        local children = { parent:GetChildren() }
        for _, child in ipairs(children) do
            if child.IsObjectType and child:IsObjectType("Button")
                and child.GetText and child:GetText() and child:GetText() ~= "" then
                addon.Commands:StyleDialogButton(child, true)
            end
            if child.GetChildren then Scan(child, depth + 1) end
        end
    end
    Scan(frame, 0)
end

function addon.Theme:Initialize()
    local frame = _G.GameMenuFrame
    if frame then
        self:AddDropShadow("Quality of Life", frame)
        frame:HookScript("OnShow", function()
            addon.Theme:SkinGameMenu()
        end)
        self:SkinGameMenu()
    end
end

function BaziUI.Theme:CreateColorSwatch(parent, read, write, prepareCancel)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(34, 24)
    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0.72, 0.52, 0.27, 1)
    local fill = button:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    function button:Refresh()
        local color = read()
        fill:SetColorTexture(color[1], color[2], color[3], 1)
    end
    button:SetScript("OnClick", function()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local color = read()
        local restore = prepareCancel and prepareCancel()
        local function apply(r, g, b)
            write({r, g, b})
            button:Refresh()
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color[1], g = color[2], b = color[3],
            swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function()
                if restore then restore(); button:Refresh() else apply(unpack(color)) end
            end,
        })
    end)
    button:Refresh()
    return button
end
