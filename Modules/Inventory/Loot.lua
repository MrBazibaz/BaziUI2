local addon = BaziUI
local inventory = addon.Inventory
local loot, skin, preview
local nativeWidth, nativeHeight
local clearedSlots = {}
local originalAlpha, originalFonts = {}, {}
local hiddenChrome = {}
local originalPoints = {}
local qualityBorders = {}
local originalTextAlignment = {}
local qualityHooks = {}
local closeButton, closeMouseEnabled
local scrollTopInset, scrollBottomInset = 29, 3

local function anchor(region, point, relative, relativePoint, x, y, rightInset)
    local oldPoint, oldRelative, oldRelativePoint, oldX, oldY = region:GetPoint(1)
    local matchesFirst = oldPoint == point and oldRelative == relative
        and oldRelativePoint == relativePoint and oldX == x and oldY == y
    if matchesFirst and not rightInset and region:GetNumPoints() == 1 then return end
    if matchesFirst and rightInset and region:GetNumPoints() == 2 then
        local secondPoint, secondRelative, secondRelativePoint, secondX, secondY = region:GetPoint(2)
        if secondPoint == "BOTTOMRIGHT" and secondRelative == relative
            and secondRelativePoint == "BOTTOMRIGHT" and secondX == -rightInset and secondY == scrollBottomInset then
            return
        end
    end
    if not originalPoints[region] then
        local points = {}
        for index = 1, region:GetNumPoints() or 0 do
            points[index] = {region:GetPoint(index)}
        end
        originalPoints[region] = points
    end
    region:ClearAllPoints()
    region:SetPoint(point, relative, relativePoint, x, y)
    if rightInset then
        region:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", -rightInset, scrollBottomInset)
    end
end

local function resizeLoot()
    local scroll = loot.ScrollBox
    if not scroll or not loot.CalculateElementsHeight or not loot.GetPanelMaxHeight then return end
    local rows = loot:CalculateElementsHeight()
    local top = scroll.GetUpperPadding and scroll:GetUpperPadding() or 6
    local bottom = scroll.GetLowerPadding and scroll:GetLowerPadding() or 6
    local height = math.min(loot:GetPanelMaxHeight(), math.ceil(rows + top + bottom + scrollTopInset + scrollBottomInset))
    if loot:GetHeight() ~= height then loot:SetHeight(height) end
end

local function hideArt(region)
    if not region or not region.GetAlpha or region:GetAlpha() == 0 then return end
    if originalAlpha[region] == nil then originalAlpha[region] = region:GetAlpha() end
    region:SetAlpha(0)
end

local function hideChrome(region)
    if not region or not region.IsShown or not region:IsShown() then return end
    hiddenChrome[region] = true
    region:Hide()
end

local function font(label, offset)
    if not label or not label.GetFont then return end
    if not originalFonts[label] then originalFonts[label] = {label:GetFont()} end
    local file = GameFontNormal:GetFont()
    addon.Typography.Apply(label, "Inventory:Items", file, addon.Typography.BaseSize() + (offset or 0), "", true)
end

local function styleRow(row, incoming)
    hideChrome(row.QualityText)
    hideChrome(row.QualityStripe)
    if row.QualityText and row.Init and not qualityHooks[row] then
        qualityHooks[row] = true
        hooksecurefunc(row, "Init", function(self)
            if skin:IsShown() then
                hideChrome(self.QualityText)
                hideChrome(self.QualityStripe)
            end
        end)
    end
    font(row.Text)
    local item = row.Item
    if not item then return end
    anchor(item, "LEFT", row, "LEFT", 5, 0)
    if row.Text then
        originalTextAlignment[row.Text] = originalTextAlignment[row.Text] or row.Text:GetJustifyV()
        row.Text:SetJustifyV("MIDDLE")
        anchor(row.Text, "LEFT", item, "RIGHT", 8, 0)
    end
    local data = row.GetElementData and row:GetElementData()
    local isIncoming = incoming and data and data.slotIndex == incoming.slot
    if addon.EquipmentAdvisor then
        local index = data and data.slotIndex
        local link = not isIncoming and type(index) == "number" and addon.Adventure.Call(GetLootSlotLink, index)
        addon.EquipmentAdvisor.PaintIndicator(row, link, "loot", "RIGHT", -6, 0)
    end
    if isIncoming and not row.baziCleanupPrice then
        row.baziCleanupPrice = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.baziCleanupPrice:SetPoint("RIGHT", -8, 0)
        row.baziCleanupAccent = row:CreateTexture(nil, "BACKGROUND", nil, 2)
        row.baziCleanupAccent:SetAllPoints()
        row.baziCleanupAccent:SetColorTexture(0.78, 0.48, 0.12, 0.30)
    end
    if row.baziCleanupPrice then
        row.baziCleanupPrice:SetShown(not not isIncoming)
        row.baziCleanupAccent:SetShown(not not isIncoming)
        if isIncoming then
            inventory.GeneralFont(row.baziCleanupPrice, -2, "OUTLINE")
            row.baziCleanupPrice:SetText(inventory.Money(incoming.total))
            if row.Text then row.Text:SetPoint("RIGHT", row.baziCleanupPrice, "LEFT", -8, 0) end
        end
    end
    local quality = data and data.quality
    local color = row.QualityText and ITEM_QUALITY_COLORS[quality]
    local border = qualityBorders[row]
    if color and not border then
        border = item:CreateTexture(nil, "OVERLAY", nil, 2)
        border:SetAllPoints()
        border:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziActionGold.tga")
        border:SetDesaturated(true)
        border:SetAlpha(0.78)
        qualityBorders[row] = border
    end
    if border then border:SetShown(color ~= nil) end
    if color then
        border:SetVertexColor(color.r, color.g, color.b)
        hideArt(item.IconBorder)
    end
end

function inventory.RefreshLoot()
    local db = inventory.Settings()
    local enabled = db.enabled and db.lootSkin
    if preview and preview:IsShown() then
        preview:ApplyStyle()
    end
    if not loot then return end
    skin:SetShown(enabled)
    skin.title:SetShown(enabled)
    if not enabled then
        if nativeWidth then loot:SetSize(nativeWidth, nativeHeight); nativeWidth, nativeHeight = nil, nil end
        for _, border in pairs(qualityBorders) do border:Hide() end
        if loot.ScrollBox and loot.ScrollBox.ForEachFrame then
            loot.ScrollBox:ForEachFrame(function(row)
                if row.baziAdvisor then row.baziAdvisor:Hide() end
                if row.baziCleanupPrice then
                    row.baziCleanupPrice:Hide()
                    row.baziCleanupAccent:Hide()
                end
            end)
        end
        for label, alignment in pairs(originalTextAlignment) do label:SetJustifyV(alignment) end
        wipe(originalTextAlignment)
        for region in pairs(hiddenChrome) do region:Show() end
        wipe(hiddenChrome)
        for region, alpha in pairs(originalAlpha) do region:SetAlpha(alpha) end
        for label, values in pairs(originalFonts) do label:SetFont(unpack(values)) end
        wipe(originalAlpha)
        wipe(originalFonts)
        for region, points in pairs(originalPoints) do
            region:ClearAllPoints()
            for _, point in ipairs(points) do region:SetPoint(unpack(point, 1, 5)) end
        end
        wipe(originalPoints)
        if closeButton then
            closeButton:EnableMouse(closeMouseEnabled)
            closeButton = nil
        end
        return
    end
    if loot:IsShown() then
        if not nativeWidth then nativeWidth, nativeHeight = loot:GetSize() end
        loot:SetWidth(db.lootWidth)
        anchor(loot, "TOP", inventory.LootAnchor(), "TOP", 0, 0)
        local provider = loot.ScrollBox and loot.ScrollBox.GetDataProvider and loot.ScrollBox:GetDataProvider()
        if provider and provider.RemoveByPredicate and next(clearedSlots) then
            provider:RemoveByPredicate(function(element) return clearedSlots[element.slotIndex] end)
            wipe(clearedSlots)
        end
        resizeLoot()
    end

    hideChrome(loot.NineSlice)
    hideChrome(loot.Bg)
    hideChrome(_G.LootFrameBg)
    hideChrome(loot.Background)
    hideChrome(loot.Inset)
    hideChrome(loot.TitleContainer)
    hideChrome(_G.LootFrameTitleText)
    for _, region in ipairs({loot:GetRegions()}) do
        if region:IsObjectType("Texture") then hideArt(region) end
    end
    local title = loot.TitleContainer and loot.TitleContainer.TitleText or loot.TitleText or loot.Title
    hideArt(title)
    for _, region in ipairs({loot:GetRegions()}) do
        if region:IsObjectType("FontString") and region:GetText() == ITEMS then hideArt(region) end
    end
    local button = loot.ClosePanelButton or loot.CloseButton
        or (loot.TitleContainer and loot.TitleContainer.CloseButton) or _G.LootFrameCloseButton
    if button then
        if not closeButton then
            closeButton = button
            closeMouseEnabled = button:IsMouseEnabled()
            button:EnableMouse(false)
        end
        hideChrome(button)
    end
    inventory.GeneralFont(skin.title, 0, "OUTLINE")
    skin.fill:SetColorTexture(0.045, 0.026, 0.012, db.lootOpacity / 100)
    skin.header:SetColorTexture(addon.Headers.Fill("loot", inventory.HeaderColor()))
    skin.title:SetTextColor(addon.Headers.Text("loot", 1, 0.82, 0.49))
    skin.border:SetShown(not db.removeBorder)

    local scroll = loot.ScrollBox
    local incoming = inventory.CleanupLootTarget and inventory.CleanupLootTarget()
    local function style(row) styleRow(row, incoming) end
    if scroll then
        local scrollbarVisible = loot.ScrollBar and loot.ScrollBar:IsShown()
        anchor(scroll, "TOPLEFT", loot, "TOPLEFT", 3, -scrollTopInset, scrollbarVisible and 15 or 3)
    end
    if scroll and scroll.ForEachFrame then
        scroll:ForEachFrame(style)
    elseif scroll and scroll.ScrollTarget then
        for _, row in ipairs({scroll.ScrollTarget:GetChildren()}) do style(row) end
    end
end

local refreshQueued = false
local function queueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if loot and loot:IsShown() then inventory.RefreshLoot() end
    end)
end

local function install()
    if loot or not LootFrame or not addon.db then return end
    loot = LootFrame
    skin = CreateFrame("Frame", nil, loot)
    skin:SetAllPoints()
    skin:SetFrameLevel(math.max(0, loot:GetFrameLevel() - 1))
    skin:EnableMouse(false)
    skin:Hide()
    skin.fill = skin:CreateTexture(nil, "BACKGROUND")
    skin.fill:SetPoint("TOPLEFT", 3, -3)
    skin.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    skin.header = skin:CreateTexture(nil, "ARTWORK")
    skin.header:SetPoint("TOPLEFT", 3, -3)
    skin.header:SetPoint("TOPRIGHT", -3, -3)
    skin.header:SetHeight(26)
    local dismiss = inventory.Button(skin, "×", 25, CloseLoot)
    dismiss:SetPoint("TOPRIGHT", -5, -4)
    dismiss:SetFrameLevel(loot:GetFrameLevel() + 5)
    local dragHeader = CreateFrame("Frame", nil, skin)
    dragHeader:SetPoint("TOPLEFT", skin.header, "TOPLEFT")
    dragHeader:SetPoint("BOTTOMRIGHT", skin.header, "BOTTOMRIGHT", -33, 0)
    dragHeader:SetFrameLevel(loot:GetFrameLevel() + 4)
    dragHeader:EnableMouse(true)
    dragHeader:RegisterForDrag("LeftButton")
    dragHeader:SetScript("OnDragStart", inventory.StartLootDrag)
    dragHeader:SetScript("OnDragStop", inventory.StopLootDrag)
    dragHeader:SetScript("OnHide", inventory.StopLootDrag)
    skin.title = skin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skin.title:SetPoint("CENTER", skin.header, "CENTER")
    skin.title:Hide()
    skin.title:SetText(ITEMS or "Items")
    skin.title:SetTextColor(1, 0.82, 0.49)
    skin.border = addon.Theme:CreateFrameBorder(skin, skin, skin)
    addon.Theme:AddDropShadow("Inventory", skin, skin.border)
    loot:HookScript("OnShow", function()
        if inventory.Settings().lootSkin then inventory.ResetLootPosition() end
        inventory.RefreshLoot()
        queueRefresh()
    end)
    loot:HookScript("OnHide", function()
        if inventory.RefreshCleanup then inventory.RefreshCleanup() end
        if inventory.RefreshRolls then inventory.RefreshRolls() end
    end)
    if loot.Open then
        hooksecurefunc(loot, "Open", function()
            if loot:IsShown() then inventory.RefreshLoot() end
        end)
    end
    if loot.ScrollBox and loot.ScrollBox.Update then
        hooksecurefunc(loot.ScrollBox, "Update", queueRefresh)
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "LOOT_OPENED", "LOOT_SLOT_CHANGED", "LOOT_SLOT_CLEARED", "GET_ITEM_INFO_RECEIVED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, slot)
    install()
    if event == "LOOT_OPENED" then wipe(clearedSlots)
    elseif event == "LOOT_SLOT_CLEARED" and slot then clearedSlots[slot] = true end
    queueRefresh()
    if event == "LOOT_OPENED" then
        C_Timer.After(0, function()
            if inventory.RefreshCleanup then inventory.RefreshCleanup() end
            if inventory.RefreshRolls then inventory.RefreshRolls() end
        end)
    end
end)

function inventory.VisibleLoot()
    if preview and preview:IsShown() then return preview end
    local db = inventory.Settings()
    if db.enabled and db.lootSkin and loot and loot:IsShown() then return loot end
end

function inventory.ToggleLootPreview()
    if preview and preview:IsShown() then preview:Hide(); return false end
    if not preview then
        preview = inventory.Window("BaziUILootPlacement", "Items", 425, 106, nil, nil, "lootOpacity")
        preview.lootLinked = true
        preview:SetFrameStrata("FULLSCREEN_DIALOG")
        preview.headerStyleKey = "loot"
        local row = inventory.Label(preview)
        row:SetPoint("TOPLEFT", 13, -39)
        row:SetText("Test Loot   " .. inventory.Money(1250))
        row:SetTextColor(1, 0.82, 0.49)
        inventory.GeneralFont(row, 0)
        preview:SetScript("OnHide", function()
            inventory.CloseCleanupPreview()
            inventory.CloseRollPreview()
        end)
    end
    inventory.ResetLootPosition()
    preview:Show()
    inventory.RefreshLoot()
    inventory.OpenCleanup("preview")
    inventory.OpenRolls(true)
    return true
end
