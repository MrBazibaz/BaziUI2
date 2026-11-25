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
    frame:SetWidth(inventory.Settings().lootWidth)
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
        fill:SetColorTexture(0.045, 0.026, 0.012, (db[frame.backgroundKey or opacityKey] or db.opacity) / 100)
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

function inventory.Scroll(parent, top, bottom)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT", 8, top)
    scroll:SetPoint("BOTTOMRIGHT", -24, bottom)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(9)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.14, 0.08, 0.04, 0.45)
    local gem = bar:CreateTexture(nil, "OVERLAY")
    addon.Theme:StyleScrollThumb(gem)
    bar:SetThumbTexture(gem)
    bar:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(math.max(0, math.min(scroll:GetVerticalScrollRange(), bar:GetValue() - delta * 32)))
    end)
    scroll:SetScript("OnScrollRangeChanged", function(_, _, range)
        bar:SetMinMaxValues(0, math.max(1, range))
        bar:SetValue(math.min(range, bar:GetValue()))
        bar:SetShown(range > 0)
    end)
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
