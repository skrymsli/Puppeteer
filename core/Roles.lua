PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local util = PTUtil
local colorize = util.Colorize
local GetColoredRoleText = util.GetColoredRoleText

AssignedRoles = nil

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

function SetUnitRoleAndUpdate(unit, role)
    if not SetUnitAssignedRole(unit, role) then
        UpdateUnitFrameGroups()
    end
end

RoleAssignInfo = {}

do
    local initFunc = function(self)
        self.checked = (GetAssignedRole(RoleAssignInfo.Name) or "No Role") == self.role
    end

    local genRole = function(role)
        return {
            text = GetColoredRoleText(role),
            role = role,
            initFunc = initFunc,
            func = function(info)
                SetAssignedRole(RoleAssignInfo.Name, info.role)
                UpdateUnitFrameGroups()
            end
        }
    end
    local massRoleFunc = function(info)
        if not RoleAssignInfo.FrameGroup then
            return
        end
        for _, ui in pairs(RoleAssignInfo.FrameGroup.uis) do
            if (not ui:GetRole() or not info.role) and UnitIsPlayer(ui:GetUnit()) then
                SetAssignedRole(UnitName(ui:GetUnit()), info.role)
            end
        end
        UpdateUnitFrameGroups()
        RoleDropdown:SetToggleState(false)
    end
    local genMassRole = function(role)
        return {
            text = GetColoredRoleText(role),
            role = role,
            notCheckable = true,
            func = massRoleFunc
        }
    end

    RoleDropdown = PTGuiLib.Get("dropdown", UIParent)
    local options = {
        {
            initFunc = function(self)
                self.text = colorize(RoleAssignInfo.Name.."'s Role", RoleAssignInfo.ClassColor)
            end,
            notCheckable = true,
            disabled = true,
            textHeight = 12
        }, 
        genRole("Tank"),
        genRole("Healer"),
        genRole("Damage"),
        genRole("No Role"), 
        {
            notCheckable = true,
            disabled = true
        }, {
            text = "Set Unassigned As",
            tooltipTitle = "Set Unassigned As",
            tooltipText = "Mass-set the roles of unassigned players. Only applies to players contained in this UI group.",
            notCheckable = true,
            textHeight = 11,
            children = {
                genMassRole("Tank"),
                genMassRole("Healer"),
                genMassRole("Damage")
            }
        }, {
            text = "Clear Roles",
            tooltipTitle = "Clear Roles",
            tooltipText = "Clear all players' roles. Only applies to players contained in this UI group.",
            notCheckable = true,
            textHeight = 11,
            func = massRoleFunc
        }
    }
    RoleDropdown:SetOptions(options)
end