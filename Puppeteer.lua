Puppeteer = {}
PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
_G.PuppeteerLib = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0")

VERSION = GetAddOnMetadata("Puppeteer", "version")

TestUI = false

Banzai = AceLibrary("Banzai-1.0")
HealComm = AceLibrary("HealComm-1.0")
GuidRoster = nil -- Will be nil if SuperWoW isn't present

local compost = AceLibrary("Compost-2.0")
local util = PTUtil
local colorize = util.Colorize
local GetKeyModifier = util.GetKeyModifier
local GetClass = util.GetClass
local GetPowerType = util.GetPowerType
local UseItem = util.UseItem
local GetItemCount = util.GetItemCount

PartyUnits = util.PartyUnits
PetUnits = util.PetUnits
TargetUnits = util.TargetUnits
RaidUnits = util.RaidUnits
RaidPetUnits = util.RaidPetUnits
AllUnits = util.AllUnits
AllUnitsSet = util.AllUnitsSet
AllCustomUnits = util.CustomUnits
AllCustomUnitsSet = util.CustomUnitsSet

ReadableButtonMap = {
    ["LeftButton"] = "Left",
    ["MiddleButton"] = "Middle",
    ["RightButton"] = "Right",
    ["Button4"] = "Button 4",
    ["Button5"] = "Button 5"
}

ResurrectionSpells = {
    ["PRIEST"] = "Resurrection",
    ["PALADIN"] = "Redemption",
    ["SHAMAN"] = "Ancestral Spirit",
    ["DRUID"] = "Rebirth"
}

local ptBarsPath = util.GetAssetsPath().."textures\\bars\\"
BarStyles = {
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Blizzard Smooth"] = ptBarsPath.."Blizzard-Smooth",
    ["Blizzard Raid"] = ptBarsPath.."Blizzard-Raid",
    ["Blizzard Raid Sideless"] = ptBarsPath.."Blizzard-Raid-Sideless",
    ["HealersMate"] = ptBarsPath.."HealersMate",
    ["HealersMate Borderless"] = ptBarsPath.."HealersMate-Borderless",
    ["HealersMate Shineless"] = ptBarsPath.."HealersMate-Shineless",
    ["HealersMate Shineless Borderless"] = ptBarsPath.."HealersMate-Shineless-Borderless"
}

GameTooltip = CreateFrame("GameTooltip", "PTGameTooltip", UIParent, "GameTooltipTemplate")

CurrentlyHeldButton = nil

-- An unmapped array of all unit frames
AllUnitFrames = {}
-- A map of units to an array of unit frames associated with the unit
PTUnitFrames = {}

-- Key: Unit frame group name | Value: The group
UnitFrameGroups = {}

CustomUnitGUIDMap = PTUnitProxy and PTUnitProxy.CustomUnitGUIDMap or {}
GUIDCustomUnitMap = PTUnitProxy and PTUnitProxy.GUIDCustomUnitMap or {}


CurrentlyInRaid = false

Mouseover = nil

-- Returns the array of unit frames of the unit
function GetUnitFrames(unit)
    return PTUnitFrames[unit]
end

-- A temporary dummy function while the addon initializes. See below for the real iterator.
function UnitFrames(unit)
    return function() end
end

local function OpenUnitFramesIterator()
    -- UnitFrames function definition.
    -- Returns an iterator for the unit frames of the unit.
    -- These iterators have a serious problem in that they do not support concurrent iteration.
    if util.IsSuperWowPresent() then
        local EMPTY_UIS = {}
        local PTUnitFrames = PTUnitFrames
        local GuidUnitMap = PTGuidRoster.GuidUnitMap
        local iterTable = {} -- The table reused for iteration over GUID units
        local uis
        local i = 0
        local len = 0
        local iterFunc = function()
            i = i + 1
            if i <= len then
                return uis[i]
            end
        end
        function UnitFrames(unit)
            if i < len then
                print("Collision: "..i.."/"..len)
            end
            if GuidUnitMap[unit] then -- If a GUID is provided, ALL UIs associated with that GUID will be iterated
                uis = iterTable
                for i = 1, table.getn(uis) do
                    uis[i] = nil
                end
                table.setn(uis, 0)
                for _, unit in pairs(GuidUnitMap[unit]) do
                    for _, frame in ipairs(PTUnitFrames[unit]) do
                        table.insert(uis, frame)
                    end
                end
            else
                uis = PTUnitFrames[unit] or EMPTY_UIS
            end
            len = table.getn(uis)
            i = 0
            return iterFunc
        end
    else -- Optimized version for vanilla
        local PTUnitFrames = PTUnitFrames
        local uis
        local i = 0
        local len = 0
        local iterFunc = function()
            i = i + 1
            if i <= len then
                return uis[i]
            end
        end
        function UnitFrames(unit)
            i = 0
            uis = PTUnitFrames[unit]
            len = table.getn(uis)
            return iterFunc
        end
    end
end

function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function GetSpells()
    return PTSpells["Friendly"]
end

function GetHostileSpells()
    return PTSpells["Hostile"]
end

function UpdateUnitFrameGroups()
    for _, group in pairs(UnitFrameGroups) do
        group:UpdateUIPositions()
    end
end

function UpdateAllIncomingHealing()
    if PTHealPredict then
        for _, ui in ipairs(AllUnitFrames) do
            if PTOptions.UseHealPredictions then
                local _, guid = UnitExists(ui:GetUnit())
                ui:SetIncomingHealing(PTHealPredict.GetIncomingHealing(guid))
            else
                ui:SetIncomingHealing(0)
            end
        end
    else
        for _, ui in ipairs(AllUnitFrames) do
            if PTOptions.UseHealPredictions then
                ui:UpdateIncomingHealing()
            else
                ui:SetIncomingHealing(0)
            end
        end
    end
end

function UpdateAllOutlines()
    for _, ui in ipairs(AllUnitFrames) do
        ui:UpdateOutline()
    end
end

function CreateUnitFrameGroup(groupName, environment, units, petGroup, profile, sortByRole)
    if UnitFrameGroups[groupName] then
        error("[Puppeteer] Tried to create a unit frame group using existing name! \""..groupName.."\"")
        return
    end
    local uiGroup = PTUnitFrameGroup:New(groupName, environment, units, petGroup, profile, sortByRole)
    for _, unit in ipairs(units) do
        local ui = PTUnitFrame:New(unit, AllCustomUnitsSet[unit] ~= nil)
        if not PTUnitFrames[unit] then
            PTUnitFrames[unit] = {}
        end
        table.insert(PTUnitFrames[unit], ui)
        table.insert(AllUnitFrames, ui)
        uiGroup:AddUI(ui)
        if unit ~= "target" then
            ui:Hide()
        end
    end
    UnitFrameGroups[groupName] = uiGroup
    return uiGroup
end

local function initUnitFrames()
    local getSelectedProfile = PuppeteerSettings.GetSelectedProfile
    CreateUnitFrameGroup("Party", "party", PartyUnits, false, getSelectedProfile("Party"))
    CreateUnitFrameGroup("Pets", "party", PetUnits, true, getSelectedProfile("Pets"))
    CreateUnitFrameGroup("Raid", "raid", RaidUnits, false, getSelectedProfile("Raid"))
    CreateUnitFrameGroup("Raid Pets", "raid", RaidPetUnits, true, getSelectedProfile("Raid Pets"))
    CreateUnitFrameGroup("Target", "all", TargetUnits, false, getSelectedProfile("Target"), false)
    if util.IsSuperWowPresent() then
        CreateUnitFrameGroup("Focus", "all", PTUnitProxy.CustomUnitsMap["focus"], false, getSelectedProfile("Focus"), false)
    end

    UnitFrameGroups["Target"].ShowCondition = function(self)
        local friendly = not UnitCanAttack("player", "target")
        return (PTOptions.AlwaysShowTargetFrame or (UnitExists("target") and 
            (friendly and PTOptions.ShowTargets.Friendly) or (not friendly and PTOptions.ShowTargets.Hostile))) 
            and not PTOptions.Hidden
    end

    OpenUnitFramesIterator()
end

function OnAddonLoaded()
    StartTiming("OnLoad")
    local freshInstall = false
    if PTSpells == nil then
        freshInstall = true
        local PTSpells = {}
        PTSpells["Friendly"] = {}
        PTSpells["Hostile"] = {}
        setglobal("PTSpells", PTSpells)
    end

    for _, spells in pairs(PTSpells) do
        for _, modifier in ipairs(util.GetKeyModifiers()) do
            if not spells[modifier] then
                spells[modifier] = {}
            end
        end
    end

    if PTBindings == nil then
        _G.PTBindings = {}
        PTBindings["SelectedLoadout"] = "Default"
        local loadouts = {}
        PTBindings["Loadouts"] = loadouts
        loadouts["Default"] = CreateEmptyBindingsLoadout()
    end

    PuppeteerSettings.SetDefaults()

    SetupSpecialButtons()
    InitBindingDisplayCache()

    if util.IsSuperWowPresent() then
        -- In case other addons override unit functions, we want to make sure we're using their functions
        PTUnitProxy.CreateUnitProxies()

        -- Do it again after all addons have loaded
        local frame = CreateFrame("Frame")
        local reapply = GetTime() + 0.1
        frame:SetScript("OnUpdate", function()
            if GetTime() > reapply then
                PTUnitProxy.CreateUnitProxies()
                frame:SetScript("OnUpdate", nil)
            end
        end)
    end

    if not _G.PTRoleCache then
        _G.PTRoleCache = {}
    end
    if not _G.PTRoleCache[GetRealmName()] then
        _G.PTRoleCache[GetRealmName()] = {}
    end
    AssignedRoles = _G.PTRoleCache[GetRealmName()]
    PruneAssignedRoles()

    if util.IsSuperWowPresent() then
        PTUnit.UpdateGuidCaches()

        local customUnitUpdater = CreateFrame("Frame", "PTCustomUnitUpdater")
        local nextUpdate = GetTime() + 0.25
        -- Older versions of SuperWoW had an issue where units that aren't part of normal units wouldn't receive events,
        -- so updates are done manually
        local needsManualUpdates = util.SuperWoWFeatureLevel < util.SuperWoW_v1_4
        customUnitUpdater:SetScript("OnUpdate", function()
            if GetTime() > nextUpdate then
                nextUpdate = GetTime() + 0.25

                for unit, guid in pairs(CustomUnitGUIDMap) do
                    if needsManualUpdates or not UnitExists(guid) then
                        PTUnit.Get(unit):UpdateAuras()
                        for ui in UnitFrames(unit) do
                            ui:UpdateHealth()
                            ui:UpdatePower()
                            ui:UpdateAuras()
                            ui:UpdateIncomingHealing()
                        end
                    end
                end
            end
        end)
    else
        PTUnit.CreateCaches()
    end
    PuppeteerSettings.UpdateTrackedDebuffTypes()
    PTProfileManager.InitializeDefaultProfiles()

    do
        if PTOptions.Scripts.OnLoad then
            local scriptString = "local GetProfile = PTProfileManager.GetProfile "..
                "local CreateProfile = PTProfileManager.CreateProfile "..PTOptions.Scripts.OnLoad
            local script = loadstring(scriptString)
            local ok, result = pcall(script)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("ERROR: ", 1, 0.2, 0.2)
                    ..colorize("The Load Script produced an error! If this causes Puppeteer to fail to load, "..
                        "you will need to manually edit the script in your game files.", 1, 0.4, 0.4))
                DEFAULT_CHAT_FRAME:AddMessage(colorize("OnLoad Script Error: "..tostring(result), 1, 0, 0))
            end
        end
    end
    PTSettingsGUIOld.InitSettings()
    PTSettingsGui.Init()
    if PTHealPredict then
        PTHealPredict.OnLoad()

        PTHealPredict.HookUpdates(function(guid, incomingHealing, incomingDirectHealing)
            if not PTOptions.UseHealPredictions then
                return
            end
            local units = GuidRoster.GetUnits(guid)
            if not units then
                return
            end
            for _, unit in ipairs(units) do
                for ui in UnitFrames(unit) do
                    ui:SetIncomingHealing(incomingHealing, incomingDirectHealing)
                end
            end
        end)
    else
        local roster = AceLibrary("RosterLib-2.0")
        PuppeteerLib:RegisterEvent("HealComm_Healupdate", function(name)
            if not PTOptions.UseHealPredictions then
                return
            end
            local unit = roster:GetUnitIDFromName(name)
            if unit then
                for ui in UnitFrames(unit) do
                    ui:UpdateIncomingHealing()
                end
            end
            if UnitName("target") == name then
                for ui in UnitFrames("target") do
                    ui:UpdateIncomingHealing()
                end
            end
        end)
        PuppeteerLib:RegisterEvent("HealComm_Ressupdate", function(name)
            local unit = roster:GetUnitIDFromName(name)
            if unit then
                for ui in UnitFrames(unit) do
                    ui:UpdateHealth()
                end
            end
            if UnitName("target") == name then
                for ui in UnitFrames("target") do
                    ui:UpdateHealth()
                end
            end
        end)
    end
    
    SetLFTAutoRoleEnabled(PTOptions.LFTAutoRole)

    TestUI = PTOptions.TestUI

    if TestUI then
        DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] UI Testing is enabled. Use /pt testui to disable.", 1, 0.6, 0.6))
    end

    initUnitFrames()
    StartDistanceScanner()

    PuppeteerLib:RegisterEvent("Banzai_UnitGainedAggro", function(unit)
        if PTGuidRoster then
            unit = PTGuidRoster.GetUnitGuid(unit)
        end
        for ui in UnitFrames(unit) do
            ui:UpdateOutline()
        end
    end)
	PuppeteerLib:RegisterEvent("Banzai_UnitLostAggro", function(unit)
        if PTGuidRoster then
            unit = PTGuidRoster.GetUnitGuid(unit)
        end
        for ui in UnitFrames(unit) do
            ui:UpdateOutline()
        end
    end)

    if PTOnLoadInfoDisabled == nil then
        PTOnLoadInfoDisabled = false
    end

    do
        local INFO_SEND_TIME = GetTime() + 0.5
        local infoFrame = CreateFrame("Frame")
        infoFrame:SetScript("OnUpdate", function()
            if GetTime() < INFO_SEND_TIME then
                return
            end
            infoFrame:SetScript("OnUpdate", nil)
            if not PTOnLoadInfoDisabled then
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] Use ", 0.5, 1, 0.5)..colorize("/pt help", 0, 1, 0)
                    ..colorize(" to see commands.", 0.5, 1, 0.5))
            end
    
            if not util.IsSuperWowPresent() and util.IsNampowerPresent() then
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("WARNING: ", 1, 0.2, 0.2)
                    ..colorize("You are using Nampower without SuperWoW, which will cause heal predictions to be wildly inaccurate "..
                    "for you and your raid members! It is highly recommended to install SuperWoW.", 1, 0.4, 0.4))
            end

            if util.IsSuperWowPresent() and not HealComm:IsEventRegistered("UNIT_CASTEVENT") then
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("WARNING: ", 1, 0.2, 0.2)
                    ..colorize("You have another addon that uses a HealComm version that is incompatible with SuperWoW! "..
                    "This will cause wildly inaccurate heal predictions to be shown to your raid members. It is "..
                    "recommended to either unload the offending addon or copy Puppeteer's HealComm "..
                    "into the other addon.", 1, 0.4, 0.4))
            end
        end)
    end

    -- Create default bindings for new characters
    if freshInstall then
        local class = GetClass("player")
        local spells = GetSpells()
        local hostileSpells = GetHostileSpells()
        if class == "PRIEST" then
            spells["None"]["LeftButton"] = "Power Word: Shield"
            spells["None"]["MiddleButton"] = "Renew"
            spells["None"]["RightButton"] = "Lesser Heal"
            spells["Shift"]["LeftButton"] = "Target"
            spells["Shift"]["RightButton"] = "Context"
            spells["Control"]["RightButton"] = "Dispel Magic"

            hostileSpells["None"]["RightButton"] = "Dispel Magic"
        elseif class == "DRUID" then
            spells["None"]["LeftButton"] = "Rejuvenation"
            spells["None"]["RightButton"] = "Healing Touch"
            spells["Shift"]["LeftButton"] = "Target"
            spells["Shift"]["MiddleButton"] = "Role"
            spells["Shift"]["RightButton"] = "Context"
            spells["Control"]["RightButton"] = "Remove Curse"
        elseif class == "PALADIN" then
            spells["None"]["LeftButton"] = "Flash of Light"
            spells["None"]["RightButton"] = "Holy Light"
            spells["Shift"]["LeftButton"] = "Target"
            spells["Shift"]["MiddleButton"] = "Role"
            spells["Shift"]["RightButton"] = "Context"
            spells["Control"]["RightButton"] = "Cleanse"
        elseif class == "SHAMAN" then
            spells["None"]["LeftButton"] = "Healing Wave"
            spells["None"]["RightButton"] = "Lesser Healing Wave"
            spells["Shift"]["LeftButton"] = "Target"
            spells["Shift"]["MiddleButton"] = "Role"
            spells["Shift"]["RightButton"] = "Context"
            spells["Control"]["RightButton"] = "Cure Disease"
        else
            -- Non-healer classes can use this addon like traditional raid frames
            spells["None"]["LeftButton"] = "Target"
            spells["None"]["MiddleButton"] = "Role"
            spells["None"]["RightButton"] = "Context"
        end
        hostileSpells["None"]["LeftButton"] = "Target"
    end

    do
        if PTOptions.Scripts.OnPostLoad then
            local scriptString = PTOptions.Scripts.OnPostLoad
            local script = loadstring(scriptString)
            local ok, result = pcall(script)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("ERROR: ", 1, 0.2, 0.2)
                    ..colorize("The Postload Script produced an error! If this causes Puppeteer to fail to operate, "..
                        "you may need to manually edit the script in your game files.", 1, 0.4, 0.4))
                DEFAULT_CHAT_FRAME:AddMessage(colorize("OnPostLoad Script Error: "..tostring(result), 1, 0, 0))
            end
        end
    end

    EndTiming("OnLoad")
end

function CheckPartyFramesEnabled()
    local shouldBeDisabled = (CurrentlyInRaid and PTOptions.DisablePartyFrames.InRaid) or 
        (not CurrentlyInRaid and PTOptions.DisablePartyFrames.InParty)
    SetPartyFramesEnabled(not shouldBeDisabled)
end

function SetPartyFramesEnabled(enabled)
    if enabled then
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = getglobal("PartyMemberFrame"..i)
            if frame and frame.PTRealShow then
                frame.Show = frame.PTRealShow
                frame.PTRealShow = nil

                if UnitExists("party"..i) then
                    frame:Show()
                end
                local prevThis = _G.this
                _G.this = frame
                PartyMemberFrame_OnLoad()
                _G.this = prevThis
            end
        end
    else
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = getglobal("PartyMemberFrame"..i)
            if frame and not frame.PTRealShow then
                frame:UnregisterAllEvents()
                frame.PTRealShow = frame.Show
                frame.Show = function() end
                frame:Hide()
            end
        end
    end
end

function _G.PT_ToggleFocusUnit(unit)
    if PTUnitProxy.IsUnitUnitType(unit, "focus") then
        if not PTUnitProxy.CustomUnitsSetMap["focus"][unit] then
            return -- Do not toggle focus if user is clicking on a UI that isn't the focus UI
        end
        PT_UnfocusUnit(unit)
    else
        PT_FocusUnit(unit)
    end
end

function _G.PT_FocusUnit(unit)
    local guid = PTGuidRoster.ResolveUnitGuid(unit)
    if not guid or PTUnitProxy.IsGuidUnitType(guid, "focus") then
        return
    end

    PTUnitProxy.SetGuidUnitType(guid, "focus")
    PlaySound("GAMETARGETHOSTILEUNIT")
end

function _G.PT_UnfocusUnit(unit)
    local guid = PTGuidRoster.ResolveUnitGuid(unit)
    if not guid then
        return
    end
    local focusUnit = PTUnitProxy.GetCurrentUnitOfType(guid, "focus")
    if not focusUnit then
        return
    end
    PTUnitProxy.SetCustomUnitGuid(focusUnit, nil)
    PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
end

function _G.PT_PromoteFocus(unit)
    local guid = PTGuidRoster.ResolveUnitGuid(unit)
    if not guid then
        return
    end
    PTUnitProxy.PromoteGuidUnitType(guid, "focus")
end

function CycleFocus(onlyAttackable)
    PTUnitProxy.CycleUnitType("focus", onlyAttackable)
end

local emptySpell = {}
function UnitFrame_OnClick(button, unit, unitFrame)
    local binding = GetBindingFor(unit, GetKeyModifier(), button)
    local targetCastable = UnitIsConnected(unit) and UnitIsVisible(unit)
    local wantToRes = PTOptions.AutoResurrect and util.IsDeadFriend(unit) and ResurrectionSpells[GetClass("player")]
    if not binding then
        if targetCastable and wantToRes then
            RunBinding_Spell(emptySpell, unit)
        end
        return
    end

    RunBinding(binding, unit, unitFrame)
end

-- Reevaluates what UI frames should be shown
function CheckGroup()
    if GetNumRaidMembers() > 0 then
        if not CurrentlyInRaid then
            CurrentlyInRaid = true
            SetPartyFramesEnabled(not PTOptions.DisablePartyFrames.InRaid)
        end
    else
        if CurrentlyInRaid then
            CurrentlyInRaid = false
            SetPartyFramesEnabled(not PTOptions.DisablePartyFrames.InParty)
        end
    end
    local superwow = util.IsSuperWowPresent()
    if superwow then
        GuidRoster.ResetRoster()
        GuidRoster.PopulateRoster()
        PTUnit.UpdateGuidCaches()
    end
    for _, unit in ipairs(util.AllRealUnits) do
        local exists, guid = UnitExists(unit)
        if unit ~= "target" then
            if exists then
                for ui in UnitFrames(unit) do
                    ui:Show()
                end
            else
                for ui in UnitFrames(unit) do
                    ui:Hide()
                end
            end
        end
    end
    for _, group in pairs(UnitFrameGroups) do
        group:EvaluateShown()
    end
    if not superwow then -- If SuperWoW isn't present, the units may have shifted and thus require a full scan
        PTUnit.UpdateAllUnits()
    end
    for _, ui in pairs(AllUnitFrames) do
        if ui:IsShown() then
            ui:UpdateRange()
            ui:UpdateAuras()
            ui:UpdateIncomingHealing()
            ui:UpdateOutline()
        end
    end
    if superwow then
        PTHealPredict.SetRelevantGUIDs(GuidRoster.GetTrackedGuids())
    end
    RunTrackingScan()
end

function CheckTarget()
    local exists, guid = UnitExists("target")
    if exists then
        local friendly = not UnitCanAttack("player", "target")
        if (friendly and PTOptions.ShowTargets.Friendly) or (not friendly and PTOptions.ShowTargets.Hostile) then
            for ui in UnitFrames("target") do
                ui.lastHealthPercent = (ui:GetCurrentHealth() / ui:GetMaxHealth()) * 100
                ui:UpdateRange()
                ui:UpdateSight()
                ui:UpdateRole()
                ui:UpdateIncomingHealing()
            end
        end
    else
        for ui in UnitFrames("target") do
            ui.lastHealthPercent = (ui:GetCurrentHealth() / ui:GetMaxHealth()) * 100
            ui:UpdateAll()
            ui:UpdateRole()
            ui:UpdateIncomingHealing()
        end
    end
    UnitFrameGroups["Target"]:EvaluateShown()
end

function IsRelevantUnit(unit)
    --return not string.find(unit, "0x")
    return AllUnitsSet[unit] ~= nil or GUIDCustomUnitMap[unit]
end

function print(msg)
    if not PTOptions or not PTOptions["Debug"] then
        return
    end
    local window
    local i = 1
    while not window do
        local name = GetChatWindowInfo(i)
        if not name then
            break
        end
        if name == "Debug" then
            window = getglobal("ChatFrame"..i)
            break
        end
        i = i + 1
    end
    if window then
        window:AddMessage(tostring(msg))
    end
end

function StartTiming(name)
    if not pfDebug_StartTiming then
        return
    end
    pfDebug_StartTiming(name)
end

function EndTiming(name)
    if not pfDebug_EndTiming then
        return
    end
    pfDebug_EndTiming(name)
end