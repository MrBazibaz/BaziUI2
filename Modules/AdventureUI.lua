local addon, A, D = BaziUI, BaziUI.Adventure, BaziUI.Dashboard
local M, J, S = addon.AltManager, addon.Journey, addon.SmartAlerts
local UI = {}
addon.AdventureUI = UI
local I, theme = addon.Inventory, addon.Theme
local labels = {alerts = "Smart Alerts", journey = "Journey", alts = "Alt Manager"}
local tabs = {
    alerts = {"History"},
    journey = {"Overview", "Timeline", "Sessions", "Milestones", "Exploration", "Dungeons & Raids", "PvP", "Professions", "Records"},
    alts = {"Characters", "Inventory", "Professions", "Crafting Goals", "Economy", "Mail & Auctions", "Lockouts"},
}
local art = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\"
local icons = {Character = "Diamond", Exploration = "Pin", Questing = "Quest", Professions = "Settings",
    Equipment = "Shield", PvE = "Dagger", PvP = "Dagger", Notes = "Chat"}
local views = {}

local function stamp(at)
    return type(at) == "number" and date("%d %b %H:%M", at) or "Unknown"
end
local function duration(seconds)
    return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
end
local function money(value) return type(value) == "number" and I.Money(value) or "Unknown" end
local function contains(value, query) return type(value) == "string" and value:lower():find(query, 1, true) ~= nil end
local function add(rows, label, value, icon, color)
    rows[#rows + 1] = {label = label, value = value, icon = icon, color = color}
end

local function demoCharacters()
    local function copper(n, bound) return {id = 2770, link = "Copper Ore", count = n, quality = 1, bound = bound} end
    local function character(key, name, token, level, realm, faction, balance, count, age)
        return {identity = {key = key, name = name, token = token, class = token, level = level, realm = realm,
            faction = faction, money = balance, zone = "Ironforge"}, updated = A.Now() - age, login = A.Now() - age,
            bags = {time = A.Now() - age, items = {copper(count, faction == "Horde")}}, free = 11}
    end
    local a = character("sample1", "Baby Wasabi", "ROGUE", 8, "Amberfall", "Alliance", 18392, 12, 600)
    local b = character("sample2", "Buba Ganush", "WARRIOR", 22, "Amberfall", "Alliance", 125440, 34, 86300)
    local c = character("sample3", "Papa Bonk", "SHAMAN", 14, "Stonewatch", "Horde", 80125, 8, 345600)
    b.bank = {time = A.Now() - 9 * 86400, items = {copper(80, false)}}
    a.skills = {Skinning = {rank = 63, maximum = 75, profession = true}}
    b.skills = {Mining = {rank = 118, maximum = 150, profession = true}}
    b.mail = {time = b.updated, total = 2, entries = {}}
    return {sample1 = a, sample2 = b, sample3 = c}
end

local function demoJournal()
    local now = A.Now()
    local j = {identity = demoCharacters().sample1.identity, first = now - 432000, entries = {},
        totals = {quest = 18, deaths = 2, xp = 14320, seconds = 9000, earned = 25300, dungeons = 1, wins = 2, levels = 3, skillPoints = 25},
        records = {quests = 7, xpHour = 5600, goldHour = 8500, fastest = {name = "The Stockade", seconds = 1560},
            vendor = {name = "Runed Training Blade", value = 6200}},
        sessions = {{at = now - 86400, seconds = 3800, quest = 7, xp = 5000, earned = 6500, levels = 1},
            {at = now - 3600, seconds = 2800, quest = 4, xp = 2500, earned = 4100, levels = 1}}}
    local list = {{"Character", "Reached level 8"}, {"Exploration", "Visited Kharanos"},
        {"Professions", "Engineering reached 50"}, {"Questing", "Turned in Secure the Mountain"},
        {"PvE", "First recorded defeat of Bazil Thredd"}, {"PvP", "Won Warsong Gulch"},
        {"Equipment", "First recorded rare item · Fine Steel Dagger"}, {"Notes", "Set out for Redridge"}}
    for i = 1, 72 do
        local entry = list[(i - 1) % #list + 1]
        j.entries[i] = {category = entry[1], title = entry[2], at = now - (73 - i) * 1300, milestone = i % 3 == 0}
    end
    return j
end

local journeyCategories = {Exploration = "Exploration", ["Dungeons & Raids"] = "PvE", PvP = "PvP", Professions = "Professions"}
local function journeyRows(view)
    local rows, tab = {}, view.section
    local journal = view.preview and view.sample or J.Current()
    if not journal then return rows end
    if tab == "Overview" then
        local char = journal.identity or A.current and A.current.identity
        if char then add(rows, char.name, ("%s · %s · Level %s"):format(char.race or "?", char.class or "?", char.level or "?"), "Diamond") end
        add(rows, "Recorded since", stamp(journal.first))
        for _, field in ipairs({{"levels", "Levels gained"}, {"quest", "Quests turned in"}, {"xp", "Experience"},
            {"deaths", "Deaths"}, {"materials", "Materials looted"}, {"skillPoints", "Profession skill points"}, {"bosses", "Bosses"},
            {"dungeons", "Dungeons completed"}, {"matches", "PvP matches"}, {"wins", "PvP wins"}}) do
            if journal.totals[field[1]] then add(rows, field[2], tostring(journal.totals[field[1]])) end
        end
        add(rows, "Recorded playtime", duration(journal.totals.seconds or 0))
        add(rows, "Recorded balance gains", money(journal.totals.earned or 0))
        add(rows, "Recorded balance losses", money(journal.totals.spent or 0))
    elseif tab == "Sessions" then
        for i = #journal.sessions, 1, -1 do
            local session = journal.sessions[i]
            add(rows, stamp(session.at), ("%s · %d quests · %d levels"):format(duration(session.seconds), session.quest or 0, session.levels or 0), "Diamond")
            add(rows, ("XP %d · Deaths %d · Skill +%d"):format(session.xp or 0, session.deaths or 0, session.skillPoints or 0),
                money(session.earned or 0))
        end
    elseif tab == "Records" then
        local record = journal.records
        if record.quests then add(rows, "Quests in one session", tostring(record.quests)) end
        if record.xpHour then add(rows, "Highest recorded XP/hour", tostring(record.xpHour)) end
        if record.goldHour then add(rows, "Highest recorded balance gains/hour", money(record.goldHour)) end
        if record.vendor then add(rows, "Highest vendor value · " .. record.vendor.name, money(record.vendor.value)) end
        if record.fastest then add(rows, "Shortest observed run · " .. record.fastest.name, duration(record.fastest.seconds)) end
    else
        local category = journeyCategories[tab]
        for i = #journal.entries, 1, -1 do
            local entry = journal.entries[i]
            if (not category or entry.category == category) and (tab ~= "Milestones" or entry.milestone)
                and (view.query == "" or contains(entry.title, view.query)) then
                add(rows, entry.title, stamp(entry.at), icons[entry.category])
            end
        end
    end
    return rows
end

local function altRows(view)
    local characters = view.preview and view.sample or M.Characters()
    local rows, ordered, total, tab = {}, {}, 0, view.section
    for key, char in pairs(characters) do
        local meta = char.identity
        if meta and (not view.realm or meta.realm == view.realm) and (not view.faction or meta.faction == view.faction)
            and (not view.character or view.character == key) then ordered[#ordered + 1] = {key = key, char = char} end
    end
    table.sort(ordered, function(a, b)
        local x, y = a.char.identity, b.char.identity
        if view.sort == "Level" and x.level ~= y.level then return (x.level or 0) > (y.level or 0) end
        if view.sort == "Gold" and x.money ~= y.money then return (x.money or 0) > (y.money or 0) end
        if view.sort == "Class" and x.class ~= y.class then return (x.class or "") < (y.class or "") end
        if view.sort == "Last login" and a.char.login ~= b.char.login then return (a.char.login or 0) > (b.char.login or 0) end
        return x.name == y.name and a.key < b.key or x.name < y.name
    end)
    if tab == "Inventory" and view.query == "" then
        add(rows, "Search by item name or ID", nil, "Search")
        return rows
    end
    local itemTotals = {}
    for _, entry in ipairs(ordered) do
        local char, key = entry.char, entry.key
        local meta = char.identity
        local class = RAID_CLASS_COLORS and RAID_CLASS_COLORS[meta.token]
        local color = class and {class.r, class.g, class.b}
        local heading = meta.name .. " · " .. meta.realm
        if tab == "Characters" and (view.query == "" or contains(heading .. " " .. (meta.class or ""), view.query)) then
            add(rows, heading, ("%s · %s · Level %s"):format(meta.faction or "?", meta.class or "?", meta.level or "?"), "Group", color)
            add(rows, (meta.zone or "Unknown zone") .. " · seen " .. stamp(char.login), "Updated " .. stamp(char.updated))
            add(rows, "Gold · bags free · rested XP", ("%s  ·  %s  ·  %s"):format(money(meta.money), char.free or "?", meta.rested or "?"))
            local gear = char.gear and char.gear.MainHand
            if gear and gear.link then add(rows, "Main hand", gear.link) end
        elseif tab == "Inventory" then
            local found = {}
            local function search(source, location)
                if not source or view.location and view.location ~= location then return end
                for _, item in ipairs(source.items) do
                    local name = item.link and (item.link:match("%[(.-)%]") or item.link) or D.Item(item.id)
                    if (not view.quality or view.quality == item.quality) and (tostring(item.id) == view.query or contains(name, view.query)) then
                        local result = found[item.id] or {label = name}
                        found[item.id] = result
                        result[location] = (result[location] or 0) + item.count
                        itemTotals[item.id] = (itemTotals[item.id] or 0) + item.count
                    end
                end
            end
            search(char.bags, "bags")
            search(char.bank, "bank")
            if next(found) then
                add(rows, heading, "Bags " .. stamp(char.bags and char.bags.time) .. " · Bank " .. stamp(char.bank and char.bank.time), "Group", color)
                for _, item in pairs(found) do
                    local bags, bank = item.bags or (char.bags and "0" or "?"), item.bank or (char.bank and "0" or "?")
                    add(rows, item.label, view.location and tostring(view.location == "bags" and bags or bank) or ("Bags %s · Bank %s"):format(bags, bank))
                end
            end
        elseif tab == "Professions" then
            for name, skill in pairs(char.skills or {}) do
                if skill.profession and (view.query == "" or contains(name, view.query)) then
                    add(rows, name .. " · " .. heading, ("%d / %d"):format(skill.rank, skill.maximum), "Settings", color)
                end
            end
            if view.query ~= "" then
                for name, known in pairs(char.recipes or {}) do
                    for _, recipe in pairs(known.entries) do
                        if contains(recipe.name, view.query) or (recipe.output and tostring(recipe.output) == view.query) then
                            add(rows, recipe.name, name .. " · " .. heading, "Settings", color)
                            for id, need in pairs(recipe.materials) do add(rows, D.Item(id), tostring(need)) end
                        end
                    end
                end
            end
        elseif tab == "Crafting Goals" then
            local goals = view.preview and {sample = {name = "Copper Modulator", amount = 1, materials = {[2770] = 8}}} or M.Goals(key)
            for _, goal in pairs(goals) do
                add(rows, goal.name .. " · " .. heading, "×" .. goal.amount, "Settings", color)
                for id, per in pairs(goal.materials or {}) do
                    local matches = M.Ownership(id, false, characters, meta)
                    local own, supply = nil, 0
                    for _, match in ipairs(matches) do
                        if match.key == key then own = match.bags else supply = supply + (match.transferable or 0) end
                    end
                    if own == nil and char.bags then own = 0 end
                    add(rows, view.preview and "Copper Ore" or D.Item(id),
                        ("%s / %d in bags · %d unbound on eligible alts"):format(own or "?", per * goal.amount, supply))
                end
            end
        elseif tab == "Economy" then
            if type(meta.money) == "number" then total = total + meta.money end
            add(rows, heading, money(meta.money), "Diamond", color)
            if char.goldChange then add(rows, "Last balance change", (char.goldChange >= 0 and "+" or "−") .. money(math.abs(char.goldChange))) end
        elseif tab == "Mail & Auctions" then
            add(rows, heading, nil, "Bell", color)
            add(rows, "Mailbox · " .. stamp(char.mail and char.mail.time), char.mail and tostring(char.mail.total) or "Unknown")
            add(rows, "Auctions · " .. stamp(char.auctions and char.auctions.time), char.auctions and tostring(char.auctions.total) or "Unknown")
            for _, mail in ipairs(char.mail and char.mail.entries or {}) do add(rows, mail.title, mail.sender) end
            for _, auction in ipairs(char.auctions and char.auctions.entries or {}) do
                add(rows, auction.link or "Item data unavailable", auction.count and ("×" .. auction.count))
            end
        elseif tab == "Lockouts" then
            add(rows, heading, stamp(char.lockouts and char.lockouts.time), "Shield", color)
            for _, raid in ipairs(char.lockouts and char.lockouts.entries or {}) do
                if not raid.reset or raid.reset > A.Now() then add(rows, raid.name, "Reset " .. stamp(raid.reset)) end
            end
        end
    end
    if tab == "Economy" and #ordered > 0 then table.insert(rows, 1, {label = "Total recorded balance", value = money(total), icon = "Diamond"}) end
    for id, amount in pairs(itemTotals) do table.insert(rows, 1,
        {label = view.preview and "Total recorded · Copper Ore" or "Total recorded · " .. D.Item(id), value = tostring(amount)}) end
    return rows
end

local function historyRows(view)
    local rows = {}
    if view.preview then
        local demo = {{"Main hand is broken", "critical"}, {"Inventory is full", "critical"},
            {"Skinning reached 60", "progress"}, {"Finding Warmth · ready to turn in", "success"}, {"Mail collected", "success"}}
        for _, alert in ipairs(demo) do add(rows, alert[1], "Preview", "Bell", S.colors[alert[2]]) end
        return rows
    end
    for i = #S.history, 1, -1 do
        local alert = S.history[i]
        add(rows, alert.title, stamp(alert.created) .. (alert.resolved and " · Resolved" or ""),
            S.categories[alert.category], S.colors[alert.severity])
    end
    return rows
end

local readers = {alerts = historyRows, journey = journeyRows, alts = altRows}
local function render(view)
    if not view.list:IsVisible() then return end
    local data = readers[view.kind](view)
    if #data == 0 then add(data, "No recorded results.") end
    local shown = math.min(#data, view.limit or 40)
    for i = 1, shown do
        local row = view.rows[i]
        if not row then
            row = theme:RoundedCard(view.list)
            row:SetPoint("TOPLEFT", 1, -((i - 1) * 31))
            row:SetPoint("TOPRIGHT", -2, -((i - 1) * 31))
            row:SetHeight(28)
            row.icon = row:CreateTexture(nil, "OVERLAY")
            row.icon:SetSize(13, 13)
            row.icon:SetPoint("LEFT", 8, 0)
            row.left = I.Label(row)
            row.right = I.Label(row)
            row.left:SetJustifyH("LEFT")
            row.right:SetJustifyH("RIGHT")
            row.left:SetWordWrap(false)
            row.right:SetWordWrap(false)
            row.right:SetPoint("RIGHT", -9, 0)
            row.right:SetWidth(230)
            row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
            view.rows[i] = row
        end
        local entry = data[i]
        if view.kind == "alerts" then
            theme:PaintQuestCard(row)
        else
            row:SetBackdropColor(0.14, 0.115, 0.09, 0.54)
            row:SetBackdropBorderColor(theme:AccentInk(0.22))
        end
        row.icon:SetTexture(entry.icon and art .. entry.icon .. ".tga" or nil)
        row.icon:SetVertexColor(theme:Accent())
        row.left:SetPoint("LEFT", entry.icon and 28 or 9, 0)
        I.GeneralFont(row.left, -1, "")
        I.GeneralFont(row.right, -3, "")
        row.left:SetTextColor(unpack(entry.color or {0.89, 0.78, 0.62}))
        row.right:SetTextColor(0.70, 0.65, 0.58)
        row.left:SetText(entry.label)
        row.right:SetText(entry.value or "")
        row:Show()
    end
    for i = shown + 1, #view.rows do view.rows[i]:Hide() end
    local height = shown * 31
    if view.list:GetHeight() ~= height then
        view.list:SetHeight(height)
        if view.bar.SyncRange then view.bar:SyncRange() end
    end
    view.more:SetShown(shown < #data)
end

local function button(parent, label, width, x, y, callback)
    local b = theme:CreateButton(parent, label, width, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetScript("OnClick", callback)
    return b
end

local function dropdown(parent, width, x, y, choices, current, set)
    local control = theme:CreateSettingsDropdown(parent)
    control:SetSize(width, 24)
    control:SetPoint("TOPLEFT", x, y)
    local function sync()
        for _, option in ipairs(choices()) do if option[1] == current() then control:SetText(option[2]); return end end
        control:SetText("All")
    end
    control:SetupMenu(function(_, root)
        for _, option in ipairs(choices()) do
            local value = option[1]
            root:CreateRadio(option[2], function() return current() == value end, function() set(value); sync() end)
        end
    end)
    sync()
    return sync
end

local function edit(parent, width, x, y, placeholder, fn)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 24)
    box:SetPoint("TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetText(placeholder)
    box:SetScript("OnEditFocusGained", function(self) if self:GetText() == placeholder then self:SetText("") end end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) fn(self:GetText()); self:ClearFocus() end)
    return box
end

local function options(values)
    local entries = {}
    for _, value in ipairs(values) do entries[#entries + 1] = {value, value} end
    return entries
end

function UI.Open(kind)
    local view = views[kind]
    if view then
        view.window:ApplyStyle()
        view.window:Show()
        view.window:Raise()
        return
    end
    local window = I.Window("BaziUIAdventure" .. kind, labels[kind], 660, 520)
    view = {window = window, kind = kind, section = tabs[kind][1], query = "", rows = {}}
    views[kind] = view
    local parent = CreateFrame("Frame", nil, window)
    parent:SetPoint("TOPLEFT", 4, -33)
    parent:SetPoint("BOTTOMRIGHT", -4, -3)
    local content = CreateFrame("Frame", nil, parent)
    content:SetPoint("TOPLEFT", 9, -93)
    content:SetPoint("BOTTOMRIGHT", -8, 10)
    local scroll
    view.list, scroll, view.bar = I.Scroll(content, 0, 0)
    scroll:HookScript("OnSizeChanged", function(_, width) view.list:SetWidth(math.max(1, width)) end)
    view.more = button(parent, "Show more", 104, 12, -62, function()
        view.limit = (view.limit or 40) + 40
        render(view)
    end)
    local function redraw()
        view.limit = 40
        view.bar:SetValue(0)
        render(view)
    end
    dropdown(parent, 175, 11, -5, function() return options(tabs[kind]) end, function() return view.section end, function(section)
        view.section = section
        if kind == "journey" and not view.preview then J.Save() end
        redraw()
    end)
    local preview
    preview = button(parent, "Preview", 94, 196, -5, function()
        view.preview = not view.preview
        view.sample = view.preview and (kind == "journey" and demoJournal() or kind == "alts" and demoCharacters()) or nil
        theme:SetButtonActive(preview, view.preview)
        if kind == "alerts" then S.Preview(view.preview and (view.alertSample or "all") or nil) end
        redraw()
    end)
    if kind ~= "alerts" then
        edit(parent, 175, 11, -35, "Search · press Enter", function(value)
            view.query = value:lower():match("^%s*(.-)%s*$")
            redraw()
        end)
    end
    if kind == "alts" then
        dropdown(parent, 111, 196, -35, function() return options({"Name", "Level", "Class", "Gold", "Last login"}) end,
            function() return view.sort or "Name" end, function(value) view.sort = value; redraw() end)
        dropdown(parent, 110, 316, -35, function() return {{"all", "Bags + bank"}, {"bags", "Bags"}, {"bank", "Bank"}} end,
            function() return view.location or "all" end, function(value) view.location = value ~= "all" and value or nil; redraw() end)
        dropdown(parent, 108, 435, -35, function()
            return {{"all", "Any quality"}, {0, "Poor"}, {1, "Common"}, {2, "Uncommon"}, {3, "Rare"}, {4, "Epic"}}
        end, function() return view.quality or "all" end, function(value) view.quality = value ~= "all" and value or nil; redraw() end)
        dropdown(parent, 110, 305, -5, function()
            local result, seen = {{"all", "Any realm"}}, {}
            for _, char in pairs(view.preview and view.sample or M.Characters()) do
                local realm = char.identity and char.identity.realm
                if realm and not seen[realm] then seen[realm] = true; result[#result + 1] = {realm, realm} end
            end
            return result
        end, function() return view.realm or "all" end, function(value) view.realm = value ~= "all" and value or nil; redraw() end)
        dropdown(parent, 110, 422, -5, function() return {{"all", "Any faction"}, {"Alliance", "Alliance"}, {"Horde", "Horde"}} end,
            function() return view.faction or "all" end, function(value) view.faction = value ~= "all" and value or nil; redraw() end)
        dropdown(parent, 110, 537, -5, function()
            local result = {{"all", "Any character"}}
            for key, char in pairs(view.preview and view.sample or M.Characters()) do
                if char.identity then result[#result + 1] = {key, char.identity.name .. " · " .. char.identity.realm} end
            end
            return result
        end, function() return view.character or "all" end, function(value) view.character = value ~= "all" and value or nil; redraw() end)
    elseif kind == "journey" then
        edit(parent, 210, 196, -35, "Journal note · press Enter", function(value)
            if not view.preview then J.Record("Notes", value:sub(1, 240), true); render(view) end
        end)
    else
        dropdown(parent, 185, 11, -35, function()
            return {{"all", "Multiple alerts"}, {1, "Critical durability"}, {2, "Inventory full"}, {3, "Expired enhancement"},
                {4, "Profession skill"}, {5, "Quest completed"}, {"resolved", "Resolved"}}
        end, function() return view.alertSample or "all" end, function(value)
            view.alertSample = value
            if view.preview then S.Preview(value) end
        end)
    end
    window:HookScript("OnShow", function()
        if kind == "journey" and not view.preview then J.Save() end
        render(view)
    end)
    window:HookScript("OnHide", function()
        if kind == "alerts" and view.preview then
            view.preview = false
            theme:SetButtonActive(preview, false)
            S.Preview(nil)
        end
    end)
    window:Show()
    window:Raise()
end

local redraw
function UI.Refresh()
    if redraw or not next(views) then return end
    redraw = C_Timer.NewTimer(0.20, function()
        redraw = nil
        for _, view in pairs(views) do if not view.preview then render(view) end end
    end)
end
A.On("snapshot", UI.Refresh)
A.On("settings", UI.Refresh)
A.On("journal", UI.Refresh)
A.On("alerts", UI.Refresh)
A.On("GET_ITEM_INFO_RECEIVED", UI.Refresh)

local settingsHelp = {
    alerts = {
        enabled = "Checks your gear, inventory and progress and shows alerts when a rule is triggered.",
        standalone = "Shows alerts in a separate movable stack. With Dashboard also selected, this stack keeps the highest-priority alert.",
        dashboard = "Adds active alerts to the Smart Alerts widget in Dashboard. Enable Dashboard and its Smart Alerts widget first. Turn off standalone notifications to show even a single alert in Dashboard.",
        growUp = "Builds the stack upward from its position, keeping the bottom edge in place.",
        combat = "Allows alerts while you are in combat. It also controls optional sounds and chat messages during combat.",
        peace = "Allows alerts outside of combat. It also controls optional sounds and chat messages outside of combat.",
        critical = "Limits the visible list, sounds and chat messages to critical alerts such as a full inventory or broken gear.",
        dnd = "Silences the on-screen list, sounds and chat messages. Alerts still update in History.",
        sound = "Plays the selected sound when an alert first appears. Changing the selection plays a sample.",
        chat = "Writes the first appearance of each alert to chat, where you can read it later.",
        width = "Sets the width of the standalone alert stack.",
        scale = "Scales the entire standalone stack, including icons and text.",
        opacity = "Sets the opacity of the standalone alert card backgrounds. At 100%, the background is fully opaque.",
        maximum = "Limits the number of alerts displayed in each enabled destination. Higher-priority alerts are shown first.",
        duration = "Controls how long one-off alerts stay visible. Issues such as broken gear stay until resolved.",
        animation = "Changes the fade-in time for new standalone cards. Set it to 0 to show cards immediately.",
        free = "Warns when your number of free general-purpose bag slots reaches this threshold.",
        durability = "Warns when a piece of equipped gear falls to this percentage. Broken gear is critical.",
        ammo = "Low ammunition threshold when the Hunter Ammo watcher is off. While it is on, Smart Alerts uses the watcher's thresholds.",
        criticalAmmo = "Critical ammunition threshold when the Hunter Ammo watcher is off. Capped at the low threshold.",
        valuable = "Alerts for loot whose vendor price reaches this value in copper. Quality-based loot alerts work independently.",
    },
    journey = {
        enabled = "Starts recording this character's observed milestones and session totals. Open Journey to see the timeline or add a note.",
        retention = "Sets how many days ordinary timeline entries are kept. Milestones survive age-based cleanup.",
        limit = "Caps the total timeline length. The oldest ordinary entries are removed before milestones.",
    },
    alts = {
        enabled = "Records bags and equipment for characters you log into. Bank contents are updated when you open each character's bank.",
        tooltip = "Adds recorded item ownership to item tooltips. Counts reflect each character's latest saved snapshot.",
        shift = "Keeps ownership information collapsed until you hold Shift over the item.",
        sameRealm = "Limits item tooltip ownership to characters on the current realm.",
        total = "Adds one combined count from matching character snapshots.",
        individual = "Lists characters with a recorded copy and the quantity on each.",
        breakdown = "Shows bags and bank on separate counts. A question mark means the location has no readable snapshot.",
        lastUpdated = "Shows the date of the last bank snapshot beside each character's count.",
        materials = "Lists other characters with a recorded recipe or crafting goal that uses the item.",
    },
}
local alertRuleHelp = {
    durability = "Warns about low durability and marks broken equipped items as critical.",
    empty = "Warns when the main hand, chest, legs or feet slot is empty.",
    fishing = "Warns if you enter combat with a fishing pole in your main hand.",
    poison = "Warns when an observed temporary weapon enhancement expires on the same equipped weapon.",
    ammo = "Warns about low ammunition using the Hunter Ammo watcher's thresholds while it is enabled. Otherwise uses the values above.",
    pet = "Warns if your hunter pet is dead or the client reports it as unhappy.",
    supplies = "Uses the item quantities you set under Dashboard Tracking for your own supplies.",
    bags = "Warns when general-purpose bag space is low. When loot is blocked, the alert can open Inventory Cleanup.",
    loot = "Alerts for rare or higher quality items, and items above your optional vendor price threshold.",
    quest = "Alerts when a tracked quest changes to ready for turn-in.",
    questLog = "Warns when the client reports that the quest log has reached its capacity.",
    questTimer = "Warns when a timed quest has less than two minutes left.",
    skill = "Shows a short notification when a profession or combat skill rises and its row is not already shown in Dashboard.",
    craft = "Alerts when tracked crafting materials or an item quantity goal reaches its target.",
    level = "Shows a short notification when you gain a character level.",
    talent = "Shows how many player talent points are unspent, including points you had at login. The alert clears after you spend them.",
    boss = "Alerts when the game reports a successful boss encounter.",
    reputation = "Alerts when you move up to a higher standing with a faction.",
    mail = "Shows an alert while the game reports new mail.",
    altMaterial = "Alerts when you loot something an alt needs for a tracked crafting goal. Requires Alt Manager.",
    upgrade = "Compares gear using your class and active specialization or talent tree. Click a loot alert to find the green-arrow item in your bags.",
}

function UI.Settings(kind, parent, helpers)
    local cfg = A.Settings(kind)
    local content, scroll, bar = I.Scroll(parent, 0, 4)
    scroll:HookScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    local panel = helpers.panel(content, -4, 350)
    helpers.section(panel, labels[kind], -12)
    local y = -45
    local help = settingsHelp[kind]
    local function checkbox(label, get, set, description)
        local control = theme:CreateCheckbox(panel)
        control:SetSize(21, 21)
        control:SetPoint("TOPLEFT", 24, y)
        local title = helpers.label(panel, label, "GameFontHighlight")
        title:SetPoint("LEFT", control, "RIGHT", 8, 0)
        theme:SettingsHelp(control, label, description, title)
        control:SetChecked(get())
        control:SetScript("OnClick", function(self)
            set(self:GetChecked() == true)
            A.Refresh()
        end)
        y = y - 29
    end
    local function flag(label, key)
        checkbox(label, function() return cfg[key] == true end, function(value) cfg[key] = value end, help[key])
    end
    local function slider(label, key, minimum, maximum)
        helpers.slider(panel, label, "", minimum, maximum, 1, cfg[key], y, function(value)
            cfg[key] = value
            if kind == "alerts" then S.Render() end
            A.Refresh()
        end, true, true, nil, help[key])
        y = y - 40
    end
    flag("Enable " .. labels[kind], "enabled")
    local openLabel = "Open " .. (kind == "alerts" and "history" or labels[kind])
    local open = button(panel, openLabel, 172, 20, y, function() UI.Open(kind) end)
    theme:SettingsHelp(open, openLabel, kind == "alerts" and "Shows alerts from this session, including alerts that have been resolved."
        or "Opens the module window with its data, filters and preview.")
    if kind == "alerts" then
        local move = button(panel, "Move alerts", 120, 201, y, function() addon.Options:OpenMovers("Smart Alerts") end)
        theme:SettingsHelp(move, "Move alerts", "Opens Movers to reposition the separate Smart Alerts stack. Dashboard has its own position.")
        local preview = false
        local sample = button(panel, "Toggle preview", 130, 330, y, function() preview = not preview; S.Preview(preview and "all" or nil) end)
        theme:SettingsHelp(sample, "Toggle preview", "Shows example alerts for positioning and appearance.")
        y = y - 35
        for _, flagInfo in ipairs({{"Show standalone notifications", "standalone"}, {"Show in Dashboard", "dashboard"},
            {"Grow upward", "growUp"}, {"Show in combat", "combat"}, {"Show out of combat", "peace"},
            {"Critical only", "critical"}, {"Do not disturb", "dnd"}}) do flag(unpack(flagInfo)) end
        local soundRow = y
        flag("Play notification sound", "sound")
        dropdown(panel, 190, 263, soundRow, S.SoundChoices, function() return cfg.soundKey end, function(value)
            cfg.soundKey = value
            S.PlaySound(value)
        end)
        flag("Show new notifications in chat", "chat")
        for _, range in ipairs({{"Width", "width", 170, 550}, {"Scale %", "scale", 60, 160}, {"Opacity %", "opacity", 20, 100},
            {"Maximum visible alerts", "maximum", 1, 10}, {"Notification duration (sec)", "duration", 3, 30},
            {"Fade duration (0.01 sec)", "animation", 0, 60}, {"Low free bag slots", "free", 0, 20},
            {"Low durability %", "durability", 1, 50}, {"Low ammunition", "ammo", 0, 1200},
            {"Critical ammunition", "criticalAmmo", 0, 500}, {"Vendor value threshold (copper, 0 = off)", "valuable", 0, 10000}}) do slider(unpack(range)) end
        for _, category in ipairs({"Equipment", "Class", "Quests", "Professions", "Inventory", "Progress", "Economy"}) do
            local key = category
            checkbox(category .. " notifications", function() return not cfg.categories or cfg.categories[key] ~= false end, function(value)
                cfg.categories = cfg.categories or {}
                cfg.categories[key] = value
            end, "Controls all alerts in this category, including any individually enabled rules below.")
        end
        for _, rule in ipairs(S.rules) do
            local key, title, default = rule[1], rule[2], rule[4] ~= false
            checkbox(title, function()
                if cfg.rules and cfg.rules[key] ~= nil then return cfg.rules[key] end
                return default
            end, function(value)
                cfg.rules = cfg.rules or {}
                cfg.rules[key] = value
            end, alertRuleHelp[key])
        end
    elseif kind == "journey" then
        y = y - 35
        slider("History retention (days)", "retention", 7, 365)
        slider("Maximum timeline entries", "limit", 100, 2000)
        local clear
        clear = button(panel, "Clear this character's history", 240, 21, y, function()
            if not clear.confirm then clear.confirm = true; clear:SetText("Confirm clear history"); return end
            clear.confirm = nil
            clear:SetText("Clear this character's history")
            J.Reset()
        end)
        parent:HookScript("OnHide", function() clear.confirm = nil; clear:SetText("Clear this character's history") end)
        y = y - 39
    elseif kind == "alts" then
        y = y - 35
        for _, row in ipairs({{"Show recorded ownership in tooltips", "tooltip"}, {"Show ownership while holding Shift", "shift"},
            {"Only show the current realm in tooltips", "sameRealm"}, {"Show total recorded ownership", "total"},
            {"Show character names and counts", "individual"}, {"Show bag and bank counts separately", "breakdown"},
            {"Show last recorded bank date", "lastUpdated"}, {"Show recorded recipe and goal matches", "materials"}}) do flag(unpack(row)) end
        local target
        local sync = dropdown(panel, 209, 20, y, function()
            local result = {{false, "Choose an offline character"}}
            for key, char in pairs(M.Characters()) do
                if key ~= A.Key() and char.identity then result[#result + 1] = {key, char.identity.name .. " · " .. char.identity.realm} end
            end
            return result
        end, function() return target or false end, function(value) target = value end)
        local forget
        forget = button(panel, "Forget character snapshot", 190, 236, y, function()
            if not target or target == A.Key() then return end
            if forget.confirm ~= target then forget.confirm = target; forget:SetText("Confirm forget snapshot"); return end
            M.Characters()[target] = nil
            forget.confirm, target = nil, nil
            forget:SetText("Forget character snapshot")
            sync()
            UI.Refresh()
        end)
        parent:HookScript("OnHide", function() forget.confirm = nil; forget:SetText("Forget character snapshot") end)
        y = y - 39
    end
    panel:SetHeight(-y + 14)
    content:SetHeight(-y + 25)
    if bar.SyncRange then bar:SyncRange() end
end
