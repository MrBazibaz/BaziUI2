local addon, A, D = BaziUI, BaziUI.Adventure, BaziUI.Dashboard
local S, inventory = addon.SmartAlerts, addon.Inventory
local call, read = A.Call, A.Read
local U = {}
addon.LootUpgrades = U

local slots = {
    HEAD = {"Head"}, NECK = {"Neck"}, SHOULDER = {"Shoulder"}, CLOAK = {"Back"},
    CHEST = {"Chest"}, ROBE = {"Chest"}, WRIST = {"Wrist"}, HAND = {"Hands"},
    WAIST = {"Waist"}, LEGS = {"Legs"}, FEET = {"Feet"}, FINGER = {"Finger0", "Finger1"},
    TRINKET = {"Trinket0", "Trinket1"}, WEAPON = {"MainHand", "SecondaryHand"},
    WEAPONMAINHAND = {"MainHand"}, WEAPONOFFHAND = {"SecondaryHand"}, HOLDABLE = {"SecondaryHand"},
    SHIELD = {"SecondaryHand"}, ["2HWEAPON"] = {"MainHand"}, RANGED = {"Ranged"},
    RANGEDRIGHT = {"Ranged"}, THROWN = {"Ranged"}, RELIC = {"Ranged"},
}
local armorSlots = {HEAD=true, SHOULDER=true, CLOAK=true, CHEST=true, ROBE=true,
    WRIST=true, HAND=true, WAIST=true, LEGS=true, FEET=true, SHIELD=true}
local primaryArmor = {WARRIOR=3, PALADIN=3, HUNTER=2, SHAMAN=2,
    ROGUE=2, DRUID=2, PRIEST=1, MAGE=1, WARLOCK=1}

local function preferredArmor(item, player)
    if item.class ~= 4 or not armorSlots[item.kind] or item.kind == "CLOAK" or item.kind == "SHIELD" then return true end
    local preferred = primaryArmor[player.token]
    if player.level >= 40 then
        if player.token == "WARRIOR" or player.token == "PALADIN"
            or player.token == "HUNTER" or player.token == "SHAMAN" then preferred = preferred + 1 end
    end
    return not preferred or item.sub == preferred
end
local stats = {
    str = {"STRENGTH"}, agi = {"AGILITY"}, sta = {"STAMINA"}, int = {"INTELLECT"}, spi = {"SPIRIT"},
    ap = {"ATTACK_POWER"}, rap = {"RANGED_ATTACK_POWER"}, sp = {"SPELL_DAMAGE_DONE", "SPELL_POWER"},
    heal = {"SPELL_HEALING_DONE", "SPELL_POWER"}, crit = {"CRIT_RATING"}, hit = {"HIT_RATING"},
    haste = {"HASTE_RATING"}, defense = {"DEFENSE_SKILL_RATING"}, dodge = {"DODGE_RATING"},
    parry = {"PARRY_RATING"}, block = {"BLOCK_RATING", "BLOCK_VALUE"}, armor = {"ARMOR"},
    mp5 = {"MANA_REGENERATION"}, expertise = {"EXPERTISE_RATING"},
}
local profiles = {
    strength = {str=1.7, agi=0.8, sta=0.3, ap=0.8, crit=1.2, hit=1.6, haste=1, expertise=1.3, dps=7},
    fury = {str=1.5, agi=0.9, sta=0.3, ap=0.9, crit=1.45, hit=2.1, haste=1.3, expertise=1.4, dps=7.5},
    rogue = {agi=1.8, str=0.8, sta=0.3, ap=0.8, crit=1.2, hit=1.8, haste=1.1, expertise=1.3, dps=7},
    rogueCombat = {agi=1.6, str=0.8, sta=0.3, ap=0.9, crit=1.1, hit=2, haste=1.4, expertise=1.5, dps=8},
    hunter = {agi=1.9, sta=0.4, int=0.5, ap=0.7, rap=0.7, crit=1.2, hit=1.5, haste=0.9, rangedDps=8},
    marksman = {agi=1.85, sta=0.3, int=0.45, ap=0.8, rap=0.8, crit=1.35, hit=1.65, haste=0.85, rangedDps=9},
    hunterSurvival = {agi=2.3, sta=0.55, int=0.35, ap=0.6, rap=0.6, crit=1.35, hit=1.5, haste=0.7, rangedDps=7},
    caster = {int=1.1, spi=0.35, sta=0.35, sp=1.7, crit=1, hit=1.5, haste=1.1, rangedDps=3},
    fire = {int=1.05, spi=0.35, sta=0.35, sp=1.7, crit=1.45, hit=1.55, haste=1, rangedDps=3},
    frost = {int=1.15, spi=0.4, sta=0.45, sp=1.8, crit=0.9, hit=1.5, haste=1.05, rangedDps=3},
    affliction = {int=0.9, spi=0.4, sta=0.4, sp=1.9, crit=0.5, hit=1.5, haste=1.2, rangedDps=3},
    healer = {int=1.25, spi=0.9, sta=0.25, heal=1.6, crit=0.6, haste=0.8, mp5=2},
    holy = {int=1.55, spi=0.35, sta=0.25, heal=1.65, crit=0.95, haste=0.8, mp5=2},
    tank = {str=0.55, agi=0.75, sta=1.7, armor=0.09, defense=2, dodge=1.3, parry=1.3, block=1.1, hit=0.6, dps=2.2},
    feral = {agi=1.6, str=1.4, sta=0.9, armor=0.04, ap=0.8, crit=1.1, hit=1.3, dodge=0.7},
    enhancement = {str=1, agi=1.5, sta=0.4, int=0.55, ap=0.8, sp=0.5, crit=1.2, hit=1.5, expertise=1.3, dps=6},
}
local trees = {
    WARRIOR={"strength","fury","tank"}, PALADIN={"holy","tank","strength"},
    HUNTER={"hunter","marksman","hunterSurvival"}, ROGUE={"rogue","rogueCombat","rogue"},
    PRIEST={"healer","healer","caster"}, SHAMAN={"caster","enhancement","healer"},
    MAGE={"caster","fire","frost"}, WARLOCK={"affliction","caster","fire"},
    DRUID={"caster","feral","healer"}, DEATHKNIGHT={"tank","strength","strength"},
}
local fallback = {WARRIOR="strength", PALADIN="strength", HUNTER="hunter", ROGUE="rogue", PRIEST="caster",
    SHAMAN="enhancement", MAGE="caster", WARLOCK="affliction", DRUID="feral", DEATHKNIGHT="strength"}
local specs = {[65]="holy", [66]="tank", [70]="strength", [71]="strength", [72]="fury", [73]="tank",
    [102]="caster", [103]="feral", [104]="tank", [105]="healer", [250]="tank", [251]="strength", [252]="strength",
    [253]="hunter", [254]="marksman", [255]="hunterSurvival", [256]="healer", [257]="healer", [258]="caster",
    [259]="rogue", [260]="rogueCombat", [261]="rogue", [262]="caster", [263]="enhancement", [264]="healer",
    [62]="caster", [63]="fire", [64]="frost", [265]="affliction", [266]="caster", [267]="fire"}

local function weights(class)
    if not read(class) or not fallback[class] then return end
    local api = C_SpecializationInfo
    local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
    local index, best = call(api and api.GetSpecialization or GetSpecialization or GetPrimaryTalentTree), 0
    if not read(index) or type(index) ~= "number" or index < 1 then
        index = nil
        for tree = 1, #(trees[class] or {}) do
            local specID, _, points, _, legacyPoints, _, modernPoints = call(getInfo or GetTalentTabInfo, tree)
            if getInfo then points = modernPoints elseif read(specID) and type(specID) == "number" then points = legacyPoints end
            if read(points) and type(points) == "number" and points > best then index, best = tree, points end
        end
    end
    local id = index and call(getInfo, index)
    local key = specs[id] or trees[class] and trees[class][index] or fallback[class]
    return profiles[key], key
end

local function itemTooltip(link)
    return call(C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
end

local function tooltipStat(tooltip, template)
    if type(tooltip) ~= "table" or type(template) ~= "string" then return end
    local before, after = template:match("^(.-)%%[%d%.%$]*[dfs](.*)$")
    if not before then return end
    local function escape(s) return (s:gsub("([^%w])", "%%%1")) end
    local pattern = "^" .. escape(before) .. "(%d+[.,]?%d*)" .. escape(after) .. "$"
    for _, line in ipairs(tooltip.lines or {}) do
        local text = line.leftText
        local number = read(text) and type(text) == "string"
            and text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match(pattern)
        if number then return tonumber((number:gsub(",", "."))) end
    end
end

local function canUse(link, item)
    if call(C_Item and C_Item.IsUsableItem or IsUsableItem, link) == true then return true end
    if item.class ~= 2 and item.class ~= 4 then return false end
    if not call(C_Item and C_Item.IsEquippableItem or IsEquippableItem, link) then return false end
    local tooltip = itemTooltip(link)
    if type(tooltip) ~= "table" or type(tooltip.lines) ~= "table" or #tooltip.lines == 0 then return false end
    local function restricted(color)
        return read(color) and color and read(color.r) and read(color.g) and read(color.b)
            and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number"
            and color.r > 0.75 and color.g < 0.35 and color.b < 0.35
    end
    for index = 2, #tooltip.lines do
        local line = tooltip.lines[index]
        if restricted(line.leftColor) or restricted(line.rightColor) then return false end
    end
    return true
end

local cache, cachedCount = {}, 0
local function details(link)
    if not read(link) or not link then return end
    if cache[link] ~= nil then return cache[link] or nil end
    local name, canonical, _, _, required, _, _, _, equip, _, _, class, sub = call(inventory.GetItemInfo, link)
    if type(name) ~= "string" or not (read(equip) and read(required) and read(class) and read(sub)) then return end
    local kind = type(equip) == "string" and equip:match("^INVTYPE_(.+)$")
    if cachedCount >= 500 then wipe(cache); cachedCount = 0 end
    cachedCount = cachedCount + 1
    if not slots[kind] or class == 2 and sub == 20 then cache[link] = false; return end
    local input = type(link) == "string" and link or read(canonical) and canonical
    if not input then return end
    local raw = call(C_Item and C_Item.GetItemStats or GetItemStats, input)
    local hasStats = type(raw) == "table" and next(raw) ~= nil
    if type(raw) ~= "table" then raw = {} end
    local tooltip
    if not hasStats and (armorSlots[kind] or class == 2) then tooltip = itemTooltip(input) end
    local values = {}
    for key, aliases in pairs(stats) do
        for _, token in ipairs(aliases) do
            local value = raw["ITEM_MOD_" .. token .. "_SHORT"]
            if read(value) and type(value) == "number" then values[key] = value; break end
            if tooltip then
                value = tooltipStat(tooltip, _G["ITEM_MOD_" .. token])
                if value then values[key] = value; break end
            end
        end
    end
    if values.armor == nil and read(raw.RESISTANCE0_NAME) and type(raw.RESISTANCE0_NAME) == "number" then
        values.armor = raw.RESISTANCE0_NAME
    end
    if armorSlots[kind] and values.armor == nil then
        values.armor = tooltipStat(tooltip or itemTooltip(input), _G.ARMOR_TEMPLATE)
    end
    local ranged = slots[kind][1] == "Ranged"
    if class == 2 then
        local dps = raw.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
        if not read(dps) or type(dps) ~= "number" then
            dps = tooltipStat(tooltip or itemTooltip(input), _G.DPS_TEMPLATE)
        end
        values[ranged and "rangedDps" or "dps"] = dps
    end
    if not hasStats and not next(values) then return end
    local unique, _, limit, category = call(C_Item and C_Item.GetItemUniquenessByID, link)
    local item = {name=name, id=A.ID(link), kind=kind, class=class, sub=sub, required=required or 0, values=values,
        unique=unique == true, limit=read(limit) and limit or nil, category=read(category) and category or nil}
    if class ~= 2 or values.dps or values.rangedDps then cache[link] = item end
    return item
end

local secondaryWeights = {armor = 0.015, dps = 0.5, rangedDps = 0.5}
local function statWeight(profile, name)
    return profile[name] or secondaryWeights[name] or 0
end

local function score(item, profile, offhand)
    local result = 0
    for name, value in pairs(item.values) do
        local factor = offhand and name == "dps" and 0.5 or 1
        result = result + value * statWeight(profile, name) * factor
    end
    return result
end

local function preservesWeightedStats(item, old, profile)
    if old then
        for name, value in pairs(old.values) do
            if statWeight(profile, name) > 0 and (item.values[name] or 0) < value then
                return false
            end
        end
    end
    return true
end

local function equipped(gear, slot)
    local piece = gear[slot]
    if not piece then return nil, false end
    if not piece.id and not piece.link then return nil, true end
    local item = details(piece.link or piece.id)
    return item, item ~= nil
end

local function compare(link, snapshot, profile, key)
    local player, gear = snapshot and snapshot.identity, snapshot and snapshot.gear
    if not player or not gear then return end
    local item = details(link)
    if not item or type(item.required) ~= "number" or type(player.level) ~= "number" or item.required > player.level
        or not preferredArmor(item, player) or not canUse(link, item) then return end
    if not profile then return end
    local main, mainKnown = equipped(gear, "MainHand")
    local off, offKnown = equipped(gear, "SecondaryHand")
    local best
    for _, slot in ipairs(slots[item.kind]) do
        local old, known = equipped(gear, slot)
        local offhand = slot == "SecondaryHand"
        local twoHand = item.kind == "2HWEAPON"
        local canReplace = known and (not offhand or mainKnown and main and main.kind ~= "2HWEAPON")
        if offhand and item.class == 2 and not (old and old.class == 2) then canReplace = false end
        if twoHand and not offKnown then canReplace = false end
        if slot == "MainHand" and old and old.kind == "2HWEAPON" and not twoHand then canReplace = false end
        if player.token == "ROGUE" and key == "rogue" and slot == "MainHand" and old and old.sub == 15 and item.sub ~= 15 then
            canReplace = false
        end
        local dps = slot == "Ranged" and "rangedDps" or "dps"
        if item.class == 2 and (not item.values[dps] or old and old.class == 2 and not old.values[dps]) then
            canReplace = false
        end
        if twoHand and off and off.class == 2 and not off.values.dps then canReplace = false end
        if canReplace and (item.unique or item.category) then
            local copies = 0
            for wornSlot, piece in pairs(gear) do
                if wornSlot ~= slot and not (twoHand and wornSlot == "SecondaryHand") then
                    local worn = item.category and details(piece.link or piece.id)
                    if item.unique and piece.id == item.id or worn and worn.category == item.category then copies = copies + 1 end
                end
            end
            if copies >= (item.limit or 1) then canReplace = false end
        end
        if canReplace then
            local before = (old and score(old, profile, offhand) or 0) + (twoHand and off and score(off, profile, true) or 0)
            local gain = score(item, profile, offhand) - before
            local clearUpgrade = gain > 0.00001 and not (twoHand and off) and preservesWeightedStats(item, old, profile)
            if (clearUpgrade or gain >= math.max(0.35, before * 0.015)) and (not best or gain > best.gain) then
                best = {slot=slot, gain=gain, item=item}
            end
        end
    end
    return best
end
function U.Compare(link, snapshot)
    local profile, key = weights(snapshot and snapshot.identity and snapshot.identity.token)
    return compare(link, snapshot, profile, key)
end

local pending, shown, marks = {}, {}, {}
local dashboardLink, dashboardUpgrades = nil, {}
local function enabled() return S.IsEnabled("upgrade", "Equipment") end

local function itemKey(link)
    if read(link) and type(link) == "string" then return link:match("|H(item:[^|]+)|h") or link end
end

function U.MatchesLink(left, right)
    local key = itemKey(left)
    return key ~= nil and key == itemKey(right)
end

function U.Mark(item)
    local key = item and not item.empty and itemKey(item.hyperlink)
    return key and item.bag and item.slot and marks[item.bag .. ":" .. item.slot] == key
end

local function reveal(link)
    if inventory.RevealUpgrade then inventory.RevealUpgrade(link) end
end

function U.DashboardUpgrades()
    local rows = {}
    for _, entry in ipairs(dashboardUpgrades) do
        local link = entry.link
        rows[#rows + 1] = {label = "Equip " .. entry.name, labelColor = S.colors.success,
            tooltip = "Click to show this upgrade in your bags.", click = function() reveal(link) end,
            icon = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\ChevronUp.tga"}
    end
    return rows
end

local function refresh()
    if not addon.db then return end
    local current, changed, found, byID = {}, false, {}, {}
    local snapshot = A.current
    if enabled() and snapshot and snapshot.identity and C_Container then
        local profile, key = weights(snapshot.identity.token)
        for _, bag in ipairs(inventory.BagIDs()) do
            local count = call(C_Container.GetContainerNumSlots, bag) or 0
            for slot = 1, count do
                local link = call(C_Container.GetContainerItemLink, bag, slot)
                local id = A.ID(link)
                if id then
                    if byID[id] == nil then byID[id] = link
                    elseif byID[id] ~= link then byID[id] = false end
                end
                local result = id and profile and compare(link, snapshot, profile, key)
                if result then
                    current[bag .. ":" .. slot] = itemKey(link)
                    found[link] = result
                end
            end
        end
    end
    for key, link in pairs(current) do if marks[key] ~= link then changed = true; break end end
    if not changed then for key in pairs(marks) do if not current[key] then changed = true; break end end end
    marks = current
    if changed and inventory.RefreshUpgradeMarks then inventory.RefreshUpgradeMarks() end
    for link, id in pairs(shown) do
        if not found[link] then S.Set(id, "upgrade", "Equipment", "progress"); shown[link] = nil
        elseif not S.active[id] then shown[link] = nil end
    end
    local now, newest = GetTime()
    for link, untilTime in pairs(pending) do
        local bagLink = found[link] and link or byID[A.ID(link)]
        local result = bagLink and found[bagLink]
        if now > untilTime or not enabled() then
            pending[link] = nil
        elseif result then
            local alertID = "upgrade:" .. bagLink
            local title = "Equipment upgrade · " .. result.item.name
            local options = D.WidgetSettings("smartAlerts")
            local alerts = S.Settings()
            local dashboard = D.Settings().enabled and options.enabled and options.mode ~= "hidden"
            local combat = InCombatLockdown()
            local notify = dashboard and not alerts.dnd and not alerts.critical
                and (combat and alerts.combat or not combat and alerts.peace)
            if notify then D.Notify("upgrade", title) end
            S.Set(alertID, "upgrade", "Equipment", "progress", title,
                "Click to show in bags", false, function()
                    reveal(bagLink)
                end, notify and {sound = true, chatWarning = true} or nil)
            shown[bagLink], pending[link] = alertID, nil
            if not newest or untilTime > newest.time or untilTime == newest.time and bagLink < newest.link then
                newest = {link = bagLink, time = untilTime}
            end
        end
    end
    dashboardLink = newest and newest.link or (found[dashboardLink] and dashboardLink)
    local upgrades = {}
    for link, result in pairs(found) do
        upgrades[#upgrades + 1] = {link = link, name = result.item.name, gain = result.gain}
    end
    table.sort(upgrades, function(a, b)
        if (a.link == dashboardLink) ~= (b.link == dashboardLink) then return a.link == dashboardLink end
        if a.gain ~= b.gain then return a.gain > b.gain end
        return a.link < b.link
    end)
    local changedUpgrades = #upgrades ~= #dashboardUpgrades
    if not changedUpgrades then
        for index, entry in ipairs(upgrades) do
            if entry.link ~= dashboardUpgrades[index].link then changedUpgrades = true; break end
        end
    end
    dashboardUpgrades = upgrades
    if changedUpgrades then D.Invalidate("smartAlerts") end
end

A.On("snapshot", function(_, dirty)
    if dirty.bags or dirty.gear or dirty.identity then refresh() end
end)
for _, event in ipairs({"PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_UPDATED", "GET_ITEM_INFO_RECEIVED", "settings"}) do
    A.On(event, refresh)
end
A.On("lootDetails", function(_, _, link, item)
    if not enabled() or not link or item.class ~= 2 and item.class ~= 4 then return end
    if not D.HasRoom(pending) then wipe(pending) end
    pending[link] = GetTime() + 10
    refresh()
end)
