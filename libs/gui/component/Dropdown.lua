-- This can either be used as a normal dropdown or a context menu. If the parent is UIParent, it will be a context menu.
-- Otherwise, it is a dropdown. This can be changed during runtime simply by calling SetParent through the GUI component.
-- The positioning of the dropdown's components are modified to behave like you'd expect. SetWidth actually sets the width.
-- SetHeight does nothing, and will always be 25 px.

-- Initialization is handled by this component. Use SetOptions to set the options table.
-- === New Fields ===
-- initFunc(self, gui) - Runs on level initialization before the button is added
-- dropdownText - The text the dropdown will be set to when this option is clicked, runs before "func"
-- closeOnClick - If true, closes all menus regardless of level, runs after "func"
-- children - Array for a next level menu; If present, "hasArrow" is automatically set to true
-- parent [Automatically Assigned] - Reference to the previous level element, or nil if root
-- siblings [Automatically Assigned] - Reference to the array of elements in the level
-- gui [Automatically Assigned] - Reference to the GUI instance
-- === Adjusted Existing Fields ===
-- func(self, gui) - Always passes self as the first argument and the GUI instance as the second argument
-- arg1, arg2 - Do not use, now internally used to pass self and gui to "func"
-- value - Do not use, now internally used to reference self

PTGuiDropdown = PTGuiComponent:Extend("dropdown")
local _G = getfenv(0)

PTGuiDropdown.Options = nil

function PTGuiDropdown:New()
    local obj = setmetatable({}, self)
    local dropdown = CreateFrame("Frame", self:GenerateName(), nil, "UIDropDownMenuTemplate")
    -- Make positioning behave like you'd think
    local left = _G[dropdown:GetName().."Left"]
    local a,b,c,d,e = left:GetPoint(1)
    left:ClearAllPoints()
    left:SetPoint(a,b,c, -18, e + 1)
    -- Make SetWidth actually set the width, like one would hope
    local dropdownSetWidth = dropdown.SetWidth
    dropdown.SetWidth = function(self, width)
        _G[dropdown:GetName().."Middle"]:SetWidth(width - 15)
        dropdownSetWidth(self, width)
        _G[dropdown:GetName().."Text"]:SetWidth(width - 25)
        dropdown.noResize = 1
    end
    -- The dropdown doesn't stretch vertically, so the height is always 25
    local dropdownSetHeight = dropdown.SetHeight
    dropdown.SetHeight = function(self, height)
        dropdownSetHeight(self, 25)
    end
    -- Make clicking anywhere on the dropdown open the menu
    dropdown:EnableMouse(true)
    dropdown:SetScript("OnMouseUp", function()
        if MouseIsOver(this) then
            PTUtil.CallWithThis(_G[this:GetName().."Button"], _G[this:GetName().."Button"]:GetScript("OnClick"))
        end
    end)
    obj:SetHandle(dropdown)
    return obj
end

local recordedTextures = {"ButtonNormalTexture", "ButtonDisabledTexture", "ButtonPushedTexture", "ButtonHighlightTexture"}
function PTGuiDropdown:SetParent(obj)
    local menuType = obj == UIParent and "MENU" or nil
    if menuType == "MENU" and not self.guiSavedProps then
        -- If this is becoming a context menu, we need to save the current button properties so that we can 
        -- restore them if this becomes a dropdown menu again
        local frameName = self:GetHandle():GetName()
        local savedProps = {}
        for _, tex in ipairs(recordedTextures) do
            savedProps[tex] = _G[frameName..tex]:GetTexture()
        end
        local button = _G[frameName.."Button"]
        local buttonPoints = {}
        for i = 1, button:GetNumPoints() do
            local a,b,c,d,e = button:GetPoint(i)
            buttonPoints[i] = {a,b,c,d,e}
        end
        savedProps["ButtonPoints"] = buttonPoints
        self.guiSavedProps = savedProps
    elseif menuType ~= "MENU" and self.guiSavedProps then
        -- Restore the properties if we're switching from a context menu to a dropdown
        local frameName = self:GetHandle():GetName()
        local savedProps = self.guiSavedProps
        _G[frameName.."Left"]:Show()
		_G[frameName.."Middle"]:Show()
		_G[frameName.."Right"]:Show()
        for _, tex in ipairs(recordedTextures) do
            _G[frameName..tex]:SetTexture(savedProps[tex])
        end
        local button = _G[frameName.."Button"]
		button:ClearAllPoints();
        for _, pt in ipairs(savedProps.ButtonPoints) do
            _G[frameName.."Button"]:SetPoint(unpack(pt))
        end
        self:GetHandle().displayMode = nil

        self.guiSavedProps = nil
    end
    UIDropDownMenu_Initialize(self:GetHandle(), function(level)
        self:Initialize(level)
    end, menuType)
    self.super.SetParent(self, obj)
end

function PTGuiDropdown:OnDispose()
    self:SetToggleState(false)
    self.super.OnDispose(self)

    self.Options = nil
    self:SetText("")
end

function PTGuiDropdown:Initialize(level)
    if not self.Options then
        return
    end
    level = level or 1
    local value = UIDROPDOWNMENU_MENU_VALUE
    local options = level == 1 and self.Options or value.children
    for _, option in ipairs(options) do
        if option.initFunc then
            option:initFunc(self)
        end
        UIDropDownMenu_AddButton(option, level)
    end
end

-- Sets the options for this dropdown. If elements are added afterwards, it is mandatory that this function is called again.
function PTGuiDropdown:SetOptions(options)
    self.Options = options
    self:BakeOptions(options)
    return self
end

function PTGuiDropdown:BakeOptions(options, parent)
    for _, opt in ipairs(options) do
        opt.parent = parent
        opt.siblings = options
        opt.value = opt
        opt.arg1 = opt
        opt.arg2 = self
        opt.gui = self
        if opt.dropdownText or opt.closeOnClick then
            local func = opt.func
            opt.func = function(self, gui)
                if self.dropdownText then
                    gui:SetText(self.dropdownText)
                end
                if func then
                    func(self, gui)
                end
                if self.closeOnClick then
                    gui:SetToggleState(false)
                end
            end
        end
        if opt.children then
            opt.hasArrow = true
            self:BakeOptions(opt.children, opt)
        end
    end
end

function PTGuiDropdown:SetText(text)
    UIDropDownMenu_SetText(text, self:GetHandle())
    return self
end

function PTGuiDropdown:GetText()
    return UIDropDownMenu_GetText(self:GetHandle())
end

function PTGuiDropdown:IsToggledOn()
    return (_G["DropDownList1"]:IsVisible() ~= nil) and (UIDROPDOWNMENU_OPEN_MENU == self:GetName())
end

function PTGuiDropdown:SetToggleState(shown, anchor, xOffset, yOffset)
    if self:IsToggledOn() ~= shown then
        ToggleDropDownMenu(1, nil, self:GetHandle(), anchor and anchor:GetName() or nil, xOffset, yOffset)
    end
end

PTGuiLib.RegisterComponent(PTGuiDropdown)