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
function module:Apply()
    local cfg = settings()
    if not cfg then return end
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
