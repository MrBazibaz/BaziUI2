local D = BaziUI.Dashboard
local row = D.Value
local function art(entry, icon)
    entry.icon = icon
    return entry
end

D.scenarios = {
    {"mixed", "Multiple activities"}, {"questing", "Questing"},
    {"crafting", "Crafting"}, {"skills", "Skill progression"}, {"dungeon", "Dungeon"},
    {"raid", "Raid"}, {"pvp", "Battleground"}, {"supplies", "Low supplies"}, {"activity", "Recent activity"},
}
local samples = {
    recentActivity = {countdown = {duration = 20, remaining = 12}, rows = {
        {label = "Rampage", value = "12", icon = 132338, streakTier = 3, streakCount = 12,
            labelColor = {1, 0.46, 0.34}, tooltip = "Personal best: 18 kills"},
        art(row("Experience", "+80"), 135932),
        art(row("Coins", BaziUI.Inventory.Money(110)), 133784),
        art(row("Chunk of Boar Meat", "×2"), 133970),
        art(row("Linen Cloth", "×3"), 132889),
    }},
    quests = {title = "Redridge Mountains", questItems = {{id = "preview", icon = 133469}}, rows = {
        row("Greater Tarantula", 6, 12, "Underbelly Scales"),
        art(row("Tarantula Egg", 6, 6, "Completed objective"), 132832),
        art(row("Blackrock Axe", 2, 10, "8 remaining"), 132395),
    }},
    professions = {rows = {
        art(row("Mining", "62 / 75 (+4)"), 136248),
        art(row("Engineering", 45, 75), 136243),
        art(row("Cooking", 32, 75), 133971),
        art(row("Skinning", 24, 75), 134366),
    }},
    skills = {rows = {row("Daggers", 28, 30), row("Defense", 29, 30), row("Lockpicking", 15, 30)}},
    crafting = {rows = {art(row("Copper Modulator", "×2"), 133216)}},
    craftingGoals = {rows = {
        row("Copper Modulator ×2", "1 craftable"),
        art(row("Copper Bar", 6, 8), 133216), art(row("Linen Cloth", 4, 4), 132889),
    }},
    supplies = {rows = {
        {label = "Free bag slots", value = "0", warning = true},
        {label = "Durability", value = "18%", warning = true},
    }},
    items = {rows = {art(row("Light Leather", 24, 50), 134252)}},
    reputation = {rows = {row("Darnassus", 1051, 12000, "Honored\n+450 this session")}},
    status = {rows = {row("Free bag slots", 8), row("Durability", "92%"), row("FPS", 72)}},
    session = {rows = {row("Duration", "18:41"), row("XP gained", 2200), row("Quests turned in", 2)}},
    dungeon = {title = "The Deadmines", rows = {
        row("Bosses defeated", 2, 6),
        {label = "Rhahk'Zor", value = "Defeated", done = true},
        {label = "Sneed", value = "Defeated", done = true},
        {label = "Gilnid", value = ""},
        row("Time in instance", "12:37"),
    }},
    raid = {title = "Molten Core", rows = {
        row("Bosses defeated", 1, 10), row("Attempts / wipes", "3 / 1"), row("Time in instance", "25:31"),
    }},
    pvp = {title = "Warsong Gulch", rows = {
        row("Honorable kills", 12), row("Killing blows", 3), row("Deaths", 2), row("Honor gained", 195),
    }},
}
samples.professions.rows[1].progress, samples.professions.rows[1].highlight = 62 / 75, true
samples.skills.rows[1].highlight = true
samples.reputation.rows[1].value = "|cff92d785+25|r  1051 / 12000"
local profiles = {
    mixed = {quests = true, professions = true, skills = true, crafting = true, reputation = true,
        supplies = true, items = true, status = true, session = true, recentActivity = true},
    questing = {quests = true, items = true},
    crafting = {crafting = true, craftingGoals = true}, skills = {skills = true, professions = true},
    dungeon = {dungeon = true, quests = true}, raid = {raid = true, supplies = true},
    pvp = {pvp = true}, supplies = {supplies = true, status = true}, activity = {recentActivity = true},
}

function D.PreviewData(scenario, id)
    local group = profiles[scenario]
    if group and group[id] then return samples[id] end
end
