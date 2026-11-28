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

local treeNames = {
    WARRIOR={Arms="strength", Fury="fury", Protection="tank"},
    PALADIN={Holy="holy", Protection="tank", Retribution="strength"},
    HUNTER={["Beast Mastery"]="hunter", Marksmanship="marksman", Survival="hunterSurvival"},
    ROGUE={Assassination="rogue", Combat="rogueCombat", Subtlety="rogue"},
    PRIEST={Discipline="healer", Holy="healer", Shadow="caster"},
    SHAMAN={Elemental="caster", Enhancement="enhancement", Restoration="healer"},
    MAGE={Arcane="caster", Fire="fire", Frost="frost"},
    WARLOCK={Affliction="affliction", Demonology="caster", Destruction="fire"},
    DRUID={Balance="caster", Feral="feral", ["Feral Combat"]="feral", Restoration="healer"},
}

local function finite(value)
    return read(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function traitProfile(class, traits)
    local configID = call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    if not finite(configID) then return end
    local config = call(traits.GetConfigInfo, configID)
    if type(config) ~= "table" or type(config.treeIDs) ~= "table" then return end
    local best, selected, tied = 0, nil, false
    for _, treeID in ipairs(config.treeIDs) do
        local groups = call(traits.GetGroupDisplayInfoByTreeID, treeID)
        if type(groups) ~= "table" then return end
        local ids, byID = {}, {}
        for _, group in ipairs(groups) do
            ids[#ids + 1] = group.groupID
            byID[group.groupID] = group
        end
        if #ids > 0 then
            local currencies = call(traits.GetGroupCurrencyInfo, configID, ids)
            if type(currencies) ~= "table" then return end
            for _, entry in ipairs(currencies) do
                local group, points = byID[entry.traitNodeGroupID], 0
                for _, currency in ipairs(entry.currencyInfos or {}) do
                    if not finite(currency.spent) then return end
                    points = points + currency.spent
                end
                if group and points > best then
                    best, selected, tied = points, group, false
                elseif group and points > 0 and points == best then
                    tied = true
                end
            end
        end
    end
    if selected and not tied and read(selected.displayName) and type(selected.displayName) == "string" then
        local key = treeNames[class] and treeNames[class][selected.displayName]
        if key then return key end
        -- Resolve localized tree names using the client's specialization names.
        local api = C_SpecializationInfo
        local info = api and api.GetSpecializationInfo or GetSpecializationInfo
        for index = 1, #(trees[class] or {}) do
            local id, name = call(info, index)
            if read(name) and name == selected.displayName then
                return specs[id] or trees[class][index]
            end
        end
    end
end

local function weights(class)
    if not read(class) or not fallback[class] then return end
    local traits = C_Traits
    if traits and traits.GetGroupDisplayInfoByTreeID and traits.GetGroupCurrencyInfo then
        local key = traitProfile(class, traits) or fallback[class]
        return profiles[key], key
    end
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

-- Persist the exact scoring profile used by the current character.
function U.CurrentProfileKey()
    local _, key = weights(select(2, UnitClass("player")))
    return key
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

local function compare(link, snapshot, profile, key, eligibility)
    local player, gear = snapshot and snapshot.identity, snapshot and snapshot.gear
    if not player or not gear then return end
    local item = details(link)
    if not item or type(item.required) ~= "number" or type(player.level) ~= "number" or item.required > player.level
        or not preferredArmor(item, player) then return end
    if eligibility then
        if not eligibility(link, item, snapshot) then return end
    elseif not canUse(link, item) then return end
    if not profile then return end
    local main, mainKnown = equipped(gear, "MainHand")
    local off, offKnown = equipped(gear, "SecondaryHand")
    local best
    for _, slot in ipairs(slots[item.kind]) do
        local old, known = equipped(gear, slot)
        local offhand = slot == "SecondaryHand"
        local twoHand = item.kind == "2HWEAPON"
        local canReplace = known and (not offhand or mainKnown and main and main.kind ~= "2HWEAPON")
        if offhand and item.class == 2 and not (old and old.class == 2) then
            if not eligibility or not (snapshot.weaponProficiencies and snapshot.weaponProficiencies.dualWield == true) then canReplace = false end
        end
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
    snapshot = snapshot or A.EquipmentSnapshot()
    local profile, key = weights(snapshot and snapshot.identity and snapshot.identity.token)
    return compare(link, snapshot, profile, key)
end

-- Classic weapon proficiency passives. Unknown proficiencies are not assumed.
local weaponProficiency = {[0]=196,[1]=197,[2]=264,[3]=266,[4]=198,[5]=199,[6]=200,
    [7]=201,[8]=202,[10]=227,[13]=15590,[15]=1180,[16]=2567,[18]=5011,[19]=5009}
function U.CurrentWeaponProficiencies()
    local result = {}
    for subclass, spell in pairs(weaponProficiency) do
        if call(IsPlayerSpell, spell) == true or call(IsSpellKnown, spell) == true then
            result[subclass] = true
        end
    end
    result.shield = call(IsPlayerSpell, 9116) == true or call(IsSpellKnown, 9116) == true
    result.dualWield = call(IsPlayerSpell, 674) == true or call(IsSpellKnown, 674) == true
    if type(CanDualWield) == "function" and call(CanDualWield) == true then result.dualWield = true end
    -- Equipped weapons are direct evidence of proficiency.
    local snapshot = A.EquipmentSnapshot()
    for _, piece in pairs(snapshot.gear or {}) do
        local item = piece.link and details(piece.link)
        if item and item.class == 2 then result[item.sub] = true end
    end
    local off = snapshot.gear and snapshot.gear.SecondaryHand
    local offItem = off and off.link and details(off.link)
    if offItem and offItem.class == 2 then result.dualWield = true end
    if offItem and offItem.kind == "SHIELD" then result.shield = true end
    return result
end

-- Offline comparisons must supply a verified eligibility predicate.
-- Never fall back to the logged-in player's usability or talent profile.
function U.CompareAlt(link, character, eligibility)
    if type(character) ~= "table" or type(eligibility) ~= "function" then return end
    local key = character.gearProfile
    local profile = key and profiles[key]
    if not profile or not character.identity or not character.gear then return end
    return compare(link, character, profile, key, eligibility)
end

-- Conservative offline eligibility: reject restrictions we cannot verify.
local function altEligible(link, item, character)
    local meta = character.identity
    -- Conservative Classic held-offhand eligibility; unlike weapons these
    -- do not become usable simply because the secondary slot is empty.
    if item.kind == "HOLDABLE" and not ({MAGE=true,PRIEST=true,WARLOCK=true,DRUID=true,SHAMAN=true,PALADIN=true})[meta.token] then
        return false
    end
    if item.class == 2 then
        if item.sub == 19 and not ({MAGE=true,PRIEST=true,WARLOCK=true})[meta.token] then return false end
        if not (character.weaponProficiencies and character.weaponProficiencies[item.sub]) then return false end
    elseif item.class == 4 then
        if item.kind == "SHIELD" and not (({WARRIOR=true,PALADIN=true,SHAMAN=true})[meta.token]
            and character.weaponProficiencies and character.weaponProficiencies.shield == true) then return false end
        if item.kind == "RELIC" then return false end
    else return false end
    local tooltip = itemTooltip(link)
    if type(tooltip) ~= "table" or type(tooltip.lines) ~= "table" or #tooltip.lines == 0 then return false end
    -- Reject class, race, profession, reputation and other explicit requirements.
    -- The ordinary minimum level is checked by compare().
    for _, line in ipairs(tooltip.lines) do
        local value = line.leftText
        if not read(value) then return false end
        if type(value) == "string" then
            value = value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            if value:match("^Classes:") or value:match("^Races:") or
                (value:match("^Requires ") and not value:match("^Requires Level %d+$")) then return false end
        end
    end
    return true
end

function U.AltRecommendations(link, unbound)
    local result = {}
    if unbound ~= true or not A.Settings("alts").enabled then return result end
    local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = call(inventory.GetItemInfo, link)
    if bindType ~= 2 and bindType ~= 0 then return result end
    local manager = addon.AltManager
    local player = A.current and A.current.identity
    if not manager or not player then return result end
    for key, character in pairs(manager.Characters()) do
        if key ~= player.key and character.identity and manager.SameTransferGroup(character.identity, player) then
            local upgrade = U.CompareAlt(link, character, altEligible)
            if upgrade then
                result[#result+1] = {key=key, identity=character.identity, profile=character.gearProfile,
                    gain=upgrade.gain, slot=upgrade.slot}
            end
        end
    end
    table.sort(result, function(a,b) return a.gain > b.gain end)
    return result
end

SLASH_BAZIALTDEBUG1 = "/bazialtdebug"
SlashCmdList.BAZIALTDEBUG = function(message)
    local link = message and message:match("(|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h.-|h|r)")
        or message and message:match("(|Hitem:[^|]+|h.-|h)")
    if not link then print("Usage: /bazialtdebug [item link]"); return end
    local item = details(link)
    if not item then print("Bazi Alt Gear: item data unavailable or not equipment."); return end
    local manager = addon.AltManager
    local player = A.current and A.current.identity
    if not manager or not player then print("Alt Manager data unavailable."); return end
    local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = call(inventory.GetItemInfo, link)
    print(("Bazi Alt Gear: %s | Requires level %s | Bind type %s (assuming unbound)"):format(item.name,tostring(item.required),tostring(bindType)))
    local recommended = {}
    for _, entry in ipairs(U.AltRecommendations(link, true)) do recommended[entry.key] = entry end
    for key, character in pairs(manager.Characters()) do
        local meta = character.identity
        if key ~= player.key and meta then
            local profile = character.gearProfile and profiles[character.gearProfile]
            local reason
            if not A.Settings("alts").enabled then reason = "Alt Manager disabled"
            elseif not manager.SameTransferGroup(meta, player) then reason = "Different transfer group"
            elseif bindType ~= 0 and bindType ~= 2 then reason = "Not transferable or unknown binding"
            elseif not profile or not character.gear then reason = "Missing profile or equipment"
            elseif type(meta.level) ~= "number" or type(item.required) ~= "number" then reason = "Unknown level"
            elseif item.required > meta.level then reason = "Level too low"
            elseif not preferredArmor(item, meta) then reason = "Wrong armor type"
            elseif item.class == 2 and not (character.weaponProficiencies and character.weaponProficiencies[item.sub]) then reason = "Weapon proficiency not confirmed"
            elseif not altEligible(link, item, character) then reason = "Item restrictions or eligibility not confirmed"
            elseif recommended[key] then reason = ("YES: %s, gain +%.2f"):format(recommended[key].slot,recommended[key].gain)
            else reason = "No qualifying upgrade (score or slot restrictions)" end
            print(("%s | Level %s | %s | %s"):format(meta.name or key,tostring(meta.level),character.gearProfile or "unknown",reason))
            if profile and character.gear then
                for _, slot in ipairs(slots[item.kind]) do
                    local old, known = equipped(character.gear, slot)
                    if known then
                        local offhand = slot == "SecondaryHand"
                        local before = old and score(old, profile, offhand) or 0
                        local off, offKnown = equipped(character.gear, "SecondaryHand")
                        if item.kind == "2HWEAPON" and off then before = before + score(off, profile, true) end
                        local after = score(item, profile, offhand)
                        print(("  %s: %s | %.2f -> %.2f (raw %+.2f)%s"):format(slot,old and old.name or "Empty",before,after,after-before,item.kind == "2HWEAPON" and not offKnown and " [offhand unknown]" or ""))
                    else print("  " .. slot .. ": equipment data unavailable") end
                end
            end
        end
    end
end

-- Read-only diagnostic: use the same scoring and eligibility checks as recommendations.
SLASH_BAZIGEARDEBUG1 = "/bazigeardebug"
SlashCmdList.BAZIGEARDEBUG = function(message)
    local snapshot = A.EquipmentSnapshot()
    local player = snapshot and snapshot.identity
    local profile, key = weights(player and player.token)
    if not profile then print("Bazi Gear: profile unavailable."); return end
    print("Bazi Gear: " .. player.token .. " / " .. key)
    local parts = {}
    for stat, weight in pairs(profile) do parts[#parts + 1] = stat .. "=" .. weight end
    table.sort(parts)
    print("Weights: " .. table.concat(parts, ", ") .. " (default armor=0.015, DPS=0.5 where unspecified)")
    local link = message and message:match("(|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h.-|h|r)")
        or message and message:match("(|Hitem:[^|]+|h.-|h)")
    if not link then
        print("Usage: /bazigeardebug [item link] (Shift-click an item into chat).")
        return
    end
    local item = details(link)
    if not item then print("Item data unavailable; try again after the tooltip loads."); return end
    local function describe(label, value, offhand)
        if not value then print(label .. ": empty"); return end
        local values = {}
        for stat, amount in pairs(value.values) do
            values[#values + 1] = stat .. "=" .. amount
        end
        table.sort(values)
        print(("%s: %s | score %.2f | %s"):format(label, value.name, score(value, profile, offhand), table.concat(values, ", ")))
    end
    if not snapshot.gear then print("Equipment data unavailable."); return end
    for _, slot in ipairs(slots[item.kind]) do
        local old, known = equipped(snapshot.gear, slot)
        local offhand = slot == "SecondaryHand"
        print("Slot: " .. slot)
        describe("Candidate", item, offhand)
        if known then
            describe("Equipped", old, offhand)
            local before = old and score(old, profile, offhand) or 0
            if item.kind == "2HWEAPON" then
                local off, offKnown = equipped(snapshot.gear, "SecondaryHand")
                if offKnown and off then
                    describe("Displaced offhand", off, true)
                    before = before + score(off, profile, true)
                elseif not offKnown then print("Offhand data unavailable.") end
            end
            print(("Raw score gain: %+.2f"):format(score(item, profile, offhand) - before))
        else print("Equipped item data unavailable.") end
    end
    local result = compare(link, snapshot, profile, key)
    if result then
        print(("Recommendation: YES (%s, gain %+.2f)"):format(result.slot, result.gain))
    else
        print("Recommendation: NO (score threshold or eligibility checks not met).")
    end
end

local nativeRewardsHooked
local function updateNativeRewards()
    if not (QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() and QuestInfoFrame) then return end
    local snapshot = A.EquipmentSnapshot()
    local function paint(parent, depth)
        if not parent or depth > 5 then return end
        local upgrade = parent.baziQuestUpgrade
        if parent.type == "choice" and parent.GetID and parent:IsShown() then
            local id = parent:GetID()
            local link = D.Call(GetQuestItemLink, "choice", id) or select(6, D.Call(GetQuestItemInfo, "choice", id))
            local result = link and U.Compare(link, snapshot)
            if result and not upgrade then
                upgrade = parent:CreateTexture(nil, "OVERLAY", nil, 4)
                upgrade:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\ChevronUp.tga")
                upgrade:SetSize(15, 15)
                upgrade:SetVertexColor(0.36, 1, 0.43)
                upgrade:SetPoint("TOPRIGHT", parent.Icon or parent, "TOPRIGHT", 0, 0)
                parent.baziQuestUpgrade = upgrade
            end
            if upgrade then upgrade:SetShown(result ~= nil and result ~= false) end
        elseif upgrade then upgrade:Hide() end
        for _, child in ipairs({parent:GetChildren()}) do paint(child, depth + 1) end
    end
    paint(QuestInfoFrame.rewardsFrame or QuestFrameRewardPanel, 0)
end

local function hookNativeRewards()
    if not nativeRewardsHooked and QuestInfo_Display then
        hooksecurefunc("QuestInfo_Display", function() C_Timer.After(0, updateNativeRewards) end)
        nativeRewardsHooked = true
    end
end
A.On("ready", hookNativeRewards)
A.On("PLAYER_LOGIN", hookNativeRewards)
A.On("QUEST_COMPLETE", function()
    hookNativeRewards()
    C_Timer.After(0, updateNativeRewards)
end)
A.On("GET_ITEM_INFO_RECEIVED", updateNativeRewards)

local pending, shown, marks = {}, {}, {}
local knownBagItems
local dashboardPending = {}
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

local function announceDashboardUpgrade(link, name)
    local expires = dashboardPending[link]
    if not expires then return end
    dashboardPending[link] = nil
    if expires >= GetTime() then D.Notify("upgrade", "Equipment upgrade · " .. name) end
end

local refresh
local function ignoredItems(create)
    local data, key = A.Data(), A.Key()
    if not data or not key then return end
    if create then
        data.ignoredGear = data.ignoredGear or {}
        data.ignoredGear[key] = data.ignoredGear[key] or {}
    end
    return data.ignoredGear and data.ignoredGear[key]
end

function U.IgnoredItems()
    return ignoredItems(false) or {}
end

function U.Ignore(link)
    local key, list = itemKey(link), ignoredItems(true)
    if not key or not list then return end
    list[key] = link
    if refresh then refresh() end
    D.Invalidate("smartAlerts")
end

function U.RestoreIgnored(key)
    local list = ignoredItems(false)
    if not list then return end
    if key then list[key] = nil else wipe(list) end
    if refresh then refresh() end
    D.Invalidate("smartAlerts")
end

function U.DashboardUpgrades()
    local rows = {}
    for _, entry in ipairs(dashboardUpgrades) do
        local link = entry.link
        rows[#rows + 1] = {label = "Equip " .. entry.name, labelColor = S.colors.success,
            tooltip = "Left-click to show this upgrade in your bags.\nRight-click to ignore this item for this character.", click = function() reveal(link) end,
            mute = function() U.Ignore(link) end,
            onShown = dashboardPending[link] and function() announceDashboardUpgrade(link, entry.name) end or nil,
            icon = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\ChevronUp.tga"}
    end
    return rows
end

refresh = function(allowNewBagUpgrades)
    if not addon.db then return end
    local current, changed, found, byID, bagItems = {}, false, {}, {}, {}
    local now, newest = GetTime()
    local snapshot = A.current
    local ignored = U.IgnoredItems()
    if enabled() and snapshot and snapshot.identity and C_Container then
        local profile, key = weights(snapshot.identity.token)
        for _, bag in ipairs(inventory.BagIDs()) do
            local count = call(C_Container.GetContainerNumSlots, bag) or 0
            for slot = 1, count do
                local link = call(C_Container.GetContainerItemLink, bag, slot)
                local id = A.ID(link)
                if id then
                    bagItems[link] = true
                    if allowNewBagUpgrades == true and knownBagItems and not knownBagItems[link] and not pending[link] then
                        pending[link] = now + 12
                    end
                    if byID[id] == nil then byID[id] = link
                    elseif byID[id] ~= link then byID[id] = false end
                end
                local result = id and profile and not ignored[itemKey(link)] and compare(link, snapshot, profile, key)
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
    knownBagItems = enabled() and snapshot and snapshot.identity and snapshot.gear and bagItems or nil
    local processed = {}
    for link, expires in pairs(dashboardPending) do
        if not found[link] or expires < now then dashboardPending[link] = nil end
    end
    for link, untilTime in pairs(pending) do
        local bagLink = found[link] and link or byID[A.ID(link)]
        local result = bagLink and found[bagLink]
        if now > untilTime or not enabled() then
            pending[link] = nil
        elseif result and processed[bagLink] then
            pending[link] = nil
        elseif result then
            processed[bagLink] = true
            local alertID = "upgrade:" .. bagLink
            local title = "Equipment upgrade · " .. result.item.name
            local options = D.WidgetSettings("smartAlerts")
            local alerts = S.Settings()
            local dashboard = alerts.dashboard and D.Settings().enabled and options.enabled and options.mode ~= "hidden"
            if dashboard then dashboardPending[bagLink] = math.max(untilTime, now + 3) end
            S.Set(alertID, "upgrade", "Equipment", "progress", title,
                "Click to show in bags", false, function()
                    reveal(bagLink)
                end, dashboard and {sound = true, chatWarning = true} or nil)
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
    if changedUpgrades or newest then D.Invalidate("smartAlerts") end
end

A.On("snapshot", function(_, dirty)
    if dirty.bags or dirty.gear or dirty.identity then refresh(dirty.bags) end
end)
for _, event in ipairs({"PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_UPDATED", "GET_ITEM_INFO_RECEIVED", "settings"}) do
    A.On(event, refresh)
end
A.On("loot", function(_, _, link)
    if not enabled() or not link then return end
    local class = select(6, D.Call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, link))
    if read(class) and type(class) == "number" and class ~= 2 and class ~= 4 then return end
    if not D.HasRoom(pending) then wipe(pending) end
    pending[link] = GetTime() + 10
    refresh()
end)
