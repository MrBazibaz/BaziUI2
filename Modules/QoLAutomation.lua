local addon = BaziUI
local qol = {}
addon.QoLAutomation = qol

qol.options = {
    {"autoQuest", "Automate quest pickup and turn-in"},
    {"acceptSharedQuests", "Accept shared quests"},
    {"acceptSummon", "Accept summon"},
    {"acceptResurrection", "Accept resurrection"},
    {"releasePvP", "Release in PvP"},
    {"sellJunk", "Sell junk automatically"},
    {"repair", "Repair automatically"},
    {"trainAll", "Show Train All button"},
    {"easyDestroy", "Fill in item deletion confirmation"},
}

local function enabled(key)
    local db = addon.db and addon.db.profile.qol
    return db and db[key]
end

local function automaticQuest(event, questID)
    if IsShiftKeyDown() or InCombatLockdown() then return end
    local automatic, shared = enabled("autoQuest"), enabled("acceptSharedQuests")
    if event == "QUEST_ACCEPT_CONFIRM" then
        if shared then
            ConfirmAcceptQuest()
            StaticPopup_Hide("QUEST_ACCEPT")
        end
    elseif event == "QUEST_DETAIL" then
        local fromPlayer = UnitIsPlayer("questnpc")
        local questGiver = UnitName("questnpc")
        if not fromPlayer and questGiver and (not canaccessvalue or canaccessvalue(questGiver)) then
            fromPlayer = UnitIsPlayer(questGiver) and (UnitInParty(questGiver) or UnitInRaid(questGiver))
        end
        if (fromPlayer and shared) or (not fromPlayer and automatic) then
            if QuestGetAutoAccept and QuestGetAutoAccept() then CloseQuest() else AcceptQuest() end
        end
    elseif automatic then
        if event == "QUEST_AUTOCOMPLETE" then
            local log = C_QuestLog
            local index = log.GetLogIndexForQuestID(questID)
            local info = index and log.GetInfo(index)
            if info and info.isAutoComplete then
                log.SetSelectedQuest(questID)
                ShowQuestComplete(questID)
            end
        elseif event == "GOSSIP_SHOW" then
            for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
                if quest.isComplete then C_GossipInfo.SelectActiveQuest(quest.questID); return end
            end
            for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
                if quest.questID then C_GossipInfo.SelectAvailableQuest(quest.questID); return end
            end
        elseif event == "QUEST_GREETING" then
            if not (GetNumActiveQuests and GetNumAvailableQuests) then return end
            for index = 1, GetNumActiveQuests() do
                local _, complete = GetActiveTitle(index)
                if complete then SelectActiveQuest(index); return end
            end
            if GetNumAvailableQuests() > 0 then SelectAvailableQuest(1) end
        elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
            if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return end
            for index = 1, 6 do
                local requirement = _G["QuestProgressItem" .. index]
                if requirement and requirement:IsShown() and requirement.objectType == "currency" then return end
            end
            if event == "QUEST_PROGRESS" and IsQuestCompletable() then
                CompleteQuest()
            elseif event == "QUEST_COMPLETE" and GetNumQuestChoices() <= 1 then
                GetQuestReward(GetNumQuestChoices())
            end
        end
    end
end

local merchantSession = 0
local function vendor()
    merchantSession = merchantSession + 1
    if IsShiftKeyDown() then return end
    if enabled("repair") and CanMerchantRepair and CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost > 0 and cost <= GetMoney() then RepairAllItems() end
    end
    if not enabled("sellJunk") or not C_Container then return end

    local container = C_Container
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    local slots = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, container.GetContainerNumSlots(bag) do
            local info = container.GetContainerItemInfo(bag, slot)
            if info and info.quality == 0 and not info.hasNoValue then
                slots[#slots + 1] = {bag, slot, info.itemID}
            end
        end
    end
    local session, index = merchantSession, 0
    local function sellNext()
        if session ~= merchantSession or not enabled("sellJunk") or not MerchantFrame
            or not MerchantFrame:IsShown() or CursorHasItem() then return end
        index = index + 1
        local candidate = slots[index]
        if not candidate then return end
        local bag, slot, id = unpack(candidate)
        local info = container.GetContainerItemInfo(bag, slot)
        local profile = addon.db.profile.inventory
        local ignored = profile and profile.ignored and profile.ignored[id]
        if info and info.itemID == id and info.quality == 0 and not info.isLocked and not ignored then
            local price = getInfo and select(11, getInfo(info.hyperlink or id))
            if price and price > 0 then container.UseContainerItem(bag, slot) end
        end
        if index < #slots then C_Timer.After(0.12, sellNext) end
    end
    if #slots > 0 then C_Timer.After(0, sellNext) end
end

local summonTicket = 0
local function summon()
    if not enabled("acceptSummon") or UnitAffectingCombat("player") then return end
    local name = C_SummonInfo.GetSummonConfirmSummoner()
    if not name or name == "" then return end
    local location = C_SummonInfo.GetSummonConfirmAreaName()
    summonTicket = summonTicket + 1
    local ticket = summonTicket
    print("Bazi UI: Summon will be accepted in 10 seconds. Decline it to cancel.")
    C_Timer.After(10, function()
        if ticket == summonTicket and enabled("acceptSummon") and not UnitAffectingCombat("player")
            and StaticPopup_Visible("CONFIRM_SUMMON")
            and name == C_SummonInfo.GetSummonConfirmSummoner()
            and location == C_SummonInfo.GetSummonConfirmAreaName() then
            C_SummonInfo.ConfirmSummon()
            StaticPopup_Hide("CONFIRM_SUMMON")
        end
    end)
end

local function release()
    if not enabled("releasePvP") or not UnitIsDead("player") or IsShiftKeyDown() then return end
    local _, instance = IsInInstance()
    if instance ~= "pvp" then return end
    local options = C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions and C_DeathInfo.GetSelfResurrectOptions()
    if options and #options > 0 then return end
    RepopMe()
end

local deleteDialogs = {DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true}
local function fillDelete()
    if not enabled("easyDestroy") then return end
    for index = 1, STATICPOPUP_NUMDIALOGS or 4 do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() and deleteDialogs[popup.which] then
            local edit = popup.EditBox or popup.editBox or _G["StaticPopup" .. index .. "EditBox"]
            if edit and edit:IsShown() then
                edit:SetText(DELETE_ITEM_CONFIRM_STRING or "DELETE")
            end
        end
    end
end

local trainAll
local function trainer()
    if not ClassTrainerFrame or not ClassTrainerTrainButton or not GetNumTrainerServices then return end
    if not trainAll then
        trainAll = addon.Theme:CreateButton(ClassTrainerFrame, "Train All", 80, 22)
        trainAll:SetPoint("RIGHT", ClassTrainerTrainButton, "LEFT", -5, 0)
        trainAll:SetScript("OnClick", function()
            local money = GetMoney()
            for index = GetNumTrainerServices(), 1, -1 do
                local _, status = GetTrainerServiceInfo(index)
                local cost = GetTrainerServiceCost(index) or 0
                if status == "available" and cost <= money then
                    BuyTrainerService(index)
                    money = money - cost
                end
            end
        end)
    end
    local available = false
    for index = 1, GetNumTrainerServices() do
        local _, status = GetTrainerServiceInfo(index)
        if status == "available" and (GetTrainerServiceCost(index) or 0) <= GetMoney() then available = true; break end
    end
    trainAll:SetEnabled(available)
    local points = ClassTrainerFrame.trainingPoints
    trainAll:SetShown(not not enabled("trainAll") and not (points and points:IsShown()))
end
qol.RefreshTrainer = trainer

local handlers = {
    MERCHANT_SHOW = vendor,
    MERCHANT_CLOSED = function() merchantSession = merchantSession + 1 end,
    CONFIRM_SUMMON = summon,
    RESURRECT_REQUEST = function()
        if enabled("acceptResurrection") then
            AcceptResurrect()
            StaticPopup_Hide("RESURRECT")
            StaticPopup_Hide("RESURRECT_NO_TIMER")
            StaticPopup_Hide("RESURRECT_NO_SICKNESS")
        end
    end,
    PLAYER_DEAD = function() C_Timer.After(0, release) end,
    DELETE_ITEM_CONFIRM = function() if enabled("easyDestroy") then C_Timer.After(0, fillDelete) end end,
    TRAINER_SHOW = function() C_Timer.After(0, trainer) end,
    TRAINER_UPDATE = trainer,
}
local events = CreateFrame("Frame")
for event in pairs(handlers) do events:RegisterEvent(event) end
for _, event in ipairs({"GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "QUEST_ACCEPT_CONFIRM", "QUEST_AUTOCOMPLETE"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then handler(...) else automaticQuest(event, ...) end
end)

