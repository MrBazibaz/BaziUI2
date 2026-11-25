-- Settings and integration for the MIT-licensed Everchat runtime. See Everchat/LICENSE.
BaziUI.Chat = {}
local ns = BaziUI.Chat

local DEFAULTS = {
	timestamps = true,
	guildBadge = true,
	-- "[General]" instead of "[1. General - Zephras Isle]" (Channels.lua).
	shortChannels = true,
	-- Quests, items and spells other players link, named in this client's
	-- language (Names.lua).
	localNames = true,
	-- Everchat's buttons on the side rail (Buttons.lua): copy, options and the
	-- audio alerts' bell (railMute, below) by default.
	railCopy = false,
	railClear = false,
	railOptions = true,
	railRoll = false,
	-- The chat's look (Theme.lua): "everchat", "minimal" (no frame on the
	-- open tab) or "classic" (the game's own tabs and box); in the first two,
	-- its metal, "gold", "silver" or "bronze".
	theme = "everchat",
	themeMetal = "gold",
	-- Chat bubbles (Fonts.lua): their font ("friz", the game's, or a chat
	-- font's key) and size.
	bubbleFont = "friz",
	bubbleSize = 13,
	-- What the bubbles show (Bubbles.lua): items' and spells' icons, links in
	-- their colors, the speaker's name.
	bubbleIcons = true,
	bubbleColors = true,
	bubbleNames = false,
	-- A notice for whispers while the chat isn't in use (Whispers.lua), and
	-- where the player put it (nil: over the chat).
	whisperToasts = true,
	-- How long a whisper notice stays, scaling the time its words take.
	whisperDuration = "normal",
	-- How tabs flag unread messages (Alerts.lua): "dot", "name" or "flash".
	alertStyle = "dot",
	-- The chat while not in use (Skin.lua): "faded", as the game's chat does,
	-- "hidden", only new messages showing for a while, or "always" visible.
	chatRest = "faded",
	lockChat = false,
	-- ...and how long new messages show while it's hidden, in seconds.
	hideAtRestSeconds = 10,
	-- The chat's font: a key of Fonts.FONTS, or "game" for the game's own (Fonts.lua).
	chatFont = "general",
	-- "compact", "normal" or "wide" (Timestamps.lua).
	lineSpacing = "normal",
	-- "none" (the chat's shadow), "thin" or "thick" (Fonts.lua).
	fontOutline = "none",
	-- Where messages start and end: "none", "bands" (every other one on a
	-- lighter ground) or "line" (between them) (Timestamps.lua).
	messageSeparator = "line",
	-- The player's own lines in a color of their choosing (Lines.lua).
	ownColorOn = false,
	ownColor = { 1, 0.925, 0.784 },
	-- Logins, logouts and channel notices in grey (Channels.lua).
	muteNotices = true,
	-- Mentions of the account's other characters too (Alerts.lua).
	mentionAlts = true,
	-- Item icons before item links in Trade (Channels.lua).
	itemIcons = true,
	-- Repeated ads in numbered channels hidden for 5 minutes (Channels.lua).
	hideRepeats = true,
	-- Public lines mostly in these alphabets hidden (Filters.lua).
	hideHan = false,
	hideHangul = false,
	hideCyrillic = false,
	hideLatin = false,
	-- The player's name in gold when others write it; the tab lights up (Alerts.lua).
	mentions = true,
	-- ...and the whisper sound plays (Alerts.lua).
	mentionSound = true,
	-- No Everchat sounds at all until turned back on: the rail's bell (Alerts.lua).
	soundsMuted = false,
	railMute = true,
	-- The whisper notices' switch (Whispers.lua), above the bell.
	railWhispers = true,
	-- The side bar's eye, going through the chat's states at rest (chatRest).
	railHide = true,
	-- No Everchat sounds in combat or inside instances (Alerts.lua).
	quietInCombat = false,
	-- A mark before friends' and guild members' names in public channels (Channels.lua).
	socialMarks = true,
	-- The character's race and class icons before
	-- names in every conversation channel (Channels.lua).
	raceMarks = false,
	classMarks = false,
	-- How players' surnames show in the chat: "full", "initial" or "hidden" (Channels.lua).
	surnames = "full",
	-- "inv" in whispers and guild lines invites their writer with a click (Links.lua).
	inviteLinks = true,
	-- The rail's search button (Search.lua).
	railSearch = false,
	-- Chat kept across reloads and logins (History.lua).
	keepHistory = true,
}


local function settings()
    local profile = BaziUI.db.profile
    profile.chat = profile.chat or {}
    if profile.chat.chatFont == "game" then profile.chat.chatFont = "general" end
    for key, value in pairs(DEFAULTS) do
        if profile.chat[key] == nil then
            profile.chat[key] = type(value) == "table" and CopyTable(value) or value
        end
    end
    ns.db = profile.chat
    return ns.db
end

DEFAULTS.enabled = false
DEFAULTS.inputPosition = "bottom"
DEFAULTS.linkIcons = true
DEFAULTS.itemIcons = false
DEFAULTS.showSeparators = true

ns.defaults = DEFAULTS
ns.Settings = settings
ns.version = BaziUI.version
function ns.Guard(_, fn) return fn end
function ns.SkipsHook() return false end
function ns.Print(message) BaziUI:Print(message) end

function ns.PlayerName()
    local name, surname = (UnitNameUnmodified or UnitName)("player")
    return surname and surname ~= "" and (name .. " " .. surname) or name
end

function ns.CharacterKey()
    return ns.PlayerName() .. "-" .. GetRealmName()
end

ns.Options = {
    Toggle = function() BaziUI.Options:OpenChat() end,
    CreateWindow = function(width, title)
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(width, 180)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        BaziUI.Theme:ApplyWindow(frame)
        if title then
            local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            label:SetPoint("TOP", 0, -12)
            label:SetText(title)
        end
        return frame
    end,
    CreateTextButton = function(parent, label, action)
        local button = BaziUI.Theme:CreateButton(parent, label, 102, 25)
        button:SetScript("OnClick", action)
        return button
    end,
}
ns.CreateWindow = ns.Options.CreateWindow

function ns.Refresh(key)
    local db = ns.db
    if key == "showSeparators" then db.messageSeparator = db.showSeparators and "line" or "none" end
    if not ns.active then return end
    if key == "theme" or key == "themeMetal" or key == "borderColor" or key == "backgroundColor" or key == "backgroundOpacity" or key == "inputPosition" then
        ns.Theme.Set(ns.Theme.PaletteFor(db.theme, db.themeMetal), ns.Theme.IsMinimal(db.theme))
    elseif key == "inputX" or key == "inputY" or key == "inputWidth" or key == "inputHeight" then
        ns.EditBox.RefreshLayout()
    elseif key == "scrollbarLeft" then
        ns.Scroll.RefreshSide()
    elseif key == "chatRest" then
        ns.Skin.SetRestMode(db.chatRest)
        ns.Skin.SetHiddenSeconds()
    elseif key == "hideAtRestSeconds" then
        ns.Skin.SetHiddenSeconds()
    elseif key == "lockChat" then
        ns.Resize.SetLocked(db.lockChat)
    elseif key == "hideButtons" then
        ns.Buttons.Refresh()
        ns.Resize.UpdateLock()
        ns.Header.Relayout()
        ns.Theme.Set(ns.Theme.PaletteFor(db.theme, db.themeMetal), ns.Theme.IsMinimal(db.theme))
    elseif key == "chatFont" or key == "fontOutline" or key == "fontSize" then
        if key == "fontSize" then ns.Fonts.ResetSizes() end
        ns.Fonts.Refresh()
    elseif key == "lineSpacing" then
        ns.Timestamps.ApplySpacing()
    elseif key == "showSeparators" or key == "channelSize" then
        ns.Timestamps.RefreshSeparators()
    elseif key == "timestamps" then
        ns.Timestamps.Refresh()
    elseif key == "whisperToasts" then
        ns.Whispers.SetEnabled(db.whisperToasts)
    elseif key == "alertStyle" then
        ns.Alerts.ApplyStyle()
    elseif key == "surnames" or key == "socialMarks" or key == "raceMarks" or key == "classMarks" or key == "linkIcons" or key == "shortChannels" then
        ns.Lines.Refresh()
    end
end

local eventTypes = {
    "SAY", "YELL", "EMOTE", "GUILD", "OFFICER", "PARTY", "PARTY_LEADER",
    "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
    "WHISPER", "BN_WHISPER", "CHANNEL"
}

local channelEvents = {}
for _, kind in ipairs(eventTypes) do channelEvents["CHAT_MSG_" .. kind] = true end

function ns.HasChannelSoundSetting(event)
    return channelEvents[event] == true
end

function ns.IsChannelMuted(event, number)
    local kind = event:sub(10)
    if kind == "CHANNEL" then
        if (canaccessvalue and not canaccessvalue(number)) or type(number) ~= "number" then return true end
        local _, name = GetChannelName(number)
        if (canaccessvalue and not canaccessvalue(name)) or type(name) ~= "string" then return true end
        kind = "CHANNEL:" .. name
    end
    local choice = ns.db.channelSounds and ns.db.channelSounds[kind]
    return choice == "none" or (choice == nil and ns.HasChannelSoundSetting(event))
end

local function configureChannels(events)
    for _, kind in ipairs(eventTypes) do
        local event = "CHAT_MSG_" .. kind
        events:RegisterEvent(event)
    end
    if SetChatColorNameByClass then
        for _, kind in ipairs(eventTypes) do
            if kind ~= "CHANNEL" and ChatTypeInfo[kind] then SetChatColorNameByClass(kind, true) end
        end
    end
end

function ns.ApplyChannelColors()
    if not ns.active then return end
    for key, color in pairs(ns.db.channelColors or {}) do
        local name = key:match("^CHANNEL:(.+)$")
        local kind = key
        if name then
            local id = GetChannelName(name)
            kind = (not canaccessvalue or canaccessvalue(id)) and id and id > 0 and "CHANNEL" .. id or nil
        end
        local info = kind and ChatTypeInfo[kind]
        if info and (math.abs(info.r - color[1]) > 0.004 or math.abs(info.g - color[2]) > 0.004
            or math.abs(info.b - color[3]) > 0.004) then
            ns.Channels.SetColor(kind, unpack(color))
        end
    end
end

local function start(events)
    local db = settings()
    local everchat = C_AddOns and C_AddOns.IsAddOnLoaded("Everchat")
    if not db.enabled or everchat then
        if db.nativeTimestamps then
            if C_CVar.GetCVar("showTimestamps") == "none" then
                C_CVar.SetCVar("showTimestamps", db.nativeTimestamps)
            end
            db.nativeTimestamps = nil
        end
        if db.enabled and everchat then ns.Print("Chat is paused while Everchat is loaded.") end
        return
    end
    local timeFormat = C_CVar.GetCVar("showTimestamps")
    if timeFormat and timeFormat ~= "none" and timeFormat ~= "" then
        db.nativeTimestamps = timeFormat
        C_CVar.SetCVar("showTimestamps", "none")
    end
    ns.Theme.Set(ns.Theme.PaletteFor(db.theme, db.themeMetal), ns.Theme.IsMinimal(db.theme))
    for _, module in ipairs({"Fonts", "Players", "Skin", "EditBox", "Timestamps",
        "Names", "Lines", "Channels", "Whispers", "Alerts", "Scroll", "History", "Links"}) do
        ns[module].Init()
    end
    ns.Skin.SetHiddenSeconds()
    configureChannels(events)
    ns.active = true
    ns.TabCopy.Init()
    ns.ApplyChannelColors()
    events:RegisterEvent("CHANNEL_UI_UPDATE")
end

local soundTrace, soundHooks
local function traceSound(api, sound, channel)
    if not soundTrace then return end
    if canaccessvalue and not canaccessvalue(sound) then return end
    local stack = debugstack and debugstack(3, 6, 0) or ""
    local source = stack:match("Interface[/\\\\]AddOns[/\\\\][^\n]+") or "client or unknown Lua caller"
    if canaccessvalue and not canaccessvalue(channel) then channel = nil end
    local entry = ("%s %s %s [%s] (%s)"):format(date("%H:%M:%S"), api, tostring(sound),
        type(channel) == "string" and channel or "default", source)
    local entries = soundTrace
    entries[#entries + 1] = entry
    if #entries > 20 then table.remove(entries, 1) end
end

function ns.ToggleSoundTrace()
    if soundTrace then
        local entries = soundTrace
        soundTrace = nil
        ns.Print(#entries == 0 and "Sound trace ended. No Lua sound calls captured." or "Sound trace ended. Latest Lua sound calls:")
        for _, entry in ipairs(entries) do ns.Print(entry) end
        return
    end
    if not soundHooks then
        hooksecurefunc("PlaySound", function(sound, channel) traceSound("PlaySound", sound, channel) end)
        if PlaySoundFile then
            hooksecurefunc("PlaySoundFile", function(file, channel) traceSound("PlaySoundFile", file, channel) end)
        end
        if C_Sound and C_Sound.PlaySound then
            hooksecurefunc(C_Sound, "PlaySound", function(sound, channel) traceSound("C_Sound.PlaySound", sound, channel) end)
        end
        if C_Sound and C_Sound.PlaySoundFile then
            hooksecurefunc(C_Sound, "PlaySoundFile", function(file, channel) traceSound("C_Sound.PlaySoundFile", file, channel) end)
        end
        soundHooks = true
    end
    soundTrace = {}
    ns.Print("Sound trace started. Run /bazi chatsound or /bazi soundtrace again after you hear the sound.")
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, message, sender, _, _, _, _, _, number)
    if event == "PLAYER_LOGIN" then
        local ok, reason = pcall(start, self)
        if not ok then ns.Print("Chat could not start. " .. tostring(reason)) end
        return
    end
    if event == "CHANNEL_UI_UPDATE" then ns.ApplyChannelColors(); return end
    local kind = event:sub(10)
    if kind == "CHANNEL" then
        if (issecretvalue and issecretvalue(number)) or type(number) ~= "number" then return end
        local _, name = GetChannelName(number)
        if (canaccessvalue and not canaccessvalue(name)) or not name then return end
        kind = "CHANNEL:" .. name
    end
    if (issecretvalue and issecretvalue(sender)) or type(sender) ~= "string" then return end
    if sender == ns.PlayerName() or (sender and Ambiguate(sender, "none") == ns.PlayerName()) then return end
    local sound = ns.db.channelSounds and ns.db.channelSounds[kind]
    if sound and sound ~= "none" and sound ~= "mentions" and not ns.Alerts.IsMuted() then ns.Alerts.Preview(sound) end
end)

