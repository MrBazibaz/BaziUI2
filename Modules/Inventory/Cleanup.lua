local inventory = BaziUI.Inventory
local container = C_Container
local frame, content, emptyLabel, scroll, scrollbar, protectedButton
function inventory.GetCleanupMoverFrame() return frame end
local origin, pendingLoot, target
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

local function eligible(item, settings)
    if not (item and item.name and item.price and item.stackCount and item.hyperlink and not item.isLocked
        and item.quality and item.quality <= settings.maxDeleteQuality and item.class ~= 12
        and not ignored(item, settings)) then return false end
    local quest = container.GetContainerItemQuestInfo and container.GetContainerItemQuestInfo(item.bag, item.slot)
    return not (quest and (quest.isQuestItem or quest.questID))
end

local function lootItem(slot)
    local link = GetLootSlotLink(slot)
    if type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then return end
    local id = tonumber(link:match("|Hitem:(%d+)"))
    if not id then return end
    local _, _, count, _, _, locked, isQuestItem = GetLootSlotInfo(slot)
    if issecretvalue and (issecretvalue(count) or issecretvalue(locked) or issecretvalue(isQuestItem)) then return end
    if locked then return end
    local _, _, _, _, _, _, _, stack, _, _, price, class = inventory.GetItemInfo(link)
    if not stack or stack <= 0 then return end
    count = count or 1
    return {slot = slot, id = id, link = link, count = count, stack = stack,
        quest = isQuestItem == true or class == 12, total = (price or 0) * count}
end

local function bagCapacity()
    local partial, free = {}, {}
    for _, bag in ipairs(inventory.BagIDs()) do
        local slots, family = container.GetContainerNumFreeSlots(bag)
        family = family or 0
        free[family] = (free[family] or 0) + (slots or 0)
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
    return partial, free
end

local function fits(item, partial, free)
    if not partial then partial, free = bagCapacity() end
    local remaining = item.count
    for _, count in ipairs(partial[item.id] or {}) do
        remaining = remaining - math.max(0, item.stack - count)
    end
    local needed = math.ceil(remaining / item.stack)
    local available = free[0] or 0
    if needed <= available then return true end
    local familyOf = C_Item and C_Item.GetItemFamily or GetItemFamily
    local family = familyOf and familyOf(item.link) or 0
    if bit and family ~= 0 then
        for bagFamily, slots in pairs(free) do
            if bit.band(family, bagFamily) ~= 0 then available = available + slots end
        end
    end
    return needed <= available
end

local function blockedLoot()
    local best, partial, free
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
    if GetCursorInfo() or InCombatLockdown() then return end
    local snapshot = request.item
    local best = request.origin == "loot" and blockedLoot()
    if not best or not request.replacement or best.link ~= request.replacement.link
        or best.slot ~= request.replacement.slot then return end
    local current = inventory.Item(snapshot.bag, snapshot.slot)
    local db = inventory.Settings()
    if not db.enabled or not db.cleanup or not eligible(current, db) or current.itemID ~= snapshot.itemID
        or current.hyperlink ~= snapshot.hyperlink or current.stackCount ~= snapshot.stackCount then return end
    container.PickupContainerItem(current.bag, current.slot)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or itemID ~= current.itemID then ClearCursor(); return end
    DeleteCursorItem()
    if GetCursorInfo() then ClearCursor(); return end
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

local rows, showProtected = {}, false

local function build()
    local header
    frame, header = inventory.Window("BaziUIInventoryCleanup", "Cleanup", 425, 192, nil, nil, "cleanupOpacity")
    frame.lootLinked, frame.lootAbove = true, true
    frame.closeButton:Hide()
    frame:HookScript("OnHide", function() inventory.RefreshLoot() end)
    protectedButton = inventory.Button(header, "Protected", 79, function(self)
        showProtected = not showProtected
        self:SetText(showProtected and "Items" or "Protected")
        inventory.RefreshCleanup()
    end)
    protectedButton:SetPoint("RIGHT", -4, 0)
    content, scroll, scrollbar = inventory.Scroll(frame, -7, 34)
    emptyLabel = inventory.Label(content)
    emptyLabel:SetPoint("BOTTOMLEFT", 5, 5)
end

local function makeRow(i)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(43)
    row:SetPoint("BOTTOMLEFT", 0, (i - 1) * 46)
    row:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, (i - 1) * 46)
    local fill = row:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.035, 0.025, 0.018, 0.72)
    local line = row:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(0.72, 0.58, 0.37, 0.43)
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
    row.action = inventory.Button(row, "Delete", 69, function()
        local item = row.item
        if showProtected then
            inventory.Settings().ignored[item.itemID] = false
            inventory.RefreshCleanup()
            return
        end
        StaticPopup_Show("BAZI_INVENTORY_DELETE", item.name .. " ×" .. item.stackCount, nil,
            {item = item, origin = origin, replacement = target})
    end)
    row.action:SetPoint("RIGHT", -5, 0)
    row.title = inventory.Label(row)
    row.title:SetPoint("TOPLEFT", 49, -5)
    row.title:SetPoint("RIGHT", row.action, "LEFT", -6, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.price = inventory.Label(row)
    row.price:SetPoint("BOTTOMRIGHT", row.action, "LEFT", -8, 4)
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
        for _, bag in ipairs(inventory.BagIDs()) do
            for slot = 1, container.GetContainerNumSlots(bag) do
                local item = inventory.Item(bag, slot)
                if eligible(item, db) then items[#items + 1] = item end
            end
        end
        table.sort(items, function(a, b)
            if value(a) == value(b) then return a.name < b.name end
            return value(a) < value(b)
        end)
    end
    emptyLabel:SetText(showProtected and "No protected items" or "No eligible items")
    emptyLabel:SetShown(#items == 0)
    inventory.GeneralFont(emptyLabel, -1, nil, "Inventory:Cleanup", size)
    for i, item in ipairs(items) do
        local row = rows[i] or makeRow(i)
        row.item = item
        row.icon:SetTexture(item.iconFileID)
        inventory.GeneralFont(row.title, 0, nil, "Inventory:Cleanup", size)
        inventory.GeneralFont(row.price, -1, nil, "Inventory:Cleanup", size)
        inventory.GeneralFont(row.vendor, -1, nil, "Inventory:Cleanup", size)
        row.title:SetText(item.name .. (item.stackCount and " ×" .. item.stackCount or ""))
        row.vendor:SetText(showProtected and "" or
            (item.stackCount > 1 and ("Vendor  ·  " .. money(item.price) .. " each") or "Vendor"))
        row.price:SetText(showProtected and "" or money(value(item)))
        row.action:SetText(showProtected and "Unprotect" or "Delete")
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

function inventory.CloseCleanupPreview()
    if origin == "preview" and frame then frame:Hide() end
end

local function closeLootCleanup()
    if origin ~= "loot" then return end
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
    frame:SetFrameStrata(source == "preview" and "FULLSCREEN_DIALOG" or "DIALOG")
    frame:Show()
    frame:Raise()
    inventory.RefreshCleanup()
    scrollbar:SetValue(scroll:GetVerticalScrollRange())
    inventory.RefreshLoot()
end

local events = CreateFrame("Frame")
local lootOpen, queued
local function refreshLootCleanup()
    queued = nil
    if not lootOpen or origin == "preview" then return end
    local db = inventory.Settings()
    if not db.enabled or not db.cleanup then closeLootCleanup(); return end
    lootAfterDeletion()
    if not lootOpen then return end
    target = not pendingLoot and blockedLoot() or nil
    if not target then
        closeLootCleanup()
    elseif origin == "loot" and frame:IsShown() then
        inventory.RefreshCleanup()
        inventory.RefreshLoot()
    else
        inventory.OpenCleanup("loot")
    end
end

for _, event in ipairs({"LOOT_OPENED", "LOOT_CLOSED", "LOOT_SLOT_CHANGED", "LOOT_SLOT_CLEARED",
    "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "LOOT_OPENED" then
        lootOpen = true
    elseif event == "LOOT_CLOSED" then
        lootOpen, pendingLoot = nil, nil
        closeLootCleanup()
        return
    end
    if lootOpen and not queued then
        queued = true
        C_Timer.After(0, refreshLootCleanup)
    end
end)
