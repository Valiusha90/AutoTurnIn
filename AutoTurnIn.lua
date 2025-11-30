-- Auto TurnIn Shards - Turtle / Vanilla

-- Quest names (exactly as shown in game, in your language)
local QUESTS = {
    ["Shard De-Harmonization"] = "ShardDeharm",
    ["Mass Harmonization"]     = "MassHarm",
    ["Shard Harmonization"]    = "ShardHarm",
    ["Corrupted Sand"]    = "CorruptedSand",
    ["Sand in Bulk"]    = "SandInBulk",
}

-- Saved variable declared in .toc
AutoTurnInDB = AutoTurnInDB

--------------------------------------------------------
-- Helpers
--------------------------------------------------------

local function EnsureDB()
    if not AutoTurnInDB then
        AutoTurnInDB = {}
    end
    if not AutoTurnInDB.enabled then
        AutoTurnInDB.enabled = {}
    end

    -- default: OFF for all
    local questName, key
    for questName, key in pairs(QUESTS) do
        if AutoTurnInDB.enabled[key] == nil then
            AutoTurnInDB.enabled[key] = 0
        end
    end
end

local function IsQuestHandled(questTitle)
    if not questTitle then return false end
    local key = QUESTS[questTitle]
    if not key then return false end
    return AutoTurnInDB
       and AutoTurnInDB.enabled
       and AutoTurnInDB.enabled[key] == 1
end

--------------------------------------------------------
-- UI frame with checkboxes
--------------------------------------------------------

local ui = CreateFrame("Frame", "AutoTurnInFrame", UIParent)
ui:SetWidth(220)
ui:SetHeight(110)
ui:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ui:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
ui:SetMovable(true)
ui:EnableMouse(true)
ui:RegisterForDrag("LeftButton")

ui:SetScript("OnDragStart", function()
    this:StartMoving()
end)
ui:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

ui:Hide()

local title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)
title:SetText("Auto Turn-in")

local checkboxes = {}

local function CreateQuestCheckbox(labelText, key, index)
    local name = "AutoShardTurninCheck"..index
    local cb = CreateFrame("CheckButton", name, ui, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 12, -20 - (index - 1) * 22)

    local textFS = getglobal(name.."Text")
    if textFS then
        textFS:SetText(labelText)
    end

    -- Only one can be selected at a time; clicking again unselects all
    cb:SetScript("OnClick", function()
        if not (AutoTurnInDB and AutoTurnInDB.enabled) then return end

        local clickedKey = key

        if this:GetChecked() then
            -- Set this one ON, all others OFF
            AutoTurnInDB.enabled[clickedKey] = 1

            local qn, k2
            for qn, k2 in pairs(QUESTS) do
                if k2 ~= clickedKey then
                    AutoTurnInDB.enabled[k2] = 0
                    if checkboxes[k2] then
                        checkboxes[k2]:SetChecked(nil)
                    end
                end
            end
        else
            -- Unchecking current: no quest selected
            AutoTurnInDB.enabled[clickedKey] = 0
        end
    end)

    checkboxes[key] = cb
end

do
    local idx = 1
    local questName, key
    for questName, key in pairs(QUESTS) do
        CreateQuestCheckbox(questName, key, idx)
        idx = idx + 1
    end
end

-- /autoshard to open config
SLASH_AUTOSHARD1 = "/autoturnin"
SlashCmdList["AUTOTURNIN"] = function()
    if ui:IsShown() then
        ui:Hide()
    else
        ui:Show()
    end
end

--------------------------------------------------------
-- Core auto-turn-in logic (Vanilla style)
--------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("QUEST_GREETING")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")

f:SetScript("OnEvent", function()
    -- in 1.12, `event` is global; args: arg1, arg2, ...

    if event == "VARIABLES_LOADED" then
        EnsureDB()

        -- sync checkbox states
        local questName, key
        for questName, key in pairs(QUESTS) do
            if checkboxes[key] then
                checkboxes[key]:SetChecked(AutoTurnInDB.enabled[key] == 1)
            end
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Auto TurnIn loaded.|r Type |cffffff00/autoshard|r.")

    elseif event == "GOSSIP_SHOW" then
        ------------------------------------------------
        -- Gossip questgivers: auto-select shard quests
        ------------------------------------------------

        -- AVAILABLE quests
        local available = { GetGossipAvailableQuests() }
        local totalAvail = table.getn(available)
        local questIndex = 0

        local i
        for i = 1, totalAvail do
            if type(available[i]) == "string" then
                questIndex = questIndex + 1   -- this is the Nth quest in the list
                local qTitle = available[i]
                if IsQuestHandled(qTitle) then
                    SelectGossipAvailableQuest(questIndex)
                    return
                end
            end
        end

        -- ACTIVE quests (for turn-in)
        local active = { GetGossipActiveQuests() }
        local totalAct = table.getn(active)
        questIndex = 0

        for i = 1, totalAct do
            if type(active[i]) == "string" then
                questIndex = questIndex + 1
                local aTitle = active[i]
                if IsQuestHandled(aTitle) then
                    SelectGossipActiveQuest(questIndex)
                    return
                end
            end
        end

    elseif event == "QUEST_GREETING" then
        ------------------------------------------------
        -- Non-gossip questgivers (classic-style)
        ------------------------------------------------
        local numAvail = GetNumAvailableQuests()
        local i

        for i = 1, numAvail do
            local qTitle = GetAvailableTitle(i)
            if IsQuestHandled(qTitle) then
                SelectAvailableQuest(i)
                return
            end
        end

        local numAct = GetNumActiveQuests()
        for i = 1, numAct do
            local aTitle, isComplete = GetActiveTitle(i)
            if isComplete and IsQuestHandled(aTitle) then
                SelectActiveQuest(i)
                return
            end
        end

    elseif event == "QUEST_DETAIL" then
        local qTitle = GetTitleText()
        if IsQuestHandled(qTitle) then
            AcceptQuest()
        end

    elseif event == "QUEST_PROGRESS" then
        local qTitle = GetTitleText()
        if IsQuestHandled(qTitle) and IsQuestCompletable() then
            CompleteQuest()
        end

    elseif event == "QUEST_COMPLETE" then
        local qTitle = GetTitleText()
        if IsQuestHandled(qTitle) then
            local numChoices = GetNumQuestChoices()
            if numChoices == 0 then
                GetQuestReward(1)
            else
                GetQuestReward(1)
            end
        end
    end
end)
