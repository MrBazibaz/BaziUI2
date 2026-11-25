local ns = BaziUI.Chat

-- Everchat's text, resolved for this client's language: Locales/enUS.lua is
-- the source and the fallback (anything a language doesn't translate shows
-- in English, so a partial translation never breaks the addon); the other
-- files in Locales/ each load only for their locale. Languages Everchat
-- doesn't translate borrow the game's own words for the tab names.
local GAME_WORDS = { newTabTitle = "NEW_CHAT_WINDOW", newTabGuild = "GUILD", newTabGroup = "PARTY", newTabWhispers = "WHISPER", newTabLoot = "LOOT" }

local translation = ns.Locales[GetLocale()]
if not translation then
	translation = {}
	for key, global in pairs(GAME_WORDS) do
		translation[key] = _G[global]
	end
end

ns.L = setmetatable(translation, { __index = ns.Locales.enUS })
