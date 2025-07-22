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
local GetColoredRoleText = util.GetColoredRoleText
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

AssignedRoles = nil

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

function GetBindings()
    return PTBindings.Loadouts[PTBindings.SelectedLoadout]
end

function GetBindingsFor(unit)
    local bindings = GetBindings().Bindings
    if not UnitCanAttack("player", unit) or bindings.UseFriendlyForEnemy then
        return bindings.Friendly
    end
    return bindings.Hostile
end

function GetBinding(friendlyOrEnemy, modifier, button)
    local bindings = GetBindings()
    if bindings.UseFriendlyForEnemy and friendlyOrEnemy == "Enemy" then
        friendlyOrEnemy = "Friendly"
    end
    local l1 = bindings.Bindings[friendlyOrEnemy]
    if not l1 then
        return
    end
    local l2 = l1[modifier]
    if not l2 then
        return
    end
    return l2[button]
end

function GetBindingFor(unit, modifier, button)
    return GetBinding(not UnitCanAttack("player", unit) and "Friendly" or "Enemy", modifier, button)
end

function SetSelectedBindingsLoadout(name)
    PTBindings.SelectedLoadout = name
end

function UpdateUnitFrameGroups()
    for _, group in pairs(UnitFrameGroups) do
        group:UpdateUIPositions()
    end
end

local ScanningTooltip = CreateFrame("GameTooltip", "PTScanningTooltip", nil, "GameTooltipTemplate");
ScanningTooltip:SetOwner(WorldFrame, "ANCHOR_NONE");
-- Allow tooltip SetX() methods to dynamically add new lines based on these
ScanningTooltip:AddFontStrings(
    ScanningTooltip:CreateFontString( "$parentTextLeft1", nil, "GameTooltipText" ),
    ScanningTooltip:CreateFontString( "$parentTextRight1", nil, "GameTooltipText" ) );

-- Thanks ChatGPT
function ExtractSpellRank(spellname)
    -- Find the starting position of "Rank "
    local start_pos = string.find(spellname, "Rank ")

    -- Check if "Rank " was found
    if start_pos then
        -- Adjust start_pos to point to the first digit
        --start_pos = start_pos + 5  -- Move past "Rank "

        -- Find the ending parenthesis
        local end_pos = string.find(spellname, ")", start_pos)

        -- Extract the number substring
        if end_pos then
            local number_str = string.sub(spellname, start_pos, end_pos - 1)
            --local number = tonumber(number_str)  -- Convert to a number

            return number_str
        end
    end
    return nil
end

-- Thanks again ChatGPT
local tooltipResources = {"Mana", "Rage", "Energy"}
function ExtractResourceCost(costText)

    -- First extract resource type
    local resource
    for _, r in ipairs(tooltipResources) do
        if string.find(costText, r) then
            resource = string.lower(r)
            break
        end
    end

    -- No resource found, this spell is probably free
    if not resource then
        return 0
    end

    -- Find the position where non-digit characters start
    local num_end = string.find(costText, "%D")

    -- If a non-digit character is found, extract the number
    if num_end then
        -- Extract the number substring from the start to the position before the non-digit character
        local number_str = string.sub(costText, 1, num_end - 1)
        -- Convert the substring to a number
        local number = tonumber(number_str)
        -- Print the result
        return number, resource
    else
        -- If no non-digit character is found, the entire string is a number
        local number = tonumber(costText)
        return number, resource
    end
end


function GetSpellID(spellname)
    local id = 1;
    local matchingSpells = {}
    local spellRank = ExtractSpellRank(spellname)

    if spellRank ~= nil then
        spellname = string.gsub(spellname, "%b()", "")
    end

    for i = 1, GetNumSpellTabs() do
        local _, _, _, numSpells = GetSpellTabInfo(i);
        for j = 1, numSpells do
            local spellName, rank, realID = GetSpellName(id, "spell");
            if spellName == spellname then
                if rank == spellRank then -- If the rank is specified, then we can check if this is the right spell
                    return id
                else
                    table.insert(matchingSpells, id)
                end
            end
            id = id + 1;
        end
    end
    return matchingSpells[table.getn(matchingSpells)]
end

-- Returns the numerical cost and the resource name; "unknown" if the spell is unknown; 0 if the spell is free
function GetResourceCost(spellName)
    ScanningTooltip:SetOwner(UIParent, "ANCHOR_NONE");

    local spellID, bookType
    if GetSpellSlotTypeIdForName then -- Nampower 2.6.0 function
        spellID, bookType = GetSpellSlotTypeIdForName(spellName)
        if bookType == "unknown" then
            return "unknown"
        end
        if bookType ~= "spell" then
            return 0
        end
    else
        spellID = GetSpellID(spellName)
    end
    if not spellID then
        return "unknown"
    end

    ScanningTooltip:SetSpell(spellID, "spell")

    local leftText = getglobal("PTScanningTooltipTextLeft"..2)

    if leftText:GetText() then
        return ExtractResourceCost(leftText:GetText())
    end
    return 0
end

-- Returns the aura's name and its school type
function GetAuraInfo(unit, type, index)
    -- Make these texts blank since they don't clear otherwise
    local leftText = getglobal("PTScanningTooltipTextLeft1")
    leftText:SetText("")
    local rightText = getglobal("PTScanningTooltipTextRight1")
    rightText:SetText("")
    if type == "Buff" then
        ScanningTooltip:SetUnitBuff(unit, index)
    else
        ScanningTooltip:SetUnitDebuff(unit, index)
    end
    return leftText:GetText() or "", rightText:GetText() or ""
end

function IsValidMacro(name)
    return GetMacroIndexByName(name) ~= 0
end

function RunMacro(name, target)
    if not IsValidMacro(name) then
        return
    end
    if target then
        _G.PT_MacroTarget = target
    end
    local _, _, body = GetMacroInfo(GetMacroIndexByName(name))
    local commands = util.SplitString(body, "\n")
    for i = 1, table.getn(commands) do
        ChatFrameEditBox:SetText(commands[i])
        ChatEdit_SendText(ChatFrameEditBox)
    end
    if target then
        _G.PT_MacroTarget = nil
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
        local default = {
            ["UseFriendlyForEnemy"] = false,
            ["Bindings"] = {
                ["Friendly"] = {
                    ["None"] = {
                        ["LeftButton"] = {
                            ["Type"] = "SPELL",
                            ["Data"] = "Power Word: Shield"
                        },
                        ["RightButton"] = {
                            ["Type"] = "ACTION",
                            ["Data"] = "Target"
                        }
                    }
                },
                ["Enemy"] = {}
            }
        }
        loadouts["Default"] = default
    end
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
    PuppeteerSettings.SetDefaults()

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

LFTAutoRoleFrame = CreateFrame("Frame", "PT_LFTAutoRoleFrame")
function SetLFTAutoRoleEnabled(enabled)
    if not LFT_ADDON_PREFIX then -- Must not be Turtle WoW, or LFT has changed
        return
    end

    if not enabled then
        LFTAutoRoleFrame:SetScript("OnEvent", nil)
        LFTAutoRoleFrame:SetScript("OnUpdate", nil)
        LFTAutoRoleFrame:UnregisterAllEvents()
        return
    end

    if LFTAutoRoleFrame:GetScript("OnEvent") ~= nil then -- Already enabled
        return
    end
    
    local roleMap = {
        ["t"] = "Tank",
        ["h"] = "Healer",
        ["d"] = "Damage"
    }
    local offerCompleteTime = -1 -- The time the offer is completed, used to verify rolecheck info is valid
    local alreadyAssigned = {} -- The Tank & Healer names
    local scanDPSTime = -1
    local AutoRoleFrame_OnUpdate = function()
        if scanDPSTime > GetTime() then
            return
        end

        for _, unit in ipairs(PartyUnits) do
            local name = UnitName(unit)
            if name ~= "Unknown" and not util.ArrayContains(alreadyAssigned, name) then
                print("Assuming "..name.." is Damage")
                SetAssignedRole(name, "Damage")
            end
        end
        UpdateUnitFrameGroups()
        LFTAutoRoleFrame:SetScript("OnUpdate", nil)
    end
    LFTAutoRoleFrame:RegisterEvent("CHAT_MSG_ADDON")
    LFTAutoRoleFrame:SetScript("OnEvent", function()
        if arg1 == LFT_ADDON_PREFIX then
            -- After an offer is complete, it is immediately followed by rolecheck info for the tank and healer
            if strfind(arg2, "S2C_ROLECHECK_INFO") then
                if GetNumPartyMembers() == 4 then
                    local params = util.SplitString(arg2, LFT_ADDON_FIELD_DELIMITER)
                    local member = params[2]
                    params = util.SplitString(params[3], ":") -- get confirmed roles
                    if offerCompleteTime + 0.5 > GetTime() and table.getn(params) == 1 then
                        local role = roleMap[params[1]]
                        table.insert(alreadyAssigned, member)
                        SetAssignedRole(member, role) -- Tank & Healer is sent after the offer is complete
                        print("Assigning "..member.." to "..role)
                        if table.getn(alreadyAssigned) == 2 then -- Set rest as Damage after Tank & Healer is sent
                            -- Delay scanning party members because their names might not be loaded yet
                            scanDPSTime = GetTime() + 1.5
                            LFTAutoRoleFrame:SetScript("OnUpdate", AutoRoleFrame_OnUpdate)
                        end
                        UpdateUnitFrameGroups()
                    end
                end
            elseif strfind(arg2, "S2C_OFFER_COMPLETE") then
                alreadyAssigned = {}
                offerCompleteTime = GetTime()
            end
        end
    end)
end

function GetAssignedRole(name)
    if not AssignedRoles or not AssignedRoles[name] then
        return
    end
    AssignedRoles[name]["lastSeen"] = time()
    return AssignedRoles[name]["role"]
end

function GetUnitAssignedRole(unit)
    if not UnitIsPlayer(unit) then
        return
    end
    return GetAssignedRole(UnitName(unit))
end

function SetAssignedRole(name, role)
    if role == nil or role == "No Role" then
        AssignedRoles[name] = nil
        return
    end
    AssignedRoles[name] = {
        ["role"] = role,
        ["lastSeen"] = time()
    }
end

-- Returns true if role assignment failed
function SetUnitAssignedRole(unit, role)
    if not UnitIsPlayer(unit) then
        return true
    end
    SetAssignedRole(UnitName(unit), role)
end

function PruneAssignedRoles()
    local currentTime = time()
    for name, data in pairs(AssignedRoles) do
        if not data["lastSeen"] or data["lastSeen"] < currentTime - (24 * 60 * 60) then
            AssignedRoles[name] = nil
            --print("Pruned "..name.."'s role")
        end
    end
end

local roleTarget
local roleTargetClassColor
local roleTargetGroup

local function setUnassignedRoles(role)
    if not roleTargetGroup then
        return
    end
    for _, ui in pairs(roleTargetGroup.uis) do
        if not ui:GetRole() and UnitIsPlayer(ui:GetUnit()) then
            SetAssignedRole(UnitName(ui:GetUnit()), role)
        end
    end
    UpdateUnitFrameGroups()
    ToggleDropDownMenu(1, nil, _G["PTRoleDropdown"])
end

local function applyTargetRole(role)
    SetAssignedRole(roleTarget, role)
    UpdateUnitFrameGroups()
end

do
    local roleDropdown = CreateFrame("Frame", "PTRoleDropdown", UIParent, "UIDropDownMenuTemplate")

    local options = {
        {
            ["text"] = "",
            ["arg1"] = "Assign Role",
            ["notCheckable"] = true,
            ["disabled"] = true
        }, {
            ["text"] = GetColoredRoleText("Tank"),
            ["arg1"] = "Tank",
            ["func"] = applyTargetRole
        }, {
            ["text"] = GetColoredRoleText("Healer"),
            ["arg1"] = "Healer",
            ["func"] = applyTargetRole
        }, {
            ["text"] = GetColoredRoleText("Damage"),
            ["arg1"] = "Damage",
            ["func"] = applyTargetRole
        }, {
            ["text"] = GetColoredRoleText("No Role"),
            ["arg1"] = "No Role",
            ["func"] = applyTargetRole
        }, {
            ["text"] = "",
            ["notCheckable"] = true,
            ["disabled"] = true
        }, {
            ["text"] = "Set Unassigned As",
            ["tooltipTitle"] = "Set Unassigned As",
            ["tooltipText"] = "Mass-set the roles of unassigned players. Only applies to players contained in this UI group.",
            ["notCheckable"] = true,
            ["hasArrow"] = true,
            ["suboptions"] = {
                {
                    ["text"] = GetColoredRoleText("Tank"),
                    ["arg1"] = "Tank",
                    ["notCheckable"] = true,
                    ["func"] = setUnassignedRoles
                }, {
                    ["text"] = GetColoredRoleText("Healer"),
                    ["arg1"] = "Healer",
                    ["notCheckable"] = true,
                    ["func"] = setUnassignedRoles
                }, {
                    ["text"] = GetColoredRoleText("Damage"),
                    ["arg1"] = "Damage",
                    ["notCheckable"] = true,
                    ["func"] = setUnassignedRoles
                }
            }
        }, {
            ["text"] = "Clear Roles",
            ["arg1"] = "Clear Roles",
            ["tooltipTitle"] = "Clear Roles",
            ["tooltipText"] = "Clear all players' roles. Only applies to players contained in this UI group.",
            ["notCheckable"] = true,
            ["func"] = function()
                if not roleTargetGroup then
                    return
                end
                for _, ui in pairs(roleTargetGroup.uis) do
                    if ui:GetRole() and UnitIsPlayer(ui:GetUnit()) then
                        SetAssignedRole(UnitName(ui:GetUnit()), nil)
                    end
                end
                UpdateUnitFrameGroups()
                ToggleDropDownMenu(1, nil, _G["PTRoleDropdown"])
            end
        }
    }

    UIDropDownMenu_Initialize(roleDropdown, function(level)
        level = level or 1
        if level == 1 then
            for _, option in ipairs(options) do
                option.checked = (GetAssignedRole(roleTarget) or "No Role") == option.arg1

                if option.arg1 == "Assign Role" and roleTarget then
                    option.text = colorize("Assign Role: ", 1, 0.5, 1)..colorize(roleTarget, roleTargetClassColor)
                end
                UIDropDownMenu_AddButton(option)
            end
        elseif level == 2 then
            local suboptions
            for _, option in ipairs(options) do
                if option.text == UIDROPDOWNMENU_MENU_VALUE then
                    suboptions = option.suboptions
                end
            end
            for _, option in ipairs(suboptions) do
                UIDropDownMenu_AddButton(option, level)
            end
        end
    end, "MENU")
end

local function setUnitRoleAndUpdate(unit, role)
    if not SetUnitAssignedRole(unit, role) then
        UpdateUnitFrameGroups()
    end
end

SpecialBinds = {
    ["target"] = function(unit)
        TargetUnit(unit)
    end,
    ["assist"] = function(unit)
        AssistUnit(unit)
    end,
    ["follow"] = function(unit)
        FollowUnit(unit)
    end,
    ["context"] = function(unit, ui)
        -- Resolve focus to a proper unit if possible
        if AllCustomUnitsSet[unit] then
            unit = PTUnitProxy.ResolveCustomUnit(unit)
            if not unit then
                return
            end
        end

        local dropdown

        local specialContexts = {
            ["player"] = _G["PlayerFrameDropDown"],
            ["target"] = _G["TargetFrameDropDown"],
            ["pet"] = _G["PetFrameDropDown"]
        }
        if specialContexts[unit] then
            dropdown = specialContexts[unit]
        elseif util.StartsWith(unit, "raid") and not util.StartsWith(unit, "raidpet") then
            FriendsDropDown.displayMode = "MENU"
            FriendsDropDown.initialize = function()
                UnitPopup_ShowMenu(_G[UIDROPDOWNMENU_OPEN_MENU], "PARTY", unit, nil, string.sub(unit, 5))
            end
            dropdown = FriendsDropDown
        elseif util.StartsWith(unit, "party") and not util.StartsWith(unit, "partypet") then
            dropdown = _G["PartyMemberFrame"..string.sub(unit, 6).."DropDown"]
        end


        if dropdown then
            local frame = ui:GetRootContainer()
            ToggleDropDownMenu(1, nil, dropdown, frame:GetName(), frame:GetWidth(), 0)
        end
    end,
    ["Role: Tank"] = function(unit)
        setUnitRoleAndUpdate(unit, "Tank")
    end,
    ["Role: Healer"] = function(unit)
        setUnitRoleAndUpdate(unit, "Healer")
    end,
    ["Role: Damage"] = function(unit)
        setUnitRoleAndUpdate(unit, "Damage")
    end,
    ["Role: None"] = function(unit)
        setUnitRoleAndUpdate(unit, nil)
    end,
    ["Role"] = function(unit, ui)
        if not UnitIsPlayer(unit) then
            return
        end
        roleTarget = UnitName(unit)
        roleTargetClassColor = util.GetClassColor(util.GetClass(unit), true)
        roleTargetGroup = ui.owningGroup
        local frame = ui:GetRootContainer()
        local dropdown = _G["PTRoleDropdown"]
        if dropdown:IsShown() then
            ToggleDropDownMenu(1, nil, dropdown)
        end
        ToggleDropDownMenu(1, nil, dropdown, frame:GetName(), frame:GetWidth(), frame:GetHeight())
        PlaySound("igMainMenuOpen")
    end,
    ["Focus"] = function(unit)
        if not util.IsSuperWowPresent() then
            DEFAULT_CHAT_FRAME:AddMessage(colorize("You need SuperWoW to focus targets.", 1, 0.5, 0.5))
            return
        end

        PT_ToggleFocusUnit(unit)
    end,
    ["Promote Focus"] = function(unit)
        if not util.IsSuperWowPresent() then
            DEFAULT_CHAT_FRAME:AddMessage(colorize("You need SuperWoW to focus targets.", 1, 0.5, 0.5))
            return
        end

        PT_PromoteFocus(unit)
    end,
    ["Demote Focus"] = function(unit)
        if not util.IsSuperWowPresent() then
            DEFAULT_CHAT_FRAME:AddMessage(colorize("You need SuperWoW to focus targets.", 1, 0.5, 0.5))
            return
        end

        PT_UnfocusUnit(unit)
        PT_FocusUnit(unit)
    end
}

-- Create aliases for special binds
SpecialBinds["Set Role"] = SpecialBinds["Role"]

-- Make all the special binds upper case
do
    local upperSpecialBinds = {}
    for name, func in pairs(SpecialBinds) do
        upperSpecialBinds[string.upper(name)] = func
    end
    SpecialBinds = upperSpecialBinds
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

local Sound_Disabled = function() end

function RunTargetedAction(unit, actionFunc)
    local hasTarget = UnitExists("target")
    local changeTarget = not UnitIsUnit("target", unit)

    if changeTarget then
        local Sound_Enabled = PlaySound
        _G.PlaySound = Sound_Disabled
        TargetUnit(unit)
        _G.PlaySound = Sound_Enabled
    end

    actionFunc()

    if changeTarget and not PTOptions.AutoTarget then
        if hasTarget then
            TargetLastTarget()
        else
            local Sound_Enabled = PlaySound
            _G.PlaySound = Sound_Disabled
            ClearTarget()
            _G.PlaySound = Sound_Enabled
        end
    end
end

function RunBinding_Spell(binding, unit)
    local spell = binding.Data

    if PTOptions.AutoResurrect and util.IsDeadFriend(unit) then
        if PTUnit.Get(unit):HasBuffIDOrName(45568, "Holy Champion") and GetSpellID("Revive Champion") 
            and UnitAffectingCombat("player") then
                spell = "Revive Champion"
        else
            spell = ResurrectionSpells[GetClass("player")] or spell
        end
    end

    if util.IsSuperWowPresent() then
        if PTOptions.AutoTarget and not UnitIsUnit("target", unit) then
            TargetUnit(unit)
        end
        CastSpellByName(spell, unit)
    else
        RunTargetedAction(unit, function()
            CastSpellByName(spell)
        end)
    end
end

function RunBinding_Action(binding, unit, unitFrame)
    SpecialBinds[string.upper(binding.Data)](unit, unitFrame)
end

function RunBinding_Item(binding, unit)
    RunTargetedAction(unit, function()
        UseItem(binding.Data)
    end)
end

function RunBinding_Macro(binding, unit)
    RunTargetedAction(unit, function()
        RunMacro(binding.Data, unit)
    end)
end

BindingScriptCache = {}
function RunBinding_Script(binding, unit, unitFrame)
    local scriptString = binding.Data
    if not BindingScriptCache[scriptString] then
        BindingScriptCache[scriptString] = loadstring("local unit = PTScriptUnit\n"..scriptString)
    end
    _G.PTScriptUnit = unit
    local ok, result = pcall(BindingScriptCache[scriptString])
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("[Puppeteer] Error occurred while running custom script binding: "..result)
    end
end

MultiMenu = PTGuiLib.Get("dropdown", UIParent)

function RunBinding_Multi(binding, unit, unitFrame)
    if MultiMenu.Options ~= nil then
        compost:Reclaim(MultiMenu.Options, 1)
    end
    MultiMenu:SetToggleState(false)
    local options = compost:GetTable()
    if binding.Data.Title and binding.Data.Title ~= "" then
        table.insert(options, compost:AcquireHash(
            "text", binding.Data.Title,
            "isTitle", true,
            "notCheckable", true,
            "textHeight", 12
        ))
    end
    local list = binding.Data.Bindings
    for _, subBinding in ipairs(list) do
        local subBinding = subBinding
        local display = compost:GetTable()
        _UpdateBindingDisplay(subBinding, display)
        table.insert(options, compost:AcquireHash(
            "text", display.Normal,
            "notCheckable", true,
            "keepShownOnClick", true, -- This is used so that dropdowns shown during the func call don't get immediately hidden
            "func", function()
                MultiMenu:SetToggleState(false)
                RunBinding(subBinding, unit, unitFrame)
            end
        ))
        compost:Reclaim(display)
    end
    MultiMenu:SetOptions(options)
    local container = unitFrame:GetRootContainer()
    MultiMenu:SetToggleState(true, container, container:GetWidth(), container:GetHeight())
    PlaySound("GAMESPELLBUTTONMOUSEDOWN")
end

function RunBinding(binding, unit, unitFrame)
    local targetCastable = UnitIsConnected(unit) and UnitIsVisible(unit)
    local bindingType = binding.Type
    if bindingType == "SPELL" then
        if targetCastable then
            RunBinding_Spell(binding, unit)
        end
    elseif bindingType == "ACTION" then
        RunBinding_Action(binding, unit, unitFrame)
    elseif bindingType == "ITEM" then
        if targetCastable then
            RunBinding_Item(binding, unit)
        end
    elseif bindingType == "MACRO" then
        RunBinding_Macro(binding, unit)
    elseif bindingType == "SCRIPT" then
        RunBinding_Script(binding, unit, unitFrame)
    elseif bindingType == "MULTI" then
        RunBinding_Multi(binding, unit, unitFrame)
    end
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