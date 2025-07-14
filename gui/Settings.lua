PTSettingsGui = {}
PTUtil.SetEnvironment(PTSettingsGui, PuppeteerSettings)
local util = PTUtil
local compost = AceLibrary("Compost-2.0")
local GetOption = PuppeteerSettings.GetOption
local SetOption = PuppeteerSettings.SetOption

TabFrame = PTGuiLib.Get("tab_frame")--:Hide()

function Init()
    TabFrame:SetPoint("CENTER")
        :SetSize(425, 475)
        :SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)
        :SetSpecial()

    local title = PTGuiLib.Get("title", TabFrame)
    title:SetPoint("TOP", TabFrame, "TOP", 0, 22)
    title:SetHeight(38)
    title:SetWidth(170)
    title:SetText("Puppeteer Settings")

    local closeButton = CreateFrame("Button", nil, TabFrame:GetHandle(), "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", TabFrame:GetHandle(), "TOPRIGHT", 0, 0)
    closeButton:SetScript("OnClick", function() TabFrame:Hide() end)

    TabFrame:CreateTab("Bindings")
    CreateTab_Options()
    TabFrame:CreateTab("Customize")
    CreateTab_About()
end

function CreateTab_Options()
    local container = TabFrame:CreateTab("Options")

    local tabPanel = PTGuiLib.Get("tab_panel", container)
    tabPanel:SetPoint("TOPLEFT", container, "TOPLEFT", 5, -28 - 50)
    tabPanel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -5, 5)
    tabPanel:SetSimpleBackground()

    CreateTab_Options_Casting(tabPanel)
    CreateTab_Options_SpellsTooltip(tabPanel)
    CreateTab_Options_TurtleWoW(tabPanel)
    CreateTab_Options_Other(tabPanel)
    CreateTab_Options_Mods(tabPanel)
end

function CreateTab_Options_Casting(panel)
    local container = panel:CreateTab("Casting")
    local layout = NewLabeledColumnLayout(container, {150, 310}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory

    factory:dropdown("Cast When", "What button state to start casting spells at", "CastWhen", {"Mouse Up", "Mouse Down"}, function()
        for _, ui in ipairs(Puppeteer.AllUnitFrames) do
            ui:RegisterClicks()
        end
    end)
    local resSpell = Puppeteer.ResurrectionSpells[util.GetClass("player")]
    local autoResInfo = not resSpell and "This does nothing for your class" or {"Cast "..resSpell..
        " when clicking on a dead target instead of bound spells", "Special binds, such as \"Target\", can still be used"}
    factory:checkbox("Auto Resurrect", autoResInfo, "AutoResurrect")
    factory:checkbox("Target On Cast", "If enabled, casting a spell on a player will also cause you to target them", "AutoTarget")
end

function CreateTab_Options_SpellsTooltip(panel)
    local container = panel:CreateTab("Spells Tooltip")
    local layout = NewLabeledColumnLayout(container, {150, 310}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory
    factory:checkbox("Enable Spells Tooltip", {"Show the spells tooltip when hovering over unit frames"}, "SpellsTooltip.Enabled")
    factory:checkbox("Show % Mana Cost", {"Show the percent mana cost in the spells tooltip", 
        "Does nothing for non-mana users"}, "SpellsTooltip.ShowManaPercentCost")
    layout:column(2):levelAt(1)
    factory:checkbox("Show # Mana Cost", {"Show the number mana cost in the spells tooltip", 
        "Does nothing for non-mana users"}, "SpellsTooltip.ShowManaCost")
    layout:column(1)
    factory:slider("Hide Casts Above", "Hide cast count if above this threshold", "SpellsTooltip.HideCastsAbove", 0, 20)
    factory:slider("Critical Casts Level", "Show yellow text at this threshold", "SpellsTooltip.CriticalCastsLevel", 0, 20)
    factory:checkbox("Shortened Keys", "Shortens keys to 1 letter", "SpellsTooltip.AbbreviatedKeys")
    layout:column(2):levelAt(1)
    factory:checkbox("Colored Keys", "Color code the keys as opposed to all being white", "SpellsTooltip.ColoredKeys")
    layout:column(1)
    factory:checkbox("Show Power Bar", "Show a power bar in the spells tooltip", "SpellsTooltip.ShowPowerBar", function()
        if PTOptions.SpellsTooltip.ShowPowerBar then
            Puppeteer.SpellsTooltipPowerBar:Show()
        else
            Puppeteer.SpellsTooltipPowerBar:Hide()
        end
    end)
    factory:dropdown("Show Power As", "What type of information to show for power amounts", "SpellsTooltip.ShowPowerAs", 
        {"Power", "Power/Max Power", "Power %"})
    factory:dropdown("Attach To", "What the tooltip should be attached to", "SpellsTooltip.AttachTo", 
        {"Button", "Frame", "Group", "Screen"})
    layout:offset(0, 10)
    factory:dropdown("Anchor", "Where the tooltip should be anchored", "SpellsTooltip.Anchor", 
        {"Top Left", "Top Right", "Bottom Left", "Bottom Right"})
end

function CreateTab_Options_TurtleWoW(panel)
    local container = panel:CreateTab("Turtle WoW")
    local layout = NewLabeledColumnLayout(container, {150, 310}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory
    factory:checkbox("LFT Auto Role", {"Automatically assign roles when joining LFT groups", 
            "This functionality was created for 1.17.2 and may break in future updates"}, "LFTAutoRole",
            function() Puppeteer.SetLFTAutoRoleEnabled(PTOptions.LFTAutoRole) end)
end

function CreateTab_Options_Other(panel)
    local container = panel:CreateTab("Other")
    local layout = NewLabeledColumnLayout(container, {150, 220, 300}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory
    factory:checkbox("Always Show Target", "Always show the target frame, regardless of whether you have a target or not",
        "AlwaysShowTargetFrame", function() Puppeteer.CheckTarget() end)
    layout:offset(0, 10)
    factory:label("Show Targets:")
    layout:column(2):levelAt(1)
    factory:checkbox("Friendly", {"Show the Target frame when targeting friendlies", "No effect if Always Show Target is checked"},
        "ShowTargets.Friendly", function() Puppeteer.CheckTarget() end)
    layout:column(3):levelAt(2)
    factory:checkbox("Hostile", {"Show the Target frame when targeting hostiles", "No effect if Always Show Target is checked"},
        "ShowTargets.Hostile", function() Puppeteer.CheckTarget() end)
    layout:column(1)
    factory:label("Hide Party Frames:")
    layout:column(2):levelAt(1)
    factory:checkbox("In Party", {"Hide default party frames while in party", "This may cause issues with other addons"},
        "DisablePartyFrames.InParty", function() Puppeteer.CheckPartyFramesEnabled() end)
    layout:column(3):levelAt(2)
    factory:checkbox("In Raid", {"Hide default party frames while in raid", "This may cause issues with other addons"},
        "DisablePartyFrames.InRaid", function() Puppeteer.CheckPartyFramesEnabled() end)
    layout:column(1)
    local dragAllCheckbox = factory:checkbox("Drag All Frames", {"If enabled, all frames will be moved when dragging", 
        "Use the inverse key to move a single frame; Opposite effect if disabled"}, "FrameDrag.MoveAll")
    layout:ignoreNext()
    local inverseDropdown = factory:dropdown("Inverse Key", {"This key will be used to do the opposite of the default drag operation"}, 
        "FrameDrag.AltMoveKey", {"Shift", "Control", "Alt"})
    inverseDropdown:SetWidth(80)
    inverseDropdown:SetPoint("LEFT", dragAllCheckbox, "RIGHT", 90, 0)
    factory:checkbox("Show Heal Predictions", {"See predictions on incoming healing", "Improved predictions if using SuperWoW"},
        "UseHealPredictions", function() Puppeteer.UpdateAllIncomingHealing() end)
end

function CreateTab_Options_Mods(panel)
    local container, scrollFrame = panel:CreateTab("Mods", true)
    local layout = NewLabeledColumnLayout(container, {150, 310}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory

    local TEXT_WIDTH = 370

    local generalInfo = CreateLabel(container, "Some client mods can enhance your experience with Puppeteer by unlocking additional functionality.")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", container, "TOP", 0, -10)

    local superWowDetected = util.IsSuperWowPresent()
    local unitXPDetected = util.IsUnitXPSP3Present()
    local nampowerDetected = util.IsNampowerPresent()

    local detectedTexts = {
        [true] = util.Colorize("Mod Detected", 0.2, 1, 0.2),
        [false] = util.Colorize("Mod Not Detected", 1, 0.2, 0.2)
    }
    local superWowLabel = CreateLabel(container, "SuperWoW")
        :SetPoint("TOP", generalInfo, "BOTTOM", 0, -20)
        :SetFontSize(14)
    local superWowDetectedLabel = CreateLabel(container, detectedTexts[superWowDetected])
        :SetPoint("TOP", superWowLabel, "BOTTOM", 0, -5)
        :SetFontSize(10)
        :SetFontFlags("OUTLINE")
    local superWowInfo = CreateLabel(container, "SuperWoW provides the following enhancements:\n\n"..
        "- Enables tracking of many class buff and debuff timers\n"..
        "- Enhances spell casting by directly casting on targets rather than split-second switching tricks\n"..
        "- Allows you to see accurate distance to other friendly players and NPCs\n"..
        "- Mousing over unit frames properly sets your mouseover target\n"..
        "- Shows incoming healing from players that do not have HealComm and predicts more accurate numbers")
        :SetJustifyH("LEFT")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", superWowDetectedLabel, "BOTTOM", 0, -10)
    local superWowLink = CreateLinkEditbox(container, "https://github.com/balakethelock/SuperWoW")
        :SetPoint("TOP", superWowInfo, "BOTTOM", 0, -5)
        :SetSize(300, 20)
    local superWowLinkLabel = CreateLabel(container, "Link:")
        :SetPoint("RIGHT", superWowLink, "LEFT", -5, 0)

    layout:ignoreNext()
    local setMouseoverCheckbox = factory:checkbox("Set Mouseover", {"Requires SuperWoW Mod To Work", 
        "If enabled, hovering over frames will set your mouseover target"}, "SetMouseover")
        :SetPoint("TOP", superWowLink, "BOTTOM", 0, -10)
    if not superWowDetected then
        setMouseoverCheckbox:Disable()
    end

    -- UnitXP SP3

    local unitXPLabel = CreateLabel(container, "UnitXP SP3")
        :SetPoint("TOP", setMouseoverCheckbox, "BOTTOM", 0, -20)
        :SetFontSize(14)
    local unitXPDetectedLabel = CreateLabel(container, detectedTexts[unitXPDetected])
        :SetPoint("TOP", unitXPLabel, "BOTTOM", 0, -5)
        :SetFontSize(10)
        :SetFontFlags("OUTLINE")
    
    local unitXPInfo = CreateLabel(container, "UnitXP SP3 provides the following enhancements:\n\n"..
        "- Allows you to see more accurate distance than SuperWoW and also see distance to enemies\n"..
        "- Displays when units are out of line-of-sight")
        :SetJustifyH("LEFT")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", unitXPDetectedLabel, "BOTTOM", 0, -10)
    local unitXPLink = CreateLinkEditbox(container, "https://github.com/allfoxwy/UnitXP_SP3")
        :SetPoint("TOP", unitXPInfo, "BOTTOM", 0, -5)
        :SetSize(300, 20)
    local unitXPLinkLabel = CreateLabel(container, "Link:")
        :SetPoint("RIGHT", unitXPLink, "LEFT", -5, 0)

    -- Nampower

    local nampowerLabel = CreateLabel(container, "Nampower")
        :SetPoint("TOP", unitXPLink, "BOTTOM", 0, -20)
        :SetFontSize(14)
    local nampowerDetectedLabel = CreateLabel(container, detectedTexts[nampowerDetected])
        :SetPoint("TOP", nampowerLabel, "BOTTOM", 0, -5)
        :SetFontSize(10)
        :SetFontFlags("OUTLINE")
    
    local nampowerInfo = CreateLabel(container, "Nampower provides the following enhancements:\n\n"..
        "- Allows you to queue spell casts like in modern versions of WoW, drastically increasing casting efficiency")
        :SetJustifyH("LEFT")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", nampowerDetectedLabel, "BOTTOM", 0, -10)
    local nampowerLink = CreateLinkEditbox(container, "https://github.com/pepopo978/nampower")
        :SetPoint("TOP", nampowerInfo, "BOTTOM", 0, -5)
        :SetSize(300, 20)
    local nampowerLinkLabel = CreateLabel(container, "Link:")
        :SetPoint("RIGHT", nampowerLink, "LEFT", -5, 0)
    

    
    scrollFrame:UpdateScrollRange()
end

function CreateTab_About()
    local container = TabFrame:CreateTab("About")

    local text = PTGuiLib.GetText(container, 
            "Puppeteer Version "..Puppeteer.VERSION..
            "\n\n\nPuppeteer Author: OldManAlpha\nDiscord: oldmana\nTurtle IGN: Oldmana, Lowall, Jmdruid"..
            "\n\nHealersMate Original Author: i2ichardt\nEmail: rj299@yahoo.com"..
            "\n\nContributers: Turtle WoW Community, ChatGPT"..
            "\n\n\nCheck For Updates, Report Issues, Make Suggestions:\n",
            12)
        :SetPoint("TOP", container, "TOP", 0, -80)

    local site = "https://github.com/OldManAlpha/Puppeteer"
    PTGuiLib.Get("editbox", container)
        :SetText(site)
        :SetPoint("TOP", text, "BOTTOM", 0, -10)
        :SetSize(300, 20)
        :SetJustifyH("CENTER")
        :SetScript("OnTextChanged", function(self)
            self:SetText(site)
        end)
end


-- Factory-related functions

function NewLabeledColumnLayout(container, columns, startY, spacing)
    local layout = {}
    layout.lastAdded = {}
    layout.params = {}
    layout.selectedColumn = 1
    function layout:getNextPoint(columnIndex)
        local offsetX, offsetY = self.params.offsetX or 0, self.params.offsetY or 0
        if self.lastAdded[columnIndex] then
            return "TOPLEFT", self.lastAdded[columnIndex], "BOTTOMLEFT", offsetX, -spacing + offsetY
        end
        return "TOPLEFT", container, "TOPLEFT", columns[columnIndex] + offsetX, startY + offsetY
    end
    function layout:layoutComponent(component)
        if not self.params.ignoreNext then
            local columnIndex = self.selectedColumn or 1
            component:SetPoint(self:getNextPoint(columnIndex))
            self.lastAdded[columnIndex] = component
        end
        util.ClearTable(self.params)
    end
    function layout:column(columnIndex)
        self.selectedColumn = columnIndex
        return self
    end
    function layout:offset(offsetX, offsetY)
        self.params.offsetX = (self.params.offsetX or 0) + offsetX
        self.params.offsetY = (self.params.offsetY or 0) + offsetY
        return self
    end
    function layout:levelAt(columnIndex)
        local lastAdded = self.lastAdded[columnIndex]
        self.lastAdded[self.selectedColumn] = lastAdded
        self:offset(columns[self.selectedColumn] - columns[columnIndex], spacing + lastAdded:GetHeight())
    end
    function layout:setLastAdded(columnIndex, component)
        self.lastAdded[columnIndex] = component
        return self
    end
    function layout:ignoreNext()
        self.params.ignoreNext = true
        return self
    end
    return layout
end

function NewComponentFactory(container, layout)
    return {
        ["layout"] = layout,
        ["doLayout"] = function(self, component)
            if self.layout then
                self.layout:layoutComponent(component)
            end
        end,
        ["checkbox"] = function(self, text, tooltipText, optionLoc, clickFunc)
            local checkbox, label = CreateLabeledCheckbox(container, text, tooltipText)
            self:doLayout(checkbox)
            checkbox:SetScript("OnClick", function(self)
                SetOption(optionLoc, this:GetChecked() == 1)
                if clickFunc then
                    clickFunc(self)
                end
            end)
            checkbox:SetChecked(GetOption(optionLoc))
            return checkbox, label
        end,
        ["dropdown"] = function(self, text, tooltipText, optionLoc, options, selectFunc)
            local dropdown, label = CreateLabeledDropdown(container, text, tooltipText)
            self:doLayout(dropdown)
            local optionsTable = {}
            for _, option in ipairs(options) do
                table.insert(optionsTable, {
                    text = option,
                    dropdownText = option,
                    initFunc = function(self)
                        self.checked = GetOption(optionLoc) == self.text
                    end,
                    func = function(self)
                        SetOption(optionLoc, self.text)
                        if selectFunc then
                            selectFunc(self)
                        end
                    end
                })
            end
            dropdown:SetText(GetOption(optionLoc))
            dropdown:SetOptions(optionsTable)
            return dropdown, label
        end,
        ["slider"] = function(self, text, tooltipText, optionLoc, minValue, maxValue)
            local slider, label = CreateLabeledSlider(container, text, tooltipText)
            slider:SetMinMaxValues(minValue, maxValue)
            slider:SetValue(GetOption(optionLoc))
            slider:GetSlider():SetNumberedText()
            local script = slider:GetSlider():GetScript("OnValueChanged")
            slider:GetSlider():SetScript("OnValueChanged", function(self)
                script()
                SetOption(optionLoc, self:GetValue())
            end)
            self:doLayout(slider)
            return slider, label
        end,
        ["label"] = function(self, text, tooltipText)
            -- Dummy frame
            local frame = PTGuiLib.Get("container", container)
                :SetSize(20, 20)
            local label = CreateLabel(container, text)
                :SetPoint(GetLabelPoint(frame))
            self:doLayout(frame)
            return label, frame
        end
    }
end

function GetLabelPoint(relative)
    return "RIGHT", relative, "LEFT", -5, 0
end

function CreateLabeledCheckbox(parent, text, tooltipText)
    local checkbox = CreateCheckbox(parent)
    local label = CreateLabel(parent, text)
    label:SetPoint(GetLabelPoint(checkbox))
    checkbox:ApplyTooltip(tooltipText)
    label:ApplyTooltip(tooltipText)
    return checkbox, label
end

function CreateLabeledDropdown(parent, text, tooltipText)
    local dropdown = CreateDropdown(parent)
    local label = CreateLabel(parent, text)
    label:SetPoint(GetLabelPoint(dropdown))
    dropdown:ApplyTooltip(tooltipText)
    label:ApplyTooltip(tooltipText)
    return dropdown, label
end

function CreateLabeledSlider(parent, text, tooltipText)
    local slider = CreateSlider(parent)
    local label = CreateLabel(parent, text)
    label:SetPoint(GetLabelPoint(slider))
    slider:ApplyTooltip(tooltipText)
    label:ApplyTooltip(tooltipText)
    return slider, label
end

function CreateLinkEditbox(parent, site)
    return PTGuiLib.Get("editbox", parent)
        :SetText(site)
        :SetJustifyH("CENTER")
        :SetScript("OnTextChanged", function(self)
            self:SetText(site)
        end)
end

function CreateDropdown(parent, width)
    return PTGuiLib.Get("dropdown", parent)
        :SetSize(width or 140, 25)
end

function CreateSlider(parent, width, height)
    return PTGuiLib.Get("editbox_slider", parent)
        :SetSize(width or 160, height or 36)
end

function CreateCheckbox(parent, width, height)
    return PTGuiLib.Get("checkbox", parent)
        :SetSize(width or 20, height or 20)
end

function CreateLabel(parent, text)
    return PTGuiLib.GetText(parent, text)
end