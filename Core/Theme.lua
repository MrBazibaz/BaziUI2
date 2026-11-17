local addon = BaziUI

addon.Theme = addon.Theme or {}

-- Keep Blizzard's relief and ornaments; purple belongs on controls only.
addon.Theme.colors = {
    purple = { 0.29, 0.12, 0.48, 1 },
    purpleHover = { 0.39, 0.19, 0.61, 1 },
    purplePressed = { 0.20, 0.08, 0.34, 1 },
    purpleDisabled = { 0.18, 0.13, 0.23, 0.82 },
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
    -- Keep the original rim texture; add subtle bronze accents.
    local top = frame:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(0.68, 0.47, 0.20, 0.85)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -4)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -4)
    top:SetHeight(1)
    local bottom = frame:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(0.68, 0.47, 0.20, 0.85)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 4)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 4)
    bottom:SetHeight(1)
    frame.baziGoldEdges = { top, bottom }
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
    fill:SetColorTexture(0.29, 0.12, 0.48, 0.96)
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
    if normal then Tint(normal, self.colors.purple) end
    if pushed then Tint(pushed, self.colors.purplePressed) end
    if highlight then
        highlight:SetBlendMode("ADD")
        Tint(highlight, self.colors.purpleHover)
    end
    if disabled then Tint(disabled, self.colors.purpleDisabled) end

    button:SetScript("OnEnter", function(self)
        self.baziPurpleFill:SetColorTexture(0.39, 0.19, 0.61, 0.96)
        if not self.isActive then Tint(self:GetNormalTexture(), addon.Theme.colors.purpleHover) end
    end)
    button:SetScript("OnLeave", function(self)
        local c = self.isActive and addon.Theme.colors.purpleHover or addon.Theme.colors.purple
        self.baziPurpleFill:SetColorTexture(c[1], c[2], c[3], 0.96)
        Tint(self:GetNormalTexture(), self.isActive and addon.Theme.colors.purpleHover or addon.Theme.colors.purple)
    end)

    return button
end

function addon.Theme:SetButtonActive(button, active)
    if not button then return end
    button.isActive = active
    local c = active and self.colors.purpleHover or self.colors.purple
    if button.baziPurpleFill then button.baziPurpleFill:SetColorTexture(c[1], c[2], c[3], 0.96) end
    Tint(button:GetNormalTexture(), active and self.colors.purpleHover or self.colors.purple)
end

function addon.Theme:Initialize()
end
