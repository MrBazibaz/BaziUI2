-- BaziQoL sound features, integrated into Bazi UI.
-- The old addon used the Error Speech CVar plus five fizzle sound IDs.
local addon = BaziUI
addon.QoLSounds = addon.QoLSounds or {}
local module = addon.QoLSounds
local fizzleIDs = {569772, 569773, 569774, 569775, 569776}
local previousSpeech
local mutedByUs = false
local function settings()
    return addon.db and addon.db.profile and addon.db.profile.qol
end
local filteredMessages = {}
local combatErrorGlobals = {
    "ERR_OUT_OF_RANGE", "SPELL_FAILED_OUT_OF_RANGE", "ERR_TOO_FAR_TO_ATTACK",
    "ERR_BADATTACKFACING", "SPELL_FAILED_UNIT_NOT_INFRONT", "SPELL_FAILED_NOT_BEHIND",
    "SPELL_FAILED_NOT_READY", "SPELL_FAILED_MOVING", "SPELL_FAILED_SPELL_IN_PROGRESS",
    "ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN", "ERR_NO_ATTACK_TARGET", "SPELL_FAILED_NO_TARGET",
    "ERR_OUT_OF_MANA", "ERR_OUT_OF_RAGE", "ERR_OUT_OF_ENERGY", "ERR_OUT_OF_FOCUS",
    "ERR_OUT_OF_RUNES", "ERR_OUT_OF_RUNIC_POWER", "SPELL_FAILED_NO_POWER",
}
local englishPhrases = {
    "out of range", "too far away", "facing the wrong way", "must be in front",
    "not ready yet", "spell is not ready", "ability is not ready", "another action is in progress",
    "can't do that while moving", "cannot do that while moving", "you can't do that yet",
    "you have no target", "must be closer", "too far from target", "not enough mana",
    "not enough rage", "not enough energy", "not enough focus", "not enough runic power",
    "not enough runes",
}

local filterInstalled
local function installTextFilter()
    local frame = UIErrorsFrame
    if filterInstalled or not frame or type(frame.AddMessage) ~= "function" then return end
    for _, key in ipairs(combatErrorGlobals) do
        local message = _G[key]
        if type(message) == "string" and message ~= "" then filteredMessages[message:lower()] = true end
    end
    local original = frame.AddMessage
    frame.AddMessage = function(self, message, ...)
        local cfg = settings()
        if cfg and cfg.hideCombatErrors and (not issecretvalue or not issecretvalue(message))
            and (not canaccessvalue or canaccessvalue(message)) and type(message) == "string" then
            local key = message:lower()
            if filteredMessages[key] then return end
            for _, phrase in ipairs(englishPhrases) do
                if key:find(phrase, 1, true) then return end
            end
        end
        return original(self, message, ...)
    end
    filterInstalled = true
end

function module:Apply()
    local cfg = settings()
    if not cfg then return end
    if cfg.hideCombatErrors then installTextFilter() end
    if GetCVar and SetCVar then
        if cfg.muteErrorSpeech then
            if previousSpeech == nil then
                previousSpeech = GetCVar("Sound_EnableErrorSpeech")
            end
            SetCVar("Sound_EnableErrorSpeech", "0")
        elseif previousSpeech ~= nil then
            SetCVar("Sound_EnableErrorSpeech", previousSpeech)
            previousSpeech = nil
        end
    end
    if cfg.muteFailedSpellSounds and not mutedByUs then
        if MuteSoundFile then
            for _, id in ipairs(fizzleIDs) do MuteSoundFile(id) end
            mutedByUs = true
        end
    elseif not cfg.muteFailedSpellSounds and mutedByUs then
        if UnmuteSoundFile then
            for _, id in ipairs(fizzleIDs) do UnmuteSoundFile(id) end
            mutedByUs = false
        end
    end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    module:Apply()
end)
