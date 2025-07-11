PTGuiCheckbox = PTGuiComponent:Extend("checkbox")
PTGuiCheckbox:Import(true, "SetChecked")
PTGuiCheckbox:Import(false, "GetChecked")

function PTGuiCheckbox:New()
    local obj = setmetatable({}, self)
    obj:SetHandle(CreateFrame("CheckButton", self:GenerateName(), nil, "UICheckButtonTemplate"))
    return obj
end

function PTGuiCheckbox:OnDispose()
    self.super.OnDispose(self)

    self:SetChecked(false)
end

PTGuiLib.RegisterComponent(PTGuiCheckbox)