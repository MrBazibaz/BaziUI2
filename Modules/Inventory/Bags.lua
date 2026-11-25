local inventory = BaziUI.Inventory
local frame, caption, search, content, viewport, scrollBar, guildTabs, viewToggle, wallet
local bagToggle, bagStrip, combatBagControls
local revealUpgrade, scrollToUpgrade
local moversOpenedBags
local mode, atBank, atGuild = "bags", false, false
local cells, headings, dividers, known, knownSlots, fresh = {}, {}, {}, {}, {}, {}
local hoveredBag
local function updateBagHighlight(button)
    local item = button.item
    local matches = mode == "bags" and hoveredBag ~= nil and item and not item.dropTarget
        and (not item.empty and item.bag == hoveredBag or item.empty and item.emptyBags and item.emptyBags[hoveredBag])
    button.bagHighlight:SetShown(not not matches)
end
local function setHoveredBag(bag)
    hoveredBag = bag
    for _, button in ipairs(cells) do updateBagHighlight(button) end
end
local draggedCategory, draggingItem
local feedingPet, targetingItem, targetRefreshQueued = false, false, false
local feedPetSpell = 6991
local isCurrentSpell = C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
local canPetEatItem = C_PetInfo and C_PetInfo.CanPetEatItem
local container = C_Container
local slotAtlas = "UI-HUD-ActionBar-IconFrame"
local emptyIcon = "Interface\\Icons\\INV_Misc_Bag_08"
local capacityIcons = {general = emptyIcon, ammo = "Interface\\Icons\\INV_Misc_Quiver_09",
    reagent = "Interface\\Icons\\INV_Misc_Herb_19"}
local recentDuration = 120
local bagInset, scrollbarSpace = 8, 18
local function slotKey(item) return item.bag .. ":" .. item.slot end
local sortBags = container.SortBags or SortBags
local sortBank = container.SortBankBags or SortBankBags
local merchantLayout = false
local function readable(value)
    return (not issecretvalue or not issecretvalue(value)) and (not canaccessvalue or canaccessvalue(value))
end
if container.SortBank and Enum and Enum.BankType and Enum.BankType.Character then
    sortBank = function() container.SortBank(Enum.BankType.Character) end
end

local function updateCharacter()
    local guid = UnitGUID("player")
    if not readable(guid) or not guid then return end
    local db = BaziUI.db
    if not db then return end
    db.inventoryCharacters = db.inventoryCharacters or {}
    local used, total = 0, 0
    for _, bag in ipairs(inventory.BagIDs(true)) do
        local slots = container.GetContainerNumSlots(bag)
        total = total + slots
        used = used + slots - (container.GetContainerNumFreeSlots(bag) or 0)
    end
    local character = db.inventoryCharacters[guid] or {}
    character.name, character.realm = UnitName("player"), GetRealmName()
    character.used, character.total = used, total
    local copper = GetMoney()
    if readable(copper) and type(copper) == "number" then
        character.copper = copper
        character.updated = GetServerTime()
    end
    db.inventoryCharacters[guid] = character
    if wallet then wallet.text:SetText(inventory.Money(character.copper)) end
end

local function itemsForView(hideEmpty)
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
            elseif not hideEmpty then
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
                stack.emptyBags = stack.emptyBags or {}
                stack.emptyBags[bag] = true
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
    -- The client validates the target when the secure click uses the bag slot.
    return true
end

local function atMerchant()
    return mode == "bags" and MerchantFrame and MerchantFrame:IsShown()
end

local function refillAmmoBag()
    if InCombatLockdown() or atBank or atGuild or hasItemTarget() or GetCursorInfo()
        or MerchantFrame and MerchantFrame:IsShown() or TradeFrame and TradeFrame:IsShown()
        or MailFrame and MailFrame:IsShown() then return end
    local familyOf = C_Item and C_Item.GetItemFamily or GetItemFamily
    if not familyOf or not bit then return end
    local ammoBags, sources = {}, {}
    for _, bag in ipairs(inventory.BagIDs(true)) do
        local _, family = container.GetContainerNumFreeSlots(bag)
        local kind = inventory.BagKind(bag, family)
        if kind == "ammo" then ammoBags[bag] = family
        elseif kind == "general" then sources[#sources + 1] = bag end
    end
    if not next(ammoBags) then return end
    for _, bag in ipairs(sources) do
        for slot = 1, container.GetContainerNumSlots(bag) do
            local source = inventory.Item(bag, slot)
            if source and source.class == 6 and not source.isLocked then
                local family = familyOf(source.hyperlink or source.itemID)
                local stack = select(8, inventory.GetItemInfo(source.hyperlink or source.itemID))
                for target, mask in pairs(ammoBags) do
                    if family and bit.band(family, mask) ~= 0 then
                        local destination, merge, split, splitCount
                        for targetSlot = 1, container.GetContainerNumSlots(target) do
                            local current = container.GetContainerItemInfo(target, targetSlot)
                            if not current then destination = destination or targetSlot
                            elseif not current.isLocked and current.itemID == source.itemID and stack then
                                local room = stack - current.stackCount
                                if room >= source.stackCount then merge = targetSlot; break end
                                if room > (splitCount or 0) then split, splitCount = targetSlot, room end
                            end
                        end
                        destination = merge or destination
                        if not destination and split and container.SplitContainerItem then
                            container.SplitContainerItem(bag, slot, splitCount)
                            destination = split
                        elseif destination then
                            container.PickupContainerItem(bag, slot)
                        end
                        if destination then
                            local kind, id = GetCursorInfo()
                            if kind == "item" and id == source.itemID then
                                container.PickupContainerItem(target, destination)
                                if GetCursorInfo() then container.PickupContainerItem(bag, slot) end
                            end
                            return
                        end
                    end
                end
            end
        end
    end
end

local function slotGUID(item)
    if not (C_Item and C_Item.GetItemGUID and ItemLocation and ItemLocation.CreateFromBagAndSlot) then return end
    local ok, guid = pcall(C_Item.GetItemGUID, ItemLocation:CreateFromBagAndSlot(item.bag, item.slot))
    if ok and type(guid) == "string" and (not issecretvalue or not issecretvalue(guid)) then return guid end
end

local function merchantSlot(button)
    local item = button.item
    if button.vendorVacant or not item or item.empty then return end
    local live = container.GetContainerItemInfo(item.bag, item.slot)
    if live and live.itemID == item.itemID and (not item.hyperlink or live.hyperlink == item.hyperlink)
        and (not button.vendorGUID or slotGUID(item) == button.vendorGUID) then
        return live
    end
    button.vendorVacant = true
    if not InCombatLockdown() then button:Disable() end
    button.icon:SetColorTexture(0.14, 0.08, 0.04)
    button.icon:SetVertexColor(0.53, 0.53, 0.53, 1)
    button.text:SetText("")
    button.level:SetText("")
    button.questGlow:Hide()
    button.questStarter:Hide()
    button.upgrade:Hide()
    button:SetRecentPulse(false)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function currentBagItem(item)
    if not item or item.empty or item.tab then return end
    local live = container.GetContainerItemInfo(item.bag, item.slot)
    if not live or not readable(live) or not readable(live.itemID) or not readable(item.itemID)
        or live.itemID ~= item.itemID or not readable(item.hyperlink) then return end
    if item.hyperlink and (not readable(live.hyperlink) or live.hyperlink ~= item.hyperlink) then return end
    return live
end

StaticPopupDialogs.BAZI_QUEST_ITEM_SELL = {
    text = "%s is used by %s. Sell it anyway?",
    button1 = SELL or YES, button2 = CANCEL, timeout = 0, hideOnEscape = true,
    OnAccept = function(_, data)
        if InCombatLockdown() or not atMerchant() or MerchantFrame.selectedTab == 2 then return end
        local live = currentBagItem(data.item)
        if live and not live.isLocked and live.stackCount == data.item.stackCount
            and (not data.guid or slotGUID(data.item) == data.guid) then
            container.UseContainerItem(data.item.bag, data.item.slot)
            merchantSlot(data.button)
        end
    end,
}

local function showItemTooltip(button)
    local item = button.item
    if not item or item.empty then
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
        return
    end
    if InCombatLockdown() and not currentBagItem(item) then
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
        return
    end
    if atMerchant() and not merchantSlot(button) then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if item.tab then GameTooltip:SetGuildBankItem(item.tab, item.slot)
    else GameTooltip:SetBagItem(item.bag, item.slot) end
    local quest = mode == "bags" and inventory.RequiredByQuest(item)
    if quest then GameTooltip:AddLine("Quest objective: " .. quest, 1, 0.82, 0.32, true) end
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

local function dragBagItem(button)
    local item = button.item
    if not item or item.empty or hasItemTarget() then return end
    if InCombatLockdown() then
        if mode ~= "bags" or atMerchant() or button.vendorVacant then return end
        local cursorType = GetCursorInfo()
        if not readable(cursorType) or cursorType ~= nil then return end
        -- The secure bag window keeps its last layout in combat. Check the
        -- live slot before picking up an item from that layout.
        local live = currentBagItem(item)
        if live and readable(live.isLocked) and not live.isLocked then
            container.PickupContainerItem(item.bag, item.slot)
        end
        return
    end
    if item.isLocked or (atMerchant() and not merchantSlot(button)) then return end
    if atMerchant() and inventory.RequiredByQuest(item) then
        BaziUI:Print("Right-click this quest item to confirm a sale.")
        return
    end
    draggingItem = true
    pickup(item)
    draggingItem = GetCursorInfo() == "item"
    inventory.RefreshBags()
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
    button.questStarter = button:CreateTexture(nil, "OVERLAY", nil, 5)
    button.questStarter:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\QuestAvailable.tga")
    button.questStarter:SetSize(16, 16)
    button.questStarter:SetPoint("BOTTOMLEFT", 1, 1)
    button.questStarter:Hide()
    button.text = inventory.Label(button)
    button.text:SetPoint("BOTTOMRIGHT", -2, 2)
    button.level = inventory.Label(button)
    button.level:SetPoint("TOPLEFT", 2, -2)
    button.upgrade = CreateFrame("Frame", nil, button)
    button.upgrade:SetPoint("TOPRIGHT", -1, -1)
    button.upgrade:SetSize(17, 19)
    button.upgrade:EnableMouse(false)
    local upgradeBackground = button.upgrade:CreateTexture(nil, "BACKGROUND")
    upgradeBackground:SetAllPoints()
    upgradeBackground:SetColorTexture(0.025, 0.09, 0.035, 0.94)
    for index = 1, 2 do
        local arrow = button.upgrade:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\ChevronUp.tga")
        arrow:SetTexCoord(4/32, 28/32, 7/32, 24/32)
        arrow:SetVertexColor(0.41, 1, 0.30)
        arrow:SetSize(15, 9)
        arrow:SetPoint("TOP", 0, 2 - index * 6)
    end
    button.upgrade:Hide()
    button.addMark = inventory.Label(button)
    button.addMark:SetPoint("CENTER")
    button.addMark:SetText("+")
    button.addMark:SetTextColor(1, 0.82, 0.24)
    button.addMark:SetShadowOffset(1, -1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button.bagHighlight = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.bagHighlight:SetAllPoints()
    button.bagHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.bagHighlight:SetBlendMode("ADD")
    button.bagHighlight:SetVertexColor(1, 0.78, 0.25, 0.65)
    button.bagHighlight:Hide()
    button:HookScript("OnHide", function(self) self.bagHighlight:Hide() end)
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
        if self.item and self.item.dropTarget then self.icon:SetColorTexture(BaziUI.Theme:AccentInk(0.56)) end
        local item = self.item
        if not item or item.empty then return end
        local recent = mode == "bags" and fresh[slotKey(item)]
        if recent and recent.id == item.itemID then
            recent.seen = true
            self:SetRecentPulse(false)
        end
        showItemTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        if self.item and self.item.dropTarget then self.icon:SetColorTexture(BaziUI.Theme:AccentInk(0.13)) end
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", dragBagItem)
    button:SetScript("OnReceiveDrag", function(self)
        if InCombatLockdown() or hasItemTarget() then return end
        if atMerchant() and (self.vendorVacant or not self.item.empty and not merchantSlot(self)) then return end
        if draggingItem and assignCursor(self.category) then return end
        if self.item.dropTarget then return end
        pickup(self.item)
    end)
    button:HookScript("PreClick", function(self, mouse)
        if InCombatLockdown() then return end
        self.targetClick = mode == "bags" and (feedingPet or hasItemTarget())
        self.vendorClick = atMerchant()
        self.vendorBlocked = false
        self.mailClick = mode == "bags" and MailFrame and MailFrame:IsShown()
        if self.vendorClick and not self.item.empty then
            local live = merchantSlot(self)
            if not live or live.isLocked then
                self.vendorBlocked = true
                self:SetAttribute("type1", nil)
                self:SetAttribute("type2", nil)
                return
            end
        end
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
        if InCombatLockdown() or self.targetClick or self.vendorBlocked then return end
        local item = self.item
        if mouse == "RightButton" then
            if not item or item.empty or item.tab or (item.isLocked and not self.vendorClick) then return end
            if self.mailClick and MailFrame:IsShown() then
                if SendMailFrame and not SendMailFrame:IsVisible() and MailFrameTab2 and MailFrameTab2:IsVisible() then
                    MailFrameTab2:Click()
                end
                if SendMailFrame and SendMailFrame:IsVisible() then container.UseContainerItem(item.bag, item.slot) end
            elseif self.vendorClick and MerchantFrame:IsShown() and MerchantFrame.selectedTab ~= 2 then
                local live = merchantSlot(self)
                if live and not live.isLocked then
                    local quest = inventory.RequiredByQuest(live) or inventory.RequiredByQuest(item)
                    if quest then
                        StaticPopup_Show("BAZI_QUEST_ITEM_SELL", item.name or live.itemName or "This item", quest,
                            {item = item, guid = self.vendorGUID, button = self})
                    else
                        container.UseContainerItem(item.bag, item.slot)
                        merchantSlot(self)
                    end
                end
            end
            return
        end
        if item.dropTarget then assignCursor(self.category); return end
        if not item.empty and IsModifiedClick() and item.hyperlink and HandleModifiedItemClick(item.hyperlink) then return end
        if self.vendorClick and inventory.RequiredByQuest(item) then
            BaziUI:Print("Right-click this quest item to confirm a sale.")
            return
        end
        if inventory.ChooseCleanupItem and inventory.ChooseCleanupItem(item) then return end
        pickup(item)
    end)
    cells[index] = button
    return button
end

local collapsedCategories = {}
local function heading(index)
    if headings[index] then return headings[index] end
    local button = CreateFrame("Button", nil, content)
    button:SetHeight(21)
    local card = BaziUI.Theme:RoundedCard(content)
    card:SetFrameLevel(content:GetFrameLevel())
    card:EnableMouse(false)
    card:SetBackdropColor(0.14, 0.105, 0.13, 0.37)
    button.card = card
    local area = CreateFrame("Button", nil, content)
    area:SetFrameLevel(content:GetFrameLevel())
    button.dropArea = area
    area:SetScript("OnReceiveDrag", function() assignCursor(button.category) end)
    area:SetScript("OnClick", function() if draggingItem then assignCursor(button.category) end end)
    button:RegisterForDrag("LeftButton")
    button.text = inventory.Label(button, "GameFontNormal")
    button.text:SetPoint("LEFT", 6, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    button.count = inventory.Label(button)
    button.count:SetPoint("RIGHT", -6, 0)
    button.text:SetPoint("RIGHT", button.count, "LEFT", -6, 0)
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
                    inventory.RefreshBags(true)
                end
                break
            end
        end
    end)
    local function assign(self) assignCursor(self.category) end
    button:SetScript("OnReceiveDrag", assign)
    button:SetScript("OnClick", function(self)
        if InCombatLockdown() then return end
        if draggingItem then assign(self); return end
        collapsedCategories[self.category] = not collapsedCategories[self.category]
        inventory.RefreshBags(true)
    end)
    headings[index] = button
    return button
end

local function isRevealedUpgrade(item)
    local upgrades = BaziUI.LootUpgrades
    return revealUpgrade and upgrades and upgrades.Mark(item) and upgrades.MatchesLink(item.hyperlink, revealUpgrade)
end

local function applyUpgradeMark(button)
    local upgrades = BaziUI.LootUpgrades
    button.upgrade:SetShown(not not (mode == "bags" and not button.vendorVacant and upgrades and upgrades.Mark(button.item)))
end

function inventory.RefreshUpgradeMarks()
    if not frame or mode ~= "bags" then return end
    if revealUpgrade and frame:IsShown() and not InCombatLockdown() then
        inventory.RefreshBags()
        return
    end
    for _, button in ipairs(cells) do
        if button:IsShown() then applyUpgradeMark(button) end
    end
end

function inventory.RefreshBags(rebuildMerchantLayout, prepareHidden)
    if not frame or (not frame:IsShown() and not prepareHidden) or InCombatLockdown() then return end
    local merchant = atMerchant()
    if merchant and merchantLayout and not rebuildMerchantLayout then
        for _, button in ipairs(cells) do
            if button:IsShown() then merchantSlot(button) end
        end
        return
    end
    merchantLayout = not not merchant
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
    local bagsVisible = mode == "bags" and (not db.bagsOnAlt or IsAltKeyDown())
    bagToggle:SetShown(bagsVisible)
    local showBagStrip = bagsVisible and frame.bagStripOpen == true
    bagStrip:SetShown(not not showBagStrip)
    if showBagStrip then
        for _, button in ipairs(bagStrip.buttons) do
            button.icon:SetTexture(GetInventoryItemTexture("player", button.slot) or emptyIcon)
        end
    end
    guildTabs:SetShown(mode == "guild")
    viewToggle:SetShown(atBank or atGuild)
    local capacity = mode == "bags" and inventory.Capacity() or {}
    local capacityHeight = 0
    for _, kind in ipairs(inventory.capacityOrder) do
        local bar, slots = frame.capacity.bars[kind], capacity[kind]
        bar.slots = slots
        bar:SetShown(slots ~= nil)
        if slots then
            bar.fill:SetMinMaxValues(0, slots.total)
            bar.fill:SetValue(slots.total - slots.free)
            bar.fill:SetStatusBarColor(BaziUI.Theme:Accent())
            inventory.GeneralFont(bar.count, 0, "OUTLINE", "Inventory:Capacity", db.capacityFontSize)
            bar.count:SetFormattedText("%d / %d", slots.total - slots.free, slots.total)
            local height = math.max(12, math.ceil(bar.count:GetStringHeight()))
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", frame.capacity, "TOPLEFT", 0, -capacityHeight)
            bar:SetPoint("TOPRIGHT", frame.capacity, "TOPRIGHT", 0, -capacityHeight)
            bar:SetHeight(height)
            capacityHeight = capacityHeight + height + 1
        end
    end
    frame.capacity:SetShown(capacityHeight > 0)
    frame.capacity:SetHeight(math.max(1, capacityHeight))
    local query = search:GetText():lower()
    local grouped, categoryNames = {}, {}
    for _, name in ipairs(db.categories) do categoryNames[name:lower()] = name end
    local hideEmpty = mode == "bags" and db.hideEmptyCategory
    local items = itemsForView(hideEmpty)
    if revealUpgrade then
        local found
        for _, item in ipairs(items) do
            if isRevealedUpgrade(item) then found = true; break end
        end
        if not found then revealUpgrade, scrollToUpgrade = nil, nil end
    end
    for _, item in ipairs(items) do
        local category = groupFor(item, db)
        category = categoryNames[category:lower()] or category
        if isRevealedUpgrade(item) then collapsedCategories[category] = nil end
        local name = item.name or item.hyperlink or ""
        if query == "" or name:lower():find(query, 1, true) or category:lower():find(query, 1, true) then
            grouped[category] = grouped[category] or {}
            table.insert(grouped[category], item)
        end
    end
    local order = {unpack(db.categories)}
    if not hideEmpty then
        if db.emptyTop then table.insert(order, 1, "Empty") else order[#order + 1] = "Empty" end
    end
    if grouped.Recent then table.insert(order, db.growUp and #order + 1 or 1, "Recent") end
    local y, cellIndex, headingIndex, shelfX, shelfHeight = 0, 0, 0, 0, 0
    local upgradeOffset
    local step = size + gap
    local cardPadding, cardGap = 6, 5
    local shelfWidth = columns * step - gap + 2 * cardPadding
    for _, category in ipairs(order) do
        local items = grouped[category]
        local collapsed = collapsedCategories[category] and not draggingItem and query == ""
        local itemCount = items and #items or 0
        if draggingItem and category ~= "Recent" and category ~= "Empty" then
            items = items or {}
            items[#items + 1] = {empty = true, dropTarget = true}
        end
        if items then
            headingIndex = headingIndex + 1
            local bar = heading(headingIndex)
            bar.category = category
            bar.text:SetText((collapsed and "+ " or "") .. category)
            inventory.GeneralFont(bar.text, 0)
            bar.text:SetTextColor(BaziUI.Headers.Text(frame.headerStyleKey or "inventory", 1, 0.82, 0.49))
            bar.count:SetText(itemCount)
            local measure = bar.text.GetUnboundedStringWidth or bar.text.GetStringWidth
            local labelWidth = math.ceil(measure(bar.text) + measure(bar.count) + 26)
            local width = collapsed and 1 or math.max(1, math.min(#items, columns))
            local itemWidth = width * step - gap + 2 * cardPadding
            local cardWidth = math.min(shelfWidth, math.max(itemWidth, labelWidth))
            if cardWidth > shelfWidth - shelfX then
                y, shelfX, shelfHeight = y + shelfHeight, 0, 0
            end
            bar:ClearAllPoints()
            local x = shelfX
            bar:SetPoint("TOPLEFT", x, -y)
            bar:SetWidth(cardWidth)
            bar.count:SetTextColor(BaziUI.Theme:Accent())
            bar:Show()
            local blockHeight = 25 + (collapsed and 0 or math.ceil(#items / width) * (size + gap))
            bar.card:ClearAllPoints()
            bar.card:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 0)
            bar.card:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, -blockHeight + 2)
            bar.card:SetBackdropBorderColor(BaziUI.Theme:AccentInk(0.13))
            bar.card:Show()
            bar.dropArea:ClearAllPoints()
            bar.dropArea:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y - 20)
            bar.dropArea:SetSize(bar:GetWidth(), math.max(size, blockHeight - 23))
            bar.dropArea:SetShown(not not draggingItem and #items > 0)
            for j, item in ipairs(not collapsed and items or {}) do
                cellIndex = cellIndex + 1
                local button = cell(cellIndex)
                button.item = item
                updateBagHighlight(button)
                button.vendorVacant = nil
                button.vendorGUID = merchant and not item.empty and slotGUID(item) or nil
                button:Enable()
                button.category = category
                local itemSlot = not item.empty and not item.tab and ("%d %d"):format(item.bag, item.slot) or nil
                local targeting = mode == "bags" and (feedingPet or targetingItem)
                local matches = targeting and acceptsTarget(item, feedingPet)
                local revealed = not targeting and isRevealedUpgrade(item)
                local dim = targeting and not matches or not targeting and revealUpgrade and not revealed
                button:SetAttribute("item2", itemSlot)
                button:SetAlpha(dim and 0.32 or 1)
                button:ClearAllPoints()
                button:SetSize(size, size)
                button:SetPoint("TOPLEFT", content, "TOPLEFT",
                    x + cardPadding + ((j - 1) % width) * (size + gap), -y - 23 - math.floor((j - 1) / width) * (size + gap))
                if scrollToUpgrade and revealed and not upgradeOffset then
                    upgradeOffset = y + 23 + math.floor((j - 1) / width) * (size + gap)
                end
                button.icon:SetColorTexture(0.14, 0.08, 0.04)
                if item.iconFileID and not db.hideIcons then button.icon:SetTexture(item.iconFileID) end
                local unusable = not revealed and db.unusable and item.hyperlink and IsUsableItem and not IsUsableItem(item.hyperlink)
                    and (item.class == 2 or item.class == 4)
                button.baseDesaturation = item.empty or db.junk and item.quality == 0
                button.icon:SetDesaturated(dim or not revealed and button.baseDesaturation)
                local shade = item.empty and 0.53 or 1
                button.icon:SetVertexColor(shade, unusable and 0.33 or shade, unusable and 0.33 or shade,
                    item.isLocked and 0.45 or 1)
                local startsQuest = not item.empty and not item.tab and inventory.QuestStarter(item.bag, item.slot)
                button.questStarter:SetShown(not not startsQuest)
                local isQuest = not item.empty and (startsQuest or category == "Quest" or item.class == 12)
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
                if item.dropTarget then
                    button.edge:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\Ghost.tga")
                    button.edge:SetVertexColor(BaziUI.Theme:Accent())
                    button.icon:SetColorTexture(BaziUI.Theme:AccentInk(0.13))
                    button.questGlow:Hide()
                    button.addMark:Hide()
                else
                    button.edge:SetAtlas(slotAtlas)
                    button.edge:SetVertexColor(0.79, 0.65, 0.46, 1)
                end
                local level = db.quality and (item.class == 2 or item.class == 4)
                    and BaziUI.ItemLevel.GetItemLevel(item.hyperlink or item.itemID)
                button.level:SetText(level or "")
                button.level:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
                applyUpgradeMark(button)
                button:Show()
                local recent = category == "Recent" and fresh[slotKey(item)]
                button:SetRecentPulse(recent and not recent.seen)
            end
            shelfHeight = math.max(shelfHeight, blockHeight)
            shelfX = shelfX + cardWidth + cardGap
        end
    end
    for i = cellIndex + 1, #cells do cells[i]:Hide() end
    for i = headingIndex + 1, #headings do
        headings[i]:Hide(); headings[i].dropArea:Hide(); headings[i].card:Hide()
    end
    local contentHeight = math.max(1, y + shelfHeight - gap)
    local controls = (mode == "guild" and 60 or 35) + search:GetHeight() + bagInset
        + (mode == "bags" and (capacityHeight + 7) or 0)
    local topInset = db.growUp and (bagInset - 4) or controls
    local bottomInset = db.growUp and controls or 27
    local wantedHeight = contentHeight + topInset + bottomInset
    local height = math.min(UIParent:GetHeight() * 0.85, math.max(105, wantedHeight))
    local needsScroll = wantedHeight - height > 0.5
    local rightInset = bagInset + (needsScroll and scrollbarSpace or 0)
    frame:SetWidth(math.max(325, shelfWidth + bagInset + rightInset))
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
        viewport:ClearAllPoints()
        viewport:SetPoint("TOPLEFT", frame, "TOPLEFT", bagInset, -topInset)
        viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -rightInset, bottomInset)
        bagStrip:ClearAllPoints()
        bagStrip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -5, -8)
        frame.capacity:ClearAllPoints()
        frame.capacity:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", search, up and "TOPLEFT" or "BOTTOMLEFT", 0, up and 4 or -4)
        frame.capacity:SetPoint(up and "BOTTOMRIGHT" or "TOPRIGHT", search, up and "TOPRIGHT" or "BOTTOMRIGHT",
            frame.sort:GetWidth() + 6, up and 4 or -4)
        frame.grewUp, frame.controls, frame.rightInset, frame.showBagStrip = up, controls, rightInset, showBagStrip
    end
    viewport.baziAllowScroll = needsScroll
    content:SetHeight(contentHeight)
    viewport:UpdateScrollChildRect()
    scrollBar:SyncRange()
    if upgradeOffset then
        scrollToUpgrade = nil
        scrollBar:SetValue(math.max(0, math.min(viewport:GetVerticalScrollRange(), upgradeOffset - (viewport:GetHeight() - size) / 2)))
    elseif needsScroll and (moveToEdge or keepBottom) then
        if not db.growUp then
            scrollBar:SetValue(0)
        else
            C_Timer.After(0, function()
                if (frame:IsShown() or prepareHidden and mode == "bags") and inventory.Settings().growUp then
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
    local controls = CreateFrame("Button", "BaziUICombatBagToggle", UIParent, "SecureHandlerClickTemplate,SecureHandlerStateTemplate")
    controls:RegisterForClicks("LeftButtonUp")
    controls:SetFrameRef("bagWindow", frame)
    controls:SetAttribute("UpdateBagBindings", [[
        self:ClearBindings()
        if self:GetAttribute("state-bazibagwindow") ~= "combat" then return end
        if not self:GetAttribute("bagMode") then self:GetFrameRef("bagWindow"):Hide(); return end
        if not self:GetAttribute("enabled") then return end
        for index = 1, self:GetAttribute("keyCount") or 0 do
            self:SetBindingClick(false, self:GetAttribute("key" .. index), self:GetName(), "LeftButton")
        end
    ]])
    controls:SetAttribute("_onstate-bazibagwindow", [[ self:RunAttribute("UpdateBagBindings") ]])
    controls:SetAttribute("_onclick", [[
        if not self:GetAttribute("enabled") or not self:GetAttribute("bagMode") then return end
        local window = self:GetFrameRef("bagWindow")
        if window:IsShown() then window:Hide() else window:Show() end
    ]])
    frame.closeButton:SetScript("OnClick", function() if not InCombatLockdown() then frame:Hide() end end)
    SecureHandlerWrapScript(frame.closeButton, "OnClick", controls, [[
        if control:GetAttribute("state-bazibagwindow") == "combat" then control:GetFrameRef("bagWindow"):Hide() end
    ]])
    RegisterStateDriver(controls, "bazibagwindow", "[combat] combat; ready")
    combatBagControls = controls
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
        if InCombatLockdown() then return end
        frame.bagStripOpen = not frame.bagStripOpen
        inventory.RefreshBags(true)
    end)
    bagToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Equipped bags")
        GameTooltip:Show()
    end)
    bagToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bagStrip = CreateFrame("Frame", nil, frame)
    bagStrip:SetSize(28, 155)
    bagStrip.buttons = {}
    bagStrip:HookScript("OnHide", function() setHoveredBag(nil) end)
    bagStrip:Hide()
    for _, bag in ipairs(inventory.BagIDs(true)) do
        local slot = bag > 0 and container.ContainerIDToInventoryID and container.ContainerIDToInventoryID(bag)
        if slot and slot > 0 then
            local button = CreateFrame("Button", nil, bagStrip)
            button:SetSize(26, 26)
            button:SetPoint("TOP", 0, -#bagStrip.buttons * 30)
            button.slot = slot
            button.bag = bag
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
                setHoveredBag(self.bag)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                if GetInventoryItemTexture("player", slot) then GameTooltip:SetInventoryItem("player", slot)
                else GameTooltip:SetText("Empty bag slot") end
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function()
                setHoveredBag(nil)
                GameTooltip:Hide()
            end)
            bagStrip.buttons[#bagStrip.buttons + 1] = button
        end
    end
    search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetAutoFocus(false)
    search:SetPoint("TOPLEFT", 13, -35)
    search:SetSize(120, 22)
    search:SetTextInsets(22, 4, 0, 0)
    local glass = search:CreateTexture(nil, "ARTWORK")
    glass:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\Search.tga")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", 5, 0)
    glass:SetVertexColor(0.75, 0.63, 0.44)
    frame.capacity = CreateFrame("Frame", nil, frame)
    frame.capacity.bars = {}
    for _, kind in ipairs(inventory.capacityOrder) do
        local bar = CreateFrame("Frame", nil, frame.capacity)
        local icon = bar:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetPoint("LEFT")
        icon:SetTexture(capacityIcons[kind])
        bar:EnableMouse(true)
        bar:SetScript("OnEnter", function(self)
            if not self.slots then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(inventory.capacityLabels[kind])
            GameTooltip:AddLine(("%d free of %d"):format(self.slots.free, self.slots.total), 1, 1, 1)
            GameTooltip:Show()
        end)
        bar:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        local fill = CreateFrame("StatusBar", nil, bar)
        fill:SetHeight(4)
        fill:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        fill:SetPoint("RIGHT")
        fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        local track = fill:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints()
        track:SetColorTexture(0.18, 0.14, 0.12, 1)
        bar.count = inventory.Label(fill)
        bar.count:SetPoint("RIGHT", bar, "RIGHT")
        bar.fill = fill
        frame.capacity.bars[kind] = bar
    end
    local placeholder = inventory.Label(search)
    placeholder:SetPoint("LEFT", 22, 0)
    placeholder:SetText("Search items")
    placeholder:SetTextColor(0.59, 0.54, 0.48)
    local function updatePlaceholder()
        placeholder:SetShown(search:GetText() == "" and not search:HasFocus())
    end
    search:SetScript("OnTextChanged", function(_, userInput)
        updatePlaceholder()
        if userInput then revealUpgrade, scrollToUpgrade = nil, nil end
        if not revealUpgrade then inventory.RefreshBags(true) end
    end)
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
        updateCharacter()
        local byName, characters, total = {}, {}, 0
        local function key(name, realm) return name .. "-" .. (realm or ""):gsub("%s+", "") end
        for _, character in pairs(BaziUI.db.inventoryCharacters or {}) do
            if character.name then byName[key(character.name, character.realm)] = character end
        end
        for _, character in pairs(BaziUI.AltManager and BaziUI.AltManager.Characters() or {}) do
            local meta = character.identity
            if meta and meta.name and meta.realm and type(meta.money) == "number" then
                local id = key(meta.name, meta.realm)
                local prior = byName[id]
                if not prior or type(prior.copper) ~= "number" or (not prior.updated and prior.copper == 0)
                    or (character.updated or 0) > (prior.updated or 0) then
                    byName[id] = {name = meta.name, realm = meta.realm, copper = meta.money,
                        used = prior and prior.used, total = prior and prior.total}
                end
            end
        end
        for _, character in pairs(byName) do
            characters[#characters + 1] = character
            total = total + (character.copper or 0)
        end
        table.sort(characters, function(a, b)
            if (a.copper or -1) ~= (b.copper or -1) then return (a.copper or -1) > (b.copper or -1) end
            return a.name < b.name
        end)
        for _, character in ipairs(characters) do
            local text = character.name
            if character.used and character.total then text = text .. " · " .. character.used .. "/" .. character.total .. " slots" end
            if character.realm and character.realm ~= GetRealmName() then text = text .. " · " .. character.realm end
            GameTooltip:AddDoubleLine(text, type(character.copper) == "number" and inventory.Money(character.copper)
                or "Unknown", 1, 0.94, 0.80, 1, 1, 1)
        end
        GameTooltip:AddDoubleLine("Total", inventory.Money(total), 1, 0.82, 0.44, 1, 1, 1)
        GameTooltip:Show()
    end)
    wallet:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnHide", function()
        setHoveredBag(nil)
        revealUpgrade, scrollToUpgrade = nil, nil
        if inventory.CancelCleanupChoice then inventory.CancelCleanupChoice() end
        for _, button in ipairs(cells) do
            button:SetAlpha(1)
            button.icon:SetDesaturated(not not button.baseDesaturation)
        end
        frame.bagStripOpen = false
        if InCombatLockdown() then return end
        bagStrip:Hide()
        search:ClearFocus()
    end)
    return window, title
end

function inventory.OpenBags(requested)
    if not inventory.Settings().enabled or InCombatLockdown() then return end
    if not frame then frame, caption = createBag() end
    frame.opening = not frame:IsShown() or mode ~= (requested or "bags")
    mode = requested or "bags"
    if mode ~= "bags" then revealUpgrade, scrollToUpgrade = nil, nil end
    if scrollToUpgrade then
        search:SetText("")
        search:ClearFocus()
    end
    combatBagControls:SetAttribute("bagMode", mode == "bags")
    frame.sort:SetEnabled(mode == "bags" and sortBags ~= nil or mode == "bank" and sortBank ~= nil)
    updateCharacter()
    frame:Show()
    frame:Raise()
    inventory.RefreshBags(true)
end

function inventory.RevealUpgrade(link)
    if InCombatLockdown() or not inventory.Settings().enabled or MerchantFrame and MerchantFrame:IsShown() then return end
    revealUpgrade, scrollToUpgrade = link, true
    inventory.OpenBags("bags")
end

function inventory.MoversLayout(enabled)
    if InCombatLockdown() then return end
    if enabled then
        if inventory.Settings().enabled and not (frame and frame:IsShown()) then
            inventory.OpenBags("bags")
            moversOpenedBags = frame and frame:IsShown()
        end
    elseif moversOpenedBags then
        moversOpenedBags = nil
        if frame and mode == "bags" then frame:Hide() end
    end
end

local bagBindingCommands = {"TOGGLEBACKPACK", "OPENALLBAGS", "TOGGLEBAG1", "TOGGLEBAG2", "TOGGLEBAG3",
    "TOGGLEBAG4", "TOGGLEREAGENTBAG", "TOGGLEKEYRING"}
local function syncCombatBagBindings(enabled)
    if not combatBagControls or InCombatLockdown() then return end
    local keys, count = {}, 0
    for _, command in ipairs(bagBindingCommands) do
        for _, key in ipairs({GetBindingKey(command)}) do
            if not keys[key] then
                keys[key], count = true, count + 1
                combatBagControls:SetAttribute("key" .. count, key)
            end
        end
    end
    combatBagControls:SetAttribute("keyCount", count)
    combatBagControls:SetAttribute("bagMode", mode == "bags")
    combatBagControls:SetAttribute("enabled", enabled)
end

local function prepareBagWindow()
    if InCombatLockdown() then return end
    local enabled = inventory.Settings().enabled
    if enabled and not frame then frame, caption = createBag() end
    if (mode == "bank" and not atBank) or (mode == "guild" and not atGuild) then mode = "bags" end
    if enabled then
        inventory.RefreshBags(nil, mode == "bags")
    elseif frame then
        frame:Hide()
    end
    syncCombatBagBindings(enabled)
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

local pendingBagAction, closingNativeBags
local bagActionPriority = {close = 1, open = 2, toggle = 3}
local concealedBags = {}

local function restoreNativeBags()
    for bag, alpha in pairs(concealedBags) do bag:SetAlpha(alpha) end
    wipe(concealedBags)
end

local function concealNativeBag(bag)
    if bag and bag:IsShown() and concealedBags[bag] == nil then
        concealedBags[bag] = bag:GetAlpha()
        bag:SetAlpha(0)
    end
end

local function queueBagAction(action)
    if closingNativeBags or InCombatLockdown() or not inventory.Settings().enabled then return end
    if action ~= "close" then
        concealNativeBag(ContainerFrameCombinedBags)
        for i = 1, NUM_CONTAINER_FRAMES or 13 do concealNativeBag(_G["ContainerFrame" .. i]) end
    end
    if pendingBagAction then
        if bagActionPriority[action] >= bagActionPriority[pendingBagAction] then pendingBagAction = action end
        return
    end
    pendingBagAction = action
    C_Timer.After(0, function()
        local requested = pendingBagAction
        pendingBagAction = nil
        if InCombatLockdown() or not inventory.Settings().enabled then
            restoreNativeBags()
            return
        end
        if requested == "close" then
            if frame then frame:Hide() end
            return
        end
        if CloseAllBags then
            closingNativeBags = true
            CloseAllBags()
            closingNativeBags = false
        end
        restoreNativeBags()
        if requested == "toggle" then toggle()
        else inventory.OpenBags("bags") end
    end)
end

local bindings = {ToggleBackpack = "toggle", ToggleAllBags = "toggle", ToggleBag = "toggle",
    OpenAllBags = "open", OpenBackpack = "open", OpenBag = "open",
    CloseAllBags = "close", CloseBackpack = "close"}

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "GET_ITEM_INFO_RECEIVED",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "AUCTION_HOUSE_SHOW",
    "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANKBAGSLOTS_CHANGED", "CURSOR_CHANGED",
    "MODIFIER_STATE_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "CURRENT_SPELL_CAST_CHANGED",
    "QUEST_LOG_UPDATE"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_BINDINGS" then
        syncCombatBagBindings(inventory.Settings().enabled)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then updateCharacter(); prepareBagWindow(); return end
    if event == "MODIFIER_STATE_CHANGED" then
        if frame and frame:IsShown() and not InCombatLockdown() then
            local db = inventory.Settings()
            bagToggle:SetShown(mode == "bags" and (not db.bagsOnAlt or IsAltKeyDown()))
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        -- Let Blizzard's binding run securely, including when combat starts mid-click.
        for name, action in pairs(bindings) do
            if type(_G[name]) == "function" then
                hooksecurefunc(name, function() queueBagAction(action) end)
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
        if moversOpenedBags and not (BaziUI.Movers and BaziUI.Movers.IsActive()) then inventory.MoversLayout(false) end
        refreshItemTarget()
        inventory.UpdateWindows()
        if inventory.Settings().enabled then refillAmmoBag() end
        return
    end
    local db = inventory.Settings()
    if event == "MERCHANT_CLOSED" then
        merchantLayout = false
        StaticPopup_Hide("BAZI_QUEST_ITEM_SELL")
        inventory.RefreshBags(true)
        return
    end
    if event == "PLAYER_MONEY" or event == "PLAYER_LOGIN"
        or db.enabled and event == "BAG_UPDATE_DELAYED" then updateCharacter() end
    if event == "PLAYER_MONEY" then return end
    if event == "BANKFRAME_OPENED" then
        atBank = true
        if db.bank then inventory.OpenBags("bank") end
    elseif event == "BANKFRAME_CLOSED" then
        atBank = false
        if mode == "bank" and not InCombatLockdown() then
            frame:Hide()
            prepareBagWindow()
        end
    elseif event == "GUILDBANKFRAME_OPENED" then
        atGuild = true
        if db.guild then inventory.OpenBags("guild") end
    elseif event == "GUILDBANKFRAME_CLOSED" then
        atGuild = false
        if mode == "guild" and not InCombatLockdown() then
            frame:Hide()
            prepareBagWindow()
        end
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
    if event == "PLAYER_LOGIN" then
        prepareBagWindow()
    else
        inventory.RefreshBags(nil, db.enabled and mode == "bags" and event == "BAG_UPDATE_DELAYED")
    end
    if db.enabled and (event == "BAG_UPDATE_DELAYED" or event == "PLAYER_LOGIN") then refillAmmoBag() end
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
    prepareBagWindow()
    if inventory.RefreshRolls then inventory.RefreshRolls() end
    if inventory.RefreshCleanup then inventory.RefreshCleanup() end
    if inventory.RefreshLoot then inventory.RefreshLoot() end
end
