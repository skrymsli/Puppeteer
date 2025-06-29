SLASH_PUPPETEER1 = "/puppeteer"
SLASH_PUPPETEER2 = "/pt"
SLASH_PUPPETEER3 = "/hm"
SlashCmdList["PUPPETEER"] = function(args)
    if args == "reset" then
        for _, group in pairs(Puppeteer.UnitFrameGroups) do
            local gc = group:GetContainer()
            gc:ClearAllPoints()
            gc:SetPoint(PTUtil.GetCenterScreenPoint(gc:GetWidth(), gc:GetHeight()))
        end
        PuppeteerSettings.HM_SettingsContainer:ClearAllPoints()
        PuppeteerSettings.HM_SettingsContainer:SetPoint("CENTER", 0, 0)
        DEFAULT_CHAT_FRAME:AddMessage("Reset all frame positions.")
    elseif args == "check" then
        Puppeteer.CheckGroup()
    elseif args == "update" then
        for _, ui in pairs(Puppeteer.AllUnitFrames) do
            ui:SizeElements()
            ui:UpdateAll()
        end
        for _, group in pairs(Puppeteer.UnitFrameGroups) do
            group:ApplyProfile()
            group:UpdateUIPositions()
        end
    elseif args == "testui" then
        PTOptions.TestUI = not PTOptions.TestUI
        Puppeteer.TestUI = PTOptions.TestUI
        if PTOptions.TestUI then
            for _, ui in pairs(Puppeteer.AllUnitFrames) do
                ui.fakeStats = ui.GenerateFakeStats()
                ui:Show()
            end
        end
        Puppeteer.CheckGroup()
        if not PTOptions.TestUI and PTUnitProxy then
            for _, type in ipairs(PTUnitProxy.CustomUnitTypes) do
                PTUnitProxy.UpdateUnitTypeFrames(type)
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("UI Testing is now "..(not PTOptions.TestUI and 
            PTUtil.Colorize("off", 1, 0.6, 0.6) or PTUtil.Colorize("on", 0.6, 1, 0.6))..".")
    elseif args == "toggle" then
        PTOptions.Hidden = not PTOptions.Hidden
        Puppeteer.CheckGroup()
        DEFAULT_CHAT_FRAME:AddMessage("The Puppeteer UI is now "..(PTOptions.Hidden and 
            PTUtil.Colorize("hidden", 1, 0.6, 0.6) or PTUtil.Colorize("shown", 0.6, 1, 0.6))..".")
    elseif args == "show" then
        PTOptions.Hidden = false
        Puppeteer.CheckGroup()
        DEFAULT_CHAT_FRAME:AddMessage("The Puppeteer UI is now "..(PTOptions.Hidden and 
            PTUtil.Colorize("hidden", 1, 0.6, 0.6) or PTUtil.Colorize("shown", 0.6, 1, 0.6))..".")
    elseif args == "hide" then
        PTOptions.Hidden = true
        Puppeteer.CheckGroup()
        DEFAULT_CHAT_FRAME:AddMessage("The Puppeteer UI is now "..(PTOptions.Hidden and 
            PTUtil.Colorize("hidden", 1, 0.6, 0.6) or PTUtil.Colorize("shown", 0.6, 1, 0.6))..".")
    elseif args == "silent" then
        PTOnLoadInfoDisabled = not PTOnLoadInfoDisabled
        DEFAULT_CHAT_FRAME:AddMessage("Load message is now "..(PTOnLoadInfoDisabled and 
            PTUtil.Colorize("off", 1, 0.6, 0.6) or PTUtil.Colorize("on", 0.6, 1, 0.6))..".")
    elseif args == "help" or args == "?" then
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt", 0, 0.8, 0).." -- Opens the addon configuration")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt reset", 0, 0.8, 0).." -- Resets all heal frame positions")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt testui", 0, 0.8, 0)..
            " -- Toggles fake players to see how the UI would look")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt toggle", 0, 0.8, 0).." -- Shows/hides the UI")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt show", 0, 0.8, 0).." -- Shows the UI")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt hide", 0, 0.8, 0).." -- Hides the UI")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt silent", 0, 0.8, 0).." -- Turns off/on message when addon loads")
    elseif args == "" then
        local container = PuppeteerSettings.HM_SettingsContainer
        if container then
            if container:IsVisible() then
                container:Hide()
            else
                container:Show()
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("HM_SettingsContainer frame not found.")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Unknown subcommand. See usage with /pt help")
    end
end