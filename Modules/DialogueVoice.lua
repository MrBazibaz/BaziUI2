local addon = BaziUI
local dialogue = addon.Dialogue
local voice = {queue = {}}
dialogue.Voice = voice

local function spoken()
    return _G.Spoken
end

local function matches(page, clip)
    if not clip or not clip.source then return end
    if page.standalone then return clip == page.clip end
    if clip.source.key ~= "quests" and clip.source.key ~= "gossip" then return end
    if page.questID > 0 then return tonumber(clip.questID) == page.questID end
    return page.guid and page.guid == clip.unitGUID
end

local function paragraph(page)
    if page.paragraph then return page.paragraph end
    local api = spoken()
    if not (api and api.SplitCaption and api.WordMarks) then return end
    local marks = api:WordMarks()
    local words = api:SplitCaption(page.text)
    if not marks or not words then return end
    page.paragraph = {{text = page.text, words = marks.MarkLinks(page.text, words)}}
    return page.paragraph
end

function voice.Highlight(page, caption)
    if not (caption and caption.speaking and caption.activeWord and matches(page, caption.clip)) then return page.text end
    local paragraphs = paragraph(page)
    if not paragraphs then return page.text end
    local marks = spoken():WordMarks()
    if page.captionWords ~= caption.words then
        page.captionWords = caption.words
        page.captionMap = marks.Align(caption.words, paragraphs)
    end
    local map = page.captionMap
    if not map then return page.text end
    local first, nextWord = marks.Pick(map, caption.activeWord)
    if not first then return page.text end
    local spans = marks.Spans(map, paragraphs, first, nextWord)
    local color = addon.QuestTracker.Settings().accent
    local hex = string.format("|cff%02x%02x%02x", math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
    return marks.Want(paragraphs[1], 1, nil, nil, nil, spans, hex), paragraphs[1].words[map[first].w].first
end

local function track(page, clip)
    if not matches(page, clip) then return end
    local paragraphs = paragraph(page)
    local api = spoken()
    local speech = clip.present and clip.present.transcript or clip.text
    if paragraphs and api.CaptionWords and type(speech) == "string" and speech ~= "" then
        if page.matchedClip ~= clip then
            local words = api:CaptionWords(speech)
            page.matchedClip, page.matched = clip, words and api:WordMarks().Align(words, paragraphs)
        end
        if not page.matched then return end
    end
    page.clip = clip
    return true
end

local finished = setmetatable({}, {__mode = "k"})
local registered
function voice.Update(page)
    local api = spoken()
    if not api then return page.text end
    if not registered and api.RegisterCallback then
        registered = api:RegisterCallback("CLIP_STOPPED", function(clip, complete)
            if complete then finished[clip] = true end
        end)
    end
    local caption = api.GetCaption and api:GetCaption()
    if not (caption and not finished[caption.clip] and track(page, caption.clip)) and api.GetQueue then
        for _, clip in ipairs(api:GetQueue()) do
            if not finished[clip] and track(page, clip) then break end
        end
    end
    if caption and page.clip == caption.clip then return voice.Highlight(page, caption) end
    return page.text
end

function voice.Remember(page)
    if not spoken() or page.text == "" then return end
    voice.Update(page)
    if page.clip and finished[page.clip] then return end
    page.waitUntil = GetTime() + 2
    for index, entry in ipairs(voice.queue) do
        if page.key == entry.key then table.remove(voice.queue, index); break end
    end
    table.insert(voice.queue, 1, page)
    if #voice.queue > 12 then table.remove(voice.queue) end
end

function voice.Play(page, live)
    local api = spoken()
    if not api or not page then return end
    local clip = page.clip
    if clip and api.GetNowPlaying and api:GetNowPlaying() == clip then
        api:Pause()
    elseif clip and api.GetCurrent and api:GetCurrent() == clip and api:IsPaused() then
        api:Resume()
    elseif live then
        local ace = _G.LibStub and LibStub("AceAddon-3.0", true)
        local quests = ace and ace:GetAddon("SpokenQuests", true)
        if quests and quests.ReadVisibleQuest then quests:ReadVisibleQuest("Bazi UI dialogue") end
    elseif clip and clip.source and clip.source.PlayNow then
        -- Only presentation and audio data are replayed. The original event callbacks own the NPC interaction.
        local replay = {}
        for _, field in ipairs({"key", "path", "length", "textOnly", "priority", "present", "text", "questID", "unitGUID"}) do
            replay[field] = clip[field]
        end
        clip.source:PlayNow(replay)
    end
end

function voice.IsPlaying(page)
    local api = spoken()
    return api and page and page.clip and api.GetNowPlaying and api:GetNowPlaying() == page.clip
end

function voice.IsCurrent(page)
    local api = spoken()
    return api and page and page.clip and api.GetCurrent and api:GetCurrent() == page.clip
end

function voice.HasNPCHead()
    local api = spoken()
    local head = api and api.GetCurrent and api:GetCurrent()
    local source = head and head.source and head.source.key
    return source == "quests" or source == "gossip"
end

function voice.Skip(page)
    local api = spoken()
    local head = api and api.GetCurrent and api:GetCurrent()
    if head and api.Skip then
        if page and page.clip == head then finished[head] = true end
        api:Skip()
    end
end

local standaloneSources = {quests = true, gossip = true, places = true, readables = true, bosses = true}
local function ownsClip(api, clip)
    local source = clip and clip.source and clip.source.key
    return standaloneSources[source] and not finished[clip]
        and (not api.ShowsNarratorFor or api:ShowsNarratorFor(source))
end

function voice.OwnsHead()
    local api = spoken()
    return api and api.GetCurrent and ownsClip(api, api:GetCurrent())
end

local standalone, standaloneHead, showAfter
function voice.Standalone()
    local api = spoken()
    local clip = api and api.GetCurrent and api:GetCurrent()
    local source = clip and clip.source and clip.source.key
    if not ownsClip(api, clip) then
        standalone, standaloneHead = nil, nil
        return
    end
    if standaloneHead ~= clip then
        standaloneHead = clip
        standalone = nil
        local present = clip.present or {}
        local title, text = present.label, present.transcript or clip.text
        if type(text) == "string" and text ~= "" then
            local npc = source == "quests" or source == "gossip"
            local selfTest = clip.origin == "/spq test"
            showAfter = GetTime() + (npc and not selfTest and 0.4 or 0)
            standalone = {clip = clip, standalone = true, selfTest = selfTest, questID = selfTest and 0 or tonumber(clip.questID) or 0,
                title = title and title ~= "" and title or present.header or "Spoken", text = text}
        end
    end
    if not standalone then return end
    if GetTime() < showAfter then return nil, true end
    return standalone
end

function voice.Waiting(page)
    local api = spoken()
    local seen, n = {}, 0
    if page.clip then seen[page.clip] = true end
    for _, entry in ipairs(voice.queue) do
        local clip = entry.clip
        if clip and not seen[clip] and not finished[clip] then seen[clip] = true; n = n + 1 end
    end
    for _, clip in ipairs(api and api.GetQueue and api:GetQueue() or {}) do
        if not seen[clip] and not finished[clip] then seen[clip] = true; n = n + 1 end
    end
    return n
end

function voice.CleanQueue()
    for index = #voice.queue, 1, -1 do
        local page = voice.queue[index]
        if page.clip and finished[page.clip] or not page.clip and GetTime() > page.waitUntil then
            table.remove(voice.queue, index)
        end
    end
end
