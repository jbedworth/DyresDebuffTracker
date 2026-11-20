-- Lua 5.1 mock suite for Dyre's Debuff Tracker. Run from the AddOn folder:
--   lua5.1 tests/run.lua
-- It loads Dyre's Toolkit's real files from ../DyresToolkit when that folder
-- is there; else (as in CI, which has only this repository, or with
-- DDT_TOOLKIT_COPY=1) from the copy in tests/toolkit (Toolkit v2.10.2). The
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
local TOOLKIT_FILES = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Profiles.lua", "Auras.lua", "Units.lua",
    "HealthBars.lua", "Spells.lua", "Macros.lua", "Announce.lua", "ClassData.lua", "Owners.lua", "Control.lua",
    "DotTracker.lua", "PlateDots.lua", "DotPredict.lua"}
local OLD_TOOLKIT = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Auras.lua", "Units.lua",
    "HealthBars.lua"}
local RUNTIME = {"Core.lua", "Engines.lua", "Frost.lua", "Options.lua"}
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
    [772] = "Rend", [5246] = "Intimidating Shout", [1715] = "Hamstring", [2878] = "Turn Undead", [20066] = "Repentance"}

-- The client for one character: its class, its spells, the AddOns loaded.
local function fixture(options)
    options = options or {}
    local state = {messages = {}, frames = {}, named = {}, macros = {}, settings = {}, pages = {}, headings = {},
        timers = {}, now = 100, containers = {}, containerCombat = {}, auraReads = 0}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.SlashCmdList = {}
    env.DEFAULT_CHAT_FRAME = {AddMessage = function(_, message) state.messages[#state.messages + 1] = message end}
    env.UIParent = newFrame(state, "Frame", "UIParent")
    env.CreateFrame = function(kind, name, parent, template)
        local frame = newFrame(state, kind, name, parent, template)
        if kind == "AuraContainer" then
            -- Forever's engine container: it reads the auras itself; the
            -- AddOn only gives it slots, a unit, and regions to draw.
            state.containers[#state.containers + 1] = frame
            state.containerCombat[#state.containerCombat + 1] = state.combat == true
            frame.slots, frame.unit = {}, "none"
            function frame:AddAuraSlot(key, filter, slotOptions)
                local button = newFrame(state, "Button", nil, self)
                self.slots[#self.slots + 1] = {key = key, filter = filter, options = slotOptions, button = button}
                slotOptions.initializeFrame(button)
            end
            function frame:SetUnit(unit) self.unit = unit end
            function frame:UpdateAllAuras() end
        end
        return frame
    end
    env.InCombatLockdown = function() return state.combat == true end
    env.GetTime = function() return state.now end
    env.C_Timer = {After = function(delay, fn) state.timers[#state.timers + 1] = fn end}
    env.UnitClass = function() return options.className or "Warlock", options.class or "WARLOCK" end
    env.UnitGUID = function(unit) return unit == "player" and "Player-1" or nil end
    env.UnitExists = function() return false end
    env.UnitName = function(unit) return unit == "player" and (options.player or "Dyre") or nil end
    env.GetRealmName = function() return "Realm" end
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
    -- options.auras(unit, index, filter): the auras Classic Era's plain-Lua container reads.
    env.C_UnitAuras = {GetAuraDataByIndex = function(unit, index, filter)
        state.auraReads = state.auraReads + 1
        return options.auras and options.auras(unit, index, filter) or nil
    end}
    if options.engine then
        env.C_XMLUtil = {GetTemplateInfo = function(name) return name == "CustomAuraContainerTemplate" and {} or nil end}
    end
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
        IsAddOnLoaded = function(addon)
            return loaded[addon] ~= nil or (addon == "Blizzard_AuraContainer" and options.engine == true)
        end,
        LoadAddOn = function() end,
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
        state.toolkitNS = ns
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

-- Whether a class table has a control spell (a Toolkit newer than the copy may).
local function HasControl(classData, key)
    for _, def in ipairs(classData and classData.control or {}) do
        if def.key == key then return true end
    end
    return false
end

-- Every new class (the class gate, lead 2026-11-14): what its table makes.
-- {class, className, spellbook, dots?, control?, the Focus box key, macros written}
local CLASS_ROWS = {
    {"DRUID", "Druid", {{8921, "Moonfire"}, {339, "Entangling Roots"}, {2637, "Hibernate"}}, true, true, "roots",
        {"! Hibernate"}},
    {"HUNTER", "Hunter", {{1978, "Serpent Sting"}, {1513, "Scare Beast"}}, true, true, "scarebeast", {}},
    {"PRIEST", "Priest", {{589, "Shadow Word: Pain"}, {9484, "Shackle Undead"}}, true, true, nil, {"! Shackle"}},
    {"ROGUE", "Rogue", {{1943, "Rupture"}, {6770, "Sap"}, {2094, "Blind"}}, true, true, "blind", {"! Sap"}},
    {"SHAMAN", "Shaman", {{8050, "Flame Shock"}}, true, false, nil, {}},
    {"WARRIOR", "Warrior", {{772, "Rend"}, {5246, "Intimidating Shout"}, {1715, "Hamstring"}}, true, true,
        "hamstring", {}},
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
            local focus, want = ddt.controlTracker.focusBox, row[6]
            -- Hamstring came after the tests/toolkit copy (Toolkit, John 2026-11-17).
            if want == "hamstring" and not HasControl(ddt.classData, "hamstring") then want = nil end
            equal(focus and focus.key, want, class .. " Focus box")
            equal(state.named.DyresDebuffTrackerControlFocus ~= nil, want ~= nil, class .. " Focus box frame")
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

-- John, 2026-11-17: "add Warrior Hamstring to CC abilities that can be on
-- more than one mob, as well as Druid roots".
test("Hamstring and Entangling Roots on two mobs give two crowd-control bars", function()
    for _, case in ipairs({
        {"WARRIOR", "Warrior", {{772, "Rend"}, {1715, "Hamstring"}}, 1715, "hamstring"},
        {"DRUID", "Druid", {{8921, "Moonfire"}, {339, "Entangling Roots"}}, 339, "roots"},
    }) do
        local state = fixture({class = case[1], className = case[2], book = case[3]})
        local env, units = state.env, {}
        env.UnitExists = function(unit) return units[unit] ~= nil end
        env.UnitGUID = function(unit) return unit == "player" and "Player-1" or (units[unit] and units[unit].guid) end
        env.UnitName = function(unit) return units[unit] and units[unit].name end
        env.UnitCanAttack = function(_, unit) return units[unit] ~= nil end
        local tracker = state.ddt.controlTracker
        assert(tracker, case[1] .. " has a control bar")
        if not HasControl(state.ddt.classData, case[5]) then
            -- The tests/toolkit copy predates Hamstring; ../DyresToolkit has it.
            assert(TOOLKIT == "tests/toolkit/", case[5] .. " must be in ../DyresToolkit")
        else
            local spell
            for _, def in ipairs(state.ddt.classData.control) do
                if def.key == case[5] then spell = def end
            end
            assert(spell and spell.bar and not spell.single, case[5] .. ": a bar spell, not single")
            for index, guid in ipairs({"Creature-1", "Creature-2"}) do
                units.target = {guid = guid, name = "Boar"}
                emit(state, "UNIT_SPELLCAST_SENT", "player", "Boar", "cast-" .. index, case[4])
                emit(state, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. index, case[4])
            end
            local held = {}
            for _, row in ipairs(tracker.rows) do
                if row.guid then held[#held + 1] = row.guid .. ":" .. tostring(row.key) end
            end
            table.sort(held)
            equal(table.concat(held, ","), "Creature-1:" .. case[5] .. ",Creature-2:" .. case[5],
                case[1] .. ": one bar per mob")
        end
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

-- treadpool, a player, 2026-11-17: "Would be cleaner if it only showed the
-- DoTs that are actively ticking"; John: "Yes, build it".
test("Hide empty DoT slots: a checkbox only with the Toolkit's flag, repaired, rebuilt, in the profile", function()
    local realFlag
    local function WithFlag(state)
        realFlag = state.toolkit.TRACKER_HIDE_EMPTY == true
        state.toolkit.TRACKER_HIDE_EMPTY = true
    end
    local state = fixture({before = WithFlag})
    local db, setting = state.ddt.db, state.settings.DDT_DOTS_HIDE_EMPTY
    assert(setting, "the checkbox on the DoTs page")
    equal(setting.category, "DoTs")
    equal(setting.name, "Hide empty DoT slots")
    equal(setting.default, false)
    equal(db.dots.hideEmpty, false, "off by default")
    local rebuilds, tracker = 0, state.ddt.dotTracker
    local rebuild = tracker.Rebuild
    tracker.Rebuild = function(self) rebuilds = rebuilds + 1; return rebuild(self) end
    if realFlag then
        assert(next(tracker.pinned.target.casts or {}), "recast clicks on the target row while off")
    end
    setting.set(true)
    equal(db.dots.hideEmpty, true)
    equal(rebuilds, 1, "a change rebuilds the tracker")
    if realFlag then
        -- The Toolkit with the change: the pinned target row makes no secure slots.
        equal(next(tracker.pinned.target.casts or {}), nil, "no recast clicks on the target row")
    end
    -- The profile carries it, and its refresh rebuilds.
    local ns = state.toolkitNS
    ns.db.profiles["Other - Realm"] = {class = "Warlock", parts = {DyresDebuffTracker = {dots = {hideEmpty = false}}},
        pending = {}}
    local before = rebuilds
    equal(ns.profile:CopyFrom("Other - Realm"), true)
    equal(db.dots.hideEmpty, false, "copied")
    assert(rebuilds > before, "the profile refresh rebuilds")
    -- Bad saved values are repaired.
    for _, bad in ipairs({"yes", 1, {}}) do
        equal(fixture({saved = {dots = {hideEmpty = bad}}}).ddt.db.dots.hideEmpty, false, "saved " .. tostring(bad))
    end
    equal(fixture({saved = {dots = {hideEmpty = true}}}).ddt.db.dots.hideEmpty, true, "a good value stays")
    -- Without the flag (an older Toolkit): no checkbox, no error.
    local old = fixture({before = function(s) s.toolkit.TRACKER_HIDE_EMPTY = nil end})
    equal(old.settings.DDT_DOTS_HIDE_EMPTY, nil)
    equal(#old.messages, 0)
end)

-- A player, 2026-11-19: "Is there a way to disable the target dot window or
-- hide it?"; John: "a 3 panels toggle show/off, default to show".
test("Panel switches: three checkboxes only with the Toolkit's TRACKER_PANELS, repaired, live, in the profile", function()
    local realFlag
    local function WithFlag(state)
        realFlag = type(state.toolkit.TRACKER_PANELS) == "table"
        state.toolkit.TRACKER_PANELS = state.toolkit.TRACKER_PANELS or {"target", "focus", "list"}
    end
    local state = fixture({before = WithFlag})
    local db, tracker = state.ddt.db, state.ddt.dotTracker
    local names = {TARGET = "Show Target panel", FOCUS = "Show Focus panel", LIST = "Show Others panel"}
    for suffix, name in pairs(names) do
        local setting = state.settings["DDT_DOTS_SHOW_" .. suffix]
        assert(setting, "the checkbox " .. name)
        equal(setting.category, "DoTs")
        equal(setting.name, name)
        equal(setting.default, true)
    end
    for _, key in ipairs({"target", "focus", "list"}) do
        equal(db.dots.show[key], true, key .. " shown by default")
    end
    local refreshes = 0
    local refresh = tracker.Refresh
    tracker.Refresh = function(self) refreshes = refreshes + 1; return refresh(self) end
    if realFlag then
        equal(tracker.sections.target:IsShown(), true, "the Target panel shows")
    end
    state.settings.DDT_DOTS_SHOW_TARGET.set(false)
    equal(db.dots.show.target, false)
    equal(db.dots.show.focus, true, "the others stay")
    equal(refreshes, 1, "a change refreshes the tracker")
    if realFlag then
        equal(tracker.sections.target:IsShown(), false, "the Target panel hides at once")
        equal(tracker.sections.focus:IsShown(), true, "the Focus panel stays")
    end
    state.settings.DDT_DOTS_SHOW_TARGET.set(true)
    if realFlag then
        equal(tracker.sections.target:IsShown(), true, "the Target panel shows again")
    end
    -- The profile carries it (it is under dots).
    local ns = state.toolkitNS
    ns.db.profiles["Other - Realm"] = {class = "Warlock",
        parts = {DyresDebuffTracker = {dots = {show = {target = true, focus = false, list = false}}}}, pending = {}}
    local before = refreshes
    equal(ns.profile:CopyFrom("Other - Realm"), true)
    equal(db.dots.show.target, true, "copied")
    equal(db.dots.show.focus, false, "copied")
    equal(db.dots.show.list, false, "copied")
    assert(refreshes > before, "the profile refresh refreshes the tracker")
    -- Only false hides: bad saved values show the panel.
    for _, bad in ipairs({"no", 0, {}, true}) do
        local saved = fixture({saved = {dots = {show = {target = bad, focus = bad, list = bad}}}}).ddt.db.dots.show
        equal(saved.target, true, "saved " .. tostring(bad))
        equal(saved.list, true, "saved " .. tostring(bad))
    end
    equal(fixture({saved = {dots = {show = "off"}}}).ddt.db.dots.show.focus, true, "not a table: all shown")
    equal(fixture({saved = {dots = {show = {list = false}}}}).ddt.db.dots.show.list, false, "false stays")
    -- Without the flag (an older Toolkit): no checkboxes, no error, still saved.
    local old = fixture({before = function(s) s.toolkit.TRACKER_PANELS = nil end})
    equal(old.settings.DDT_DOTS_SHOW_TARGET, nil)
    equal(old.settings.DDT_DOTS_SHOW_LIST, nil)
    equal(#old.messages, 0)
    equal(old.ddt.db.dots.show.target, true, "still saved and repaired")
end)

-- Dyre's Toolkit Profile (Toolkit 2.10.0; John, 2026-11-17: "one place to go
-- to persist your profile").
local function Same(a, b, path)
    path = path or "settings"
    if type(a) ~= "table" or type(b) ~= "table" then
        equal(a, b, path)
        return
    end
    for key, value in pairs(a) do Same(value, b[key], path .. "." .. tostring(key)) end
    for key in pairs(b) do
        if a[key] == nil then error(path .. "." .. tostring(key) .. ": only in the second table") end
    end
end

test("profile: joins with RegisterProfilePart, and without it nothing changes", function()
    local state = fixture()
    equal(state.ddt.profileJoined, true)
    local found
    for _, part in ipairs(state.toolkit.ProfileParts()) do
        if (part.addon or part) == "DyresDebuffTracker" then found = true end
    end
    assert(found, "listed as a part")
    local old = fixture({before = function(s) s.toolkit.RegisterProfilePart = nil end})
    equal(old.ddt.profileJoined, false)
    assert(old.ddt.dotTracker and old.ddt.controlTracker, "the engines still run")
    equal(#old.messages, 0, "no error, nothing said")
end)

test("profile: sanitize gives the defaults from {} and repairs any table, never erroring", function()
    local state = fixture()
    local ddt = state.ddt
    Same(ddt.ProfileSettings({}), ddt.SanitizeDB({}, ddt.classData))
    for _, bad in ipairs({nil, "x", {dots = "x"}, {dots = {order = {"moonfire"}, theme = 7, sizes = 3},
            control = {markers = "x", texts = {fear = 5}}, predict = {opacity = 0 / 0}, junk = {1, 2}}}) do
        local clean = ddt.ProfileSettings(bad)
        equal(#clean.dots.order, #ddt.classData.dots, "every slot of this class")
        equal(clean.dots.theme, "bars")
        equal(clean.junk, nil, "unknown keys dropped")
    end
end)

test("profile: a copy from another character applies live and keeps this character's own keys", function()
    local state = fixture()
    local ddt, ns = state.ddt, state.toolkitNS
    local db, dots, control = ddt.db, ddt.db.dots, ddt.db.control
    db.macrosOwned["! Fear"] = true
    dots.lastCurse = "Curse of Agony"
    local list = state.named.DyresDebuffTrackerList
    equal(list.width, 290)
    -- A Druid's part: its order has Druid slots; its own macro and recast.
    ns.db.profiles["Leaf - Realm"] = {class = "Druid", parts = {DyresDebuffTracker = {
        dots = {theme = "bars", trackerSize = 125, grow = {target = "up", list = "up"}, order = {"moonfire", "rake"},
            health = true, lastCurse = "Curse of Tongues", panelOpacity = {list = 40}},
        control = {scale = 80, say = true, announce = {fear = true}},
        predict = {color = "red", diesPlace = "left"},
        macrosOwned = {["! Hibernate"] = true}}}, pending = {}}
    local ok, reload = ns.profile:CopyFrom("Leaf - Realm")
    equal(ok, true)
    equal(#reload, 0, "live: no reload")
    equal(db.dots, dots, "the same tables: the engines' stores")
    equal(db.control, control)
    equal(dots.trackerSize, 125)
    equal(dots.sizes.bars.barWidth, 363)
    equal(dots.grow.target, "up")
    equal(dots.health, true)
    equal(dots.panelOpacity.list, 40)
    equal(#dots.order, #ddt.classData.dots, "a Druid's order repaired for this Warlock")
    equal(control.scale, 80)
    equal(control.say, true)
    equal(control.announce.fear, true)
    equal(db.predict.color, "red")
    equal(db.predict.diesPlace, "left")
    equal(db.macrosOwned["! Fear"], true, "macros stay this character's")
    equal(db.macrosOwned["! Hibernate"], nil)
    equal(dots.lastCurse, "Curse of Agony", "the recast memory stays this character's")
    equal(list.width, 363, "the tracker rebuilt with the new size")
    equal(ddt.dotTracker.theme, "bars")
    equal(state.named.DyresDebuffTrackerControl:GetScale(), 0.8, "the control bar's new scale")
    -- Defaults: a clean slate, own keys kept.
    ok = ns.profile:CopyFrom(state.toolkit.PROFILE_DEFAULTS)
    equal(ok, true)
    equal(dots.trackerSize, 100)
    equal(list.width, 290)
    equal(control.scale, 100)
    equal(db.macrosOwned["! Fear"], true)
    equal(dots.lastCurse, "Curse of Agony")
end)

test("profile: export and import round trip; a bad line or a failing part changes nothing", function()
    local state = fixture()
    local ddt, ns = state.ddt, state.toolkitNS
    local db = ddt.db
    db.dots.trackerSize = 75
    ddt.ApplyTrackerSize(db.dots)
    local line = ns.profile:Export()
    contains(line, "DYRE2:profile:")
    db.dots.trackerSize = 110
    db.macrosOwned["! Fear"] = true
    local ok = ns.profile:Import(line)
    equal(ok, true)
    equal(db.dots.trackerSize, 75)
    equal(db.dots.sizes.bars.barWidth, 218)
    equal(db.macrosOwned["! Fear"], true, "not in the line, kept")
    -- A damaged line: refused, nothing changed.
    local before = ns.profile:Export()
    equal(ns.profile:Import("DYRE2:profile:garbage:1"), nil)
    equal(ns.profile:Export(), before)
    -- Another part that fails: all or nothing.
    state.toolkit.RegisterProfilePart({addon = "DyresBroken", current = function() return {} end,
        sanitize = function() error("broken") end})
    db.dots.trackerSize = 110
    ok = ns.profile:CopyFrom(state.toolkit.PROFILE_DEFAULTS)
    equal(ok, nil)
    equal(db.dots.trackerSize, 110, "nothing changed")
    -- In combat: refused.
    state.combat = true
    equal(ns.profile:CopyFrom(state.toolkit.PROFILE_DEFAULTS), nil)
end)

-- The Mage's frozen and chilled arcs (John, 2026-11-18).
local MAGE = {class = "MAGE", className = "Mage", book = {{118, "Polymorph"}, {133, "Fireball"}}}

local function Mage(extra)
    local options = {}
    for key, value in pairs(MAGE) do options[key] = value end
    for key, value in pairs(extra or {}) do options[key] = value end
    return fixture(options)
end

-- A nameplate for unit with Blizzard's health bar, added as the client does.
local function AddPlate(state, unit, hostile)
    local env = state.env
    state.plates = state.plates or {}
    state.hostile = state.hostile or {}
    local plate = env.CreateFrame("Frame", nil, env.UIParent)
    plate.UnitFrame = {healthBar = env.CreateFrame("StatusBar", nil, plate)}
    state.plates[unit] = plate
    state.hostile[unit] = hostile ~= false
    env.C_NamePlate.GetNamePlateForUnit = function(token) return state.plates[token] end
    env.UnitExists = function(token) return state.plates[token] ~= nil end
    env.UnitCanAttack = function(_, token) return state.hostile[token] == true end
    emit(state, "NAME_PLATE_UNIT_ADDED", unit)
    return plate
end

local function RemovePlate(state, unit)
    emit(state, "NAME_PLATE_UNIT_REMOVED", unit)
    state.plates[unit] = nil
end

local function SlotBy(container, key)
    for _, slot in ipairs(container.slots) do
        if slot.key == key then return slot end
    end
end

test("frozen and chilled arcs: Mages only, on by default, with their settings, repaired", function()
    local warlock = fixture()
    equal(warlock.ddt.frostArcs, nil, "no arcs for a Warlock")
    equal(warlock.settings.DDT_FROST, nil, "no rows for other classes")
    equal(warlock.heading("Frozen and chilled"), nil)
    local state = Mage()
    assert(state.ddt.frostArcs, "a Mage has the arcs")
    local setting = state.settings.DDT_FROST
    assert(setting, "the switch")
    equal(setting.category, "DoTs")
    equal(setting.default, true)
    equal(state.ddt.db.frost.enabled, true, "on by default")
    assert(state.heading("DoTs: Frozen and chilled"), "its heading on the DoTs page")
    equal(state.settings.DDT_FROST_OFFSET.default, 10)
    equal(state.settings.DDT_FROST_SIZE.default, 100)
    equal(#state.messages, 0)
    local bad = Mage({saved = {frost = {enabled = "yes", offset = 999, size = 10.5}}}).ddt.db.frost
    equal(bad.enabled, true, "not a boolean: on")
    equal(bad.offset, 60, "at most 60")
    equal(bad.size, 100, "not a whole number: the default")
    local good = Mage({saved = {frost = {enabled = false, offset = 0, size = 200}}}).ddt.db.frost
    equal(good.enabled, false)
    equal(good.offset, 0)
    equal(good.size, 200)
    -- The art: 256 x 64, uncompressed BGRA, top-left origin.
    for _, name in ipairs({"FrozenArc", "ChilledArc"}) do
        local data = assert(io.open("Textures/" .. name .. ".tga", "rb")):read("*a")
        equal(#data, 18 + 256 * 64 * 4, name)
        equal(data:byte(13) + data:byte(14) * 256, 256, name .. " width")
        equal(data:byte(15) + data:byte(16) * 256, 64, name .. " height")
        equal(data:byte(18), 0x28, name)
    end
end)

test("frozen and chilled arcs on Forever: one HARMFUL slot each, a set, nothing read, also in combat", function()
    local state = Mage({engine = true})
    local arcs = state.ddt.frostArcs
    equal(#arcs.all, state.ddt.FROST_PREWARM, "holders made ahead, out of combat")
    state.combat = true
    local plate = AddPlate(state, "nameplate1")
    local holder = arcs.byUnit.nameplate1
    assert(holder, "the plate got a holder")
    equal(#arcs.all, state.ddt.FROST_PREWARM, "from the pool: none made in combat")
    equal(holder.parent, plate, "parented to the plate")
    equal(holder.point[2], plate.UnitFrame.healthBar, "on the bar FindPlateBar finds")
    equal(holder.shown, true, "a hostile mob")
    local container = holder.container
    equal(container.kind, "AuraContainer", "the engine's container")
    equal(container.unit, "nameplate1")
    equal(#container.slots, 3, "frozen, chilled, and the armor's chill")
    local frozen, chilled = SlotBy(container, "frozen"), SlotBy(container, "chilled")
    local armor = SlotBy(container, "chilledArmor")
    equal(frozen.filter, "HARMFUL", "any Mage's freeze: Shatter works on it")
    equal(chilled.filter, "HARMFUL|PLAYER", "only your Chill procs your talents")
    equal(armor.filter, "HARMFUL", "the armor's chill: no PLAYER (found in client, 6136)")
    local frozenIDs = frozen.options.candidateFilters.includeSpellIDs
    local chilledIDs = chilled.options.candidateFilters.includeSpellIDs
    local armorIDs = armor.options.candidateFilters.includeSpellIDs
    equal(frozenIDs[1], nil, "a set, not a list")
    equal(chilledIDs[1], nil, "a set, not a list")
    equal(armorIDs[1], nil, "a set, not a list")
    for _, id in ipairs({122, 865, 6131, 10230, 12494}) do equal(frozenIDs[id], true, "frozen " .. id) end
    for _, id in ipairs({116, 25304, 120, 10161, 12484, 12486}) do
        equal(chilledIDs[id], true, "chilled " .. id)
    end
    equal(armorIDs[6136], true, "Frost Armor's Chilled")
    equal(armorIDs[7321], true, "Ice Armor's Chilled")
    equal(chilledIDs[6136], nil, "not in the PLAYER slot")
    equal(frozenIDs[116], nil, "Frostbolt chills; it does not freeze")
    equal(chilledIDs[122], nil, "Frost Nova freezes")
    -- Both arcs are the engine's buttons, set up once: Frozen above Chilled.
    equal(holder.arcs.frozen, frozen.button)
    equal(holder.arcs.chilled, chilled.button)
    equal(holder.arcs.chilledArmor, armor.button)
    equal(frozen.button.point[5], 7, "Frozen 7 above")
    equal(chilled.button.point[5], 0)
    equal(armor.button.point[5], 0, "the armor's chill: the chilled arc's place")
    -- After every AddOn's handler: placed again, on the bar a plate AddOn may have made.
    local other = state.env.CreateFrame("StatusBar", nil, plate)
    plate.UnitFrame = {healthBar = other}
    for _, timer in ipairs(state.timers) do timer() end
    equal(holder.point[2], other, "placed again on the newer bar")
    -- A friendly unit: hidden. UNIT_FLAGS follows a change.
    AddPlate(state, "nameplate2", false)
    equal(arcs.byUnit.nameplate2.shown, false)
    state.hostile.nameplate2 = true
    emit(state, "UNIT_FLAGS", "nameplate2")
    equal(arcs.byUnit.nameplate2.shown, true)
    -- Removed: the holder lets go and goes back to the pool; added again, reused.
    RemovePlate(state, "nameplate1")
    equal(holder.container.unit, "none")
    equal(holder.shown, false)
    equal(holder.parent, state.env.UIParent)
    equal(arcs.byUnit.nameplate1, nil)
    AddPlate(state, "nameplate3")
    equal(arcs.byUnit.nameplate3, holder, "the pool's holder again")
    -- More plates than the pool in combat: made then, as PlateDots does.
    for index = 4, 13 do AddPlate(state, "nameplate" .. index) end
    assert(#arcs.all > state.ddt.FROST_PREWARM, "made in combat when the pool ran dry")
    equal(state.auraReads, 0, "no AddOn code reads an aura")
    state.combat = false
    local made = #arcs.all
    emit(state, "PLAYER_REGEN_ENABLED")
    equal(#arcs.all, made, "enough holders: none more")
end)

test("frozen and chilled arcs in /ddt debug: plates, shown, visible, anchors; never an aura", function()
    local state = Mage({engine = true})
    AddPlate(state, "nameplate1")
    AddPlate(state, "nameplate2", false)
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("frost on=true engine=engine holders=10 plates=2 shown=1 visible=1 anchors=[Blizzard=2]"),
        true, "one line for the arcs")
    equal(state.auraReads, 0, "the line reads no aura")
    state.settings.DDT_FROST.set(false)
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("frost on=false engine=engine holders=10 plates=0"), true, "off: no plates")
    local warlock = fixture()
    warlock.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(warlock.said("frost none (Mage only)"), true)
end)

test("frozen and chilled arcs on Classic Era: both at once, only your own Chill", function()
    -- unit -> {{spellId, yours}}: Frost Nova from another Mage, your Frostbolt.
    local auras = {nameplate1 = {{122, false}, {116, true}}}
    local function Read(unit, index, filter)
        local n = 0
        for _, aura in ipairs(auras[unit] or {}) do
            if aura[2] or not filter:find("PLAYER", 1, true) then
                n = n + 1
                if n == index then
                    return {spellId = aura[1], name = "x", icon = 1, duration = 8, expirationTime = 108}
                end
            end
        end
    end
    local state = Mage({auras = Read})
    AddPlate(state, "nameplate1")
    local holder = state.ddt.frostArcs.byUnit.nameplate1
    equal(holder.container.kind, "Frame", "the plain-Lua container")
    equal(holder.arcs.frozen.shown, true, "frozen: another Mage's Frost Nova counts")
    equal(holder.arcs.chilled.shown, true, "chilled: your Frostbolt; both at once")
    auras.nameplate1 = {{116, false}}
    emit(state, "UNIT_AURA", "nameplate1")
    equal(holder.arcs.frozen.shown, false)
    equal(holder.arcs.chilled.shown, false, "another Mage's chill gives you no proc")
    auras.nameplate1 = {{12494, false}, {6136, false}}
    emit(state, "UNIT_AURA", "nameplate1")
    equal(holder.arcs.frozen.shown, true, "Frostbite's freeze")
    equal(holder.arcs.chilled.shown, false)
    equal(holder.arcs.chilledArmor.shown, true, "Frost Armor's chill, whatever its source says")
end)

test("frozen and chilled arcs: off, height, and size apply at once, and the profile carries them", function()
    local state = Mage({engine = true})
    local arcs, db = state.ddt.frostArcs, state.ddt.db
    AddPlate(state, "nameplate1")
    local holder = arcs.byUnit.nameplate1
    equal(holder.scale, 1)
    equal(holder.point[5], 10, "10 pixels above the bar")
    state.settings.DDT_FROST_SIZE.set(200)
    state.settings.DDT_FROST_OFFSET.set(30)
    holder = arcs.byUnit.nameplate1
    equal(holder.scale, 2)
    equal(holder.point[5], 15, "30 pixels at scale 2")
    state.settings.DDT_FROST.set(false)
    equal(arcs.byUnit.nameplate1, nil, "off: no arcs")
    equal(holder.shown, false)
    AddPlate(state, "nameplate2")
    equal(arcs.byUnit.nameplate2, nil, "off: a new plate gets none")
    -- A profile copy turns them on again, with its own size.
    local ns = state.toolkitNS
    ns.db.profiles["Other - Realm"] = {class = "Mage", parts = {DyresDebuffTracker = {frost = {enabled = true,
        size = 50, offset = 0}}}, pending = {}}
    equal(ns.profile:CopyFrom("Other - Realm"), true)
    equal(db.frost.size, 50)
    assert(arcs.byUnit.nameplate1 and arcs.byUnit.nameplate2, "both plates have arcs again")
    equal(arcs.byUnit.nameplate2.scale, 0.5)
    equal(arcs.byUnit.nameplate2.point[5], 0)
end)

test("frozen and chilled arcs: events only, and no AddOn code reads an aura", function()
    local text = assert(io.open("Frost.lua", "rb")):read("*a")
    equal(text:find("\"OnUpdate\"", 1, true), nil, "no OnUpdate")
    equal(text:find("C_UnitAuras", 1, true), nil)
    equal(text:find("UnitAura(", 1, true), nil)
    equal(text:find("UnitDebuff(", 1, true), nil)
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

test("the TOC: optional toolkit, per-character settings, and the four files in order", function()
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
