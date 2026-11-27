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
-- The target and focus panels' solid outline, in whole pixels (the Toolkit's
-- TRACKER_OUTLINE; a DDT player, 2026-11-20, GitHub issue 1); 0 draws none.
DDT.OUTLINE_WIDTH = {min = 0, max = 20, default = 3}
DDT.CONTROL_SCALE = {min = 50, max = 150, step = 5, default = 100}
-- The crowd-control bar's look (MTF's Polymorph bar settings, moved here for
-- every class; John: "Yes, move it"). The defaults draw the Toolkit's own
-- look (200 wide, a 16 px bar, the name line at 100%), so nothing changes
-- until you move a slider.
DDT.CONTROL_LOOK = {
    {key = "width", label = "Bar width", min = 120, max = 400, step = 10, default = 200},
    {key = "barHeight", label = "Bar height", min = 10, max = 40, step = 1, default = 16},
    {key = "textScale", label = "Text size", min = 50, max = 200, step = 5, default = 100, percent = true},
}
DDT.CONTROL_OPACITY = {min = 10, max = 100, step = 5, default = 100}

-- A whole number on the slider's steps, within its range, else the default.
local function Stepped(value, spec)
    if type(value) ~= "number" or value ~= value or value ~= math.floor(value) then
        return spec.default
    end
    value = math.floor(value / spec.step + 0.5) * spec.step
    return math.max(spec.min, math.min(spec.max, value))
end
-- "Tracker size" (John, 2026-11-14: "increasing or decreasing by up to 25%"):
-- one percent for both themes. Bars: the bar width; Compact: the icon size.
-- The name width and the text scale stay. The Toolkit reads the sizes.
DDT.TRACKER_SIZE = {min = 75, max = 125, step = 5, default = 100}

-- trackerSize false: the sizes were set one by one (the per-look sliders, or
-- Warlock Tools Forever's sizes copied over), so no percent overwrites them.
-- Each panel's color, as Warlock Tools Forever's defaults (the Toolkit's).
DDT.PANEL_COLORS = {target = "ff8787ed", focus = "ffe61a1a", list = "ff545454"}
DDT.CURSE_MODES = {"last", "smart"}

-- A color as the Settings color swatch stores it (AARRGGBB), else the default.
function DDT.SanitizeColor(value, default)
    if type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x$") then
        return value:lower()
    end
    return default
end

-- The percent, repaired: a number, on a step of 5, from 75 to 125.
function DDT.SanitizeTrackerSize(value)
    local spec = DDT.TRACKER_SIZE
    if type(value) ~= "number" or value ~= value then
        return spec.default
    end
    value = math.floor(value / spec.step + 0.5) * spec.step
    return math.max(spec.min, math.min(spec.max, value))
end

-- A size's default in a look ("bars", "barWidth" -> 290).
function DDT.SizeDefault(theme, key)
    for _, size in ipairs(DDT.SIZE_SPECS[theme]) do
        if size.key == key then
            return size.default
        end
    end
end

-- Writes the percent's sizes into dots.sizes, for both themes.
function DDT.ApplyTrackerSize(dots)
    local percent = DDT.SanitizeTrackerSize(dots.trackerSize)
    dots.trackerSize = percent
    local Default = DDT.SizeDefault
    dots.sizes.bars.barWidth = math.floor(Default("bars", "barWidth") * percent / 100 + 0.5)
    dots.sizes.compact.iconSize = math.floor(Default("compact", "iconSize") * percent / 100 + 0.5)
end

local function Bool(value, default)
    if type(value) == "boolean" then
        return value
    end
    return default
end

-- A panel's own settings, repaired; a missing value is the tracker-wide one
-- (`wide`, already repaired): health, healthText, frame, outlineWidth,
-- trackerSize (a percent, or false: sizes set one by one), and sizes.
function DDT.SanitizePanel(saved, wide)
    saved = type(saved) == "table" and saved or {}
    local sizes = type(saved.sizes) == "table" and saved.sizes or {}
    local percent = saved.trackerSize
    if percent == nil then
        percent = wide.trackerSize
    end
    local healthText = wide.healthText
    for _, mode in ipairs(DDT.HEALTH_TEXTS) do
        if saved.healthText == mode then
            healthText = mode
        end
    end
    local outline, spec = saved.outlineWidth, DDT.OUTLINE_WIDTH
    if type(outline) == "number" and outline == math.floor(outline) then
        outline = math.max(spec.min, math.min(spec.max, outline))
    else
        outline = wide.outlineWidth
    end
    local trackerSize = false
    if percent ~= false then
        trackerSize = DDT.SanitizeTrackerSize(percent)
    end
    local panel = {
        health = Bool(saved.health, wide.health),
        healthText = healthText,
        frame = Bool(saved.frame, wide.frame),
        outlineWidth = outline,
        trackerSize = trackerSize,
        sizes = {
            compact = DDT.SanitizeSizes("compact", type(sizes.compact) == "table" and sizes.compact or wide.sizes.compact),
            bars = DDT.SanitizeSizes("bars", type(sizes.bars) == "table" and sizes.bars or wide.sizes.bars),
        },
    }
    if panel.trackerSize ~= false then
        DDT.ApplyTrackerSize(panel)
    end
    return panel
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
DDT.SanitizeSizes = SanitizeSizes

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
        -- GitHub issue 1 (a player, 2026-11-20: "I'd like to hide all of that
        -- and only show the debuff bars"; John: "Build parts 1 and 2"): the
        -- outline width (Toolkit TRACKER_OUTLINE) and the rows' background and
        -- border (Toolkit TRACKER_FRAME; only false hides them).
        outlineWidth = Whole(dots.outlineWidth, DDT.OUTLINE_WIDTH.min, DDT.OUTLINE_WIDTH.max,
            DDT.OUTLINE_WIDTH.default),
        frame = dots.frame ~= false,
        -- Warlock Tools Forever's tracker settings, moved here (John, via the lead,
        -- 2026-11-20: "Users of WTF should manage their DoT tracking features
        -- in DDT ... This includes DoT Colors, tracker panels, etc."): each
        -- slot's and panel's color, and the Warlock's smart curse.
        colors = {}, panelColors = {},
        curseMode = Choice(dots.curseMode, DDT.CURSE_MODES, "last"),
        curseMarker = dots.curseMarker ~= false,
        -- "! Curse" has its own switch (John, 2026-11-27: "Keep ! Curse
        -- separate"): before, it followed control.macros, so a save without
        -- it starts from that.
        curseMacro = Bool(dots.curseMacro, not (type(db.control) == "table" and db.control.macros == false)),
    }
    if clean.trackerSize ~= false then
        DDT.ApplyTrackerSize(clean)
    end
    -- Each panel's own settings (the Toolkit's TRACKER_PANEL_OPTIONS; John,
    -- 2026-11-21: "each needs it's own config (size, border width, etc.)").
    -- Without saved panels (older saves, a WTF import, an older profile),
    -- the tracker-wide values above are each panel's starting values, once.
    local panels = type(dots.panels) == "table" and dots.panels or {}
    clean.panels = {}
    for _, key in ipairs(DDT.PANELS) do
        clean.panels[key] = DDT.SanitizePanel(panels[key], clean)
    end
    local panelColors = type(dots.panelColors) == "table" and dots.panelColors or {}
    for _, key in ipairs(DDT.PANELS) do
        clean.panelColors[key] = DDT.SanitizeColor(panelColors[key], DDT.PANEL_COLORS[key])
    end
    local grow = type(dots.grow) == "table" and dots.grow or {}
    local show = type(dots.show) == "table" and dots.show or {}
    for _, key in ipairs(DDT.PANELS) do
        clean.show[key] = show[key] ~= false
        clean.grow[key] = Choice(grow[key], DDT.GROW, "down")
        clean.sections[key] = Place(sections[key])
        clean.panelOpacity[key] = Whole(panelOpacity[key], 10, 100, 100)
    end
    local colors = type(dots.colors) == "table" and dots.colors or {}
    for _, slot in ipairs(slots) do
        clean.colors[slot.key] = DDT.SanitizeColor(colors[slot.key], DDT.SanitizeColor(slot.color, "ffffffff"))
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
        markers = {}, announce = {}, texts = {}, opacity = Stepped(control.opacity, DDT.CONTROL_OPACITY)}
    for _, spec in ipairs(DDT.CONTROL_LOOK) do
        cleanControl[spec.key] = Stepped(control[spec.key], spec)
    end
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
    -- The Warlock's Demonic Brand pentagram (Frost.lua); kept for every class, used by Warlocks.
    local brand = type(db.brand) == "table" and db.brand or {}
    db.brand = {enabled = Bool(brand.enabled, true),
        offset = Whole(brand.offset, DDT.BRAND_OFFSET.min, DDT.BRAND_OFFSET.max, DDT.BRAND_OFFSET.default),
        size = Whole(brand.size, DDT.BRAND_SIZE.min, DDT.BRAND_SIZE.max, DDT.BRAND_SIZE.default)}
    -- The Mage's Winter's Chill arc (Frost.lua); kept for every class, used by Mages.
    local chill = type(db.wintersChill) == "table" and db.wintersChill or {}
    db.wintersChill = {enabled = Bool(chill.enabled, true),
        offset = Whole(chill.offset, DDT.CHILL_OFFSET.min, DDT.CHILL_OFFSET.max, DDT.CHILL_OFFSET.default),
        size = Whole(chill.size, DDT.CHILL_SIZE.min, DDT.CHILL_SIZE.max, DDT.CHILL_SIZE.default),
        -- The stack chime (Chime.lua): on by default, as Dyre's Buff Reminders' was.
        chime = Bool(chill.chime, true),
        noteSet = DDT.ChillChimeSet(chill.noteSet) or DDT.CHILL_CHIME_DEFAULT}
    -- The class Tools AddOn's settings were copied (or there was nothing to
    -- copy): once per character, and a profile copy counts (DDT.ImportFromTools).
    db.toolsImported = db.toolsImported == true
    -- Dyre's Buff Reminders' Winter's Chill chime settings were copied (or
    -- there was nothing to copy): the same rules (DDT.ImportChillChime).
    db.chimeImported = db.chimeImported == true
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

-- A class Tools AddOn's settings, copied once -------------------------------

-- DDT is the one home of the Warlock's DoT tracker, damage to come, and
-- crowd-control bar (John, via the lead, 2026-11-20: "Users of WTF should
-- manage their DoT tracking features in DDT"; "Yes, full move") and of the
-- Mage's Polymorph bar (John: "Yes, move it"). WTF 1.11.0 and MTF 1.6.0 stop
-- claiming them; each keeps its old keys as the last older version saved
-- them (never deleted). Their per-character saved variables are read once
-- and never written.
-- What came over, said once in chat.
DDT.TOOLS_IMPORTED = "Copied your %s settings from %s. Change them here, under Dyre's Debuff Tracker."
-- WTF's default group texts end with its credit; DDT's say "via Dyre's Debuff Tracker".
local WTF_CREDIT = " - via Warlock Tools Forever (WTF)"
local DDT_CREDIT = " - via Dyre's Debuff Tracker"
-- The keys copied, as each AddOn saves them (WTF: Core.lua SanitizeDB and
-- Control.lua SanitizeControl; the WTF session's
-- wtf-1.11.0-ddt-import-keys.md. MTF: Core.lua SanitizeDB, 1.5.1). Left
-- out: WTF's lock copies (locked, placeholders), colorsVersion and
-- markersVersion. DDT's own keys they lack (grow, frame, trackerSize) stay.
DDT.WTF_KEYS = {
    tracker = {"enabled", "theme", "sizes", "order", "health", "healthText", "position", "sections",
        "panelOpacity", "onPlates", "plateDots", "plateDotsOffset", "plateDotsOpacity", "outlineWidth",
        "hideEmpty", "show", "colors", "panelColors", "curseMode", "curseMarker", "lastCurse", "lastBane",
        "lastControl"},
    predict = {"enabled", "plates", "dies", "fill", "color", "opacity", "outline", "diesPlace", "diesX", "diesY",
        "plateDiesPlace", "plateDiesX", "plateDiesY"},
    -- The bar's own settings; WTF had them only while its bar was on.
    control = {"enabled", "position", "scale", "plateTimers"},
    -- The macros and their markers: WTF kept the Warlock's macros whether its
    -- bar was on or off (the Toolkit's macros owner), so these always come.
    macros = {"macros", "markers"},
    -- The control spells' group messages (WTF's Announce page): DDT spell key
    -- -> WTF's switch. WTF owned the announcements whatever its bar switch.
    announce = {fear = "fearGroup", banish = "banishGroup", enslave = "enslaveGroup", howl = "howlGroup"},
}
-- MTF's db.polymorph -> DDT's db.control (the bar's own settings, while MTF's
-- bar was on); "height" is DDT's "barHeight".
DDT.MTF_KEYS = {bar = {enabled = "enabled", position = "position", scale = "scale", opacity = "opacity",
    width = "width", height = "barHeight", textScale = "textScale"},
    -- MTF's default place for a bar never moved (nil position): the bar stays
    -- where the player saw it (DDT's own default is lower).
    defaultPosition = {point = "CENTER", relativePoint = "CENTER", x = -260, y = 60}}

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, each in pairs(value) do
        copy[key] = Copy(each)
    end
    return copy
end

local function CopyKeys(from, to, keys)
    local copied = false
    for _, key in ipairs(keys) do
        if from[key] ~= nil then
            to[key] = Copy(from[key])
            copied = true
        end
    end
    return copied
end

-- A group text: WTF's credit becomes DDT's; else as written.
local function GroupText(text)
    if type(text) ~= "string" then
        return nil
    end
    if text:sub(-#WTF_CREDIT) == WTF_CREDIT then
        return text:sub(1, #text - #WTF_CREDIT) .. DDT_CREDIT
    end
    return text
end

local function ImportWTF(db, wtf)
    local copied = false
    local tracker = type(wtf.tracker) == "table" and wtf.tracker or nil
    if tracker and tracker.enabled ~= false then
        copied = CopyKeys(tracker, db.dots, DDT.WTF_KEYS.tracker) or copied
        if tracker.sizes ~= nil then
            -- WTF's sizes are kept as they are; no percent overwrites them.
            db.dots.trackerSize = false
        end
        -- WTF had one value for every panel: each panel starts from it.
        db.dots.panels = nil
    end
    local predict = type(wtf.predict) == "table" and wtf.predict or nil
    if predict and predict.enabled ~= false then
        copied = CopyKeys(predict, db.predict, DDT.WTF_KEYS.predict) or copied
    end
    local control = type(wtf.control) == "table" and wtf.control or nil
    if control then
        if control.enabled ~= false then
            copied = CopyKeys(control, db.control, DDT.WTF_KEYS.control) or copied
        end
        copied = CopyKeys(control, db.control, DDT.WTF_KEYS.macros) or copied
    end
    local announce = type(wtf.announce) == "table" and wtf.announce or nil
    if announce then
        db.control.announce = type(db.control.announce) == "table" and db.control.announce or {}
        db.control.texts = type(db.control.texts) == "table" and db.control.texts or {}
        for key, switch in pairs(DDT.WTF_KEYS.announce) do
            if type(announce[switch]) == "boolean" then
                -- WTF's master switch off silenced every message.
                db.control.announce[key] = announce[switch] and announce.enabled ~= false
                copied = true
            end
            db.control.texts[key] = GroupText(announce[switch .. "Text"]) or db.control.texts[key]
        end
        if announce.channel == "say" then
            db.control.say = true
        end
    end
    return copied
end

local function ImportMTF(db, mtf)
    local copied = false
    local polymorph = type(mtf.polymorph) == "table" and mtf.polymorph or nil
    if polymorph then
        if polymorph.enabled ~= false then
            for from, to in pairs(DDT.MTF_KEYS.bar) do
                if polymorph[from] ~= nil then
                    db.control[to] = Copy(polymorph[from])
                    copied = true
                end
            end
            if polymorph.position == nil then
                db.control.position = Copy(DDT.MTF_KEYS.defaultPosition)
            end
        end
        -- MTF kept "! Polymorph" and its moon whether its bar was on or off.
        if type(polymorph.macro) == "boolean" then
            db.control.macros = polymorph.macro
            copied = true
        end
        if polymorph.mark == false then
            db.control.markers = type(db.control.markers) == "table" and db.control.markers or {}
            db.control.markers.polymorph = 0
            copied = true
        end
    end
    local announce = type(mtf.announce) == "table" and mtf.announce or nil
    if announce then
        db.control.announce = type(db.control.announce) == "table" and db.control.announce or {}
        db.control.texts = type(db.control.texts) == "table" and db.control.texts or {}
        if type(announce.polymorphGroup) == "boolean" then
            -- MTF sent it only while its bar was on.
            db.control.announce.polymorph = announce.polymorphGroup and (not polymorph or polymorph.enabled ~= false)
            copied = true
        end
        db.control.texts.polymorph = GroupText(announce.polymorphGroupText) or db.control.texts.polymorph
    end
    return copied
end

-- Each class's Tools AddOn: its saved variables, the first version that
-- no longer claims (the handover), and what moved.
DDT.TOOLS_IMPORT = {
    WARLOCK = {addon = "WarlockToolsForever", title = "Warlock Tools Forever", saved = "WarlockToolsForeverDB",
        handover = "1.11.0", what = "DoT tracker, damage prediction, and crowd-control", copy = ImportWTF},
    MAGE = {addon = "MageToolsForever", title = "Mage Tools Forever", saved = "MageToolsForeverDB",
        handover = "1.6.0", what = "Polymorph bar", copy = ImportMTF},
}

local function AddOnVersion(addon)
    local read = type(C_AddOns) == "table" and C_AddOns.GetAddOnMetadata or rawget(_G, "GetAddOnMetadata")
    local value = type(read) == "function" and read(addon, "Version") or nil
    return type(value) == "string" and value or nil
end

local function AddOnLoaded(addon)
    local loaded = type(C_AddOns) == "table" and C_AddOns.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
    return type(loaded) == "function" and loaded(addon) == true
end
DDT.AddOnVersion, DDT.AddOnLoaded = AddOnVersion, AddOnLoaded

-- Once per character, before the engines are made. While the class's Tools
-- AddOn is loaded at a version that still claims (older than its handover,
-- or unreadable), it waits: that AddOn still has the parts, and its values
-- may still change. Then its values win, part by part, where it had that
-- part on: its claim (priority 10) won over DDT's (5), so DDT's values for
-- that part were never used; with it off, DDT's part showed, so DDT's stay.
-- Marked done once it ran, or when the AddOn is not loaded (nothing to read).
-- One chat line when something came over. Returns whether it did.
function DDT.ImportFromTools(db, class, classData)
    if db.toolsImported then
        return false
    end
    local source = DDT.TOOLS_IMPORT[class]
    if not source or not AddOnLoaded(source.addon) then
        db.toolsImported = true
        return false
    end
    local version = AddOnVersion(source.addon)
    if not version or not DDT.VersionAtLeast(version, source.handover) then
        return false
    end
    db.toolsImported = true
    local saved = rawget(_G, source.saved)
    if type(saved) ~= "table" then
        return false
    end
    local copied = source.copy(db, saved)
    DDT.SanitizeDB(db, classData)
    if copied then
        DDT.Report(string.format(DDT.TOOLS_IMPORTED, source.what, source.title))
    end
    return copied
end

DDT.CHIME_IMPORTED = "Copied your Winter's Chill chime settings from Dyre's Buff Reminders. Change them here, "
    .. "under Dyre's Debuff Tracker, Winter's Chill."

-- Dyre's Buff Reminders' Winter's Chill chime settings (DBR 1.9.0 to 1.13.2;
-- per character, DyresBuffRemindersDB.wintersChill = {enabled, noteSet},
-- kept as saved by DBR 1.13.3 for one release), once per character, for a
-- Mage. The ImportFromTools rules: it waits while DBR is loaded at a version
-- older than 1.13.3 (or unreadable), as that DBR still plays its chime and
-- its values may still change; it is marked done once it ran, or when DBR
-- is not loaded. Read only, through DBR's own rules: only false turns the
-- chime off; a note set other than bassoon or sax is not copied. One chat
-- line when something came. Returns whether it did.
function DDT.ImportChillChime(db, class)
    if db.chimeImported then
        return false
    end
    if class ~= "MAGE" or not AddOnLoaded(DDT.DBR_ADDON) then
        db.chimeImported = true
        return false
    end
    local version = AddOnVersion(DDT.DBR_ADDON)
    if not version or not DDT.VersionAtLeast(version, DDT.DBR_HANDOVER) then
        return false
    end
    db.chimeImported = true
    local saved = rawget(_G, "DyresBuffRemindersDB")
    local chill = type(saved) == "table" and saved.wintersChill
    if type(chill) ~= "table" then
        return false
    end
    db.wintersChill.chime = chill.enabled ~= false
    db.wintersChill.noteSet = DDT.ChillChimeSet(chill.noteSet) or db.wintersChill.noteSet
    DDT.Report(DDT.CHIME_IMPORTED)
    return true
end

-- The smart curse's key, from WTF's binding to DDT's (lead, from John): while
-- WTF's binding has a key and DDT's none, out of combat only. WTF 1.10.x
-- still defines its binding, so this runs at the first login with this DDT,
-- before WTF 1.11.0 removes it. Each login until DDT's has a key.
DDT.WTF_CURSE_BINDING = "CLICK WarlockToolsForeverSmartCurse:LeftButton"
DDT.CURSE_BINDING = "CLICK DyresDebuffTrackerSmartCurse:LeftButton"

function DDT.MoveCurseBinding()
    if type(GetBindingKey) ~= "function" or type(SetBinding) ~= "function" or InCombatLockdown() then
        return false
    end
    if GetBindingKey(DDT.CURSE_BINDING) then
        return false
    end
    local keys = {GetBindingKey(DDT.WTF_CURSE_BINDING)}
    if #keys == 0 then
        return false
    end
    for _, key in ipairs(keys) do
        SetBinding(key, DDT.CURSE_BINDING)
    end
    if type(SaveBindings) == "function" and type(GetCurrentBindingSet) == "function" then
        SaveBindings(GetCurrentBindingSet())
    end
    DDT.Report("Your Smart curse key (" .. table.concat(keys, ", ") .. ") now casts Dyre's Debuff Tracker's "
        .. "smart curse.")
    return true
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
    .. "/ddt debug shows what the trackers see; /ddt preview brand shows the Demonic Brand pentagram on your "
    .. "target (Warlocks, WoW: Forever); /ddt preview chill shows the Winter's Chill arc on your target (Mages)."

local function HandleCommand(message)
    local command, argument = (message or ""):lower():match("^%s*(%S*)%s*(%S*)")
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
    elseif command == "preview" and (argument == "chill" or (argument == "" and DDT.class == "MAGE")) then
        DDT.PreviewChill()
    elseif command == "preview" and (argument == "" or argument == "brand") then
        DDT.PreviewBrand()
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

-- The toolkit check, the saved settings' repair, and the engines, once. At
-- PLAYER_LOGIN, or earlier when a host AddOn (Warlock Tools Forever, Mage
-- Tools Forever) builds its page with our settings sections at its own
-- PLAYER_LOGIN before ours runs (Dyre's Toolkit 2.17.0: "a host builds its
-- page at its PLAYER_LOGIN, which may come before yours"). True when the
-- engines started.
function DDT.EnsureStarted()
    if DDT.started == nil then
        DDT.db = DDT.db or {}
        DDT.toolkit = DDT.Toolkit()
        DDT.available = DDT.toolkit ~= nil
        DDT.started = DDT.available
        if DDT.available then
            DDT.Start()
        end
    end
    return DDT.started == true
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
            -- Our settings sections, for the host pages (Options.lua).
            DDT.RegisterSettingsSections()
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    self:UnregisterEvent("ADDON_LOADED")
    if not DDT.EnsureStarted() then
        DDT.Report(DDT.TOOLKIT_MISSING)
        return
    end
    DDT.InitializeOptions()
    DDT.toolkit.RegisterAddOn({addon = addonName, title = DDT.TITLE, setLocked = DDT.SetLocked,
        openSettings = DDT.OpenSettings})
end)
