PTGuiTabComponent = PTGuiComponent:Extend("tab_component")

PTGuiTabComponent.TabPosition = "TOP" -- "TOP", "BOTTOM"
PTGuiTabComponent.TabOffsetX = 0
PTGuiTabComponent.TabOffsetY = 0

function PTGuiTabComponent:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj.Tabs = {}
    obj:RegisterSizeListener()
    return obj
end

function PTGuiTabComponent:RegisterSizeListener()
    self:SetScript("OnSizeChanged", function()
        self:PositionTabs()
    end, true)
end

function PTGuiTabComponent:CreateTab(name)
    local tabIndex = self:GetTabCount() + 1
    local tabLabel = "Tab"..tabIndex
    local container = PTGuiContainer:New("$parent"..tabLabel.."Container", self:GetHandle())
    container:SetAllPoints(self:GetHandle())
    container:Hide()
    self:AddComponent(tabLabel, container)
    self:SetPrimary()
    local tab = CreateFrame("Button", "$parent"..tabLabel, self:GetHandle(), self.TabPosition == "TOP" and "TabButtonTemplate" or "CharacterFrameTabButtonTemplate")
    if self.TabPosition == "TOP" then
        tab:SetHeight(22)
    end
    tab:SetText(name)
    tab:RegisterForClicks("LeftButtonUp")

    tab:SetScript("OnClick", function()
        self:SetSelectedTab(tabIndex)
        self:PlayTabSound()
    end)
    local tabInfo = {tab = tab, container = container, name = name}
    table.insert(self.Tabs, tabInfo)
    self:UpdateTabCount()
    PanelTemplates_TabResize(0, tab)
    self:PositionTabs()
    return container
end

function PTGuiTabComponent:GetTabCount()
    return table.getn(self.Tabs)
end

function PTGuiTabComponent:GetTab(indexOrName)
    if type(indexOrName) == "string" then
        for _, tab in ipairs(self.Tabs) do
            if tab.name == indexOrName then
                return tab
            end
        end
    end
    return self.Tabs[indexOrName]
end

-- Returns the GUI instance of the tab container
function PTGuiTabComponent:GetTabContainer(indexOrName)
    return self:GetTab(indexOrName).container
end

-- Returns the Blizzard frame instance of the tab container
function PTGuiTabComponent:GetTabFrame(indexOrName)
    return self:GetTab(indexOrName).container:GetHandle()
end

function PTGuiTabComponent:GetSelectedTab()
    return self:GetTabContainer(PanelTemplates_GetSelectedTab(self:GetHandle()))
end

function PTGuiTabComponent:UpdateTabCount()
    PanelTemplates_SetNumTabs(self:GetHandle(), self:GetTabCount())
    self:SetSelectedTab(1)
end

function PTGuiTabComponent:SetSelectedTab(index)
    PanelTemplates_SetTab(self:GetHandle(), index)
    for i, tab in ipairs(self.Tabs) do
        if i == index then
            tab.container:Show()
        else
            tab.container:Hide()
        end
    end
end

function PTGuiTabComponent:PlayTabSound()
    PlaySoundFile("Sound\\Interface\\uCharacterSheetTab.wav")
end

function PTGuiTabComponent:PositionTabs()
    local space = self:GetWidth() - self.TabOffsetX
    local usedSpace = 0
    local row = 0
    for i, tab in ipairs(self.Tabs) do
        tab = tab.tab
        tab:ClearAllPoints()
        usedSpace = usedSpace + tab:GetWidth()
        if usedSpace < space and row > 0 then
            tab:SetPoint("LEFT", self:GetTab(i - 1).tab, "RIGHT")
        else
            if self.TabPosition == "TOP" then
                tab:SetPoint("TOPLEFT", self:GetHandle(), "TOPLEFT", self.TabOffsetX, self.TabOffsetY + (tab:GetHeight() * (row + 1)))
            else
                tab:SetPoint("TOPLEFT", self:GetHandle(), "BOTTOMLEFT", self.TabOffsetX, self.TabOffsetY - (tab:GetHeight() * row))
            end
            row = row + 1
            usedSpace = tab:GetWidth()
        end
    end
end

function PTGuiTabComponent:SetTabPosition(pos, xOffset, yOffset)
    self.TabPosition = pos
    self.TabOffsetX = xOffset
    self.TabOffsetY = yOffset
end