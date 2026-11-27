local addon, A, D = BaziUI, BaziUI.Adventure, BaziUI.Dashboard
local call, read = A.Call, A.Read
local S = {active = {}, history = {}, cooldowns = {}}
addon.SmartAlerts = S
local art = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\"
S.colors = {critical = {0.93, 0.49, 0.40}, warning = {0.98, 0.76, 0.38},
    progress = {0.78, 0.61, 0.91}, success = {0.57, 0.79, 0.48}}
S.categories = {Equipment = "Shield", Class = "Dagger", Quests = "Quest", Professions = "Settings",
    Inventory = "Search", Progress = "Diamond", Economy = "Bell"}
S.rules = {
    {"durability", "Low or broken equipment", "Equipment"}, {"empty", "Empty core armor and weapon slots", "Equipment", false},
    {"upgrade", "Looted equipment upgrades", "Equipment"},
    {"fishing", "Fishing pole in combat", "Equipment"}, {"poison", "Missing or expired weapon enhancement", "Class"}, {"selfBuff", "Missing or expired self buff", "Class"},
    {"ammo", "Low or depleted ammunition", "Class"}, {"pet", "Hunter pet dead or unhappy", "Class"},
    {"supplies", "Low tracked supplies", "Inventory"}, {"bags", "Low or full inventory", "Inventory"},
    {"loot", "Rare or valuable loot", "Inventory"}, {"quest", "Quest ready to turn in", "Quests"},
    {"questLog", "Full quest log", "Quests"}, {"questTimer", "Timed quest ending", "Quests"},
    {"skill", "Skill rank changes", "Professions"}, {"craft", "Crafting or material goals reached", "Professions"},
    {"level", "Level gained", "Progress"}, {"talent", "Unspent talent points", "Progress"},
    {"boss", "Boss defeated", "Progress"}, {"reputation", "New reputation standing", "Progress"}, {"mail", "New mail", "Economy"},
    {"altMaterial", "Material needed by an alt", "Inventory"},
}
local defaults = {}
for _, rule in ipairs(S.rules) do defaults[rule[1]] = rule[4] ~= false end
local weight = {critical = 4, warning = 3, progress = 2, success = 1}
local frame, cards, expiry, ticker, sample, layoutMode
cards = {}
local function settings() return A.Settings("alerts") end
local guideText = "Red alerts need immediate attention. Gold alerts are reminders. Purple shows progress and green shows success. Hover for details, or click an equipment upgrade to reveal it in your bags."

function S.IsEnabled(rule, category)
    local cfg = settings()
    if not cfg.enabled then return false end
    if cfg.categories and cfg.categories[category] == false then return false end
    local value = cfg.rules and cfg.rules[rule]
    if value ~= nil then return value end
    return defaults[rule] ~= false
end

local function changed()
    if S.Render then S.Render() end
    D.Invalidate("smartAlerts")
    A.Emit("alerts")
end

local function schedule()
    if expiry then expiry:Cancel(); expiry = nil end
    local soon
    for _, alert in pairs(S.active) do
        if alert.expires then soon = math.min(soon or alert.expires, alert.expires) end
    end
    if soon then expiry = C_Timer.NewTimer(math.max(0.05, soon - GetTime()), function()
        expiry = nil
        local now = GetTime()
        for key, alert in pairs(S.active) do
            if alert.expires and alert.expires <= now then S.active[key] = nil end
        end
        changed()
        schedule()
    end) end
end

local popupSounds = {
    {"alertRetroBonk", "Retro Bonk", "AlertRetroBonk"},
    {"alertRetroBlip", "Retro Blip", "AlertRetroBlip"},
    {"alertFeltTap", "Felt Tap", "AlertFeltTap"},
    {"alertGlassDrop", "Glass Drop", "AlertGlassDrop"},
    {"alertTwinBell", "Twin Bell", "AlertTwinBell"},
    {"alertSoftKnock", "Soft Knock", "AlertSoftKnock"},
}
local soundFiles = {}
for _, entry in ipairs(popupSounds) do
    soundFiles[entry[1]] = "Interface\\AddOns\\BaziUI\\Assets\\Sounds\\" .. entry[3] .. ".ogg"
end

function S.SoundChoices()
    local choices = {{"raidWarning", "Raid warning"}}
    for _, entry in ipairs(popupSounds) do choices[#choices + 1] = entry end
    local audio = addon.Chat and addon.Chat.Alerts
    for _, entry in ipairs(audio and audio.SOUNDS or {}) do choices[#choices + 1] = {entry.key, entry.label} end
    return choices
end

function S.PlaySound(key)
    if not key or key == "raidWarning" then
        call(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    elseif soundFiles[key] then
        call(PlaySoundFile, soundFiles[key], "Master")
    else
        local audio = addon.Chat and addon.Chat.Alerts
        if audio then call(audio.Preview, key) end
    end
end

local dashboardBuffsEnabled
function S.Set(id, rule, category, severity, title, detail, persistent, action, deliveredByWatcher, reminder)
    local cfg, old = settings(), S.active[id]
    if not title or not S.IsEnabled(rule, category) then
        if old then
            S.active[id], old.resolved = nil, A.Now()
            changed()
            schedule()
        end
        return
    end
    if old and old.severity == severity and old.title == title and old.detail == detail then return end
    local now = GetTime()
    if not old and (S.cooldowns[id] or 0) > now then return end
    local alert = old or {id = id, created = A.Now(), entered = now}
    alert.rule, alert.category, alert.severity, alert.title, alert.detail, alert.action = rule, category, severity, title, detail, action
    alert.mute = reminder and reminder.mute
    alert.expires = not persistent and now + cfg.duration or nil
    S.active[id] = alert
    if not old then
        if #S.history >= 100 then table.remove(S.history, 1) end
        S.history[#S.history + 1] = alert
        if #S.history % 20 == 0 then
            for key, untilTime in pairs(S.cooldowns) do if untilTime <= now then S.cooldowns[key] = nil end end
        end
        S.cooldowns[id] = now + (persistent and 0 or math.max(15, cfg.duration))
        local combat = InCombatLockdown()
        local dashboardReminder = (rule == "selfBuff" or rule == "poison") and dashboardBuffsEnabled and dashboardBuffsEnabled()
        if not dashboardReminder and not cfg.dnd and (not cfg.critical or severity == "critical") and (combat and cfg.combat or not combat and cfg.peace) then
            local embedded = cfg.dashboard and D.Settings().enabled and D.WidgetSettings("smartAlerts")
            if reminder then
                D.Notify("classBuffReminder", title, nil, reminder.channels)
            elseif embedded and embedded.enabled and embedded.mode ~= "hidden" then
                D.Notify(rule, title, deliveredByWatcher)
            else
                if cfg.sound and not (deliveredByWatcher and deliveredByWatcher.sound)
                    and (not S.lastSound or now - S.lastSound >= 1.5) then
                    S.PlaySound(cfg.soundKey)
                    S.lastSound = now
                end
                if cfg.chat and not (deliveredByWatcher and deliveredByWatcher.chatWarning) then addon:Print(title) end
            end
        end
    end
    changed()
    schedule()
end

local function persistent(id, rule, category, severity, title, detail, action)
    S.Set(id, rule, category, severity, title, detail, true, action)
end

local function canDisplay(cfg)
    local combat = InCombatLockdown()
    return cfg.enabled and not cfg.dnd and (combat and cfg.combat or not combat and cfg.peace)
end

function S.Visible()
    local cfg, rows = settings(), {}
    if not canDisplay(cfg) then return rows end
    for _, entry in pairs(S.active) do
        if (not cfg.critical or entry.severity == "critical") and S.IsEnabled(entry.rule, entry.category) then rows[#rows + 1] = entry end
    end
    table.sort(rows, function(a, b)
        if a.severity ~= b.severity then return weight[a.severity] > weight[b.severity] end
        if a.entered ~= b.entered then return a.entered > b.entered end
        return a.id < b.id
    end)
    return rows
end

local function lootHint()
    local f = _G.LootFrame
    if f and f:IsShown() and addon.Inventory.OpenCleanup then addon.Inventory.OpenCleanup("loot") end
end

local function scanGear(snapshot)
    local cfg = settings()
    for slot, piece in pairs(snapshot.gear or {}) do
        local max, current = piece.maximum, piece.current
        local percent = type(max) == "number" and max > 0 and type(current) == "number" and math.floor(100 * current / max)
        local name = A.SlotNames[slot] or slot
        local title
        if percent and percent <= cfg.durability then
            title = current == 0 and (name .. " is broken") or ("%s durability · %d%%"):format(name, percent)
        end
        persistent("durability:" .. slot, "durability", "Equipment", current == 0 and "critical" or "warning", title)
        local armor = slot == "MainHand" or slot == "Chest" or slot == "Legs" or slot == "Feet"
        persistent("empty:" .. slot, "empty", "Equipment", "warning", armor and not piece.id and not piece.link and ("Empty slot · " .. name) or nil)
    end
    local main = snapshot.gear and snapshot.gear.MainHand
    local item = main and main.id and A.ItemDetails(main.link or main.id)
    local weapon = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
    local fishing = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
    persistent("fishing", "fishing", "Equipment", "warning",
        InCombatLockdown() and item and item.class == weapon and item.sub == fishing and "Fishing pole equipped in combat" or nil)
end

function S.RefreshAmmo(snapshot)
    local watcher = addon.HUDAmmo
    local watch = watcher and addon.HUD.Settings("ammo")
    local cfg = settings()
    local count, band, delivered
    if watch and watch.enabled then
        count = watcher.Read()
        if count == nil then return end
        band = watcher.Band(count, watch.low, watch.critical)
        local sound = band == 2 and watch.criticalSound or watch.lowSound
        delivered = {chatWarning = watch.chatWarning, sound = watch.sound and sound ~= "none"}
    else
        snapshot = snapshot or A.current
        if not snapshot or not snapshot.identity or snapshot.identity.token ~= "HUNTER" then return end
        local slot = A.SlotID("Ammo")
        local ammo = slot and call(GetInventoryItemID, "player", slot)
        local ranged = snapshot.gear and snapshot.gear.Ranged
        local item = ranged and A.ItemDetails(ranged.link or ranged.id)
        local usesAmmo = item and item.class == 2 and (item.sub == 2 or item.sub == 3 or item.sub == 18)
        count = ammo and D.Count(ammo) or usesAmmo and 0
        if type(count) == "number" then
            band = count <= math.min(cfg.ammo, cfg.criticalAmmo) and 2 or count <= cfg.ammo and 1 or 0
        end
    end
    local title = band and band > 0 and (count == 0 and "No ammunition equipped or remaining"
        or ((band == 2 and "Critical ammunition · %d" or "Low ammunition · %d"):format(count)))
    S.Set("ammo", "ammo", "Class", band == 2 and "critical" or "warning", title, nil, true, nil, delivered)
end

local function alertSkillGain(name, skill)
    local widget = skill.profession and "professions" or "skills"
    local function notify()
        if D.IsShowingRow(widget, name) then
            S.Set("skill:" .. name, "skill", "Professions", "progress")
            return
        end
        S.Set("skill:" .. name, "skill", "Professions", "progress", name .. " reached " .. skill.rank,
            skill.rank == skill.maximum and "Current skill cap reached" or nil)
    end
    if D.Settings().enabled then
        D.Invalidate(widget)
        C_Timer.After(0.12, notify)
    else
        notify()
    end
end

local watchedBuffs = {
    DRUID = {{1126, 21849, 5232, 6756, 5234, 8907, 9884, 9885, 21850}, {467, 782, 1075, 8914, 9756, 9910}},
    HUNTER = {{13165, 13163, 5118, 13161, 20043, 13159, 34074, 61846, 14318, 14319, 14320, 14321, 14322, 14323, 20190},
        {1299346, 1299348, 19506, 20905, 20906}},
    MAGE = {{168, 7302, 6117, 30482, 7300, 7301, 7320, 10219, 10220, 22782, 22783}, {1459, 23028, 1460, 1461, 10156, 10157}},
    PRIEST = {{588, 7128, 602, 1006, 10951, 10952}, {1243, 21562, 1244, 1245, 2791, 10937, 10938, 21564}, {14752, 27681, 14818, 14819, 27841}, {976, 27683, 10957, 10958}},
    SHAMAN = {{324, 52127, 974, 325, 905, 945, 8134, 10431, 10432}},
    WARLOCK = {{687, 706, 28176, 696, 1086, 11733, 11734, 11735}},
    PALADIN = {{465, 7294, 19746, 19876, 19888, 19891, 20218, 10290, 643, 10291, 1032, 10292, 10293, 10298, 10299, 10300, 10301, 19895, 19896, 19897, 19898, 19899, 19900},
        {19740, 19742, 20217, 19977, 20911, 25782, 25894, 25895, 25898, 25899, 19834, 19835, 19836, 19837, 19838, 25291, 19850, 19852, 19853, 19854, 25290, 25916, 25918, 20912, 20913, 20914}},
    WARRIOR = {{6673, 469, 5242, 6192, 11549, 11550, 11551, 25289}},
}

local function spellName(spell)
    return call(C_Spell and C_Spell.GetSpellName or GetSpellInfo, spell)
end

local function knowsSpell(spell)
    return call(C_SpellBook and C_SpellBook.IsSpellKnown, spell) == true
        or call(IsPlayerSpell, spell) == true or call(IsSpellKnown, spell) == true
end

local temporaryWeapons = {}
local function preferences()
    local store, key = A.Data(), A.Key()
    if not store or not key then return {} end
    store.buffPreferences = store.buffPreferences or {}
    store.buffPreferences[key] = store.buffPreferences[key] or {}
    return store.buffPreferences[key]
end
local lastCast, lastReadableBuffs
local weaponSlots = {{"MainHand", "MainHand"}, {"SecondaryHand", "OffHand"}, {"Ranged", "Ranged"}}
local shamanImbues = {8017, 8024, 8033, 8232}
-- Standard enchant IDs; unknown Forever variants retain a generic reminder.
local poisonFamilies = {"Instant Poison", "Deadly Poison", "Crippling Poison", "Mind-numbing Poison", "Wound Poison", "Occult Poison", "Atrophic Poison", "Numbing Poison", "Sebacious Poison"}
local function poisonFamily(name)
    if type(name) ~= "string" then return end
    for _, family in ipairs(poisonFamilies) do
        if name == family or name:sub(1, #family + 1) == family .. " " then return family end
    end
end
local poisonEnchants = {
    [323]="Instant Poison", [324]="Instant Poison", [325]="Instant Poison",
    [623]="Instant Poison", [624]="Instant Poison", [625]="Instant Poison",
    [7]="Deadly Poison", [8]="Deadly Poison", [626]="Deadly Poison", [627]="Deadly Poison", [2630]="Deadly Poison",
    [22]="Crippling Poison", [603]="Crippling Poison",
    [35]="Mind-numbing Poison", [23]="Mind-numbing Poison", [643]="Mind-numbing Poison",
    [703]="Wound Poison", [704]="Wound Poison", [705]="Wound Poison", [706]="Wound Poison",
}
local gatheringTrackers = {{2580, "Find Minerals"}, {2383, "Find Herbs"}}
local lastGatheringTracker

local function gatheringTracking()
    local api = C_Minimap
    local count = call(api and api.GetNumTrackingTypes)
    if type(count) ~= "number" then return end
    local trackers, localized = {}, {}
    for _, entry in ipairs(gatheringTrackers) do
        local spell = entry[1]
        localized[spellName(spell) or entry[2]] = spell
    end
    for index = 1, count do
        local info = call(api.GetTrackingInfo, index)
        if type(info) == "table" then
            local name = read(info.name) and info.name
            local spell = read(info.spellID) and info.spellID or name and localized[name]
            if spell == 2580 or spell == 2383 then
                if not read(info.active) or type(info.active) ~= "boolean" then return end
                trackers[spell] = {name = name or spellName(spell), active = info.active}
            end
        end
    end
    return trackers
end

local function buffOptions(token, create)
    local cfg = settings()
    if create then
        cfg.buffReminders = cfg.buffReminders or {}
        cfg.buffReminders[token] = cfg.buffReminders[token] or {}
    end
    return cfg.buffReminders and cfg.buffReminders[token]
end

local rankKeyCache = {}
local function spellKey(spell)
    -- Use the lowest registered ID with the same spell name, so ranks share settings.
    if rankKeyCache[spell] then return rankKeyCache[spell] end
    local name = spellName(spell)
    local canonical = spell
    if type(name) == "string" then
        local _, token = call(UnitClass, "player")
        for _, family in ipairs(watchedBuffs[token] or {}) do
            for _, id in ipairs(family) do
                if id < canonical and spellName(id) == name then canonical = id end
            end
        end
        if token == "SHAMAN" then
            for _, id in ipairs(shamanImbues) do
                if id < canonical and spellName(id) == name then canonical = id end
            end
        end
    end
    local key = "spell:" .. canonical
    if type(name) == "string" then rankKeyCache[spell] = key end
    return key
end

local function migrateRankOptions(token)
    local options = buffOptions(token)
    if not options then return end
    local moves = {}
    for key, entry in pairs(options) do
        local id = type(key) == "string" and tonumber(key:match("^spell:(%d+)$"))
        if id and not entry.learned then
            local canonical = spellKey(id)
            if canonical ~= key then moves[#moves + 1] = {key, canonical, entry} end
        end
    end
    table.sort(moves, function(a,b) return a[1] < b[1] end)
    for _, move in ipairs(moves) do
        local target = options[move[2]]
        if not target then options[move[2]] = move[3]
        else
            for field, value in pairs(move[3]) do
                if target[field] == nil then target[field] = value end
            end
        end
        options[move[1]] = nil
    end
end

function S.BuffReminderChoices(category)
    local _, token = call(UnitClass, "player")
    if not token then return {} end
    migrateRankOptions(token)
    local list, seen, registered = {}, {}, {}
    local function add(key, name, group)
        if group ~= "temporary" then registered[key] = true end
        if category and category ~= "all" and category ~= group then return end
        if name and not seen[name] then list[#list + 1], seen[name] = {key, name}, true end
    end
    for _, family in ipairs(watchedBuffs[token] or {}) do
        for _, spell in ipairs(family) do if knowsSpell(spell) then add(spellKey(spell), spellName(spell), "class") end end
    end
    local trackers = gatheringTracking() or {}
    for _, entry in ipairs(gatheringTrackers) do
        local spell = entry[1]
        if trackers[spell] then add(spellKey(spell), trackers[spell].name or entry[2], "gathering") end
    end
    if token == "SHAMAN" then
        add("imbue", "Weapon imbues (any)", "weapon")
        for _, spell in ipairs(shamanImbues) do if knowsSpell(spell) then add(spellKey(spell), spellName(spell), "weapon") end end
    elseif token == "ROGUE" then
        add("poison", "Weapon poisons (any)", "weapon")
        for _, name in pairs(preferences()) do
            if type(name) == "string" then
                for _, poisonName in ipairs(poisonFamilies) do
                    if name == poisonName then add("poison:" .. name, name, "weapon"); break end
                end
            end
        end
    end
    add("temporary", "Other temporary weapon enhancements", "temporary")
    add("fishingLure", "Fishing lures", "gathering")
    for key, entry in pairs(buffOptions(token) or {}) do
        if not entry.learned and not registered[key] then add(key, entry.label, entry.category or "temporary") end
    end
    table.sort(list, function(a, b) return a[2] == b[2] and a[1] < b[1] or a[2] < b[2] end)
    return list
end

function S.BuffReminderOption(key, field)
    local _, token = call(UnitClass, "player")
    local options = token and buffOptions(token)
    return not options or not options[key] or options[key][field] ~= false
end

function S.SetBuffReminderOption(key, field, value, label)
    local _, token = call(UnitClass, "player")
    if not token or not key then return end
    local options = buffOptions(token, true)
    options[key] = options[key] or {}
    local entry = options[key]
    entry[field], entry.label = value, label or entry.label
    D.Invalidate("classBuffs")
    if settings().enabled then A.Queue("class") end
    A.Emit("buffReminderSettings")
end

local function applyBuffOptions(token, reminders)
    local options, visible = buffOptions(token) or {}, {}
    for _, reminder in ipairs(reminders) do
        local key = reminder.key
        local pref = options[key]
        if not pref or pref.enabled ~= false then
            reminder.channels = pref
            reminder.mute = function() S.SetBuffReminderOption(key, "enabled", false, reminder.label) end
            visible[#visible + 1] = reminder
        end
    end
    return visible
end

A.On("playerSpellCast", function(spell)
    if not (dashboardBuffsEnabled and dashboardBuffsEnabled()) and not settings().enabled then return end
    lastCast = {spell = spell, time = GetTime()}
    if dashboardBuffsEnabled() then D.Invalidate("classBuffs") end
end)

local function playerBuffNames(token)
    local getAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not getAura then return end
    if call(C_Secrets and C_Secrets.ShouldAurasBeSecret) == true then return end
    local names = {}
    for index = 1, 80 do
        local ok, aura = pcall(getAura, "player", index, "HELPFUL")
        if not ok or not read(aura) then return end
        if not aura then return names end
        if not read(aura.name) then return end
        if aura.name then
            names[aura.name] = true
        end
        if read(aura.spellId) and type(aura.spellId) == "number" then names[aura.spellId] = true end
    end
    return names
end

local function weaponEffects(hand)
    local api, types = C_Item, Enum and Enum.ItemEnchantType
    local slots = Enum and Enum.WeaponSlot
    if api and api.GetWeaponEnchantInfo and types and slots then
        if slots[hand] == nil then return end
        local items = call(api.GetWeaponEnchantInfo, slots[hand])
        if type(items) ~= "table" then return end
        local effects = {active = false, imbue = false, temporary = {}}
        for index, enchant in ipairs(items) do
            if not read(enchant.hasEnchant) or not read(enchant.enchantType) then return end
            if enchant.hasEnchant then
                if enchant.enchantType == types.Imbue then effects.active, effects.imbue = true, true end
                if enchant.enchantType == types.Temporary or enchant.enchantType == types.Imbue then
                    effects.active = true
                    local id = read(enchant.enchantID) and enchant.enchantID or index
                    effects.temporary[enchant.enchantType .. ":" .. id] = enchant
                end
            end
        end
        return effects
    end
    if hand == "Ranged" then return end
    local main, _, _, _, off = call(GetWeaponEnchantInfo)
    local active = main
    if hand == "OffHand" then active = off end
    if read(active) and type(active) == "boolean" then return {active = active, imbue = active} end
end

-- Diagnostic only: does not modify reminder state or saved settings.
SLASH_BAZIBUFFDEBUG1 = "/bazibuffdebug"
SlashCmdList.BAZIBUFFDEBUG = function()
    local function safe(value)
        if not read(value) then return "<restricted>" end
        if value == nil then return "<nil>" end
        if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then return tostring(value) end
        return "<" .. type(value) .. ">"
    end
    local function out(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = safe(select(i, ...)) end
        print("Bazi Buff: " .. table.concat(parts, " "))
    end
    local _, token = call(UnitClass, "player")
    out("Class:", token)
    for _, family in ipairs(watchedBuffs[token] or {}) do
        for _, spell in ipairs(family) do
            if knowsSpell(spell) then out("Known:", spell, (spellName(spell))) end
        end
    end
    if token == "SHAMAN" then
        for _, spell in ipairs(shamanImbues) do
            if knowsSpell(spell) then out("Known imbue:", spell, (spellName(spell))) end
        end
    end
    local getAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if getAura and call(C_Secrets and C_Secrets.ShouldAurasBeSecret) ~= true then
        for i = 1, 80 do
            local ok, aura = pcall(getAura, "player", i, "HELPFUL")
            if not ok or not read(aura) then out("Aura data unavailable"); break end
            if not aura then break end
            out("Aura:", aura.name, "ID:", aura.spellId, "duration:", aura.duration, "expires:", aura.expirationTime)
        end
    else out("Aura API unavailable or restricted") end
    for _, slot in ipairs(weaponSlots) do
        local hand = slot[2]
        local slots = Enum and Enum.WeaponSlot
        local api = C_Item and C_Item.GetWeaponEnchantInfo
        local entries = slots and slots[hand] ~= nil and call(api, slots[hand])
        out("Weapon:", hand)
        if read(entries) and type(entries) == "table" then
            for i, enchant in ipairs(entries) do
                if read(enchant) and type(enchant) == "table" then
                    out("Entry:", i, "active:", enchant.hasEnchant, "type:", enchant.enchantType, "ID:", enchant.enchantID, "timeLeft:", enchant.timeLeft)
                end
            end
        else
            local effects = weaponEffects(hand)
            out("Fallback active:", effects and effects.active, "imbue:", effects and effects.imbue)
        end
    end
    out("End diagnostic")
end

local function weaponIdentity(slot, fallback)
    local inventorySlot = A.SlotID(slot)
    if inventorySlot and ItemLocation and ItemLocation.CreateFromEquipmentSlot then
        local location = ItemLocation:CreateFromEquipmentSlot(inventorySlot)
        local guid = location and call(C_Item and C_Item.GetItemGUID, location)
        if guid then return guid end
    end
    return fallback
end

local function missingWeaponEffects(slot, weapon, effects)
    if not effects.temporary then return {} end
    local record = temporaryWeapons[slot]
    if not record or record.weapon ~= weapon then
        record = {weapon = weapon, effects = {}}
        temporaryWeapons[slot] = record
    end
    local now, activeTypes, missing, newlyApplied = GetTime(), {}, {}, {}
    for id, enchant in pairs(effects.temporary) do
        local old = record.effects[id]
        local duration = read(enchant.timeLeft) and enchant.timeLeft
        local expires = type(duration) == "number" and duration > 0 and now + duration / 1000 or nil
        local applied = not old or old.missing or expires and old.expires and expires - old.expires > 2
        local seen = applied and now or old.seen
        if applied then newlyApplied[id] = true end
        -- Cast success and the enchant update can arrive in either order.
        local cast = (applied or (old and not old.spell)) and lastCast and math.abs(lastCast.time - seen) <= 0.6
            and now - lastCast.time <= 0.6 and lastCast.spell
        record.effects[id] = {expires = expires, kind = enchant.enchantType, seen = seen,
            spell = cast or old and old.spell}
        activeTypes[enchant.enchantType] = true
    end
    for id, old in pairs(record.effects) do
        if not effects.temporary[id] then
            if activeTypes[old.kind] then
                record.effects[id] = nil
            else
                old.missing = true
                missing[id] = old
            end
        end
    end
    return missing, newlyApplied
end

local function classReminders(token, gear)
    local notices = {}
    if not token or call(UnitIsDeadOrGhost, "player") == true then return notices end
    migrateRankOptions(token)
    local families = watchedBuffs[token]
    local preferredBuffs = preferences()
    local names = playerBuffNames(token)
    local options = buffOptions(token) or {}
    local function spellEnabled(spell)
        local pref = options[spellKey(spell)]
        return not pref or pref.enabled ~= false
    end
    if names then lastReadableBuffs = names
    elseif InCombatLockdown() then names = lastReadableBuffs end
    local trackers, selected, trackingActive = gatheringTracking() or {}, nil, false
    for _, entry in ipairs(gatheringTrackers) do
        local spell, label = entry[1], entry[2]
        local tracker = trackers[spell]
        if tracker then
            if tracker.active then lastGatheringTracker, trackingActive = spell, true end
            if not selected or spell == lastGatheringTracker then selected = spell end
        end
    end
    if selected and not trackingActive then
        local name = trackers[selected].name or (selected == 2580 and "Find Minerals" or "Find Herbs")
        notices[#notices + 1] = {id = "gatheringTracking", key = spellKey(selected), label = name, rule = "selfBuff",
            title = name .. " is off", detail = "Turn this tracking back on from your action bar or the minimap tracking menu.",
            icon = "Search", spells = {[name] = true}}
    end
    for _, family in ipairs(families or {}) do
        local active, expected, spells, knownCount = false, nil, {}, 0
        local knownNames = {}
        local familyID = family[1]
        local preferredName = preferredBuffs[familyID] and spellName(preferredBuffs[familyID])
        for _, spell in ipairs(family) do
            local name = spellName(spell)
            if name then
                local known = knowsSpell(spell)
                if known and call(C_Spell and C_Spell.IsSpellPassive, spell) ~= true then
                    if not knownNames[name] then knownNames[name], knownCount = true, knownCount + 1 end
                    if not expected or name == preferredName then expected = spell end
                    if spellEnabled(spell) then spells[name] = true end
                end
                if names and (names[name] or names[spell]) then
                    active = true
                    if known and call(C_Spell and C_Spell.IsSpellPassive, spell) ~= true then preferredBuffs[familyID] = spell end
                end
            end
        end
        if names and expected and not active then
            local name = spellName(expected)
            local preferred = preferredName == name
            local generic = ({[13165]="Activate an Aspect", [324]="Activate a Shield", [168]="Activate an Armor", [687]="Activate an Armor", [465]="Activate an Aura", [19740]="Apply a Blessing"})[familyID]
            local title = not preferred and knownCount > 1 and (generic or "Activate a class buff") or name .. " is missing"
            if preferred then spells = spellEnabled(expected) and {[name] = true} or {} end
            notices[#notices + 1] = {id = "selfBuff:" .. familyID, key = spellKey(expected), label = name, rule = "selfBuff",
                title = title, detail = "Reapply this buff to yourself.", spells = spells}
        end
    end
    local shaman = token == "SHAMAN"
    local imbues, usableImbues, missing = {}, {}, {}
    if shaman then
        for _, id in ipairs(shamanImbues) do
            local name = knowsSpell(id) and spellName(id)
            if name then
                imbues[name] = id
                if spellEnabled(id) then usableImbues[name] = true end
            end
        end
    end
    local poison = token == "ROGUE" and (knowsSpell(8681) or knowsSpell(3408) or knowsSpell(2835) or (D.Count(6947) or 0) > 0)
    for _, weapon in ipairs(weaponSlots) do
        local slot, hand = weapon[1], weapon[2]
        local piece = gear and gear[slot]
        local inventorySlot = A.SlotID(slot)
        local link = piece and (piece.link or piece.id) or inventorySlot and call(GetInventoryItemLink, "player", inventorySlot)
        local info = link and A.ItemDetails(link)
        local effect = info and info.class == 2 and weaponEffects(hand)
        if not link or (info and info.class ~= 2) then temporaryWeapons[slot] = nil end
        if effect then
            local name = A.SlotNames[slot] or slot
            local needsImbue = next(imbues) ~= nil and hand ~= "Ranged" and info.sub ~= 20 and not effect.imbue
            local missingEffects, newlyApplied = missingWeaponEffects(slot, weaponIdentity(slot, link), effect)
            newlyApplied = newlyApplied or {}
            local imbueSpell
            local prefKey = "imbue:" .. hand
            local poisonKey = "poison:" .. hand
            if token == "ROGUE" and effect.imbue and effect.temporary and hand ~= "Ranged" then
                local identified
                for _, enchant in pairs(effect.temporary) do
                    if enchant.enchantType == Enum.ItemEnchantType.Imbue and read(enchant.enchantID) then
                        identified = poisonEnchants[enchant.enchantID] or preferredBuffs["poisonEnchant:" .. tostring(enchant.enchantID)]
                        if identified then break end
                    end
                end
                preferredBuffs[poisonKey] = identified
            end
            if shaman and effect.imbue and effect.temporary then
                for effectID, enchant in pairs(effect.temporary) do
                    if enchant.enchantType == Enum.ItemEnchantType.Imbue then
                        local enchantID = read(enchant.enchantID) and enchant.enchantID
                        local mapKey = enchantID and ("imbueEnchant:" .. tostring(enchantID))
                        local mapped = mapKey and (preferredBuffs[mapKey] or ({[6]=8017,[5]=8024})[enchantID])
                        local castName = lastCast and GetTime() - lastCast.time <= 0.6 and spellName(lastCast.spell)
                        if newlyApplied[effectID] and castName and imbues[castName] and mapKey and not mapped then
                            mapped = imbues[castName]
                            preferredBuffs[mapKey] = mapped
                        end
                        if mapped and knowsSpell(mapped) then preferredBuffs[prefKey] = mapped end
                    end
                end
            end
            for id, previous in pairs(missingEffects) do
                local source = previous.spell and spellName(previous.spell)
                if previous.kind == Enum.ItemEnchantType.Imbue and (shaman or token == "ROGUE") then
                    if needsImbue then imbueSpell = source and imbues[source] or imbueSpell end
                else
                    local fishing = info.sub == 20
                    local key = source and spellKey(previous.spell) or (fishing and "fishingLure" or "temporary")
                    if source and not options[key] then
                        options = buffOptions(token, true)
                        options[key] = {label = source, category = fishing and "gathering" or "temporary"}
                    end
                    notices[#notices + 1] = {id = "temporaryWeapon:" .. slot .. ":" .. id, key = key,
                        label = source or (fishing and "Fishing lures" or "Other temporary weapon enhancements"), rule = "poison",
                        title = (source and (source .. " is missing") or (fishing and "Fishing lure is missing" or "Temporary weapon enhancement missing")) .. " · " .. name,
                        detail = source and ("Reapply " .. source .. " if available.") or "Reapply the temporary enhancement if available.",
                        itemSpells = previous.spell and {[previous.spell] = true},
                        spells = source and knowsSpell(previous.spell) and {[source] = true}}
                end
            end
            if needsImbue then
                imbueSpell = imbueSpell or preferredBuffs[prefKey]
                if imbueSpell and not knowsSpell(imbueSpell) then imbueSpell = nil end
                local key = imbueSpell and spellKey(imbueSpell) or "imbue"
                local group = missing[key] or {label = imbueSpell and spellName(imbueSpell) or "Weapon imbues (any)", hands = {}}
                missing[key] = group
                group.hands[#group.hands + 1] = name
            elseif poison and hand ~= "Ranged" and info.sub ~= 20 and not effect.imbue then
                local preferred = preferredBuffs[poisonKey]
                notices[#notices + 1] = {id = "enhancement:" .. slot, key = preferred and ("poison:" .. preferred) or "poison",
                    label = preferred or "Weapon poisons (any)", rule = "poison",
                    title = (preferred and (preferred .. " is missing") or "Apply poison to your weapon") .. " · " .. name,
                    detail = preferred and ("Reapply " .. preferred .. ".") or "Apply a poison to this weapon.",
                    poisonGlow = preferred or true}
            end
        end
    end
    for key, group in pairs(missing) do
        notices[#notices + 1] = {id = "enhancement:imbue:" .. key, key = key, label = group.label, rule = "poison", title = key == "imbue" and "Imbue your weapon" or group.label .. " is missing",
            detail = (key == "imbue" and "Apply any known weapon imbue" or ("Reapply " .. group.label)) .. " · " .. table.concat(group.hands, ", "),
            spells = key == "imbue" and usableImbues or (usableImbues[group.label] and {[group.label] = true} or {})}
    end
    return applyBuffOptions(token, notices)
end

-- Resolve application spells from actual bag items rather than assuming spell IDs.
local function collectPoisonSpells()
    local found = {}
    local container = C_Container
    local getItemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
    if not container or not getItemSpell then return found end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local count = call(container.GetContainerNumSlots, bag) or 0
        for slot = 1, count do
            local item = call(container.GetContainerItemID, bag, slot)
            if item then
                local name, spell = call(getItemSpell, item)
                if read(name) and read(spell) and type(name) == "string" and type(spell) == "number" then
                    local family = poisonFamily(name)
                    if family then found[spell] = family end
                end
            end
        end
    end
    return found
end

local function glowReminders(reminders)
    local bars = addon.ActionBars
    if not (bars and bars.SetClassReminderActions) then return end
    local wanted, inDashboard = {}, dashboardBuffsEnabled and dashboardBuffsEnabled()
    local poisonSpells
    for _, reminder in ipairs(reminders) do
        if inDashboard or S.IsEnabled(reminder.rule, "Class") then
            for name in pairs(reminder.spells or {}) do wanted[name] = true end
            for spell in pairs(reminder.itemSpells or {}) do wanted[spell] = true end
            if reminder.poisonGlow then
                poisonSpells = poisonSpells or collectPoisonSpells()
                for spell, family in pairs(poisonSpells) do
                    if reminder.poisonGlow == true or reminder.poisonGlow == family then wanted[spell] = true end
                end
            end
        end
    end
    bars:SetClassReminderActions(wanted)
end

dashboardBuffsEnabled = function()
    if not D.byID.classBuffs or not D.Settings().enabled then return false end
    local widget = D.WidgetSettings("classBuffs")
    return widget.enabled and widget.mode ~= "hidden"
end

local function scanClass(snapshot)
    local meta = snapshot.identity
    if not meta then return end
    local present = {}
    local reminders = classReminders(meta.token, snapshot.gear)
    glowReminders(reminders)
    for _, reminder in ipairs(reminders) do
        present[reminder.id] = true
        S.Set(reminder.id, reminder.rule, "Class", "warning", reminder.title, reminder.detail, true, nil, nil, reminder)
    end
    for id, alert in pairs(S.active) do
        if (alert.rule == "selfBuff" or alert.rule == "poison") and not present[id] then
            persistent(id, alert.rule, "Class", "warning")
        end
    end
    if meta.token == "HUNTER" then
        S.RefreshAmmo(snapshot)
        local exists = call(UnitExists, "pet")
        local dead = exists and call(UnitIsDeadOrGhost, "pet")
        local unhappy = exists and call(GetPetHappiness) == 1
        persistent("pet", "pet", "Class", dead and "critical" or "warning", dead and "Hunter pet is dead" or unhappy and "Hunter pet is unhappy" or nil)
    end
end

local lastDashboardReminders = {}
D.Register({id = "classBuffs", label = "Class buffs", priority = 94, tick = true,
    events = {"UNIT_AURA", "UNIT_INVENTORY_CHANGED", "WEAPON_ENCHANT_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
        "SPELLS_CHANGED", "MINIMAP_UPDATE_TRACKING", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST"},
    eventFilter = function(event, unit)
        return (event ~= "UNIT_AURA" and event ~= "UNIT_INVENTORY_CHANGED") or unit == "player"
    end,
    read = function()
        local _, token = call(UnitClass, "player")
        local gear
        if token == "SHAMAN" or token == "ROGUE" then
            gear = {}
            for _, slot in ipairs({"MainHand", "SecondaryHand"}) do
                local id = A.SlotID(slot)
                if id then gear[slot] = {link = call(GetInventoryItemLink, "player", id),
                    id = call(GetInventoryItemID, "player", id)} end
            end
        end
        local reminders, rows, current = classReminders(token, gear), {}, {}
        glowReminders(reminders)
        for _, reminder in ipairs(reminders) do
            current[reminder.id] = reminder.key
            if lastDashboardReminders[reminder.id] ~= reminder.key and dashboardBuffsEnabled() then
                D.Notify("classBuffReminder", reminder.title, nil, reminder.channels)
            end
            rows[#rows + 1] = {label = reminder.title, labelColor = S.colors.warning,
                icon = art .. (reminder.icon or (reminder.rule == "poison" and "Dagger" or "Shield")) .. ".tga",
                tooltip = reminder.detail, mute = reminder.mute}
        end
        lastDashboardReminders = current
        return D.Rows(rows, #rows > 0, #rows > 0)
    end})

local factionRanks
A.On("snapshot", function(snapshot, dirty)
    if not dirty.reputation then return end
    local nextRanks = {}
    for _, faction in ipairs(snapshot.factions or {}) do
        local id, rank = faction.id, faction.rank
        local previous = factionRanks and factionRanks[id]
        if type(rank) == "number" then
            nextRanks[id] = rank
            if previous and rank > previous and faction.standing ~= "" then
                A.Emit("factionAdvanced", id, "Reached " .. faction.standing .. " with " .. faction.row.label, rank)
            end
        end
    end
    factionRanks = nextRanks
end)
A.On("factionAdvanced", function(id, title)
    S.Set("faction:" .. id, "reputation", "Progress", "success", title)
end)

local questState, skills, goalState = nil, nil, {}
local function scanQuests()
    local q, tracker = C_QuestLog, addon.QuestTracker
    if not (q and tracker and tracker.DashboardQuests) then return end
    local log = tracker.DashboardQuests()
    local nextState = {}
    for id, row in pairs(log or {}) do
        local title = row.info and row.info.title
        if read(title) and type(title) == "string" and type(id) == "number" then
            local ready = call(q.IsComplete, id)
            if type(ready) == "boolean" then
                nextState[id] = ready
                if ready and questState and questState[id] == false then
                    S.Set("quest:" .. id, "quest", "Quests", "success", title .. " · ready to turn in", nil, false,
                        function() tracker.OpenQuest(id) end)
                end
            end
            local total, elapsed = call(q.GetTimeAllowed, id)
            local left = type(total) == "number" and read(elapsed) and type(elapsed) == "number" and total - elapsed
            persistent("questTimer:" .. id, "questTimer", "Quests", "warning",
                left and left > 0 and left <= 120 and (title .. " · less than 2 minutes") or nil)
        end
    end
    for id in pairs(questState or {}) do
        if nextState[id] == nil then persistent("questTimer:" .. id, "questTimer", "Quests", "warning") end
    end
    questState = nextState
    local _, entries = call(q.GetNumQuestLogEntries)
    local limit = Constants and Constants.QuestLogConsts and Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT or _G.MAX_QUEST_LOG_SIZE
    persistent("questLog", "questLog", "Quests", "warning",
        type(limit) == "number" and read(entries) and type(entries) == "number" and entries >= limit and "Quest log is full" or nil)
end

local function checkGoal(id, name, done)
    if done and goalState[id] == false then S.Set(id, "craft", "Professions", "success", name .. " · materials ready") end
    goalState[id] = done
end

local function scanSupplies()
    local tracking = D.Tracking()
    if not tracking then return end
    local kept = {}
    for id, value in pairs(tracking.supplies or {}) do
        local minimum = type(value) == "table" and value.minimum or value
        local have = D.Count(id)
        local key = "supply:" .. id
        kept[key] = true
        if type(minimum) == "number" and type(have) == "number" then
            persistent(key, "supplies", "Inventory", "warning", have < minimum and ("%s · %d left"):format(D.Item(id), have) or nil)
        end
    end
    for key in pairs(S.active) do
        if key:match("^supply:") and not kept[key] then persistent(key, "supplies", "Inventory", "warning") end
    end
    for id, goal in pairs(tracking.goals or {}) do
        local done = next(goal.materials or {}) ~= nil
        for item, quantity in pairs(goal.materials or {}) do
            local have = D.Count(item)
            if not have or have < quantity * goal.amount then done = false; break end
        end
        checkGoal("craft:" .. id, goal.name or tostring(id), done)
    end
    for id, goal in pairs(tracking.items or {}) do
        local need = type(goal) == "table" and goal.target or goal
        local have = D.Count(id)
        if type(need) == "number" and have then checkGoal("item:" .. id, D.Item(id), have >= need) end
    end
end

A.On("snapshot", function(snapshot, dirty)
    if not settings().enabled then return end
    if dirty.gear or dirty.class then scanGear(snapshot) end
    if dirty.gear or dirty.class or dirty.bags then scanClass(snapshot) end
    if dirty.bags then
        local free = snapshot.free
        local title = type(free) == "number" and free <= settings().free and (free == 0 and "Inventory is full" or ("%d free bag slots remaining"):format(free)) or nil
        persistent("bags", "bags", "Inventory", free == 0 and "critical" or "warning", title,
            free == 0 and "If loot cannot fit, open Inventory Cleanup." or nil, free == 0 and lootHint or nil)
        scanSupplies()
    end
    if dirty.quests then scanQuests() end
    if dirty.skills and snapshot.skills and next(snapshot.skills) then
        if skills then for name, skill in pairs(snapshot.skills) do
            local old = skills[name]
            if old and old.rank < skill.rank then
                alertSkillGain(name, skill)
            end
        end end
        skills = snapshot.skills
    end
    if dirty.mail then
        persistent("mail", "mail", "Economy", "progress", call(HasNewMail) and "New mail received" or nil)
    end
end)
local function unspentTalents()
    local hasPoints, classPoints, specPoints = call(C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints)
    if hasPoints == true then
        if read(classPoints) and read(specPoints) and type(classPoints) == "number" and type(specPoints) == "number" then
            local total = classPoints + specPoints
            if total > 0 then return total, true end
        end
        return nil, true
    elseif hasPoints == false then
        return 0, false
    end

    local count = call(GetNumTalentPoints)
    if type(count) ~= "number" then count = call(GetUnspentTalentPoints, false, false) end
    if type(count) ~= "number" then count = call(GetNumUnspentTalents) end
    if type(count) == "number" then return count, count > 0 end
end

local function updateTalents()
    if not S.IsEnabled("talent", "Progress") then
        persistent("talent", "talent", "Progress", "progress")
        return
    end
    local count, hasPoints = unspentTalents()
    if hasPoints == nil then return end
    local title = hasPoints and (count and ("Unspent talent points · %d"):format(count) or "You have unspent talent points")
    persistent("talent", "talent", "Progress", "progress", title)
    return hasPoints
end

local function replaceNativeTalentAlert(alert)
    if not addon.db or not S.IsEnabled("talent", "Progress") or not alert:IsShown() then return end
    local text = alert.Text and call(alert.Text.GetText, alert.Text)
    local nativeText = _G.TALENT_MICRO_BUTTON_UNSPENT_TALENTS
    if type(nativeText) == "string" and type(text) == "string" and text ~= nativeText then return end
    local hasPoints = updateTalents()
    if hasPoints == nil and type(nativeText) == "string" and text == nativeText then
        S.Set("talent", "talent", "Progress", "progress", "You have unspent talent points")
    end
    if S.active.talent then alert:Hide() end
end

local function hideTalentHelpTip()
    if S.active.talent and S.IsEnabled("talent", "Progress") and HelpTip and _G.TALENT_MICRO_BUTTON_UNSPENT_TALENTS then
        call(HelpTip.Hide, HelpTip, UIParent, _G.TALENT_MICRO_BUTTON_UNSPENT_TALENTS)
    end
end

local helpTipHooked, legacyHooked
local talentWatcher = CreateFrame("Frame")
talentWatcher:RegisterEvent("ADDON_LOADED")
talentWatcher:RegisterEvent("PLAYER_LOGIN")
talentWatcher:SetScript("OnEvent", function()
    if not helpTipHooked and HelpTip and MainMenuMicroButton_ShowAlert and hooksecurefunc then
        helpTipHooked = true
        hooksecurefunc("MainMenuMicroButton_ShowAlert", function(_, text)
            local nativeText = _G.TALENT_MICRO_BUTTON_UNSPENT_TALENTS
            if not addon.db or type(nativeText) ~= "string" or not read(text) or text ~= nativeText then return end
            if not S.IsEnabled("talent", "Progress") then return end
            if updateTalents() == nil then
                S.Set("talent", "talent", "Progress", "progress", "You have unspent talent points")
            end
            hideTalentHelpTip()
        end)
    end
    local alert = _G.TalentMicroButtonAlert
    if not legacyHooked and alert then
        legacyHooked = true
        alert:HookScript("OnShow", replaceNativeTalentAlert)
        replaceNativeTalentAlert(alert)
    end
end)

local function refreshTalentAlert()
    updateTalents()
    hideTalentHelpTip()
end
for _, event in ipairs({"PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED",
    "TRAIT_CONFIG_LIST_UPDATED", "PLAYER_SPECIALIZATION_CHANGED"}) do A.On(event, refreshTalentAlert) end
A.On("PLAYER_LEVEL_UP", function(level)
    if read(level) and type(level) == "number" then S.Set("level", "level", "Progress", "success", "Reached level " .. level) end
    refreshTalentAlert()
end)
A.On("ENCOUNTER_END", function(id, name, _, _, success)
    if read(id) and read(name) and read(success) and type(id) == "number" and type(name) == "string" and success == 1 then
        S.Set("boss:" .. id, "boss", "Progress", "success", "Defeated " .. name)
    end
end)
A.On("lootDetails", function(id, _, _, item)
    local cfg = settings()
    if not cfg.enabled then return end
    if type(item.quality) == "number" and item.quality >= 3 or cfg.valuable > 0 and type(item.price) == "number" and item.price >= cfg.valuable then
        S.Set("loot:" .. id, "loot", "Inventory", "progress", "Looted " .. item.name)
    end
end)
A.On("altMaterial", function(id, _, entry)
    S.Set("altMaterial:" .. id, "altMaterial", "Inventory", "progress", entry.identity.name .. " needs " .. D.Item(id))
end)

local examples = {
    {"critical", "Equipment", "Main hand is broken", "Repair required"},
    {"critical", "Inventory", "Inventory is full", "Cleanup is available when loot cannot fit"},
    {"warning", "Class", "Main hand temporary enhancement expired", "Apply a new poison"},
    {"progress", "Professions", "Skinning reached 60"},
    {"success", "Quests", "Finding Warmth · ready to turn in"},
    {"progress", "Equipment", "You looted a better item", "Show in bags · Fine Steel Dagger"},
}

local function makeFrame()
    frame = CreateFrame("Frame", "BaziUISmartAlerts", UIParent)
    frame:SetSize(290, 36)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:Hide()
    return frame
end

local function makeCard(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.tile = addon.Theme:RoundedCard(row)
    row.tile:SetAllPoints()
    row.tile:SetFrameLevel(row:GetFrameLevel())
    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetSize(16, 16)
    row.title = addon.Inventory.Label(row)
    row.title:SetPoint("TOPLEFT", 31, -7)
    row.title:SetPoint("TOPRIGHT", -6, -7)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.detail = addon.Inventory.Label(row)
    row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.detail:SetPoint("RIGHT", -6, 0)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(false)
    row.fade = row:CreateAnimationGroup()
    local alpha = row.fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    row.enter = alpha
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.mute then
            self.mute()
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        elseif button == "LeftButton" and self.action and not InCombatLockdown() then self.action() end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.title:GetText())
        if self.alertDetail then GameTooltip:AddLine(self.alertDetail, 1, 1, 1, true) end
        if self.mute then GameTooltip:AddLine("Right-click to mute this reminder. Re-enable it in Dashboard > Alerts.", 0.68, 0.63, 0.57, true) end
        GameTooltip:AddLine("Red: urgent · Gold: reminder · Purple: progress · Green: success", 0.85, 0.73, 0.55, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    return row
end

function S.GetFrame() return frame end
function S.Settings() return settings() end
function S.LayoutMode(enabled)
    layoutMode = enabled
    S.Render()
end
local previewVersion = 0
function S.Preview(mode)
    previewVersion = previewVersion + 1
    local version = previewVersion
    sample = mode == "resolved" and 1 or mode
    S.Render()
    if mode == "resolved" then C_Timer.After(1.8, function()
        if version == previewVersion then sample = "resolved"; S.Render() end
    end) end
end

function S.Render()
    if not addon.db or frame and addon.Movers and addon.Movers.IsDragging(frame) then return end
    local cfg = settings()
    local rows = S.Visible()
    if sample then
        rows = {}
        for i, entry in ipairs(examples) do
            if sample == "all" or sample == i then
                rows[#rows + 1] = {id = i, severity = entry[1], category = entry[2], title = entry[3], detail = entry[4]}
            end
        end
    end
    local maximum = cfg.dashboard and D.Settings().enabled and D.WidgetSettings("smartAlerts").enabled
        and D.WidgetSettings("smartAlerts").mode ~= "hidden" and not sample and 1 or cfg.maximum
    if not sample and not layoutMode and (not cfg.standalone or #rows == 0) then
        if frame then frame:Hide() end
        return
    end
    local parent, h = frame or makeFrame(), 0
    local opening = not parent:IsShown()
    for i = 1, math.min(#rows, sample == "all" and #examples or maximum) do
        local alert = rows[i]
        local row = cards[i] or makeCard(parent)
        cards[i] = row
        local color = S.colors[alert.severity]
        addon.Theme:PaintQuestCard(row.tile, cfg.opacity / 100, true)
        row.icon:SetTexture(art .. (S.categories[alert.category] or "Bell") .. ".tga")
        row.icon:SetVertexColor(unpack(color))
        addon.Inventory.GeneralFont(row.title, -2, "")
        addon.Inventory.GeneralFont(row.detail, -4, "")
        row.title:SetText(alert.title)
        row.title:SetTextColor(unpack(color))
        row.detail:SetText(alert.detail or "")
        row.detail:SetTextColor(0.78, 0.72, 0.64)
        row:SetHeight(alert.detail and 43 or 31)
        row:ClearAllPoints()
        if cfg.growUp then
            row:SetPoint("BOTTOMLEFT", 0, h)
            row:SetPoint("BOTTOMRIGHT", 0, h)
        else
            row:SetPoint("TOPLEFT", 0, -h)
            row:SetPoint("TOPRIGHT", 0, -h)
        end
        h = h + row:GetHeight() + 4
        row.action = not layoutMode and alert.action or nil
        row.mute = not sample and not layoutMode and alert.mute or nil
        row.alertDetail = alert.detail
        row:EnableMouse(not layoutMode)
        row:Show()
        if row.marker ~= alert.id and cfg.animation > 0 then
            row.enter:SetDuration(cfg.animation / 100)
            row.fade:Stop()
            row.fade:Play()
        end
        row.marker = alert.id
    end
    for i = math.min(#rows, sample == "all" and #examples or maximum) + 1, #cards do cards[i]:Hide(); cards[i].marker = nil end
    parent:SetSize(cfg.width, math.max(layoutMode and 36 or 1, h - 4))
    parent:SetScale(cfg.scale / 100)
    local node = cfg.growUp and "BOTTOM" or "TOP"
    local ratio = UIParent:GetEffectiveScale() / parent:GetEffectiveScale()
    local point, relativeTo, relativePoint, x, y = parent:GetPoint(1)
    if point ~= node or relativeTo ~= UIParent or relativePoint ~= "CENTER" or x ~= cfg.x * ratio or y ~= cfg.y * ratio then
        parent:ClearAllPoints()
        parent:SetPoint(node, UIParent, "CENTER", cfg.x * ratio, cfg.y * ratio)
    end
    parent:Show()
    if opening and not sample and not layoutMode and addon.Inventory.ShowFirstUseGuide then
        addon.Inventory.ShowFirstUseGuide(parent, "hideSmartAlertsGuide", "Reading Smart Alerts",
            guideText)
    end
end

A.On("settings", function()
    refreshTalentAlert()
    if _G.TalentMicroButtonAlert then replaceNativeTalentAlert(_G.TalentMicroButtonAlert) end
    if ticker then ticker:Cancel(); ticker = nil end
    if not settings().enabled and not dashboardBuffsEnabled() then glowReminders({}) end
    if settings().enabled then
        ticker = C_Timer.NewTicker(10, function()
            A.Queue("class")
            A.Queue("quests")
        end)
    end
    changed()
end)
A.On("PLAYER_REGEN_ENABLED", changed)
A.On("PLAYER_REGEN_DISABLED", changed)

D.Register({id = "smartAlerts", label = "Alerts", priority = 95, read = function()
    local cfg, rows = settings(), {}
    if cfg.dashboard and canDisplay(cfg) then
        local advisor = addon.LootUpgrades
        local upgrades = not cfg.critical and S.IsEnabled("upgrade", "Equipment") and advisor and advisor.DashboardUpgrades()
        local function appendUpgrades()
            for _, row in ipairs(upgrades) do
                if #rows >= cfg.maximum then break end
                rows[#rows + 1] = row
            end
            upgrades = nil
        end
        for i, alert in ipairs(S.Visible()) do
            if upgrades and alert.severity ~= "critical" then appendUpgrades() end
            if #rows >= cfg.maximum then break end
            -- Where both destinations are enabled, standalone carries the first visible alert.
            local duplicated = (alert.rule == "selfBuff" or alert.rule == "poison") and dashboardBuffsEnabled()
            if not duplicated and alert.rule ~= "upgrade" and (not cfg.standalone or i > 1) then
                rows[#rows + 1] = {label = alert.title, labelColor = S.colors[alert.severity], tooltip = alert.detail and (alert.detail .. "\n\n" .. guideText) or guideText, click = alert.action, mute = alert.mute,
                    icon = art .. (S.categories[alert.category] or "Bell") .. ".tga", highlight = alert.severity == "critical"}
            end
        end
        if upgrades then appendUpgrades() end
    end
    return D.Rows(rows, #rows > 0, #rows > 0)
end})
