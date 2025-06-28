Puppeteer.DistanceScannerFrame = CreateFrame("Frame", "PTDistanceScannerFrame", UIParent)

local util = PTUtil
local compost = AceLibrary("Compost-2.0")
local TRACKING_MIN_DIST = 20
local TRACKING_MAX_DIST = 60
local SIGHT_MAX_DIST = 80

local almostAllUnits = util.CloneTable(util.AllUnits) -- Everything except the player
table.remove(almostAllUnits, util.IndexOf(almostAllUnits, "player"))
if PTUnitProxy then
    PTUnitProxy.RegisterUpdateListener(function()
        almostAllUnits = util.CloneTable(util.AllUnits) -- Everything except the player
        table.remove(almostAllUnits, util.IndexOf(almostAllUnits, "player"))
    end)
end

local distanceTrackedUnits = util.CloneTable(almostAllUnits) -- Initially scan all units
local sightTrackedUnits = util.CloneTable(almostAllUnits)
local preciseDistance = util.CanClientGetPreciseDistance()
local sightTrackingEnabled = util.CanClientSightCheck()
local nextTrackingUpdate = GetTime() + 0.5
local nextUpdate = GetTime() + 0.6
if not preciseDistance and not sightTrackingEnabled then
    nextUpdate = nextUpdate + 99999999 -- Effectively disable updates
end

local TRACKING_UPDATE_INTERVAL = 1.25

local _G = getfenv(0)
if PTUtil.IsSuperWowPresent() then
    setmetatable(PTUnitProxy, {__index = getfenv(1)})
    setfenv(1, PTUnitProxy)
end

function Puppeteer.RunTrackingScan()
    local UnitFrames = Puppeteer.UnitFrames
    local time = GetTime()
    if time > nextTrackingUpdate then
        nextTrackingUpdate = time + TRACKING_UPDATE_INTERVAL


        compost:Erase(distanceTrackedUnits)
        local prevSightTrackedUnits = sightTrackedUnits
        sightTrackedUnits = compost:GetTable()
        if PTGuidRoster then
            for guid, cache in pairs(PTUnit.GetAllUnits()) do
                Puppeteer.EvaluateTracking(guid)
            end
        else
            for _, unit in ipairs(almostAllUnits) do
                Puppeteer.EvaluateTracking(unit)
            end
        end

        for _, unit in ipairs(prevSightTrackedUnits) do
            for ui in UnitFrames(unit) do
                ui:UpdateSight()
            end
        end
        compost:Reclaim(prevSightTrackedUnits)
    end

    if time > nextUpdate then
        nextUpdate = time + 0.1
        for _, unit in ipairs(distanceTrackedUnits) do
            local cache = PTUnit.Get(unit)
            if cache and cache:UpdateDistance() then
                for ui in UnitFrames(unit) do
                    ui:UpdateRange()
                end
            end
        end
        for _, unit in ipairs(sightTrackedUnits) do
            local cache = PTUnit.Get(unit)
            if cache and cache:UpdateSight() then
                for ui in UnitFrames(unit) do
                    ui:UpdateSight()
                end
            end
        end
    end
end

function Puppeteer.EvaluateTracking(unit, update)
    local UnitFrames = Puppeteer.UnitFrames
    local cache = PTUnit.Get(unit)
    local distanceChanged = cache:UpdateDistance()
    local sightChanged = cache:UpdateSight()
    local new = cache:CheckNew()
    local dist = cache:GetDistance()
    if distanceChanged or sightChanged or new then
        for ui in UnitFrames(unit) do
            if distanceChanged or new then
                ui:UpdateRange()
            end
            if sightChanged or new then
                ui:UpdateSight()
            end
        end
    end
    local isTarget = UnitIsUnit(unit, "target")
    if PTGuidRoster then
        unit = PTGuidRoster.ResolveUnitGuid(unit)
    end
    if isTarget or (dist < TRACKING_MAX_DIST and dist > TRACKING_MIN_DIST) then -- Only closely track units that are close to the range threshold
        if not update or not util.ArrayContains(distanceTrackedUnits, unit) then
            table.insert(distanceTrackedUnits, unit)
        end
    end
    if sightTrackingEnabled and (isTarget or (dist > 0 and dist < SIGHT_MAX_DIST)) then
        if not update or not util.ArrayContains(sightTrackedUnits, unit) then
            table.insert(sightTrackedUnits, unit)
        end
    end
end

function Puppeteer.StartDistanceScanner()
    Puppeteer.DistanceScannerFrame:SetScript("OnUpdate", Puppeteer.RunTrackingScan)
end