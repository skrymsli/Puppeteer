PTUnitFrameGroup = {}
PTUtil.SetEnvironment(PTUnitFrameGroup)
PTUnitFrameGroup.__index = PTUnitFrameGroup
local _G = getfenv(0)
local PT = Puppeteer
local util = PTUtil

PTUnitFrameGroup.name = "???"
PTUnitFrameGroup.raidmana = "??"
PTUnitFrameGroup.healermana = "??"

PTUnitFrameGroup.profile = nil

PTUnitFrameGroup.container = nil
PTUnitFrameGroup.borderFrame = nil
PTUnitFrameGroup.header = nil
PTUnitFrameGroup.label = nil
PTUnitFrameGroup.manalabel = nil
PTUnitFrameGroup.healermanalabel = nil
PTUnitFrameGroup.reportManaButton = nil
PTUnitFrameGroup.uis = nil
PTUnitFrameGroup.units = nil

PTUnitFrameGroup.petGroup = false
PTUnitFrameGroup.environment = "all" -- party, raid, or all
PTUnitFrameGroup.sortByRole = true

PTUnitFrameGroup.moveContainer = CreateFrame("Frame", "PTUnitFrameGroupBulkMoveContainer", UIParent)
PTUnitFrameGroup.moveContainer:EnableMouse(true)
PTUnitFrameGroup.moveContainer:SetMovable(true)

ContextMenu = PTGuiLib.Get("dropdown", UIParent)
ContextMenu:SetDynamicOptions(function(addOption, level, args)
    addOption("text", "Lock Position",
        "func", function(self, gui)
            PuppeteerSettings.SetFrameLocked(gui.FrameGroup.name, not self.checked)
        end,
        "initFunc", function(self, gui)
            self.checked = PuppeteerSettings.IsFrameLocked(gui.FrameGroup.name)
        end)

    addOption("notCheckable", true,
        "disabled", true)

    addOption("text", "Open Settings",
        "notCheckable", true,
        "func", function(self, gui)
            PTSettingsGui.TabFrame:Show()
        end)
end)

function PTUnitFrameGroup:New(name, environment, units, petGroup, profile, sortByRole)
    local obj = setmetatable({name = name, environment = environment, uis = {}, units = units, petGroup = petGroup, 
        profile = profile, sortByRole = sortByRole}, self)
    obj:Initialize()
    return obj
end

function PTUnitFrameGroup:EvaluateShown()
    if self:CanShowInEnvironment(Puppeteer.CurrentlyInRaid and "raid" or "party") and self:ShowCondition() then
        self:Show()
        self:UpdateUIPositions()
    else
        self:Hide()
    end
end

function PTUnitFrameGroup:ShowCondition()
    if PTOptions.Hidden or PuppeteerSettings.IsFrameHidden(self.name) then
        return false
    end

    if PTOptions.HideWhileSolo and (GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0) then
        return false
    end

    for _, ui in pairs(self.uis) do
        if ui:IsShown() then
            return true
        end
    end
    return false
 end

function PTUnitFrameGroup:AddUI(ui, noUpdate)
    self.uis[ui:GetUnit()] = ui
    ui:SetOwningGroup(self)
    if not noUpdate then
        self:UpdateUIPositions()
    end
end

function PTUnitFrameGroup:GetContainer()
    return self.container
end

function PTUnitFrameGroup:ResetFrameLevel()
    self.container:SetFrameLevel(0)
    self.borderFrame:SetFrameLevel(1)
end

function PTUnitFrameGroup:GetEnvironment()
    return self.environment
end

function PTUnitFrameGroup:CanShowInEnvironment(environment)
    return self.environment == "all" or self.environment == environment
end

function PTUnitFrameGroup:Show()
    self.container:Show()
    for _, ui in pairs(self.uis) do
        ui:UpdateAll()
    end
    self:UpdateReportManaButton()
    self:UpdateRaidMana()
end

function PTUnitFrameGroup:UpdateRaidMana()
    if self.name ~= "Raid" then
        return
    end
    if not PTOptions.ShowRaidMana then
        self.raidmana = ""
        self.healermana = ""
        self:SetFrameTitle()
        self:UpdateReportManaButton()
        return
    end
    local totalManaPct = 0
    local totalManaUnits = 0
    local healerManaPct = 0
    local healerManaUnits = 0
    for _, ui in pairs(self.uis) do
        if ui:IsShown() and UnitIsConnected(ui:GetUnit()) then
            local powerType, _, _, _, _ = UnitPowerType(ui:GetUnit())
            if powerType == 0 then -- Mana
                local mana = ui:GetCurrentPower()
                local manaMax = ui:GetMaxPower()
                local manaPct = manaMax > 0 and ((mana / manaMax) * 100) or 0
                totalManaPct = manaPct + totalManaPct
                totalManaUnits = totalManaUnits + 1
                if ui:GetRole() == "Healer" then
                    healerManaPct = manaPct + healerManaPct
                    healerManaUnits = healerManaUnits + 1
                end
            end
        end
    end
    if totalManaUnits > 0 then
        self.raidmana = string.format("%d%%", math.floor((totalManaPct / totalManaUnits)))
    else
        self.raidmana = ""
    end
    if healerManaUnits > 0 then
        self.healermana = string.format("%d%%", math.floor((healerManaPct / healerManaUnits)))
    else
        self.healermana = ""
    end

    self:UpdateReportManaButton()
    self:SetFrameTitle()
end

function PTUnitFrameGroup:ReportRaidMana()
    if not UnitInRaid("player") or not (IsRaidLeader() or IsRaidOfficer()) then
        return
    end

    if self.raidmana == "" then
        DEFAULT_CHAT_FRAME:AddMessage("No mana users in raid.")
        return
    end

    local msg = "Raid Mana: ".. self.raidmana
    if self.healermana ~= "" then
        msg = msg .. " || Healer Mana: " .. self.healermana
    end
    SendChatMessage(msg, "RAID_WARNING", nil, nil);
end

function PTUnitFrameGroup:Hide()
    self.container:Hide()
end

-- Used while moving frames to avoid the lag while moving over other toplevel frames
function PTUnitFrameGroup:RemoveToplevel()
    self.container:SetToplevel(false)
    self.container:SetFrameStrata("HIGH")
end

function PTUnitFrameGroup:ApplyToplevel()
    self.container:SetToplevel(true)
    self.container:SetFrameStrata("MEDIUM")
end

function PTUnitFrameGroup:UpdateHeaderColor()
    local opacity = PuppeteerSettings.IsFrameLocked(self.name) and 0.1 or 0.5
    self.header:SetBackdropColor(0, 0, 0, opacity)
end

function PTUnitFrameGroup:Initialize()
    local container = CreateFrame("Frame", "PTUnitFrameGroupContainer_"..self.name, UIParent)
    self.container = container
    container:EnableMouse(true)
    container:SetMovable(true)
    container:SetUserPlaced(false)
    self:ApplyToplevel()
    container:ClearAllPoints()
    local anchor, x, y = PuppeteerSettings.GetFramePosition(self.name)
    container:SetPoint(anchor or "TOPLEFT", UIParent, "TOPLEFT", x or 100, y or -100)
    container:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    container:SetBackdropColor(0, 0, 0, self:GetProfile().BackgroundOpacity / 100)

    container:SetScript("OnMouseDown", function()
        local button = arg1

        if button ~= "LeftButton" or container.isMoving then
            return
        end

        if PuppeteerSettings.IsFrameLocked(self.name) then
            return
        end

        container.isMoving = true

        if (util.GetKeyModifier() == PTOptions.FrameDrag.AltMoveKey) == PTOptions.FrameDrag.MoveAll then
            container:StartMoving()
            container:SetUserPlaced(false) -- StartMoving sets this and needs to be reverted
            self:RemoveToplevel()
            return
        end

        container.bulkMovement = true

        local moveContainer = PTUnitFrameGroup.moveContainer
        moveContainer:ClearAllPoints()
        moveContainer:SetPoint("TOPLEFT", 0, 0)
        -- If the container doesn't have a size, it doesn't move
        moveContainer:SetWidth(1)
        moveContainer:SetHeight(1)
        local movingGroups = {}
        for _, group in pairs(Puppeteer.UnitFrameGroups) do
            if not PuppeteerSettings.IsFrameLocked(group.name) and group:GetContainer():IsVisible() then
                group:RemoveToplevel()
                local gc = group:GetContainer()
                local xOffset = gc:GetLeft()
                local yOffset = gc:GetTop() - GetScreenHeight()
                gc:ClearAllPoints()
                gc:SetPoint("TOPLEFT", moveContainer, "TOPLEFT", xOffset, yOffset)
                table.insert(movingGroups, group)
            end
        end
        moveContainer.groups = movingGroups
        moveContainer:StartMoving()
    end)

    container:SetScript("OnMouseUp", function()
        local button = arg1

        if button == "RightButton" and MouseIsOver(self.header) and self.header:IsVisible() then
            ContextMenu.FrameGroup = self
            ContextMenu:SetToggleState(false)
            ContextMenu:SetToggleState(true, container, container:GetWidth(), container:GetHeight())
            PlaySound("igMainMenuOpen")
            return
        end

        if (button ~= "LeftButton" or not container.isMoving) then
            return
        end

        container.isMoving = false

        if not container.bulkMovement then
            container:StopMovingOrSizing()
            self:ApplyToplevel()
            util.ConvertAnchor(container, PuppeteerSettings.GetFramePosition(self.name))
            return
        end

        container.bulkMovement = false

        local moveContainer = PTUnitFrameGroup.moveContainer
        moveContainer:StopMovingOrSizing()
        for _, group in pairs(moveContainer.groups) do
            group:ApplyToplevel()
            local gc = group:GetContainer()
            util.ConvertAnchor(gc, PuppeteerSettings.GetFramePosition(group.name))
        end
        -- Prevent container from potentially blocking mouse by setting it back to 0 size
        moveContainer:SetWidth(0)
        moveContainer:SetHeight(0)
    end)

    container:SetScript("OnHide", function()
        if not container.isMoving then
            return
        end
        local prevArg = arg1
        arg1 = "LeftButton"
        container:GetScript("OnMouseUp")()
        arg1 = prevArg
    end)

    local header = CreateFrame("Frame", "$parentHeader", container)
    self.header = header
    header:SetPoint("TOPLEFT", container, 0, 0)
    header:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"})
    self:UpdateHeaderColor()

    local label = header:CreateFontString(header, "OVERLAY", "GameFontNormal")
    self.label = label
    label:SetPoint("CENTER", header, "CENTER", 0, 0)
    


    local mana = header:CreateFontString(header, "OVERLAY", "GameFontNormal")
    self.manalabel = mana
    mana:SetTextColor(0, 0.7, 1, 1)

    local healerMana = header:CreateFontString(header, "OVERLAY", "GameFontNormal")
    self.healermanalabel = healerMana
    healerMana:SetTextColor(0.2, 1, 0.4, 1)

    local reportBtn = CreateFrame("Button", "$parentReportMana", header)
    self.reportManaButton = reportBtn
    reportBtn:SetWidth(16)
    reportBtn:SetHeight(16)
    reportBtn:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    reportBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    reportBtn:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    reportBtn:GetHighlightTexture():SetAlpha(0.3)
    reportBtn:SetScript("OnClick", function()
        self:ReportRaidMana()
    end)
    reportBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(reportBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Report raid & healer mana")
        GameTooltip:Show()
    end)
    reportBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    reportBtn:Hide()

    self:SetFrameTitle()

    local borderFrame = CreateFrame("Frame", "$parentBorder", container)
    self.borderFrame = borderFrame
    borderFrame:SetPoint("CENTER", container, 0, 0)

    self:ApplyProfile()
end

function PTUnitFrameGroup:UpdateManaLabelLayout(headerWidth)
    if self.name ~= "Raid" then
        return
    end
    local hasButton = self.reportManaButton:IsShown()
    local btnSpace = hasButton and 20 or 0
    local totalWidth = headerWidth or self.header:GetWidth()
    local availableWidth = totalWidth - btnSpace - 4
    local fontSize = 12
    if self.healermana ~= "" then
        -- Two labels sharing space need more aggressive sizing
        if availableWidth < 90 then
            fontSize = 8
        elseif availableWidth < 130 then
            fontSize = 9
        elseif availableWidth < 170 then
            fontSize = 10
        end
    else
        if availableWidth < 60 then
            fontSize = 9
        end
    end
    self.manalabel:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
    self.healermanalabel:SetFont("Fonts\\FRIZQT__.TTF", fontSize)

    self.manalabel:ClearAllPoints()
    self.healermanalabel:ClearAllPoints()
    if self.healermana ~= "" then
        local halfWidth = (availableWidth - 4) / 2
        self.manalabel:SetWidth(halfWidth)
        self.healermanalabel:SetWidth(halfWidth)
        self.manalabel:SetPoint("LEFT", self.header, "LEFT", 2, 0)
        self.healermanalabel:SetPoint("RIGHT", self.header, "RIGHT", -btnSpace - 2, 0)
    else
        self.manalabel:SetWidth(availableWidth)
        self.manalabel:SetPoint("CENTER", self.header, "CENTER", -btnSpace / 2, 0)
    end
end

function PTUnitFrameGroup:UpdateReportManaButton()
    if self.name ~= "Raid" or not self.reportManaButton then
        return
    end
    if UnitInRaid("player") and (IsRaidLeader() or IsRaidOfficer()) and PTOptions.ShowRaidMana then
        self.reportManaButton:Show()
    else
        self.reportManaButton:Hide()
    end
end

function PTUnitFrameGroup:UpdateManaLabels()
    if self.name ~= "Raid" or not PTOptions.ShowRaidMana then
        return
    end
    local hasButton = self.reportManaButton and self.reportManaButton:IsShown()
    local btnSpace = hasButton and 20 or 0
    local availableWidth = self.header:GetWidth() - btnSpace - 4
    if self.healermana ~= "" then
        if availableWidth >= 280 then
            self.manalabel:SetText("Raid: "..self.raidmana)
            self.healermanalabel:SetText("Heal: "..self.healermana)
        elseif availableWidth >= 130 then
            self.manalabel:SetText("R:"..self.raidmana)
            self.healermanalabel:SetText("H:"..self.healermana)
        elseif availableWidth >= 80 then
            self.manalabel:SetText(self.raidmana)
            self.healermanalabel:SetText(self.healermana)
        else
            -- Strip % to fit in very narrow headers
            local r = string.gsub(self.raidmana, "%%", "")
            local h = string.gsub(self.healermana, "%%", "")
            self.manalabel:SetText(r)
            self.healermanalabel:SetText(h)
        end
    else
        if availableWidth >= 200 then
            self.manalabel:SetText("Raid: "..self.raidmana)
        else
            self.manalabel:SetText(self.raidmana)
        end
        self.healermanalabel:SetText("")
    end
    self:UpdateManaLabelLayout()
end

function PTUnitFrameGroup:SetFrameTitle()
    if(self.name == "Raid") then
        if PTOptions.ShowRaidMana then
            self.label:SetText("")
            self:UpdateManaLabels()
        else
            self.label:SetText("Raid")
            self.manalabel:SetText("")
            self.healermanalabel:SetText("")
        end
    else
        self.label:SetText(self.name)
        self.manalabel:SetText("")
        self.healermanalabel:SetText("")
    end
end

function PTUnitFrameGroup:ApplyProfile()
    local profile = self:GetProfile()
    
    local borderFrame = self.borderFrame
    if profile.BorderStyle == "Tooltip" then
        borderFrame:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 17, 
            tile = true, tileSize = 17})
    elseif profile.BorderStyle == "Dialog Box" then
        borderFrame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, 
            tile = true, tileSize = 24})
    else
        borderFrame:SetBackdrop({})
    end
end

function PTUnitFrameGroup:UpdateUIPositions()
    local profile = self:GetProfile()
    local profileWidth = profile.Width
    local profileHeight = profile:GetHeight()
    local maxUnitsInAxis = profile.MaxUnitsInAxis
    local orientation = profile.Orientation
    local headerEnabled = not PuppeteerSettings.IsTitleHidden(self.name)
    local headerHeight = headerEnabled and 20 or 0

    local sortedUIs = self:GetSortedUIs()
    local splitSortedUIs = {}
    for _, group in ipairs(sortedUIs) do
        local currentTable = {}
        local unitsUntilShift = maxUnitsInAxis
        for _, ui in ipairs(group) do
            if unitsUntilShift == 0 then
                table.insert(splitSortedUIs, currentTable)
                currentTable = {}
                unitsUntilShift = maxUnitsInAxis
            end
            table.insert(currentTable, ui)
            unitsUntilShift = unitsUntilShift - 1
        end
        if table.getn(currentTable) > 0 then
            table.insert(splitSortedUIs, currentTable)
        end
    end

    -- IMPORTANT: "Column" does not necessarily mean vertical!
    local largestColumn = orientation == "Vertical" and profile.MinUnitsY or profile.MinUnitsX
    for _, column in ipairs(splitSortedUIs) do
        largestColumn = math.max(largestColumn, table.getn(column))
    end

    local xSpacing = profile.HorizontalSpacing
    local ySpacing = profile.VerticalSpacing
    for columnIndex, column in ipairs(splitSortedUIs) do
        for i, ui in ipairs(column) do -- Column is guaranteed to be less than max units
            local container = ui:GetRootContainer()
            local x = orientation == "Vertical" and ((profileWidth + xSpacing) * (columnIndex - 1)) or ((profileWidth + xSpacing) * (i - 1))
            local y = orientation == "Vertical" and ((profileHeight + ySpacing) * (i - 1)) or ((profileHeight + ySpacing) * (columnIndex - 1))
            container:SetPoint("TOPLEFT", self.container, "TOPLEFT", x, -y - headerHeight)
        end
    end

    local largestRow = math.max(table.getn(splitSortedUIs), orientation == "Vertical" and profile.MinUnitsX or profile.MinUnitsY)

    
    --largestRow = math.max(largestRow, 1)
    --largestColumn = math.max(largestColumn, 1)

    local width = orientation == "Vertical" and (profileWidth * largestRow + (xSpacing * (largestRow - 1))) or (profileWidth * largestColumn + (xSpacing * (largestColumn - 1)))
    width = math.max(width, profileWidth) -- Prevent width from being 0
    local height = orientation == "Vertical" and (profileHeight * largestColumn + (ySpacing * (largestColumn - 1))) or (profileHeight * largestRow + (ySpacing * (largestRow - 1)))
    height = height + headerHeight
    self.container:SetWidth(width)
    self.container:SetHeight(height)

    local header = self.header
    if headerEnabled then
        header:Show()
        header:SetWidth(width)
        header:SetHeight(headerHeight)
    else
        header:Hide()
    end

    local borderPadding = 0
    if profile.BorderStyle == "Tooltip" then
        borderPadding = 10
    elseif profile.BorderStyle == "Dialog Box" then
        borderPadding = 18
    end
    self.borderFrame:SetWidth(width + borderPadding)
    self.borderFrame:SetHeight(height + borderPadding)

    local label = self.label
    label:SetPoint("CENTER", header, "CENTER", 0, 0)

    self:UpdateManaLabels()
end

-- Returns an array with the index being the group number, and the value being an array of units
function PTUnitFrameGroup:GetSortedUIs()
    local profile = self:GetProfile()
    local uis = self.uis
    local groups = {}
    
    if self.environment == "raid" and profile.SplitRaidIntoGroups and not self.petGroup then
        for i = 1, 8 do
            groups[i] = {}
        end
        local raidUnits = PTUtil.RaidUnits
        local numRaidMembers = GetNumRaidMembers()
        for i = 1, numRaidMembers do
            local _, _, subgroup = GetRaidRosterInfo(i)
            local group = groups[subgroup]
            table.insert(group, uis[raidUnits[i]])
        end
        -- If testing, fill empty slots with fake players
        if Puppeteer.TestUI then
            for groupNumber = 1, 8 do
                local group = groups[groupNumber]
                for frameNumber = 1, 5 do
                    if not group[frameNumber] then
                        numRaidMembers = numRaidMembers + 1
                        table.insert(group, uis[raidUnits[numRaidMembers]])
                    end
                end
            end
        end
    else
        groups[1] = {}
        local group = groups[1]
        for _, ui in pairs(uis) do
            if ui:IsShown() then
                table.insert(group, ui)
            end
        end
    end

    local sortedGroups = {}
    if profile.SortUnitsBy == "ID" then
        for groupNumber, group in ipairs(groups) do
            if table.getn(group) > 0 then
                local groupSet = {} -- Convert group UI array to a set with the key as the Unit ID
                for _, ui in ipairs(group) do
                    groupSet[ui:GetUnit()] = ui
                end
                if self.environment == "raid" then
                    if not self.petGroup then -- Should already be sorted if we're not dealing with the pets
                        table.insert(sortedGroups, group)
                    else -- Pets need to be sorted manually
                        local sortedGroup = {}
                        for _, unit in ipairs(self.units) do -- Iterate through all unit IDs this UI group can handle, in order
                            if groupSet[unit] then
                                table.insert(sortedGroup, groupSet[unit])
                            end
                        end
                        table.insert(sortedGroups, sortedGroup)
                    end
                else
                    local sortedGroup = {}
                    for _, unit in ipairs(self.units) do -- Iterate through all unit IDs this UI group can handle, in order
                        if groupSet[unit] then
                            table.insert(sortedGroup, groupSet[unit])
                        end
                    end
                    table.insert(sortedGroups, sortedGroup)
                end
            end
        end
    elseif profile.SortUnitsBy == "Name" then
        for groupNumber, group in ipairs(groups) do
            if table.getn(group) > 0 then
                table.sort(group, function(a, b)
                    local aName = UnitName(a:GetUnit()) or a.fakeStats.name or a:GetUnit()
                    local bName = UnitName(b:GetUnit()) or b.fakeStats.name or b:GetUnit()
                    return aName < bName
                end)
                table.insert(sortedGroups, group)
            end
        end
    elseif profile.SortUnitsBy == "Class Name" then
        for groupNumber, group in ipairs(groups) do
            if table.getn(group) > 0 then
                table.sort(group, function(a, b)
                    local aName = util.GetClass(a:GetUnit()) or a.fakeStats.class
                    local bName = util.GetClass(b:GetUnit()) or b.fakeStats.class
                    return aName < bName
                end)
                table.insert(sortedGroups, group)
            end
        end
    end
    local sortByRole = self.sortByRole
    for _, group in ipairs(sortedGroups) do
        if sortByRole then
            local rolePriority = {
                ["Tank"] = 1,
                ["Healer"] = 2,
                ["Damage"] = 3
            }
            local groupCopy = util.CloneTable(group)
            local roleSorter = function(a, b)
                if not a or not b then
                    return false
                end
                local aRank = ((rolePriority[a:GetRole()] or 4) * 1000) + util.IndexOf(groupCopy, a) + 
                    (UnitIsUnit("player", a:GetUnit()) and 0 or 100) + (UnitIsUnit("pet", a:GetUnit()) and 0 or 99)
                local bRank = ((rolePriority[b:GetRole()] or 4) * 1000) + util.IndexOf(groupCopy, b) + 
                    (UnitIsUnit("player", b:GetUnit()) and 0 or 100) + (UnitIsUnit("pet", b:GetUnit()) and 0 or 99)
                return aRank < bRank
            end
            table.sort(group, roleSorter)
        end
        for _, ui in ipairs(group) do
            ui:UpdateRole()
        end
    end
    return sortedGroups
end

function PTUnitFrameGroup:GetProfile()
    return self.profile
end