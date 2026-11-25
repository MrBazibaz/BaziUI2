local ns = BaziUI.Chat
local Theme = ns.Theme

local Alerts = {}
ns.Alerts = Alerts

-- Unread messages put a dot on the tab, right of its name, in the color the
-- unread messages have in the chat: guild green, whisper pink, party blue...
-- the player's own chat colors. While a tab's unread messages are all of one
-- kind it keeps that color; once they mix, it turns gold. A dot is everyone's
-- "unread" (Discord, Slack, Telegram); a line under the tab read as "selected"
-- and several of them crowded the header. A soft halo around the dot breathes
-- twice when it appears, then once every 12 seconds: a light that never stops
-- moving keeps asking for attention, one that never moves again is easy to
-- miss.
--
-- Only people talking count (say, yell, guild, party, raid, instance,
-- whispers, channels): system lines, loot, combat and the player's own
-- messages don't light anything. Tabs are filters over one chat, so the same
-- message often reaches several of them: each message is counted once, by the
-- event's line ID. One seen in a window on show lights nothing, and opening a
-- tab reads its messages in every other tab too. Each tab can opt out from its menu
-- (Alerts > "New messages", added with Menu.ModifyMenu, Blizzard's way for
-- addons to extend a menu without tainting its other entries). General and the
-- combat log start with it off.
-- Everchat's own art, drawn at its size in screen pixels: a 6px disc
-- (Media/Dot.tga, top-left of an 8x8 texture) and a soft round glow
-- (Media/Halo.tga). The dot sits in the tab's right padding, a little right of
-- the name, so tabs keep their width.
local DOT_TEXTURE = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\Dot"
local DOT_PIXELS = 6
local DOT_TEXTURE_PIXELS = 8
local DOT_GAP = 3
local HALO_TEXTURE = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\Halo"
local HALO_PIXELS = 20
-- Each breath goes from off to full and back to off.
local PEAK_ALPHA = 1
local LOW_ALPHA = 0
local REST_ALPHA = 0
local BREATHS = 2
local BREATH_SECONDS = 0.9
-- After the first breaths, one more every so often while it's unread: a
-- reminder, not a light that never stops moving.
local REMIND_SECONDS = 12

-- CHAT_MSG_ events that carry someone talking.
local CONVERSATION = {
	SAY = true, YELL = true,
	GUILD = true, OFFICER = true, GUILD_DISCORD = true,
	PARTY = true, PARTY_LEADER = true,
	RAID = true, RAID_LEADER = true, RAID_WARNING = true,
	INSTANCE_CHAT = true, INSTANCE_CHAT_LEADER = true,
	WHISPER = true, BN_WHISPER = true,
	CHANNEL = true, COMMUNITIES_CHANNEL = true,
}

local L = ns.L

-- Unread messages by chat frame, oldest first: { id = line ID or nil, color }.
-- Marks by tab. Never stored on Blizzard frames.
local states = {}
-- Line IDs of the conversation messages each frame got while out of sight
-- (whether or not its tab alerts: opening General reads them everywhere too),
-- and those already seen, newest last; both bounded.
local received = {}
local seen, seenOrder = {}, {}
local MAX_REMEMBERED = 500
-- Puts a tab's dot out (defined with the marks below).
local ClearMark
local glows = {}
local hooked = {}

local function TabOf(chatFrame)
	return _G[chatFrame:GetName() .. "Tab"]
end

-- Per character, by window ID: the player's choice where it differs from the
-- default.
local function GetSettings()
	local key = ns.CharacterKey()
	ns.db.alerts = ns.db.alerts or {}
	ns.db.alerts[key] = ns.db.alerts[key] or {}
	return ns.db.alerts[key]
end

-- Sounds. A mention plays the game's own whisper sound (someone talking to
-- you), when the option is on. Each tab can also ring for its new messages
-- while it isn't on show, with a sound of its own (2026-10-12, the user: a
-- sound for every tab in use, all of a tab's alerts in one table): its menu's
-- audio alert switch or the options window's table, per character by window
-- ID like the visual alert; off by default except in whisper windows. A tab
-- starts with the sound of what it shows: a singing bowl for guild, a toast
-- of tankards for a group, war drums for a raid, a glass tapped twice for
-- whispers, a shop's door bell for Trade, a kalimba for mixed or other talk
-- (General, a channel's tab). In v0.39.0 and v0.40.0 the sound belonged to
-- the message's kind, and before v0.41.0 a switch per kind sat beside the
-- tabs' own switches: two boxes for one thing, the user found. Everchat's own
-- sounds (Media/Sounds, made by art/sounds.py; CLAUDE.md has the rounds
-- tried).
-- It plays when the tab's first unread message arrives, then at most once a
-- minute while messages keep coming unread, and starts over once the tab is
-- opened: a busy channel shouldn't ring with every line. And one sound at a
-- time: a message reaches every tab that shows it.
local MENTION_SOUND = SOUNDKIT and SOUNDKIT.TELL_MESSAGE

-- Everchat's sounds by group, in the options' order: the themed ones, nods
-- to the game's world (2026-10-12, the user's idea and picks: a murloc's
-- gurgle, the level-up "ding"), one for each class (its signature spell,
-- from the game's own sounds made into a short alert; in the game's class
-- order, its class shown before its name), then the instruments the user
-- liked in the rounds.
local SOUNDS = {
	{ key = "softDrop", file = "SoftDrop", label = "Soft Drop", group = "bazi" },
	{ key = "doubleDrop", file = "DoubleDrop", label = "Double Drop", group = "bazi" },
	{ key = "warmChime", file = "WarmChime", label = "Warm Chime", group = "bazi" },
	{ key = "chime", file = "Chime", label = "Chime", group = "bazi" },
	{ key = "echo", file = "Echo", label = "Echo", group = "bazi" },
	{ key = "pulse", file = "Pulse", label = "Pulse", group = "bazi" },
	{ key = "signal", file = "Signal", label = "Signal", group = "bazi" },
	{ key = "urgent", file = "Urgent", label = "Urgent", group = "bazi" },
}
Alerts.SOUNDS = SOUNDS
Alerts.SOUND_GROUPS = {{key = "bazi", label = "Bazi UI"}}
local SOUND_PATH = "Interface\\AddOns\\BaziUI\\Assets\\Sounds\\"
local SOUND_FILES = {}
for _, sound in ipairs(SOUNDS) do
	SOUND_FILES[sound.key] = SOUND_PATH .. sound.file .. ".ogg"
end

-- Sounds other addons share through LibSharedMedia-3.0 (SharedMedia packs,
-- BigWigs, DBM...) can be a tab's sound too, stored as "lsm:" and the
-- sound's name, as the shared fonts are. One no addon shares now (its addon
-- turned off) leaves the tab with its usual sound and stays stored, so it
-- comes back with its addon.
local SHARED = "lsm:"
local OWN_SUFFIX = " (Bazi UI)"
local sharedMedia

local function SharedName(key)
	if type(key) == "string" and key:sub(1, #SHARED) == SHARED then
		return key:sub(#SHARED + 1)
	end
end

-- The library's own "None" is silent (the value 1, or a silent file in older
-- copies), and Everchat's sounds are already listed as they are.
local function Offered(name, file)
	if (type(file) ~= "string" and type(file) ~= "number") or file == 1 then
		return false
	end
	if type(file) == "string" then
		local path = file:lower():gsub("/", "\\")
		if path:find("quiet%.ogg$") or path:find(SOUND_PATH:lower(), 1, true) == 1 then
			return false
		end
	end
	return name:sub(-#OWN_SUFFIX) ~= OWN_SUFFIX
end

local function SharedFile(key)
	local name = SharedName(key)
	local files = name and sharedMedia and sharedMedia:HashTable("sound")
	local file = files and files[name]
	if file and Offered(name, file) then
		return file
	end
end

-- A sound's file (a path or a file ID) by its key, while it's there.
local replacedSounds = {
	blip = "softDrop", bubble = "doubleDrop", ping = "warmChime",
	pip = "softDrop", pop = "doubleDrop", tap = "softDrop",
	hallBell = "chime",
	huntingHorn = "echo",
	toast = "pulse",
	dice = "signal",
	warDrums = "urgent",
	warHorn = "chime",
	celesta = "echo",
	shopBell = "pulse",
	murloc = "signal",
	ding = "urgent",
	fishOn = "chime",
	levelUp = "echo",
	artisan = "pulse",
	thunderClap = "signal",
	holyLight = "urgent",
	hawk = "chime",
	backstab = "echo",
	shield = "pulse",
	healingWave = "signal",
	frost = "urgent",
	sheep = "chime",
	soulShard = "echo",
	moonfire = "pulse",
	glass = "signal",
	kalimba = "urgent",
	bowl = "chime",
	lute = "echo",
	dulcimer = "pulse",
	vibraphone = "signal",
	marimba = "urgent",
}

function Alerts.ResolveSoundKey(key)
	return replacedSounds[key] or key
end

local function SoundFile(key)
	return SOUND_FILES[Alerts.ResolveSoundKey(key)] or SharedFile(key)
end

-- The sounds other addons share, for the options' list ({ key, label }), in
-- the library's order.
function Alerts.SharedSounds()
	local list = {}
	local files = sharedMedia and sharedMedia:HashTable("sound")
	if not files then
		return list
	end
	for _, name in ipairs(sharedMedia:List("sound")) do
		if Offered(name, files[name]) then
			table.insert(list, { key = SHARED .. name, label = name })
		end
	end
	return list
end

-- Everchat's sounds are shared too, for other addons' sound lists (boss
-- timers, auras), under their English names and Everchat's, so a name
-- stays the same whatever the client's language.
ns.Fonts.WhenSharedMedia(function(media)
	sharedMedia = media
	for _, sound in ipairs(SOUNDS) do
		media:Register(media.MediaType.SOUND, sound.label .. OWN_SUFFIX, SOUND_FILES[sound.key])
	end
end)

-- The sound a tab starts with, by the one kind of talk it shows (its message
-- groups, Trade by its channel), else the kalimba.
local GROUP_KINDS = {
	GUILD = "guild", OFFICER = "guild",
	PARTY = "party", INSTANCE_CHAT = "party",
	RAID = "raid", RAID_WARNING = "raid",
	WHISPER = "whisper", BN_WHISPER = "whisper",
}
local KIND_SOUNDS = { guild = "echo", party = "pulse", raid = "urgent", whisper = "chime", trade = "signal" }
local OTHER_SOUND = "chime"
-- Trade's zone channel, the same in every language.
local TRADE_ZONE_CHANNEL = 2

-- PlaySoundFile isn't in the generated API docs (it's the classic global):
-- without it, the event calendar's chime.
local SOUND_GAP = 2
-- How soon a tab rings again; a whisper window sooner, as another person may
-- be writing.
local lastSound = 0
-- By chat frame: when it last rang or the player last spoke in it, since it
-- was last read.

-- Per character, by window ID, where they differ from the default: whether
-- the tab rings (`tabSounds`) and its sound (`tabSoundChoices`), apart, so
-- turning it off and on keeps the sound.
local function CharacterTable(name)
	local key = ns.CharacterKey()
	ns.db[name] = ns.db[name] or {}
	ns.db[name][key] = ns.db[name][key] or {}
	return ns.db[name][key]
end

local function GetSoundSettings()
	return CharacterTable("tabSounds")
end

local function GetSoundChoices()
	return CharacterTable("tabSoundChoices")
end

-- A whisper window: a person's temporary one, or one showing only whispers
-- (the "+" menu's preset). Its lists are only read.
local function IsWhisperWindow(chatFrame)
	if chatFrame.isTemporary then
		return chatFrame.chatType == "WHISPER" or chatFrame.chatType == "BN_WHISPER"
	end
	local groups = chatFrame.messageTypeList
	if not groups or not next(groups) then
		return false
	end
	for _, group in pairs(groups) do
		if group ~= "WHISPER" and group ~= "BN_WHISPER" then
			return false
		end
	end
	return true
end

-- Whether the tab rings. Unset, only whisper windows do.
function Alerts.HasSound(chatFrame)
	local saved = GetSoundSettings()[chatFrame:GetID()]
	if saved == nil then
		return IsWhisperWindow(chatFrame)
	end
	return saved ~= false
end

-- Who wants to know when a switch changes: a tab's alerts (the options
-- window's table, while the tab's menu changes them, and the other way
-- round), and the side bar's switches (its buttons and the options window).
local switchListeners = {}

function Alerts.OnSwitchChanged(listener)
	table.insert(switchListeners, listener)
end

local function SwitchChanged(chatFrame)
	for _, listener in ipairs(switchListeners) do
		listener(chatFrame)
	end
end

-- Only choices that differ from the default are kept.
-- Not "different and enabled or nil": that turns false into nil, so a whisper
-- window, on by default, could never be turned off (2026-10-12, the user).
function Alerts.SetSound(chatFrame, enabled)
	enabled = enabled and true or false
	if enabled == IsWhisperWindow(chatFrame) then
		GetSoundSettings()[chatFrame:GetID()] = nil
	else
		GetSoundSettings()[chatFrame:GetID()] = enabled
	end
	SwitchChanged(chatFrame)
end

-- A sound's file and, should it not play, the kit to play instead.
local function SoundOf(key)
	return PlaySoundFile and SoundFile(key) or nil
end

-- The one kind of talk a tab shows (its lists are only read): a group's
-- party and raid count as the party's; nil for mixed or other talk.
local function TabKind(chatFrame)
	if IsWhisperWindow(chatFrame) then
		return "whisper"
	end
	local kinds, count = {}, 0
	local function Add(kind)
		if not kinds[kind] then
			kinds[kind] = true
			count = count + 1
		end
	end
	for _, group in pairs(chatFrame.messageTypeList or {}) do
		if GROUP_KINDS[group] then
			Add(GROUP_KINDS[group])
		end
	end
	local trade = C_ChatInfo.GetChannelShortcutForChannelID and C_ChatInfo.GetChannelShortcutForChannelID(TRADE_ZONE_CHANNEL)
	for _, channel in pairs(chatFrame.channelList or {}) do
		if trade and type(channel) == "string" and channel:lower() == trade:lower() then
			Add("trade")
		end
	end
	if count == 2 and kinds.party and kinds.raid then
		return "party"
	end
	return count == 1 and next(kinds) or nil
end

-- The sound a tab starts with: its kind's (or the one the options give that
-- kind, account-wide: new whisper tabs' today, every kind's in earlier
-- versions), else the kalimba.
function Alerts.GetDefaultSound(chatFrame)
	local kind = TabKind(chatFrame)
	if not kind then
		return OTHER_SOUND
	end
	local chosen = ns.db.kindSounds and ns.db.kindSounds[kind]
	return SoundFile(chosen) and Alerts.ResolveSoundKey(chosen) or KIND_SOUNDS[kind]
end

-- The sound every new whisper tab starts with, the game's own for each person
-- included: a tab's own choice is forgotten when it closes.
function Alerts.GetWhisperSound()
	local chosen = ns.db.kindSounds and ns.db.kindSounds.whisper
	return SoundFile(chosen) and chosen or KIND_SOUNDS.whisper
end

function Alerts.SetWhisperSound(key)
	if not SoundFile(key) then
		return
	end
	ns.db.kindSounds = ns.db.kindSounds or {}
	ns.db.kindSounds.whisper = key ~= KIND_SOUNDS.whisper and key or nil
	SwitchChanged()
end

-- A tab's sound (a SOUNDS key), whether it rings or not.
function Alerts.GetTabSound(chatFrame)
	local chosen = GetSoundChoices()[chatFrame:GetID()]
	return SoundFile(chosen) and chosen or Alerts.GetDefaultSound(chatFrame)
end

function Alerts.SetTabSound(chatFrame, key)
	if not SoundFile(key) then
		return
	end
	GetSoundChoices()[chatFrame:GetID()] = key ~= Alerts.GetDefaultSound(chatFrame) and key or nil
	SwitchChanged(chatFrame)
end

-- A sound file, or a sound kit when there's no file or it doesn't play (a
-- shared sound whose file is gone), on the master channel: many players
-- mute sound effects, and an alert they can't hear is no alert (ElvUI's
-- chat alerts do the same). The master volume still applies.
local function Play(file, kit)
	if file and PlaySoundFile(file, "Master") then
		return
	end
	if kit then
		PlaySound(kit, "Master")
	end
end

-- A sound heard on purpose (the options' play buttons, picking one): never
-- held back by the quiet option or the gap between alerts.
function Alerts.Preview(key)
	if SoundFile(key) then
		Play(SoundOf(key))
	end
end

-- The tab's sound on purpose: turning its alert on says at once that it works.
function Alerts.PlayTabSound(chatFrame)
	Play(SoundOf(Alerts.GetTabSound(chatFrame)))
end

-- Silent while the player has muted Everchat's audio alerts (the rail's
-- bell or the options; 2026-10-12, a "do not disturb" kept apart from the
-- rule below), or by that rule while fighting or inside an instance.
local function Quiet()
	return ns.db.soundsMuted or (ns.db.quietInCombat and (UnitAffectingCombat("player") or IsInInstance()))
end

function Alerts.IsMuted()
	return ns.db.soundsMuted and true or false
end

-- Its listeners (the rail's bell, the options window) hear it at once.
function Alerts.SetMuted(muted)
	ns.db.soundsMuted = muted and true or false
	SwitchChanged()
end

-- Another of the side bar's switches changed (Skin.lua's hidden chat).
function Alerts.NotifySwitchChanged()
	SwitchChanged()
end

-- Whether it played.
local function Ring(file, kit)
	local now = GetTime()
	if (file or kit) and not Quiet() and now - lastSound >= SOUND_GAP then
		lastSound = now
		Play(file, kit)
		return true
	end
	return false
end

-- Off by default for General, which gets everything and would light up
-- whenever another tab is on show, and for the combat log; on for the rest.
local function IsEnabledByDefault(chatFrame)
	return chatFrame ~= DEFAULT_CHAT_FRAME and chatFrame ~= COMBATLOG
end
Alerts.IsEnabledByDefault = IsEnabledByDefault

function Alerts.IsEnabled(chatFrame)
	local choice = GetSettings()[chatFrame:GetID()]
	if choice == nil then
		return IsEnabledByDefault(chatFrame)
	end
	return choice
end

function Alerts.SetEnabled(chatFrame, enabled)
	-- Only a choice that differs from the default is stored.
	if enabled == IsEnabledByDefault(chatFrame) then
		GetSettings()[chatFrame:GetID()] = nil
	else
		GetSettings()[chatFrame:GetID()] = enabled
	end
	if not enabled then
		ClearMark(chatFrame)
	end
	SwitchChanged(chatFrame)
end

-- The unread mark: the dot and its breathing halo, on any frame (the tabs
-- here; Header.lua puts one on the chevron and on its list's rows). The
-- caller anchors mark.dot; the halo follows it.
local MarkMixin = {}

function MarkMixin:Light(color)
	self.color = color
	self.glow:SetVertexColor(color.r, color.g, color.b)
	-- A vertex color's alpha is the texture's own: the dot keeps its fade.
	self.dot:SetVertexColor(color.r, color.g, color.b, self.fade)
	if not self.dot:IsShown() then
		self.dot:Show()
		self.glow:SetAlpha(PEAK_ALPHA)
		self.glow:SetShown(self.fade > 0)
		self.pulse:Play()
	end
end

-- How much of the mark shows: all of it, save while the chat hides at rest
-- (Tabs.lua, Header.lua). The halo breathes by its own animations, so it
-- only shows or not.
function MarkMixin:SetFade(alpha)
	if alpha == self.fade then
		return
	end
	self.fade = alpha
	self.dot:SetAlpha(alpha)
	if self:IsLit() then
		self.glow:SetShown(alpha > 0)
	end
end

function MarkMixin:Clear()
	self.color = nil
	self.pulse:Stop()
	self.reminder:Stop()
	self.glow:Hide()
	self.dot:Hide()
end

function MarkMixin:IsLit()
	return self.dot:IsShown()
end

function Alerts.CreateMark(owner)
	local mark = CreateFromMixins(MarkMixin)
	mark.fade = 1
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, owner)
	local dot = owner:CreateTexture(nil, "ARTWORK", nil, 2)
	dot:SetTexture(DOT_TEXTURE)
	dot:SetTexCoord(0, DOT_PIXELS / DOT_TEXTURE_PIXELS, 0, DOT_PIXELS / DOT_TEXTURE_PIXELS)
	dot:SetSize(DOT_PIXELS * px, DOT_PIXELS * px)
	-- An alert stays visible however faded the chat is.
	dot:SetIgnoreParentAlpha(true)
	dot:Hide()
	mark.dot = dot

	local glow = owner:CreateTexture(nil, "BORDER", nil, 2)
	glow:SetTexture(HALO_TEXTURE)
	glow:SetBlendMode("ADD")
	glow:SetSize(HALO_PIXELS * px, HALO_PIXELS * px)
	glow:SetPoint("CENTER", dot, "CENTER")
	glow:SetIgnoreParentAlpha(true)
	glow:Hide()
	mark.glow = glow

	local function Step(group, from, to, duration)
		local step = group:CreateAnimation("Alpha")
		step:SetFromAlpha(from)
		step:SetToAlpha(to)
		step:SetDuration(duration or BREATH_SECONDS)
		step:SetSmoothing("IN_OUT")
		step:SetOrder(#{ group:GetAnimations() })
	end

	-- A breath every REMIND_SECONDS, for as long as it stays lit.
	local reminder = glow:CreateAnimationGroup()
	reminder:SetLooping("REPEAT")
	reminder:SetToFinalAlpha(true)
	Step(reminder, REST_ALPHA, REST_ALPHA, REMIND_SECONDS)
	Step(reminder, REST_ALPHA, PEAK_ALPHA)
	Step(reminder, PEAK_ALPHA, REST_ALPHA)
	mark.reminder = reminder

	-- Breaths when it appears, then the reminders.
	local pulse = glow:CreateAnimationGroup()
	pulse:SetToFinalAlpha(true)
	for _ = 1, BREATHS do
		Step(pulse, PEAK_ALPHA, LOW_ALPHA)
		Step(pulse, LOW_ALPHA, PEAK_ALPHA)
	end
	Step(pulse, PEAK_ALPHA, REST_ALPHA)
	pulse:SetScript("OnFinished", function()
		reminder:Play()
	end)
	mark.pulse = pulse
	return mark
end

-- The color a tab's unread messages show in, or nil while it has none.
local litColors = {}

function Alerts.GetColor(tab)
	return litColors[tab]
end

-- A tab's mark sits a little right of its name, in the tab's right padding,
-- so tabs keep their width; while it's lit the name moves left by half the
-- dot and its gap, centering the two together in the tab.
local function LabelShift(tab)
	local dot = DOT_PIXELS * PixelUtil.ConvertPixelsToUIForRegion(1, tab)
	return ns.Shapes.WholePixels(tab, (DOT_GAP + dot) / 2)
end

-- How much of each tab's mark shows (Alerts.SetTabFade).
local markFades = {}

local function GetMark(tab)
	local mark = glows[tab]
	if not mark then
		mark = Alerts.CreateMark(tab)
		mark.dot:SetPoint("LEFT", tab:GetFontString(), "RIGHT", DOT_GAP, 0)
		mark:SetFade(markFades[tab] or 1)
		glows[tab] = mark
	end
	return mark
end

-- The "flash" style: a soft light rising from the tab's base, in the
-- messages' color, coming and going a second each way until they're read,
-- as the game flashes its tabs (FlashAnim). The game's own texture for it
-- (ChatFrameTab-NewMessage) is drawn for its taller tabs with their art, and
-- on Everchat's header it was a hard line along the base: this is the top
-- half of Everchat's halo, laid on the base, so it's brightest there and
-- fades up and to the sides.
local FLASH_INSET = 2
local FLASH_SHARE = 0.6
local FLASH_PEAK = 0.85
local flashes = {}

local function GetFlash(tab)
	local flash = flashes[tab]
	if not flash then
		flash = tab:CreateTexture(nil, "BORDER", nil, 2)
		flash:SetTexture(HALO_TEXTURE)
		flash:SetTexCoord(0, 1, 0, 0.5)
		flash:SetBlendMode("ADD")
		flash:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", FLASH_INSET, 0)
		flash:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -FLASH_INSET, 0)
		flash:SetHeight(Theme.HEADER_HEIGHT * FLASH_SHARE)
		-- An alert stays visible however faded the tab is.
		flash:SetIgnoreParentAlpha(true)
		flash:Hide()
		local anim = flash:CreateAnimationGroup()
		anim:SetLooping("REPEAT")
		for order, alphas in ipairs({ { 0, FLASH_PEAK }, { FLASH_PEAK, 0 } }) do
			local step = anim:CreateAnimation("Alpha")
			step:SetFromAlpha(alphas[1])
			step:SetToAlpha(alphas[2])
			step:SetDuration(1)
			step:SetSmoothing("IN_OUT")
			step:SetOrder(order)
		end
		flash.anim = anim
		flashes[tab] = flash
	end
	return flash
end

-- The "name" style's reminder: the light across the name again.
local reminders = {}

local function StopReminder(tab)
	if reminders[tab] then
		reminders[tab]:Cancel()
		reminders[tab] = nil
	end
end

-- How tabs flag unread messages: "dot", "name" or "flash". The chevron and
-- its list (Header.lua) always use the dot: the names aren't in sight there.
local function Style()
	local style = ns.db.alertStyle
	if style == "name" or style == "flash" then
		return style
	end
	return "dot"
end

local function Unlight(tab)
	local mark = glows[tab]
	if mark and mark:IsLit() then
		mark:Clear()
	end
	ns.Tabs.SetLabelShift(tab, 0)
	ns.Tabs.SetAlertColor(tab, nil)
	StopReminder(tab)
	local flash = flashes[tab]
	if flash then
		flash.anim:Stop()
		flash:Hide()
	end
end

local function LightTab(tab, color)
	local fresh = litColors[tab] == nil
	litColors[tab] = color
	local style = Style()
	if style == "name" then
		ns.Tabs.SetAlertColor(tab, color, fresh)
		if not reminders[tab] then
			reminders[tab] = C_Timer.NewTicker(REMIND_SECONDS, function()
				ns.Tabs.ShineName(tab)
			end)
		end
	elseif style == "flash" then
		local flash = GetFlash(tab)
		flash:SetVertexColor(color.r, color.g, color.b)
		flash:SetShown((markFades[tab] or 1) > 0)
		if not flash.anim:IsPlaying() then
			flash.anim:Play()
		end
	else
		GetMark(tab):Light(color)
		ns.Tabs.SetLabelShift(tab, LabelShift(tab))
	end
	ns.Tabs.SetAlerting(tab, true)
end

-- A tab's mark fades with the chat only while it hides at rest (Tabs.lua).
function Alerts.SetTabFade(tab, alpha)
	markFades[tab] = alpha
	local mark = glows[tab]
	if mark then
		mark:SetFade(alpha)
	end
	local flash = flashes[tab]
	if flash and litColors[tab] and Style() == "flash" then
		flash:SetShown(alpha > 0)
	end
end

function ClearMark(chatFrame)
	states[chatFrame] = nil
	local tab = TabOf(chatFrame)
	if litColors[tab] then
		litColors[tab] = nil
		Unlight(tab)
		ns.Tabs.SetAlerting(tab, false)
		ns.Header.UpdatePulse()
	end
end

-- The styles as the options offer them: key, name, the sentence that says
-- what it does. The flash goes by the game's own word for its visual alert
-- (the cooldown manager's).
function Alerts.StyleChoices()
	return {
		{ "dot", L.alertDot, L.alertDotTip },
		{ "name", L.alertName, L.alertNameTip },
		{ "flash", CDMVIS_FLASH or L.alertFlash, L.alertFlashTip },
	}
end

local STYLE_TIPS = { dot = "alertDotTip", name = "alertNameTip", flash = "alertFlashTip" }

-- What the chosen style does, in a sentence (the tab menu, the tabs table).
function Alerts.StyleTip()
	return L[STYLE_TIPS[Style()]]
end

-- A style just chosen, shown for a moment on a tab of the chat (the options,
-- as a sound plays when it's picked): the first docked tab that isn't open,
-- lit in gold, put out again unless a message of its own came meanwhile.
-- Nothing to show while some tab is lit already: it shows the style itself.
local PREVIEW_SECONDS = 4
local preview

local function EndPreview()
	if not preview then
		return
	end
	local tab, chatFrame = preview.tab, preview.chatFrame
	preview.timer:Cancel()
	preview = nil
	local messages = states[chatFrame]
	if litColors[tab] and not (messages and #messages > 0) then
		litColors[tab] = nil
		Unlight(tab)
		ns.Tabs.SetAlerting(tab, false)
		ns.Header.UpdatePulse()
	end
end

function Alerts.PreviewStyle()
	EndPreview()
	if next(litColors) then
		return
	end
	for _, id in ipairs(ns.Header.Order()) do
		local chatFrame = _G["ChatFrame" .. id]
		if chatFrame and Alerts.Covers(chatFrame) and not chatFrame:IsShown() then
			local tab = TabOf(chatFrame)
			LightTab(tab, Theme.GOLD)
			ns.Header.UpdatePulse()
			preview = { tab = tab, chatFrame = chatFrame, timer = C_Timer.NewTimer(PREVIEW_SECONDS, EndPreview) }
			return
		end
	end
end

-- Every lit tab again in the style now chosen (the options).
function Alerts.ApplyStyle()
	local lit = {}
	for tab, color in pairs(litColors) do
		lit[tab] = color
	end
	for tab, color in pairs(lit) do
		Unlight(tab)
		litColors[tab] = nil
		LightTab(tab, color)
	end
end

-- One color object per chat color, so unread messages share it and compare
-- by identity.
local colors = {}

local function ColorOf(r, g, b)
	local key = ("%.3f %.3f %.3f"):format(r, g, b)
	local color = colors[key]
	if not color then
		color = CreateColor(r, g, b)
		colors[key] = color
	end
	return color
end

-- The color of the first unread message while they're all of one kind, gold
-- once they mix.
local function Show(chatFrame)
	local messages = states[chatFrame]
	if not messages or #messages == 0 then
		ClearMark(chatFrame)
		return
	end
	local color = messages[1].color
	for _, message in ipairs(messages) do
		if message.color ~= color then
			color = Theme.GOLD
			break
		end
	end
	LightTab(TabOf(chatFrame), color)
	ns.Header.UpdatePulse()
end

-- A ring of the last MAX_REMEMBERED IDs (order doesn't matter to its
-- readers); returns the one it forgot.
local function Remember(list, id)
	local index = (list.last or 0) % MAX_REMEMBERED + 1
	list.last = index
	local forgotten = list[index]
	list[index] = id
	return forgotten
end

-- IDs waiting in some tab's unread list: only those need a search when read.
local pending = {}

-- Told of every line ID read (Whispers.lua: a whisper read in the chat is
-- read in its notice too).
local seenListeners = {}

function Alerts.OnSeen(listener)
	table.insert(seenListeners, listener)
end

-- A message was read: it stops counting in every tab.
local function MarkSeen(id)
	if seen[id] then
		return
	end
	seen[id] = true
	for _, listener in ipairs(seenListeners) do
		listener(id)
	end
	local forgotten = Remember(seenOrder, id)
	if forgotten then
		seen[forgotten] = nil
	end
	if not pending[id] then
		return
	end
	pending[id] = nil
	for chatFrame, messages in pairs(states) do
		local changed = false
		for index = #messages, 1, -1 do
			if messages[index].id == id then
				table.remove(messages, index)
				changed = true
			end
		end
		if changed then
			Show(chatFrame)
		end
	end
end

-- A message read elsewhere (Whispers.lua's notice): its tabs' dots go.
function Alerts.MarkSeenID(id)
	MarkSeen(id)
end

-- Everything the window got while out of sight is forgotten too.
function Alerts.Clear(chatFrame)
	received[chatFrame] = nil
	ClearMark(chatFrame)
end

-- Mentions: someone else writing the player's name in a conversation. The
-- name shows in gold in the line (Lines.lua composes it, through
-- Alerts.HighlightMentions) and the tab lights up even when its alerts are
-- off: General, off by default, is where public channels name people. Only
-- text outside links is looked at (the sender's own link, items...).
-- Forever names have two words ("Nuul Abrenuntio"): the full name counts in
-- any case; the first name alone ("Nuul") only with its capital, as names are
-- written, since some first names are everyday words ("Short", "Crying") and
-- would light up on every "short" or "crying".
local MENTION_OPEN, MENTION_CLOSE = "|cffffd100", "|r"
-- Shorter first names aren't looked for on their own.
local FIRST_NAME_MIN = 3
-- The names looked for, each as { full = pattern, first = pattern or false,
-- key = its first name in lower case: a line without any key can't mention
-- anyone }: the character's own and, with `mentionAlts` (2026-10-14, the
-- user's call, from the research on other chat addons), the account's other
-- characters Everchat has seen, so a guildmate asking for an alt is seen too.
local mentionNames

local function AnyCase(text)
	return (text:gsub("%a", function(letter)
		return "[" .. letter:upper() .. letter:lower() .. "]"
	end))
end

local function NameEntry(name)
	local entry = {
		key = (name:match("^%S+") or name):lower(),
		full = "%f[%w]" .. AnyCase(name) .. "%f[%W]",
		first = false,
	}
	local first = name:match("^(%S+)%s")
	if first and #first >= FIRST_NAME_MIN then
		entry.first = "%f[%w]" .. first:sub(1, 1) .. AnyCase(first:sub(2)) .. "%f[%W]"
	end
	return entry
end

-- The account's other characters, from the keys Everchat saves its data
-- under ("Name Surname-Realm"; names have no hyphens, realms may). A key with
-- the first name alone, kept under the old form until that character logs in
-- again, is left out: matched as a full name, in any case, a first name that
-- is an everyday word would be marked all over the chat.
local function OtherCharacters(own)
	local names, known = {}, { [own] = true }
	for _, store in ipairs({ ns.db.tabSetups, ns.db.fontSized, ns.db.chatLayouts }) do
		if type(store) == "table" then
			for key in pairs(store) do
				local name = type(key) == "string" and key:match("^([^%-]+)%-")
				if name and name:find("%s") and not known[name] then
					known[name] = true
					table.insert(names, name)
				end
			end
		end
	end
	return names
end

local function MentionNames()
	if mentionNames == nil then
		mentionNames = {}
		local name = ns.PlayerName()
		if name and name ~= "" and name ~= UNKNOWNOBJECT then
			table.insert(mentionNames, NameEntry(name))
			if ns.db.mentionAlts ~= false then
				for _, other in ipairs(OtherCharacters(name)) do
					table.insert(mentionNames, NameEntry(other))
				end
			end
		end
	end
	return mentionNames
end

-- The names a line may hold, by their first names (most lines hold none).
local function Candidates(text)
	local lower, found = text:lower(), nil
	for _, entry in ipairs(MentionNames()) do
		if lower:find(entry.key, 1, true) then
			found = found or {}
			table.insert(found, entry)
		end
	end
	return found
end

-- The option changed: the names are gathered again.
function Alerts.ResetMentions()
	mentionNames = nil
end

-- Applies `fn` to the parts of a line outside links.
local function OutsideLinks(text, fn)
	local parts, position = {}, 1
	while true do
		local first, last = text:find("|H.-|h.-|h", position)
		table.insert(parts, fn(text:sub(position, (first or 0) - 1)))
		if not first then
			break
		end
		table.insert(parts, text:sub(first, last))
		position = last + 1
	end
	return table.concat(parts)
end

local function Mentions(text)
	local entries = Candidates(text)
	if not entries then
		return false
	end
	local found = false
	OutsideLinks(text, function(part)
		for _, entry in ipairs(entries) do
			found = found or part:find(entry.full) ~= nil or (entry.first and part:find(entry.first) ~= nil)
		end
		return part
	end)
	return found
end

-- Wraps full names first (marked with \1...\2 meanwhile), then first names
-- where they aren't already inside a full one.
local function Highlight(part, entries)
	for _, entry in ipairs(entries) do
		part = part:gsub(entry.full, "\1%0\2")
	end
	for _, entry in ipairs(entries) do
		if entry.first then
			part = part:gsub("([^\1]*)(\1?[^\2]*\2?)", function(plain, marked)
				return plain:gsub(entry.first, "\1%0\2") .. marked
			end)
		end
	end
	return (part:gsub("\1", MENTION_OPEN):gsub("\2", MENTION_CLOSE))
end

-- Lines.lua: a conversation line from someone else, with the player's name in gold.
function Alerts.HighlightMentions(text, event, own)
	if not ns.db.mentions or own or type(event) ~= "string" or not CONVERSATION[strsub(event, 10)] then
		return text
	end
	local entries = Candidates(text)
	if not entries then
		return text
	end
	return OutsideLinks(text, function(part)
		return Highlight(part, entries)
	end)
end

-- Shown means read: selected on the dock, or floating.
local function IsOnShow(chatFrame)
	return not chatFrame.isDocked or chatFrame == FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
end

-- Whether a window on show shows this message too, for messages without a
-- readable line ID, which can't be marked seen: a window gets the events of
-- its message groups (it registers them), and of channels the ones in its
-- lists (by zone channel or by name, when those can be read). Its lists are
-- only read. `inUse`: only a window the player is attending.
local WHISPER_GROUPS = {
	CHAT_MSG_WHISPER = "WHISPER",
	CHAT_MSG_WHISPER_INFORM = "WHISPER",
	CHAT_MSG_BN_WHISPER = "BN_WHISPER",
	CHAT_MSG_BN_WHISPER_INFORM = "BN_WHISPER",
}

-- Whether a window that takes whispers shows this one, by the game's own
-- rules (ChatFrameOverrides.lua): with "New whispers" in a tab of their own,
-- only that person's tab shows them; a window kept to some people shows
-- only theirs, and one that left someone out doesn't show theirs.
local function ShowsWhisper(chatFrame, group, sender)
	if not (type(sender) == "string" and canaccessvalue(sender)) then
		return true
	end
	local person = sender:lower()
	local target = chatFrame.chatTarget
	if chatFrame.chatType == group and type(target) == "string" and canaccessvalue(target)
		and target:lower() == person then
		return true
	end
	local mode = C_CVar.GetCVar("whisperMode")
	if mode == "popout" then
		return false
	end
	if chatFrame.privateMessageList and not chatFrame.privateMessageList[person] then
		return false
	end
	if chatFrame.excludePrivateMessageList and chatFrame.excludePrivateMessageList[person]
		and mode ~= "popout_and_inline" then
		return false
	end
	return true
end

local function ShownElsewhere(event, eventArgs, inUse)
	local zone = eventArgs and eventArgs[7]
	zone = type(zone) == "number" and canaccessvalue(zone) and zone > 0 and zone or nil
	local channel = eventArgs and eventArgs[9]
	channel = type(channel) == "string" and canaccessvalue(channel) and channel:upper() or nil
	local function Shows(chatFrame)
		if event ~= "CHAT_MSG_CHANNEL" then
			if not chatFrame:IsEventRegistered(event) then
				return false
			end
			local group = WHISPER_GROUPS[event]
			return not group or ShowsWhisper(chatFrame, group, eventArgs and eventArgs[2])
		end
		for index, name in pairs(chatFrame.channelList or {}) do
			if (zone and chatFrame.zoneChannelList and chatFrame.zoneChannelList[index] == zone)
				or (channel and type(name) == "string" and name:upper() == channel) then
				return true
			end
		end
		return false
	end
	for _, name in ipairs(CHAT_FRAMES) do
		local chatFrame = _G[name]
		if chatFrame and chatFrame:IsVisible() and IsOnShow(chatFrame) and Alerts.Covers(chatFrame) and Shows(chatFrame)
			and (not inUse or ns.Skin.IsChatInUse(chatFrame)) then
			return true
		end
	end
	return false
end

-- Whether a window on show that shows this message is in use (Whispers.lua:
-- no notice for a whisper the player is looking at).
function Alerts.SeenInUse(event, eventArgs)
	return ShownElsewhere(event, eventArgs, true)
end

-- A message was added to a window (Blizzard passes the event and its
-- arguments along): light the tab if the window is docked out of sight and
-- the message hasn't been seen in another window.
local function OnAddMessage(chatFrame, message, r, g, b, _, _, _, event, eventArgs)
	-- Lines History adds back were read before.
	if type(event) ~= "string" or not CONVERSATION[strsub(event, 10)] or not r or ns.History.ReplayTime() then
		return
	end
	-- The player's own messages (the sender's GUID may be a secret value).
	local guid = eventArgs and eventArgs[12]
	if guid and canaccessvalue(guid) and guid == UnitGUID("player") then
		return
	end
	-- The same line ID reaches every window the message is added to. Without
	-- a readable one (a secret value) it can't be marked seen: it counts in its
	-- own tab unless a window on show shows it too.
	local id = eventArgs and eventArgs[11]
	if id and not canaccessvalue(id) then
		id = nil
	end
	local mentioned = ns.db.mentions and type(message) == "string" and canaccessvalue(message) and Mentions(message)
	if mentioned and ns.db.mentionSound and not ns.IsChannelMuted(event, eventArgs and eventArgs[8]) then
		Ring(nil, MENTION_SOUND)
	end

	if IsOnShow(chatFrame) then
		if id then
			MarkSeen(id)
		end
		return
	end
	if id then
		if seen[id] then
			return
		end
		received[chatFrame] = received[chatFrame] or {}
		Remember(received[chatFrame], id)
	elseif ShownElsewhere(event, eventArgs) then
		return
	end
	-- Whispers always light up, as Blizzard's own flash (whose light along
	-- the tab is replaced by the dot) did, even in a tab with alerts off.
	local whisper = event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER"
	if not Alerts.IsEnabled(chatFrame) and not mentioned and not whisper then
		return
	end
	local messages = states[chatFrame] or {}
	states[chatFrame] = messages
	local color = ColorOf(r, g, b)
	table.insert(messages, { id = id, color = color })
	if id then
		pending[id] = true
	end
	if #messages > MAX_REMEMBERED then
		table.remove(messages, 1)
	else
		-- Already lit in this color, or gold: the mark stays as it is.
		local lit = Alerts.GetColor(TabOf(chatFrame))
		if lit and (lit == color or lit == Theme.GOLD) and #messages > 1 then
			return
		end
	end
	Show(chatFrame)
end

-- Opening a window reads what it got while out of sight, in every tab.
local function OnShow(chatFrame)
	local ids = received[chatFrame]
	Alerts.Clear(chatFrame)
	if ids then
		for _, id in ipairs(ids) do
			MarkSeen(id)
		end
	end
end

-- The combat log never gets conversation messages: no alerts there, and no
-- hook on its AddMessage (Lines and History leave it alone too).
function Alerts.Covers(chatFrame)
	return chatFrame ~= COMBATLOG
end

local function Setup(chatFrame)
	if hooked[chatFrame] or not Alerts.Covers(chatFrame) then
		return
	end
	hooked[chatFrame] = true
	if not ns.SkipsHook("alerts") then
		hooksecurefunc(chatFrame, "AddMessage", ns.Guard("Alerts.OnAddMessage", OnAddMessage))
	end
	chatFrame:HookScript("OnShow", OnShow)
end

local function SetupAllChatFrames()
	for _, name in pairs(CHAT_FRAMES) do
		Setup(_G[name])
	end
end

-- Everchat's part of the tab menu, all added here so its order never
-- depends on which addon callback runs first: at the top, a section in
-- Blizzard's style (a gold title like their "Display" and "Filters", the
-- switch for the tab's visual alert and the one for its sound; which sound is chosen
-- in the options window's table), a divider, then "Copy chat" over
-- Blizzard's window
-- entries. The combat log only gets "Copy chat". Through Menu.ModifyMenu,
-- Blizzard's way for addons to add entries without tainting the menu's
-- other handlers.
-- Returns where the next entry goes.
local function AddAlertsSection(rootDescription, chatFrame)
	rootDescription:Insert(MenuUtil.CreateTitle(L.tabAlertsTitle), 1)

	local function IsNotifying()
		return Alerts.IsEnabled(chatFrame)
	end
	local function ToggleNotify()
		Alerts.SetEnabled(chatFrame, not Alerts.IsEnabled(chatFrame))
	end
	local notify = MenuUtil.CreateCheckbox(L.tabNotify, IsNotifying, ToggleNotify)
	notify:SetOnEnter(function(frame)
		ns.Links.ShowSmallTip(frame, "ANCHOR_RIGHT", { { Alerts.StyleTip(), HIGHLIGHT_FONT_COLOR } })
	end)
	notify:SetOnLeave(function(frame)
		ns.Links.HideSmallTip(frame)
	end)
	rootDescription:Insert(notify, 2)
	rootDescription:Insert(MenuUtil.CreateDivider(), 3)
	return 4


end

local function AddMenuEntries(owner, rootDescription)
	local chatFrame = owner and owner.GetID and _G["ChatFrame" .. owner:GetID()]
	if not chatFrame then
		return
	end
	local index = 1
	if Alerts.Covers(chatFrame) then
		index = AddAlertsSection(rootDescription, chatFrame)
	end
	rootDescription:Insert(ns.Links.CreateCopyEntry(chatFrame), index)
	-- The docked chat's lock (Resize.lua), in the game's words for the lock
	-- it offers on its other windows, right above its own window entries.
	if chatFrame.isDocked or chatFrame == DEFAULT_CHAT_FRAME then
		local text = ns.Resize.IsLocked() and UNLOCK_WINDOW or LOCK_WINDOW
		rootDescription:Insert(MenuUtil.CreateButton(text, function()
			ns.Resize.SetLocked(not ns.Resize.IsLocked(), true)
		end), index + 1)
		index = index + 1
	end
	-- The game never closes its combat log: its tab can leave the strip, and
	-- the options bring it back (which the chat says).
	if chatFrame == COMBATLOG and chatFrame.isDocked then
		rootDescription:Insert(MenuUtil.CreateButton(L.hideTab, function()
			ns.Header.SetCombatLogHidden(true)
			Alerts.NotifySwitchChanged()
			ns.Print(L.combatLogTabHidden:format(L.optionsWindowTitle, L.optionsHistoryTabs))
		end), index + 1)
	end
end

function Alerts.Init()
	SetupAllChatFrames()
	hooksecurefunc("FCF_OpenNewWindow", SetupAllChatFrames)
	hooksecurefunc("FCF_OpenTemporaryWindow", SetupAllChatFrames)
	-- A closed window's ID may come back as another window.
	hooksecurefunc("FCF_Close", function(frame, fallback)
		local closed = fallback or frame or FCF_GetCurrentChatFrame()
		if closed then
			GetSettings()[closed:GetID()] = nil
			GetSoundSettings()[closed:GetID()] = nil
			GetSoundChoices()[closed:GetID()] = nil
			Alerts.Clear(closed)
		end
	end)
	-- Before 2026-10-12 a tab's switch held its sound's name: it rings, with
	-- that sound. The switches by kind of message of 2026-10-12 are gone.
	local switches, choices = GetSoundSettings(), GetSoundChoices()
	for id, saved in pairs(switches) do
		if type(saved) == "string" then
			if SOUND_FILES[saved] and choices[id] == nil then
				choices[id] = saved
			end
			switches[id] = true
		end
	end
	ns.db.kindOff = nil
	-- Temporary windows never outlive a reload.
	for _, settings in ipairs({ GetSettings(), GetSoundSettings(), GetSoundChoices() }) do
		for id in pairs(settings) do
			if id > Constants.ChatFrameConstants.MaxChatWindows then
				settings[id] = nil
			end
		end
	end
	Menu.ModifyMenu("MENU_FCF_TAB", AddMenuEntries)
end
