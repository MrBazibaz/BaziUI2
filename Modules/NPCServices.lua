-- Bazi UI standalone NPC service registry.
-- NPC IDs come from UnitGUID; never infer a service from an NPC name.
-- Entries are intentionally empty until verified Forever NPC-ID data is imported.
-- Format: [npcID] = { vendor = true, repair = true, flight = true,
--                     trainer = true, inn = true, bank = true }
-- This file is independent of Questie and other addons.
BaziUI.NPCServices = BaziUI.NPCServices or {}
BaziUI.NPCServices.byID = BaziUI.NPCServices.byID or {}
-- Small, independently verifiable pilot set (NPC IDs / service flags).
-- Reference: NpcIcons v1.0.2 Forever, NpcData.lua (QuestieDB-derived).
-- Do not bulk-copy GPL-3.0 datasets into BaziUI without a license decision.
BaziUI.NPCServices.byID[843] = { vendor = true } -- Gina MacGregor
BaziUI.NPCServices.byID[1668] = { vendor = true, repair = true } -- William MacGregor
BaziUI.NPCServices.byID[1670] = { vendor = true } -- Mike Miller

function BaziUI.NPCServices:Get(unit)
    if not UnitGUID then return nil end
    local guid = UnitGUID(unit)
    if type(guid) ~= "string" then return nil end
    if issecretvalue and issecretvalue(guid) then return nil end
    local npcID = guid:match("^Creature%-[^%-]*%-[^%-]*%-[^%-]*%-[^%-]*%-(%d+)%-")
        or guid:match("^Vehicle%-[^%-]*%-[^%-]*%-[^%-]*%-[^%-]*%-(%d+)%-")
    if not npcID then return nil end
    return self.byID[tonumber(npcID)]
end
