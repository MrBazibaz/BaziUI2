local addon = BaziUI
local inventory = {}
addon.Inventory = inventory

local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
function inventory.GetItemInfo(item)
    if getItemInfo and item then return getItemInfo(item) end
end

local defaults = {
    lootWidth = 425, lootX = 245, lootY = 105,
    cleanupWidth = 465, cleanupHeight = 340, cleanupFontSize = 0, cleanupX = 0, cleanupY = 0,
    enabled = false, columns = 10, bankColumns = 12, guildColumns = 14,
    size = 32, fontSize = 12, opacity = 85, x = 280, y = -150,
    hideEmptyCategory = true, capacityFontSize = 10,
    rollX = 265, rollY = 120, openRoll = true, rolls = true, cleanup = true,
    rollGlow = true, rollTips = true, rollAnimations = true,
    maxDeleteQuality = 2,
    quality = true, junk = true, unusable = true, flash = true,
    merchant = true, bank = true, auction = true, guild = true,
}
local addedCategories = {"Hearthstone", "Projectile", "Spell Reagents", "Recipes", "Bags", "Quivers", "Keys", "Miscellaneous"}

function inventory.Settings()
    local profile = addon.db.profile
    profile.inventory = profile.inventory or {}
    local db = profile.inventory
    if not db.capacityIconsUpdated then
        db.hideEmptyCategory = true
        db.capacityIconsUpdated = true
    end
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end
    db.categories = db.categories or {"Quest", "Consumables", "Equipment", "Trade Goods", "Other", "Junk"}
    if not db.expandedCategories then
        local existing = {}
        for _, name in ipairs(db.categories) do existing[name:lower()] = true end
        local insertAt = #db.categories + 1
        for i, name in ipairs(db.categories) do if name == "Other" then insertAt = i; break end end
        for _, name in ipairs(addedCategories) do
            if not existing[name:lower()] then
                table.insert(db.categories, insertAt, name)
                insertAt = insertAt + 1
            end
        end
        db.expandedCategories = true
    end
    db.emptyFontSize = db.emptyFontSize or db.fontSize
    db.cleanupOpacity = db.cleanupOpacity or db.opacity
    db.rollOpacity = db.rollOpacity or db.opacity
    db.lootOpacity = db.lootOpacity or db.opacity
    if db.lootSkin == nil then db.lootSkin = true end
    db.assignments = db.assignments or {}
    db.ignored = db.ignored or {}
    return db
end

local lootAnchor, lootDragOwner
local temporaryLootX, temporaryLootY
function inventory.LootAnchor()
    if not lootAnchor then
        lootAnchor = CreateFrame("Frame", nil, UIParent)
        lootAnchor:SetSize(1, 1)
        lootAnchor:EnableMouse(false)
        lootAnchor:SetMovable(true)
    end
    if lootDragOwner then return lootAnchor end
    local db = inventory.Settings()
    lootAnchor:ClearAllPoints()
    lootAnchor:SetPoint("TOP", UIParent, "CENTER", temporaryLootX or db.lootX, temporaryLootY or db.lootY)
    return lootAnchor
end

function inventory.StartLootDrag(owner)
    if lootDragOwner or InCombatLockdown() then return end
    local anchor = inventory.LootAnchor()
    lootDragOwner = owner
    anchor:StartMoving()
end

function inventory.StopLootDrag(owner)
    if lootDragOwner ~= owner then return end
    lootAnchor:StopMovingOrSizing()
    local cx, cy = UIParent:GetCenter()
    local x, y = lootAnchor:GetCenter(), lootAnchor:GetTop()
    if x and y then temporaryLootX, temporaryLootY = x - cx, y - cy end
    lootDragOwner = nil
    inventory.LootAnchor()
end

function inventory.ResetLootPosition()
    if lootDragOwner then
        lootAnchor:StopMovingOrSizing()
        lootDragOwner = nil
    end
    temporaryLootX, temporaryLootY = nil, nil
    if lootAnchor then inventory.LootAnchor() end
end

function inventory.PositionLootWindow(frame, above)
    local anchor = inventory.LootAnchor()
    local loot = inventory.VisibleLoot and inventory.VisibleLoot()
    if loot == frame then loot = nil end
    frame:ClearAllPoints()
    if above then frame:SetPoint("BOTTOM", loot or anchor, "TOP", 0, 0)
    elseif loot then frame:SetPoint("TOP", loot, "BOTTOM", 0, 0)
    else frame:SetPoint("TOP", anchor, "TOP", 0, 0) end
    frame:SetWidth(loot and loot:GetWidth() or inventory.Settings().lootWidth)
end

function inventory.Label(parent, font)
    return parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
end

function inventory.GeneralFont(label, offset, flags, scope, baseSize)
    local typography = addon.Typography
    typography.Apply(label, scope or "Inventory:Header", typography.Path(addon.db.profile.font),
        math.max(8, (baseSize or typography.BaseSize()) + (offset or 0)), flags or "", true)
end

function inventory.HeaderColor()
    local chat = addon.Chat
    if chat and chat.active and chat.Skin and chat.Skin.DockHeaderColor then
        return chat.Skin.DockHeaderColor()
    end
    local quest = addon.db.profile.questTracker
    if quest and quest.headerColor then
        local color = quest.headerColor
        return color[1], color[2], color[3], 0.95
    end
    return 0.24, 0.17, 0.10, 0.95
end

function inventory.Money(copper)
    copper = math.floor(math.max(0, tonumber(copper) or 0))
    local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12|t" end
    if silver > 0 then parts[#parts + 1] = silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12|t" end
    if copper % 100 > 0 or #parts == 0 then
        parts[#parts + 1] = (copper % 100) .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12|t"
    end
    return table.concat(parts, " ")
end

function inventory.Button(parent, text, width, handler)
    local button = addon.Theme:CreateButton(parent, text, width, 23)
    button:SetScript("OnClick", handler)
    return button
end

function inventory.Window(name, title, width, height, xKey, yKey, opacityKey)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    local inset = 3
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", inset, -inset)
    fill:SetPoint("BOTTOMRIGHT", -inset, inset)
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", inset, -inset)
    header:SetPoint("TOPRIGHT", -inset, -inset)
    header:SetHeight(27)
    local band = header:CreateTexture(nil, "BACKGROUND")
    band:SetAllPoints()
    local caption = inventory.Label(header, "GameFontNormal")
    caption:SetPoint("LEFT", 10, 0)
    caption:SetText(title)
    local close = inventory.Button(header, "×", 25, function() frame:Hide() end)
    close:SetPoint("RIGHT", -2, 0)
    frame.closeButton = close
    frame.border = addon.Theme:CreateFrameBorder(frame, frame, frame)
    addon.Theme:AddDropShadow("Inventory", frame, frame.border)
    frame.border:SetFrameLevel(header:GetFrameLevel() + 1)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if frame.lootLinked then inventory.StartLootDrag(header); return end
        if frame.inventoryGrowth and InCombatLockdown() then return end
        if not inventory.Settings().locked then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function()
        if frame.lootLinked then inventory.StopLootDrag(header); return end
        if frame.inventoryGrowth and InCombatLockdown() then return end
        frame:StopMovingOrSizing()
        if xKey then
            local x, y = frame:GetCenter()
            local cx, cy = UIParent:GetCenter()
            local db = inventory.Settings()
            if frame.inventoryGrowth then y = db.growUp and frame:GetBottom() or frame:GetTop() end
            db[xKey], db[yKey] = math.floor(x - cx + 0.5), math.floor(y - cy + 0.5)
            frame:ApplyStyle()
        end
    end)
    header:HookScript("OnHide", function()
        if frame.lootLinked then inventory.StopLootDrag(header) end
    end)
    function frame:ApplyStyle()
        local db = inventory.Settings()
        if frame.inventoryGrowth or frame.lootAbove then
            header:ClearAllPoints()
            local side = (frame.lootAbove or db.growUp) and "BOTTOM" or "TOP"
            local y = side == "BOTTOM" and inset or -inset
            header:SetPoint(side .. "LEFT", frame, side .. "LEFT", inset, y)
            header:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -inset, y)
        end
        inventory.GeneralFont(caption, 0, "OUTLINE")
        local headerKey = frame.headerStyleKey or (opacityKey == "rollOpacity" and "rolls")
            or (opacityKey == "cleanupOpacity" and "cleanup") or "inventory"
        caption:SetTextColor(addon.Headers.Text(headerKey, 1, 0.82, 0.49))
        fill:SetColorTexture(0.045, 0.026, 0.012, (frame.baziOpacity or db[frame.backgroundKey or opacityKey] or db.opacity) / 100)
        band:SetColorTexture(addon.Headers.Fill(headerKey, inventory.HeaderColor()))
        frame.border:SetShown(not db.removeBorder)
        if frame.lootLinked then inventory.PositionLootWindow(frame, frame.lootAbove)
        elseif xKey then
            frame:ClearAllPoints()
            local point = frame.inventoryGrowth and (db.growUp and "BOTTOM" or "TOP") or "CENTER"
            frame:SetPoint(point, UIParent, "CENTER", db[xKey], db[yKey])
        elseif not frame:GetPoint() then
            frame:SetPoint("CENTER")
        end
    end
    frame:ApplyStyle()
    return frame, header, caption
end

function inventory.MoveCategory(from, to)
    local categories = inventory.Settings().categories
    if from == to or not categories[from] or not categories[to] then return end
    table.insert(categories, to, table.remove(categories, from))
    inventory.RefreshBags()
end

function inventory.Scroll(parent, top, bottom, questRail)
    local compact = questRail == "compact"
    questRail = questRail and not compact
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT", questRail and 12 or 8, top)
    scroll:SetPoint("BOTTOMRIGHT", questRail and -8 or -24, bottom)
    if questRail then scroll:SetClipsChildren(true) end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(compact and 7 or 9)
    local ornament
    if questRail then
        ornament = addon.Theme:RailOrnament(parent, parent, 6)
        bar:SetPoint("TOP", scroll, "TOPLEFT", -5.5, 0)
        bar:SetPoint("BOTTOM", scroll, "BOTTOMLEFT", -5.5, 0)
        bar:SetFrameLevel(scroll:GetFrameLevel() + 3)
    elseif compact then
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 0, 0)
    else
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    end
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP")
    track:SetPoint("BOTTOM")
    track:SetWidth(compact and 1 or 2)
    track:SetColorTexture(addon.Theme:AccentInk(0.30))
    track:SetShown(not questRail)
    local gem = bar:CreateTexture(nil, "OVERLAY")
    addon.Theme:StyleScrollThumb(gem)
    local thumb
    if compact then
        thumb = bar:CreateTexture(nil, "OVERLAY")
        thumb:SetWidth(4)
        gem:SetAlpha(0)
    end
    local function placeThumb(value)
        local range = scroll:GetVerticalScrollRange()
        if thumb and range > 0.5 then
            addon.Theme:PlaceRailThumb(bar, thumb, gem, scroll:GetHeight(), range, value / range, 26)
        end
    end
    bar:SetThumbTexture(gem)
    bar:SetScript("OnValueChanged", function(_, value)
        scroll:SetVerticalScroll(value)
        if compact then placeThumb(value) end
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        if scroll.baziAllowScroll == false then return end
        bar:SetValue(math.max(0, math.min(scroll:GetVerticalScrollRange(), bar:GetValue() - delta * 32)))
    end)
    function bar:SyncRange()
        local range = scroll.baziAllowScroll == false and 0 or math.max(0, scroll:GetVerticalScrollRange())
        if compact then
            track:SetColorTexture(addon.Theme:AccentInk(0.30))
            thumb:SetColorTexture(addon.Theme:AccentInk(0.85))
        else
            addon.Theme:PaintScrollRail(track, gem, scroll:GetHeight(), range)
        end
        if ornament then
            addon.Theme:ColorRailOrnament(ornament, true, true)
            gem:SetWidth(4)
        end
        bar:SetMinMaxValues(0, math.max(1, range))
        bar:SetValue(math.min(range, bar:GetValue()))
        if compact then placeThumb(bar:GetValue()) end
        bar:SetShown(range > 0.5)
    end
    scroll:SetScript("OnScrollRangeChanged", function() bar:SyncRange() end)
    scroll:HookScript("OnShow", function() bar:SyncRange() end)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    bar:Hide()
    return content, scroll, bar
end

function inventory.BagIDs(includeSpecial)
    local ids = {}
    local index = Enum and Enum.BagIndex
    if index and index.Bag_4 then
        ids = {index.Backpack, index.Bag_1, index.Bag_2, index.Bag_3, index.Bag_4}
        if includeSpecial and index.ReagentBag then ids[#ids + 1] = index.ReagentBag end
        if includeSpecial and index.Keyring then ids[#ids + 1] = index.Keyring end
    else
        for bag = 0, (NUM_BAG_SLOTS or 4) do ids[#ids + 1] = bag end
    end
    return ids
end

inventory.capacityLabels = {general = "Bags", ammo = "Quiver", reagent = "Reagent"}
inventory.capacityOrder = {"general", "ammo", "reagent"}

local function canRead(value)
    return (not issecretvalue or not issecretvalue(value)) and (not canaccessvalue or canaccessvalue(value))
end

function inventory.BagKind(bag, family)
    local index = Enum and Enum.BagIndex
    if index and index.ReagentBag == bag then return "reagent" end
    if index and index.Keyring == bag then return end
    if not canRead(family) then return end
    if family and family >= 1 and family <= 3 then return "ammo" end
    if not family or family == 0 then return "general" end
    return "reagent"
end

function inventory.Capacity()
    local capacity = {}
    for _, bag in ipairs(inventory.BagIDs(true)) do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        local total = C_Container.GetContainerNumSlots(bag)
        local kind = inventory.BagKind(bag, family)
        if kind and canRead(total) and type(total) == "number" and total > 0
            and canRead(free) and type(free) == "number" then
            local row = capacity[kind] or {total = 0, free = 0}
            row.total, row.free = row.total + total, row.free + free
            capacity[kind] = row
        end
    end
    return capacity
end

function inventory.QuestStarter(bag, slot)
    local quest = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
    return quest and quest.questID and (not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted
        or not C_QuestLog.IsQuestFlaggedCompleted(quest.questID)) and not quest.isActive and quest.questID
end

local questItems, questNames
local function cacheQuestItems()
    questItems, questNames = {}, {}
    local tracker = BaziUI.QuestTracker
    local objectives = C_QuestLog and C_QuestLog.GetQuestObjectives
    if not (tracker and tracker.DashboardQuests and objectives) then return end
    for id, entry in pairs(tracker.DashboardQuests()) do
        for _, objective in ipairs(objectives(id) or {}) do
            local itemID = objective.itemID or objective.itemId
            local title = entry.info.title
            if itemID then questItems[itemID] = title end
            if objective.type == "item" then
                local text = objective.text or ""
                local name = text:match("^(.-)%s*:%s*%d+%s*/%s*%d+$")
                    or text:match("^%d+%s*/%s*%d+%s+(.+)$") or text
                if name ~= "" then questNames[name:lower()] = title end
            end
        end
    end
end

function inventory.RequiredByQuest(item)
    if not item or not canRead(item.itemID) or not item.itemID then return end
    if not questItems then cacheQuestItems() end
    local name = item.name or item.itemName
    return questItems[item.itemID] or (canRead(name) and type(name) == "string" and questNames[name:lower()] or nil)
end

local questEvents = CreateFrame("Frame")
questEvents:RegisterEvent("QUEST_LOG_UPDATE")
questEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
questEvents:SetScript("OnEvent", function() questItems, questNames = nil, nil end)

function inventory.Item(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return end
    local name, _, quality, _, _, _, _, _, _, _, price, class = inventory.GetItemInfo(info.hyperlink or info.itemID)
    info.name, info.price, info.class = name, price, class
    info.quality = quality or info.quality
    info.bag, info.slot = bag, slot
    return info
end

function inventory.Full()
    for _, bag in ipairs(inventory.BagIDs()) do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if (free or 0) > 0 and (family or 0) == 0 then return false end
    end
    return true
end
