local addonName, DDT = ...

-- The engines for your class (stage E): Dyre's Toolkit's DoT tracker,
-- nameplate dots, damage to come, and crowd-control bar, each given its part
-- of the saved settings and the frame names below.
--
-- A class Tools AddOn wins for its own class (lead decision 7a, 2026-11-01).
-- This AddOn claims every owner kind (and its HealthBars source) at priority
-- 5, under a Tools AddOn's 10, so where both are on, the Tools AddOn shows,
-- writes, and says it, and this one steps aside on its own. Warlock Tools
-- Forever 1.4.1 and Mage Tools Forever 1.2.3, released before the owner
-- registry, never claim: while one of those versions (or one whose version
-- cannot be read) is loaded for your class, this AddOn makes no engines for
-- that class at all and its pages say which AddOn has them (lead, stage B
-- answer 2). Their later versions claim, and the claims decide.

DDT.PRIORITY = 5
DDT.CLASS_ADDONS = {
    WARLOCK = {addon = "WarlockToolsForever", title = "Warlock Tools Forever", unclaimedThrough = "1.4.1"},
    MAGE = {addon = "MageToolsForever", title = "Mage Tools Forever", unclaimedThrough = "1.2.3"},
}
DDT.NAMES = {
    dots = {target = "DyresDebuffTrackerTarget", focus = "DyresDebuffTrackerFocus", list = "DyresDebuffTrackerList"},
    control = "DyresDebuffTrackerControl",
    controlRow = "DyresDebuffTrackerControlRow",
    controlClick = "DyresDebuffTrackerControlClick",
    controlFocus = "DyresDebuffTrackerControlFocus",
}
local CONTROL_ROWS = 5
local CONTROL_WIDTH = 200
-- The control bar's rows: name line 18, bar line 16, padding 6, gap 4.
local CONTROL_ROW_STEP = 44
local CONTROL_POINT = {"CENTER", "CENTER", -260, -60}
local DOT_POINT = {"CENTER", "CENTER", -260, 120}

local function Metadata(addon, field)
    local read = type(C_AddOns) == "table" and C_AddOns.GetAddOnMetadata or rawget(_G, "GetAddOnMetadata")
    if type(read) ~= "function" then
        return nil
    end
    local value = read(addon, field)
    return type(value) == "string" and value or nil
end

local function Loaded(addon)
    local loaded = type(C_AddOns) == "table" and C_AddOns.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
    return type(loaded) == "function" and loaded(addon) == true
end

-- Whether version "a.b.c" is at most limit, part by part ("1.4.10" > "1.4.9").
function DDT.VersionAtMost(version, limit)
    local function Parts(text)
        local parts = {}
        for number in tostring(text):gmatch("%d+") do
            parts[#parts + 1] = tonumber(number)
        end
        return parts
    end
    local a, b = Parts(version), Parts(limit)
    for index = 1, math.max(#a, #b) do
        local x, y = a[index] or 0, b[index] or 0
        if x ~= y then
            return x < y
        end
    end
    return true
end

-- Your class's Tools AddOn: its info and whether this AddOn steps aside for
-- it without a claim (loaded, and a version from before the owner registry).
function DDT.ClassAddOn(class)
    local info = DDT.CLASS_ADDONS[class]
    if not info or not Loaded(info.addon) then
        return info, false
    end
    local version = Metadata(info.addon, "Version")
    return info, version == nil or DDT.VersionAtMost(version, info.unclaimedThrough)
end

-- The player's class file name ("WARLOCK"), never a secret.
local function PlayerClass()
    local _, class = UnitClass("player")
    if DDT.toolkit.IsSecret(class) or type(class) ~= "string" then
        return nil
    end
    return class
end

local function PredictColor()
    for _, preset in ipairs(DDT.PREDICT_COLORS) do
        if preset.key == DDT.db.predict.color then
            return preset.color
        end
    end
    return DDT.PREDICT_COLORS[1].color
end

local function Locked()
    return DDT.toolkit.IsLocked()
end

local function CreateDots()
    local toolkit, db = DDT.toolkit, DDT.db
    -- Where the combat log is restricted (Forever), Toolkit 2.6 reads hidden
    -- ticks (predictor.hidden); nil on an older Toolkit there: no damage to come.
    DDT.predictor = toolkit.CreateDotPredictor({addon = addonName, priority = DDT.PRIORITY, class = DDT.class,
        store = db.predict, color = PredictColor})
    local tracker, missing = toolkit.CreateDotTracker({addon = addonName, priority = DDT.PRIORITY, class = DDT.class,
        store = db.dots, names = DDT.NAMES.dots, point = DOT_POINT, locked = Locked, ctrlMove = true,
        movable = {register = toolkit.RegisterMovable, beginDrag = toolkit.BeginDrag, endDrag = toolkit.EndDrag},
        predictor = DDT.predictor,
        onSpellsChanged = function()
            if DDT.plateDots then
                DDT.plateDots:Refresh()
            end
        end})
    if not tracker then
        DDT.Report("The DoT tracker stays off: this client lacks " .. tostring(missing) .. ".")
        return
    end
    DDT.dotTracker = tracker
    DDT.plateDots = toolkit.CreatePlateDots({tracker = tracker, store = db.dots})
end

-- The focus box shows the first bar spell a row cannot recast (WTF's Fear);
-- a class whose control spells all click has none.
local function FocusBoxKey(spells)
    for _, spell in ipairs(spells) do
        if spell.bar and not spell.click then
            return spell.key
        end
    end
end

local function SampleNames(spells)
    local samples = {}
    for _, spell in ipairs(spells) do
        if spell.bar and #samples < 2 then
            samples[#samples + 1] = spell.label .. " (sample)"
        end
    end
    return samples
end

local function CreateControl()
    local toolkit, db = DDT.toolkit, DDT.db
    local spells = DDT.classData.control
    local widget = toolkit.CreateWidget({addon = addonName, key = "control", title = "Crowd control",
        store = db.control, width = CONTROL_WIDTH, height = CONTROL_ROWS * CONTROL_ROW_STEP - 4,
        name = DDT.NAMES.control, point = CONTROL_POINT, sizes = {scale = DDT.CONTROL_SCALE},
        onLayout = function(_, _, _, scale)
            if DDT.controlTracker then
                DDT.controlTracker:SetScale(scale)
            end
        end})
    DDT.controlWidget = widget
    local focusKey = FocusBoxKey(spells)
    local tracker, missing = toolkit.CreateControlTracker({addon = addonName, priority = DDT.PRIORITY,
        class = DDT.class, store = db.control, parent = widget, rows = CONTROL_ROWS,
        names = {row = DDT.NAMES.controlRow, click = DDT.NAMES.controlClick,
            focus = focusKey and DDT.NAMES.controlFocus or nil},
        focusBox = focusKey and {key = focusKey} or nil, locked = Locked, samples = SampleNames(spells),
        announce = {
            text = function(key) return db.control.announce[key] and db.control.texts[key] or nil end,
            say = function() return db.control.say end,
        },
        keeper = {owned = db.macrosOwned, warn = DDT.Report},
        onAdopt = function(name)
            DDT.Report("Dyre's Debuff Tracker keeps your \"" .. name .. "\" macro now.")
        end,
        onDragStart = function() toolkit.BeginDrag(widget) end,
        onDragStop = function() toolkit.EndDrag(widget) end})
    if not tracker then
        DDT.Report("The crowd-control bar stays off: this client lacks " .. tostring(missing) .. ".")
        return
    end
    DDT.controlTracker = tracker
    tracker:SetScale(db.control.scale / 100)
end

-- At login: your class, its table, and the engines it has data for.
function DDT.Start()
    DDT.class = PlayerClass()
    DDT.classData = DDT.class and DDT.toolkit.ClassSpells(DDT.class) or nil
    DDT.SanitizeDB(DDT.db, DDT.classData)
    if not DDT.classData then
        return
    end
    local info, yields = DDT.ClassAddOn(DDT.class)
    if yields then
        DDT.yieldsTo = info
        return
    end
    if #(DDT.classData.dots or {}) > 0 then
        CreateDots()
    end
    if #(DDT.classData.control or {}) > 0 then
        CreateControl()
    end
end

-- What a page says about a kind: "ours", the title of the AddOn that has it,
-- or "none" (no data for your class).
local KIND_ENGINE = {dots = "dotTracker", control = "controlTracker"}

function DDT.KindStatus(kind)
    if DDT.yieldsTo then
        return DDT.yieldsTo.title
    end
    local engine = DDT[KIND_ENGINE[kind]]
    if not engine then
        return "none"
    end
    local ownerKind = kind .. ":" .. DDT.class
    local owner = DDT.toolkit.KindOwner(ownerKind)
    if owner == nil or owner == addonName then
        return "ours"
    end
    return Metadata(owner, "Title") or owner
end

function DDT.Owns(kind)
    return DDT.KindStatus(kind) == "ours"
end

-- Settings changed: every engine follows.
function DDT.RefreshDots(rebuild)
    if DDT.dotTracker then
        DDT.dotTracker:Refresh()
        if rebuild then
            DDT.dotTracker:Rebuild()
        end
    end
    if DDT.plateDots then
        DDT.plateDots:Refresh()
    end
    if DDT.predictor then
        DDT.predictor:Refresh()
    end
end

function DDT.RefreshControl()
    if DDT.controlTracker then
        DDT.controlTracker:Refresh()
    end
end

-- The toolkit's lock changed (it says one line for every AddOn).
function DDT.SetLocked()
    if DDT.dotTracker then
        DDT.dotTracker:Refresh()
    end
    DDT.RefreshControl()
end

function DDT.ResetPositions()
    DDT.db.dots.position = nil
    DDT.db.dots.sections = {}
    if DDT.dotTracker then
        DDT.dotTracker:ResetPosition()
    end
    DDT.toolkit.ResetWidgets(addonName)
    DDT.Report("Frames are back in their default places.")
end

function DDT.DebugLines()
    local lines = {string.format("class=%s table=%s yields=%s dots=%s control=%s", tostring(DDT.class),
        tostring(DDT.classData ~= nil), tostring(DDT.yieldsTo and DDT.yieldsTo.addon), DDT.KindStatus("dots"),
        DDT.KindStatus("control"))}
    for _, part in ipairs({{"tracker", DDT.dotTracker}, {"predict", DDT.predictor}, {"control", DDT.controlTracker}}) do
        if part[2] then
            for _, line in ipairs(part[2]:DebugLines()) do
                lines[#lines + 1] = part[1] .. " " .. line
            end
        end
    end
    return lines
end
