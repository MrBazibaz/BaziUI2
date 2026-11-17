local addon = BaziUI

addon.Theme = addon.Theme or {}

-- Keep Blizzard's relief and ornaments; purple belongs on controls only.
addon.Theme.colors = {
    purple = { 0.29, 0.12, 0.48, 1 },
    purpleHover = { 0.39, 0.19, 0.61, 1 },
    purplePressed = { 0.20, 0.08, 0.34, 1 },
    purpleDisabled = { 0.18, 0.13, 0.23, 0.82 },
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
    -- Gold trim on all four sides, retaining the native beveled frame.
    local edges = {}
    local function AddEdge(a, b, ax, ay, bx, by, horizontal)
        local e = frame:CreateTexture(nil, "OVERLAY")
        e:SetColorTexture(0.70, 0.48, 0.20, 0.86)
        e:SetPoint(a, frame, a, ax, ay)
        e:SetPoint(b, frame, b, bx, by)
        if horizontal then e:SetHeight(2) else e:SetWidth(2) end
        edges[#edges + 1] = e
    end
    AddEdge("TOPLEFT", "TOPRIGHT", 5, -4, -5, -4, true)
    AddEdge("BOTTOMLEFT", "BOTTOMRIGHT", 5, 4, -5, 4, true)
    AddEdge("TOPLEFT", "BOTTOMLEFT", 4, -5, 4, 5, false)
    AddEdge("TOPRIGHT", "BOTTOMRIGHT", -4, -5, -4, 5, false)
    frame.baziGoldEdges = edges
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
    if normal then Tint(normal, self.colors.gold) end
    if pushed then Tint(pushed, self.colors.goldPressed) end
    if highlight then
        highlight:SetBlendMode("ADD")
        Tint(highlight, self.colors.goldHover)
    end
    if disabled then Tint(disabled, self.colors.goldPressed) end

    button:SetScript("OnEnter", function(self)
        self.baziPurpleFill:SetColorTexture(0.39, 0.19, 0.61, 0.96)
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

function addon.Theme:Initialize()
end
