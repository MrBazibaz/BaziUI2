local addon, D = BaziUI, BaziUI.Dashboard
local size, gap = 27, 4
local holder, window, viewport, card, items, sample
local buttons = {}
local driver = CreateFrame("Frame")
driver:Hide()

local function hideHolder()
    if not holder then return end
    if holder.hideInCombat then
        UnregisterStateDriver(holder, "visibility")
        holder.hideInCombat = nil
    end
    holder:Hide()
end

local function createButton()
    -- Keep the secure buttons outside Dashboard's frame hierarchy so the
    -- Dashboard can still resize and update its other cards during combat.
    local button = CreateFrame("Button", nil, holder, "SecureActionButtonTemplate")
    button:SetSize(size, size)
    button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    addon.Theme:CreateFrameBorder(button, button, button)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", function(self)
        local side = D.Settings().questItemSide
        GameTooltip:SetOwner(self, side == "top" and "ANCHOR_TOP" or side == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetText("Quest item preview") end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    return button
end

local function sync()
    if InCombatLockdown() then return end
    if not items or not window:IsVisible() then
        hideHolder()
        driver:Hide()
        return
    end
    local cfg = D.Settings()
    local left, top = cfg.questItemSide == "left", cfg.questItemSide == "top"
    local point, x, y, across
    if top then
        local edge, width, upper = window:GetLeft(), window:GetWidth(), window:GetTop()
        if not (edge and width and upper) then return end
        point, x, y = "BOTTOM", edge + width / 2, upper + gap
        across = math.max(1, math.floor((width + gap) / (size + gap)))
    else
        local viewTop, viewBottom = viewport:GetTop(), viewport:GetBottom()
        local cardTop, cardBottom = card:GetTop(), card:GetBottom()
        if not (viewTop and viewBottom and cardTop and cardBottom) or cardTop < viewBottom or cardBottom > viewTop then
            hideHolder()
            return
        end
        local edge = left and window:GetLeft() or window:GetRight()
        if not edge then return end
        point, x = left and "TOPRIGHT" or "TOPLEFT", edge + (left and -gap or gap)
        y = math.max(viewBottom + size, math.min(cardTop, viewTop))
        across = math.max(1, math.floor((y - viewBottom + gap) / (size + gap)))
    end
    local scale = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(size, size)
    end
    local strata = window:GetFrameStrata()
    if holder:GetFrameStrata() ~= strata then holder:SetFrameStrata(strata) end
    if holder:GetScale() ~= scale then holder:SetScale(scale) end
    local anchor, _, _, oldX, oldY = holder:GetPoint(1)
    if anchor ~= point or oldX ~= x or oldY ~= y then
        holder:ClearAllPoints()
        holder:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
    end
    if cfg.combat == "hide" and not holder.hideInCombat then
        RegisterStateDriver(holder, "visibility", "[combat] hide; show")
        holder.hideInCombat = true
    elseif cfg.combat ~= "hide" and holder.hideInCombat then
        UnregisterStateDriver(holder, "visibility")
        holder.hideInCombat = nil
    end
    for i, item in ipairs(items) do
        local button = buttons[i] or createButton()
        buttons[i] = button
        local itemAction = not sample and "item:" .. item.id or nil
        if button.actionItem ~= itemAction then
            button:SetAttribute("type", itemAction and "item" or nil)
            button:SetAttribute("item", itemAction)
            button.actionItem = itemAction
        end
        if button.link ~= item.link or button.texture ~= item.icon then
            button.link, button.texture = item.link, item.icon
            button.icon:SetTexture(item.icon)
            if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
        end
        local group, index = math.floor((i - 1) / across), (i - 1) % across
        local dx, dy
        if top then
            local inRow = math.min(across, #items - group * across)
            dx, dy = (index - (inRow - 1) / 2) * (size + gap), group * (size + gap)
        else
            dx, dy = group * (size + gap) * (left and -1 or 1), -index * (size + gap)
        end
        if button.side ~= point or button.x ~= dx or button.y ~= dy then
            button:ClearAllPoints()
            button:SetPoint(point, holder, point, dx, dy)
            button.side, button.x, button.y = point, dx, dy
        end
        if not button:IsShown() then button:Show() end
    end
    for i = #items + 1, #buttons do
        if buttons[i]:IsShown() then buttons[i]:Hide() end
    end
    if not holder:IsShown() then holder:Show() end
end

driver:SetScript("OnUpdate", sync)

function D.ShowQuestItems(dashboard, view, questCard, questItems, preview)
    if not window then
        dashboard:HookScript("OnHide", function()
            items = nil
            sync()
        end)
    end
    window, viewport, card, items, sample = dashboard, view, questCard, questItems, preview
    if not items and not driver:IsShown() then return end
    driver:Show()
    sync()
end
