PTGuiScrollFrame = PTGuiComponent:Extend("scroll_frame")
local _G = getfenv(0)
local util = PTUtil

function PTGuiScrollFrame:New(content)
    local obj = setmetatable({}, self)
    local scrollFrame = CreateFrame("ScrollFrame", self:GenerateName(), nil, "UIPanelScrollFrameTemplate")
    if content then
        content:GetHandle():SetParent(scrollFrame)
    else
        content = PTGuiLib.Get("container", scrollFrame)
    end
    scrollFrame:SetScrollChild(content:GetHandle())
    scrollFrame.scrollBarHideable = 1
    obj:SetHandle(scrollFrame)
    obj:AddComponent("content", content)
    obj:SetPrimary()
    obj:SetupScrollbar()
    obj:SetSimpleBackground()
    obj:UpdateScrollRange()
    return obj
end

-- You better be disposing everything contained in this scroll frame before disposing the frame
function PTGuiScrollFrame:OnDispose()
    self.super.OnDispose(self)
end

function PTGuiScrollFrame:GetContainer()
    return self:GetComponent("content"):GetHandle()
end

function PTGuiScrollFrame:GetAnchor()
    return self:GetComponent("content"):GetHandle()
end

function PTGuiScrollFrame:SetWidth(width)
    self.super.SetWidth(self, width)
    self:GetComponent("content"):SetWidth(width)
    return self
end

function PTGuiScrollFrame:SetHeight(height)
    self.super.SetHeight(self, height)
    self:GetComponent("content"):SetHeight(height)
    return self
end

function PTGuiScrollFrame:UpdateScrollRange()
    util.CallWithThis(self:GetHandle(), ScrollFrame_OnScrollRangeChanged)
    return self
end

function PTGuiScrollFrame:UpdateScrollChildRect()
    self:GetHandle():UpdateScrollChildRect()
    return self
end

-- TODO: Reduce the minimum size and make maximum size infinite
function PTGuiScrollFrame:SetupScrollbar()
    local scrollFrame = self:GetHandle()
    local scrollBar = _G[scrollFrame:GetName().."ScrollBar"]
    local scrollUpButton = _G[scrollBar:GetName().."ScrollUpButton"]
    local scrollDownButton = _G[scrollBar:GetName().."ScrollDownButton"]
    
    local defaultPoints = {}
    for i = 1, scrollBar:GetNumPoints() do
        local a,b,c,d,e = scrollBar:GetPoint(i)
        defaultPoints[i] = {a, b, c, d, e}
    end
    self.defaultScrollbarPoints = defaultPoints

    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, -7, -20)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, -7, 18)

    local backgroundTop = scrollBar:CreateTexture(scrollBar:GetName().."BgTop", "LOW")
    backgroundTop:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    backgroundTop:SetWidth(31)
    backgroundTop:SetHeight(128)
    backgroundTop:SetPoint("BOTTOM", scrollUpButton, "TOP", 0, -128 + 4)
    backgroundTop:SetTexCoord(0, 0.484375, 0, 0.5)

    local backgroundBottom = scrollBar:CreateTexture(scrollBar:GetName().."BottomTop", "LOW")
    backgroundBottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    backgroundBottom:SetWidth(31)
    backgroundBottom:SetHeight(106)
    backgroundBottom:SetPoint("TOP", scrollDownButton, "BOTTOM", 0, 106 - 2)
    backgroundBottom:SetTexCoord(0.515625, 1.0, 0, 0.4140625)

    local backgroundMiddle = scrollBar:CreateTexture(scrollBar:GetName().."BgMiddle", "LOW")
    backgroundMiddle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    backgroundMiddle:SetWidth(31)
    backgroundMiddle:SetPoint("TOP", backgroundTop, "BOTTOM", 0, 0)
    backgroundMiddle:SetTexCoord(0, 0.484375, 0.125, 0.875)
    backgroundMiddle:Hide()

    scrollBar:SetScript("OnSizeChanged", function()
        -- Scrollbar height value is scaled, but the button heights aren't..
        local missingSpace = (scrollBar:GetHeight() / scrollBar:GetEffectiveScale()) + 
            scrollUpButton:GetHeight() + scrollDownButton:GetHeight() + 10 - 
            (backgroundTop:GetHeight() + backgroundBottom:GetHeight())
        if missingSpace > 0 then
            backgroundMiddle:SetHeight(missingSpace)
            backgroundMiddle:SetTexCoord(0, 0.484375, 0.125, 0.125 + (missingSpace / 256))
            backgroundMiddle:Show()
        else
            backgroundMiddle:Hide()
        end
    end)
end

PTGuiLib.RegisterComponent(PTGuiScrollFrame)