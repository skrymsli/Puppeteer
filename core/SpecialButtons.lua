-- Handles mouse wheel and key bindings

PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local util = PTUtil

_G.BINDING_HEADER_PUPPETEER = "Puppeteer"
local bindingsNames = {}
for i = 1, 10 do
    bindingsNames[i] = "PUPPETEERBINDING"..i
    _G["BINDING_NAME_"..bindingsNames[i]] = "Dynamic Binding "..i
end

local BindingPrefixes = {
    "",
    "SHIFT-",
    "CTRL-",
    "ALT-",
    "ALT-CTRL-SHIFT-",
    "ALT-CTRL-",
    "ALT-SHIFT-",
    "CTRL-SHIFT-"
}

StoredBindings = {} -- Key: Baked keybind key(like "ALT-SHIFT-R") | Value: The stored value of the binding
IndexButtonMap = {} -- Key: Index corresponding to the binding | Value: Button name
KeybindIndexMap = {} -- Key: Baked keybind key | Value: Index corresponding to the binding

function SetupSpecialButtons()
    util.ClearTable(IndexButtonMap)
    util.ClearTable(KeybindIndexMap)
    local index = 1
    for _, button in ipairs(PTOptions.Buttons) do
        if not util.ArrayContains(util.GetAllButtons(), button) then
            for _, prefix in ipairs(BindingPrefixes) do
                KeybindIndexMap[prefix..button] = index
            end
            IndexButtonMap[index] = button
            index = index + 1
        end
    end
end

function ApplyOverrideBindings()
    for fullButton, index in pairs(KeybindIndexMap) do
        local binding = GetBindingAction(fullButton)
        StoredBindings[fullButton] = binding
        SetBinding(fullButton, bindingsNames[index])
    end
end

function RemoveOverrideBindings()
    for button, binding in pairs(StoredBindings) do
        SetBinding(button, binding)
    end
    util.ClearTable(StoredBindings)
end

function HandleKeyPress(index)
    local button = IndexButtonMap[index]
    if keystate == "down" then
        CurrentlyHeldButton = button
        if button == "MOUSEWHEELUP" or button == "MOUSEWHEELDOWN" then
            FakeMouseWheelHold(button)
        end
        ReapplySpellsTooltip()
        if PTOptions.CastWhen == "Mouse Down" then
            UnitFrame_OnClick(button, Mouseover, MouseoverFrame)
        end
    else
        if button ~= "MOUSEWHEELUP" and button ~= "MOUSEWHEELDOWN" then
            CurrentlyHeldButton = nil
            ReapplySpellsTooltip()
        end
        if PTOptions.CastWhen == "Mouse Up" then
            UnitFrame_OnClick(button, Mouseover, MouseoverFrame)
        end
    end
end

MouseWheelHeldFaker = CreateFrame("Frame", "PTMouseWheelHeldFaker")

local unholdAt
local unholdButton
local MouseWheelHeldFaker_OnUpdate = function()
    if GetTime() >= unholdAt then
        MouseWheelHeldFaker:SetScript("OnUpdate", nil)
        if CurrentlyHeldButton == unholdButton then
            CurrentlyHeldButton = nil
            ReapplySpellsTooltip()
        end
    end
end
function FakeMouseWheelHold(button)
    unholdAt = GetTime() + 0.08
    unholdButton = button
    MouseWheelHeldFaker:SetScript("OnUpdate", MouseWheelHeldFaker_OnUpdate)
end