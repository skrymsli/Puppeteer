PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local compost = AceLibrary("Compost-2.0")
local util = PTUtil
local colorize = util.Colorize
local GetSpellID = util.GetSpellID
local GetClass = util.GetClass

BindingClipboard = nil

function GetBindings()
    return PTBindings.Loadouts[PTBindings.SelectedLoadout]
end

function GetBindingsFor(unit)
    local bindings = GetBindings().Bindings
    if not UnitCanAttack("player", unit) or bindings.UseFriendlyForHostile then
        return bindings.Friendly
    end
    return bindings.Hostile
end

function GetBinding(friendlyOrHostile, modifier, button)
    local bindings = GetBindings()
    if bindings.UseFriendlyForHostile and friendlyOrHostile == "Hostile" then
        friendlyOrHostile = "Friendly"
    end
    local l1 = bindings.Bindings[friendlyOrHostile]
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
    return GetBinding(not UnitCanAttack("player", unit) and "Friendly" or "Hostile", modifier, button)
end

function GetSelectedBindingsLoadoutName()
    return PTBindings.SelectedLoadout
end

function SetSelectedBindingsLoadout(name)
    PTBindings.SelectedLoadout = name
    PTSettingsGui.LoadBindings()
    InitBindingDisplayCache()
end

function GetBindingLoadouts()
    return PTBindings.Loadouts
end

function NewBindingsLoadout(name, baseLoadout)
    local loadouts = GetBindingLoadouts()
    if loadouts[name] then
        return
    end
    local loadout = baseLoadout and util.CloneTable(baseLoadout, true) or CreateEmptyBindingsLoadout()
    loadouts[name] = loadout
end

function CreateEmptyBindingsLoadout()
    return {
        UseFriendlyForHostile = false,
        Bindings = {
            Friendly = {},
            Hostile = {}
        }
    }
end

local SORT_DESCENDING = function(a, b) return a < b end
function GetBindingLoadoutNames()
    local loadouts = GetBindingLoadouts()
    local names = {}
    for name, _ in pairs(loadouts) do
        table.insert(names, name)
    end
    table.sort(names, SORT_DESCENDING)
    return names
end

function PruneLoadout(loadout, copy)
    if copy then
        loadout = util.CloneTable(loadout, true)
    end
    for targetName, target in pairs(loadout.Bindings) do
        for modifierName, modifier in pairs(target) do
            for button, binding in pairs(modifier) do
                local shouldRemove = PruneBinding(binding)
                if shouldRemove then
                    modifier[button] = nil
                end
            end
            if util.IsTableEmpty(modifier) then
                target[modifierName] = nil
            end
        end
    end
    return loadout
end

function PruneBinding(binding)
    if not binding.Type then
        return true
    end
    if binding.Tooltip then
        local tooltip = binding.Tooltip
        if tooltip.Type ~= "DEFAULT" and (tooltip.Data == nil or tooltip.Data == "") then
            tooltip.Type = nil
            tooltip.Data = nil
        end

        if util.IsTableEmpty(tooltip) then
            binding.Tooltip = nil
        end
    end
    -- Empty spells are default and don't need to be stored
    if binding.Type == "SPELL" and (not binding.Data or binding.Data == "") then
        return true
    end
    if binding.Type == "MULTI" then
        if binding.Data.Title == "" then
            binding.Data.Title = nil
        end
        for _, subBinding in ipairs(binding.Data.Bindings) do
            PruneBinding(subBinding)
        end
    end
end

local stringDataBindings = util.ToSet({"SPELL", "ACTION", "ITEM", "MACRO", "SCRIPT"})
function ExpandBinding(binding)
    if not binding.Type then
        binding.Type = "SPELL"
    end
    if not binding.Data then
        if stringDataBindings[binding.Type] then
            binding.Data = ""
        elseif binding.Type == "MULTI" then
            binding.Data = {Bindings = {}}
        end
    end
    if not binding.Tooltip then
        binding.Tooltip = {}
    end
end

function LoadoutEquals(loadout1, loadout2, noCopy)
    return util.TableEquals(PruneLoadout(loadout1, not noCopy), PruneLoadout(loadout2, not noCopy))
end

-- Returns a copy of the clipboard
function GetBindingClipboard()
    return util.CloneTable(BindingClipboard, true)
end

function HasBindingClipboard()
    return BindingClipboard ~= nil
end

-- Copies the binding to the clipboard
function SetBindingClipboard(binding)
    BindingClipboard = util.CloneTable(binding, true)
end


function GetBindingTooltipText(binding)
    if binding.Tooltip and binding.Tooltip.Type == "CUSTOM" then
        return binding.Tooltip.Data
    end
end

local Sound_Disabled = function() end

function RunTargetedAction(binding, unit, actionFunc, mustTempTarget)
    local hasTarget = UnitExists("target")
    local changeTarget = (mustTempTarget or binding.TargetWhileCasting or PTOptions.TargetWhileCasting) 
        and not UnitIsUnit("target", unit)

    if changeTarget then
        local Sound_Enabled = PlaySound
        _G.PlaySound = Sound_Disabled
        TargetUnit(unit)
        _G.PlaySound = Sound_Enabled
    end

    actionFunc()

    local targetAfterCasting = binding.TargetAfterCasting or 
        (binding.TargetAfterCasting == nil and PTOptions.TargetAfterCasting)
    if targetAfterCasting then
        TargetUnit(unit)
    elseif changeTarget then
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

    RunTargetedAction(binding, unit, function()
        if util.IsSuperWowPresent() then
            CastSpellByName(spell, unit)
        else
            CastSpellByName(spell)
        end
    end, not util.IsSuperWowPresent())
end

function RunBinding_Action(binding, unit, unitFrame)
    local action = ActionBindsMap[binding.Data]
    if not action then
        return
    end
    action.Script(unit, unitFrame)
end

function RunBinding_Item(binding, unit)
    RunTargetedAction(binding, unit, function()
        util.UseItem(binding.Data)
    end, true)
end

function RunBinding_Macro(binding, unit)
    RunTargetedAction(binding, unit, function()
        util.RunMacro(binding.Data, unit)
    end)
end

BindingScriptAPI = {
    EnsureBuffs = function(unit, ...)
        local unitData = PTUnit.Get(unit)
        for _, buff in ipairs(arg) do
            if not unitData:HasBuff(buff) then
                if util.IsSuperWowPresent() then
                    CastSpellByName(buff, unit)
                else
                    CastSpellByName(buff)
                end
                return buff
            end
        end
    end
}

local preScript = "local unit = PTScriptUnit;"..
                "local unresolvedUnit = PTScriptUnitUnresolved;"..
                "local unitData = PTUnit.Get(unit);"..
                "local unitFrame = PTScriptUnitFrame;"
BindingScriptCache = {}
BindingEnvironment = setmetatable({_G = _G, api = BindingScriptAPI}, {__index = PTUnitProxy or _G})
function RunBinding_Script(binding, unit, unitFrame)
    local scriptString = binding.Data
    if not BindingScriptCache[scriptString] then
        local func, err = loadstring(preScript..scriptString, scriptString)
        if not func then
            DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] Failed to load binding function:", 1, 0.5, 0.5))
            DEFAULT_CHAT_FRAME:AddMessage(colorize(err, 1, 0.5, 0.5))
            return
        end
        setfenv(func, BindingEnvironment)
        BindingScriptCache[scriptString] = func
    end
    BindingEnvironment.PTScriptUnit = PTUnitProxy and PTUnitProxy.CustomUnitGUIDMap[unit] or unit
    BindingEnvironment.PTScriptUnitUnresolved = unit
    BindingEnvironment.PTScriptUnitFrame = unitFrame
    RunTargetedAction(binding, unit, function()
        local ok, result = pcall(BindingScriptCache[scriptString])
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] Error occurred while running custom script binding:", 1, 0.5, 0.5))
            DEFAULT_CHAT_FRAME:AddMessage(colorize(result, 1, 0.5, 0.5))
        end
    end)
end

MultiMenu = PTGuiLib.Get("dropdown", UIParent)

local function RunMultiBindingElement(self)
    local binding = self.binding
    this.checked = not this.checked
    self.checked = not self.checked -- Done to counter keepShownOnClick check toggle
    if not binding.Data.KeepOpen then
        MultiMenu:SetToggleState(false)
    end


    -- Hacks to make sure any dropdown menus that open while running the binding stay open
    -- The root issue is that since the click function isn't finished running when another dropdown opens,
    -- it tries to close the newly opened dropdown
    local button
    local buttonKeepShownOnClick -- The intended value
    local realAddButton = _G.UIDropDownMenu_AddButton
    if binding.Type ~= "SPELL" and binding.Type ~= "ITEM" then -- Spells and items can't possibly run into an issue
        local selfIndex = util.IndexOf(self.siblings, self)
        _G.UIDropDownMenu_AddButton = function(info, level)
            realAddButton(info, level)
            level = level or 1
            if level ~= 1 then
                return
            end
            local listFrame = _G["DropDownList"..level]
            local index = listFrame.numButtons
            
            if index == selfIndex then
                button = _G[listFrame:GetName().."Button"..index]
                buttonKeepShownOnClick = button.keepShownOnClick
                button.keepShownOnClick = 1
            end
        end
    end

    -- It's rather important that we don't raise an error here
    local ok, result = pcall(RunBinding, self.subBinding, self.unit, self.unitFrame)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("Error while running binding: "..result)
    end

    -- Restore state to what it should be
    _G.UIDropDownMenu_AddButton = realAddButton
    if button then
        util.RunLater(function()
            button.keepShownOnClick = buttonKeepShownOnClick
            if button.checked then
                _G[button:GetName().."Check"]:Hide()
                button.checked = nil
            else
                _G[button:GetName().."Check"]:Show()
                button.checked = 1
            end
        end)
    end
end

function RunBinding_Multi(binding, unit, unitFrame)
    StartTiming("MultiInit")
    if MultiMenu.Options ~= nil then
        compost:Reclaim(MultiMenu.Options, 1)
    end
    MultiMenu:SetToggleState(false)
    local options = compost:GetTable()
    local title = binding.Data.Title ~= "" and binding.Data.Title -- or GetBindingTooltipText(binding)
    if title then
        local titleColor = binding.Data.TitleColor or BindTypeTooltipColors[binding.Type]
        table.insert(options, compost:AcquireHash(
            "text", colorize(title, titleColor),
            "isTitle", true,
            "notCheckable", true,
            "textHeight", 12
        ))
    end
    local list = binding.Data.Bindings
    for _, subBinding in ipairs(list) do
        local subBinding = subBinding
        local display = compost:GetTable()
        StartTiming("MultiInitDisplay")
        _UpdateBindingDisplay(subBinding, display)
        EndTiming("MultiInitDisplay")
        table.insert(options, compost:AcquireHash(
            "text", display.Normal,
            "notCheckable", true,
            "keepShownOnClick", true, -- This is used so that dropdowns shown during the func call don't get immediately hidden
            "func", RunMultiBindingElement,
            "binding", binding,
            "subBinding", subBinding,
            "unit", unit,
            "unitFrame", unitFrame
        ))
        compost:Reclaim(display)
    end
    if binding.Data.KeepOpen then
        table.insert(options, compost:AcquireHash(
            "notCheckable", true,
            "disabled", true
        ))
        table.insert(options, compost:AcquireHash(
            "text", colorize("Close Menu", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b),
            "notCheckable", true,
            "keepShownOnClick", true,
            "func", function(self)
                MultiMenu:SetToggleState(false)
            end
        ))
    end
    MultiMenu:SetOptions(options)
    local container = unitFrame:GetRootContainer()
    MultiMenu:SetToggleState(true, container, container:GetWidth(), container:GetHeight())
    MultiMenu:SetKeepOpen(true)
    PlaySound("GAMESPELLBUTTONMOUSEDOWN")
    EndTiming("MultiInit")
end

function RunBinding(binding, unit, unitFrame)
    if binding.Data == nil then
        return
    end
    local targetCastable = UnitExists(unit) and UnitIsConnected(unit) and UnitIsVisible(unit)
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