local inventory = BaziUI.Inventory
local frame, caption, search, content, viewport, scrollBar, guildTabs, viewToggle, wallet
local bagToggle, bagStrip
local mode, atBank, atGuild = "bags", false, false
local cells, headings, dividers, known, knownSlots, fresh = {}, {}, {}, {}, {}, {}
local draggedCategory, draggingItem
local feedingPet, targetingItem, targetRefreshQueued = false, false, false
local feedPetSpell = 6991
local isCurrentSpell = C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
local canPetEatItem = C_PetInfo and C_PetInfo.CanPetEatItem
local container = C_Container
local slotAtlas = "UI-HUD-ActionBar-IconFrame"
local emptyIcon = "Interface\\Icons\\INV_Misc_Bag_08"
local recentDuration = 120
local bagInset, scrollbarSpace = 8, 18
local function slotKey(item) return item.bag .. ":" .. item.slot end
local sortBags = container.SortBags or SortBags
local sortBank = container.SortBankBags or SortBankBags
if container.SortBank and Enum and Enum.BankType and Enum.BankType.Character then
    sortBank = function() container.SortBank(Enum.BankType.Character) end
end

local function updateCharacter()
    local guid = UnitGUID("player")
    if not guid then return end
    local db = BaziUI.db
    db.inventoryCharacters = db.inventoryCharacters or {}
    local used, total = 0, 0
    for _, bag in ipairs(inventory.BagIDs(true)) do
        local slots = container.GetContainerNumSlots(bag)
        total = total + slots
        used = used + slots - (container.GetContainerNumFreeSlots(bag) or 0)
    end
    db.inventoryCharacters[guid] = {
        name = UnitName("player"), realm = GetRealmName(),
        copper = GetMoney(), used = used, total = total,
    }
    if wallet then wallet.text:SetText(inventory.Money(GetMoney())) end
end

local function itemsForView()
    local items = {}
    if mode == "guild" then
        local tab = GetCurrentGuildBankTab()
        if not tab or tab < 1 then return items end
        for slot = 1, (MAX_GUILDBANK_SLOTS_PER_TAB or 98) do
            local link = GetGuildBankItemLink(tab, slot)
            if link then
                local icon, count, locked = GetGuildBankItemInfo(tab, slot)
                local name, _, quality, _, _, _, _, _, _, _, _, class = inventory.GetItemInfo(link)
                items[#items + 1] = {hyperlink = link, itemID = tonumber(link:match("item:(%d+)")),
                    iconFileID = icon, stackCount = count, isLocked = locked, name = name,
                    quality = quality, class = class, tab = tab, slot = slot}
            else
                items[#items + 1] = {tab = tab, slot = slot, empty = true}
            end
        end
        return items
    end
    local ids = inventory.BagIDs(true)
    if mode == "bank" then
        local index = Enum and Enum.BagIndex
        ids = {}
        if index and index.CharacterBankTab_1 then
            for tab = 1, 9 do
                local bag = index["CharacterBankTab_" .. tab]
                if bag then ids[#ids + 1] = bag end
            end
        else
            ids[1] = index and index.Bank or BANK_CONTAINER or -1
            for bag = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7) do
                ids[#ids + 1] = bag
            end
        end
    end
    local emptyByKind = {}
    for _, bag in ipairs(ids) do
        local _, family = container.GetContainerNumFreeSlots(bag)
        local index = Enum and Enum.BagIndex
        local kind = index and index.ReagentBag == bag and "reagent"
            or index and index.Keyring == bag and "keys" or family or 0
        for slot = 1, container.GetContainerNumSlots(bag) do
            local item = inventory.Item(bag, slot)
            if item then
                items[#items + 1] = item
            else
                local stack = emptyByKind[kind]
                if not stack then
                    local texture
                    if kind ~= 0 and container.ContainerIDToInventoryID and bag > 0 then
                        local inv = container.ContainerIDToInventoryID(bag)
                        if inv and inv > 0 then texture = GetInventoryItemTexture("player", inv) end
                    end
                    texture = texture or (kind == "reagent" and "Interface\\Icons\\INV_Misc_Herb_19")
                        or (kind == "keys" and "Interface\\Icons\\INV_Misc_Key_03")
                        or ((kind == 1 or kind == 2) and "Interface\\Icons\\INV_Misc_Quiver_09") or emptyIcon
                    stack = {bag = bag, slot = slot, empty = true, stackCount = 0, iconFileID = texture, kind = kind}
                    emptyByKind[kind] = stack
                    items[#items + 1] = stack
                end
                stack.stackCount = stack.stackCount + 1
            end
        end
    end
    return items
end

local function groupFor(item, db)
    if item.empty then return "Empty" end
    local recent = mode == "bags" and fresh[slotKey(item)]
    if db.flash and recent and recent.id == item.itemID and GetTime() - recent.time < recentDuration then
        return "Recent"
    end
    local custom = db.assignments[item.itemID]
    if custom then return custom end
    if item.itemID == 6948 then return "Hearthstone" end
    if item.quality == 0 then return "Junk" end
    local class = item.class
    if class == 12 or (item.bag and container.GetContainerItemQuestInfo
        and (container.GetContainerItemQuestInfo(item.bag, item.slot) or {}).isQuestItem) then return "Quest" end
    if class == 6 then return "Projectile" end
    if class == 1 then return "Bags" end
    if class == 11 then return "Quivers" end
    if class == 13 then return "Keys" end
    if class == 5 then return "Spell Reagents" end
    if class == 9 then return "Recipes" end
    if class == 15 then return "Miscellaneous" end
    if class == 0 then return "Consumables" end
    if class == 2 or class == 4 then return "Equipment" end
    if class == 7 then return "Trade Goods" end
    return "Other"
end

local function pickup(item)
    if not item or item.isLocked then return end
    if item.tab then PickupGuildBankItem(item.tab, item.slot)
    else container.PickupContainerItem(item.bag, item.slot) end
end

local function hasItemTarget()
    return (SpellCanTargetItem and SpellCanTargetItem()) or (SpellCanTargetItemID and SpellCanTargetItemID())
end

local function acceptsTarget(item, feeding)
    if not item or item.empty or item.tab or item.isLocked or not item.itemID then return false end
    if feeding then return canPetEatItem and canPetEatItem(item.itemID) end
    if not (ItemLocation and C_Item) then return false end
    local location = ItemLocation:CreateFromBagAndSlot(item.bag, item.slot)
    return (C_Item.DoesItemMatchSpellItemCondition and C_Item.DoesItemMatchSpellItemCondition(location))
        or (C_Item.DoesItemMatchTargetEnchantingSpell and C_Item.DoesItemMatchTargetEnchantingSpell(location))
end

local function showItemTooltip(button)
    local item = button.item
    if not item or item.empty then
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if item.tab then GameTooltip:SetGuildBankItem(item.tab, item.slot)
    else GameTooltip:SetBagItem(item.bag, item.slot) end
    BaziUI.ItemLevel.AddItemTooltipLine(GameTooltip, item.hyperlink or item.itemID)
    GameTooltip:Show()
    if GameTooltip_ShowCompareItem and (IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems")) then
        GameTooltip_ShowCompareItem(GameTooltip)
    end
end

local function assignCursor(category)
    if InCombatLockdown() or not category or category == "Empty" or category == "Recent" then return false end
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return false end
    inventory.Settings().assignments[id] = category
    for key, recent in pairs(fresh) do if recent.id == id then fresh[key] = nil end end
    draggingItem = nil
    ClearCursor()
    inventory.RefreshBags()
    return true
end

local function cell(index)
    if cells[index] then return cells[index] end
    local button = CreateFrame("Button", nil, content, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    button.baziInventorySlot = true
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("_onstate-bazibagcombat", [[
        if newstate == "combat" then
            self:SetAttribute("type1", nil)
            self:SetAttribute("type2", nil)
            self:SetAttribute("target-bag1", nil)
            self:SetAttribute("target-slot1", nil)
        else
            self:SetAttribute("type2", "item")
        end
    ]])
    RegisterStateDriver(button, "bazibagcombat", "[combat] combat; safe")
    button:RegisterForDrag("LeftButton")
    button.edge = button:CreateTexture(nil, "OVERLAY")
    button.edge:SetAllPoints()
    button.edge:SetAtlas(slotAtlas)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local mask = button:CreateMaskTexture()
    mask:SetAllPoints(button)
    mask:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziActionSlotMask.tga")
    button.icon:AddMaskTexture(mask)
    button.questGlow = button:CreateTexture(nil, "OVERLAY", nil, 2)
    button.questGlow:SetAllPoints()
    button.questGlow:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziActionGold.tga")
    button.text = inventory.Label(button)
    button.text:SetPoint("BOTTOMRIGHT", -2, 2)
    button.level = inventory.Label(button)
    button.level:SetPoint("TOPLEFT", 2, -2)
    button.addMark = inventory.Label(button)
    button.addMark:SetPoint("CENTER")
    button.addMark:SetText("+")
    button.addMark:SetTextColor(1, 0.82, 0.24)
    button.addMark:SetShadowOffset(1, -1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local flash = button:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-glow-orange") then
        flash:SetAtlas("bags-glow-orange")
    else
        flash:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziActionGold.tga")
    end
    local animation = flash:CreateAnimationGroup()
    animation:SetLooping("REPEAT")
    local rise = animation:CreateAnimation("Alpha")
    rise:SetFromAlpha(0.08)
    rise:SetToAlpha(0.8)
    rise:SetDuration(0.45)
    rise:SetOrder(1)
    rise:SetSmoothing("IN_OUT")
    local fade = animation:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.8)
    fade:SetToAlpha(0.08)
    fade:SetDuration(0.6)
    fade:SetOrder(2)
    fade:SetSmoothing("IN_OUT")
    button.SetRecentPulse = function(_, enabled)
        if enabled then
            flash:Show()
            if not animation:IsPlaying() then animation:Play() end
        else
            animation:Stop()
            flash:Hide()
        end
    end
    flash:Hide()
    button:HookScript("OnHide", function(self) self:SetRecentPulse(false) end)
    button:SetScript("OnEnter", function(self)
        local item = self.item
        if not item or item.empty then return end
        local recent = mode == "bags" and fresh[slotKey(item)]
        if recent and recent.id == item.itemID then
            recent.seen = true
            self:SetRecentPulse(false)
        end
        showItemTooltip(self)
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        if self.item.empty or self.item.isLocked or InCombatLockdown() or hasItemTarget() then return end
        draggingItem = true
        pickup(self.item)
        draggingItem = GetCursorInfo() == "item"
        inventory.RefreshBags()
    end)
    button:SetScript("OnReceiveDrag", function(self)
        if InCombatLockdown() or hasItemTarget() then return end
        if draggingItem and assignCursor(self.category) then return end
        if self.item.dropTarget then return end
        pickup(self.item)
    end)
    button:HookScript("PreClick", function(self, mouse)
        if InCombatLockdown() then return end
        self.targetClick = mode == "bags" and (feedingPet or hasItemTarget())
        self.vendorClick = mode == "bags" and MerchantFrame and MerchantFrame:IsShown()
        self.mailClick = mode == "bags" and MailFrame and MailFrame:IsShown()
        if mouse == "LeftButton" then
            local allowed = self.targetClick and acceptsTarget(self.item, feedingPet)
            local nativeTarget = allowed and hasItemTarget()
            self:SetAttribute("target-bag1", nativeTarget and self.item.bag or nil)
            self:SetAttribute("target-slot1", nativeTarget and self.item.slot or nil)
            local feedFallback = allowed and feedingPet and not nativeTarget
            self:SetAttribute("item1", feedFallback and ("%d %d"):format(self.item.bag, self.item.slot) or nil)
            self:SetAttribute("type1", feedFallback and "item" or nil)
        elseif mouse == "RightButton" then
            self:SetAttribute("type2", not self.vendorClick and not self.mailClick and not self.targetClick and "item" or nil)
        end
    end)
    button:HookScript("OnClick", function(self, mouse)
        if InCombatLockdown() or self.targetClick then return end
        local item = self.item
        if mouse == "RightButton" then
            if not item or item.empty or item.tab or item.isLocked then return end
            if self.mailClick and MailFrame:IsShown() then
                if SendMailFrame and not SendMailFrame:IsVisible() and MailFrameTab2 and MailFrameTab2:IsVisible() then
                    MailFrameTab2:Click()
                end
                if SendMailFrame and SendMailFrame:IsVisible() then container.UseContainerItem(item.bag, item.slot) end
            elseif self.vendorClick and MerchantFrame:IsShown() and MerchantFrame.selectedTab ~= 2 then
                container.UseContainerItem(item.bag, item.slot)
            end
            return
        end
        if item.dropTarget then assignCursor(self.category); return end
        if not item.empty and IsModifiedClick() and item.hyperlink and HandleModifiedItemClick(item.hyperlink) then return end
        pickup(item)
    end)
    cells[index] = button
    return button
end

local function heading(index)
    if headings[index] then return headings[index] end
    local button = CreateFrame("Button", nil, content)
    button:SetHeight(20)
    local area = CreateFrame("Button", nil, content)
    area:SetFrameLevel(content:GetFrameLevel())
    button.dropArea = area
    area:SetScript("OnReceiveDrag", function() assignCursor(button.category) end)
    area:SetScript("OnClick", function() if draggingItem then assignCursor(button.category) end end)
    button:RegisterForDrag("LeftButton")
    button.text = inventory.Label(button, "GameFontNormal")
    button.text:SetPoint("LEFT")
    button:SetScript("OnDragStart", function(self) draggedCategory = self.category end)
    button:SetScript("OnDragStop", function(self)
        local from = draggedCategory
        draggedCategory = nil
        if from ~= self.category then return end
        local categories = inventory.Settings().categories
        for _, target in ipairs(headings) do
            if target:IsShown() and target:IsMouseOver() and target.category ~= from then
                local oldIndex, newIndex
                for i, value in ipairs(categories) do
                    if value == from then oldIndex = i end
                    if value == target.category then newIndex = i end
                end
                if oldIndex and newIndex then
                    table.remove(categories, oldIndex)
                    table.insert(categories, newIndex, from)
                    inventory.RefreshBags()
                end
                break
            end
        end
    end)
    local function assign(self) assignCursor(self.category) end
    button:SetScript("OnReceiveDrag", assign)
    button:SetScript("OnClick", assign)
    headings[index] = button
    return button
end

function inventory.RefreshBags()
    if not frame or not frame:IsShown() or InCombatLockdown() then return end
    local db = inventory.Settings()
    local moveToEdge = frame.grewUp ~= db.growUp or frame.opening
    local keepBottom = db.growUp and viewport:GetVerticalScrollRange() - viewport:GetVerticalScroll() < 2
    frame.opening = nil
    local columns = mode == "guild" and db.guildColumns or mode == "bank" and db.bankColumns or db.columns
    local size, gap = db.size, 3
    columns = math.min(columns, math.max(1, math.floor((UIParent:GetWidth() - 42) / (size + gap))))
    caption:SetText(mode == "bank" and "Bank" or mode == "guild" and "Guild Bank" or "Inventory")
    inventory.GeneralFont(wallet.text, -2)
    frame.closeButton:SetShown(not db.growUp)
    bagToggle:SetShown(mode == "bags" and IsAltKeyDown())
    local showBagStrip = mode == "bags" and frame.bagStripOpen
    bagStrip:SetShown(not not showBagStrip)
    if showBagStrip then
        for _, button in ipairs(bagStrip.buttons) do
            button.icon:SetTexture(GetInventoryItemTexture("player", button.slot) or emptyIcon)
        end
    end
    guildTabs:SetShown(mode == "guild")
    viewToggle:SetShown(atBank or atGuild)
    local query = search:GetText():lower()
    local grouped, categoryNames = {}, {}
    for _, name in ipairs(db.categories) do categoryNames[name:lower()] = name end
    for _, item in ipairs(itemsForView()) do
        local category = groupFor(item, db)
        category = categoryNames[category:lower()] or category
        local name = item.name or item.hyperlink or ""
        if query == "" or name:lower():find(query, 1, true) or category:lower():find(query, 1, true) then
            grouped[category] = grouped[category] or {}
            table.insert(grouped[category], item)
        end
    end
    local order = {unpack(db.categories)}
    if db.emptyTop then table.insert(order, 1, "Empty") else order[#order + 1] = "Empty" end
    if grouped.Recent then table.insert(order, db.growUp and #order + 1 or 1, "Recent") end
    local y, cellIndex, headingIndex, column, shelfHeight, dividerIndex = 0, 0, 0, 0, 0, 0
    local function divider()
        dividerIndex = dividerIndex + 1
        local line = dividers[dividerIndex]
        if not line then
            line = content:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(0.72, 0.58, 0.37, 0.5)
            if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
            if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
            dividers[dividerIndex] = line
        end
        local pixel = PixelUtil and PixelUtil.GetPixelToUIUnitFactor
            and PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale() or 1
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y - 19)
        line:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y - 19)
        line:SetHeight(pixel)
        line:Show()
    end
    for _, category in ipairs(order) do
        local items = grouped[category]
        if draggingItem and category ~= "Recent" and category ~= "Empty" then
            items = items or {}
            items[#items + 1] = {empty = true, dropTarget = true}
        end
        if items then
            local width = (category == "Empty" or category == "Recent") and columns
                or math.min(columns, math.max(#items, math.ceil((#category * 7 + 6) / (size + gap))))
            if column + width > columns then
                y, column, shelfHeight = y + shelfHeight, 0, 0
            end
            if column == 0 then divider() end
            headingIndex = headingIndex + 1
            local bar = heading(headingIndex)
            bar:ClearAllPoints()
            local x = column * (size + gap)
            bar:SetPoint("TOPLEFT", x, -y)
            bar:SetWidth(width * (size + gap) - gap)
            bar.category = category
            bar.text:SetText(category)
            bar:Show()
            local blockHeight = 23 + math.ceil(#items / width) * (size + gap)
            bar.dropArea:ClearAllPoints()
            bar.dropArea:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y - 20)
            bar.dropArea:SetSize(bar:GetWidth(), math.max(size, blockHeight - 23))
            bar.dropArea:SetShown(not not draggingItem and #items > 0)
            for j, item in ipairs(items or {}) do
                cellIndex = cellIndex + 1
                local button = cell(cellIndex)
                button.item = item
                button.category = category
                local itemSlot = not item.empty and not item.tab and ("%d %d"):format(item.bag, item.slot) or nil
                local targeting = mode == "bags" and (feedingPet or targetingItem)
                local matches = targeting and acceptsTarget(item, feedingPet)
                button:SetAttribute("item2", itemSlot)
                button:SetAlpha(targeting and not matches and 0.32 or 1)
                button:ClearAllPoints()
                button:SetSize(size, size)
                button:SetPoint("TOPLEFT", content, "TOPLEFT",
                    x + ((j - 1) % width) * (size + gap), -y - 23 - math.floor((j - 1) / width) * (size + gap))
                button.icon:SetColorTexture(0.14, 0.08, 0.04)
                if item.iconFileID and not db.hideIcons then button.icon:SetTexture(item.iconFileID) end
                local unusable = db.unusable and item.hyperlink and IsUsableItem and not IsUsableItem(item.hyperlink)
                    and (item.class == 2 or item.class == 4)
                button.icon:SetDesaturated((targeting and not matches) or item.empty or db.junk and item.quality == 0)
                local shade = item.empty and 0.53 or 1
                button.icon:SetVertexColor(shade, unusable and 0.33 or shade, unusable and 0.33 or shade,
                    item.isLocked and 0.45 or 1)
                local isQuest = not item.empty and (category == "Quest" or item.class == 12)
                local color = db.quality and (item.quality or 0) >= 2 and ITEM_QUALITY_COLORS[item.quality]
                button.questGlow:SetShown(isQuest or not not color or not not item.dropTarget)
                if color and not isQuest then
                    button.questGlow:SetDesaturated(true)
                    button.questGlow:SetVertexColor(color.r, color.g, color.b)
                    button.questGlow:SetAlpha(0.78)
                else
                    button.questGlow:SetDesaturated(false)
                    button.questGlow:SetVertexColor(1, 1, 1)
                    button.questGlow:SetAlpha(1)
                end
                local font = GameFontHighlightSmall:GetFont()
                BaziUI.Typography.Apply(button.text, "Inventory:Items", font, item.empty and db.emptyFontSize or db.fontSize, "OUTLINE", true)
                BaziUI.Typography.Apply(button.level, "Inventory:Items", font, db.fontSize, "OUTLINE", true)
                local count = item.stackCount or 0
                local text = item.empty and count or db.hideIcons and (item.name or "") or (count > 1 and count or "")
                if item.empty and item.kind == "keys" and db.hideKeyCount then text = "" end
                button.text:SetText(item.dropTarget and "" or text)
                button.addMark:SetShown(not not item.dropTarget)
                if item.dropTarget then button.addMark:SetFont(font, size * 0.67, "OUTLINE") end
                button.edge:SetVertexColor(0.79, 0.65, 0.46, 1)
                local level = db.quality and (item.class == 2 or item.class == 4)
                    and BaziUI.ItemLevel.GetItemLevel(item.hyperlink or item.itemID)
                button.level:SetText(level or "")
                button.level:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
                button:Show()
                local recent = category == "Recent" and fresh[slotKey(item)]
                button:SetRecentPulse(recent and not recent.seen)
            end
            shelfHeight = math.max(shelfHeight, blockHeight)
            column = column + width
        end
    end
    for i = cellIndex + 1, #cells do cells[i]:Hide() end
    for i = headingIndex + 1, #headings do headings[i]:Hide(); headings[i].dropArea:Hide() end
    for i = dividerIndex + 1, #dividers do dividers[i]:Hide() end
    local contentHeight = math.max(1, y + shelfHeight - gap)
    content:SetHeight(contentHeight)
    local controls = (mode == "guild" and 60 or 35) + search:GetHeight() + bagInset
    local topInset = db.growUp and (bagInset - 4) or controls
    local bottomInset = db.growUp and controls or 27
    if showBagStrip then
        if db.growUp then topInset = topInset + 31 else bottomInset = bottomInset + 11 end
    end
    local wantedHeight = contentHeight + topInset + bottomInset
    local height = math.min(UIParent:GetHeight() * 0.85, math.max(105, wantedHeight))
    local rightInset = bagInset + (wantedHeight > height and scrollbarSpace or 0)
    frame:SetWidth(math.max(325, columns * (size + gap) - gap + bagInset + rightInset))
    frame:SetHeight(height)
    frame.backgroundKey = mode == "guild" and "guildBankOpacity" or mode == "bank" and "bankOpacity" or nil
    frame.headerStyleKey = mode == "guild" and "guildBank" or mode == "bank" and "bank" or "inventory"
    frame:ApplyStyle()
    if frame.grewUp ~= db.growUp or frame.controls ~= controls or frame.rightInset ~= rightInset
        or frame.showBagStrip ~= showBagStrip then
        local up = db.growUp
        search:ClearAllPoints()
        search:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", bagInset, up and 35 or -35)
        search:SetPoint("RIGHT", frame.sort, "LEFT", -6, 0)
        frame.sort:ClearAllPoints()
        frame.sort:SetPoint(up and "BOTTOMRIGHT" or "TOPRIGHT", -bagInset, up and 35 or -35)
        viewToggle:ClearAllPoints()
        viewToggle:SetPoint(up and "BOTTOMRIGHT" or "TOPRIGHT", up and -162 or -34, up and 6 or -6)
        guildTabs:ClearAllPoints()
        guildTabs:SetPoint(up and "BOTTOMRIGHT" or "TOPRIGHT", -12, up and 60 or -60)
        wallet:ClearAllPoints()
        wallet:SetPoint("BOTTOMRIGHT", -10, up and 6 or 4)
        viewport:SetPoint("TOPLEFT", frame, "TOPLEFT", bagInset, -topInset)
        viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -rightInset, bottomInset)
        bagStrip:ClearAllPoints()
        bagStrip:SetPoint(up and "TOPLEFT" or "BOTTOMLEFT", bagInset, up and -4 or 4)
        frame.grewUp, frame.controls, frame.rightInset, frame.showBagStrip = up, controls, rightInset, showBagStrip
    end
    if moveToEdge or keepBottom then
        if not db.growUp then
            scrollBar:SetValue(0)
        else
            C_Timer.After(0, function()
                if frame:IsShown() and inventory.Settings().growUp then
                    scrollBar:SetValue(viewport:GetVerticalScrollRange())
                end
            end)
        end
    end
end

local function createBag()
    local window, header, title = inventory.Window("BaziUIInventory", "Inventory", 375, 400, "x", "y")
    local frame = window
    frame.inventoryGrowth = true
    frame.closeButton:SetScript("OnClick", function() if not InCombatLockdown() then frame:Hide() end end)
    bagToggle = CreateFrame("Button", nil, header)
    bagToggle:SetSize(20, 20)
    bagToggle:SetPoint("LEFT", 7, 0)
    bagToggle:SetNormalTexture(emptyIcon)
    bagToggle:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    bagToggle:Hide()
    bagToggle:SetScript("OnShow", function()
        title:SetPoint("LEFT", header, "LEFT", 32, 0)
    end)
    bagToggle:SetScript("OnHide", function()
        title:SetPoint("LEFT", header, "LEFT", 10, 0)
    end)
    bagToggle:SetScript("OnClick", function()
        frame.bagStripOpen = not frame.bagStripOpen
        inventory.RefreshBags()
    end)
    bagToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Equipped bags")
        GameTooltip:Show()
    end)
    bagToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bagStrip = CreateFrame("Frame", nil, frame)
    bagStrip:SetSize(155, 28)
    bagStrip.buttons = {}
    bagStrip:Hide()
    for _, bag in ipairs(inventory.BagIDs(true)) do
        local slot = bag > 0 and container.ContainerIDToInventoryID and container.ContainerIDToInventoryID(bag)
        if slot and slot > 0 then
            local button = CreateFrame("Button", nil, bagStrip)
            button:SetSize(26, 26)
            button:SetPoint("LEFT", #bagStrip.buttons * 30, 0)
            button.slot = slot
            button:RegisterForDrag("LeftButton")
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("TOPLEFT", 1, -1)
            button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            local border = button:CreateTexture(nil, "OVERLAY")
            border:SetAllPoints()
            border:SetAtlas(slotAtlas)
            local function equip()
                if not CursorHasItem() or InCombatLockdown() then return end
                draggingItem = nil
                PutItemInBag(slot)
                inventory.RefreshBags()
            end
            button:SetScript("OnReceiveDrag", equip)
            button:SetScript("OnClick", function()
                if CursorHasItem() then equip()
                elseif not InCombatLockdown() then PickupBagFromSlot(slot) end
            end)
            button:SetScript("OnDragStart", function()
                if not InCombatLockdown() then PickupBagFromSlot(slot) end
            end)
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                if GetInventoryItemTexture("player", slot) then GameTooltip:SetInventoryItem("player", slot)
                else GameTooltip:SetText("Empty bag slot") end
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            bagStrip.buttons[#bagStrip.buttons + 1] = button
        end
    end
    search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetAutoFocus(false)
    search:SetPoint("TOPLEFT", 13, -35)
    search:SetSize(120, 22)
    search:SetTextInsets(4, 4, 0, 0)
    local placeholder = inventory.Label(search)
    placeholder:SetPoint("LEFT", 7, 0)
    placeholder:SetText("Search items")
    placeholder:SetTextColor(0.59, 0.54, 0.48)
    local function updatePlaceholder()
        placeholder:SetShown(search:GetText() == "" and not search:HasFocus())
    end
    search:SetScript("OnTextChanged", function() updatePlaceholder(); inventory.RefreshBags() end)
    search:SetScript("OnEditFocusGained", updatePlaceholder)
    search:SetScript("OnEditFocusLost", updatePlaceholder)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local sort = CreateFrame("Button", nil, frame)
    sort:SetSize(26, 24)
    sort:SetNormalTexture(emptyIcon)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-button-autosort-up") then
        sort:GetNormalTexture():SetAtlas("bags-button-autosort-up")
    end
    sort:SetDisabledTexture(emptyIcon)
    sort:GetDisabledTexture():SetDesaturated(true)
    sort:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    sort:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if mode == "bags" and sortBags then sortBags()
        elseif mode == "bank" and sortBank then sortBank() end
    end)
    search:SetPoint("RIGHT", sort, "LEFT", -6, 0)
    sort:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -35)
    sort:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sort items")
        GameTooltip:Show()
    end)
    sort:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.sort = sort
    viewToggle = inventory.Button(frame, "Bags / Bank", 97, function()
        if atBank then inventory.OpenBags(mode == "bank" and "bags" or "bank")
        elseif atGuild then inventory.OpenBags(mode == "guild" and "bags" or "guild") end
    end)
    viewToggle:SetPoint("TOPRIGHT", -12, -35)
    guildTabs = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    guildTabs:SetSize(108, 22)
    guildTabs:SetPoint("TOPRIGHT", -12, -60)
    guildTabs:SetText("Guild tab")
    guildTabs:SetupMenu(function(_, root)
        for i = 1, GetNumGuildBankTabs() do
            local tab = i
            local name, _, viewable = GetGuildBankTabInfo(tab)
            if viewable then
                root:CreateButton(name, function()
                    SetCurrentGuildBankTab(tab)
                    QueryGuildBankTab(tab)
                    inventory.RefreshBags()
                end)
            end
        end
    end)
    content, viewport, scrollBar = inventory.Scroll(frame, -62, 27)
    wallet = CreateFrame("Frame", nil, frame)
    wallet:SetFrameLevel(header:GetFrameLevel() + 3)
    wallet:SetPoint("BOTTOMRIGHT", -10, 4)
    wallet:SetSize(156, 20)
    wallet:EnableMouse(true)
    wallet.text = inventory.Label(wallet)
    wallet.text:SetPoint("RIGHT")
    wallet.text:SetText(inventory.Money(GetMoney()))
    wallet:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Character Gold")
        local characters, total = {}, 0
        for _, character in pairs(BaziUI.db.inventoryCharacters or {}) do
            characters[#characters + 1] = character
            total = total + character.copper
        end
        table.sort(characters, function(a, b)
            if a.copper ~= b.copper then return a.copper > b.copper end
            return a.name < b.name
        end)
        for _, character in ipairs(characters) do
            local text = character.name .. " · " .. character.used .. "/" .. character.total .. " slots"
            if character.realm ~= GetRealmName() then text = text .. " · " .. character.realm end
            GameTooltip:AddDoubleLine(text, inventory.Money(character.copper), 1, 0.94, 0.80, 1, 1, 1)
        end
        GameTooltip:AddDoubleLine("Total", inventory.Money(total), 1, 0.82, 0.44, 1, 1, 1)
        GameTooltip:Show()
    end)
    wallet:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnHide", function()
        search:ClearFocus()
    end)
    return window, title
end

function inventory.OpenBags(requested)
    if not inventory.Settings().enabled or InCombatLockdown() then return end
    if not frame then frame, caption = createBag() end
    frame.opening = not frame:IsShown() or mode ~= (requested or "bags")
    mode = requested or "bags"
    frame.sort:SetEnabled(mode == "bags" and sortBags ~= nil or mode == "bank" and sortBank ~= nil)
    updateCharacter()
    frame:Show()
    frame:Raise()
    inventory.RefreshBags()
end

local function refreshItemTarget()
    if targetRefreshQueued then return end
    targetRefreshQueued = true
    C_Timer.After(0, function()
        targetRefreshQueued = false
        local kind, index, _, spellID = GetCursorInfo()
        local feeding = not InCombatLockdown() and canPetEatItem and SpellIsTargeting() and UnitExists("pet")
            and (kind == "spell" and (spellID or index) == feedPetSpell
                or isCurrentSpell and isCurrentSpell(feedPetSpell))
        local targeting = not InCombatLockdown() and not not hasItemTarget()
        feeding = not not feeding
        if feeding == feedingPet and targeting == targetingItem then return end
        local open = feeding and not feedingPet
        feedingPet, targetingItem = feeding, targeting
        if open then inventory.OpenBags("bags")
        else inventory.RefreshBags() end
    end)
end

local function toggle()
    if InCombatLockdown() then return end
    if frame and frame:IsShown() then frame:Hide()
    else inventory.OpenBags("bags") end
end

local bindings = {ToggleBackpack = toggle, ToggleAllBags = toggle, ToggleBag = toggle,
    OpenAllBags = inventory.OpenBags, OpenBackpack = inventory.OpenBags, OpenBag = inventory.OpenBags,
    CloseAllBags = function() if frame and not InCombatLockdown() then frame:Hide() end end,
    CloseBackpack = function() if frame and not InCombatLockdown() then frame:Hide() end end}

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_MONEY", "PLAYER_LOGOUT", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "GET_ITEM_INFO_RECEIVED",
    "MERCHANT_SHOW", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "AUCTION_HOUSE_SHOW",
    "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANKBAGSLOTS_CHANGED", "CURSOR_CHANGED",
    "MODIFIER_STATE_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "CURRENT_SPELL_CAST_CHANGED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "MODIFIER_STATE_CHANGED" then
        if frame and frame:IsShown() and not InCombatLockdown() then
            bagToggle:SetShown(mode == "bags" and IsAltKeyDown())
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        for name, handler in pairs(bindings) do
            local original = _G[name]
            if original then
                _G[name] = function(...)
                    if inventory.Settings().enabled and not InCombatLockdown() then return handler() end
                    return original(...)
                end
            end
        end
        for i = 0, NUM_CONTAINER_FRAMES or 13 do
            local bag = i == 0 and ContainerFrameCombinedBags or _G["ContainerFrame" .. i]
            if bag then
                bag:HookScript("OnShow", function(self)
                    if inventory.Settings().enabled and not InCombatLockdown() then self:Hide() end
                end)
            end
        end
    end
    if event == "CURSOR_CHANGED" then
        refreshItemTarget()
        if draggingItem and GetCursorInfo() ~= "item" then
            draggingItem = nil
            inventory.RefreshBags()
        end
        return
    end
    if event == "CURRENT_SPELL_CAST_CHANGED" then
        refreshItemTarget()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        refreshItemTarget()
        inventory.UpdateWindows()
        return
    end
    local db = inventory.Settings()
    if db.enabled and (event == "PLAYER_MONEY" or event == "PLAYER_LOGOUT"
        or event == "BAG_UPDATE_DELAYED" or event == "PLAYER_LOGIN") then updateCharacter() end
    if event == "PLAYER_LOGOUT" or event == "PLAYER_MONEY" then return end
    if event == "BANKFRAME_OPENED" then
        atBank = true
        if db.bank then inventory.OpenBags("bank") end
    elseif event == "BANKFRAME_CLOSED" then
        atBank = false
        if mode == "bank" and frame and not InCombatLockdown() then frame:Hide() end
    elseif event == "GUILDBANKFRAME_OPENED" then
        atGuild = true
        if db.guild then inventory.OpenBags("guild") end
    elseif event == "GUILDBANKFRAME_CLOSED" then
        atGuild = false
        if mode == "guild" and frame and not InCombatLockdown() then frame:Hide() end
    elseif event == "MERCHANT_SHOW" and db.merchant or event == "AUCTION_HOUSE_SHOW" and db.auction then
        inventory.OpenBags("bags")
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_LOGIN" then
        local current, slots, increases = {}, {}, {}
        for _, bag in ipairs(inventory.BagIDs(true)) do
            for slot = 1, container.GetContainerNumSlots(bag) do
                local info = container.GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    local key = slotKey({bag = bag, slot = slot})
                    local id, count = info.itemID, info.stackCount
                    slots[key] = {id = id, count = count}
                    current[id] = (current[id] or 0) + count
                    local old = knownSlots[key]
                    local delta = count - (old and old.id == id and old.count or 0)
                    if delta > 0 then increases[#increases + 1] = {key = key, id = id, delta = delta} end
                end
            end
        end
        for key, recent in pairs(fresh) do
            if not slots[key] or slots[key].id ~= recent.id then fresh[key] = nil end
        end
        if event ~= "PLAYER_LOGIN" then
            local gains = {}
            for id, count in pairs(current) do
                gains[id] = count - (known[id] or 0)
            end
            table.sort(increases, function(a, b) return a.delta < b.delta end)
            for _, change in ipairs(increases) do
                local id, key = change.id, change.key
                if gains[id] > 0 then
                    gains[id] = gains[id] - change.delta
                    local recent = {id = id, time = GetTime()}
                    fresh[key] = recent
                    C_Timer.After(recentDuration, function()
                        if fresh[key] == recent then
                            fresh[key] = nil
                            inventory.RefreshBags()
                        end
                    end)
                end
            end
        end
        known, knownSlots = current, slots
    end
    inventory.RefreshBags()
    if (event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED") and GameTooltip:IsShown() then
        local owner = GameTooltip:GetOwner()
        for _, button in ipairs(cells) do
            if owner == button then
                if button:IsVisible() then showItemTooltip(button) else GameTooltip:Hide() end
                break
            end
        end
    end
end)

function inventory.UpdateWindows()
    if frame and not inventory.Settings().enabled and not InCombatLockdown() then frame:Hide() end
    inventory.RefreshBags()
    if inventory.RefreshRolls then inventory.RefreshRolls() end
    if inventory.RefreshCleanup then inventory.RefreshCleanup() end
    if inventory.RefreshLoot then inventory.RefreshLoot() end
end
