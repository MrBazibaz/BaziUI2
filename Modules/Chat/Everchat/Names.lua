local ns = BaziUI.Chat

local Names = {}
ns.Names = Names

-- Whatever another player links comes with its name in that player's
-- language: the link's text is theirs, its data is what the game reads. The
-- name is put in this client's language from the data, as the link's tooltip
-- already is ("[SE BUSCA: Gath'Ilzogg]" for an English "[WANTED:
-- Gath'Ilzogg]"): quests, items, spells, recipes, a profession's window,
-- achievements and currencies. A name the client hasn't loaded is asked for
-- (the game's own load, answered by an event) and the line is composed again
-- when it arrives. The link's data stays as sent, so clicks and tooltips
-- keep working; Copy chat copies the line as written.

-- A link's ID, the number its data starts with.
local function Id(data)
	return tonumber(data:match("^(%d+)"))
end

local function LoadSpell(id)
	if C_Spell.RequestLoadSpellData then
		C_Spell.RequestLoadSpellData(id)
	end
end

-- A profession's window: "trade:<player>:<spell>:<skill line>", named after the
-- profession. Its spell and its skill line are named alike ("Enchanting"),
-- which tells the fields apart; a link laid out otherwise is left as sent.
local function ProfessionName(data)
	local spellID, skillLineID = data:match(":(%d+):(%d+)$")
	spellID, skillLineID = tonumber(spellID), tonumber(skillLineID)
	if not (spellID and skillLineID and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName) then
		return nil
	end
	local name = C_TradeSkillUI.GetTradeSkillDisplayName(skillLineID)
	if name and name ~= "" and name == C_Spell.GetSpellName(spellID) then
		return name
	end
	return nil
end

local KINDS = {
	quest = {
		Name = function(data)
			local id = Id(data)
			return id and C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
		end,
		Load = function(id)
			if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
				C_QuestLog.RequestLoadQuestByID(id)
			end
		end,
		event = "QUEST_DATA_LOAD_RESULT",
	},
	item = {
		-- The whole link data: a random suffix ("of the Bear") is part of the
		-- name. GetItemInfo asks the server for an item it doesn't know.
		Name = function(data)
			return C_Item.GetItemInfo("item:" .. data)
		end,
		event = "GET_ITEM_INFO_RECEIVED",
	},
	spell = {
		Name = function(data)
			local id = Id(data)
			return id and C_Spell.GetSpellName(id)
		end,
		Load = LoadSpell,
		event = "SPELL_DATA_LOAD_RESULT",
	},
	-- A recipe: the client's own link for it holds its name with the
	-- profession's ("Enchanting: Enchant Chest - Minor Stats").
	enchant = {
		Name = function(data)
			local id = Id(data)
			local link = id and C_Spell.GetSpellTradeSkillLink and C_Spell.GetSpellTradeSkillLink(id)
			return link and link:match("|h%[(.-)%]|h")
		end,
		Load = LoadSpell,
		event = "SPELL_DATA_LOAD_RESULT",
	},
	trade = {
		Name = ProfessionName,
	},
	achievement = {
		Name = function(data)
			local id = Id(data)
			return id and GetAchievementInfo and select(2, GetAchievementInfo(id))
		end,
	},
	currency = {
		Name = function(data)
			local id = Id(data)
			local info = id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
			return info and info.name
		end,
	},
}

-- The lines waiting for a name, by the event that answers and the ID (weak:
-- a line gone from its window's history is forgotten), and the IDs asked for
-- already, answered or not: each is asked for once a session.
local waiting, asked = {}, {}
-- Entries that aren't chat lines (the whisper notice's messages) and what
-- writes them again.
local refreshers = setmetatable({}, { __mode = "k" })

local function Wait(spec, id, entry)
	local event = spec.event
	waiting[event] = waiting[event] or {}
	asked[event] = asked[event] or {}
	local set = waiting[event][id]
	if not set then
		if asked[event][id] then
			return
		end
		asked[event][id] = true
		set = setmetatable({}, { __mode = "k" })
		waiting[event][id] = set
		if spec.Load then
			spec.Load(id)
		end
	end
	set[entry] = true
end

-- The links' names in this client's language, where the game knows them;
-- `entry` is the line's history entry, composed again when a name arrives;
-- or anything else, with `refresh` to write it again.
function Names.Localize(text, entry, refresh)
	if ns.db.localNames == false or not text:find("|H", 1, true) then
		return text
	end
	return (text:gsub("(|H(%a+):([^|]*)|h%[)([^%]]*)(%]|h)", function(head, kind, data, _, tail)
		local spec = KINDS[kind]
		if not spec then
			return nil
		end
		local name = spec.Name(data)
		if type(name) == "string" and name ~= "" then
			return head .. name .. tail
		end
		local id = Id(data)
		if entry and spec.event and id then
			if refresh then
				refreshers[entry] = refresh
			end
			Wait(spec, id, entry)
		end
		return nil
	end))
end

function Names.AddIcons(text)
	if not ns.db.linkIcons then return text end
	return (text:gsub("(|H(%a+):(%d+)[^|]*|h[^|]*|h)", function(link, kind, id)
		local texture
		if kind == "item" and C_Item and C_Item.GetItemIconByID then
			texture = C_Item.GetItemIconByID(tonumber(id))
		elseif (kind == "spell" or kind == "trade" or kind == "enchant") and C_Spell and C_Spell.GetSpellTexture then
			texture = C_Spell.GetSpellTexture(tonumber(id))
		elseif kind == "quest" then
			texture = "Interface\\Icons\\INV_Misc_Note_01"
		end
		if texture then return "|T" .. texture .. ":14:14|t " .. link end
	end))
end

function Names.Init()
	local frame = CreateFrame("Frame")
	for _, spec in pairs(KINDS) do
		if spec.event then
			frame:RegisterEvent(spec.event)
		end
	end
	frame:SetScript("OnEvent", function(_, event, id, success)
		local set = waiting[event] and waiting[event][id]
		if not set then
			return
		end
		waiting[event][id] = nil
		if success == false then
			return
		end
		for entry in pairs(set) do
			local refresh = refreshers[entry]
			if refresh then
				refresh(entry)
			else
				ns.Lines.RefreshEntry(entry)
			end
		end
	end)
end
