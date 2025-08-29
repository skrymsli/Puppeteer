PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)

DistanceScannerFrame = CreateFrame("Frame", "PTDistanceScannerFrame", UIParent)

local util = PTUtil
local compost = AceLibrary("Compost-2.0")
local TRACKING_MIN_DIST = 20
local TRACKING_MAX_DIST = 60
local SIGHT_MAX_DIST = 80

local AllUnits = util.AllUnits

local distanceTrackedUnits = util.CloneTable(AllUnits) -- Initially scan all units
local sightTrackedUnits = util.CloneTable(AllUnits)
local preciseDistance = util.CanClientGetPreciseDistance()
local sightTrackingEnabled = util.CanClientSightCheck()
local nextTrackingUpdate = GetTime() + 0.5
local nextUpdate = GetTime() + 0.6
if not preciseDistance and not sightTrackingEnabled then
    nextUpdate = nextUpdate + 99999999 -- Effectively disable updates
end

local TRACKING_UPDATE_INTERVAL = 1.25

function RunTrackingScan()
    local UnitFrames = UnitFrames
    local time = GetTime()
    if time > nextTrackingUpdate then
        --StartTiming("TrackingEval")
        nextTrackingUpdate = time + TRACKING_UPDATE_INTERVAL


        compost:Erase(distanceTrackedUnits)
        local prevSightTrackedUnits = sightTrackedUnits
        sightTrackedUnits = compost:GetTable()
        if PTGuidRoster then
            for guid, cache in pairs(PTUnit.GetAllUnits()) do
                EvaluateTracking(guid)
            end
        else
            for _, unit in ipairs(AllUnits) do
                EvaluateTracking(unit)
            end
        end

        for _, unit in ipairs(prevSightTrackedUnits) do
            for ui in UnitFrames(unit) do
                ui:UpdateSight()
            end
        end
        compost:Reclaim(prevSightTrackedUnits)
        --EndTiming("TrackingEval")
    end

    --StartTiming("TrackingScan")
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
    --EndTiming("TrackingScan")
end

function EvaluateTracking(unit, update)
    local UnitFrames = UnitFrames
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

function StartDistanceScanner()
    DistanceScannerFrame:SetScript("OnUpdate", RunTrackingScan)
end