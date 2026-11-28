local inventory = BaziUI.Inventory
local container = C_Container
local frame, content, emptyLabel, scroll, scrollbar, protectedButton, chooseButton
function inventory.GetCleanupMoverFrame() return frame end
local origin, pendingLoot, target, choosing
local lootOpen, selectedLoot, queued, queueCleanupRefresh
local questOpen, questAttempt, questBlocked, lastTurnIn
local rolls = {}
local protected = {[7005] = true, [2901] = true, [5956] = true, [6219] = true,
    [6256] = true, [6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true,
    [6948] = true, [4470] = true}

local money = inventory.Money

local function value(item)
    return item.price * item.stackCount
end

local function ignored(item, settings)
    local custom = settings.ignored[item.itemID]
    if custom ~= nil then return custom end
    return protected[item.itemID] or false
end

local function isKeyring(bag)
    local index = Enum and Enum.BagIndex
    return bag == (index and index.Keyring or KEYRING_CONTAINER or -2)
end

local function protectedAltUpgrade(item)
    local advisor = BaziUI.LootUpgrades
    if not advisor or not advisor.AltRecommendations or (item.class ~= 2 and item.class ~= 4) then return false end
    local ok, protected = pcall(function()
        local live = container.GetContainerItemInfo(item.bag, item.slot)
        if not live then return true end
        if issecretvalue and (issecretvalue(live.isBound) or issecretvalue(live.hyperlink)) then return true end
        if live.hyperlink ~= item.hyperlink or type(live.isBound) ~= "boolean" then return true end
        if live.isBound then return false end
        return #advisor.AltRecommendations(item.hyperlink, true) > 0
    end)
    -- Never discard equipment when the protection check fails.
    return not ok or protected
end

local function eligible(item, settings)
    if not (item and item.name and item.price and item.stackCount and item.hyperlink and not item.isLocked
        and item.quality and item.quality <= settings.maxDeleteQuality and item.class ~= 12
        and not isKeyring(item.bag) and not ignored(item, settings)) then return false end
    if protectedAltUpgrade(item) then return false end
    local _, family = container.GetContainerNumFreeSlots(item.bag)
    if inventory.BagKind(item.bag, family) ~= "general" then return false end
    local quest = container.GetContainerItemQuestInfo and container.GetContainerItemQuestInfo(item.bag, item.slot)
    return not (quest and (quest.isQuestItem or quest.questID)) and not inventory.RequiredByQuest(item)
end

local function read(value)
    return (not issecretvalue or not issecretvalue(value)) and (not canaccessvalue or canaccessvalue(value))
end

local function incomingItem(link, count, id)
    if not read(link) then link = nil end
    if type(link) == "string" then
        id = id or tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
    end
    if not read(id) or type(id) ~= "number" or id <= 0 or not read(count) then return end
    local _, _, _, _, _, _, _, stack, _, _, price, class, _, _, _, _, reagent = inventory.GetItemInfo(link or id)
    if not stack and C_Item and C_Item.GetItemMaxStackSizeByID then stack = C_Item.GetItemMaxStackSizeByID(id) end
    if not stack or stack <= 0 then return end
    count = count or 1
    return {id = id, link = link or id, count = count, stack = stack,
        quest = class == 12, reagent = reagent == true, key = class == 13, total = (price or 0) * count}
end

local function lootItem(slot)
    local _, name, count, _, _, locked, isQuestItem, questID = GetLootSlotInfo(slot)
    if not read(locked) or not read(isQuestItem) or locked then return end
    local item = incomingItem(GetLootSlotLink(slot), count)
    if item then
        item.slot = slot
        item.quest = item.quest or isQuestItem == true or read(questID) and questID ~= nil
            or inventory.RequiredByQuest({itemID = item.id, name = name}) ~= nil
    end
    return item
end

local function bagCapacity()
    local partial, free = {}, {[0] = 0}
    for _, bag in ipairs(inventory.BagIDs(true)) do
        local slots, family = container.GetContainerNumFreeSlots(bag)
        if inventory.BagKind(bag, family) == "general" then
            free[0] = free[0] + (slots or 0)
            for slot = 1, container.GetContainerNumSlots(bag) do
                local item = container.GetContainerItemInfo(bag, slot)
                if item and item.itemID and not item.isLocked then
                    local id = item.itemID
                    partial[id] = partial[id] or {}
                    local counts = partial[id]
                    counts[#counts + 1] = item.stackCount or 1
                end
            end
        end
    end
    return partial, free
end

local function neededSlots(item, partial, replacing)
    local remaining = item.count
    for _, count in ipairs(partial[item.id] or {}) do
        remaining = remaining - math.max(0, item.stack - count)
    end
    if replacing and replacing.itemID == item.id then
        remaining = remaining + math.max(0, item.stack - replacing.stackCount)
    end
    return math.max(0, math.ceil(remaining / item.stack))
end

local function shortage(items, partial, free, replacing)
    if not partial then partial, free = bagCapacity() end
    local available = free[0] or 0
    if replacing then available = available + 1 end
    local needed = 0
    for _, item in ipairs(items) do
        needed = needed + neededSlots(item, partial, replacing)
    end
    return math.max(0, needed - available)
end

local function fits(item, partial, free, replacing)
    return shortage(item.items or {item}, partial, free, replacing) == 0
end

local function makesRoom(item, partial, free, replacing)
    if not item.items then return fits(item, partial, free, replacing) end
    if not partial then partial, free = bagCapacity() end
    return item.requiredFree ~= nil or shortage(item.items, partial, free, replacing) < shortage(item.items, partial, free)
end

local function blockedLoot()
    local best, partial, free
    if selectedLoot then
        local item = lootItem(selectedLoot.slot)
        if item and item.link == selectedLoot.link and not fits(item) then return item end
        selectedLoot = nil
    end
    for slot = 1, GetNumLootItems() do
        local item = lootItem(slot)
        if item then
            if not partial then partial, free = bagCapacity() end
            if not fits(item, partial, free)
                and (not best or item.quest and not best.quest or item.quest == best.quest and item.total > best.total) then
                best = item
            end
        end
    end
    return best
end

local function selectableLoot(slot)
    if not lootOpen or origin ~= "loot" or not target or not frame:IsShown() then return end
    if not read(slot) or type(slot) ~= "number" or slot < 1 or slot > GetNumLootItems() then return end
    local item = lootItem(slot)
    if item and not fits(item) then return item end
end

function inventory.CanSelectCleanupLoot(slot)
    return selectableLoot(slot) ~= nil
end

function inventory.SelectCleanupLoot(slot)
    local item = selectableLoot(slot)
    if item then
        selectedLoot, target = item, item
        inventory.RefreshCleanup()
        inventory.RefreshLoot()
    end
end

local function questReward(choice)
    local items, byID = {}, {}
    local function add(kind, index)
        local _, _, count, _, _, id = GetQuestItemInfo(kind, index)
        local item = incomingItem(GetQuestItemLink(kind, index), count, id)
        if not item then return end
        if byID[item.id] then
            byID[item.id].count = byID[item.id].count + item.count
        else
            byID[item.id] = item
            items[#items + 1] = item
        end
    end
    for index = 1, GetNumQuestRewards() do add("reward", index) end
    local choices = GetNumQuestChoices()
    if choices == 1 then choice = 1 end
    if read(choice) and type(choice) == "number" and choice > 0 and choice <= choices then add("choice", choice) end
    return {items = items, id = questOpen, choice = choice or 0}
end

local function blockedQuest()
    if not questBlocked or not questOpen then return end
    local item = lastTurnIn and lastTurnIn.reward or questReward(questAttempt or QuestInfoFrame and QuestInfoFrame.itemChoice)
    if #item.items > 0 and not fits(item) then return item end
    local _, free = bagCapacity()
    if free[0] < questBlocked then
        item.requiredFree = questBlocked
        return item
    end
    questBlocked = nil
end

local function blockedRoll()
    local now = GetTime()
    local best
    for id, deadline in pairs(rolls) do
        if deadline <= now then
            rolls[id] = nil
        else
            local _, _, count = GetLootRollItemInfo(id)
            local item = incomingItem(GetLootRollItemLink(id), count)
            if item and not fits(item) and (not best or item.total > best.total) then
                item.slot, best = id, item
            end
        end
    end
    return best
end

local function lootAfterDeletion()
    if not pendingLoot then return end
    local db = inventory.Settings()
    if not db.enabled or not db.cleanup then pendingLoot = nil; return end
    local best = lootItem(pendingLoot.slot)
    if not best or best.link ~= pendingLoot.link then pendingLoot = nil; return end
    if not fits(best) then return end
    pendingLoot = nil
    LootSlot(best.slot)
end

local function deleteItem(request)
    if GetCursorInfo() or origin ~= request.origin then return end
    local snapshot = request.item
    local best
    if origin == "loot" then best = blockedLoot()
    elseif origin == "quest" then best = blockedQuest()
    elseif origin == "roll" then best = blockedRoll() end
    local requested = request.replacement
    if not best or not requested or best.link ~= requested.link or best.slot ~= requested.slot
        or best.id ~= requested.id or best.choice ~= requested.choice then return end
    local current = inventory.Item(snapshot.bag, snapshot.slot)
    local db = inventory.Settings()
    if not db.enabled or not db.cleanup or not eligible(current, db) or current.itemID ~= snapshot.itemID
        or current.hyperlink ~= snapshot.hyperlink or current.stackCount ~= snapshot.stackCount
        or not makesRoom(best, nil, nil, current) then return end
    container.PickupContainerItem(current.bag, current.slot)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or itemID ~= current.itemID then ClearCursor(); return end
    local attempted = pcall(DeleteCursorItem)
    if not attempted or GetCursorInfo() then
        ClearCursor()
        BaziUI:Print("The client blocked item deletion. Try again after combat if you are still fighting.")
        return
    end
    if BaziUI.ActivityStats then BaziUI.ActivityStats.RecordCleanupDiscard(current.stackCount) end
    if origin ~= "loot" then queueCleanupRefresh(); return end
    pendingLoot = best
    C_Timer.After(1, function()
        if pendingLoot ~= best then return end
        lootAfterDeletion()
        pendingLoot = nil
    end)
end

StaticPopupDialogs.BAZI_INVENTORY_DELETE = {
    text = "Permanently delete %s?",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(_, item) deleteItem(item) end,
    timeout = 0, whileDead = false, hideOnEscape = true,
}

function inventory.CancelCleanupChoice()
    choosing = nil
    if chooseButton then chooseButton:SetText("Choose item") end
end

function inventory.ChooseCleanupItem(item)
    if not choosing then return false end
    if origin == "preview" or not target or not frame:IsShown() then inventory.CancelCleanupChoice(); return false end
    if not eligible(item, inventory.Settings()) or not makesRoom(target, nil, nil, item) then
        BaziUI:Print("Choose an unprotected item that frees compatible bag space.")
        return true
    end
    inventory.CancelCleanupChoice()
    StaticPopup_Show("BAZI_INVENTORY_DELETE", item.name .. " ×" .. item.stackCount, nil,
        {item = item, origin = origin, replacement = target})
    return true
end

local rows, showProtected = {}, false

local function build()
    local header
    frame, header = inventory.Window("BaziUIInventoryCleanup", "Inventory Full", 425, 192, nil, nil, "cleanupOpacity")
    frame.lootLinked, frame.lootAbove = true, true
    frame.closeButton:Hide()
    frame:HookScript("OnHide", function() inventory.CancelCleanupChoice(); inventory.RefreshLoot() end)
    protectedButton = inventory.Button(header, "Protected", 79, function(self)
        showProtected = not showProtected
        self:SetText(showProtected and "Items" or "Protected")
        inventory.RefreshCleanup()
    end)
    protectedButton:SetPoint("RIGHT", -4, 0)
    chooseButton = inventory.Button(header, "Choose item", 91, function(self)
        if choosing then inventory.CancelCleanupChoice(); return end
        if InCombatLockdown() or not target or origin == "preview" or not inventory.OpenBags then return end
        inventory.OpenBags("bags")
        choosing = true
        self:SetText("Cancel choice")
        BaziUI:Print(origin == "loot" and "Click an item in your bags to replace it." or "Click an item in your bags to delete it.")
    end)
    chooseButton:SetPoint("RIGHT", protectedButton, "LEFT", -5, 0)
    content, scroll, scrollbar = inventory.Scroll(frame, -7, 34, true)
    emptyLabel = inventory.Label(content)
    emptyLabel:SetPoint("BOTTOMLEFT", 5, 5)
end

local function makeRow(i)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(43)
    row:SetPoint("BOTTOMLEFT", 0, (i - 1) * 46)
    row:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, (i - 1) * 46)
    row.card = BaziUI.Theme:RoundedCard(row)
    row.card:SetAllPoints()
    row.card:SetFrameLevel(row:GetFrameLevel())
    local icon = CreateFrame("Button", nil, row)
    icon:SetSize(37, 37)
    icon:SetPoint("LEFT", 4, 0)
    row.icon = icon:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    local mask = icon:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziActionSlotMask.tga")
    row.icon:AddMaskTexture(mask)
    local edge = icon:CreateTexture(nil, "OVERLAY")
    edge:SetAllPoints()
    edge:SetAtlas("UI-HUD-ActionBar-IconFrame")
    icon:SetScript("OnClick", function()
        if not showProtected then
            inventory.Settings().ignored[row.item.itemID] = true
            inventory.RefreshCleanup()
        end
    end)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if row.item.hyperlink then GameTooltip:SetHyperlink(row.item.hyperlink)
        else GameTooltip:SetText(row.item.name) end
        if not showProtected then
            GameTooltip:AddLine("Click to protect this item from deletion.", 1, 0.82, 0.42)
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.action = inventory.Button(row, "Replace", 79, function()
        local item = row.item
        if showProtected then
            inventory.Settings().ignored[item.itemID] = false
            inventory.RefreshCleanup()
            return
        end
        local request = {item = item, origin = origin, replacement = target}
        if origin == "loot" and item.quality <= 1 then deleteItem(request)
        else StaticPopup_Show("BAZI_INVENTORY_DELETE", item.name .. " ×" .. item.stackCount, nil, request) end
    end)
    row.action:SetPoint("RIGHT", -5, 0)
    row.title = inventory.Label(row)
    row.title:SetPoint("TOPLEFT", 49, -5)
    row.title:SetPoint("RIGHT", row.action, "LEFT", -6, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.vendor = inventory.Label(row)
    row.vendor:SetPoint("BOTTOMLEFT", 49, 4)
    row.vendor:SetTextColor(1, 0.82, 0.42)
    rows[i] = row
    return row
end

function inventory.RefreshCleanup()
    if not frame or not frame:IsShown() then return end
    local db = inventory.Settings()
    if origin ~= "preview" and (not db.enabled or not db.cleanup) then frame:Hide(); return end
    local fromBottom = math.max(0, scroll:GetVerticalScrollRange() - scroll:GetVerticalScroll())
    frame:ApplyStyle()
    local size = db.cleanupFontSize > 0 and db.cleanupFontSize or nil
    local items = {}
    if origin == "preview" and not showProtected then
        for i = 1, 5 do
            items[i] = {name = "Sample bag item " .. i, stackCount = i, price = 12, iconFileID = 133639}
        end
    elseif showProtected then
        local ids = {}
        for id in pairs(protected) do if db.ignored[id] ~= false then ids[#ids + 1] = id end end
        for id, enabled in pairs(db.ignored) do
            if enabled and not protected[id] then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local name, link, _, _, _, _, _, _, _, icon = inventory.GetItemInfo(id)
            items[#items + 1] = {itemID = id, name = name or ("Item " .. id), hyperlink = link, iconFileID = icon}
        end
    else
        local partial, free = bagCapacity()
        for _, bag in ipairs(inventory.BagIDs(true)) do
            for slot = 1, container.GetContainerNumSlots(bag) do
                local item = inventory.Item(bag, slot)
                if eligible(item, db) and target and makesRoom(target, partial, free, item) then items[#items + 1] = item end
            end
        end
        table.sort(items, function(a, b)
            if value(a) == value(b) then return a.name < b.name end
            return value(a) < value(b)
        end)
    end
    chooseButton:SetEnabled(origin ~= "preview" and not InCombatLockdown())
    emptyLabel:SetText(showProtected and "No protected items" or "No eligible items")
    emptyLabel:SetShown(#items == 0)
    inventory.GeneralFont(emptyLabel, -1, nil, "Inventory:Cleanup", size)
    for i, item in ipairs(items) do
        local row = rows[i] or makeRow(i)
        BaziUI.Theme:PaintQuestCard(row.card)
        row.item = item
        row.icon:SetTexture(item.iconFileID)
        inventory.GeneralFont(row.title, 0, nil, "Inventory:Cleanup", size)
        inventory.GeneralFont(row.vendor, -1, nil, "Inventory:Cleanup", size)
        row.title:SetText(item.name .. (item.stackCount and " ×" .. item.stackCount or ""))
        local delta = (target and target.total or 1250) - (showProtected and 0 or value(item))
        local replace = origin == "loot" or origin == "preview"
        row.vendor:SetText(showProtected and "" or ("Vendor  " .. money(value(item)) .. (replace
            and ((delta >= 0 and "  |cff83cf83+" or "  |cffff795e-") .. money(math.abs(delta)) .. "|r") or "")))
        row.action:SetText(showProtected and "Unprotect" or replace and "Replace" or "Delete")
        row.action:SetEnabled(origin ~= "preview")
        row.icon:GetParent():EnableMouse(origin ~= "preview")
        row:Show()
    end
    for i = #items + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(26, #items * 46))
    frame:SetHeight(41 + math.max(26, math.min(3, #items) * 46))
    scroll:UpdateScrollChildRect()
    scrollbar:SetValue(math.max(0, scroll:GetVerticalScrollRange() - fromBottom))
end

function inventory.CleanupLootTarget()
    if origin == "loot" and frame and frame:IsShown() then return target end
end

function inventory.IsCleanupProtected(id)
    if type(id) ~= "number" then return false end
    local name, _, _, _, _, _, _, _, _, _, _, class = inventory.GetItemInfo(id)
    return class == 12 or not not inventory.RequiredByQuest({itemID = id, name = name})
        or ignored({itemID = id}, inventory.Settings())
end

function inventory.CloseCleanupPreview()
    if origin ~= "preview" then return end
    origin, target = nil, nil
    if frame then frame:Hide() end
    queueCleanupRefresh()
end

local function closeCleanup()
    if not origin or origin == "preview" then return end
    origin, target = nil, nil
    StaticPopup_Hide("BAZI_INVENTORY_DELETE")
    frame:Hide()
end

function inventory.OpenCleanup(source)
    local db = inventory.Settings()
    if source ~= "preview" and (not target or not db.enabled or not db.cleanup) then return end
    if not frame then build() end
    origin, showProtected = source, false
    protectedButton:SetText("Protected")
    chooseButton:SetShown(source ~= "preview")
    frame:SetFrameStrata(source == "loot" and "DIALOG" or "FULLSCREEN_DIALOG")
    frame:Show()
    frame:Raise()
    inventory.ShowFirstUseGuide(frame, "hideCleanupGuideV3", "Inventory Cleanup",
        "When your bags are full, Cleanup selects quest loot first, then the item with the highest vendor value. Click any item in the loot window to choose it instead.\n\nClick Replace beside the bag item to trade it for your selection, or use Choose item to pick from your bags. Delete frees space for a quest reward or loot roll.", "top")
    inventory.RefreshCleanup()
    scrollbar:SetValue(scroll:GetVerticalScrollRange())
    inventory.RefreshLoot()
end

local events = CreateFrame("Frame")
local function refreshLootCleanup()
    queued = nil
    if origin == "preview" then return end
    local db = inventory.Settings()
    if not db.enabled or not db.cleanup then closeCleanup(); return end
    if lootOpen then lootAfterDeletion() end
    local source = "loot"
    target = lootOpen and not pendingLoot and blockedLoot() or nil
    if not target then source, target = "quest", blockedQuest() end
    if not target then source, target = "roll", blockedRoll() end
    if not target then
        closeCleanup()
    elseif origin == source and frame:IsShown() then
        inventory.RefreshCleanup()
        inventory.RefreshLoot()
    else
        StaticPopup_Hide("BAZI_INVENTORY_DELETE")
        inventory.OpenCleanup(source)
    end
end

queueCleanupRefresh = function()
    if queued or not (lootOpen or questBlocked or next(rolls) or origin and origin ~= "preview") then return end
    queued = true
    C_Timer.After(0, refreshLootCleanup)
end

function inventory.NoteQuestTurnIn(id, choice, afterTurnIn)
    if not read(id) or type(id) ~= "number" or id <= 0 then return end
    questOpen = id
    if read(choice) then questAttempt = choice end
    lastTurnIn = {id = id, choice = choice, at = GetTime(), reward = not afterTurnIn and questReward(questAttempt or 0) or nil}
    C_Timer.After(2, function()
        if lastTurnIn and GetTime() - lastTurnIn.at >= 2 and not questBlocked then lastTurnIn = nil end
    end)
end

if AcceptQuest then
    hooksecurefunc("AcceptQuest", function()
        local id = GetQuestID()
        if read(id) and type(id) == "number" and id > 0 then inventory.NoteQuestTurnIn(id, 0, true) end
    end)
end

if CompleteQuest then
    hooksecurefunc("CompleteQuest", function()
        local id = GetQuestID()
        if read(id) and type(id) == "number" and id > 0 then inventory.NoteQuestTurnIn(id, 0) end
    end)
end

if GetQuestReward then
    hooksecurefunc("GetQuestReward", function(choice)
        local id = GetQuestID()
        if not questOpen and read(id) and type(id) == "number" and id > 0 then questOpen = id end
        if questOpen and (not lastTurnIn or lastTurnIn.id ~= questOpen or lastTurnIn.choice ~= choice) then
            inventory.NoteQuestTurnIn(questOpen, choice)
        end
    end)
end
if RollOnLoot then
    hooksecurefunc("RollOnLoot", function(id, choice)
        if read(id) and read(choice) and choice == 0 and rolls[id] then
            rolls[id] = nil
            queueCleanupRefresh()
        end
    end)
end

for _, event in ipairs({"LOOT_OPENED", "LOOT_CLOSED", "LOOT_SLOT_CHANGED", "LOOT_SLOT_CLEARED",
    "BAG_UPDATE_DELAYED", "BAG_OVERFLOW_WITH_FULL_INVENTORY", "GET_ITEM_INFO_RECEIVED", "QUEST_LOG_UPDATE", "UI_ERROR_MESSAGE",
    "QUEST_COMPLETE", "QUEST_PROGRESS", "QUEST_DETAIL", "QUEST_FINISHED", "QUEST_TURNED_IN", "START_LOOT_ROLL", "CANCEL_LOOT_ROLL",
    "CANCEL_ALL_LOOT_ROLLS", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, id, value)
    if event == "LOOT_OPENED" then
        lootOpen, selectedLoot = true, nil
    elseif event == "LOOT_CLOSED" then
        lootOpen, pendingLoot, selectedLoot = nil, nil, nil
        if origin == "loot" then closeCleanup() end
    elseif event == "QUEST_COMPLETE" or event == "QUEST_PROGRESS" or event == "QUEST_DETAIL" then
        local id = GetQuestID()
        questOpen, questAttempt, questBlocked = read(id) and id or true, nil, nil
    elseif event == "QUEST_TURNED_IN" then
        if read(id) and (not lastTurnIn or lastTurnIn.id ~= id) then inventory.NoteQuestTurnIn(id, 0, true) end
    elseif event == "QUEST_FINISHED" then
        if not questBlocked and (not lastTurnIn or GetTime() - lastTurnIn.at > 2) then
            questOpen, questAttempt, lastTurnIn = nil, nil, nil
        end
    elseif event == "START_LOOT_ROLL" then
        if not read(id) or not read(value) or type(id) ~= "number" or type(value) ~= "number" or value <= 0 then return end
        rolls[id] = GetTime() + value / 1000
        C_Timer.After(value / 1000, queueCleanupRefresh)
    elseif event == "CANCEL_LOOT_ROLL" then
        if read(id) and id then rolls[id] = nil end
    elseif event == "CANCEL_ALL_LOOT_ROLLS" then
        wipe(rolls)
    elseif event == "UI_ERROR_MESSAGE" or event == "BAG_OVERFLOW_WITH_FULL_INVENTORY" then
        local isFull = event == "BAG_OVERFLOW_WITH_FULL_INVENTORY"
            or read(value) and (value == ERR_INV_FULL or ERR_BAG_FULL and value == ERR_BAG_FULL)
            or read(id) and Enum and Enum.UIError and id == Enum.UIError.InventoryFull
        if not isFull then return end
        local recent = lastTurnIn and GetTime() - lastTurnIn.at <= 2
        if recent or questOpen and not lootOpen then
            local _, free = bagCapacity()
            questBlocked = questBlocked or free[0] + 1
        end
    end
    queueCleanupRefresh()
end)
