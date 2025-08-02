PTGuiSimpleDialog = PTGuiComponent:Extend("simple_dialog")
local getn = table.getn

function PTGuiSimpleDialog:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    frame:SetWidth(300)
    frame:SetHeight(200)
    frame:EnableMouse(true)
    --frame:SetMovable(true)
    obj:SetHandle(frame)
    obj:SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)
    local title = PTGuiLib.Get("title", frame)
        :SetSize(192, 36)
        :SetPoint("CENTER", frame, "TOP")
    obj:AddComponent("title", title)
    local text = PTGuiLib.Get("text", frame)
        :SetWidth(290)
        :SetPoint("TOP", title, "BOTTOM", 0, -5)
        :SetTextColor(1, 1, 1)
    obj:AddComponent("text", text)
    obj.Buttons = {}
    --[[
    frame:SetScript("OnMouseDown", function()
        local button = arg1

        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function()
        local button = arg1

        if button == "LeftButton" then
            frame:StopMovingOrSizing()
        end
    end)]]
    return obj
end

function PTGuiSimpleDialog:OnAcquire()
    self.super.OnAcquire(self)
    self:SetWidth(300)
    self:SetHeight(200)
end

function PTGuiSimpleDialog:OnDispose()
    self.super.OnDispose(self)

    for _, button in ipairs(self.Buttons) do
        button:Dispose()
    end
    PTUtil.ClearTable(self.Buttons)
end

function PTGuiSimpleDialog:PlayOpenSound()
    PlaySound("igMainMenuOpen")
    return self
end

function PTGuiSimpleDialog:UpdateHeight()
    self:SetScript("OnUpdate", function()
        self:SetScript("OnUpdate", nil)
        if getn(self.Buttons) > 0 then
            local lastButtonBottom = self.Buttons[getn(self.Buttons)]:GetHandle():GetBottom()
            if not lastButtonBottom then
                return
            end
            self:GetHandle():SetHeight(self:GetHandle():GetTop() - lastButtonBottom + 10)
        end
    end, true)
    return self
end

function PTGuiSimpleDialog:SetTitle(text)
    self:GetComponent("title"):SetText(text)
    return self
end

function PTGuiSimpleDialog:SetText(text)
    self:GetComponent("text"):SetText(text)
    return self
end

function PTGuiSimpleDialog:AddButton(text, onClick)
    local anchor = getn(self.Buttons) == 0 and self:GetComponent("text") or self.Buttons[getn(self.Buttons)]
    local button = PTGuiLib.Get("button", self)
        :SetText(text)
        :SetSize(200, 20)
        :SetPoint("TOP", anchor, "BOTTOM", 0, anchor == self:GetComponent("text") and -10 or -5)
        :OnClick(onClick)
    table.insert(self.Buttons, button)
    self:UpdateHeight()
    return self
end

PTGuiLib.RegisterComponent(PTGuiSimpleDialog)