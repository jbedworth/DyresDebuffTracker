local addonName, DDT = ...

-- Dyre's Debuff Tracker (phase 2, stage E; lead plan, 2026-11-01): the
-- generic wrapper on Dyre's Toolkit's tracking engines, for every class with
-- a table in the toolkit's ClassData (Warlock and Mage so far). It finds your
-- class, makes the engines for it (the DoT tracker, the nameplate dots, the
-- damage to come, the crowd-control bar and its macros and announcements),
-- and gives each its settings page. A class Tools AddOn wins for its own
-- class (lead decision 7a): this AddOn claims at priority 5 (Engines.lua).
--
-- Core owns the saved settings (per character: positions, character macros)
-- and their repair, the toolkit check, startup, and /ddt. The engines never
-- own saved variables: each gets its part of DyresDebuffTrackerDB.

DDT.TITLE = "Dyre's Debuff Tracker"
DDT.PREFIX = "DDT: "
DDT.TOOLKIT_MISSING = "Dyre's Debuff Tracker needs Dyre's Toolkit 2.9.1 or later. Install or update it from CurseForge."
-- Toolkit 2.9.1 holds every class's DoT and crowd-control table and the
-- prediction engine's finishers and late starts; its contract is still 2, so
-- the TOC version is read too. An unreadable version is let through.
DDT.TOOLKIT_VERSION = "2.9.1"

-- The toolkit functions this AddOn uses (contract 2, since Toolkit 2.5.0).
DDT.TOOLKIT_FUNCTIONS = {
    "RegisterAddOn", "IsLocked", "RegisterSettingsCategory", "OpenSettings",
    "CreateWidget", "AddWidgetSettings", "ResetWidgets", "RegisterMovable", "BeginDrag", "EndDrag",
    "ClassSpells", "CreateDotTracker", "CreatePlateDots", "CreateDotPredictor", "CreateControlTracker",
    "KindOwner", "IsOwner", "OnOwnerChanged", "FocusWorks", "ResetFocusWorks", "HexColor", "ValidMarker",
    "SpellName", "IsSecret",
}

function DDT.Report(message)
    DEFAULT_CHAT_FRAME:AddMessage(DDT.PREFIX .. tostring(message))
end

-- The toolkit, when it is 2.9.1 or later (or its version is unreadable) and
-- offers contract 2 and every function above; else nil.
-- Whether version "a.b.c" is at least floor, part by part ("2.10.0" > "2.9.1").
function DDT.VersionAtLeast(version, floor)
    local function Parts(text)
        local parts = {}
        for number in tostring(text):gmatch("%d+") do
            parts[#parts + 1] = tonumber(number)
        end
        return parts
    end
    local a, b = Parts(version), Parts(floor)
    for index = 1, math.max(#a, #b) do
        local x, y = a[index] or 0, b[index] or 0
        if x ~= y then
            return x > y
        end
    end
    return true
end

-- The installed toolkit's TOC version, or nil when it cannot be read.
local function ToolkitVersion()
    local read = type(C_AddOns) == "table" and C_AddOns.GetAddOnMetadata or rawget(_G, "GetAddOnMetadata")
    local version = type(read) == "function" and read("DyresToolkit", "Version") or nil
    return type(version) == "string" and version or nil
end

function DDT.Toolkit()
    local version = ToolkitVersion()
    if version and not DDT.VersionAtLeast(version, DDT.TOOLKIT_VERSION) then
        return nil
    end
    local toolkit = type(DyresToolkit) == "table" and type(DyresToolkit.RequireContract) == "function"
        and DyresToolkit.RequireContract(2)
    if type(toolkit) ~= "table" then
        return nil
    end
    for _, name in ipairs(DDT.TOOLKIT_FUNCTIONS) do
        if type(toolkit[name]) ~= "function" then
            return nil
        end
    end
    return toolkit
end

-- Saved settings -------------------------------------------------------------

-- The DoT tracker's sizes, as Warlock Tools Forever's (its defaults draw the
-- same rows).
DDT.SIZE_SPECS = {
    compact = {
        {key = "iconSize", min = 16, max = 40, step = 1, default = 22},
        {key = "nameWidth", min = 60, max = 200, step = 5, default = 110},
        {key = "textScale", min = 50, max = 200, step = 5, default = 100},
    },
    bars = {
        {key = "barWidth", min = 150, max = 500, step = 10, default = 290},
        {key = "lineHeight", min = 12, max = 28, step = 1, default = 16},
        {key = "textScale", min = 50, max = 200, step = 5, default = 100},
    },
}
DDT.NAME_POSITIONS = {compact = {"left", "right", "above", "below"}, bars = {"above", "below"}}
DDT.DEFAULT_NAME_POSITION = {compact = "left", bars = "above"}
DDT.HEALTH_TEXTS = {"none", "number", "percent", "both"}
DDT.FILLS = {"stripes", "solid", "bar"}
-- Where DIES goes (John, 2026-11-09), apart for the target and focus frames
-- and for nameplates: Auto is the Toolkit's choice; X and Y move it, in
-- pixels, right and up positive.
DDT.DIES_PLACES = {{"auto", "Auto"}, {"left", "Left of the bar"}, {"right", "Right of the bar"},
    {"center", "Center of the bar"}, {"above", "Above the bar"}, {"below", "Below the bar"},
    {"inside", "Inside the bar's right end"}}
DDT.DIES_OFFSET = 100
DDT.PREDICT_COLORS = {
    {key = "purple", label = "Purple", color = {0.64, 0.21, 0.93}},
    {key = "red", label = "Red", color = {1, 0.15, 0.15}},
    {key = "orange", label = "Orange", color = {1, 0.55, 0.1}},
    {key = "white", label = "White", color = {1, 1, 1}},
    {key = "green", label = "Green", color = {0.25, 0.9, 0.3}},
}
DDT.PANELS = {"target", "focus", "list"}
-- Each DoT panel's grow direction (John, 2026-11-14: "for each frame
-- (Target, Focus, Other) ... whether the DoTs should grow up or down from
-- the origin"): the Toolkit's TRACKER_GROW values, read from dots.grow.
DDT.GROW = {"down", "up"}
DDT.CONTROL_SCALE = {min = 50, max = 150, step = 5, default = 100}
-- "Tracker size" (John, 2026-11-14: "increasing or decreasing by up to 25%"):
-- one percent for both themes. Bars: the bar width; Compact: the icon size.
-- The name width and the text scale stay. The Toolkit reads the sizes.
DDT.TRACKER_SIZE = {min = 75, max = 125, step = 5, default = 100}

-- The percent, repaired: a number, on a step of 5, from 75 to 125.
function DDT.SanitizeTrackerSize(value)
    local spec = DDT.TRACKER_SIZE
    if type(value) ~= "number" or value ~= value then
        return spec.default
    end
    value = math.floor(value / spec.step + 0.5) * spec.step
    return math.max(spec.min, math.min(spec.max, value))
end

-- Writes the percent's sizes into dots.sizes, for both themes.
function DDT.ApplyTrackerSize(dots)
    local percent = DDT.SanitizeTrackerSize(dots.trackerSize)
    dots.trackerSize = percent
    local function Default(theme, key)
        for _, size in ipairs(DDT.SIZE_SPECS[theme]) do
            if size.key == key then
                return size.default
            end
        end
    end
    dots.sizes.bars.barWidth = math.floor(Default("bars", "barWidth") * percent / 100 + 0.5)
    dots.sizes.compact.iconSize = math.floor(Default("compact", "iconSize") * percent / 100 + 0.5)
end

local function Bool(value, default)
    if type(value) == "boolean" then
        return value
    end
    return default
end

local function Whole(value, low, high, default)
    if type(value) ~= "number" or value ~= math.floor(value) then
        return default
    end
    return math.max(low, math.min(high, value))
end

local function Choice(value, list, default)
    for _, each in ipairs(list) do
        if value == each then
            return value
        end
    end
    return default
end

local function Place(value)
    if type(value) == "table" and type(value.point) == "string" and type(value.relativePoint) == "string"
            and type(value.x) == "number" and type(value.y) == "number" then
        return value
    end
end

-- A one-line chat text of at most 255 bytes, else the default.
local function Text(value, default)
    if type(value) ~= "string" or not value:find("%S") or #value > 255 or value:find("\n", 1, true) then
        return default
    end
    return value
end

-- The default group message for a crowd-control spell: its name, the mob,
-- and the marker, with the AddOn's credit.
function DDT.DefaultAnnounceText(spell)
    if spell.untargeted then
        return spell.label .. "! - via Dyre's Debuff Tracker"
    end
    return spell.label .. " on >> %T <<" .. (spell.marker and " %M" or "") .. " - via Dyre's Debuff Tracker"
end

local function SanitizeSizes(theme, saved)
    saved = type(saved) == "table" and saved or {}
    local clean = {}
    for _, size in ipairs(DDT.SIZE_SPECS[theme]) do
        local value = saved[size.key]
        if type(value) ~= "number" then
            value = size.default
        end
        value = math.floor(value / size.step + 0.5) * size.step
        clean[size.key] = math.max(size.min, math.min(size.max, value))
    end
    clean.namePosition = Choice(saved.namePosition, DDT.NAME_POSITIONS[theme], DDT.DEFAULT_NAME_POSITION[theme])
    return clean
end

-- The DoT order: every slot key once, unknown and doubled keys dropped,
-- missing ones added in the class table's order.
local function SanitizeOrder(value, slots)
    local valid, seen, order = {}, {}, {}
    for _, slot in ipairs(slots) do
        valid[slot.key] = true
    end
    for _, key in ipairs(type(value) == "table" and value or {}) do
        if valid[key] and not seen[key] then
            seen[key] = true
            order[#order + 1] = key
        end
    end
    for _, slot in ipairs(slots) do
        if not seen[slot.key] then
            order[#order + 1] = slot.key
        end
    end
    return order
end

-- The saved settings, repaired; classData is your class's ClassData table
-- (nil: no table for your class, and only the generic keys are kept).
function DDT.SanitizeDB(db, classData)
    db = type(db) == "table" and db or {}
    classData = classData or {}
    local slots, spells = classData.dots or {}, classData.control or {}
    local dots = type(db.dots) == "table" and db.dots or {}
    local sizes = type(dots.sizes) == "table" and dots.sizes or {}
    local onPlates = type(dots.onPlates) == "table" and dots.onPlates or {}
    local panelOpacity = type(dots.panelOpacity) == "table" and dots.panelOpacity or {}
    local sections = type(dots.sections) == "table" and dots.sections or {}
    local clean = {
        enabled = Bool(dots.enabled, true), theme = Choice(dots.theme, {"compact", "bars"}, "bars"),
        sizes = {compact = SanitizeSizes("compact", sizes.compact), bars = SanitizeSizes("bars", sizes.bars)},
        order = SanitizeOrder(dots.order, slots), health = Bool(dots.health, false),
        healthText = Choice(dots.healthText, DDT.HEALTH_TEXTS, "none"), position = Place(dots.position),
        sections = {}, panelOpacity = {}, onPlates = {}, plateDots = Bool(dots.plateDots, false),
        plateDotsOffset = Whole(dots.plateDotsOffset, 0, 120, 50),
        plateDotsOpacity = Whole(dots.plateDotsOpacity, 10, 100, 100),
        trackerSize = dots.trackerSize, grow = {},
        -- Toolkit TRACKER_HIDE_EMPTY (treadpool, 2026-11-17; John: "Yes, build it").
        hideEmpty = Bool(dots.hideEmpty, false),
        -- Toolkit TRACKER_PANELS (a player, 2026-11-19; John: "a 3 panels
        -- toggle show/off, default to show"): only false hides a panel.
        show = {},
    }
    DDT.ApplyTrackerSize(clean)
    local grow = type(dots.grow) == "table" and dots.grow or {}
    local show = type(dots.show) == "table" and dots.show or {}
    for _, key in ipairs(DDT.PANELS) do
        clean.show[key] = show[key] ~= false
        clean.grow[key] = Choice(grow[key], DDT.GROW, "down")
        clean.sections[key] = Place(sections[key])
        clean.panelOpacity[key] = Whole(panelOpacity[key], 10, 100, 100)
    end
    for _, slot in ipairs(slots) do
        clean.onPlates[slot.key] = Bool(onPlates[slot.key], slot.dot ~= false)
        if slot.lastUsed and type(dots[slot.lastUsed]) == "string" then
            clean[slot.lastUsed] = dots[slot.lastUsed]
        end
    end
    db.dots = clean
    local predict = type(db.predict) == "table" and db.predict or {}
    local colors = {}
    for _, preset in ipairs(DDT.PREDICT_COLORS) do
        colors[#colors + 1] = preset.key
    end
    db.predict = {enabled = Bool(predict.enabled, true), plates = Bool(predict.plates, true),
        dies = Bool(predict.dies, true), fill = Choice(predict.fill, DDT.FILLS, "stripes"),
        color = Choice(predict.color, colors, "purple"), opacity = Whole(predict.opacity, 20, 100, 70),
        outline = Choice(predict.outline, {"none", "solid"}, "solid")}
    local places = {}
    for _, place in ipairs(DDT.DIES_PLACES) do
        places[#places + 1] = place[1]
    end
    for _, prefix in ipairs({"dies", "plateDies"}) do
        db.predict[prefix .. "Place"] = Choice(predict[prefix .. "Place"], places, "auto")
        db.predict[prefix .. "X"] = Whole(predict[prefix .. "X"], -DDT.DIES_OFFSET, DDT.DIES_OFFSET, 0)
        db.predict[prefix .. "Y"] = Whole(predict[prefix .. "Y"], -DDT.DIES_OFFSET, DDT.DIES_OFFSET, 0)
    end
    local control = type(db.control) == "table" and db.control or {}
    local markers = type(control.markers) == "table" and control.markers or {}
    local announce = type(control.announce) == "table" and control.announce or {}
    local texts = type(control.texts) == "table" and control.texts or {}
    local cleanControl = {enabled = Bool(control.enabled, true), plateTimers = Bool(control.plateTimers, true),
        macros = Bool(control.macros, true), say = Bool(control.say, false), position = Place(control.position),
        scale = Whole(control.scale, DDT.CONTROL_SCALE.min, DDT.CONTROL_SCALE.max, DDT.CONTROL_SCALE.default),
        markers = {}, announce = {}, texts = {}}
    for _, spell in ipairs(spells) do
        if spell.marker then
            local marker = markers[spell.key]
            cleanControl.markers[spell.key] = type(marker) == "number" and DDT.ValidMarker(marker) and marker
                or spell.marker
        end
        -- Off by default: a class Tools AddOn's own messages come first.
        cleanControl.announce[spell.key] = Bool(announce[spell.key], false)
        cleanControl.texts[spell.key] = Text(texts[spell.key], DDT.DefaultAnnounceText(spell))
    end
    db.control = cleanControl
    -- The Mage's frozen and chilled arcs (Frost.lua); kept for every class, used by Mages.
    local frost = type(db.frost) == "table" and db.frost or {}
    db.frost = {enabled = Bool(frost.enabled, true),
        offset = Whole(frost.offset, DDT.FROST_OFFSET.min, DDT.FROST_OFFSET.max, DDT.FROST_OFFSET.default),
        size = Whole(frost.size, DDT.FROST_SIZE.min, DDT.FROST_SIZE.max, DDT.FROST_SIZE.default)}
    -- The character macros this AddOn keeps (the toolkit's keeper), by name.
    local owned = type(db.macrosOwned) == "table" and db.macrosOwned or {}
    db.macrosOwned = {}
    for name, value in pairs(owned) do
        if type(name) == "string" and value == true then
            db.macrosOwned[name] = true
        end
    end
    return db
end

-- Raid markers 0-8, as /tm numbers them; the toolkit's list once it is there.
function DDT.ValidMarker(index)
    if DDT.toolkit then
        return DDT.toolkit.ValidMarker(index)
    end
    return type(index) == "number" and index >= 0 and index <= 8 and index == math.floor(index)
end

-- Startup and commands -------------------------------------------------------

local HELP = "/ddt opens the settings; /ddt reset puts the frames back; /ddt reset_focus checks the focus again; "
    .. "/ddt debug shows what the trackers see."

local function HandleCommand(message)
    local command = (message or ""):lower():match("^%s*(%S*)")
    if not DDT.available then
        DDT.Report(DDT.TOOLKIT_MISSING)
    elseif command == "" then
        DDT.OpenSettings()
    elseif command == "reset" then
        DDT.ResetPositions()
    elseif command == "reset_focus" then
        DDT.toolkit.ResetFocusWorks()
        DDT.Report("Focus check reset for every Dyre's AddOn. The macros try your focus, then the mob under the "
            .. "mouse, then your target, until a focus is seen to work.")
    elseif command == "debug" then
        for _, line in ipairs(DDT.DebugLines()) do
            DDT.Report(line)
        end
    else
        DDT.Report(HELP)
    end
end

SLASH_DYRESDEBUFFTRACKER1 = "/ddt"
SLASH_DYRESDEBUFFTRACKER2 = "/debufftracker"
SlashCmdList.DYRESDEBUFFTRACKER = HandleCommand

function DDT.OpenSettings()
    if DDT.category then
        DDT.toolkit.OpenSettings(DDT.category)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            DyresDebuffTrackerDB = type(DyresDebuffTrackerDB) == "table" and DyresDebuffTrackerDB or {}
            DDT.db = DyresDebuffTrackerDB
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    self:UnregisterEvent("ADDON_LOADED")
    DDT.db = DDT.db or {}
    DDT.toolkit = DDT.Toolkit()
    DDT.available = DDT.toolkit ~= nil
    if not DDT.available then
        DDT.Report(DDT.TOOLKIT_MISSING)
        return
    end
    DDT.Start()
    DDT.InitializeOptions()
    DDT.toolkit.RegisterAddOn({addon = addonName, title = DDT.TITLE, setLocked = DDT.SetLocked,
        openSettings = DDT.OpenSettings})
end)
