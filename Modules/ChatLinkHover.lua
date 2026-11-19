-- Item-link hover tooltips for Blizzard chat frames.
-- Hooks only hyperlink hover; clicking remains Blizzard-owned.
local function showLink(frame, link)
    if type(link) ~= "string" or not link:match("^item:") then return end
    if not GameTooltip or not GameTooltip.SetHyperlink then return end
    local tooltip = GameTooltip
    local ok = pcall(function()
        tooltip:SetOwner(frame, "ANCHOR_CURSOR")
        tooltip:SetHyperlink(link)
        tooltip:Show()
    end)
    if not ok then tooltip:Hide() end
end

local function hideLink()
    if GameTooltip and GameTooltip:IsOwned(UIParent) then return end
    if GameTooltip then GameTooltip:Hide() end
end

local hooked = {}
local function hookChatFrame(frame)
    if not frame or hooked[frame] then return end
    local ok = pcall(function()
        frame:HookScript("OnHyperlinkEnter", function(self, link)
            showLink(self, link)
        end)
        frame:HookScript("OnHyperlinkLeave", function()
            hideLink()
        end)
    end)
    if ok then hooked[frame] = true end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_CHAT_WINDOWS")
loader:SetScript("OnEvent", function()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        hookChatFrame(_G["ChatFrame" .. i])
    end
end)
