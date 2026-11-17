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
    -- Warm the existing Blizzard dialog art without replacing its border.\n    local warmth = frame:CreateTexture(nil, "BACKGROUND", nil, 2)\n    warmth:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)\n    warmth:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)\n    warmth:SetColorTexture(0.36, 0.21, 0.09, 0.32)\n    frame.baziWarmth = warmth
end

function addon.Theme:CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 142, height or 28)
    button:SetText(label)

    -- Use Blizzard's shaped button artwork, not solid color textures.
    local normal = button:GetNormalTexture()
    local pushed = button:GetPushedTexture()
    local highlight = button:GetHighlightTexture()
    local disabled = button:GetDisabledTexture()

    -- Blizzard supplies red artwork on this client. Desaturate first,\n    -- otherwise red channels survive a purple vertex tint.\n    for _, texture in ipairs({ normal, pushed, highlight, disabled }) do\n        if texture and texture.SetDesaturated then texture:SetDesaturated(true) end\n    end\n    if normal then Tint(normal, self.colors.purple) end
    if pushed then Tint(pushed, self.colors.purplePressed) end
    if highlight then
        highlight:SetBlendMode("ADD")
        Tint(highlight, self.colors.purpleHover)
    end
    if disabled then Tint(disabled, self.colors.purpleDisabled) end

    button:SetScript("OnEnter", function(self)
        if not self.isActive then Tint(self:GetNormalTexture(), addon.Theme.colors.purpleHover) end
    end)
    button:SetScript("OnLeave", function(self)
        Tint(self:GetNormalTexture(), self.isActive and addon.Theme.colors.purpleHover or addon.Theme.colors.purple)
    end)

    return button
end

function addon.Theme:SetButtonActive(button, active)
    if not button then return end
    button.isActive = active
    Tint(button:GetNormalTexture(), active and self.colors.purpleHover or self.colors.purple)
end

function addon.Theme:Initialize()
end
