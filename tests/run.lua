-- Lua 5.1 mock suite for Dyre's Debuff Tracker. Run from the AddOn folder:
--   lua5.1 tests/run.lua
-- It loads Dyre's Toolkit's real files from ../DyresToolkit when that folder
-- is there; else (as in CI, which has only this repository, or with
-- DDT_TOOLKIT_COPY=1) from the copy in tests/toolkit (Toolkit v2.9.2). The
-- copy may lag; the tests check behavior, never that the two match.

if _VERSION ~= "Lua 5.1" then
    io.stderr:write("This suite requires Lua 5.1; found " .. tostring(_VERSION) .. "\n")
    os.exit(1)
end

local TOOLKIT = "tests/toolkit/"
if os.getenv("DDT_TOOLKIT_COPY") ~= "1" then
    local probe = io.open("../DyresToolkit/DotPredict.lua", "rb")
    if probe then
        probe:close()
        TOOLKIT = "../DyresToolkit/"
    end
end
print("Dyre's Toolkit from " .. TOOLKIT)
local TOOLKIT_FILES = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Auras.lua", "Units.lua",
    "HealthBars.lua", "Spells.lua", "Macros.lua", "Announce.lua", "ClassData.lua", "Owners.lua", "Control.lua",
    "DotTracker.lua", "PlateDots.lua", "DotPredict.lua"}
local OLD_TOOLKIT = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Auras.lua", "Units.lua",
    "HealthBars.lua"}
local RUNTIME = {"Core.lua", "Engines.lua", "Options.lua"}
local tests = {}

local function test(name, body)
    tests[#tests + 1] = {name = name, body = body}
end

local function equal(actual, expected, context)
    if actual ~= expected then
        error((context and context .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
            .. tostring(actual), 2)
    end
end

local function contains(text, fragment, context)
    if type(text) ~= "string" or not text:find(fragment, 1, true) then
        error((context and context .. ": " or "") .. "expected " .. tostring(text) .. " to contain " .. fragment, 2)
    end
end

-- A client object: unknown capitalized methods are no-ops that return nothing.
local function stub(fields)
    local object = fields or {}
    return setmetatable(object, {__index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() end end
    end})
end

local function newFrame(state, kind, name, parent, template)
    local frame = stub({kind = kind, name = name, parent = parent, template = template, shown = true,
        attributes = {}, events = {}, scripts = {}, level = 1, scale = 1, alpha = 1, width = 1, height = 1})
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(shown) self.shown = shown and true or false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    function frame:GetAttribute(key) return self.attributes[key] end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:GetScript(script) return self.scripts[script] end
    function frame:GetFrameLevel() return self.level end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:SetScale(scale) self.scale = scale end
    function frame:GetScale() return self.scale end
    function frame:GetEffectiveScale() return self.scale end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:SetPoint(...) self.point = {...} end
    function frame:GetNumPoints() return self.point and 1 or 0 end
    function frame:GetPoint() if self.point then return unpack(self.point) end end
    function frame:GetCenter() return 0, 0 end
    function frame:SetParent(newParent) self.parent = newParent end
    function frame:IsForbidden() return false end
    function frame:IsProtected() return template == "SecureActionButtonTemplate" end
    function frame:CreateFontString()
        local text = stub()
        function text:SetText(value) self.text = value end
        function text:GetFont() return "Fonts\\FRIZQT__.TTF", 10, "" end
        return text
    end
    function frame:CreateTexture() return stub() end
    function frame:CreateMaskTexture() return stub() end
    state.frames[#state.frames + 1] = frame
    if name then
        state.named[name] = frame
    end
    return frame
end

local function emit(state, event, ...)
    for _, frame in ipairs(state.frames) do
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end

local SPELLS = {[172] = "Corruption", [348] = "Immolate", [980] = "Curse of Agony", [5782] = "Fear",
    [710] = "Banish", [6358] = "Seduction", [118] = "Polymorph", [5484] = "Howl of Terror",
    -- The other classes' first ranks (the class gate).
    [133] = "Fireball", [11366] = "Pyroblast", [8921] = "Moonfire", [339] = "Entangling Roots",
    [2637] = "Hibernate", [1978] = "Serpent Sting", [1513] = "Scare Beast", [589] = "Shadow Word: Pain",
    [9484] = "Shackle Undead", [1943] = "Rupture", [6770] = "Sap", [2094] = "Blind", [8050] = "Flame Shock",
    [772] = "Rend", [5246] = "Intimidating Shout", [2878] = "Turn Undead", [20066] = "Repentance"}

-- The client for one character: its class, its spells, the AddOns loaded.
local function fixture(options)
    options = options or {}
    local state = {messages = {}, frames = {}, named = {}, macros = {}, settings = {}, pages = {}, headings = {},
        timers = {}, now = 100}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.SlashCmdList = {}
    env.DEFAULT_CHAT_FRAME = {AddMessage = function(_, message) state.messages[#state.messages + 1] = message end}
    env.UIParent = newFrame(state, "Frame", "UIParent")
    env.CreateFrame = function(kind, name, parent, template) return newFrame(state, kind, name, parent, template) end
    env.InCombatLockdown = function() return state.combat == true end
    env.GetTime = function() return state.now end
    env.C_Timer = {After = function(delay, fn) state.timers[#state.timers + 1] = fn end}
    env.UnitClass = function() return options.className or "Warlock", options.class or "WARLOCK" end
    env.UnitGUID = function(unit) return unit == "player" and "Player-1" or nil end
    env.UnitExists = function() return false end
    env.UnitName = function() return nil end
    env.UnitIsDead = function() return false end
    env.UnitCanAttack = function() return false end
    env.UnitAffectingCombat = function() return false end
    env.UnitIsUnit = function() return false end
    env.GetZoneText = function() return "Orgrimmar" end
    env.IsInRaid = function() return false end
    env.IsInGroup = function() return false end
    env.RegisterStateDriver = function() end
    env.UnregisterStateDriver = function() end
    env.GameTooltip = stub()
    env.Enum = {SpellBookItemType = {Spell = 1, FutureSpell = 2}, SpellBookSpellBank = {Player = 0, Pet = 1},
        StatusBarTimerDirection = {RemainingTime = 1}}
    env.C_Spell = {GetSpellName = function(id) return SPELLS[id] end, GetSpellTexture = function() return 1 end}
    local book = options.book or {{172, "Corruption"}, {348, "Immolate"}, {5782, "Fear"}, {710, "Banish"}}
    local known = {}
    for _, item in ipairs(book) do known[item[1]] = true end
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #book} end,
        GetSpellBookItemInfo = function(index) local item = book[index]
            return item and {spellID = item[1], name = item[2], itemType = 1} end,
        IsSpellKnown = function(id) return known[id] == true end,
        HasPetSpells = function() return 0 end,
    }
    env.C_UnitAuras = {GetAuraDataByIndex = function() return nil end}
    env.C_NamePlate = {GetNamePlateForUnit = function() return nil end}
    env.C_CombatLog = {GetCurrentEventInfo = function() end,
        IsCombatLogRestricted = function() return options.restricted == true end}
    -- The AddOns: Dyre's family members by TOC Group, versions, and which are loaded.
    local loaded = options.loaded or {}
    env.C_AddOns = {
        GetAddOnMetadata = function(addon, field)
            if field == "Group" then return (addon == "DyresDebuffTracker" or loaded[addon]) and "DyresToolkit" or nil end
            if field == "Version" then return loaded[addon] end
            if field == "Title" then
                return ({WarlockToolsForever = "Warlock Tools Forever", MageToolsForever = "Mage Tools Forever"})[addon]
            end
        end,
        IsAddOnLoaded = function(addon) return loaded[addon] ~= nil end,
    }
    -- Character macros.
    env.Constants = {MacroConsts = {MAX_CHARACTER_MACROS = 18}}
    env.GetMacroIndexByName = function(name)
        for index, macro in ipairs(state.macros) do if macro.name == name then return index end end
        return 0
    end
    env.GetNumMacros = function() return 0, #state.macros end
    env.GetMacroBody = function(index) return state.macros[index].body end
    env.CreateMacro = function(name, _, body) state.macros[#state.macros + 1] = {name = name, body = body} end
    env.EditMacro = function(index, name, _, body) state.macros[index] = {name = name, body = body} end
    env.DeleteMacro = function(index) table.remove(state.macros, index) end
    env.SetRaidTarget = function() error("never SetRaidTarget") end
    for _, macro in ipairs(options.macros or {}) do state.macros[#state.macros + 1] = macro end
    -- The settings panel: pages, headings, and proxy settings by variable.
    local function Category(name)
        local object = {name = name, initializers = {}}
        function object:GetID() return "id:" .. self.name end
        return object
    end
    local function Layout(category)
        return {AddInitializer = function(_, initializer)
            state.headings[#state.headings + 1] = category.name .. ": " .. tostring(initializer.text)
        end}
    end
    local function Initializer(setting)
        return {setting = setting, AddModifyPredicate = function(self, predicate) self.modify = predicate end,
            SetParentInitializer = function() end}
    end
    if not options.noSettings then
        env.Settings = {
            VarType = {Boolean = "boolean", Number = "number", String = "string"},
            RegisterVerticalLayoutCategory = function(name) local c = Category(name); return c, Layout(c) end,
            RegisterVerticalLayoutSubcategory = function(parent, name)
                local c = Category(name)
                state.pages[#state.pages + 1] = parent.name .. " > " .. name
                return c, Layout(c)
            end,
            RegisterAddOnCategory = function() end,
            RegisterProxySetting = function(category, variable, kind, name, default, get, set)
                local setting = {category = category.name, variable = variable, name = name, get = get, set = set,
                    default = default}
                state.settings[variable] = setting
                return setting
            end,
            CreateCheckbox = function(_, setting) setting.initializer = Initializer(setting); return setting.initializer end,
            CreateDropdown = function(_, setting) setting.initializer = Initializer(setting); return setting.initializer end,
            CreateControlTextContainer = function()
                return {Add = function() end, GetData = function() return {} end}
            end,
            CreateSlider = function(_, setting) setting.initializer = Initializer(setting); return setting.initializer end,
            CreateSliderOptions = function() return {} end,
            OpenToCategory = function(id) state.opened = id end,
        }
        env.CreateSettingsListSectionHeaderInitializer = function(text) return {text = text} end
    end
    env.DyresToolkitDB = {snapToGrid = false}
    env.DyresDebuffTrackerDB = options.saved
    if not options.noToolkit then
        local ns = {InitializeMinimap = function() end}
        for _, path in ipairs(options.toolkitFiles or TOOLKIT_FILES) do
            local chunk = assert(loadfile(TOOLKIT .. path))
            setfenv(chunk, env)
            chunk("DyresToolkit", ns)
        end
        state.toolkit = env.DyresToolkit
    end
    -- Another Dyre's AddOn's claims, made before this one's login.
    if options.before then
        options.before(state)
    end
    local ddt = {}
    local first = #state.frames + 1
    for _, path in ipairs(RUNTIME) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk("DyresDebuffTracker", ddt)
    end
    local events = state.frames[first]
    events.scripts.OnEvent(events, "ADDON_LOADED", "DyresDebuffTracker")
    events.scripts.OnEvent(events, "PLAYER_LOGIN")
    state.env, state.ddt, state.events = env, ddt, events
    function state.said(fragment)
        for _, message in ipairs(state.messages) do
            if message:find(fragment, 1, true) then return true end
        end
        return false
    end
    function state.heading(fragment)
        for _, text in ipairs(state.headings) do
            if text:find(fragment, 1, true) then return text end
        end
    end
    return state
end

test("without the toolkit, or with one older than 2.5 or 2.9.1, it says once what to install and does nothing", function()
    for _, options in ipairs({{noToolkit = true}, {toolkitFiles = OLD_TOOLKIT},
            {loaded = {DyresToolkit = "2.9.0"}}, {loaded = {DyresToolkit = "2.5.3"}}}) do
        local state = fixture(options)
        equal(state.ddt.available, false)
        equal(#state.messages, 1)
        equal(state.messages[1], "DDT: " .. state.ddt.TOOLKIT_MISSING)
        equal(state.named.DyresDebuffTrackerTarget, nil, "no frames")
        equal(#state.pages, 0, "no pages")
    end
end)

test("a Warlock gets the DoT tracker, the dots, the prediction, and the control bar, at priority 5", function()
    local state = fixture()
    local ddt, toolkit = state.ddt, state.toolkit
    equal(ddt.available, true)
    equal(ddt.class, "WARLOCK")
    assert(ddt.dotTracker and ddt.plateDots and ddt.predictor and ddt.controlTracker, "every engine")
    for _, name in ipairs({"DyresDebuffTrackerTarget", "DyresDebuffTrackerFocus", "DyresDebuffTrackerList",
        "DyresDebuffTrackerControl", "DyresDebuffTrackerControlRow1", "DyresDebuffTrackerControlClick5",
        "DyresDebuffTrackerControlFocus"}) do
        assert(state.named[name], name)
    end
    equal(toolkit.KindOwner("dots:WARLOCK"), "DyresDebuffTracker")
    equal(toolkit.KindOwner("control:WARLOCK"), "DyresDebuffTracker")
    equal(toolkit.HealthBars.IsActiveSource("DyresDebuffTracker"), true)
    equal(ddt.KindStatus("dots"), "ours")
    equal(#state.messages, 0, "nothing said at login")
end)

test("two settings pages, DoTs and Crowd control, each with its own on/off switch", function()
    local state = fixture()
    equal(table.concat(state.pages, "|"), "Dyre's AddOns > Debuff Tracker|Debuff Tracker > DoTs|Debuff Tracker > Crowd control")
    local dots, control = state.settings.DDT_DOTS, state.settings.DDT_CONTROL
    equal(dots.category, "DoTs")
    equal(control.category, "Crowd control")
    equal(dots.get(), true)
    control.set(false)
    equal(state.ddt.db.control.enabled, false)
    equal(state.toolkit.KindOwner("control:WARLOCK"), nil, "off steps aside")
    equal(state.ddt.KindStatus("dots"), "ours", "the DoTs stay on")
    dots.set(false)
    equal(state.toolkit.KindOwner("dots:WARLOCK"), nil)
    assert(state.settings.DDT_ANNOUNCE_FEAR and state.settings.DDT_CONTROL_MARKER_BANISH, "per spell")
    equal(state.settings.DDT_ANNOUNCE_FEAR.get(), false, "announcements start off")
    equal(state.settings.DDT_CONTROL_MARKER_BANISH.get(), 5, "the moon")
    assert(state.settings.DDT_PREDICT, "the prediction, where the combat log runs")
end)

test("with Warlock Tools Forever 1.4.1 loaded (it never claims), DDT makes nothing for the Warlock", function()
    local state = fixture({loaded = {WarlockToolsForever = "1.4.1"}})
    local ddt = state.ddt
    equal(ddt.yieldsTo.addon, "WarlockToolsForever")
    equal(ddt.dotTracker, nil)
    equal(ddt.controlTracker, nil)
    equal(state.named.DyresDebuffTrackerTarget, nil, "no frames")
    equal(state.named.DyresDebuffTrackerControlRow1, nil)
    equal(#state.macros, 0, "no macros written")
    equal(ddt.KindStatus("control"), "Warlock Tools Forever")
    contains(state.heading("Warlock Tools Forever has your DoTs"), "Debuff Tracker:")
    contains(state.heading("has this for your class"), "Warlock Tools Forever")
end)

test("a Warlock Tools Forever that claims wins by priority, and DDT's pages say so", function()
    local state = fixture({loaded = {WarlockToolsForever = "1.5.0"}, before = function(state)
        state.toolkit.ClaimOwner("control:WARLOCK", "WarlockToolsForever", 10)
        state.toolkit.ClaimOwner("dots:WARLOCK", "WarlockToolsForever", 10)
        state.toolkit.ClaimOwner("macros:WARLOCK", "WarlockToolsForever", 10)
    end})
    local ddt = state.ddt
    equal(ddt.yieldsTo, nil, "a newer one claims: the claims decide")
    assert(ddt.controlTracker, "the engines are made")
    equal(ddt.controlTracker:IsOwner("control"), false)
    equal(ddt.dotTracker:IsOwner(), false)
    equal(ddt.KindStatus("control"), "Warlock Tools Forever")
    equal(#state.macros, 0, "WTF keeps the macros")
    equal(state.settings.DDT_CONTROL.initializer.modify(), false, "greyed")
    state.toolkit.SetOwnerEnabled("control:WARLOCK", "WarlockToolsForever", false)
    equal(ddt.KindStatus("control"), "ours", "WTF's bar off: DDT's shows")
    equal(state.settings.DDT_CONTROL.initializer.modify(), true)
end)

test("a Mage gets the Polymorph bar and macro, the Fireball DoTs, and no Focus box", function()
    local state = fixture({class = "MAGE", className = "Mage", book = {{118, "Polymorph"}, {133, "Fireball"}}})
    local ddt = state.ddt
    assert(ddt.dotTracker and ddt.predictor, "Fireball, Pyroblast, and Frostfire Bolt")
    equal(ddt.dotTracker:KnowsSlot("fireball"), true)
    equal(ddt.dotTracker:KnowsSlot("pyroblast"), false, "a talent not learned")
    assert(ddt.controlTracker, "the Polymorph bar")
    equal(ddt.controlTracker.focusBox, nil, "Polymorph clicks: no Focus box")
    equal(state.named.DyresDebuffTrackerControlFocus, nil)
    equal(state.macros[1].name, "! Polymorph")
    contains(state.macros[1].body, "Polymorph")
    equal(state.heading("Your class has no DoTs here yet"), nil)
end)

-- Every new class (the class gate, lead 2026-11-14): what its table makes.
-- {class, className, spellbook, dots?, control?, the Focus box key, macros written}
local CLASS_ROWS = {
    {"DRUID", "Druid", {{8921, "Moonfire"}, {339, "Entangling Roots"}, {2637, "Hibernate"}}, true, true, "roots",
        {"! Hibernate"}},
    {"HUNTER", "Hunter", {{1978, "Serpent Sting"}, {1513, "Scare Beast"}}, true, true, "scarebeast", {}},
    {"PRIEST", "Priest", {{589, "Shadow Word: Pain"}, {9484, "Shackle Undead"}}, true, true, nil, {"! Shackle"}},
    {"ROGUE", "Rogue", {{1943, "Rupture"}, {6770, "Sap"}, {2094, "Blind"}}, true, true, "blind", {"! Sap"}},
    {"SHAMAN", "Shaman", {{8050, "Flame Shock"}}, true, false, nil, {}},
    {"WARRIOR", "Warrior", {{772, "Rend"}, {5246, "Intimidating Shout"}}, true, true, nil, {}},
    {"PALADIN", "Paladin", {{2878, "Turn Undead"}, {20066, "Repentance"}}, false, true, "turnundead",
        {"! Repentance"}},
}

test("every new class gets the engines its table has, at priority 5, with its macros and pages", function()
    for _, row in ipairs(CLASS_ROWS) do
        local class = row[1]
        local state = fixture({class = class, className = row[2], book = row[3]})
        local ddt, toolkit = state.ddt, state.toolkit
        equal(ddt.class, class)
        assert(ddt.classData, class .. " has a table")
        equal(ddt.dotTracker ~= nil, row[4], class .. " DoT tracker")
        equal(ddt.predictor ~= nil, row[4], class .. " prediction")
        equal(ddt.controlTracker ~= nil, row[5], class .. " control bar")
        if row[4] then
            equal(toolkit.KindOwner("dots:" .. class), "DyresDebuffTracker", class)
            equal(ddt.dotTracker:KnowsSlot(ddt.classData.dots[1].key), true, class .. " knows its first DoT")
            equal(toolkit.HealthBars.IsActiveSource("DyresDebuffTracker"), true, class)
        else
            assert(state.heading("Your class has no DoTs here yet"), class .. ": the DoTs page says so")
        end
        if row[5] then
            equal(toolkit.KindOwner("control:" .. class), "DyresDebuffTracker", class)
            local focus = ddt.controlTracker.focusBox
            equal(focus and focus.key, row[6], class .. " Focus box")
            equal(state.named.DyresDebuffTrackerControlFocus ~= nil, row[6] ~= nil, class .. " Focus box frame")
            for _, spell in ipairs(ddt.classData.control) do
                assert(state.settings["DDT_ANNOUNCE_" .. spell.key:upper()], class .. " announce " .. spell.key)
                if spell.marker then
                    equal(state.settings["DDT_CONTROL_MARKER_" .. spell.key:upper()].get(), 5, spell.key .. " moon")
                end
            end
        end
        local names = {}
        for _, macro in ipairs(state.macros) do names[#names + 1] = macro.name end
        equal(table.concat(names, ","), table.concat(row[7], ","), class .. " macros")
        for _, macro in ipairs(state.macros) do
            assert(#macro.body <= 255, macro.name .. " fits")
            contains(macro.body, "/tm [@", macro.name .. " marks through /tm")
        end
        equal(#state.messages, 0, class .. ": nothing said at login")
    end
end)

test("a Druid's Entangling Roots is in the DoT tracker and on the crowd-control bar", function()
    local state = fixture({class = "DRUID", className = "Druid", book = {{339, "Entangling Roots"}}})
    local ddt = state.ddt
    equal(ddt.dotTracker:KnowsSlot("roots"), true)
    equal(ddt.controlTracker:KnowsAny(), true)
    assert(state.settings.DDT_ANNOUNCE_ROOTS, "announced as crowd control")
    local order = table.concat(ddt.db.dots.order, ",")
    equal(order, "moonfire,insect,roots,rake,rip,pounce,lacerate")
end)

test("a class with no table gets nothing but its pages' note", function()
    local state = fixture({class = "DEATHKNIGHT", className = "Death Knight", book = {}})
    local ddt = state.ddt
    equal(ddt.classData, nil)
    equal(ddt.dotTracker, nil)
    equal(ddt.controlTracker, nil)
    assert(state.heading("nothing for your class yet"), "said on the page")
    equal(#state.messages, 0, "not in chat")
    equal(type(ddt.db.dots), "table", "the saved settings are still repaired")
end)

test("WTF's macro of the same name is adopted once, and the saved table remembers it", function()
    local saved = {}
    local state = fixture({saved = saved, macros = {{name = "! Fear", body = "WTF's"}}})
    equal(state.said("keeps your \"! Fear\" macro now"), true)
    equal(saved.macrosOwned["! Fear"], true)
    local count = 0
    for _, macro in ipairs(state.macros) do
        if macro.name == "! Fear" then count = count + 1 end
    end
    equal(count, 1, "never a second copy")
    local again = fixture({saved = saved, macros = state.macros})
    equal(again.said("keeps your"), false, "not again after a reload")
end)

test("the saved settings are repaired: bad values give the defaults, good ones stay", function()
    local state = fixture({saved = {dots = {theme = "neon", order = {"siphon", "siphon", "nope"},
        sizes = {bars = {barWidth = 9999, lineHeight = 13.4}}, healthText = "percent", panelOpacity = {list = 5}},
        predict = {color = "pink", opacity = 50, plateDiesX = 300}, control = {markers = {banish = 42}, texts = {fear = "Run, %T!"},
        announce = {fear = true}, scale = 7}, macrosOwned = {["! Fear"] = true, bad = "yes"}}})
    local db = state.ddt.db
    equal(db.dots.theme, "bars")
    equal(db.dots.order[1], "siphon", "kept first, once")
    equal(#db.dots.order, 6, "every slot")
    equal(db.dots.sizes.bars.barWidth, 290, "the Tracker size percent sets it (100%)")
    equal(db.dots.sizes.bars.lineHeight, 13)
    equal(db.dots.sizes.compact.iconSize, 22)
    equal(db.dots.healthText, "percent")
    equal(db.dots.panelOpacity.list, 10)
    equal(db.predict.color, "purple")
    equal(db.predict.opacity, 50)
    equal(db.predict.diesPlace, "auto", "Auto by default")
    equal(db.predict.plateDiesX, 100, "at most 100")
    do assert(state.settings.DDT_PREDICT_DIES_PLACE, "the DIES place setting")
        state.settings.DDT_PREDICT_DIES_PLACE.set("center")
        state.settings.DDT_PREDICT_PLATE_DIES_Y.set(-12.4)
        equal(db.predict.diesPlace, "center")
        equal(db.predict.plateDiesY, -12)
    end
    equal(db.control.markers.banish, 5, "not a marker: the default")
    equal(db.control.texts.fear, "Run, %T!")
    equal(db.control.announce.fear, true)
    equal(db.control.announce.banish, false)
    contains(db.control.texts.banish, "Banish on >> %T << %M")
    equal(db.control.texts.howl, "Howl of Terror! - via Dyre's Debuff Tracker")
    equal(db.control.scale, 50)
    equal(db.macrosOwned["! Fear"], true)
    equal(db.macrosOwned.bad, nil)
end)

-- John, 2026-11-14: "a 'Tracker size' slider ... increasing or decreasing by up to 25%".
test("Tracker size: one percent, 75 to 125, sets the bar width and the compact icon size", function()
    local state = fixture()
    local db, setting = state.ddt.db, state.settings.DDT_DOTS_TRACKER_SIZE
    assert(setting, "the slider on the DoTs page")
    equal(setting.category, "DoTs")
    equal(setting.default, 100)
    equal(db.dots.trackerSize, 100)
    equal(db.dots.sizes.bars.barWidth, 290, "default bar width")
    equal(db.dots.sizes.compact.iconSize, 22, "default icon size")
    local list = state.named.DyresDebuffTrackerList
    equal(list.width, 290, "the Bars list is 290 wide")
    setting.set(75)
    equal(db.dots.trackerSize, 75)
    equal(db.dots.sizes.bars.barWidth, 218)
    equal(db.dots.sizes.compact.iconSize, 17)
    equal(list.width, 218, "the tracker follows at once out of combat")
    setting.set(125)
    equal(db.dots.sizes.bars.barWidth, 363)
    equal(db.dots.sizes.compact.iconSize, 28)
    equal(list.width, 363)
    equal(db.dots.sizes.compact.nameWidth, 110, "the name width stays")
    equal(db.dots.sizes.bars.textScale, 100, "the text scale stays")
    -- A theme switch keeps the percent: Compact's icons are 28 at 125%.
    state.settings.DDT_DOTS_THEME.set("compact")
    equal(db.dots.trackerSize, 125)
    equal(db.dots.sizes.compact.iconSize, 28)
    state.settings.DDT_DOTS_THEME.set("bars")
    equal(list.width, 363, "back to Bars, still 125%")
    -- In combat the rebuild waits for its end.
    state.combat = true
    setting.set(90)
    equal(db.dots.sizes.bars.barWidth, 261, "saved at once")
    equal(list.width, 363, "no rebuild in combat")
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    equal(list.width, 261, "rebuilt when combat ends")
    setting.set(200)
    equal(db.dots.trackerSize, 125, "the slider's value is clamped")
    -- Bad saved values are repaired.
    for _, case in ipairs({{"big", 100}, {200, 125}, {10, 75}, {0 / 0, 100}, {83, 85}, {112.4, 110}}) do
        local repaired = fixture({saved = {dots = {trackerSize = case[1]}}}).ddt.db.dots
        equal(repaired.trackerSize, case[2], "saved " .. tostring(case[1]))
        equal(repaired.sizes.bars.barWidth, math.floor(290 * case[2] / 100 + 0.5))
    end
end)

-- John, 2026-11-14: "for each frame (Target, Focus, Other) ... whether the
-- DoTs should grow up or down from the origin".
test("Grow: Down or Up per DoT panel, repaired, rebuilt, and shown only with a Toolkit that has it", function()
    local realGrow
    local function WithGrow(state)
        realGrow = state.toolkit.TRACKER_GROW ~= nil
        state.toolkit.TRACKER_GROW = state.toolkit.TRACKER_GROW or {"down", "up"}
    end
    local state = fixture({before = WithGrow})
    local db = state.ddt.db
    for _, key in ipairs({"target", "focus", "list"}) do
        equal(db.dots.grow[key], "down", key .. " grows down by default")
        local setting = state.settings["DDT_DOTS_GROW_" .. key:upper()]
        assert(setting, key .. " has a Grow setting")
        equal(setting.category, "DoTs")
        equal(setting.default, "down")
        equal(setting.get(), "down")
    end
    equal(state.settings.DDT_DOTS_GROW_LIST.name, "Grow: Others")
    local rebuilds, tracker = 0, state.ddt.dotTracker
    local rebuild = tracker.Rebuild
    tracker.Rebuild = function(self) rebuilds = rebuilds + 1; return rebuild(self) end
    state.settings.DDT_DOTS_GROW_TARGET.set("up")
    equal(db.dots.grow.target, "up")
    equal(db.dots.grow.focus, "down", "one panel at a time")
    equal(rebuilds, 1, "a change rebuilds the tracker")
    state.settings.DDT_DOTS_GROW_FOCUS.set("up")
    state.settings.DDT_DOTS_GROW_LIST.set("up")
    equal(db.dots.grow.focus, "up")
    equal(db.dots.grow.list, "up")
    equal(rebuilds, 3)
    if realGrow then
        -- The Toolkit with the grow change: a list not yet dragged sits above the stack.
        equal(state.named.DyresDebuffTrackerList.point[1], "BOTTOMLEFT", "the Others list grows up")
    end
    -- Bad saved values are repaired; good ones stay.
    local repaired = fixture({before = WithGrow,
        saved = {dots = {grow = {target = "up", focus = "sideways", list = 7}}}}).ddt.db.dots.grow
    equal(repaired.target, "up")
    equal(repaired.focus, "down")
    equal(repaired.list, "down")
    equal(fixture({saved = {dots = {grow = "up"}}}).ddt.db.dots.grow.list, "down", "not a table")
    -- The gate: a Toolkit without TRACKER_GROW (2.9.1) shows no Grow settings.
    local old = fixture({before = function(s) s.toolkit.TRACKER_GROW = nil end})
    equal(old.settings.DDT_DOTS_GROW_TARGET, nil, "no Grow setting without the Toolkit's grow")
    equal(old.settings.DDT_DOTS_GROW_LIST, nil)
    equal(old.ddt.db.dots.grow.target, "down", "still saved and repaired")
end)

test("Toolkit 2.9.1 or later is used; an unreadable version is let through", function()
    for _, version in ipairs({"2.9.1", "2.9.2", "2.10.0", "3.0.0"}) do
        local state = fixture({loaded = {DyresToolkit = version}})
        equal(state.ddt.available, true, version)
        equal(#state.messages, 0, version)
    end
    equal(fixture().ddt.available, true, "no version read")
    contains(fixture({noToolkit = true}).ddt.TOOLKIT_MISSING, "2.9.1 or later")
    local ddt = fixture().ddt
    equal(ddt.VersionAtLeast("2.9.1", "2.9.1"), true)
    equal(ddt.VersionAtLeast("2.10", "2.9.1"), true)
    equal(ddt.VersionAtLeast("2.9", "2.9.1"), false)
    equal(ddt.VersionAtLeast("1.99.99", "2.9.1"), false)
end)

test("versions compare part by part", function()
    local state = fixture()
    local at = state.ddt.VersionAtMost
    equal(at("1.4.1", "1.4.1"), true)
    equal(at("1.4.0", "1.4.1"), true)
    equal(at("1.4.10", "1.4.9"), false)
    equal(at("1.5", "1.4.1"), false)
    equal(at("2.0.0-beta", "1.4.1"), false)
end)

test("where the combat log is restricted (Forever), the predictor reads hidden ticks, with its settings", function()
    local state = fixture({restricted = true})
    assert(state.ddt.predictor, "Toolkit 2.6's hidden path")
    equal(state.ddt.predictor.hidden, true)
    equal(state.ddt.dotTracker ~= nil, true)
    equal(state.toolkit.HealthBars.IsActiveSource("DyresDebuffTracker"), true)
    assert(state.settings.DDT_PREDICT and state.settings.DDT_PREDICT_DIES, "the settings show")
    equal(fixture().ddt.predictor.hidden, false, "the combat log path where it is open")
end)

test("on Forever a class Tools AddOn's source at 10 still wins over this AddOn at 5", function()
    local state = fixture({restricted = true, loaded = {WarlockToolsForever = "1.5.0"}, before = function(state)
        state.toolkit.HealthBars.RegisterSource({addon = "WarlockToolsForever", priority = 10,
            damage = function() return nil end})
    end})
    assert(state.ddt.predictor, "made, and steps aside")
    equal(state.toolkit.HealthBars.IsActiveSource("WarlockToolsForever"), true)
    equal(state.toolkit.HealthBars.IsActiveSource("DyresDebuffTracker"), false)
end)

test("with an older Toolkit's nil predictor there, the DoT tracker runs and the page leaves out its settings", function()
    local state = fixture({restricted = true, before = function(state)
        state.toolkit.CreateDotPredictor = function() return nil, "the combat log" end
    end})
    equal(state.ddt.predictor, nil)
    assert(state.ddt.dotTracker, "the tracker still runs")
    equal(state.settings.DDT_PREDICT, nil)
end)

test("/ddt: settings, reset, debug, reset_focus; never in combat for the panel (the toolkit's rule)", function()
    local state = fixture()
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("")
    assert(state.opened, "opened the settings")
    state.ddt.db.dots.sections.list = {point = "TOP", relativePoint = "TOP", x = 1, y = 1}
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("reset")
    equal(state.ddt.db.dots.sections.list, nil)
    equal(state.said("default places"), true)
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("class=WARLOCK table=true yields=nil dots=ours control=ours"), true)
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("reset_focus")
    equal(state.said("Focus check reset"), true)
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("what")
    equal(state.said("/ddt opens the settings"), true)
end)

test("the TOC: optional toolkit, per-character settings, and the three files in order", function()
    local toc = assert(io.open("DyresDebuffTracker.toc", "rb")):read("*a")
    equal(toc:find("\r", 1, true), nil, "LF only")
    equal(toc:match("## Interface: ([^\n]+)"), "16001, 11509")
    equal(toc:match("## OptionalDeps: ([^\n]+)"), "DyresToolkit", "always loads; says once what to install")
    equal(toc:find("## Dependencies", 1, true), nil, "never a hard dependency (family rule)")
    equal(toc:match("## Group: ([^\n]+)"), "DyresToolkit")
    equal(toc:match("## SavedVariablesPerCharacter: ([^\n]+)"), "DyresDebuffTrackerDB",
        "positions and character macros are per character")
    local files = {}
    for line in toc:gmatch("[^\n]+") do
        if not line:match("^#") then files[#files + 1] = line end
    end
    equal(table.concat(files, ","), table.concat(RUNTIME, ","))
    equal(toc:match("## IconTexture: ([^\n]+)"), "Interface\\AddOns\\DyresDebuffTracker\\Textures\\Icon")
    local icon = assert(io.open("Textures/Icon.tga", "rb")):read("*a")
    equal(#icon, 18 + 64 * 64 * 4, "uncompressed 64 x 64 BGRA")
    equal(icon:byte(17), 32)
    equal(icon:byte(18), 0x28, "8 alpha bits, top-left origin")
end)

test("no runtime file calls SetRaidTarget", function()
    for _, path in ipairs(RUNTIME) do
        local text = assert(io.open(path, "rb")):read("*a")
        equal(text:find("SetRaidTarget(", 1, true), nil, path)
    end
end)

local failed = 0
for index, entry in ipairs(tests) do
    local ok, message = xpcall(entry.body, debug.traceback)
    if ok then
        print("ok " .. index .. " - " .. entry.name)
    else
        failed = failed + 1
        print("not ok " .. index .. " - " .. entry.name)
        print(message)
    end
end
print("")
print(#tests .. " tests: " .. (#tests - failed) .. " passed, " .. failed .. " failed")
print("Mock results do not establish in-client compatibility.")
if failed > 0 then
    os.exit(1)
end
