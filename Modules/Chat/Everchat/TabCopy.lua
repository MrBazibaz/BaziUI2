local ns = BaziUI.Chat
local Theme = ns.Theme

local TabCopy = {}
ns.TabCopy = TabCopy

-- Setting the chat up again on every character is the chore players of every
-- chat addon complain about most. Each character's tabs are remembered (their
-- names, what they show, font size, Everchat's alert switches and sound, and
-- their order), and the options' "Copy tabs from another character" adds the
-- ones this character lacks. Only when the player asks, and only adding: tabs
-- already here are never changed or removed, General is left alone, and
-- channels aren't joined (a tab lists them; messages come once the character
-- is in them). Prat's Memory module did this on its own, recreating windows
-- and rejoining channels on every alt, and players hated it.
--
-- Windows are created the way the "+" makes them (NewTab.lua), with
-- Blizzard's own functions; CLAUDE.md records what that implies.
local L = ns.L

local WIDTH = 340
local PADDING = 14
local ROW_HEIGHT = 22
local dialog

local function CharacterKey()
	return ns.CharacterKey()
end

local function GetSetups()
	ns.db.tabSetups = ns.db.tabSetups or {}
	return ns.db.tabSetups
end

-- The window open with this name, if any (docked or shown).
local function FindWindow(name)
	for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local frame = _G["ChatFrame" .. id]
		if frame and FCF_IsChatWindowIndexActive(id) and GetChatWindowInfo(id) == name then
			return frame
		end
	end
	return nil
end

-- This character's tabs, from the game's saved window settings.
local function Snapshot()
	local windows = {}
	for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local name, fontSize = GetChatWindowInfo(id)
		if id ~= 2 and name and name ~= "" and FCF_IsChatWindowIndexActive(id) then
			local channels = {}
			local list = { GetChatWindowChannels(id) }
			-- Pairs of channel name and zone.
			for index = 1, #list, 2 do
				table.insert(channels, list[index])
			end
			table.insert(windows, {
				id = id,
				name = name,
				fontSize = fontSize,
				groups = { GetChatWindowMessages(id) },
				channels = channels,
				alerts = ns.Alerts.IsEnabled(_G["ChatFrame" .. id]),
				sound = ns.Alerts.HasSound(_G["ChatFrame" .. id]),
				soundChoice = ns.Alerts.GetTabSound(_G["ChatFrame" .. id]),
			})
		end
	end
	if #windows == 0 then
		GetSetups()[CharacterKey()] = nil
		return
	end
	GetSetups()[CharacterKey()] = {
		savedAt = time(),
		windows = windows,
		-- The strip's order, by window ID (Header.lua's).
		order = CopyTable(ns.db.tabOrder and ns.db.tabOrder[CharacterKey()] or {}),
	}
	ns.db.profileTabs = CopyTable(GetSetups()[CharacterKey()])
	return ns.db.profileTabs
end
TabCopy.Snapshot = Snapshot

-- Adds another character's tabs that this one lacks. Returns how many were
-- added and how many didn't fit (the game allows 10 windows).
local function Copy(key, replace)
	local setup = replace and ns.db.profileTabs or GetSetups()[key]
	if not setup then
		return 0, 0
	end
	local added, missing = 0, 0
	local newIDs = {}
	for _, window in ipairs(setup.windows) do
		if window.id ~= 1 or replace then
			local frame = replace and window.id == 1 and DEFAULT_CHAT_FRAME or FindWindow(window.name)
			local existing = frame ~= nil
			if not frame and FCF_CanOpenNewWindow() then
				frame = FCF_OpenNewWindow(window.name, true)
			end
			if frame and (replace or not existing) then
				if not existing then FCF_CopyChatSettings(frame, DEFAULT_CHAT_FRAME) end
				if replace and window.id == 1 then FCF_SetWindowName(frame, window.name) end
				frame:RemoveAllMessageGroups()
				frame:RemoveAllChannels()
				for _, group in ipairs(window.groups or {}) do
					frame:AddMessageGroup(group)
				end
				for _, channel in ipairs(window.channels or {}) do
					frame:AddChannel(channel)
				end
				if window.fontSize then
					FCF_SetChatWindowFontSize(nil, frame, window.fontSize)
				end
				ns.Alerts.SetEnabled(frame, window.alerts ~= false)
				ns.Alerts.SetSound(frame, window.sound)
				if window.soundChoice then
					ns.Alerts.SetTabSound(frame, window.soundChoice)
				end
				if not existing then added = added + 1 end
			elseif not frame then
				missing = missing + 1
			end
			if frame then newIDs[window.id] = frame:GetID() end
		end
	end
	-- The other character's order, with its windows' new IDs; General and
	-- the combat log keep theirs. Windows only this character has follow.
	if (added > 0 or replace) and setup.order and #setup.order > 0 then
		local order = {}
		for _, id in ipairs(setup.order) do
			local mapped = id == 1 and 1 or newIDs[id]
			if mapped and not tContains(order, mapped) then
				table.insert(order, mapped)
			end
		end
		ns.db.tabOrder = ns.db.tabOrder or {}
		local current = ns.db.tabOrder[CharacterKey()] or {}
		for _, id in ipairs(current) do
			if not tContains(order, id) then
				table.insert(order, id)
			end
		end
		ns.db.tabOrder[CharacterKey()] = order
	end
	FCF_DockUpdate()
	return added, missing
end

-- The character's name for the list: "Name - Realm" without the realm when
-- it's this one's (Forever has one realm per region).
local function DisplayName(key)
	local name, realm = key:match("^(.-)%-(.+)$")
	if realm == GetRealmName() then
		return name
	end
	return name and (name .. " - " .. realm) or key
end

local function OthersSorted()
	local keys = {}
	for key in pairs(GetSetups()) do
		if key ~= CharacterKey() then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return (GetSetups()[a].savedAt or 0) > (GetSetups()[b].savedAt or 0)
	end)
	return keys
end

-- In Everchat's window look, like the options window (Options.CreateWindow),
-- above the options, where it's opened from.
local function CreateDialog()
	dialog = ns.Options.CreateWindow(WIDTH, L.tabCopyTitle, "FULLSCREEN_DIALOG")
	dialog:SetPoint("TOP", UIParent, "TOP", 0, -UIParent:GetHeight() / 4)

	local note = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", dialog, "TOPLEFT", PADDING, -(dialog.titleHeight + PADDING))
	note:SetPoint("RIGHT", -PADDING, 0)
	note:SetJustifyH("LEFT")
	dialog.note = note

	-- Silent: the window sounds as it closes.
	local close = ns.Options.CreateTextButton(dialog, L.linkClose, function()
		dialog:Hide()
	end, false, true)
	close:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
	dialog.closeButton = close
	dialog.rows = {}
end

local function Row(index)
	local row = dialog.rows[index]
	if not row then
		row = CreateFrame("Button", nil, dialog)
		row:SetHeight(ROW_HEIGHT)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		local label = row:CreateFontString(nil, "ARTWORK")
		label:SetPoint("LEFT", 4, 0)
		label:SetPoint("RIGHT", -4, 0)
		label:SetJustifyH("LEFT")
		row:SetFontString(label)
		row:SetNormalFontObject(GameFontHighlightLeft)
		row:SetHighlightFontObject(GameFontNormalLeft)
		dialog.rows[index] = row
	end
	return row
end

local function Refresh()
	local keys = OthersSorted()
	local previous = dialog.note
	for index, key in ipairs(keys) do
		local setup = GetSetups()[key]
		local row = Row(index)
		row:SetText(L.tabCopyRow:format(DisplayName(key), #setup.windows))
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", previous == dialog.note and -4 or 0, previous == dialog.note and -8 or 0)
		row:SetPoint("RIGHT", dialog, "RIGHT", -PADDING + 4, 0)
		row:SetScript("OnClick", function()
			if InCombatLockdown() then
				ns.Print(L.tabCopyCombat)
				return
			end
			local added, missing = Copy(key)
			if added == 0 and missing == 0 then
				ns.Print(L.tabCopyNothing)
			else
				ns.Print(L.tabCopyDone:format(added, DisplayName(key)))
				if missing > 0 then
					ns.Print(L.tabCopyFull:format(missing))
				end
			end
			dialog:Hide()
		end)
		row:Show()
		previous = row
	end
	for index = #keys + 1, #dialog.rows do
		dialog.rows[index]:Hide()
	end
	dialog.note:SetText(#keys > 0 and L.tabCopyNote or L.tabCopyEmpty)
	dialog.note:SetTextColor((#keys > 0 and Theme.GAME.TAB_TEXT or Theme.TIME):GetRGB())
	-- Summed up: positions aren't resolved yet while it's being built.
	dialog:SetHeight(dialog.titleHeight + PADDING + dialog.note:GetStringHeight()
		+ (#keys > 0 and (8 + #keys * ROW_HEIGHT) or 0) + 14 + dialog.closeButton:GetHeight() + PADDING)
end

-- The options' button.
function TabCopy.Open()
	if not dialog then
		CreateDialog()
	end
	Snapshot()
	Refresh()
	dialog:Show()
end

function TabCopy.Init()
	-- Saved on the way out (a reload too) and once the chat is set up, so a
	-- character that never logged out cleanly is still listed.
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_LOGOUT")
	local function applyProfile()
		if InCombatLockdown() then
			events:RegisterEvent("PLAYER_REGEN_ENABLED")
			return
		end
		events:UnregisterEvent("PLAYER_REGEN_ENABLED")
		if ns.db.applyProfileTabs then
			ns.db.applyProfileTabs = nil
			Copy(nil, true)
			ns.Header.SetCombatLogHidden(true)
		end
		Snapshot()
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGOUT" then
			if not ns.db.applyProfileTabs then Snapshot() end
		else applyProfile() end
	end)
	C_Timer.After(0.5, applyProfile)
end
