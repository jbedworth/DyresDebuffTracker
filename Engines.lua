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
    -- The Warlock's smart curse: the Toolkit's hidden secure button, clicked
    -- by the key binding in Bindings.xml (as Warlock Tools Forever's).
    smartCurse = "DyresDebuffTrackerSmartCurse",
}
-- "! Curse": the smart curse as a character macro, while the control macros
-- are on (Warlock Tools Forever's rule, moved here with its tracker).
DDT.CURSE_MACRO = "! Curse"
BINDING_HEADER_DYRESDEBUFFTRACKER = "Dyre's Debuff Tracker"
_G["BINDING_NAME_CLICK " .. DDT.NAMES.smartCurse .. ":LeftButton"] = "Smart curse (Warlock)"
local CONTROL_ROWS = 5
local CONTROL_WIDTH = 200
-- The control bar's rows: name line 18, bar line 16, padding 6, gap 4.
local CONTROL_ROW_STEP = 44
local CONTROL_POINT = {"CENTER", "CENTER", -260, -60}
-- The control bar's look from its settings (MTF's Polymorph bar, for every
-- class): the name line grows with the text size, the icon fits the bar.
local CONTROL_HEADER, CONTROL_PADDING, CONTROL_GAP, CONTROL_ICON_INSET = 18, 6, 4, 2
-- Slider steps come quickly while a slider is dragged: the engine's slots are
-- rebuilt once, this long after the last (MTF's rule).
local CONTROL_BUILD_DELAY = 0.2
-- A class's own control-bar behavior, from its old Tools AddOn. Mage: MTF
-- 1.5.1 Polymorph.lua, moved with its bar (John: "Yes, move it"): one row
-- (one Polymorph at a time), its purple, the spell's name on the bar, your
-- focus first (no focus on Era: the mob under the mouse, else your target),
-- secret GUIDs locked by the nameplate, the time left as text where no unit
-- shows the mob, the click there whenever you know Polymorph.
DDT.CONTROL_CLASS = {
    MAGE = {rows = 1, color = {0.75, 0.45, 0.95}, label = true,
        find = {"focus", "target", "plates"},
        lock = {units = {"focus", "mouseover", "target"}, stopAt = {mouseover = true}, plateKey = true},
        focusLock = {units = {"focus"}, plateKey = true, secretHostile = true},
        countdown = true, clickThrough = true, fixedClick = "polymorph"},
}
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

-- Each slot's and panel's color (WTF's, moved here): read live.
function DDT.SlotColor(key)
    return DDT.toolkit.HexColor(DDT.db.dots.colors[key])
end

function DDT.PanelColor(key)
    return DDT.toolkit.HexColor(DDT.db.dots.panelColors[key])
end

-- "! Curse" (Warlock): written only while this AddOn has the Warlock's DoTs
-- and the control macros are on, and you know Curse of Weakness; deleted
-- when the macros are off or you lose Weakness (only one this AddOn wrote).
-- Out of combat (in combat, when it ends). Another owner keeps its own.
function DDT.ApplyCurseMacro()
    local keeper, tracker = DDT.curseKeeper, DDT.dotTracker
    if not keeper or not tracker or not DDT.Owns("dots") then
        return
    end
    DDT.toolkit.OutOfCombat(keeper, function()
        local body = tracker:SmartCurseBody()
        if DDT.db.control.macros == false then
            if keeper.written[DDT.CURSE_MACRO] then
                keeper:Delete(DDT.CURSE_MACRO)
            end
        elseif body then
            if keeper:Write(DDT.CURSE_MACRO, body) == "adopted" then
                DDT.Report("Dyre's Debuff Tracker keeps your \"" .. DDT.CURSE_MACRO .. "\" macro now.")
            end
        elseif keeper.written[DDT.CURSE_MACRO] then
            keeper:Delete(DDT.CURSE_MACRO)
        end
    end)
end

-- The curse slot's click and letter, then "! Curse".
function DDT.ApplySmartCurse()
    if DDT.dotTracker and type(DDT.dotTracker.ApplySmartCurse) == "function" then
        DDT.dotTracker:ApplySmartCurse()
    end
    DDT.ApplyCurseMacro()
end

local function CreateDots()
    local toolkit, db = DDT.toolkit, DDT.db
    local warlock = DDT.class == "WARLOCK"
    local names = {target = DDT.NAMES.dots.target, focus = DDT.NAMES.dots.focus, list = DDT.NAMES.dots.list,
        smartCurse = warlock and DDT.NAMES.smartCurse or nil}
    -- Where the combat log is restricted (Forever), Toolkit 2.6 reads hidden
    -- ticks (predictor.hidden); nil on an older Toolkit there: no damage to come.
    DDT.predictor = toolkit.CreateDotPredictor({addon = addonName, priority = DDT.PRIORITY, class = DDT.class,
        store = db.predict, color = PredictColor})
    local tracker, missing = toolkit.CreateDotTracker({addon = addonName, priority = DDT.PRIORITY, class = DDT.class,
        store = db.dots, names = names, point = DOT_POINT, locked = Locked, ctrlMove = true,
        slotColor = DDT.SlotColor, panelColor = DDT.PanelColor,
        onSmartCurse = warlock and function() DDT.ApplyCurseMacro() end or nil,
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
    if warlock and type(tracker.SmartCurseBody) == "function" and type(toolkit.CreateMacroKeeper) == "function"
            and type(toolkit.OutOfCombat) == "function" then
        DDT.curseKeeper = toolkit.CreateMacroKeeper({owned = db.macrosOwned, warn = DDT.Report})
        -- The Warlock's DoTs change hands (Warlock Tools Forever on or off,
        -- loaded or not): "! Curse" follows.
        toolkit.OnOwnerChanged("dots:WARLOCK", function() DDT.ApplyCurseMacro() end)
        DDT.ApplyCurseMacro()
    end
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

-- The bar's look now, from its settings.
function DDT.ControlLook()
    local control, own = DDT.db.control, DDT.CONTROL_CLASS[DDT.class] or {}
    local text = control.textScale / 100
    local header = math.floor(CONTROL_HEADER * text + 0.5)
    local line = control.barHeight
    return {width = control.width, header = header, line = line, icon = line - CONTROL_ICON_INSET,
        padding = CONTROL_PADDING, gap = CONTROL_GAP, height = header + line + CONTROL_PADDING, text = text,
        alpha = control.opacity / 100, color = own.color, label = own.label}
end

-- What the engine's slots were built for: a change rebuilds them.
local function ControlBuildKey(look)
    return string.format("%d:%d:%d:%d", look.width, look.line, math.floor(look.text * 100 + 0.5),
        math.floor(look.alpha * 100 + 0.5))
end

local control = {}

-- A look change: the rows at once, also in combat, and one rebuild of the
-- engine slots after the slider rests (the engine waits out combat).
local function ScheduleControlBuild()
    local tracker = DDT.controlTracker
    if not tracker or ControlBuildKey(DDT.ControlLook()) == control.buildKey then
        return
    end
    tracker:ApplyLook()
    local token = {}
    control.buildToken = token
    local function Build()
        if control.buildToken == token then
            control.buildKey = ControlBuildKey(DDT.ControlLook())
            tracker:Rebuild()
        end
    end
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(CONTROL_BUILD_DELAY, Build)
    else
        Build()
    end
end

local function CreateControl()
    local toolkit, db = DDT.toolkit, DDT.db
    local spells = DDT.classData.control
    local own = DDT.CONTROL_CLASS[DDT.class] or {}
    local rows = own.rows or CONTROL_ROWS
    local sizes = {scale = DDT.CONTROL_SCALE, opacity = DDT.CONTROL_OPACITY}
    for _, spec in ipairs(DDT.CONTROL_LOOK) do
        sizes[spec.key] = {min = spec.min, max = spec.max, step = spec.step, default = spec.default,
            label = spec.label, percent = spec.percent}
    end
    local widget = toolkit.CreateWidget({addon = addonName, key = "control", title = "Crowd control",
        store = db.control, width = CONTROL_WIDTH, height = rows * CONTROL_ROW_STEP - CONTROL_GAP,
        name = DDT.NAMES.control, point = CONTROL_POINT, sizes = sizes,
        sizeOrder = {"scale", "width", "barHeight", "textScale"},
        -- Reset size: the bar's own sizes; Bar size and Opacity stay (MTF's).
        resetSizes = {"width", "barHeight", "textScale"},
        measure = function()
            local look = DDT.ControlLook()
            return look.width, rows * (look.height + look.gap) - look.gap
        end,
        onLayout = function(_, _, _, scale)
            if DDT.controlTracker then
                DDT.controlTracker:SetScale(scale)
                ScheduleControlBuild()
            end
        end,
        onOpacity = function() ScheduleControlBuild() end})
    DDT.controlWidget = widget
    local focusKey = FocusBoxKey(spells)
    local tracker, missing = toolkit.CreateControlTracker({addon = addonName, priority = DDT.PRIORITY,
        class = DDT.class, store = db.control, parent = widget, rows = rows, look = DDT.ControlLook,
        find = own.find, lock = own.lock, focusLock = own.focusLock, countdown = own.countdown,
        clickThrough = own.clickThrough, fixedClick = own.fixedClick,
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
    control.buildKey = ControlBuildKey(DDT.ControlLook())
    tracker:SetScale(db.control.scale / 100)
end

-- Dyre's Toolkit Profile (Toolkit 2.10.0; John, 2026-11-17: "one place to
-- go to persist your profile"). The live settings stay in
-- DyresDebuffTrackerDB; the Toolkit keeps the copies, the UI, and the text.
-- Kept per character (characterKeys): macrosOwned, the character macros this
-- AddOn keeps (macros are per character). The DoT tracker's recast memory
-- (dots.lastCurse, lastBane, lastControl: the spell you last cast, which the
-- tracker writes) sits inside dots, where characterKeys cannot reach, so the
-- part's sanitize keeps this character's own values instead.
DDT.PROFILE_CHARACTER_KEYS = {"macrosOwned"}

-- Any settings table (empty, partial, older, newer, another character's or
-- class's) to a full, repaired one for this character. Never errors.
function DDT.ProfileSettings(settings)
    settings = type(settings) == "table" and settings or {}
    local clean = DDT.SanitizeDB({dots = settings.dots, predict = settings.predict, control = settings.control,
        frost = settings.frost, macrosOwned = settings.macrosOwned, toolsImported = settings.toolsImported},
        DDT.classData)
    local live = type(DDT.db) == "table" and type(DDT.db.dots) == "table" and DDT.db.dots or {}
    for _, slot in ipairs(DDT.classData and DDT.classData.dots or {}) do
        if slot.lastUsed then
            clean.dots[slot.lastUsed] = type(live[slot.lastUsed]) == "string" and live[slot.lastUsed] or nil
        end
    end
    return clean
end

-- A copied or imported profile is in DyresDebuffTrackerDB (written in place,
-- so every engine's store is the same table): every engine reads it again.
-- The Toolkit applies a profile only out of combat; the secure parts still
-- go through each engine's out-of-combat path.
function DDT.ApplyProfile()
    local toolkit = DDT.toolkit
    if toolkit and type(toolkit.ReapplyWidgets) == "function" then
        toolkit.ReapplyWidgets(addonName)
    end
    -- Places, colors, then Refresh (owner claim, from dots.enabled) and
    -- Rebuild (theme, sizes, grow, order, health, panel opacity).
    if DDT.dotTracker then
        DDT.dotTracker:ResetPosition()
        DDT.dotTracker:ApplyPanelColors()
    end
    DDT.RefreshDots(true)
    if DDT.plateDots then
        DDT.plateDots:ApplyColors()
        DDT.plateDots:ApplyOpacity()
    end
    DDT.ApplySmartCurse()
    -- A copied profile wins over a later first-login copy from a Tools AddOn.
    DDT.db.toolsImported = true
    -- Scale and look, then Refresh: the owner claim (control.enabled), the
    -- clicks, the plate timers, and the macros (each out of combat).
    local control = DDT.controlTracker
    if control then
        control:SetScale(DDT.db.control.scale / 100)
        control:Rebuild()
        control:Refresh()
    end
    DDT.RefreshFrost()
end

-- Joins the profile, where the Toolkit has one (2.10.0); else nothing changes.
function DDT.RegisterProfile()
    local toolkit = DDT.toolkit
    if not toolkit or type(toolkit.RegisterProfilePart) ~= "function" then
        return false
    end
    return toolkit.RegisterProfilePart({addon = addonName, title = DDT.TITLE,
        current = function() return DDT.db end, sanitize = DDT.ProfileSettings,
        characterKeys = DDT.PROFILE_CHARACTER_KEYS, refresh = DDT.ApplyProfile}) == true
end

-- At login: your class, its table, and the engines it has data for.
function DDT.Start()
    DDT.class = PlayerClass()
    DDT.classData = DDT.class and DDT.toolkit.ClassSpells(DDT.class) or nil
    DDT.SanitizeDB(DDT.db, DDT.classData)
    -- After the saved settings, before the frames: a waiting part lands now.
    DDT.profileJoined = DDT.RegisterProfile()
    -- The class Tools AddOn's settings, once, before the engines read them.
    DDT.ImportFromTools(DDT.db, DDT.class, DDT.classData)
    -- WTF's smart curse key, out of combat (now, else when combat ends).
    if DDT.class == "WARLOCK" and type(DDT.toolkit.OutOfCombat) == "function" then
        DDT.toolkit.OutOfCombat(DDT.CURSE_BINDING, DDT.MoveCurseBinding)
    end
    -- The Mage's frozen and chilled arcs: this AddOn's own, so also while
    -- a Tools AddOn has the DoTs (no other AddOn draws them).
    if DDT.class == "MAGE" then
        local arcs, missing = DDT.CreateFrostArcs(DDT.toolkit, function() return DDT.db.frost end)
        if arcs then
            DDT.frostArcs = arcs
        else
            DDT.frostMissing = tostring(missing)
            DDT.Report("The frozen and chilled arcs stay off: this client lacks " .. tostring(missing) .. ".")
        end
    end
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
-- Whether the Toolkit draws each panel with its own settings
-- (TRACKER_PANEL_OPTIONS, Toolkit 2.13.0).
function DDT.PerPanel()
    return DDT.toolkit ~= nil and type(DDT.toolkit.TRACKER_PANEL_OPTIONS) == "table"
end

-- With an older Toolkit the page has only the tracker-wide rows: on each
-- change there, each panel's saved settings follow them, so a later Toolkit
-- update starts from what the player last set. Not at login: per-panel
-- values saved with a newer Toolkit stay until a tracker-wide change.
function DDT.MirrorPanels()
    local dots = DDT.db and DDT.db.dots
    if DDT.PerPanel() or type(dots) ~= "table" then
        return
    end
    for _, key in ipairs(DDT.PANELS) do
        dots.panels[key] = DDT.SanitizePanel({}, dots)
    end
end

function DDT.RefreshDots(rebuild)
    DDT.MirrorPanels()
    if DDT.dotTracker then
        DDT.dotTracker:Refresh()
        -- The panel frame switch (Toolkit TRACKER_FRAME): at once, also in combat.
        if type(DDT.dotTracker.ApplyPanelColors) == "function" then
            DDT.dotTracker:ApplyPanelColors()
        end
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

function DDT.RefreshFrost()
    if DDT.frostArcs then
        DDT.frostArcs:Refresh()
    end
end

function DDT.RefreshControl()
    if DDT.controlTracker then
        DDT.controlTracker:Refresh()
    end
    -- "! Curse" follows the control macros switch.
    DDT.ApplyCurseMacro()
end

-- A DoT's color: the tracker's bars (rebuilt) and the nameplate dots.
function DDT.RefreshDotColors()
    DDT.RefreshDots(true)
    if DDT.plateDots then
        DDT.plateDots:ApplyColors()
    end
end

-- A panel's opacity: the panel at once; its bars with the rebuild.
function DDT.RefreshPanelOpacity()
    if DDT.dotTracker then
        DDT.dotTracker:ApplyPanelOpacity()
    end
end

-- A panel back to its defaults (its place stays): shown, its own settings
-- (health, frame, outline, size), grow, color, and opacity.
function DDT.ResetPanel(key)
    local dots, defaults = DDT.db.dots, DDT.SanitizeDB({}, DDT.classData).dots
    dots.panels[key] = defaults.panels[key]
    dots.show[key], dots.grow[key] = defaults.show[key], defaults.grow[key]
    dots.panelColors[key], dots.panelOpacity[key] = defaults.panelColors[key], defaults.panelOpacity[key]
    DDT.RefreshPanelOpacity()
    DDT.RefreshDots(true)
end

function DDT.RefreshPlateDotsOpacity()
    if DDT.plateDots then
        DDT.plateDots:ApplyOpacity()
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
    -- The Mage's frozen and chilled arcs (Frost.lua).
    if DDT.frostArcs then
        for _, line in ipairs(DDT.frostArcs:DebugLines()) do
            lines[#lines + 1] = "frost " .. line
        end
    elseif DDT.class == "MAGE" then
        lines[#lines + 1] = "frost off: this client lacks " .. tostring(DDT.frostMissing)
    else
        lines[#lines + 1] = "frost none (Mage only)"
    end
    return lines
end
