local addon = BaziUI

addon.Theme = addon.Theme or {}

-- Keep Blizzard's relief and ornaments; purple belongs on controls only.
addon.Theme.colors = {
    purple = { 0.34, 0.17, 0.25, 1 },
    purpleHover = { 0.43, 0.23, 0.34, 1 },
    purplePressed = { 0.26, 0.12, 0.19, 1 },
    purpleDisabled = { 0.21, 0.14, 0.17, 0.82 },
    gold = { 0.83, 0.63, 0.30, 1 },
    goldHover = { 1.00, 0.79, 0.42, 1 },
    goldPressed = { 0.60, 0.42, 0.18, 1 },
}

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

function addon.Theme:CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 142, height or 28)
    button:SetText(label)
    -- Forever's red artwork is baked into the native button texture.
    -- Mask its central fill, leaving the original beveled rim visible.
    local fill = button:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -6)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 6)
    fill:SetColorTexture(0.34, 0.17, 0.25, 0.96)
    button.baziPurpleFill = fill

    -- Use Blizzard's shaped button artwork, not solid color textures.
    local normal = button:GetNormalTexture()
    local pushed = button:GetPushedTexture()
    local highlight = button:GetHighlightTexture()
    local disabled = button:GetDisabledTexture()

    -- Blizzard supplies red artwork on this client. Desaturate first,
    -- otherwise red channels survive a purple vertex tint.
    for _, texture in pairs({ normal, pushed, highlight, disabled }) do
        if texture and texture.SetDesaturated then texture:SetDesaturated(true) end
    end
    if normal then Tint(normal, self.colors.gold) end
    if pushed then Tint(pushed, self.colors.goldPressed) end
    if highlight then
        highlight:SetBlendMode("ADD")
        Tint(highlight, self.colors.goldHover)
    end
    if disabled then Tint(disabled, self.colors.goldPressed) end

    -- A restrained gold bevel inside the native button silhouette.
    -- Unlike tinting all template regions, this does not darken its relief.
    local trim = {}
    local function AddTrim(a, b, ax, ay, bx, by, horizontal)
        local edge = button:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0.78, 0.56, 0.25, 0.95)
        edge:SetPoint(a, button, a, ax, ay)
        edge:SetPoint(b, button, b, bx, by)
        if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end
        trim[#trim + 1] = edge
    end
    AddTrim("TOPLEFT", "TOPRIGHT", 5, -4, -5, -4, true)
    AddTrim("BOTTOMLEFT", "BOTTOMRIGHT", 5, 4, -5, 4, true)
    AddTrim("TOPLEFT", "BOTTOMLEFT", 4, -5, 4, 5, false)
    AddTrim("TOPRIGHT", "BOTTOMRIGHT", -4, -5, -4, 5, false)
    button.baziGoldTrim = trim

    button:SetScript("OnEnter", function(self)
        self.baziPurpleFill:SetColorTexture(0.43, 0.23, 0.34, 0.96)
        if not self.isActive then Tint(self:GetNormalTexture(), addon.Theme.colors.goldHover) end
    end)
    button:SetScript("OnLeave", function(self)
        local c = self.isActive and addon.Theme.colors.purpleHover or addon.Theme.colors.purple
        self.baziPurpleFill:SetColorTexture(c[1], c[2], c[3], 0.96)
        Tint(self:GetNormalTexture(), self.isActive and addon.Theme.colors.goldHover or addon.Theme.colors.gold)
    end)

    return button
end

function addon.Theme:SetButtonActive(button, active)
    if not button then return end
    button.isActive = active
    local c = active and self.colors.purpleHover or self.colors.purple
    if button.baziPurpleFill then button.baziPurpleFill:SetColorTexture(c[1], c[2], c[3], 0.96) end
    Tint(button:GetNormalTexture(), active and self.colors.goldHover or self.colors.gold)
end

-- Visual-only skin for Blizzard Game Menu buttons. No click handlers,
-- action bindings, button dimensions or protected attributes are changed.
function addon.Theme:SkinGameMenuButton(button)
    if not button or button.baziGameMenuSkinned then return end
    button.baziGameMenuSkinned = true

    -- Overlay the red native button center without changing Blizzard button states.
    -- The text is on OVERLAY too; a negative sublevel keeps it above our fill.
    local fill = button:CreateTexture(nil, "OVERLAY", nil, -7)
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -6)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 6)
    fill:SetColorTexture(0.34, 0.17, 0.25, 1)
    button.baziGameMenuFill = fill

    local function ApplyTextColor(self)
        local label = self.GetFontString and self:GetFontString()
        if label then label:SetTextColor(0.96, 0.81, 0.59, 1) end
    end
    ApplyTextColor(button)
    button:HookScript("OnShow", ApplyTextColor)
    local function Trim(a, b, ax, ay, bx, by, horizontal)
        local edge = button:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0.78, 0.56, 0.25, 0.95)
        edge:SetPoint(a, button, a, ax, ay)
        edge:SetPoint(b, button, b, bx, by)
        if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end
    end
    Trim("TOPLEFT", "TOPRIGHT", 5, -4, -5, -4, true)
    Trim("BOTTOMLEFT", "BOTTOMRIGHT", 5, 4, -5, 4, true)
    Trim("TOPLEFT", "BOTTOMLEFT", 4, -5, 4, 5, false)
    Trim("TOPRIGHT", "BOTTOMRIGHT", -4, -5, -4, 5, false)

    local function Update(self)
        local c = self:IsMouseOver() and addon.Theme.colors.purpleHover or addon.Theme.colors.purple
        fill:SetColorTexture(c[1], c[2], c[3], 0.96)
    end
    button:HookScript("OnEnter", Update)
    button:HookScript("OnLeave", Update)
    button:HookScript("OnMouseDown", Update)
    button:HookScript("OnMouseUp", Update)
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
                self:SkinGameMenuButton(child)
            end
            if child.GetChildren then Scan(child, depth + 1) end
        end
    end
    Scan(frame, 0)
end

function addon.Theme:Initialize()
    local frame = _G.GameMenuFrame
    if frame then
        frame:HookScript("OnShow", function()
            addon.Theme:SkinGameMenu()
        end)
        self:SkinGameMenu()
    end
end
