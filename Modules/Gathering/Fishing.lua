local gathering = BaziUI.Gathering
local safe = gathering.vendor.SafeCall
local fishing = {binding = "CLICK BaziUIFishingCast:LeftButton"}
gathering.Fishing = fishing

local castIDs = {7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410, 131474}
local fishingSpells = {[131476] = true, [131490] = true}
for _, id in ipairs(castIDs) do fishingSpells[id] = true end

local function knownSpell()
    local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    for index = #castIDs, 1, -1 do
        local id = castIDs[index]
        if safe(known, id) == true then return id end
    end
end

local function poleEquipped()
    local item = safe(GetInventoryItemID, "player", 16)
    local itemInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not item or not itemInfo then return false end
    local ok, _, _, _, _, _, class, subclass = pcall(itemInfo, item)
    local pole = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
    return ok and class == 2 and subclass == pole
end

local function channelingFish()
    local ok, _, _, _, _, _, _, _, spell = pcall(UnitChannelInfo, "player")
    return ok and not gathering.vendor.IsSecret(spell) and fishingSpells[spell] == true
end

local function settings()
    return gathering:Settings().fishing
end

local function enabled()
    local cfg = settings()
    local standalone = C_AddOns and C_AddOns.IsAddOnLoaded("BetterFishing")
    return cfg.enabled and not standalone
end

local temporary, castButton, bindingOwner = {}, nil, nil
local channel, pending = false, false

local function setTemporary(name, value)
    local current = C_CVar and safe(C_CVar.GetCVar, name)
    if current == nil or current == value then return end
    local record = temporary[name]
    if not record then record = {original = current}; temporary[name] = record end
    safe(C_CVar.SetCVar, name, value)
    record.applied = safe(C_CVar.GetCVar, name)
end

function fishing:RestoreCVars()
    gathering.fishingInteraction = nil
    for name, value in pairs(temporary) do
        if safe(C_CVar.GetCVar, name) == value.applied then
            safe(C_CVar.SetCVar, name, value.original)
        end
        temporary[name] = nil
    end
end

local function applySession(cfg)
    gathering.fishingInteraction = true
    setTemporary("SoftTargetInteract", "3")
    setTemporary("SoftTargetInteractArc", "2")
    setTemporary("SoftTargetInteractRange", "60")
    setTemporary("SoftTargetNameplateInteract", "1")
    setTemporary("nameplateGameObjectMaxDistance", "60")
    local bobberEffect = gathering:Settings().categories.bobber.enabled
    local icon = cfg.hideBobberIcon and not bobberEffect and "0" or "1"
    setTemporary("SoftTargetIconInteract", icon)
    setTemporary("SoftTargetIconGameObject", icon)
    if cfg.quietNames then
        for _, name in ipairs({"nameplateShowFriendlyPlayers", "UnitNameNPC", "UnitNameNonCombatCreatureName",
            "UnitNameInteractiveNPC", "UnitNameFriendlySpecialNPCName"}) do
            setTemporary(name, "0")
        end
    end
    if cfg.focusAudio then
        for _, name in ipairs({"Sound_EnableAmbience", "Sound_MusicVolume", "Sound_EnablePetSounds"}) do
            setTemporary(name, "0")
        end
        for _, name in ipairs({"Sound_EnableAllSound", "Sound_EnableSFX", "Sound_EnableSoundWhenGameIsInBG"}) do
            setTemporary(name, "1")
        end
        local volume = tostring(cfg.volume / 100)
        setTemporary("Sound_SFXVolume", volume)
        setTemporary("Sound_MasterVolume", volume)
    end
end

local function createButtons()
    castButton = CreateFrame("Button", "BaziUIFishingCast", UIParent, "SecureActionButtonTemplate")
    castButton:RegisterForClicks("AnyUp", "AnyDown")
    bindingOwner = CreateFrame("Frame", nil, UIParent)
end

function fishing:Apply()
    if InCombatLockdown() then pending = true; return end
    pending = false
    if not castButton then createButtons() end
    local cfg = settings()
    local active = enabled()
    local fishingNow = active and (channel or channelingFish())
    local spell = active and knownSpell()
    castButton:SetAttribute("type", spell and poleEquipped() and "spell" or nil)
    castButton:SetAttribute("spell", spell or nil)
    castButton:SetAttribute("useOnKeyDown", GetCVarBool("ActionButtonUseKeyDown"))
    ClearOverrideBindings(bindingOwner)

    local wasFishing = gathering.fishingInteraction
    self:RestoreCVars()
    if fishingNow then
        applySession(cfg)
        local first, second = GetBindingKey(self.binding)
        if first then SetOverrideBinding(bindingOwner, true, first, "INTERACTTARGET") end
        if second then SetOverrideBinding(bindingOwner, true, second, "INTERACTTARGET") end
        gathering:Apply()
    elseif wasFishing then
        gathering:Apply()
    end
end

local driver = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "UPDATE_BINDINGS",
    "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED",
    "LOOT_READY", "CVAR_UPDATE", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP"}) do
    pcall(driver.RegisterEvent, driver, event)
end
driver:SetScript("OnEvent", function(_, event, arg1, _, spell)
    if event == "PLAYER_LOGOUT" then
        fishing:RestoreCVars()
    elseif event == "PLAYER_ENTERING_WORLD" then
        channel = channelingFish()
        fishing:Apply()
    elseif event == "LOOT_READY" then
        if enabled() and settings().autoLoot and safe(IsFishingLoot) == true then
            for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if arg1 == "player" and not gathering.vendor.IsSecret(spell) and fishingSpells[spell] then
            channel = event == "UNIT_SPELLCAST_CHANNEL_START"
            if channel then fishing:Apply()
            else C_Timer.After(0, function() fishing:Apply() end) end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then fishing:Apply() end
    elseif event ~= "CVAR_UPDATE" or (type(arg1) == "string" and arg1:lower() == "actionbuttonusekeydown") then
        fishing:Apply()
    end
end)
