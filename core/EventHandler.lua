PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local util = PTUtil

local function RegisterEventHandler(events, handler)
    if type(events) == "string" then
        events = {events}
    end
    local frame = CreateFrame("Frame", "PTEventHandler_"..events[1])
    for _, event in ipairs(events) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", handler)
end

RegisterEventHandler("ADDON_LOADED", function()
    if arg1 ~= "Puppeteer" then
        return
    end
    GuidRoster = PTGuidRoster
    OnAddonLoaded()
end)
RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
    CheckGroup()

    if PTOptions.DisablePartyFrames.InParty then
        SetPartyFramesEnabled(false)
    end
end)
RegisterEventHandler({"UNIT_HEALTH", "UNIT_MAXHEALTH"}, function()
    local unit = arg1
    if not IsRelevantUnit(unit) then
        return
    end
    for ui in UnitFrames(unit) do
        ui:UpdateHealth()
    end
end)
RegisterEventHandler({"UNIT_MANA", "UNIT_RAGE", "UNIT_ENERGY", "UNIT_FOCUS", "UNIT_MAXMANA", "UNIT_DISPLAYPOWER"}, function()
    local unit = arg1
    if not IsRelevantUnit(unit) then
        return
    end

    for ui in UnitFrames(unit) do
        ui:UpdatePower()
    end
    
    if unit == "player" then
        ReapplySpellsTooltip()
    end
end)
RegisterEventHandler("UNIT_AURA", function()
    local unit = arg1
    if not IsRelevantUnit(unit) then
        return
    end
    PTUnit.Get(unit):UpdateAuras()
    for ui in UnitFrames(unit) do
        ui:UpdateAuras()
        ui:UpdateHealth() -- Update health because there may be an aura that changes health bar color
    end
end)
RegisterEventHandler({"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE"}, function()
    CheckGroup()
end)
RegisterEventHandler({"UNIT_PET", "PLAYER_PET_CHANGED"}, function()
    local unit = arg1
    if IsRelevantUnit(unit) then
        CheckGroup()
    end
end)
RegisterEventHandler("PLAYER_TARGET_CHANGED", function()
    for _, ui in ipairs(AllUnitFrames) do
        ui:EvaluateTarget()
    end
    local exists, guid = UnitExists("target")
    if guid then
        PTUnit.UpdateGuidCaches()
    end
    
    PTUnit.Get("target"):UpdateAll()
    if util.IsSuperWowPresent() then
        GuidRoster.SetUnitGuid("target", guid)
        PTHealPredict.SetRelevantGUIDs(GuidRoster.GetTrackedGuids())
    end

    if exists then
        EvaluateTracking("target", true)
    end

    if PTOptions.Hidden then
        return
    end

    CheckTarget()
end)
RegisterEventHandler("SPELLS_CHANGED", function()
    PuppeteerSettings.UpdateTrackedDebuffTypes()
end)
RegisterEventHandler("RAID_TARGET_UPDATE", function()
    for _, ui in ipairs(AllUnitFrames) do
        ui:UpdateRaidMark()
    end
end)

local GetKeyModifier = util.GetKeyModifier
local keyListener = CreateFrame("Frame", "PTKeyListener")
local lastModifier = "None"
keyListener:SetScript("OnUpdate", function()
    local modifier = GetKeyModifier()
    if lastModifier ~= modifier then
        lastModifier = modifier
        if SpellsTooltip:IsVisible() then
            ReapplySpellsTooltip()
        end
    end
end)