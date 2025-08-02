PuppeteerSettings = {}
PTUtil.SetEnvironment(PuppeteerSettings)

local _G = getfenv(0)
local util = PTUtil

local _, playerClass = UnitClass("player")

function UpdateTrackedDebuffTypes()
    local debuffTypeCureSpells = {
        ["PALADIN"] = {
            ["Purify"] = {"Poison", "Disease"},
            ["Cleanse"] = {"Poison", "Disease", "Magic"}
        },
        ["PRIEST"] = {
            ["Cure Disease"] = {"Disease"},
            ["Abolish Disease"] = {"Disease"},
            ["Dispel Magic"] = {"Magic"}
        },
        ["DRUID"] = {
            ["Cure Poison"] = {"Poison"},
            ["Abolish Poison"] = {"Poison"},
            ["Remove Curse"] = {"Curse"}
        },
        ["SHAMAN"] = {
            ["Cure Poison"] = {"Poison"},
            ["Cure Disease"] = {"Disease"}
        },
        ["MAGE"] = {
            ["Remove Lesser Curse"] = {"Curse"}
        }
    }

    for _, class in ipairs(util.GetClasses()) do
        if not debuffTypeCureSpells[class] then
            debuffTypeCureSpells[class] = {}
        end
    end

    local trackedDebuffTypes = {}
    do
        local id = 1;
        for i = 1, GetNumSpellTabs() do
            local _, _, _, numSpells = GetSpellTabInfo(i);
            for j = 1, numSpells do
                local spellName = GetSpellName(id, "spell");
                local types = debuffTypeCureSpells[playerClass][spellName]
                if types then
                    for _, type in ipairs(types) do
                        trackedDebuffTypes[type] = 1
                    end
                end
                id = id + 1
            end
        end
    end
    TrackedDebuffTypesSet = trackedDebuffTypes
    trackedDebuffTypes = util.ToArray(trackedDebuffTypes)

    TrackedDebuffTypes = trackedDebuffTypes
end

function SetDefaults()
    if not PTOptions then
        _G.PTOptions = {}
    end
    
    local OPTIONS_VERSION = 2
    local isHealer = util.IsHealerClass("player")
    local isManaUser = util.ClassPowerTypes[util.GetClass("player")] == "mana"
    do
        local defaults = {
            ["ShowTargets"] = {
                ["Friendly"] = isHealer,
                ["Hostile"] = false
            },
            ["AlwaysShowTargetFrame"] = false,
            ["AutoTarget"] = false,
            ["TargetWhileCasting"] = false,
            ["TargetAfterCasting"] = false,
            ["FrameDrag"] = {
                ["MoveAll"] = false,
                ["AltMoveKey"] = "Shift"
            },
            ["DisablePartyFrames"] = {
                ["InParty"] = false,
                ["InRaid"] = false
            },
            ["SpellsTooltip"] = {
                ["Enabled"] = isHealer,
                ["AttachTo"] = "Button", -- "Button", "Frame", "Group", "Screen"
                ["OffsetX"] = 0,
                ["OffsetY"] = 0,
                ["Anchor"] = "Top Right", -- "Top Left", "Top Right", "Bottom Left", "Bottom Right"
                ["ShowManaCost"] = false,
                ["ShowManaPercentCost"] = true,
                ["HideCastsAbove"] = 3,
                ["CriticalCastsLevel"] = 3,
                ["AbbreviatedKeys"] = false,
                ["ColoredKeys"] = true,
                ["ShowPowerBar"] = true,
                ["ShowPowerAs"] = isManaUser and "Power %" or "Power", -- "Power", "Power/Max Power", "Power %"
                ["ShowItemCount"] = false
            },
            ["ShowAuraTimesAt"] = {
                ["Short"] = 5, -- <1 min
                ["Medium"] = 10, -- <=2 min
                ["Long"] = 60 * 2 -- >2 min
            },
            ["CastWhen"] = "Mouse Up", -- Mouse Up, Mouse Down
            ["AutoResurrect"] = Puppeteer.ResurrectionSpells[util.GetClass("player")] ~= nil,
            ["UseHealPredictions"] = true,
            ["SetMouseover"] = true,
            ["LFTAutoRole"] = true, -- Turtle WoW
            ["TestUI"] = false,
            ["Hidden"] = false,
            ["ChosenProfiles"] = {
                ["Party"] = "Default",
                ["Pets"] = "Default",
                ["Raid"] = "Small",
                ["Raid Pets"] = "Small",
                ["Target"] = "Long",
                ["Focus"] = "Default"
            },
            ["Buttons"] = {
                "LeftButton",
                "MiddleButton",
                "RightButton",
                "Button5",
                "Button4",
                "MOUSEWHEELUP",
                "MOUSEWHEELDOWN"
            },
            ["ButtonInfo"] = {
                ["LeftButton"] = {
                    ["Name"] = "Left",
                    ["ShowUnbound"] = true
                },
                ["MiddleButton"] = {
                    ["Name"] = "Middle",
                    ["ShowUnbound"] = true
                },
                ["RightButton"] = {
                    ["Name"] = "Right",
                    ["ShowUnbound"] = true
                },
                ["Button5"] = {
                    ["Name"] = "Forward",
                    ["ShowUnbound"] = true
                },
                ["Button4"] = {
                    ["Name"] = "Back",
                    ["ShowUnbound"] = true
                },
                ["MOUSEWHEELUP"] = {
                    ["Name"] = "Wheel Up",
                    ["ShowUnbound"] = true
                },
                ["MOUSEWHEELDOWN"] = {
                    ["Name"] = "Wheel Down",
                    ["ShowUnbound"] = true
                },
            },
            ["Scripts"] = {
                ["OnLoad"] = "",
                ["OnPostLoad"] = ""
            },
            ["OptionsVersion"] = OPTIONS_VERSION
        }

        local optionsUpgrades = {
            {
                version = 2,
                upgrade = function(self, options)
                    local upgraded = util.CloneTable(options, true)
                    if options["ShowSpellsTooltip"] ~= nil then
                        if not options["SpellsTooltip"] then
                            upgraded["SpellsTooltip"] = {}
                        end
                        upgraded["SpellsTooltip"]["Enabled"] = options["ShowSpellsTooltip"]
                        upgraded["ShowSpellsTooltip"] = nil
                    end
                    if options["ChosenProfiles"] ~= nil then
                        local groupNames = {"Party", "Pets", "Raid", "Raid Pets", "Target"}
                        local changedProfileNames = {
                            ["Compact"] = "Default",
                            ["Compact (Small)"] = "Small",
                            ["Compact (Short Bar)"] = "Default (Short Bar)"
                        }
                        for _, name in ipairs(groupNames) do
                            local currentlySelected = options["ChosenProfiles"][name]
                            if changedProfileNames[currentlySelected] then
                                upgraded["ChosenProfiles"][name] = changedProfileNames[currentlySelected]
                            end
                        end
                    end
                    upgraded["OptionsVersion"] = self.version
                    return upgraded
                end,
                shouldUpgrade = function(self, options)
                    return options.OptionsVersion < self.version
                end
            }
        }

        if PTOptions.OptionsVersion and PTOptions.OptionsVersion < OPTIONS_VERSION then
            for _, upgrade in ipairs(optionsUpgrades) do
                if upgrade:shouldUpgrade(PTOptions) then
                    local prevVersion = PTOptions.OptionsVersion
                    _G.PTOptions = upgrade:upgrade(PTOptions)
                    DEFAULT_CHAT_FRAME:AddMessage("[Puppeteer] Upgraded options from version "..
                        prevVersion.." to "..upgrade.version)
                end
            end
        end
    
        for field, value in pairs(defaults) do
            if PTOptions[field] == nil then
                if type(value) == "table" then
                    PTOptions[field] = PTUtil.CloneTable(value, true)
                else
                    PTOptions[field] = value
                end
                -- TODO: Redo default application
            --[[
            elseif type(value) == "table" then
                for field2, value2 in pairs(value) do
                    if PTOptions[field][field2] == nil then
                        if type(value2) == "table" then
                            PTOptions[field][field2] = PTUtil.CloneTable(value2, true)
                        else
                            PTOptions[field][field2] = value2
                        end
                    end
                end]]
            end
        end
    end
end

function TraverseOptions(location)
    local path = util.SplitString(location, ".")
    local currentTable = PTOptions
    for i = 1, table.getn(path) - 1 do
        currentTable = currentTable[path[i]]
    end
    return currentTable, path[table.getn(path)]
end

function GetOption(location)
    local optionTable, location = TraverseOptions(location)
    return optionTable[location]
end

function SetOption(location, value)
    local optionTable, location = TraverseOptions(location)
    optionTable[location] = value
end

TrackedBuffs = nil -- Default tracked is variable based on class
TrackedDebuffs = nil -- Default tracked is variable based on class
TrackedDebuffTypes = {} -- Default tracked is variable based on class

-- Buffs/debuffs that significantly modify healing
TrackedHealingBuffs = {"Amplify Magic", "Dampen Magic"}
TrackedHealingDebuffs = {"Mortal Strike", "Wound Poison", "Curse of the Deadwood", "Veil of Shadow", "Gehennas' Curse", 
    "Necrotic Poison", "Blood Fury", "Necrotic Aura", 
    "Shadowbane Curse" -- Turtle WoW
}

do
    -- Tracked buffs for all classes
    local defaultTrackedBuffs = {
        "Blessing of Protection", "Hand of Protection", "Divine Protection", "Divine Shield", "Divine Intervention", -- Paladin
            "Bulwark of the Righteous", "Blessing of Sacrifice", "Hand of Sacrifice",
        "Power Infusion", "Spirit of Redemption", "Inner Focus", "Abolish Disease", "Power Word: Shield", -- Priest
        "Shield Wall", "Recklessness", "Last Stand", -- Warrior
        "Evasion", "Vanish", -- Rogue
        "Deterrence", "Feign Death", "Mend Pet", -- Hunter
        "Frenzied Regeneration", "Innervate", "Abolish Poison", -- Druid
        "Soulstone Resurrection", "Hellfire", -- Warlock
        "Ice Block", "Evocation", "Ice Barrier", "Mana Shield", -- Mage
        "Quel'dorei Meditation", "Grace of the Sunwell", -- Racial
        "First Aid", "Food", "Drink" -- Generic
    }
    -- Tracked buffs for specific classes
    local defaultClassTrackedBuffs = {
        ["PALADIN"] = {"Blessing of Wisdom", "Blessing of Might", "Blessing of Salvation", "Blessing of Sanctuary", 
            "Blessing of Kings", "Greater Blessing of Wisdom", "Greater Blessing of Might", 
            "Greater Blssing of Salvation", "Greater Blessing of Sanctuary", "Greater Blessing of Kings", "Daybreak", 
            "Blessing of Freedom", "Hand of Freedom", "Redoubt", "Holy Shield"},
        ["PRIEST"] = {"Prayer of Fortitude", "Power Word: Fortitude", "Prayer of Spirit", "Divine Spirit", 
            "Prayer of Shadow Protection", "Shadow Protection", "Holy Champion", "Champion's Grace", "Empower Champion", 
            "Fear Ward", "Inner Fire", "Renew", "Lightwell Renew", "Inspiration", 
            "Fade", "Spirit Tap"},
        ["WARRIOR"] = {"Battle Shout"},
        ["DRUID"] = {"Gift of the Wild", "Mark of the Wild", "Thorns", "Rejuvenation", "Regrowth"},
        ["SHAMAN"] = {"Water Walking", "Healing Way", "Ancestral Fortitude"},
        ["MAGE"] = {"Arcane Brilliance", "Arcane Intellect", "Frost Armor", "Ice Armor", "Mage Armor"},
        ["WARLOCK"] = {"Demon Armor", "Demon Skin", "Unending Breath", "Shadow Ward", "Fire Shield"},
        ["HUNTER"] = {"Rapid Fire", "Quick Shots", "Quick Strikes", "Aspect of the Pack", 
            "Aspect of the Wild", "Bestial Wrath", "Feed Pet Effect"}
    }
    local trackedBuffs = defaultClassTrackedBuffs[playerClass] or {}
    util.AppendArrayElements(trackedBuffs, TrackedHealingBuffs)
    util.AppendArrayElements(trackedBuffs, defaultTrackedBuffs)
    trackedBuffs = util.ToSet(trackedBuffs, true)

    -- Tracked debuffs for all classes
    local defaultTrackedDebuffs = {
        "Forbearance", -- Paladin
        "Death Wish", -- Warrior
        "Enrage", -- Druid
        "Recently Bandaged", "Resurrection Sickness", "Ghost", -- Generic
        "Deafening Screech" -- Applied by mobs
    }
    -- Tracked debuffs for specific classes
    local defaultClassTrackedDebuffs = {
        ["PRIEST"] = {"Weakened Soul"}
    }
    local trackedDebuffs = defaultClassTrackedDebuffs[playerClass] or {}
    util.AppendArrayElements(trackedDebuffs, TrackedHealingDebuffs)
    util.AppendArrayElements(trackedDebuffs, defaultTrackedDebuffs)
    trackedDebuffs = util.ToSet(trackedDebuffs, true)

    TrackedBuffs = trackedBuffs
    TrackedDebuffs = trackedDebuffs

    TrackedHealingBuffs = util.ToSet(TrackedHealingBuffs)
    TrackedHealingDebuffs = util.ToSet(TrackedHealingDebuffs)
end

ShowEmptySpells = true
IgnoredEmptySpells = {--[["MiddleButton"]]}
IgnoredEmptySpells = util.ToSet(IgnoredEmptySpells)
CustomButtonOrder = {
    "LeftButton",
    "MiddleButton",
    "RightButton",
    "Button5",
    "Button4"
}
CustomButtonNames = {
    ["Button4"] = "Back", 
    ["Button5"] = "Forward"
}

DebuffTypeColors = {
    ["Magic"] = {0.35, 0.35, 1},
    ["Curse"] = {0.5, 0, 1},
    ["Disease"] = {0.45, 0.35, 0.16},
    ["Poison"] = {0.6, 0.7, 0}
}


EditedSpells = {}
SpellsContext = {}

function GetSelectedProfileName(frame)
    local selected = PTOptions.ChosenProfiles[frame]
    if not PTDefaultProfiles[selected] then
        selected = "Default"
    end
    return selected
end

function GetSelectedProfile(frame)
    return PTDefaultProfiles[GetSelectedProfileName(frame)]
end
