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
    {"fishing", "Fishing pole in combat", "Equipment"}, {"poison", "Expired temporary weapon enhancement", "Class"},
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

function S.Set(id, rule, category, severity, title, detail, persistent, action, deliveredByWatcher)
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
        if not cfg.dnd and (not cfg.critical or severity == "critical") and (combat and cfg.combat or not combat and cfg.peace) then
            local embedded = cfg.dashboard and D.Settings().enabled and D.WidgetSettings("smartAlerts")
            if embedded and embedded.enabled and embedded.mode ~= "hidden" then
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

local hadEnhancement, expiredEnhancement = {}, {}
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

local function scanClass(snapshot)
    local meta = snapshot.identity
    if not meta then return end
    local cfg = settings()
    if meta.token == "HUNTER" then
        S.RefreshAmmo(snapshot)
        local exists = call(UnitExists, "pet")
        local dead = exists and call(UnitIsDeadOrGhost, "pet")
        local unhappy = exists and call(GetPetHappiness) == 1
        persistent("pet", "pet", "Class", dead and "critical" or "warning", dead and "Hunter pet is dead" or unhappy and "Hunter pet is unhappy" or nil)
    end
    if meta.token == "ROGUE" or meta.token == "SHAMAN" then
        local main, _, _, _, off = call(GetWeaponEnchantInfo)
        if type(main) ~= "boolean" then return end
        for index, slot in ipairs({"MainHand", "SecondaryHand"}) do
            local piece = snapshot.gear and snapshot.gear[slot]
            local applied = index == 1 and main or index == 2 and read(off) and off
            if applied then expiredEnhancement[slot], hadEnhancement[slot] = nil, piece and piece.id
            elseif hadEnhancement[slot] then
                expiredEnhancement[slot] = piece and piece.id == hadEnhancement[slot] and piece.id or nil
                hadEnhancement[slot] = nil
            end
            if not piece or piece.id ~= expiredEnhancement[slot] then expiredEnhancement[slot] = nil end
            local name = A.SlotNames[slot]
            persistent("enhancement:" .. slot, "poison", "Class", "warning",
                expiredEnhancement[slot] and (name .. " temporary enhancement expired") or nil)
        end
    end
end

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
    row:SetScript("OnClick", function(self)
        if self.action and not InCombatLockdown() then self.action() end
    end)
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
        row:EnableMouse(row.action ~= nil)
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
end

A.On("settings", function()
    refreshTalentAlert()
    if _G.TalentMicroButtonAlert then replaceNativeTalentAlert(_G.TalentMicroButtonAlert) end
    if ticker then ticker:Cancel(); ticker = nil end
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
            if alert.rule ~= "upgrade" and (not cfg.standalone or i > 1) then
                rows[#rows + 1] = {label = alert.title, labelColor = S.colors[alert.severity], tooltip = alert.detail, click = alert.action,
                    icon = art .. (S.categories[alert.category] or "Bell") .. ".tga", highlight = alert.severity == "critical"}
            end
        end
        if upgrades then appendUpgrades() end
    end
    return D.Rows(rows, #rows > 0, #rows > 0)
end})
