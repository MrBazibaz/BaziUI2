-- Derived from Lueur 2.0.0 by Armytille (MIT). See LICENSE.txt.
local ns = BaziUI.Gathering.vendor
local function ClientLocale() return GetLocale() end
local COMMON_WORDS = {
	enUS = "small little large great giant ancient",
	frFR = "petit petite grand grande vieux vieille ancien ancienne",
	deDE = "klein kleine kleiner kleines kleinen groß große großer großes großen alte alter altes alten uralt uralte uralter",
	esES = "pequeño pequeña pequeños pequeñas grande grandes viejo vieja viejos viejas antiguo antigua antiguos antiguas",
	ptBR = "pequeno pequena pequenos pequenas grande grandes velho velha velhos velhas antigo antiga antigos antigas",
	itIT = "piccolo piccola piccoli piccole grande grandi vecchio vecchia vecchi vecchie antico antica antichi antiche",
	ruRU = "маленький маленькая маленькое маленькие большой большая большое большие старый старая старое старые древний древняя древнее древние",
}

function ns.CommonWords()
	return COMMON_WORDS[ClientLocale()] or COMMON_WORDS.enUS
end

-- Ce qu'un coffre s'appelle. Le jeu lui donne le curseur de n'importe quel objet (une roue
-- dentée, comme à un levier) : c'est son nom qui le range parmi les coffres, quand un de ses mots
-- commence ou finit par l'un de ceux-ci (« Coffre endommagé », « Schatztruhe »). Par langue de
-- client, pour la même raison que les adjectifs. Le français est recoupé avec le cache du client
-- (« Coffre endommagé », objet 106318) ; les autres langues ne le sont avec rien.
local CHEST_WORDS = {
	enUS = "chest footlocker strongbox lockbox coffer",
	frFR = "coffre cantine malle",
	deDE = "truhe schließkassette geldkassette",
	esES = "cofre arcón baúl",
	ptBR = "baú cofre arca",
	itIT = "forziere scrigno baule",
	ruRU = "сундук ларец",
	koKR = "상자 궤짝",
	zhCN = "箱子 宝箱",
	zhTW = "箱子 寶箱",
}

function ns.ChestWords()
	return CHEST_WORDS[ClientLocale()] or CHEST_WORDS.enUS
end

local ACCENTS = {
	["à"] = "a", ["â"] = "a", ["ä"] = "a", ["á"] = "a", ["ç"] = "c", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
	["î"] = "i", ["ï"] = "i", ["í"] = "i", ["ô"] = "o", ["ö"] = "o", ["ó"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
	["ú"] = "u", ["ñ"] = "n", ["ß"] = "ss", ["À"] = "a", ["Â"] = "a", ["Ä"] = "a", ["Á"] = "a", ["Ç"] = "c", ["É"] = "e",
	["È"] = "e", ["Ê"] = "e", ["Î"] = "i", ["Í"] = "i", ["Ô"] = "o", ["Ö"] = "o", ["Ó"] = "o", ["Ù"] = "u", ["Û"] = "u",
	["Ü"] = "u", ["Ú"] = "u", ["Ñ"] = "n",
}
-- cyrillique : А-П (208 144-159) donnent а-п (208 176-191), Р-Я (208 160-175) donnent р-я
-- (209 128-143) ; Ё et ё s'écrivent е, comme le font souvent les textes du jeu
for byte = 144, 175 do
	ACCENTS["\208" .. string.char(byte)] = byte < 160 and "\208" .. string.char(byte + 32) or "\209" .. string.char(byte - 32)
end
ACCENTS["\208\129"], ACCENTS["\209\145"] = "\208\181", "\208\181"

local function Fold(text)
	return (text:gsub("[\195-\197\208\209][\128-\191]", ACCENTS):lower())
end

ns.Fold = Fold
