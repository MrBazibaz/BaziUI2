local addon, A = BaziUI, BaziUI.Adventure
local call, read = A.Call, A.Read
local E = {profiles = {"Leveling", "PvE", "PvP", "Tank", "Healer", "Custom"}}
addon.EquipmentAdvisor = E

local slots = {
    INVTYPE_HEAD = {"Head"}, INVTYPE_NECK = {"Neck"}, INVTYPE_SHOULDER = {"Shoulder"}, INVTYPE_CLOAK = {"Back"},
    INVTYPE_CHEST = {"Chest"}, INVTYPE_ROBE = {"Chest"}, INVTYPE_WRIST = {"Wrist"}, INVTYPE_HAND = {"Hands"},
    INVTYPE_WAIST = {"Waist"}, INVTYPE_LEGS = {"Legs"}, INVTYPE_FEET = {"Feet"}, INVTYPE_FINGER = {"Finger0", "Finger1"},
    INVTYPE_TRINKET = {"Trinket0", "Trinket1"}, INVTYPE_WEAPON = {"MainHand", "SecondaryHand"},
    INVTYPE_WEAPONMAINHAND = {"MainHand"}, INVTYPE_WEAPONOFFHAND = {"SecondaryHand"}, INVTYPE_HOLDABLE = {"SecondaryHand"},
    INVTYPE_SHIELD = {"SecondaryHand"}, INVTYPE_2HWEAPON = {"MainHand"}, INVTYPE_RANGED = {"Ranged"},
    INVTYPE_RANGEDRIGHT = {"Ranged"}, INVTYPE_THROWN = {"Ranged"}, INVTYPE_RELIC = {"Ranged"},
}
local labels = {
    ITEM_MOD_STRENGTH_SHORT = "Strength", ITEM_MOD_AGILITY_SHORT = "Agility", ITEM_MOD_STAMINA_SHORT = "Stamina",
    ITEM_MOD_INTELLECT_SHORT = "Intellect", ITEM_MOD_SPIRIT_SHORT = "Spirit", ITEM_MOD_ATTACK_POWER_SHORT = "Attack power",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Weapon DPS", ITEM_MOD_SPELL_POWER_SHORT = "Spell power",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Spell damage", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "Healing",
    ITEM_MOD_CRIT_RATING_SHORT = "Crit", ITEM_MOD_HIT_RATING_SHORT = "Hit", ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Defense",
    ITEM_MOD_BLOCK_VALUE_SHORT = "Block value", ITEM_MOD_ARMOR_SHORT = "Armor", RESISTANCE0_NAME = "Armor",
}
E.StatLabels = labels

local metadata, count = {}, 0
function E.Item(link)
    if not read(link) or not A.ID(link) then return end
    if metadata[link] then return metadata[link] end
    if type(link) == "string" and not link:find("item:", 1, true) then link = A.ID(link) end
    local native = C_Item
    local name, canonical, quality, level, required, _, _, _, equip, icon, price, class, sub, binding =
        call(native and native.GetItemInfo or GetItemInfo, link)
    if type(name) ~= "string" or not (read(equip) and read(quality) and read(required) and read(class) and read(sub)
        and read(binding) and read(price) and read(canonical) and read(level) and read(icon)) then return end
    local input = type(link) == "string" and link:find("item:", 1, true) and link or canonical or A.ID(link)
    local raw = slots[equip] and call(native and native.GetItemStats or GetItemStats, input)
    local stats
    if type(raw) == "table" then
        stats = {}
        for name, value in pairs(raw) do
            if read(name) and read(value) and type(name) == "string" and type(value) == "number" then stats[name] = value end
        end
    end
    local unique, _, limit, category
    if slots[equip] then unique, _, limit, category = call(native and native.GetItemUniquenessByID, input) end
    local item = {name = name, link = input, quality = quality, level = level, required = required, equip = equip, icon = icon,
        unique = unique == true, limit = read(limit) and limit or nil, category = read(category) and category or nil,
        price = price, class = class, sub = sub, binding = binding, stats = stats, id = A.ID(input)}
    if count >= 420 then metadata, count = {}, 0 end
    if stats or not slots[equip] then metadata[link], count = item, count + 1 end
    return item
end

function E.CharacterProfile(key, profile, create)
    local data = A.Data()
    if not data or not key then return end
    local record = data.weights[key]
    if not record and create then record = {active = "Custom", profiles = {}}; data.weights[key] = record end
    if not record then return end
    local name = profile or record.active
    if create and not record.profiles[name] then record.profiles[name] = {weights = {}} end
    return record.profiles[name], record
end

function E.ActiveProfile(key)
    local _, record = E.CharacterProfile(key)
    return record and record.active or "Custom"
end

local function status(delta, future, usable, scored)
    if future then return "Future comparison" end
    if usable == false then return "Requirements unmet" end
    if not scored then return "Stat differences" end
    if delta > 0.001 then return "Potential upgrade" end
    if delta < -0.001 then return "Lower profile score" end
    return "Sidegrade"
end

local function comparison(item, gear, slot, profile, eligibility, resolve)
    local previous = gear[slot]
    if not previous then return end
    local old = resolve(previous, slot)
    if (previous.id or previous.link) and not (old and old.stats) then return end
    if slot == "SecondaryHand" then
        local main = gear.MainHand
        local mainItem = main and resolve(main, "MainHand")
        if not main or main.id and not mainItem or mainItem and mainItem.equip == "INVTYPE_2HWEAPON" then return end
        -- An empty off hand does not confirm dual-wield proficiency.
        if item.equip == "INVTYPE_WEAPON" and not (old and old.class == item.class) then return end
    end
    local removed = {old}
    if item.equip == "INVTYPE_2HWEAPON" then
        local off = gear.SecondaryHand
        if not off then return end
        if off.id or off.link then
            local offItem = resolve(off, "SecondaryHand")
            if not (offItem and offItem.stats) then return end
            removed = old and {old, offItem} or {offItem}
        end
    end
    if item.unique or item.limit and item.category then
        local copies, excluded = 0, {[slot] = true}
        if item.equip == "INVTYPE_2HWEAPON" then excluded.SecondaryHand = true end
        for name, piece in pairs(gear) do
            if not excluded[name] then
                local entry = resolve(piece, name)
                if item.unique and piece.id == item.id or item.category and entry and entry.category == item.category then
                    copies = copies + 1
                end
            end
        end
        if copies >= (item.limit or 1) then return end
    end
    local delta, score, baseline, weighted = {}, 0, 0, false
    for stat, value in pairs(item.stats) do delta[stat] = value end
    local weights = profile and profile.weights or {}
    for _, worn in ipairs(removed) do
        for stat, value in pairs(worn.stats) do
            delta[stat] = (delta[stat] or 0) - value
            baseline = baseline + value * (weights[stat] or 0)
        end
    end
    for stat, weight in pairs(weights) do
        if type(weight) == "number" and weight ~= 0 and delta[stat] ~= nil then
            weighted = true
            score = score + delta[stat] * weight
        end
    end
    local label = status(score, eligibility.future, eligibility.usable, weighted)
    return {slot = slot, old = old, removed = removed, deltas = delta, score = weighted and score or nil,
        before = weighted and baseline or nil, after = weighted and baseline + score or nil,
        percent = weighted and baseline > 0 and 100 * score / baseline or nil, label = label}
end

function E.Compare(item, player, gear, profile, usable, resolve)
    resolve = resolve or function(piece) return piece.comparison or E.Item(piece.link or piece.id) end
    local choices = slots[item.equip]
    if not choices or not item.stats or not gear then return {} end
    local future = type(item.required) == "number" and type(player.level) == "number" and item.required > player.level
    local result = {}
    for _, slot in ipairs(choices) do
        local row = comparison(item, gear, slot, profile, {future = future, usable = usable}, resolve)
        if row then result[#result + 1] = row end
    end
    table.sort(result, function(a, b)
        if a.score == b.score then return a.slot < b.slot end
        return (a.score or 0) > (b.score or 0)
    end)
    return result, future
end

function E.ForPlayer(item)
    local player = A.current
    if not player or not player.identity then return {} end
    local usable = call(C_Item and C_Item.IsUsableItem or IsUsableItem, item.link)
    local profile = E.CharacterProfile(player.identity.key)
    local rows, future = E.Compare(item, player.identity, player.gear, profile, usable)
    return rows, future, usable
end

local function observedType(item, char)
    if item.equip == "INVTYPE_FINGER" or item.equip == "INVTYPE_TRINKET" or item.equip == "INVTYPE_NECK" then return true end
    for _, piece in pairs(char.gear or {}) do
        local old = piece.comparison or E.Item(piece.link or piece.id)
        if old and old.sub == item.sub and old.class == item.class then return true end
    end
    return false
end

function E.ForAlts(item, transferable, characters, player)
    local M = addon.AltManager
    player = player or A.current and A.current.identity
    local result = {}
    local bind = Enum and Enum.ItemBind
    if item.binding ~= (bind and bind.None or 0) and item.binding ~= (bind and bind.OnEquip or 2) then return result end
    -- Loot can be known unbound, whereas an ordinary item link does not reveal its current binding.
    if transferable ~= true or not (M and player) then return result end
    for key, char in pairs(characters or M.Characters()) do
        local meta = char.identity
        if key ~= player.key and M.SameTransferGroup(meta, player) and type(meta.level) == "number"
            and type(item.required) == "number" and meta.level >= item.required and observedType(item, char) then
            local profile = E.CharacterProfile(key)
            local options = E.Compare(item, meta, char.gear, profile)
            local best = options[1]
            if best and best.score and best.score > 0.001 then
                result[#result + 1] = {identity = meta, comparison = best, updated = char.updated, key = key}
            end
        end
    end
    table.sort(result, function(a, b)
        if a.comparison.score == b.comparison.score then return a.key < b.key end
        return a.comparison.score > b.comparison.score
    end)
    return result
end

local function formatDelta(value)
    return ("%+.2f"):format(value):gsub("0+$", ""):gsub("%.$", "")
end

function E.DeltaRows(result)
    local rows = {}
    for stat, value in pairs(result.deltas) do
        if value ~= 0 then
            local label = labels[stat] or _G[stat] or stat:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "):lower()
            rows[#rows + 1] = {label = label, value = formatDelta(value), color = value > 0 and {0.56, 0.80, 0.50} or {0.86, 0.47, 0.42}}
        end
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    return rows
end

local function knownTransferable(frame, item)
    local bind = Enum and Enum.ItemBind
    local boe = bind and bind.OnEquip or 2
    local notBound = bind and bind.None or 0
    if item.binding == notBound then return true end
    if item.binding ~= boe then return false end
    local owner = frame.GetOwner and frame:GetOwner()
    if owner and owner.drop and owner.drop.link == item.link and not owner.drop.finished then return true end
    return owner and owner.item and owner.item.hyperlink == item.link and read(owner.item.isBound) and owner.item.isBound == false or false
end

function E.AddTooltip(frame, link)
    local cfg = A.Settings("advisor")
    if not (cfg.enabled and cfg.tooltip) or cfg.shift and not IsShiftKeyDown() then return end
    local owner = frame.GetOwner and frame:GetOwner()
    local name = owner and owner.GetName and owner:GetName()
    if type(name) == "string" and name:find("QuestInfoRewards", 1, true) and not cfg.quests then return end
    local item = E.Item(link)
    if not (item and slots[item.equip]) then return end
    local results, future, usable = E.ForPlayer(item)
    if future then frame:AddLine("Requires level " .. item.required, 0.86, 0.72, 0.50)
    elseif usable == false then frame:AddLine("Requirements unmet", 0.86, 0.49, 0.43) end
    for index, result in ipairs(results) do
        local slot = A.SlotNames[result.slot] or result.slot
        local score = result.percent and (" · %+.1f%%"):format(result.percent) or result.score and (" · %s pts"):format(formatDelta(result.score)) or ""
        frame:AddDoubleLine(slot, result.label .. score, 0.81, 0.68, 0.88, 0.91, 0.82, 0.70)
        if index == 1 or cfg.expanded then
            local rows = E.DeltaRows(result)
            for i = 1, math.min(#rows, cfg.expanded and 15 or 3) do
                local row = rows[i]
                frame:AddDoubleLine(row.label, row.value, 0.87, 0.82, 0.74, unpack(row.color))
            end
        end
    end
    if #results > 0 then frame:AddLine("Based on reported stats. Effects, set bonuses and restrictions may apply.", 0.68, 0.63, 0.56, true)
    elseif not future and usable ~= false then frame:AddLine("Comparison data unavailable", 0.68, 0.63, 0.56) end
    if cfg.alts and A.Settings("alts").enabled then
        for index, alt in ipairs(E.ForAlts(item, knownTransferable(frame, item))) do
            if index > 2 then break end
            frame:AddDoubleLine("Potential alt upgrade", alt.identity.name, 0.81, 0.68, 0.88, 0.57, 0.78, 0.54)
            frame:AddLine("Last recorded gear · check character requirements", 0.68, 0.63, 0.56, true)
        end
    end
end

function E.Badge(link, context)
    local cfg = A.Settings("advisor")
    if not (cfg.enabled and cfg[context] and link) then return end
    local item = E.Item(link)
    if not (item and slots[item.equip]) then return end
    local results, future, usable = E.ForPlayer(item)
    local best = results[1]
    if future then return "Future · Lv " .. item.required, {0.85, 0.73, 0.48} end
    if usable == false then return "Requirements unmet", {0.84, 0.49, 0.40} end
    if best and best.score then
        local value = best.percent and ("%+.1f%%"):format(best.percent) or formatDelta(best.score) .. " pts"
        return best.label .. " · " .. value, best.score > 0 and {0.77, 0.61, 0.90} or {0.72, 0.67, 0.61}
    end
end

function E.IsUpgrade(link)
    local item = E.Item(link)
    if not item then return false end
    local results = E.ForPlayer(item)
    return results[1] and results[1].label == "Potential upgrade" or false
end

function E.PaintIndicator(owner, link, context, point, x, y)
    local label, color = E.Badge(link, context)
    local marker = owner.baziAdvisor
    if label and not marker then
        marker = owner:CreateTexture(nil, "OVERLAY", nil, 4)
        marker:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\Diamond.tga")
        marker:SetSize(11, 11)
        marker:SetPoint(point, x, y)
        owner.baziAdvisor = marker
    end
    if marker then
        marker:SetShown(label ~= nil)
        if color then marker:SetVertexColor(unpack(color)) end
    end
end

A.On("receivedLoot", function(_, _, link)
    local cfg = A.Settings("advisor")
    if not (cfg.enabled and cfg.alts and A.Settings("alts").enabled and link and A.current) then return end
    local item = E.Item(link)
    local bags = A.current.bags
    if not item or not bags then return end
    local verified
    for _, copy in ipairs(bags.items) do
        if copy.link == item.link then
            if copy.bound ~= false then return end
            verified = true
        end
    end
    local alts = E.ForAlts(item, verified)
    if alts[1] then A.Emit("altUpgrade", item, alts[1]) end
end)
