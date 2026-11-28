-- Lua 5.1 mock suite for Dyre's Debuff Tracker. Run from the AddOn folder:
--   lua5.1 tests/run.lua
-- It loads Dyre's Toolkit's real files from ../DyresToolkit when that folder
-- is there; else (as in CI, which has only this repository, or with
-- DDT_TOOLKIT_COPY=1) from the copy in tests/toolkit (Toolkit v2.17.0). The
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
local RUNTIME = {"Core.lua", "Engines.lua", "Frost.lua", "Chime.lua", "Options.lua"}
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
    -- Where the combat log is restricted (WoW: Forever), the client forbids
    -- an AddOn to register or unregister it (ADDON_ACTION_FORBIDDEN).
    local function Forbidden(event, call)
        if state.restricted and event == "COMBAT_LOG_EVENT_UNFILTERED" then
            state.forbidden[#state.forbidden + 1] = call
            error("ADDON_ACTION_FORBIDDEN: Frame:" .. call .. "()", 3)
        end
    end
    function frame:RegisterEvent(event) Forbidden(event, "RegisterEvent"); self.events[event] = true end
    function frame:RegisterUnitEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) Forbidden(event, "UnregisterEvent"); self.events[event] = nil end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:GetScript(script) return self.scripts[script] end
    function frame:GetFrameLevel() return self.level end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:SetScale(scale) self.scale = scale end
    function frame:SetMinMaxValues(low, high) self.range = {low, high} end
    function frame:SetValue(value) self.value = value end
    function frame:SetStatusBarTexture(path) self.barTexture = path end
    function frame:SetStatusBarColor(...) self.barColor = {...} end
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
    -- Textures and their pulses are kept, so a test can see what a frame draws.
    frame.textures = {}
    function frame:CreateTexture(_, layer)
        local texture = stub({layer = layer, groups = {}})
        function texture:SetTexture(path) self.path = path end
        function texture:SetBlendMode(mode) self.blend = mode end
        function texture:SetColorTexture(...) self.color = {...} end
        function texture:SetVertexColor(...) self.tint = {...} end
        function texture:SetPoint(...) self.point = {...} end
        function texture:SetSize(width, height) self.width, self.height = width, height end
        function texture:SetTexCoord(...) self.coords = {...} end
        function texture:SetAllPoints(target) self.all = target end
        function texture:CreateAnimationGroup()
            local group = stub({animations = {}})
            function group:CreateAnimation(kind)
                local animation = stub({kind = kind})
                function animation:SetFromAlpha(value) self.from = value end
                function animation:SetToAlpha(value) self.to = value end
                function animation:SetDuration(value) self.duration = value end
                self.animations[#self.animations + 1] = animation
                return animation
            end
            function group:SetLooping(looping) self.looping = looping end
            function group:Play() self.playing = true end
            self.groups[#self.groups + 1] = group
            return group
        end
        self.textures[#self.textures + 1] = texture
        return texture
    end
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
    [772] = "Rend", [5246] = "Intimidating Shout", [1715] = "Hamstring", [2878] = "Turn Undead", [20066] = "Repentance",
    -- Both clients know the Winter's Chill debuff.
    [12579] = "Winter's Chill"}

-- The client for one character: its class, its spells, the AddOns loaded.
-- The variables a row watches (WatchSettings), as one sorted string.
local function Watched(setting)
    local initializer = setting.initializer or setting
    local list = {}
    for _, variable in ipairs(initializer.watch or {}) do list[#list + 1] = variable end
    table.sort(list)
    return table.concat(list, ",")
end

local function fixture(options)
    options = options or {}
    local state = {messages = {}, frames = {}, named = {}, macros = {}, settings = {}, pages = {}, headings = {},
        timers = {}, now = 100, containers = {}, containerCombat = {}, auraReads = 0, duplicates = {}, primers = {},
        restricted = options.restricted == true, forbidden = {}}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    state.env = env
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
                function button:SetApplicationBar(bar, barOptions) self.applicationBar = {bar, barOptions} end
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
    -- options.spells: more spells this client knows (Forever's Demonic Brand).
    env.C_Spell = {GetSpellName = function(id) return SPELLS[id] or (options.spells or {})[id] end,
        GetSpellTexture = function() return 1 end}
    local book = options.book or {{172, "Corruption"}, {348, "Immolate"}, {5782, "Fear"}, {710, "Banish"}}
    local known = {}
    for _, item in ipairs(book) do known[item[1]] = true end
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #book} end,
        GetSpellBookItemInfo = function(index) local item = book[index]
            return item and {spellID = item[1], name = item[2], itemType = 1} end,
        -- options.talents: talents this character knows (a table the test may change).
        IsSpellKnown = function(id) return known[id] == true or (options.talents or {})[id] == true end,
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
        -- Every modify predicate must pass, as the client's list of them.
        return {setting = setting, AddModifyPredicate = function(self, predicate)
                local before = self.modify
                self.modify = before and function() return before() and predicate() end or predicate
            end,
            -- Never called: rows are greyed, never hidden.
            AddShownPredicate = function() error("AddShownPredicate: grey the row, never hide it", 2) end,
            -- Blizzard's: evaluate the row again when that variable changes.
            AddEvaluateStateCVar = function(self, variable)
                self.watch = self.watch or {}
                self.watch[#self.watch + 1] = variable
            end,
            SetParentInitializer = function() end, InitFrame = function() end}
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
                if state.settings[variable] then
                    state.duplicates[#state.duplicates + 1] = variable
                end
                local setting = {category = category.name, variable = variable, name = name, get = get, set = set,
                    default = default}
                state.settings[variable] = setting
                return setting
            end,
            CreateCheckbox = function(_, setting, tooltip)
                setting.initializer, setting.tooltip = Initializer(setting), tooltip
                return setting.initializer
            end,
            CreateDropdown = function(_, setting, _, tooltip)
                setting.initializer, setting.tooltip = Initializer(setting), tooltip
                return setting.initializer
            end,
            CreateControlTextContainer = function()
                return {Add = function() end, GetData = function() return {} end}
            end,
            CreateSlider = function(_, setting, options, tooltip)
                setting.tooltip = tooltip
                setting.labelFormatter = type(options) == "table" and options.labelFormatter or nil
                setting.sliderOptions = options
                setting.initializer = Initializer(setting)
                return setting.initializer
            end,
            CreateSliderOptions = function(min, max, step)
                local options = {min = min, max = max, step = step}
                function options:SetLabelFormatter(_, formatter) self.labelFormatter = formatter end
                return options
            end,
            CreateColorSwatch = function(_, setting) setting.initializer = Initializer(setting); return setting.initializer end,
            CreateElementInitializer = function(template, data)
                local element = Initializer(nil)
                element.template, element.data = template, data
                state.primers[#state.primers + 1] = element
                return element
            end,
            OpenToCategory = function(id) state.opened = id end,
        }
        env.CreateSettingsListSectionHeaderInitializer = function(text) return {text = text} end
        env.MinimalSliderWithSteppersMixin = {Label = {Right = 1}}
        state.buttons = {}
        state.buttonRows = {}
        env.CreateSettingsButtonInitializer = function(name, text, onClick)
            state.buttons[name .. ": " .. text] = onClick
            local row = Initializer(nil)
            row.text = name .. " [" .. text .. "]"
            state.buttonRows[name .. ": " .. text] = row
            return row
        end
    end
    env.DyresToolkitDB = {snapToGrid = false}
    env.DyresDebuffTrackerDB = options.saved
    -- Warlock Tools Forever's per-character saved variables (read only).
    env.WarlockToolsForeverDB = options.wtf
    env.MageToolsForeverDB = options.mtf
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
    -- An older Toolkit's page: no per-panel settings (TRACKER_PANEL_OPTIONS).
    if options.oldPanels and state.toolkit then
        state.toolkit.TRACKER_PANEL_OPTIONS = nil
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
    if not options.noLogin then
        events.scripts.OnEvent(events, "PLAYER_LOGIN")
    end
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

-- The family rule "listed and greyed, never hidden" (lead, 2026-11-27): a row
-- that does not apply now is greyed, never hidden by a shown predicate.
test("no runtime file calls AddShownPredicate (greyed, never hidden)", function()
    local toc = assert(io.open("DyresDebuffTracker.toc", "rb"))
    local files = {}
    for line in toc:lines() do
        local file = line:match("^%s*([%w_/\\]+%.lua)%s*$")
        if file then
            files[#files + 1] = file
        end
    end
    toc:close()
    assert(#files >= 5, "the TOC lists the runtime files")
    for _, file in ipairs(files) do
        local handle = assert(io.open(file, "rb"))
        local code = handle:read("*a")
        handle:close()
        -- Comments may name it; code may not.
        code = code:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
        equal(code:find("AddShownPredicate", 1, true), nil, file)
    end
end)

test("settings pages, one per section, named as the sections; the tracker and crowd control each with a switch", function()
    local state = fixture()
    equal(table.concat(state.pages, "|"), "Dyre's AddOns > Debuff Tracker|Debuff Tracker > DoT Tracker|"
        .. "Debuff Tracker > DoTs|Debuff Tracker > Crowd Control")
    local dots, control = state.settings.DDT_DOTS, state.settings.DDT_CONTROL
    equal(dots.category, "DoT Tracker")
    equal(control.category, "Crowd Control")
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
    contains(state.heading("Warlock Tools Forever shows your DoTs"), "Debuff Tracker:")
    contains(state.heading("shows these for you now"), "Warlock Tools Forever")
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

-- John, DDT 1.8.1 on Forever (2026-11-27): "no matter how many different mobs
-- I fear, the timer says the same number", and "when the mob runs out of
-- range (inevitable), it just shows the mobs name, loses all info about the
-- mob". Fear is on several mobs at once (John: "It's always multi-cast"); it
-- counts down from the cast (Dyre's Toolkit 2.18.2); DDT turns the countdown
-- on for every class.
test("a Warlock's Fear: a row per feared mob, and a mob out of range counts down", function()
    local state = fixture()
    local env, units = state.env, {}
    env.UnitExists = function(unit) return units[unit] ~= nil end
    env.UnitGUID = function(unit) return unit == "player" and "Player-1" or (units[unit] and units[unit].guid) end
    env.UnitName = function(unit) return units[unit] and units[unit].name end
    env.UnitCanAttack = function(_, unit) return units[unit] ~= nil end
    local ddt = state.ddt
    ddt.toolkit.NoteFocusWorks()
    local tracker = ddt.controlTracker
    assert(tracker, "a Warlock has a control bar")
    if not ddt.toolkit.CONTROL_CAST_COUNTDOWN then
        -- The tests/toolkit copy predates 2.18.2; ../DyresToolkit has it.
        assert(TOOLKIT == "tests/toolkit/", "CONTROL_CAST_COUNTDOWN must be in ../DyresToolkit")
        return
    end
    local function Fear(guid, name, castGUID)
        units.target = {guid = guid, name = name}
        emit(state, "PLAYER_TARGET_CHANGED")
        emit(state, "UNIT_SPELLCAST_SENT", "player", name, castGUID, 5782)
        emit(state, "UNIT_SPELLCAST_SUCCEEDED", "player", castGUID, 5782)
    end
    Fear("Creature-1", "Greymist Coastrunner", "cast-1")
    state.now = state.now + 3
    Fear("Creature-2", "Greymist Raider", "cast-2")
    local held = {}
    for _, row in ipairs(tracker.rows) do
        if row.guid then held[#held + 1] = row.guid end
    end
    equal(table.concat(held, ","), "Creature-1,Creature-2", "a row for each feared mob")
    local row = tracker.rows[2]
    equal(row.boundUnit, "target")
    equal(tracker.rows[1].boundUnit, "none", "the first mob is on no unit: never the new target")
    state.now = state.now + 4
    units.target = nil
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(row.boundUnit, "none", "no unit shows the feared mob")
    equal(row.name.text, "Greymist Raider  |cff999999" .. "~6 s|r", "Fear rank 1 is 10 s, cast 4 s ago; an estimate")
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
    assert(state.heading("nothing for your class"), "said on the page")
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
    equal(db.control.texts.howl, "Howl of Terror!")
    equal(db.control.scale, 50)
    equal(db.macrosOwned["! Fear"], true)
    equal(db.macrosOwned.bad, nil)
end)

-- John, 2026-11-28: no AddOn name in any default message (a WTF player
-- uninstalled over messages that "advertised the addon"; "Yes, use them").
test("group messages: no AddOn name in any default; old defaults with a credit become the new ones", function()
    local state = fixture()
    local ddt = state.ddt
    local spells = {}
    for _, spell in ipairs(ddt.classData.control or {}) do
        spells[#spells + 1] = spell
    end
    assert(#spells >= 4, "the Warlock's crowd-control spells")
    for _, className in ipairs({"WARLOCK", "MAGE", "PRIEST", "DRUID", "ROGUE", "HUNTER", "PALADIN", "WARRIOR"}) do
        local data = ddt.toolkit.ClassSpells and ddt.toolkit.ClassSpells(className)
        for _, spell in ipairs(type(data) == "table" and data.control or {}) do
            spells[#spells + 1] = spell
        end
    end
    for _, spell in ipairs(spells) do
        local text = ddt.DefaultAnnounceText(spell)
        equal(text:find("Dyre's Debuff Tracker", 1, true), nil, spell.key)
        equal(text:find("Tools Forever", 1, true), nil, spell.key)
        equal(text:find(" - via ", 1, true), nil, spell.key)
    end
    local byKey = {}
    for _, spell in ipairs(ddt.classData.control) do
        byKey[spell.key] = spell
    end
    local fear = "Fear on >> %T <<" .. (byKey.fear.marker and " %M" or "")
    equal(ddt.DefaultAnnounceText(byKey.fear), fear)
    equal(ddt.DefaultAnnounceText({label = "Banish", marker = true}), "Banish on >> %T << %M", "with a marker")
    equal(ddt.DefaultAnnounceText(byKey.howl), "Howl of Terror!")
    for _, credit in ipairs({" - via Dyre's Debuff Tracker", " - via Warlock Tools Forever (WTF)"}) do
        local saved = fixture({saved = {control = {texts = {fear = fear .. credit,
            howl = "Howl of Terror!" .. credit, banish = "Banished %T, leave it" .. credit,
            enslave = "My demon now"}}}}).ddt.db.control.texts
        equal(saved.fear, fear, "an old default" .. credit)
        equal(saved.howl, "Howl of Terror!", "an old default" .. credit)
        equal(saved.banish, "Banished %T, leave it" .. credit, "a player's own text stays, credit and all")
        equal(saved.enslave, "My demon now", "a player's own text stays")
    end
end)

-- John, 2026-11-14: "a 'Tracker size' slider ... increasing or decreasing by up to 25%".
test("Tracker size: one percent, 75 to 125, sets the bar width and the compact icon size", function()
    local state = fixture({oldPanels = true})
    local db, setting = state.ddt.db, state.settings.DDT_DOTS_TRACKER_SIZE
    assert(setting, "the slider on the DoTs page")
    equal(setting.category, "DoT Tracker")
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
    local state = fixture({oldPanels = true, before = WithGrow})
    local db = state.ddt.db
    for _, key in ipairs({"target", "focus", "list"}) do
        equal(db.dots.grow[key], "down", key .. " grows down by default")
        local setting = state.settings["DDT_DOTS_GROW_" .. key:upper()]
        assert(setting, key .. " has a Grow setting")
        equal(setting.category, "DoT Tracker")
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
    equal(setting.category, "DoT Tracker")
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
        equal(setting.category, "DoT Tracker")
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

-- GitHub issue 1 (a player, 2026-11-20: "When a target is selected, a frame
-- appears with a purple border. I'd like to hide all of that and only show
-- the debuff bars."; John: "Build parts 1 and 2").
test("Panel frame and outline: a checkbox with TRACKER_FRAME, a slider with TRACKER_OUTLINE, repaired, live, in the profile", function()
    local function WithFlag(state)
        state.toolkit.TRACKER_FRAME = true
    end
    local state = fixture({oldPanels = true, before = WithFlag})
    local db, tracker = state.ddt.db, state.ddt.dotTracker
    local frame, outline = state.settings.DDT_DOTS_FRAME, state.settings.DDT_DOTS_OUTLINE
    assert(frame, "the frame checkbox")
    equal(frame.category, "DoT Tracker")
    equal(frame.name, "Show panel frame")
    equal(frame.default, true)
    assert(outline, "the outline slider")
    equal(outline.category, "DoT Tracker")
    equal(outline.name, "Outline width")
    equal(outline.default, 3)
    equal(db.dots.frame, true, "the frame shows by default")
    equal(db.dots.outlineWidth, 3, "3 px by default")
    local colors, rebuilds = 0, 0
    local apply, rebuild = tracker.ApplyPanelColors, tracker.Rebuild
    tracker.ApplyPanelColors = function(self) colors = colors + 1; return apply and apply(self) end
    tracker.Rebuild = function(self) rebuilds = rebuilds + 1; return rebuild(self) end
    frame.set(false)
    equal(db.dots.frame, false)
    equal(colors, 1, "the frame changes at once")
    outline.set(0)
    equal(db.dots.outlineWidth, 0, "0 draws none")
    equal(rebuilds, 1, "the outline rebuilds the rows")
    outline.set(99)
    equal(db.dots.outlineWidth, 20, "at most 20")
    -- The profile carries both (they are under dots).
    local ns = state.toolkitNS
    ns.db.profiles["Other - Realm"] = {class = "Warlock",
        parts = {DyresDebuffTracker = {dots = {frame = true, outlineWidth = 5}}}, pending = {}}
    local before = colors
    equal(ns.profile:CopyFrom("Other - Realm"), true)
    equal(db.dots.frame, true, "copied")
    equal(db.dots.outlineWidth, 5, "copied")
    assert(colors > before, "the profile refresh applies the frame")
    -- Bad saved values are repaired.
    for _, bad in ipairs({"no", 0, {}}) do
        local dots = fixture({saved = {dots = {frame = bad, outlineWidth = bad}}}).ddt.db.dots
        equal(dots.frame, true, "saved frame " .. tostring(bad))
        equal(dots.outlineWidth, bad == 0 and 0 or 3, "saved outline " .. tostring(bad))
    end
    local dots = fixture({saved = {dots = {frame = false, outlineWidth = 2.5}}}).ddt.db.dots
    equal(dots.frame, false, "false stays")
    equal(dots.outlineWidth, 3, "not whole: the default")
    equal(fixture({saved = {dots = {outlineWidth = -4}}}).ddt.db.dots.outlineWidth, 0, "clamped")
    -- Without the frame flag (an older Toolkit): no checkbox, no error; the outline slider stays.
    local old = fixture({oldPanels = true, before = function(s) s.toolkit.TRACKER_FRAME = nil end})
    equal(old.settings.DDT_DOTS_FRAME, nil)
    assert(old.settings.DDT_DOTS_OUTLINE, "every supported Toolkit has the outline")
    equal(#old.messages, 0)
    equal(old.ddt.db.dots.frame, true, "still saved and repaired")
end)

-- DDT is the one home for the Warlock's DoTs (John, via the lead, 2026-11-20:
-- "Users of WTF should manage their DoT tracking features in DDT ... This
-- includes DoT Colors, tracker panels, etc."; "Yes, full move").
test("WTF parity: every WTF tracker and prediction setting has a DDT row", function()
    local state = fixture({oldPanels = true})
    local s = state.settings
    for _, name in ipairs({
            -- General (WTF: Theme, outline, Hide empty, plate dots, offset, opacity, health, health text)
            "DDT_DOTS_THEME", "DDT_DOTS_OUTLINE", "DDT_DOTS_PLATES", "DDT_DOTS_PLATES_OFFSET",
            "DDT_DOTS_PLATES_OPACITY", "DDT_DOTS_HEALTH", "DDT_DOTS_HEALTH_TEXT",
            -- Sizes per look, and the name position
            "DDT_DOTS_COMPACT_ICONSIZE", "DDT_DOTS_COMPACT_NAMEWIDTH", "DDT_DOTS_COMPACT_TEXTSCALE",
            "DDT_DOTS_COMPACT_NAMEPOSITION", "DDT_DOTS_BARS_BARWIDTH", "DDT_DOTS_BARS_LINEHEIGHT",
            "DDT_DOTS_BARS_TEXTSCALE", "DDT_DOTS_BARS_NAMEPOSITION",
            -- Each panel: color and opacity
            "DDT_DOTS_PANEL_COLOR_TARGET", "DDT_DOTS_PANEL_COLOR_FOCUS", "DDT_DOTS_PANEL_COLOR_LIST",
            "DDT_DOTS_PANEL_OPACITY_TARGET", "DDT_DOTS_PANEL_OPACITY_FOCUS", "DDT_DOTS_PANEL_OPACITY_LIST",
            -- The curse slot
            "DDT_DOTS_CURSE_MODE", "DDT_DOTS_CURSE_MARKER",
            -- Damage to come
            "DDT_PREDICT", "DDT_PREDICT_PLATES", "DDT_PREDICT_DIES", "DDT_PREDICT_FILL", "DDT_PREDICT_COLOR",
            "DDT_PREDICT_OPACITY", "DDT_PREDICT_OUTLINE", "DDT_PREDICT_DIES_PLACE", "DDT_PREDICT_DIES_X",
            "DDT_PREDICT_DIES_Y", "DDT_PREDICT_PLATE_DIES_PLACE", "DDT_PREDICT_PLATE_DIES_X",
            "DDT_PREDICT_PLATE_DIES_Y",
            -- Crowd control (WTF: markers, macros, plate timers; Bar size is the widget's)
            "DDT_CONTROL_MACROS", "DDT_CONTROL_PLATES", "DDT_CONTROL_MARKER_BANISH"}) do
        assert(s[name], "a DDT row for " .. name)
        equal(s[name].category, name:find("^DDT_CONTROL") and "Crowd Control"
            or (name:find("^DDT_DOTS_PLATES") or name:find("^DDT_DOTS_ORDER") or name:find("^DDT_DOTS_COLOR")
                or name:find("^DDT_DOTS_ONPLATE")) and "DoTs" or "DoT Tracker", name)
    end
    -- Each DoT: its place, color, and nameplate dot, for every Warlock slot.
    local slots = state.ddt.classData.dots
    for index, slot in ipairs(slots) do
        assert(s["DDT_DOTS_ORDER_" .. index], "place " .. index)
        assert(s["DDT_DOTS_COLOR_" .. slot.key:upper()], slot.key .. " color")
        assert(s["DDT_DOTS_ONPLATE_" .. slot.key:upper()], slot.key .. " dot")
    end
    assert(state.buttons["Tracker size: Reset size"], "Reset size")
    assert(state.buttons["Each DoT: Reset order and colors"], "Reset order and colors")
    -- A Mage has no curse slot.
    local mage = fixture({className = "Mage", class = "MAGE", book = {{133, "Fireball"}, {118, "Polymorph"}}})
    equal(mage.settings.DDT_DOTS_CURSE_MODE, nil)
    assert(mage.settings.DDT_DOTS_PANEL_COLOR_TARGET, "the panels are for every class")
end)

test("WTF parity: colors, order, sizes, panels, and nameplate dots apply and are repaired", function()
    local state = fixture({oldPanels = true})
    local ddt, s = state.ddt, state.settings
    local db, tracker = ddt.db, ddt.dotTracker
    local rebuilds, colors, opacity = 0, 0, 0
    local rebuild, apply, panelOpacity = tracker.Rebuild, tracker.ApplyPanelColors, tracker.ApplyPanelOpacity
    tracker.Rebuild = function(self) rebuilds = rebuilds + 1; return rebuild(self) end
    tracker.ApplyPanelColors = function(self) colors = colors + 1; return apply(self) end
    tracker.ApplyPanelOpacity = function(self) opacity = opacity + 1; return panelOpacity(self) end
    -- Slot colors: WTF's defaults, read live by the tracker and the plate dots.
    equal(db.dots.colors.curse, "ff9e40d9")
    s.DDT_DOTS_COLOR_CORRUPTION.set("FF112233")
    equal(db.dots.colors.corruption, "ff112233", "lower case")
    equal(select(1, tracker:SlotColor("corruption")), 0x11 / 255, "the tracker reads it")
    assert(rebuilds > 0, "the bars are rebuilt")
    s.DDT_DOTS_COLOR_CORRUPTION.set("red")
    equal(db.dots.colors.corruption, "ffffffff", "a bad color is the default")
    -- Panel colors: at once.
    equal(db.dots.panelColors.target, "ff8787ed")
    local before = colors
    s.DDT_DOTS_PANEL_COLOR_FOCUS.set("ff00ff00")
    equal(db.dots.panelColors.focus, "ff00ff00")
    assert(colors > before, "the panel colors apply at once")
    -- Panel opacity: at once.
    s.DDT_DOTS_PANEL_OPACITY_LIST.set(40)
    equal(db.dots.panelOpacity.list, 40)
    equal(opacity, 1)
    -- Order: a pick swaps two places.
    local order = db.dots.order
    local first, third = order[1], order[3]
    before = rebuilds
    s.DDT_DOTS_ORDER_1.set(third)
    equal(order[1], third)
    equal(order[3], first, "swapped")
    assert(rebuilds > before)
    state.buttons["Each DoT: Reset order and colors"]()
    equal(db.dots.order[1], first, "the class order again")
    equal(db.dots.colors.corruption, "ffffffff")
    -- Sizes, one by one: Tracker size shows the nearest percent; no percent overwrites them.
    s.DDT_DOTS_BARS_BARWIDTH.set(400)
    equal(db.dots.sizes.bars.barWidth, 400)
    equal(db.dots.trackerSize, false, "set one by one")
    equal(s.DDT_DOTS_TRACKER_SIZE.get(), 125, "the nearest percent, clamped")
    s.DDT_DOTS_BARS_LINEHEIGHT.set(99)
    equal(db.dots.sizes.bars.lineHeight, 28, "clamped")
    s.DDT_DOTS_BARS_NAMEPOSITION.set("below")
    equal(db.dots.sizes.bars.namePosition, "below")
    -- Listed and greyed, never hidden: the other look's rows are greyed, and
    -- grey live when the Theme changes.
    equal(s.DDT_DOTS_BARS_BARWIDTH.initializer.modify(), true, "Bars sizes are active with Bars")
    equal(s.DDT_DOTS_COMPACT_ICONSIZE.initializer.modify(), false, "Compact's are greyed")
    equal(s.DDT_DOTS_COMPACT_NAMEPOSITION.initializer.modify(), false, "and Compact's name position")
    local watched = table.concat(s.DDT_DOTS_COMPACT_ICONSIZE.initializer.watch or {}, ",")
    contains(watched, "DDT_DOTS_THEME", "the row watches the Theme")
    db.dots.theme = "compact"
    equal(s.DDT_DOTS_COMPACT_ICONSIZE.initializer.modify(), true, "Compact's are active with Compact")
    equal(s.DDT_DOTS_BARS_BARWIDTH.initializer.modify(), false, "Bars' are greyed")
    db.dots.theme = "bars"
    local saved = fixture({saved = {dots = {trackerSize = false, sizes = {bars = {barWidth = 400}}}}}).ddt.db.dots
    equal(saved.sizes.bars.barWidth, 400, "kept at login")
    equal(saved.trackerSize, false)
    state.buttons["Tracker size: Reset size"]()
    equal(db.dots.sizes.bars.barWidth, 290)
    equal(db.dots.sizes.bars.namePosition, "above")
    s.DDT_DOTS_TRACKER_SIZE.set(75)
    equal(db.dots.trackerSize, 75, "the percent again")
    equal(db.dots.sizes.bars.barWidth, 218)
    -- Nameplate dots: height, opacity, and each DoT's dot.
    s.DDT_DOTS_PLATES_OFFSET.set(80)
    equal(db.dots.plateDotsOffset, 80)
    s.DDT_DOTS_PLATES_OPACITY.set(55)
    equal(db.dots.plateDotsOpacity, 55)
    s.DDT_DOTS_ONPLATE_CONTROL.set(true)
    equal(db.dots.onPlates.control, true)
    -- Damage to come: fill, opacity, outline.
    s.DDT_PREDICT_FILL.set("solid")
    s.DDT_PREDICT_OPACITY.set(50)
    s.DDT_PREDICT_OUTLINE.set("none")
    equal(db.predict.fill, "solid")
    equal(db.predict.opacity, 50)
    equal(db.predict.outline, "none")
    -- Repair at login.
    local bad = fixture({saved = {dots = {colors = {curse = 5}, panelColors = {list = "nope"}, curseMode = "x",
        curseMarker = "no"}}}).ddt.db.dots
    equal(bad.colors.curse, "ff9e40d9")
    equal(bad.panelColors.list, "ff545454")
    equal(bad.curseMode, "last")
    equal(bad.curseMarker, true)
end)

-- John, 2026-11-21: "The panel settings need to be organized by the panel
-- they control, and each needs it's own config (size, border width, etc.) In
-- the "Panels" section, with a sub-section heading for Target, Focus, and
-- Other"; "The show mob health checkbox, and text config ... are missing
-- from the Target/Focus/Others boxes".
test("Panels: one sub-section per panel with its own rows; the tracker-wide rows go", function()
    local realFlag
    local state = fixture({before = function(st)
        realFlag = type(st.toolkit.TRACKER_PANEL_OPTIONS) == "table"
        st.toolkit.TRACKER_PANEL_OPTIONS = st.toolkit.TRACKER_PANEL_OPTIONS or {"health"}
    end})
    local s, db, tracker = state.settings, state.ddt.db, state.ddt.dotTracker
    for _, name in ipairs({"Panels", "Target panel", "Focus panel", "Others panel"}) do
        assert(state.heading("DoT Tracker: " .. name), "the heading " .. name)
    end
    for _, key in ipairs({"TARGET", "FOCUS", "LIST"}) do
        for _, row in ipairs({"HEALTH", "HEALTH_TEXT", "TRACKER_SIZE", "BARS_BARWIDTH", "BARS_LINEHEIGHT",
                "BARS_TEXTSCALE", "BARS_NAMEPOSITION", "COMPACT_ICONSIZE", "COMPACT_NAMEWIDTH", "COMPACT_TEXTSCALE",
                "COMPACT_NAMEPOSITION"}) do
            assert(s["DDT_PANEL_" .. key .. "_" .. row], key .. " " .. row)
            equal(s["DDT_PANEL_" .. key .. "_" .. row].category, "DoT Tracker")
        end
        for _, row in ipairs({"DDT_DOTS_PANEL_COLOR_", "DDT_DOTS_PANEL_OPACITY_"}) do
            assert(s[row .. key], row .. key)
        end
    end
    if state.toolkit.TRACKER_FRAME == true then
        assert(s.DDT_PANEL_TARGET_FRAME and s.DDT_PANEL_LIST_FRAME, "each panel's frame")
    end
    assert(s.DDT_PANEL_TARGET_OUTLINE and s.DDT_PANEL_FOCUS_OUTLINE, "the pinned panels' outline")
    equal(s.DDT_PANEL_TARGET_OUTLINE.get(), 3, "the slider reads 3")
    equal(state.ddt.WholeLabel(3), "3", "and shows the number")
    equal(s.DDT_PANEL_LIST_OUTLINE, nil, "the list has no outline")
    for _, gone in ipairs({"DDT_DOTS_HEALTH", "DDT_DOTS_HEALTH_TEXT", "DDT_DOTS_TRACKER_SIZE", "DDT_DOTS_FRAME",
            "DDT_DOTS_OUTLINE", "DDT_DOTS_BARS_BARWIDTH", "DDT_DOTS_COMPACT_ICONSIZE"}) do
        equal(s[gone], nil, gone .. " is per panel now")
    end
    assert(s.DDT_DOTS_THEME and s.DDT_DOTS_PLATES, "the tracker-wide rows stay")
    -- Each panel's own values, apart.
    s.DDT_PANEL_TARGET_HEALTH.set(true)
    s.DDT_PANEL_TARGET_HEALTH_TEXT.set("both")
    s.DDT_PANEL_FOCUS_OUTLINE.set(0)
    s.DDT_PANEL_LIST_BARS_BARWIDTH.set(400)
    s.DDT_PANEL_TARGET_TRACKER_SIZE.set(75)
    equal(db.dots.panels.target.health, true)
    equal(db.dots.panels.focus.health, false, "the focus keeps its own")
    equal(db.dots.panels.target.healthText, "both")
    equal(db.dots.panels.focus.outlineWidth, 0)
    equal(db.dots.panels.target.outlineWidth, 3)
    equal(db.dots.panels.list.sizes.bars.barWidth, 400)
    equal(db.dots.panels.list.trackerSize, false, "set one by one")
    equal(s.DDT_PANEL_LIST_TRACKER_SIZE.get(), 125, "the nearest percent")
    equal(db.dots.panels.target.sizes.bars.barWidth, 218, "75%")
    if realFlag then
        local target, focus = tracker.pinned.target, tracker.pinned.focus
        assert(target.health and target.healthPercent, "the target's health and text")
        equal(focus.health, nil, "none on the focus")
        assert(target.outline, "the target's outline")
        equal(focus.outline, nil, "no outline on the focus")
        equal(target.width, 218)
        equal(focus.width, 290)
        equal(tracker.rows[1].width, 400, "the list's own width")
    end
    -- Reset: that panel only, its place kept.
    db.dots.sections.target = {point = "CENTER", relativePoint = "CENTER", x = 1, y = 2}
    db.dots.panelColors.target = "ff00ff00"
    state.buttons["Target panel: Reset Target panel"]()
    equal(db.dots.panels.target.health, false)
    equal(db.dots.panels.target.sizes.bars.barWidth, 290)
    equal(db.dots.panelColors.target, "ff8787ed")
    equal(db.dots.sections.target.x, 1, "its place stays")
    equal(db.dots.panels.focus.outlineWidth, 0, "the others keep theirs")
end)

test("Panels: the tracker-wide values become each panel's starting values once; repaired; in the profile", function()
    local saved = {dots = {health = true, healthText = "both", frame = false, outlineWidth = 5, trackerSize = 80}}
    local state = fixture({saved = saved})
    local panels = state.ddt.db.dots.panels
    for _, key in ipairs({"target", "focus", "list"}) do
        equal(panels[key].health, true, key)
        equal(panels[key].healthText, "both", key)
        equal(panels[key].frame, false, key)
        equal(panels[key].outlineWidth, 5, key)
        equal(panels[key].trackerSize, 80, key)
        equal(panels[key].sizes.bars.barWidth, 232, key)
    end
    -- Saved panels stay; a missing or bad value is the tracker-wide one.
    local own = fixture({saved = {dots = {health = false, outlineWidth = 3, panels = {
        target = {health = true, outlineWidth = 9, trackerSize = false, sizes = {bars = {barWidth = 410}}},
        focus = {healthText = "nope", outlineWidth = 2.5, frame = "x"}}}}}).ddt.db.dots.panels
    equal(own.target.health, true)
    equal(own.target.outlineWidth, 9)
    equal(own.target.trackerSize, false)
    equal(own.target.sizes.bars.barWidth, 410)
    equal(own.focus.healthText, "none", "bad: the tracker-wide one")
    equal(own.focus.outlineWidth, 3)
    equal(own.focus.frame, true)
    equal(own.list.health, false)
    -- A profile from before per-panel settings: its tracker-wide values fill each panel.
    local ns = state.toolkitNS
    ns.db.profiles["Old - Realm"] = {class = "Warlock", parts = {DyresDebuffTracker = {dots = {health = false,
        outlineWidth = 1, trackerSize = 120}}}, pending = {}}
    equal(ns.profile:CopyFrom("Old - Realm"), true)
    local copied = state.ddt.db.dots.panels
    equal(copied.focus.outlineWidth, 1)
    equal(copied.list.trackerSize, 120)
    equal(copied.target.health, false)
end)

test("Panels: the WTF import fills all three panels; an older Toolkit shows the tracker-wide rows", function()
    local wtf = {tracker = {enabled = true, health = true, healthText = "percent", outlineWidth = 0,
        sizes = {bars = {barWidth = 400, lineHeight = 20, textScale = 100, namePosition = "below"}}}}
    local state = fixture({wtf = wtf, loaded = {WarlockToolsForever = "1.11.0"},
        saved = {dots = {panels = {target = {health = false, outlineWidth = 7}}}}})
    for _, key in ipairs({"target", "focus", "list"}) do
        local panel = state.ddt.db.dots.panels[key]
        equal(panel.health, true, key .. ": WTF's")
        equal(panel.healthText, "percent", key)
        equal(panel.outlineWidth, 0, key)
        equal(panel.trackerSize, false, key)
        equal(panel.sizes.bars.barWidth, 400, key)
        equal(panel.sizes.bars.namePosition, "below", key)
    end
    -- An older Toolkit: today's tracker-wide rows; the panels follow them.
    local old = fixture({oldPanels = true})
    local s = old.settings
    assert(s.DDT_DOTS_HEALTH and s.DDT_DOTS_TRACKER_SIZE and s.DDT_DOTS_OUTLINE, "the tracker-wide rows")
    equal(s.DDT_PANEL_TARGET_HEALTH, nil, "no per-panel rows")
    equal(old.heading("DoTs: Target panel"), nil)
    s.DDT_DOTS_HEALTH.set(true)
    s.DDT_DOTS_OUTLINE.set(6)
    for _, key in ipairs({"target", "focus", "list"}) do
        equal(old.ddt.db.dots.panels[key].health, true, key .. " follows")
        equal(old.ddt.db.dots.panels[key].outlineWidth, 6, key .. " follows")
    end
    equal(#old.messages, 0, "no error")
end)

test("WTF parity: the smart curse slot, its key binding button, and \"! Curse\" while DDT has the DoTs", function()
    SPELLS[702] = "Curse of Weakness"
    local ok, why = pcall(function()
        local book = {{172, "Corruption"}, {702, "Curse of Weakness"}, {5782, "Fear"}, {710, "Banish"}}
        local state = fixture({book = book})
        local ddt, s = state.ddt, state.settings
        assert(state.named.DyresDebuffTrackerSmartCurse, "the key binding's button")
        equal(ddt.db.dots.curseMode, "last")
        s.DDT_DOTS_CURSE_MODE.set("smart")
        equal(ddt.db.dots.curseMode, "smart")
        local macro
        for _, each in ipairs(state.macros) do
            if each.name == "! Curse" then macro = each end
        end
        assert(macro, "\"! Curse\" written")
        contains(macro.body, "Curse of Weakness")
        equal(ddt.db.macrosOwned["! Curse"], true, "kept per character")
        -- Its own switch (John, 2026-11-27: "Keep ! Curse separate"): crowd
        -- control's switches leave it; "Keep the ! Curse macro" off deletes it.
        local function HasCurse()
            for _, each in ipairs(state.macros) do
                if each.name == "! Curse" then return true end
            end
            return false
        end
        s.DDT_CONTROL_MACROS.set(false)
        equal(HasCurse(), true, "the control macros off leave it")
        s.DDT_CONTROL.set(false)
        equal(HasCurse(), true, "crowd control off leaves it")
        s.DDT_CONTROL.set(true)
        s.DDT_DOTS_CURSE_MACRO.set(false)
        equal(ddt.db.dots.curseMacro, false)
        equal(HasCurse(), false, "deleted with its own switch")
        s.DDT_DOTS_CURSE_MACRO.set(true)
        equal(HasCurse(), true, "written again")
        -- Under the DoT tracker's switch, not crowd control's.
        equal(s.DDT_DOTS_CURSE_MACRO.category, "DoT Tracker")
        equal(Watched(s.DDT_DOTS_CURSE_MACRO), state.toolkit.WatchSettings and "DDT_DOTS" or "")
        -- A save from before starts from the control macros switch.
        equal(ddt.SanitizeDB({control = {macros = false}}, ddt.classData).dots.curseMacro, false)
        equal(ddt.SanitizeDB({}, ddt.classData).dots.curseMacro, true)
        equal(ddt.SanitizeDB({control = {macros = false}, dots = {curseMacro = true}}, ddt.classData).dots.curseMacro,
            true, "its own value wins")
        -- WTF has the DoTs (an older WTF that claims): DDT writes nothing.
        local wtf = fixture({book = book, loaded = {WarlockToolsForever = "1.10.1"}, before = function(st)
            st.toolkit.ClaimOwner("dots:WARLOCK", "WarlockToolsForever", 10)
        end})
        wtf.settings.DDT_DOTS_CURSE_MODE.set("smart")
        for _, each in ipairs(wtf.macros) do
            assert(each.name ~= "! Curse", "WTF keeps its own")
        end
        -- WTF's tracker off: DDT has the DoTs, and writes it.
        wtf.toolkit.SetOwnerEnabled("dots:WARLOCK", "WarlockToolsForever", false)
        local found = false
        for _, each in ipairs(wtf.macros) do
            found = found or each.name == "! Curse"
        end
        assert(found, "written once DDT has the DoTs")
        -- A Mage: no button.
        local mage = fixture({className = "Mage", class = "MAGE", book = {{133, "Fireball"}}})
        equal(mage.named.DyresDebuffTrackerSmartCurse, nil)
    end)
    SPELLS[702] = nil
    assert(ok, why)
end)

test("WTF import: once, WTF's values win where WTF had the part; never written; one chat line", function()
    local wtf = {
        tracker = {enabled = true, theme = "compact", outlineWidth = 0, hideEmpty = true, health = true,
            healthText = "both", plateDots = true, plateDotsOffset = 70, plateDotsOpacity = 60,
            sizes = {compact = {iconSize = 30, nameWidth = 150, textScale = 120, namePosition = "right"},
                bars = {barWidth = 420, lineHeight = 20, textScale = 90, namePosition = "below"}},
            order = {"immolate", "corruption", "curse", "bane", "siphon", "control"},
            colors = {corruption = "ff123456"}, panelColors = {target = "ff00ff00"},
            panelOpacity = {list = 50}, show = {target = false}, onPlates = {control = true},
            position = {point = "CENTER", relativePoint = "CENTER", x = 10, y = 20},
            sections = {focus = {point = "TOP", relativePoint = "TOP", x = 1, y = -2}},
            curseMode = "smart", curseMarker = false, lastCurse = "Curse of Agony", locked = true},
        predict = {enabled = true, color = "green", fill = "solid", opacity = 40, outline = "none",
            diesPlace = "left", diesX = 5, plateDiesY = -7},
        control = {enabled = true, scale = 80, plateTimers = false, macros = true, markers = {banish = 3},
            position = {point = "CENTER", relativePoint = "CENTER", x = -5, y = -6}},
        announce = {fearGroup = true},
    }
    local before = {}
    local function Snapshot(value, into)
        for key, each in pairs(value) do
            into[key] = type(each) == "table" and Snapshot(each, {}) or each
        end
        return into
    end
    Snapshot(wtf, before)
    local state = fixture({wtf = wtf, loaded = {WarlockToolsForever = "1.11.0"}, saved = {dots = {theme = "bars", grow = {list = "up"}}}})
    local db = state.ddt.db
    equal(db.toolsImported, true)
    equal(db.dots.theme, "compact")
    equal(db.dots.outlineWidth, 0)
    equal(db.dots.hideEmpty, true)
    equal(db.dots.healthText, "both")
    equal(db.dots.plateDotsOffset, 70)
    equal(db.dots.sizes.bars.barWidth, 420, "WTF's sizes, as they were")
    equal(db.dots.sizes.compact.namePosition, "right")
    equal(db.dots.trackerSize, false, "no percent overwrites them")
    equal(db.dots.order[1], "immolate")
    equal(db.dots.colors.corruption, "ff123456")
    equal(db.dots.colors.curse, "ff9e40d9", "a color WTF lacked: the default")
    equal(db.dots.panelColors.target, "ff00ff00")
    equal(db.dots.panelOpacity.list, 50)
    equal(db.dots.show.target, false)
    equal(db.dots.onPlates.control, true)
    equal(db.dots.position.x, 10)
    equal(db.dots.sections.focus.y, -2)
    equal(db.dots.curseMode, "smart")
    equal(db.dots.curseMarker, false)
    equal(db.dots.lastCurse, "Curse of Agony")
    equal(db.dots.grow.list, "up", "DDT's own keys stay")
    equal(db.dots.locked, nil, "WTF's lock copy is left")
    equal(db.predict.color, "green")
    equal(db.predict.fill, "solid")
    equal(db.predict.diesX, 5)
    equal(db.predict.plateDiesY, -7)
    equal(db.control.scale, 80)
    equal(db.control.plateTimers, false)
    equal(db.control.markers.banish, 3)
    equal(db.control.position.x, -5)
    assert(state.said("Copied your DoT tracker"), "one chat line")
    -- Never written: WTF's table is as it was, and DDT holds no reference into it.
    local after = Snapshot(wtf, {})
    local function Same(a, b, path)
        for key, value in pairs(a) do
            if type(value) == "table" then
                Same(value, b[key], path .. "." .. key)
            else
                equal(b[key], value, path .. "." .. key)
            end
        end
    end
    Same(before, after, "wtf")
    Same(after, before, "wtf")
    assert(db.dots.sizes ~= wtf.tracker.sizes and db.dots.position ~= wtf.tracker.position, "copies")
    -- The engines read the copied values.
    equal(state.ddt.dotTracker.theme, "compact")
    -- Once: a second login does not copy again.
    wtf.tracker.theme = "bars"
    local again = fixture({wtf = wtf, loaded = {WarlockToolsForever = "1.11.0"}, saved = db})
    equal(again.ddt.db.dots.theme, "compact", "not copied twice")
    equal(again.said("Copied your DoT tracker"), false)
end)

test("WTF import: a part WTF had off keeps DDT's values; macros always come; not a Warlock, nothing", function()
    local wtf = {tracker = {enabled = false, theme = "compact"}, predict = {enabled = false, color = "green"},
        control = {enabled = false, scale = 60, macros = false, markers = {banish = 2}}}
    local state = fixture({wtf = wtf, loaded = {WarlockToolsForever = "1.11.0"}, saved = {dots = {theme = "bars"}, predict = {color = "red"},
        control = {scale = 120}}})
    local db = state.ddt.db
    equal(db.dots.theme, "bars", "DDT's tracker showed: its values stay")
    equal(db.dots.enabled, true)
    equal(db.predict.color, "red")
    equal(db.control.scale, 120)
    equal(db.control.macros, false, "WTF kept the macros: its switch comes")
    equal(db.control.markers.banish, 2)
    equal(db.toolsImported, true)
    -- No WTF saved variables: marked done, no line.
    local none = fixture()
    equal(none.ddt.db.toolsImported, true)
    equal(none.said("Copied your"), false)
    -- A Mage with WTF's table (an alt's folder): nothing copied.
    local mage = fixture({className = "Mage", class = "MAGE", book = {{133, "Fireball"}},
        wtf = {tracker = {theme = "compact"}}})
    equal(mage.ddt.db.dots.theme, "bars")
    equal(mage.said("Copied your"), false)
    -- A profile copy counts as done.
    local copied = fixture()
    copied.ddt.db.toolsImported = false
    local ns = copied.toolkitNS
    ns.db.profiles["Other - Realm"] = {class = "Warlock", parts = {DyresDebuffTracker = {dots = {}}}, pending = {}}
    equal(ns.profile:CopyFrom("Other - Realm"), true)
    equal(copied.ddt.db.toolsImported, true)
end)

test("Tools import waits while the Tools AddOn still claims, then runs once at its handover version", function()
    local wtf = {tracker = {enabled = true, theme = "compact"}}
    local old = fixture({wtf = wtf, loaded = {WarlockToolsForever = "1.10.1"}})
    equal(old.ddt.db.toolsImported, false, "WTF 1.10 still has the parts: wait")
    equal(old.ddt.db.dots.theme, "bars")
    equal(old.said("Copied your"), false)
    local unreadable = fixture({wtf = wtf, loaded = {WarlockToolsForever = "dev"}})
    equal(unreadable.ddt.db.toolsImported, false, "an unreadable version waits too")
    -- WTF 1.11.0 a day later: the copy runs with what WTF 1.10 last saved.
    wtf.tracker.theme = "compact"
    local new = fixture({wtf = wtf, saved = old.ddt.db, loaded = {WarlockToolsForever = "1.11.0"}})
    equal(new.ddt.db.toolsImported, true)
    equal(new.ddt.db.dots.theme, "compact")
    assert(new.said("Copied your DoT tracker, damage prediction, and crowd-control settings from Warlock Tools "
        .. "Forever"), "one line")
end)

test("WTF import: the Fear, Banish, Enslave, and Howl messages and texts come over; WTF's credit is dropped", function()
    local credit = " - via Warlock Tools Forever (WTF)"
    local wtf = {announce = {enabled = true, channel = "say", fearGroup = true,
        fearGroupText = "Fearing >> %T <<. Let it run" .. credit, banishGroup = false, banishGroupText = "Moon on %T",
        enslaveGroup = true, howlGroup = true, summonGroup = true}}
    local state = fixture({wtf = wtf, loaded = {WarlockToolsForever = "1.11.0"}})
    local control = state.ddt.db.control
    equal(control.announce.fear, true)
    equal(control.texts.fear, "Fearing >> %T <<. Let it run", "WTF's credit dropped, no other name added")
    equal(control.announce.banish, false)
    equal(control.texts.banish, "Moon on %T", "the player's own text as written")
    equal(control.announce.enslave, true)
    equal(control.announce.howl, true)
    equal(control.texts.howl, "Howl of Terror!", "no WTF text: DDT's default")
    equal(control.say, true, "WTF's Say channel")
    equal(control.summonGroup, nil, "WTF's own messages stay in WTF")
    -- WTF's master switch off silenced them all.
    wtf.announce.enabled = false
    local off = fixture({wtf = wtf, loaded = {WarlockToolsForever = "1.11.0"}}).ddt.db.control
    equal(off.announce.fear, false)
    equal(off.announce.howl, false)
end)

test("WTF's smart curse key moves to DDT's binding, once, out of combat; a DDT key stays", function()
    local function WithBindings(keys, combat)
        return function(state)
            state.bindings, state.saves = keys, 0
            state.combat = combat
            state.env.GetBindingKey = function(command)
                local list = {}
                for key, bound in pairs(state.bindings) do
                    if bound == command then list[#list + 1] = key end
                end
                table.sort(list)
                return unpack(list)
            end
            state.env.SetBinding = function(key, command) state.bindings[key] = command end
            state.env.GetCurrentBindingSet = function() return 2 end
            state.env.SaveBindings = function(set) state.saves = state.saves + 1; state.savedSet = set end
        end
    end
    local wtfCommand = "CLICK WarlockToolsForeverSmartCurse:LeftButton"
    local ddtCommand = "CLICK DyresDebuffTrackerSmartCurse:LeftButton"
    local state = fixture({before = WithBindings({F = wtfCommand, ["SHIFT-F"] = wtfCommand})})
    equal(state.bindings.F, ddtCommand)
    equal(state.bindings["SHIFT-F"], ddtCommand)
    equal(state.saves, 1)
    equal(state.savedSet, 2, "saved to the current set")
    assert(state.said("Smart curse key (F, SHIFT-F)"), "said once")
    -- DDT's binding has a key: nothing changes.
    local kept = fixture({before = WithBindings({F = wtfCommand, G = ddtCommand})})
    equal(kept.bindings.F, wtfCommand)
    equal(kept.saves, 0)
    -- No key at all: nothing bound, nothing saved, nothing said.
    local none = fixture({before = WithBindings({})})
    equal(next(none.bindings), nil)
    equal(none.saves, 0)
    equal(none.said("Smart curse key"), false)
    -- In combat at login: when combat ends.
    local fight = fixture({before = WithBindings({F = wtfCommand}, true)})
    equal(fight.bindings.F, wtfCommand, "not in combat")
    fight.combat = false
    emit(fight, "PLAYER_REGEN_ENABLED")
    equal(fight.bindings.F, ddtCommand, "after combat")
    equal(fight.saves, 1, "saved once, after combat")
    -- A Mage: nothing.
    local mage = fixture({className = "Mage", class = "MAGE", book = {{133, "Fireball"}},
        before = WithBindings({F = wtfCommand})})
    equal(mage.bindings.F, wtfCommand)
end)

test("the next WTF's macros are adopted in place: same index, so action bars keep them", function()
    local macros = {{name = "! Curse", body = "x"}, {name = "Mine", body = "y"}, {name = "! Fear", body = "WTF's"},
        {name = "! Banish", body = "WTF's"}}
    local state = fixture({macros = macros, loaded = {WarlockToolsForever = "1.11.0"}})
    equal(state.macros[3].name, "! Fear", "same index")
    equal(state.macros[4].name, "! Banish", "same index")
    assert(state.macros[3].body ~= "WTF's", "rewritten in place")
    equal(state.macros[2].name, "Mine", "the player's own macro untouched")
    assert(state.said("keeps your \"! Fear\" macro now"), "said")
end)

test("MTF import: the Polymorph bar's settings, macro, moon, and message come over once at MTF 1.6.0", function()
    local mage = {className = "Mage", class = "MAGE", book = {{133, "Fireball"}, {118, "Polymorph"}}}
    local function Mage(extra)
        local options = {}
        for key, value in pairs(mage) do options[key] = value end
        for key, value in pairs(extra) do options[key] = value end
        return fixture(options)
    end
    local mtf = {polymorph = {enabled = true, scale = 80, width = 300, height = 20, textScale = 120, opacity = 60,
        mark = false, macro = true, position = {point = "CENTER", relativePoint = "CENTER", x = 3, y = 4}},
        announce = {polymorphGroup = false, polymorphGroupText = "Sheeping %T"}, conjure = {macros = true}}
    local waiting = Mage({mtf = mtf, loaded = {MageToolsForever = "1.5.1"}})
    equal(waiting.ddt.db.toolsImported, false, "MTF 1.5 still has the bar")
    local state = Mage({mtf = mtf, loaded = {MageToolsForever = "1.6.0"}})
    local control = state.ddt.db.control
    equal(control.scale, 80)
    equal(control.width, 300)
    equal(control.barHeight, 20)
    equal(control.textScale, 120)
    equal(control.opacity, 60)
    equal(control.position.x, 3)
    equal(control.markers.polymorph, 0, "no moon")
    equal(control.macros, true)
    equal(control.announce.polymorph, false)
    equal(control.texts.polymorph, "Sheeping %T")
    assert(state.said("Copied your Polymorph bar settings from Mage Tools Forever"), "one line")
    equal(mtf.polymorph.height, 20, "MTF's table is never written")
    equal(mtf.polymorph.mark, false)
    -- MTF's bar off: DDT's bar showed, its bar values stay; the macro and moon still come.
    local off = Mage({mtf = {polymorph = {enabled = false, width = 300, mark = true, macro = false}},
        loaded = {MageToolsForever = "1.6.0"}}).ddt.db.control
    equal(off.width, 200, "DDT's own")
    equal(off.position, nil, "DDT's own place")
    -- MTF's bar never moved: it stays at MTF's default place.
    local unmoved = Mage({mtf = {polymorph = {enabled = true}}, loaded = {MageToolsForever = "1.6.0"}}).ddt.db.control
    equal(unmoved.position.y, 60, "MTF's default place")
    equal(off.macros, false)
    equal(off.markers.polymorph, 5, "the moon")
end)

test("the crowd-control bar's look: width, bar height, text size, opacity; a Mage's bar is MTF's", function()
    local state = fixture()
    local s, db, ddt = state.settings, state.ddt.db, state.ddt
    for _, name in ipairs({"WIDTH", "BARHEIGHT", "TEXTSCALE", "OPACITY", "SCALE"}) do
        local setting = s["DYRE_DYRESDEBUFFTRACKER_CONTROL_" .. name]
        assert(setting, "the " .. name .. " slider")
        equal(setting.category, "Crowd Control")
    end
    -- The defaults draw the Toolkit's own look.
    local look = ddt.ControlLook()
    equal(look.width, 200)
    equal(look.header, 18)
    equal(look.line, 16)
    equal(look.icon, 14)
    equal(look.alpha, 1)
    equal(#ddt.controlTracker.rows, 5, "a Warlock's five rows")
    db.control.width, db.control.barHeight, db.control.textScale, db.control.opacity = 300, 20, 150, 50
    look = ddt.ControlLook()
    equal(look.width, 300)
    equal(look.header, 27)
    equal(look.icon, 18)
    equal(look.alpha, 0.5)
    local bad = fixture({saved = {control = {width = 999, barHeight = 2, textScale = 83, opacity = "x"}}}).ddt.db.control
    equal(bad.width, 400)
    equal(bad.barHeight, 10)
    equal(bad.textScale, 85)
    equal(bad.opacity, 100)
    -- A Mage: one row, MTF's purple, the spell's name on the bar.
    local mage = fixture({className = "Mage", class = "MAGE", book = {{133, "Fireball"}, {118, "Polymorph"}}})
    equal(#mage.ddt.controlTracker.rows, 1, "one Polymorph at a time")
    local mlook = mage.ddt.ControlLook()
    equal(mlook.color[1], 0.75)
    equal(mlook.label, true)
end)

test("handover: DDT steps aside for a WTF that claims, in either load order, and takes over when it stops", function()
    -- WTF first (it claims before DDT's login).
    local first = fixture({loaded = {WarlockToolsForever = "1.10.1"}, before = function(st)
        for _, kind in ipairs({"dots", "control", "macros", "announce"}) do
            st.toolkit.ClaimOwner(kind .. ":WARLOCK", "WarlockToolsForever", 10)
        end
    end})
    equal(first.ddt.dotTracker:IsOwner(), false)
    equal(first.ddt.KindStatus("dots"), "Warlock Tools Forever")
    equal(first.ddt.KindStatus("control"), "Warlock Tools Forever")
    -- DDT first (WTF claims after DDT's login).
    local second = fixture({loaded = {WarlockToolsForever = "1.10.1"}})
    equal(second.ddt.dotTracker:IsOwner(), true, "DDT's until WTF claims")
    for _, kind in ipairs({"dots", "control", "macros", "announce"}) do
        second.toolkit.ClaimOwner(kind .. ":WARLOCK", "WarlockToolsForever", 10)
    end
    equal(second.ddt.dotTracker:IsOwner(), false, "WTF's claim wins after")
    equal(second.ddt.KindStatus("control"), "Warlock Tools Forever")
    -- The next WTF claims nothing: DDT has everything, loaded or not.
    local next = fixture({loaded = {WarlockToolsForever = "1.11.0"}})
    equal(next.ddt.yieldsTo, nil)
    equal(next.ddt.dotTracker:IsOwner(), true)
    equal(next.ddt.KindStatus("dots"), "ours")
    equal(next.ddt.KindStatus("control"), "ours")
    equal(next.toolkit.HealthBars.IsActiveSource("DyresDebuffTracker"), true)
    equal(next.ddt.PRIORITY, 5, "DDT keeps priority 5")
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
local MAGE = {class = "MAGE", className = "Mage", book = {{118, "Polymorph"}, {133, "Fireball"}},
    talents = {[11180] = true}}

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
    equal(setting.category, "Debuff Cues")
    equal(setting.default, true)
    equal(state.ddt.db.frost.enabled, true, "on by default")
    assert(state.heading("Debuff Cues: Frozen and chilled"), "its heading on the Debuff Cues page")
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
    -- A friendly unit: no holder on its plate. UNIT_FLAGS follows a change.
    AddPlate(state, "nameplate2", false)
    equal(arcs.byUnit.nameplate2, nil)
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
    equal(state.said("frost on=true engine=engine holders=10 plates=1 shown=1 visible=1 anchors=[Blizzard=1]"),
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

-- The Warlock's Demonic Brand pentagram (John, via the lead, 2026-11-21:
-- "Demonic Brand (for Demonology Warlocks): we need to add it. It's a debuff
-- on your current target"; then "Make it a glowing red pentagram that renders
-- above the nameplate, and make it so the size and height can be adjusted").
local BRAND = {[1293696] = "Demonic Brand"}

local function Branded(extra)
    local options = {spells = BRAND}
    for key, value in pairs(extra or {}) do options[key] = value end
    return fixture(options)
end

local function ReadTGA(name)
    local data = assert(io.open("Textures/" .. name .. ".tga", "rb")):read("*a")
    return data, data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
end

test("arcs only on a hostile mob's nameplate: never your own plate, the settings preview plate, or a friendly one", function()
    local state = Mage()
    local arcs = state.ddt.frostArcs
    local env = state.env
    -- Your own nameplate (the personal plate): no holder, also if it reads as attackable.
    env.UnitIsUnit = function(a, b) return a == "nameplate5" and b == "player" end
    local own = AddPlate(state, "nameplate5", true)
    equal(arcs.byUnit.nameplate5, nil, "no holder on your own plate")
    for _, holder in ipairs(arcs.all) do
        assert(holder.parent ~= own, "nothing parented to your own plate")
    end
    emit(state, "UNIT_FLAGS", "nameplate5")
    equal(arcs.byUnit.nameplate5, nil, "UNIT_FLAGS does not attach it either")
    -- Options > Nameplates' preview plate: not a "nameplateN" token.
    local preview = AddPlate(state, "preview", true)
    equal(arcs.byUnit.preview, nil, "no holder on the settings preview plate")
    for _, holder in ipairs(arcs.all) do
        assert(holder.parent ~= preview, "nothing parented to the preview plate")
    end
    emit(state, "UNIT_FACTION", "preview")
    equal(arcs.byUnit.preview, nil)
    -- A friendly unit: none; it gets one when it turns hostile (UNIT_FACTION),
    -- and loses it when it stops being hostile.
    local friend = AddPlate(state, "nameplate6", false)
    equal(arcs.byUnit.nameplate6, nil, "no holder on a friendly plate")
    state.hostile.nameplate6 = true
    emit(state, "UNIT_FACTION", "nameplate6")
    assert(arcs.byUnit.nameplate6, "attached once hostile")
    equal(arcs.byUnit.nameplate6.parent, friend)
    state.hostile.nameplate6 = false
    emit(state, "UNIT_FACTION", "nameplate6")
    equal(arcs.byUnit.nameplate6, nil, "detached when no longer hostile")
    -- A settings change attaches again only where it may.
    state.hostile.nameplate7 = true
    AddPlate(state, "nameplate7", true)
    arcs:Refresh()
    equal(arcs.byUnit.nameplate5, nil)
    equal(arcs.byUnit.nameplate6, nil)
    assert(arcs.byUnit.nameplate7, "a hostile mob keeps its arcs")
    -- The Warlock's Demonic Brand runs the same code.
    local warlock = Branded()
    assert(warlock.ddt.brandArcs, "a Warlock on Forever has the pentagram")
    warlock.env.UnitIsUnit = function(a, b) return a == "nameplate1" and b == "player" end
    AddPlate(warlock, "nameplate1", true)
    equal(warlock.ddt.brandArcs.byUnit.nameplate1, nil, "no pentagram holder on your own plate")
    AddPlate(warlock, "nameplate2", true)
    assert(warlock.ddt.brandArcs.byUnit.nameplate2, "the pentagram on a hostile mob")
end)

test("Demonic Brand pentagram: Warlocks where the client knows it; Show, Size, Height, Reset; repaired", function()
    local state = Branded()
    assert(state.ddt.brandArcs, "a Warlock on Forever has it")
    local s = state.settings
    equal(s.DDT_BRAND.name, "Show")
    equal(s.DDT_BRAND.category, "Debuff Cues")
    equal(s.DDT_BRAND.default, true)
    equal(state.ddt.db.brand.enabled, true, "on by default")
    equal(s.DDT_BRAND_SIZE.name, "Size")
    equal(s.DDT_BRAND_SIZE.default, 100)
    equal(s.DDT_BRAND_OFFSET.name, "Height above nameplate")
    equal(s.DDT_BRAND_OFFSET.default, 10)
    -- Both sliders show their number.
    assert(s.DDT_BRAND_SIZE.labelFormatter and s.DDT_BRAND_OFFSET.labelFormatter, "label formatters")
    equal(s.DDT_BRAND_SIZE.labelFormatter(s.DDT_BRAND_SIZE.get()), "100%")
    equal(s.DDT_BRAND_OFFSET.labelFormatter(s.DDT_BRAND_OFFSET.get()), "10")
    assert(state.buttons["Reset Demonic Brand: Reset"], "the Reset button")
    -- Its own heading, on the Debuff Cues page, where Mages see "Frozen and chilled".
    local last
    for index, heading in ipairs(state.headings) do
        if heading:find("^Debuff Cues: ") and not heading:find("[", 1, true) then last = index end
    end
    equal(state.headings[last], "Debuff Cues: Demonic Brand", "the Debuff Cues page's heading")
    equal(#state.messages, 0)
    -- Every Warlock: no talent or spec is read.
    assert(Branded({book = {{172, "Corruption"}}}).ddt.brandArcs, "a Warlock without Searing Pain too")
    -- A client that does not know the debuff (Classic Era): nothing, quietly.
    local era = fixture()
    equal(era.ddt.brandArcs, nil)
    equal(era.settings.DDT_BRAND, nil)
    equal(era.heading("Demonic Brand"), nil)
    equal(#era.messages, 0, "quiet on Classic Era")
    era.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(era.said("brand off: this client lacks Demonic Brand (1293696)"), true)
    -- Other classes: none, also on Forever.
    local mage = Mage({spells = BRAND})
    equal(mage.ddt.brandArcs, nil, "none for a Mage")
    equal(mage.settings.DDT_BRAND, nil)
    mage.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(mage.said("brand none (Warlock only)"), true)
    -- Repaired.
    local bad = Branded({saved = {brand = {enabled = "yes", offset = -5, size = 999}}}).ddt.db.brand
    equal(bad.enabled, true, "not a boolean: on")
    equal(bad.offset, 0, "at least 0")
    equal(bad.size, 200, "at most 200")
    local good = Branded({saved = {brand = {enabled = false, offset = 60, size = 50}}}).ddt.db.brand
    equal(good.enabled, false)
    equal(good.offset, 60)
    equal(good.size, 50)
    -- The art: 128 x 128, uncompressed BGRA, top-left origin; the old arc is gone.
    for _, name in ipairs({"BrandPentagram", "BrandGlow"}) do
        local data, width, height = ReadTGA(name)
        equal(#data, 18 + 128 * 128 * 4, name)
        equal(width, 128, name)
        equal(height, 128, name)
        equal(data:byte(18), 0x28, name)
    end
    equal(io.open("Textures/BrandArc.tga", "rb"), nil, "no fel arc any more")
    -- Red: the pentagram's brightest pixels are red, and the glow's middle is red.
    local data = ReadTGA("BrandGlow")
    local middle = 18 + (64 * 128 + 64) * 4
    local b, g, r = data:byte(middle + 1), data:byte(middle + 2), data:byte(middle + 3)
    assert(r > 200 and g < 128 and b < 64, "the glow is red")
end)

test("Demonic Brand pentagram on Forever: one HARMFUL|PLAYER slot of 1293696, a glow that pulses, nothing read", function()
    local state = Branded({engine = true})
    local arcs = state.ddt.brandArcs
    equal(#arcs.all, state.ddt.FROST_PREWARM, "holders made ahead, out of combat")
    state.combat = true
    local plate = AddPlate(state, "nameplate1")
    local holder = arcs.byUnit.nameplate1
    assert(holder, "the plate got a holder")
    equal(#arcs.all, state.ddt.FROST_PREWARM, "from the pool: none made in combat")
    equal(holder.parent, plate)
    equal(holder.point[2], plate.UnitFrame.healthBar, "on the bar FindPlateBar finds")
    equal(holder.point[1], "BOTTOM")
    equal(holder.point[3], "TOP", "above the plate's bar")
    equal(holder.point[5], 10, "10 pixels above the bar")
    equal(holder.width, 48)
    equal(holder.height, 48)
    equal(holder.shown, true, "a hostile mob")
    local container = holder.container
    equal(container.kind, "AuraContainer", "the engine's container")
    equal(#container.slots, 1, "the brand only")
    local slot = SlotBy(container, "brand")
    equal(slot.filter, "HARMFUL|PLAYER", "only your own Brand: only your demon uses it")
    local ids = slot.options.candidateFilters.includeSpellIDs
    equal(ids[1], nil, "a set, not a list")
    equal(ids[1293696], true, "the debuff")
    equal(ids[1293695], nil, "not the hidden talent passive")
    -- The engine's button draws the glow behind the star; the glow pulses with an AnimationGroup.
    local button = slot.button
    equal(holder.arcs.brand, button)
    equal(button.width, 48)
    local glow, star = button.textures[1], button.textures[2]
    contains(glow.path, "BrandGlow")
    equal(glow.layer, "BACKGROUND")
    equal(glow.blend, "ADD")
    contains(star.path, "BrandPentagram")
    equal(star.layer, "ARTWORK")
    equal(star.width, 28)
    local pulse = glow.groups[1]
    assert(pulse, "an AnimationGroup")
    equal(pulse.looping, "BOUNCE")
    equal(pulse.playing, true)
    equal(pulse.animations[1].kind, "Alpha")
    equal(pulse.animations[1].from, 0.45)
    equal(pulse.animations[1].to, 1)
    AddPlate(state, "nameplate2", false)
    equal(arcs.byUnit.nameplate2, nil, "a friendly unit: no holder")
    -- The plate goes: the holder lets go, hides, and goes back to the pool.
    RemovePlate(state, "nameplate1")
    equal(holder.container.unit, "none")
    equal(holder.shown, false)
    equal(holder.parent, state.env.UIParent)
    equal(arcs.byUnit.nameplate1, nil)
    equal(state.auraReads, 0, "no AddOn code reads an aura")
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("brand on=true engine=engine holders=10 plates=0 shown=0 visible=0 anchors=[]"), true)
    equal(state.said("frost none (Mage only)"), true)
    -- No OnUpdate anywhere: the pulse is the client's animation.
    local text = assert(io.open("Frost.lua", "rb")):read("*a")
    equal(text:find("OnUpdate\"", 1, true), nil)
end)

test("Demonic Brand pentagram on a plain-Lua container: your Brand shows, another Warlock's does not", function()
    -- unit -> {{spellId, yours}}
    local auras = {nameplate1 = {{1293696, true}}}
    local function Read(unit, index, filter)
        local n = 0
        for _, aura in ipairs(auras[unit] or {}) do
            if aura[2] or not filter:find("PLAYER", 1, true) then
                n = n + 1
                if n == index then
                    return {spellId = aura[1], name = "x", icon = 1, duration = 10, expirationTime = 110}
                end
            end
        end
    end
    local state = Branded({auras = Read})
    AddPlate(state, "nameplate1")
    local holder = state.ddt.brandArcs.byUnit.nameplate1
    equal(holder.container.kind, "Frame", "the plain-Lua container")
    equal(holder.arcs.brand.shown, true, "your Brand")
    auras.nameplate1 = {{1293696, false}}
    emit(state, "UNIT_AURA", "nameplate1")
    equal(holder.arcs.brand.shown, false, "another Warlock's Brand helps only their demon")
    auras.nameplate1 = {{1293695, true}, {5676, true}}
    emit(state, "UNIT_AURA", "nameplate1")
    equal(holder.arcs.brand.shown, false, "the talent and Searing Pain are not the Brand")
end)

test("Demonic Brand pentagram: Show, Size, Height, and Reset apply at once; the profile carries them", function()
    local state = Branded({engine = true})
    local arcs, db = state.ddt.brandArcs, state.ddt.db
    AddPlate(state, "nameplate1")
    state.settings.DDT_BRAND_SIZE.set(200)
    state.settings.DDT_BRAND_OFFSET.set(30)
    local holder = arcs.byUnit.nameplate1
    equal(holder.scale, 2)
    equal(holder.point[5], 15, "30 pixels at scale 2")
    state.settings.DDT_BRAND.set(false)
    equal(arcs.byUnit.nameplate1, nil, "off: none")
    AddPlate(state, "nameplate2")
    equal(arcs.byUnit.nameplate2, nil, "off: a new plate gets none")
    -- Reset: on, 100%, 10 pixels, on every plate at once; the same table.
    local brand = db.brand
    state.buttons["Reset Demonic Brand: Reset"]()
    equal(db.brand, brand, "changed in place")
    equal(db.brand.enabled, true)
    equal(db.brand.size, 100)
    equal(db.brand.offset, 10)
    equal(state.settings.DDT_BRAND_SIZE.get(), 100, "the slider reads it")
    assert(arcs.byUnit.nameplate1 and arcs.byUnit.nameplate2, "both plates have it again")
    equal(arcs.byUnit.nameplate1.scale, 1)
    equal(arcs.byUnit.nameplate1.point[5], 10)
    -- A profile copy.
    local ns = state.toolkitNS
    ns.db.profiles["Other - Realm"] = {class = "Warlock", parts = {DyresDebuffTracker = {brand = {enabled = true,
        size = 50, offset = 0}}}, pending = {}}
    equal(ns.profile:CopyFrom("Other - Realm"), true)
    equal(db.brand.size, 50)
    equal(arcs.byUnit.nameplate2.scale, 0.5)
    equal(arcs.byUnit.nameplate2.point[5], 0)
    -- In the profile's data: an export of this character holds it.
    local part = state.ddt.ProfileSettings(db)
    equal(part.brand.size, 50)
    -- The Mage's arcs keep their own settings.
    equal(db.frost.size, 100)
end)

-- The lead, 2026-11-21: John's Warlock cannot apply Demonic Brand, so a
-- "Preview" button (and /ddt preview brand) shows the pentagram on the
-- target's nameplate with no debuff, to tune Size and Height live.
test("Demonic Brand preview: on the target's plate with no debuff, live, and it ends as it should", function()
    local state = Branded({engine = true, book = {{172, "Corruption"}}})
    local arcs, press = state.ddt.brandArcs, state.buttons["Preview Demonic Brand: Preview"]
    assert(press, "the Preview button")
    -- No target plate: a message, nothing shown.
    equal(press(), "no plate")
    contains(state.messages[#state.messages], "target a mob with its nameplate showing")
    equal(arcs:Previewing(), false)
    -- A target with a plate, in combat: shown on its bar, our own frame.
    local plate = AddPlate(state, "nameplate1")
    state.plates.target = plate
    state.combat = true
    equal(press(), "started")
    contains(state.messages[#state.messages], "Press Preview again, or change target")
    local on, frame = arcs:Previewing()
    equal(on, true)
    equal(frame.shown, true)
    equal(frame.parent, plate)
    equal(frame.point[2], plate.UnitFrame.healthBar, "on the bar FindPlateBar finds")
    equal(frame.point[5], 10, "the Height setting")
    equal(frame.width, 48)
    local button = frame.arcs.brand
    contains(button.textures[1].path, "BrandGlow")
    contains(button.textures[2].path, "BrandPentagram")
    equal(button.textures[1].groups[1].playing, true, "the glow pulses")
    equal(state.auraReads, 0, "no aura read")
    for _, holder in ipairs(arcs.all) do
        assert(holder ~= frame, "not an engine holder")
    end
    -- Size and Height apply to it at once; it stays while Show is off.
    state.settings.DDT_BRAND_SIZE.set(200)
    state.settings.DDT_BRAND_OFFSET.set(40)
    equal(frame.scale, 2)
    equal(frame.point[5], 20, "40 pixels at scale 2")
    state.settings.DDT_BRAND.set(false)
    equal(frame.shown, true, "for tuning, also while Show is off")
    state.buttons["Reset Demonic Brand: Reset"]()
    equal(frame.scale, 1)
    equal(frame.point[5], 10)
    -- A second press ends it.
    equal(press(), "stopped")
    equal(frame.shown, false)
    equal(frame.parent, state.env.UIParent)
    equal(arcs:Previewing(), false)
    -- A new target ends it; so does logout; so does the plate going.
    for _, event in ipairs({"PLAYER_TARGET_CHANGED", "PLAYER_LOGOUT"}) do
        equal(press(), "started")
        emit(state, event)
        equal(arcs:Previewing(), false, event)
        equal(frame.shown, false, event)
    end
    equal(press(), "started")
    AddPlate(state, "nameplate2")
    RemovePlate(state, "nameplate2")
    equal(arcs:Previewing(), true, "another plate going: kept")
    RemovePlate(state, "nameplate1")
    equal(arcs:Previewing(), false, "its plate going: ended")
    -- The slash command toggles it too.
    plate = AddPlate(state, "nameplate3")
    state.plates.target = plate
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("preview brand")
    equal(arcs:Previewing(), true, "/ddt preview brand")
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("preview")
    equal(arcs:Previewing(), false, "/ddt preview")
    equal(state.auraReads, 0)
    -- Not a Warlock, or no Demonic Brand in the client: a message only.
    local era = fixture()
    era.env.SlashCmdList.DYRESDEBUFFTRACKER("preview brand")
    contains(era.messages[#era.messages], "this client has no Demonic Brand")
    local mage = Mage({spells = BRAND})
    mage.env.SlashCmdList.DYRESDEBUFFTRACKER("preview brand")
    contains(mage.messages[#mage.messages], "Warlocks only")
    -- The help names it.
    era.env.SlashCmdList.DYRESDEBUFFTRACKER("help")
    contains(era.messages[#era.messages], "/ddt preview brand")
end)

-- John, 2026-11-21: "set notches on the sliders default values". Every
-- slider gets the Toolkit's gold default mark (AddDefaultTick) at its real
-- default, inside its real range: each page, both panel layouts, the Mage's
-- arcs, the Warlock's Brand.
test("Default marks: every slider gets the gold mark at its own default", function()
    local seen, count = {}, 0
    local function Check(state, label)
        local sliders = 0
        for variable, setting in pairs(state.settings) do
            if setting.sliderOptions then
                sliders = sliders + 1
                local mark = setting.initializer.dyreDefault
                assert(type(mark) == "table", label .. ": no default mark on " .. variable)
                equal(mark.default, setting.default, label .. " " .. variable .. " default")
                equal(mark.min, setting.sliderOptions.min, label .. " " .. variable .. " min")
                equal(mark.max, setting.sliderOptions.max, label .. " " .. variable .. " max")
                assert(mark.default >= mark.min and mark.default <= mark.max, variable .. " in range")
                if not seen[variable] then seen[variable] = true; count = count + 1 end
            end
        end
        assert(sliders > 0, label .. ": some sliders")
    end
    Check(fixture({before = function(st)
        st.toolkit.TRACKER_PANEL_OPTIONS = st.toolkit.TRACKER_PANEL_OPTIONS or {"health"}
        st.toolkit.TRACKER_OUTLINE = st.toolkit.TRACKER_OUTLINE or {min = 0, max = 20, default = 3}
    end}), "per panel")
    Check(fixture({oldPanels = true, before = function(st)
        st.toolkit.TRACKER_OUTLINE = st.toolkit.TRACKER_OUTLINE or {min = 0, max = 20, default = 3}
    end}), "tracker-wide")
    Check(Mage(), "Mage")
    Check(Branded(), "Brand")
    -- The rows named in the request, and their real defaults.
    for variable, default in pairs({DDT_PANEL_TARGET_BARS_BARWIDTH = 290, DDT_PANEL_LIST_COMPACT_ICONSIZE = 22,
            DDT_DOTS_BARS_LINEHEIGHT = 16, DDT_DOTS_COMPACT_NAMEWIDTH = 110, DDT_DOTS_BARS_TEXTSCALE = 100,
            DDT_PANEL_TARGET_OUTLINE = 3, DDT_DOTS_OUTLINE = 3, DDT_DOTS_PANEL_OPACITY_TARGET = 100,
            DDT_DOTS_TRACKER_SIZE = 100, DDT_PANEL_FOCUS_TRACKER_SIZE = 100, DDT_PREDICT_OPACITY = 70,
            DDT_PREDICT_DIES_X = 0, DDT_FROST_OFFSET = 10, DDT_FROST_SIZE = 100, DDT_BRAND_SIZE = 100,
            DDT_BRAND_OFFSET = 10}) do
        assert(seen[variable], "checked " .. variable)
    end
    assert(count >= 30, "sliders checked: " .. count)
end)

-- The Mage's Winter's Chill balls (John, 2026-11-22: "add a similar halo
-- above the nameplate (we do for chilled/frozen) with up to 5 cells (one per
-- charge) (like a rogue/druid combo-point counter)"; then: "blue frostballs
-- that turn white as the stack builds").
local function LitCells(holder, button)
    -- Segment 1 shows white with the button; the bar's fill covers segments 2 to 5.
    if not button.shown then
        return 0
    end
    local bar = holder.bar
    if not bar.shown then
        return 1
    end
    return math.max(1, math.floor(bar.value or 1))
end

test("Winter's Chill arc: Mages only, on by default, rows, repaired, both clients", function()
    local warlock = fixture({spells = BRAND})
    equal(warlock.ddt.chillArcs, nil, "no arc for a Warlock")
    equal(warlock.settings.DDT_CHILL, nil, "no rows for other classes")
    local state = Mage()
    assert(state.ddt.chillArcs, "a Mage has the arc")
    equal(state.settings.DDT_CHILL.default, true)
    equal(state.settings.DDT_CHILL.name, "Show")
    equal(state.settings.DDT_CHILL_SIZE.default, 100)
    equal(state.settings.DDT_CHILL_SIZE.labelFormatter(150), "150%")
    equal(state.settings.DDT_CHILL_OFFSET.default, 36)
    equal(state.settings.DDT_CHILL_OFFSET.name, "Height above nameplate")
    assert(state.heading("Debuff Cues: Winter's Chill"), "its heading on the Debuff Cues page")
    assert(state.buttons["Preview Winter's Chill: Preview"] and state.buttons["Reset Winter's Chill: Reset"])
    equal(state.ddt.db.wintersChill.enabled, true, "on by default")
    equal(#state.messages, 0)
    -- After the frozen and chilled rows, before nothing of the Brand's (a Mage has none).
    local frozenAt, chillAt
    for index, heading in ipairs(state.headings) do
        if heading == "Debuff Cues: Frozen and chilled" then frozenAt = index end
        if heading == "Debuff Cues: Winter's Chill" then chillAt = index end
    end
    assert(frozenAt and chillAt and chillAt > frozenAt, "after Frozen and chilled")
    local bad = Mage({saved = {wintersChill = {enabled = "yes", offset = -5, size = 999}}}).ddt.db.wintersChill
    equal(bad.enabled, true)
    equal(bad.offset, 0)
    equal(bad.size, 200)
    -- A saved height stays.
    equal(Mage({saved = {wintersChill = {offset = 40}}}).ddt.db.wintersChill.offset, 40)
    equal(Mage({saved = {wintersChill = {offset = 20}}}).ddt.db.wintersChill.offset, 20)
    -- A client without the debuff: no cells, and one line says why.
    local old = Mage({before = function(st)
        local spell = st.env.C_Spell.GetSpellName
        st.env.C_Spell.GetSpellName = function(id) if id ~= 12579 then return spell(id) end end
    end})
    equal(old.ddt.chillArcs, nil)
    equal(old.settings.DDT_CHILL, nil)
    contains(old.messages[#old.messages], "Winter's Chill arc stays off")
    old.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(old.said("chill off: this client lacks Winter's Chill (12579)"), true)
    -- The frozen and chilled arcs keep working.
    assert(old.ddt.frostArcs)
end)

test("Winter's Chill arc on Forever: one HARMFUL|PLAYER slot of 12579, five segments, the game lights them", function()
    local state = Mage({engine = true})
    local arcs = state.ddt.chillArcs
    equal(#arcs.all, state.ddt.FROST_PREWARM, "holders made ahead, out of combat")
    state.combat = true
    local plate = AddPlate(state, "nameplate1")
    local holder = arcs.byUnit.nameplate1
    equal(#arcs.all, state.ddt.FROST_PREWARM, "none made in combat")
    equal(holder.parent, plate)
    equal(holder.point[2], plate.UnitFrame.healthBar, "on the bar FindPlateBar finds")
    equal(holder.point[5], 36, "36 pixels above the bar: over the frozen and chilled arcs")
    equal(holder.width .. "x" .. holder.height, "64x16", "the holder fits the arc")
    local slot = SlotBy(holder.container, "chill")
    equal(#holder.container.slots, 1)
    equal(slot.filter, "HARMFUL|PLAYER", "only your own: it helps only your Cone of Cold")
    local ids = slot.options.candidateFilters.includeSpellIDs
    equal(ids[1], nil, "a set, not a list")
    equal(ids[12579], true, "the debuff")
    equal(ids[11180], nil, "not the talent")
    -- The button: the arc in blue, segment 1 white, and the bar of white segments over segments 2 to 5.
    local button = slot.button
    equal(holder.arcs.chill, button)
    equal(button.width, 64, "as wide as the frozen and chilled arcs")
    equal(button.height, 16)
    local empties, lit = 0, 0
    for _, texture in ipairs(button.textures) do
        if texture.layer == "BORDER" then
            empties = empties + 1
            equal(texture.path:match("Textures\\(%w+)$"), "ChillArc")
            equal(texture.all, button, "the whole arc")
            equal(texture.coords, nil, "all five segments")
            equal(texture.tint[3], 1, "blue")
            assert(texture.tint[1] < 0.5, "blue, not white")
        end
        if texture.layer == "ARTWORK" then
            lit = lit + 1
            equal(texture.path:match("Textures\\(%w+)$"), "ChillArc")
            equal(table.concat(texture.coords, ","), "0,0.2,0,1", "the arc's first fifth")
            equal(texture.width, 12.8)
            equal(texture.height, 16)
            equal(texture.tint[1], 1, "white")
            equal(texture.point[1], "LEFT")
            equal(texture.point[4], 0, "over segment 1")
        end
        equal(texture.color, nil, "art, not a color block")
    end
    equal(empties, 1, "one blue arc")
    equal(lit, 1, "segment 1 white while the debuff shows")
    local bar = holder.bar
    equal(bar.kind, "StatusBar")
    equal(bar.parent, button)
    equal(bar.width, 51.2, "segments 2 to 5")
    equal(bar.height, 16)
    equal(bar.barTexture:match("Textures\\(%w+)$"), "ChillArcFill", "segments 2 to 5, cropped as it fills")
    equal(bar.barColor[1], 1, "white")
    -- The engine's stack gate: range 1 to 5; it sets the value to the stacks.
    local gate = button.applicationBar
    assert(gate, "SetApplicationBar was called")
    equal(gate[1], bar)
    equal(gate[2].minApplications, 1)
    equal(gate[2].maxApplications, 5)
    equal(bar.shown, true)
    -- The fill for n stacks ends between segment n and n + 1 (12.8-pixel fifths).
    equal(bar.point[1], "LEFT")
    equal(bar.point[2], button)
    for stacks = 1, 5 do
        local edge = bar.point[4] + (stacks - 1) / 4 * bar.width
        assert(math.abs(edge - 64 / 5 * stacks) < 1e-9, stacks .. " stacks: " .. edge)
    end
    equal(state.auraReads, 0, "no AddOn code reads an aura")
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("chill on=true engine=engine holders=10 plates=1 shown=1 visible=1 anchors=[Blizzard=1]"), true)
    -- A client without SetApplicationBar: segment 1 only, never a wrong count.
    local older = Mage({engine = true, before = function(st)
        local create = st.env.CreateFrame
        st.env.CreateFrame = function(...)
            local frame = create(...)
            if frame.kind == "AuraContainer" then
                local add = frame.AddAuraSlot
                function frame:AddAuraSlot(key, filter, options)
                    local init = options.initializeFrame
                    options.initializeFrame = function(b)
                        b.SetApplicationBar = false
                        init(b)
                    end
                    return add(self, key, filter, options)
                end
            end
            return frame
        end
    end})
    AddPlate(older, "nameplate1")
    local oldHolder = older.ddt.chillArcs.byUnit.nameplate1
    equal(oldHolder.bar.shown, false, "no stack gate: the bar hides")
end)

test("Winter's Chill art: a five-segment arc, clear at every fifth's edge, and its fill", function()
    -- 256 x 64 each, uncompressed BGRA, top-left origin; the balls are gone.
    for _, name in ipairs({"ChillArc", "ChillArcFill"}) do
        local data, w, h = ReadTGA(name)
        equal(#data, 18 + 256 * 64 * 4, name)
        equal(w, 256, name)
        equal(h, 64, name)
        equal(data:byte(18), 0x28, name)
    end
    equal(io.open("Textures/ChillBall.tga", "rb"), nil, "no ball any more")
    equal(io.open("Textures/ChillBalls.tga", "rb"), nil, "no row of balls any more")
    local function Alpha(data, x, y)
        return data:byte(18 + (y * 256 + x) * 4 + 4)
    end
    local function Column(data, x)
        local most = 0
        for y = 0, 63 do
            most = math.max(most, Alpha(data, x, y))
        end
        return most
    end
    -- The arc: clear in every column at each fifth's edge (51.2 pixels), so
    -- the crop there cuts no segment; solid and near white inside each fifth.
    local arc = ReadTGA("ChillArc")
    for edge = 1, 4 do
        local x = edge * 51.2
        for column = math.floor(x) - 1, math.ceil(x) do
            equal(Column(arc, column), 0, "clear at edge " .. edge .. ", column " .. column)
        end
    end
    for segment = 0, 4 do
        local x, solid = math.floor(segment * 51.2 + 25.6), false
        for y = 0, 63 do
            local at = 18 + (y * 256 + x) * 4
            local b, g, r, a = arc:byte(at + 1, at + 4)
            if a == 255 and r > 150 and g > 150 and b > 150 then solid = true end
        end
        equal(solid, true, "segment " .. segment + 1 .. ": solid, near white, for the tint")
    end
    -- The fill: segments 2 to 5 over the whole texture (64 pixels each), clear
    -- at each quarter's edge.
    local fill = ReadTGA("ChillArcFill")
    for edge = 1, 3 do
        for column = edge * 64 - 1, edge * 64 do
            equal(Column(fill, column), 0, "fill clear at edge " .. edge .. ", column " .. column)
        end
    end
    for segment = 0, 3 do
        assert(Column(fill, segment * 64 + 32) == 255, "fill segment " .. segment + 2)
    end
end)

test("Winter's Chill arc on a plain-Lua container: one segment per stack, yours only", function()
    -- unit -> {{spellId, yours, stacks}}
    local auras = {nameplate1 = {{12579, true, 1}}}
    local function Read(unit, index, filter)
        local n = 0
        for _, aura in ipairs(auras[unit] or {}) do
            if aura[2] or not filter:find("PLAYER", 1, true) then
                n = n + 1
                if n == index then
                    return {spellId = aura[1], name = "x", icon = 1, duration = 15, expirationTime = 115,
                        applications = aura[3]}
                end
            end
        end
    end
    local state = Mage({auras = Read})
    AddPlate(state, "nameplate1")
    local holder = state.ddt.chillArcs.byUnit.nameplate1
    equal(holder.container.kind, "Frame", "the plain-Lua container")
    local button = holder.arcs.chill
    -- Toolkit 2.11.0 and later gate the bar here; an older one (the copy,
    -- 2.10.2) does not: then segment 1 only, never a wrong count.
    local gated = type(button.display) == "table" and button.display.applications == holder.bar
    equal(LitCells(holder, button), 1, "one stack")
    for stacks = 2, 5 do
        auras.nameplate1 = {{12579, true, stacks}}
        emit(state, "UNIT_AURA", "nameplate1")
        equal(LitCells(holder, button), gated and stacks or 1, stacks .. " stacks")
    end
    -- A stack count of 0 for one stack still makes segment 1 white.
    auras.nameplate1 = {{12579, true, 0}}
    emit(state, "UNIT_AURA", "nameplate1")
    equal(button.shown, true)
    if gated then
        equal(holder.bar.shown, false, "the bar hides below 1")
    end
    equal(LitCells(holder, button), 1)
    auras.nameplate1 = {{12579, false, 5}}
    emit(state, "UNIT_AURA", "nameplate1")
    equal(LitCells(holder, button), 0, "another Mage's Winter's Chill: none")
    auras.nameplate1 = {{116, true, 1}, {6136, true, 1}}
    emit(state, "UNIT_AURA", "nameplate1")
    equal(LitCells(holder, button), 0, "Frostbolt's chill is not Winter's Chill")
end)

test("Winter's Chill arc: Size, Height, Reset live; the profile carries them; the preview shows 3 of 5", function()
    local state = Mage({engine = true})
    local arcs, db = state.ddt.chillArcs, state.ddt.db
    AddPlate(state, "nameplate1")
    state.settings.DDT_CHILL_SIZE.set(200)
    state.settings.DDT_CHILL_OFFSET.set(40)
    equal(arcs.byUnit.nameplate1.scale, 2)
    equal(arcs.byUnit.nameplate1.point[5], 20, "40 pixels at scale 2")
    state.settings.DDT_CHILL.set(false)
    equal(arcs.byUnit.nameplate1, nil, "off: none")
    local chill = db.wintersChill
    state.buttons["Reset Winter's Chill: Reset"]()
    equal(db.wintersChill, chill, "changed in place")
    equal(db.wintersChill.enabled, true)
    equal(db.wintersChill.size, 100)
    equal(db.wintersChill.offset, 36)
    equal(arcs.byUnit.nameplate1.point[5], 36)
    -- The profile.
    local ns = state.toolkitNS
    ns.db.profiles["Other - Realm"] = {class = "Mage", parts = {DyresDebuffTracker = {wintersChill = {
        enabled = true, size = 50, offset = 0}}}, pending = {}}
    equal(ns.profile:CopyFrom("Other - Realm"), true)
    equal(db.wintersChill.size, 50)
    equal(arcs.byUnit.nameplate1.scale, 0.5)
    equal(state.ddt.ProfileSettings(db).wintersChill.size, 50)
    equal(db.frost.size, 100, "the arcs keep their own settings")
    -- The preview: our own frame on the target's plate, 3 of 5 lit, no engine.
    local press = state.buttons["Preview Winter's Chill: Preview"]
    equal(press(), "no plate")
    contains(state.messages[#state.messages], "Winter's Chill preview: target a mob")
    local plate = AddPlate(state, "nameplate2")
    state.plates.target = plate
    state.combat = true
    equal(press(), "started")
    local on, frame = arcs:Previewing()
    equal(on, true)
    equal(frame.parent, plate)
    equal(frame.bar.value, 3, "3 of 5 lit")
    equal(frame.bar.shown, true)
    equal(frame.arcs.chill.applicationBar, nil, "not an engine button")
    state.settings.DDT_CHILL_SIZE.set(150)
    equal(frame.scale, 1.5, "live")
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(arcs:Previewing(), false, "a new target ends it")
    -- The slash command: /ddt preview chill, and /ddt preview for a Mage.
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("preview chill")
    equal(arcs:Previewing(), true)
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("preview")
    equal(arcs:Previewing(), false)
    equal(state.auraReads, 0)
    -- Not a Mage: a message only.
    local warlock = fixture()
    warlock.env.SlashCmdList.DYRESDEBUFFTRACKER("preview chill")
    contains(warlock.messages[#warlock.messages], "Mages only")
    warlock.env.SlashCmdList.DYRESDEBUFFTRACKER("help")
    contains(warlock.messages[#warlock.messages], "/ddt preview chill")
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

-- The Mage's Winter's Chill stack chime (John, 2026-11-22, via the lead: "2,
-- remove it, build it right in DDT"; Dyre's Buff Reminders 1.13.3 removes its own).
local CLEU = "COMBAT_LOG_EVENT_UNFILTERED"

-- Dyre's Sounds: every key it plays, in order; without lacks (a key pattern).
local function Sounds(state, lacks)
    state.played = {}
    local library = {}
    function library.RequireContract(contract) if contract <= 1 then return library end end
    function library.Play(key)
        if lacks and key:find(lacks) then return false end
        state.played[#state.played + 1] = key
        return true
    end
    -- A file for every key it has (AddAuraSound's sound fields).
    function library.AuraSound(key)
        if lacks and key:find(lacks) then return nil end
        return {soundFileName = key .. ".wav"}
    end
    state.env.DyresSounds = library
    -- Your target is the mob the log lines hit (state.target; nil: no target).
    state.target = "Creature-0-1"
    local guid = state.env.UnitGUID
    state.env.UnitGUID = function(unit)
        if unit == "target" then return state.target end
        return guid(unit)
    end
end

-- One combat log line, as the client gives it, then the event (on
-- state.dest, else the mob "Creature-0-1").
local function Log(state, subevent, source, spellID, spellName, amount)
    local dest = state.dest or "Creature-0-1"
    state.env.C_CombatLog.GetCurrentEventInfo = function()
        return 1, subevent, false, source, "Someone", 0, 0, dest, "Mob", 0, 0, spellID, spellName, 16,
            "DEBUFF", amount
    end
    emit(state, CLEU, CLEU)
end

local function ChimeOn(state)
    return state.ddt.chillChime.events.events[CLEU] == true
end

test("Winter's Chill chime on Classic Era: one note per stack of your own, rising, the held note at 5", function()
    local state = Mage({before = function(st) Sounds(st) end})
    equal(state.ddt.db.wintersChill.chime, true, "on by default, as Dyre's Buff Reminders' was")
    equal(state.ddt.db.wintersChill.noteSet, "bassoon")
    equal(ChimeOn(state), true, "the combat log is registered")
    equal(state.settings.DDT_CHILL_CHIME.name, "Stack chime")
    equal(state.settings.DDT_CHILL_CHIME.default, true)
    equal(state.settings.DDT_CHILL_NOTESET.default, "bassoon")
    assert(state.buttons["Test the stack chime: Test"], "Test chime")
    equal(#state.messages, 0, "nothing said at login")
    Log(state, "SPELL_AURA_APPLIED", "Player-1", 12579, "Winter's Chill")
    for stack = 2, 5 do
        Log(state, "SPELL_AURA_APPLIED_DOSE", "Player-1", 12579, "Winter's Chill", stack)
    end
    equal(table.concat(state.played, ","), "bassoon1,bassoon2,bassoon3,bassoon4,bassoon8")
    -- Nothing for a refresh, a drop, the end, another Mage, or another chill.
    state.played = {}
    Log(state, "SPELL_AURA_REFRESH", "Player-1", 12579, "Winter's Chill")
    Log(state, "SPELL_AURA_REMOVED_DOSE", "Player-1", 12579, "Winter's Chill", 4)
    Log(state, "SPELL_AURA_REMOVED", "Player-1", 12579, "Winter's Chill")
    Log(state, "SPELL_AURA_APPLIED", "Player-2", 12579, "Winter's Chill")
    Log(state, "SPELL_AURA_APPLIED", "Player-1", 116, "Frostbolt")
    Log(state, "SPELL_AURA_APPLIED_DOSE", "Player-1", 12579, "Winter's Chill", "x")
    equal(#state.played, 0, "no note")
    -- Only your target (John, 2026-11-23): another mob, or no target, plays nothing.
    state.dest = "Creature-0-2"
    Log(state, "SPELL_AURA_APPLIED", "Player-1", 12579, "Winter's Chill")
    Log(state, "SPELL_AURA_APPLIED_DOSE", "Player-1", 12579, "Winter's Chill", 5)
    equal(#state.played, 0, "not your target: no note")
    state.dest, state.target = nil, nil
    Log(state, "SPELL_AURA_APPLIED", "Player-1", 12579, "Winter's Chill")
    equal(#state.played, 0, "no target: no note")
    state.target = "Creature-0-2"
    Log(state, "SPELL_AURA_APPLIED_DOSE", "Player-1", 12579, "Winter's Chill", 2)
    equal(#state.played, 0, "the old target's chill after a target change: no note")
    state.target = "Creature-0-1"
    -- Classic's log may give the ID as 0: the name counts.
    Log(state, "SPELL_AURA_APPLIED_DOSE", "Player-1", 0, "Winter's Chill", 3)
    equal(state.played[1], "bassoon3", "by name")
    -- A count over 5 is the held note.
    Log(state, "SPELL_AURA_APPLIED_DOSE", "Player-1", 12579, "Winter's Chill", 7)
    equal(state.played[2], "bassoon8")
    -- Sax.
    state.played = {}
    state.settings.DDT_CHILL_NOTESET.set("sax")
    equal(state.played[1], "sax8", "a new set plays its held note")
    Log(state, "SPELL_AURA_APPLIED", "Player-1", 12579, "Winter's Chill")
    equal(state.played[2], "sax1")
    -- Off: the log goes, and nothing plays.
    state.settings.DDT_CHILL_CHIME.set(false)
    equal(ChimeOn(state), false, "off: no combat log")
    state.played = {}
    Log(state, "SPELL_AURA_APPLIED", "Player-1", 12579, "Winter's Chill")
    equal(#state.played, 0)
    state.settings.DDT_CHILL_CHIME.set(true)
    equal(ChimeOn(state), true)
    -- Test chime: stack 1 at once, then 2 to 5 by C_Timer (no OnUpdate).
    state.played, state.timers = {}, {}
    state.settings.DDT_CHILL_NOTESET.set("bassoon")
    state.played = {}
    state.buttons["Test the stack chime: Test"]()
    equal(state.played[1], "bassoon1")
    equal(#state.timers, 4)
    for _, fn in ipairs(state.timers) do fn() end
    equal(table.concat(state.played, ","), "bassoon1,bassoon2,bassoon3,bassoon4,bassoon8")
    -- Reset puts the chime back on, Bassoon.
    state.settings.DDT_CHILL_CHIME.set(false)
    state.settings.DDT_CHILL_NOTESET.set("sax")
    state.buttons["Reset Winter's Chill: Reset"]()
    equal(state.ddt.db.wintersChill.chime, true)
    equal(state.ddt.db.wintersChill.noteSet, "bassoon")
    equal(ChimeOn(state), true, "Reset registers it again")
    -- /ddt debug.
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("chime on=true registered=true waitsFor=none noteSet=bassoon sounds=yes"), true)
    equal(state.auraReads, 0, "the chime reads no aura")
end)

test("Winter's Chill chime: an older Dyre's Sounds plays sax; none plays nothing; repaired; not for others", function()
    local state = Mage({before = function(st) Sounds(st, "^bassoon") end})
    Log(state, "SPELL_AURA_APPLIED", "Player-1", 12579, "Winter's Chill")
    equal(state.played[1], "sax1", "no bassoon: the sax note of the same number")
    local silent = Mage()
    Log(silent, "SPELL_AURA_APPLIED", "Player-1", 12579, "Winter's Chill")
    equal(silent.buttons["Test the stack chime: Test"](), false)
    contains(silent.messages[#silent.messages], "install Dyre's Sounds")
    local bad = Mage({saved = {wintersChill = {chime = "yes", noteSet = "tuba"}}}).ddt.db.wintersChill
    equal(bad.chime, true)
    equal(bad.noteSet, "bassoon")
    local off = Mage({saved = {wintersChill = {chime = false, noteSet = "sax"}}})
    equal(off.ddt.db.wintersChill.noteSet, "sax")
    equal(ChimeOn(off), false, "saved off: no combat log")
    -- Other classes: no log, no rows.
    local warlock = fixture()
    equal(ChimeOn(warlock), false)
    equal(warlock.settings.DDT_CHILL_CHIME, nil)
    warlock.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(warlock.said("chime none (Mage only)"), true)
end)

test("Winter's Chill chime: no combat log and no aura sounds, so no chime and no rows", function()
    local state = Mage({restricted = true, before = function(st) Sounds(st) end})
    equal(ChimeOn(state), false, "Forever refuses the combat log")
    equal(state.settings.DDT_CHILL_CHIME, nil, "no chime rows")
    assert(state.settings.DDT_CHILL, "the balls' rows stay")
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("chime off: this client has no combat log and no aura sounds"), true)
end)

-- The game's aura sound API, as Forever has it (UnitAuraDocumentation:
-- AddAuraSound returns an ID; RemoveAuraSound takes it). state.encounter is
-- the Encounter restriction.
local function AuraApi(state)
    state.auraSounds, state.nextSound = {}, 0
    state.env.C_UnitAuras.AddAuraSound = function(trigger, info)
        assert(not state.combat, "AddAuraSound in combat")
        assert(not state.encounter, "AddAuraSound in an encounter")
        state.nextSound = state.nextSound + 1
        state.auraSounds[state.nextSound] = {trigger = trigger, info = info}
        return state.nextSound
    end
    state.env.C_UnitAuras.RemoveAuraSound = function(id)
        assert(not state.encounter, "RemoveAuraSound in an encounter")
        state.auraSounds[id] = nil
    end
    state.env.Enum.UnitAuraSoundTrigger = {Added = 0, ApplicationsIncreased = 1, Removed = 2}
    state.env.Enum.AddOnRestrictionType = {Encounter = 2}
    state.env.C_RestrictedActions = {IsAddOnRestrictionActive = function(kind)
        return kind == 2 and state.encounter == true
    end}
end

-- The registered sounds, "trigger:file", sorted; each checked for the rest.
local function AuraRegistered(state)
    local list = {}
    for _, entry in pairs(state.auraSounds) do
        local info = entry.info
        equal(info.unitToken, "target")
        equal(info.spellID, 12579)
        equal(info.outputChannel, "master")
        equal(info.throttleSeconds, 0.5)
        list[#list + 1] = entry.trigger .. ":" .. tostring(info.soundFileName)
    end
    table.sort(list)
    return table.concat(list, ",")
end

test("Winter's Chill chime on WoW: Forever: the game's aura sounds on your target, one fixed note", function()
    local state = Mage({restricted = true, before = function(st) Sounds(st); AuraApi(st) end})
    equal(ChimeOn(state), false, "no combat log")
    equal(state.ddt.ChillChimeMode(), "aura")
    -- Added: note 1; ApplicationsIncreased: the 3rd note.
    equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav")
    assert(state.settings.DDT_CHILL_NOTESET, "Note set row")
    assert(state.buttons["Test the stack chime: Test"], "Test chime")
    equal(#state.messages, 0, "nothing said at login")
    -- Off: removed at once; on again: registered again.
    state.settings.DDT_CHILL_CHIME.set(false)
    equal(AuraRegistered(state), "", "off: no aura sounds")
    state.settings.DDT_CHILL_CHIME.set(true)
    equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav")
    -- A note set change registers the set's notes, out of combat.
    state.played = {}
    state.settings.DDT_CHILL_NOTESET.set("sax")
    equal(AuraRegistered(state), "0:sax1.wav,1:sax3.wav")
    equal(state.played[1], "sax3", "a new set plays the note you hear most")
    -- In combat it waits for the end of combat.
    state.combat = true
    state.settings.DDT_CHILL_NOTESET.set("bassoon")
    equal(AuraRegistered(state), "0:sax1.wav,1:sax3.wav", "in combat: no change yet")
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav", "after combat")
    -- Off in combat: removed at once.
    state.combat = true
    state.settings.DDT_CHILL_CHIME.set(false)
    equal(AuraRegistered(state), "", "off in combat: removed at once")
    state.settings.DDT_CHILL_CHIME.set(true)
    equal(AuraRegistered(state), "", "on in combat: waits")
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav")
    -- An encounter: nothing changes until its end.
    state.encounter = true
    state.settings.DDT_CHILL_CHIME.set(false)
    equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav", "an encounter: waits")
    state.encounter = false
    emit(state, "ADDON_RESTRICTION_STATE_CHANGED")
    equal(AuraRegistered(state), "", "at the encounter's end")
    state.settings.DDT_CHILL_CHIME.set(true)
    -- Test chime plays what this client plays: note 1, then the 3rd note.
    state.played, state.timers = {}, {}
    state.buttons["Test the stack chime: Test"]()
    for _, fn in ipairs(state.timers) do fn() end
    equal(table.concat(state.played, ","), "bassoon1,bassoon3,bassoon3,bassoon3,bassoon3")
    -- Reset: on, Bassoon, registered.
    state.settings.DDT_CHILL_NOTESET.set("sax")
    state.buttons["Reset Winter's Chill: Reset"]()
    equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav")
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("chime aura on=true registered=true sounds=2 deferred=false noteSet=bassoon library=yes"), true)
    equal(state.auraReads, 0, "the chime reads no aura")
end)

test("Winter's Chill chime on WoW: Forever: older Dyre's Sounds, none, an old Dyre's Buff Reminders", function()
    local old = Mage({restricted = true, before = function(st) Sounds(st, "^bassoon"); AuraApi(st) end})
    equal(AuraRegistered(old), "0:sax1.wav,1:sax3.wav", "no bassoon: the sax notes")
    local none = Mage({restricted = true, before = function(st) AuraApi(st) end})
    equal(AuraRegistered(none), "", "no Dyre's Sounds: nothing registered")
    -- Dyre's Buff Reminders never chimed without the log: no wait, no line.
    local dbr = Mage({restricted = true, loaded = {DyresBuffReminders = "1.13.2"}, before = function(st)
        Sounds(st)
        AuraApi(st)
    end})
    equal(AuraRegistered(dbr), "0:bassoon1.wav,1:bassoon3.wav")
    equal(#dbr.messages, 0)
    -- Saved off: nothing registered at login.
    local off = Mage({restricted = true, saved = {wintersChill = {chime = false}}, before = function(st)
        Sounds(st)
        AuraApi(st)
    end})
    equal(AuraRegistered(off), "")
    -- Not a Mage: nothing.
    local warlock = fixture({restricted = true, before = function(st) Sounds(st); AuraApi(st) end})
    equal(AuraRegistered(warlock), "")
end)

-- John, 2026-11-28, on WoW: Forever: switching to a profile gave
-- "tried to call the protected function 'Frame:UnregisterEvent()'" from
-- RefreshChillChime, through the profile refresh, on a Warlock.
test("the combat log is never registered or unregistered without the log path (profile refresh, settings, talents)", function()
    local state = fixture({restricted = true})
    local ddt = state.ddt
    equal(ddt.ChillChimeMode(), nil, "a Warlock has no chime path")
    local ns = state.toolkitNS
    ns.db.profiles["Paladin - Realm"] = {class = "Paladin", parts = {DyresDebuffTracker = {dots = {hideEmpty = true}}},
        pending = {}}
    equal(ns.profile:CopyFrom("Paladin - Realm"), true)
    equal(ddt.db.dots.hideEmpty, true, "the profile applied")
    ddt.RefreshChill()
    ddt.RefreshChillChime()
    equal(table.concat(state.forbidden, ","), "", "a Warlock on Forever: no combat log call")
    -- A Mage on Forever with no aura sounds, and with them: the same.
    for _, before in ipairs({function(st) Sounds(st) end, function(st) Sounds(st); AuraApi(st) end}) do
        local mage = Mage({restricted = true, before = before})
        mage.ddt.db.wintersChill.chime = false
        mage.ddt.RefreshChillChime()
        mage.ddt.db.wintersChill.chime = true
        mage.ddt.RefreshChillChime()
        mage.ddt.RefreshChill()
        equal(table.concat(mage.forbidden, ","), "", "a Mage on Forever: no combat log call")
    end
    -- Classic Era: the chime off takes back only what it registered, once.
    local era = Mage({before = function(st) Sounds(st) end})
    local calls = {}
    local events = era.ddt.chillChime.events
    local unregister = events.UnregisterEvent
    events.UnregisterEvent = function(self, event)
        calls[#calls + 1] = event
        return unregister(self, event)
    end
    equal(ChimeOn(era), true)
    era.ddt.db.wintersChill.chime = false
    era.ddt.RefreshChillChime()
    era.ddt.RefreshChillChime()
    equal(ChimeOn(era), false)
    equal(table.concat(calls, ","), CLEU .. ",SPELLS_CHANGED", "unregistered once")
end)

test("Winter's Chill chime: waits while Dyre's Buff Reminders older than 1.13.3 still plays its own", function()
    for _, version in ipairs({"1.13.2", "1.9.0", "x"}) do
        local state = Mage({loaded = {DyresBuffReminders = version}, before = function(st)
            Sounds(st)
            st.env.DyresBuffRemindersDB = {wintersChill = {enabled = false, noteSet = "sax"}}
        end})
        equal(ChimeOn(state), false, version .. ": no second chime")
        equal(state.ddt.db.chimeImported, false, version .. ": the import waits")
        equal(state.ddt.db.wintersChill.chime, true, version .. ": nothing copied yet")
        equal(#state.messages, 1, version .. ": one line")
        contains(state.messages[1], "The Winter's Chill chime waits: Dyre's Buff Reminders")
        contains(state.messages[1], "Update it to 1.13.3 or later")
        state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
        equal(state.said("waitsFor=" .. (version == "x" and "x" or version)), true, version)
    end
    -- 1.13.3 and later: the chime plays.
    local state = Mage({loaded = {DyresBuffReminders = "1.13.3"}, before = function(st) Sounds(st) end})
    equal(ChimeOn(state), true)
end)

test("Winter's Chill chime: Dyre's Buff Reminders' settings come over once, from 1.13.3, for a Mage", function()
    local function Login(dbr, version, saved, extra)
        local options = {loaded = {DyresBuffReminders = version}, saved = saved, before = function(st)
            Sounds(st)
            st.env.DyresBuffRemindersDB = dbr
        end}
        for key, value in pairs(extra or {}) do options[key] = value end
        return Mage(options)
    end
    -- Off and Sax come over; one line says so.
    local state = Login({wintersChill = {enabled = false, noteSet = "sax"}}, "1.13.3")
    equal(state.ddt.db.chimeImported, true)
    equal(state.ddt.db.wintersChill.chime, false, "your off stays off")
    equal(state.ddt.db.wintersChill.noteSet, "sax")
    equal(ChimeOn(state), false)
    equal(#state.messages, 1)
    equal(state.messages[1], "DDT: " .. state.ddt.CHIME_IMPORTED)
    -- DBR's rules: only false is off; an unknown set is not copied.
    local loose = Login({wintersChill = {enabled = "maybe", noteSet = "full"}}, "1.14.0")
    equal(loose.ddt.db.wintersChill.chime, true)
    equal(loose.ddt.db.wintersChill.noteSet, "bassoon")
    -- Once: a saved flag means DBR's values are not read again.
    local again = Login({wintersChill = {enabled = false, noteSet = "sax"}}, "1.13.3",
        {chimeImported = true, wintersChill = {chime = true, noteSet = "bassoon"}})
    equal(again.ddt.db.wintersChill.chime, true, "not copied twice")
    equal(#again.messages, 0)
    -- No table (DBR never had the chime): done, quietly.
    local none = Login({}, "1.13.3")
    equal(none.ddt.db.chimeImported, true)
    equal(#none.messages, 0)
    -- DBR not loaded: done, nothing to read.
    local absent = Mage({before = function(st)
        st.env.DyresBuffRemindersDB = {wintersChill = {enabled = false}}
    end})
    equal(absent.ddt.db.chimeImported, true)
    equal(absent.ddt.db.wintersChill.chime, true, "not loaded: not read")
    -- Another class: done, never read.
    local warlock = fixture({loaded = {DyresBuffReminders = "1.13.3"}, before = function(st)
        st.env.DyresBuffRemindersDB = {wintersChill = {enabled = false}}
    end})
    equal(warlock.ddt.db.chimeImported, true)
    equal(#warlock.messages, 0)
    -- The profile carries the chime; a profile copy counts as the import.
    local profiled = Login({wintersChill = {enabled = false}}, "1.13.2")
    equal(profiled.ddt.db.chimeImported, false, "waiting")
    local ns = profiled.toolkitNS
    ns.db.profiles["Other - Realm"] = {class = "Mage", parts = {DyresDebuffTracker = {wintersChill = {
        chime = false, noteSet = "sax"}}}, pending = {}}
    equal(ns.profile:CopyFrom("Other - Realm"), true)
    equal(profiled.ddt.db.wintersChill.chime, false)
    equal(profiled.ddt.db.wintersChill.noteSet, "sax")
    equal(profiled.ddt.db.chimeImported, true, "a copied profile wins over a later import")
    equal(profiled.ddt.ProfileSettings(profiled.ddt.db).wintersChill.noteSet, "sax")
    equal(profiled.ddt.ProfileSettings({chimeImported = true}).chimeImported, true)
end)

-- The Winter's Chill talent gate (John, 2026-11-23, via the lead: "make sure
-- this only shows if the player has the talent for it").
-- Forever without the combat log: Dyre's Sounds, the aura sound API, and a health bar.
local function Plain(st)
    Sounds(st)
    AuraApi(st)
    st.env.UnitHealth = function() return 100 end
    st.env.UnitHealthMax = function() return 100 end
end

local function ChillPlate(state)
    AddPlate(state, "nameplate1")
    return state.ddt.chillArcs.byUnit.nameplate1
end

test("Winter's Chill talent: known by any rank; not known: no arc, no chime, rows greyed; preview works", function()
    for _, rank in ipairs({11180, 28592, 28593, 28594, 28595}) do
        local state = Mage({engine = true, restricted = true, talents = {[rank] = true}, before = Plain})
        assert(ChillPlate(state), "rank " .. rank .. ": the arc")
        equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav", "rank " .. rank .. ": the chime")
    end
    local state = Mage({engine = true, restricted = true, talents = {}, before = Plain})
    equal(ChillPlate(state), nil, "no talent: no arc")
    equal(AuraRegistered(state), "", "no talent: no aura sounds (another Mage's chill cannot chime you)")
    assert(state.ddt.frostArcs.byUnit.nameplate1, "the frozen and chilled arcs do not need it")
    for _, variable in ipairs({"DDT_CHILL", "DDT_CHILL_SIZE", "DDT_CHILL_OFFSET", "DDT_CHILL_CHIME", "DDT_CHILL_NOTESET"}) do
        local row = state.settings[variable]
        assert(row, variable .. " stays visible")
        equal(row.initializer.modify(), false, variable .. " greyed")
        local tip = type(row.tooltip) == "function" and row.tooltip() or row.tooltip or ""
        contains(tip, "Greyed out: you have not learned Winter's Chill yet.")
    end
    equal(state.ddt.db.wintersChill.enabled, true, "the saved settings stay")
    state.env.SlashCmdList.DYRESDEBUFFTRACKER("debug")
    equal(state.said("chill talent not known"), true)
    -- The preview still shows, so the arc can be placed before the talent.
    state.plates.target = state.plates.nameplate1
    equal(state.buttons["Preview Winter's Chill: Preview"](), "started")
    -- Classic Era: no combat log chime either.
    local era = Mage({talents = {}, before = function(st) Sounds(st) end})
    equal(ChimeOn(era), false, "no talent: no combat log chime")
end)

test("Winter's Chill talent: learned and removed out of combat apply at once; in combat after combat", function()
    local talents = {}
    local state = Mage({engine = true, restricted = true, talents = talents, before = Plain})
    equal(ChillPlate(state), nil)
    talents[28595] = true
    emit(state, "SPELLS_CHANGED")
    assert(state.ddt.chillArcs.byUnit.nameplate1, "learned: the arc at once")
    equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav", "learned: the chime")
    equal(state.settings.DDT_CHILL.initializer.modify(), true, "rows active")
    talents[28595] = nil
    emit(state, "CHARACTER_POINTS_CHANGED")
    equal(state.ddt.chillArcs.byUnit.nameplate1, nil, "removed: no arc")
    equal(AuraRegistered(state), "")
    -- In combat: the last answer stays until combat ends.
    talents[11180] = true
    state.combat = true
    emit(state, "SPELLS_CHANGED")
    equal(state.ddt.chillArcs.byUnit.nameplate1, nil, "in combat: no change yet")
    equal(state.ddt.ChillTalentText(), "not known")
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    equal(state.ddt.ChillTalentText(), "known")
    assert(state.ddt.chillArcs.byUnit.nameplate1, "after combat: the arc")
    equal(AuraRegistered(state), "0:bassoon1.wav,1:bassoon3.wav", "after combat: the chime")
end)

test("Winter's Chill talent: a Forever ID found by name; no API at all shows it, as before", function()
    local state = Mage({engine = true, talents = {[1311180] = true}, spells = {[11180] = "Winter's Chill"},
        before = function(st)
            st.env.C_Spell.GetSpellInfo = function(name)
                if name == "Winter's Chill" then return {spellID = 1311180} end
            end
        end})
    assert(ChillPlate(state), "the talent by its name")
    -- The debuff shares the name: never the talent.
    local debuff = Mage({engine = true, talents = {[12579] = true}, spells = {[11180] = "Winter's Chill"},
        before = function(st)
            st.env.C_Spell.GetSpellInfo = function() return {spellID = 12579} end
        end})
    equal(ChillPlate(debuff), nil, "the debuff's ID is not the talent")
    -- No IsPlayerSpell, C_SpellBook.IsSpellKnown, or IsSpellKnown: unreadable, shown.
    local blind = Mage({engine = true, talents = {}, before = function(st)
        st.env.C_SpellBook.IsSpellKnown = nil
        st.env.IsPlayerSpell, st.env.IsSpellKnown = nil, nil
    end})
    assert(ChillPlate(blind), "a check that cannot read never hides it")
    equal(blind.ddt.ChillTalentText(), "unreadable")
    equal(blind.settings.DDT_CHILL.initializer.modify(), true)
end)

-- Key Bindings (John, 2026-11-26: ours "should not be there" in the AddOns
-- section): a Binding's category makes the section (classic_era
-- Blizzard_SettingsDefinitions_Frame/Keybindings.lua 189-229), so every one
-- is in "Dyre's AddOns", as Dyre's Toolkit's. The name stays: keys are saved by it.
-- Settings sections (Dyre's Toolkit 2.17.0, SETTINGS_SECTIONS_VERSION 2). In
-- CI the vendored Toolkit copy is older, so the documented contract is
-- stubbed there: prefixed variables on a host page, unchanged on the owner's
-- own page, and AddWidgetSettings' opts.variable (version 2).
local function SectionToolkit(state)
    local toolkit = state.toolkit
    if type(toolkit.AddSettingsPrimer) ~= "function" then
        function toolkit.AddSettingsPrimer(_, layout, text)
            local element = state.env.Settings.CreateElementInitializer("DyresToolkitSettingsPrimerTemplate",
                {text = text})
            layout:AddInitializer(element)
            return element
        end
    end
    if type(toolkit.WatchSettings) ~= "function" then
        function toolkit.WatchSettings(initializer, variables)
            for _, variable in ipairs(variables) do initializer:AddEvaluateStateCVar(variable) end
            return initializer
        end
    end
    if (toolkit.SETTINGS_SECTIONS_VERSION or 0) >= 3 and type(toolkit.SettingsSectionTitle) == "function" then
        return
    end
    local sections = {}
    toolkit.SETTINGS_SECTIONS_VERSION = 3
    local add = toolkit.AddWidgetSettings
    function toolkit.AddWidgetSettings(category, layout, widget, opts)
        if not (opts and (opts.variable or opts.modify or opts.watch)) then
            return add(category, layout, widget, opts)
        end
        local settings, made = state.env.Settings, {}
        local register = settings.RegisterProxySetting
        settings.RegisterProxySetting = function(c, variable, ...)
            local setting = register(c, opts.variable and opts.variable(variable) or variable, ...)
            made[#made + 1] = setting
            return setting
        end
        local ok, result = pcall(add, category, layout, widget, opts)
        settings.RegisterProxySetting = register
        assert(ok, result)
        for _, setting in ipairs(made) do
            if opts.modify and setting.initializer then setting.initializer:AddModifyPredicate(opts.modify) end
            if opts.watch and setting.initializer then toolkit.WatchSettings(setting.initializer, opts.watch) end
        end
        return result
    end
    function toolkit.RegisterSettingsSection(spec)
        sections[spec.addon] = sections[spec.addon] or {}
        sections[spec.addon][spec.key] = spec
        return true
    end
    function toolkit.SettingsSectionTitle(addon, key)
        return sections[addon] and sections[addon][key] and sections[addon][key].title or nil
    end
    function toolkit.SettingsSections(addon)
        local keys = {}
        for key in pairs(sections[addon] or {}) do keys[#keys + 1] = key end
        table.sort(keys)
        return keys
    end
    local function Context(owner, key, host, filter, part)
        local prefix = host and ("DYRE_" .. host:upper() .. "__") or ""
        return {host = host or owner, owner = owner, key = key, class = select(2, state.env.UnitClass("player")),
            filter = filter, own = host == nil, part = part or "all",
            variable = function(name) return prefix .. name end}
    end
    function toolkit.OwnSettingsContext(addon, key, filter, part) return Context(addon, key, nil, filter, part) end
    function toolkit.AddSettingsSection(category, layout, opts)
        local section = sections[opts.addon] and sections[opts.addon][opts.key]
        if section and section.build(category, layout,
                Context(opts.addon, opts.key, opts.host, opts.filter, opts.part)) then
            return "rows"
        end
        return opts.part ~= "master" and "link" or nil
    end
end

local function Host(state, key, host, name, part)
    local category, layout = state.env.Settings.RegisterVerticalLayoutSubcategory({name = host}, name or key)
    return state.toolkit.AddSettingsSection(category, layout, {addon = "DyresDebuffTracker", key = key,
        host = host, part = part, link = {name = key}}), category
end

local function Prefixed(state, prefix)
    local list = {}
    for variable in pairs(state.settings) do
        if variable:sub(1, #prefix) == prefix then list[#list + 1] = variable end
    end
    table.sort(list)
    return list
end

test("settings sections: tracker, dots, and control registered at ADDON_LOADED; none without the Toolkit's", function()
    local state = fixture({before = SectionToolkit})
    equal(table.concat(state.toolkit.SettingsSections("DyresDebuffTracker"), ","), "control,cues,dots,tracker")
    equal(state.ddt.sectionsRegistered, true)
    -- A Toolkit with no sections: nothing registered, the own pages as before.
    local old = fixture({before = function(s) s.toolkit.SETTINGS_SECTIONS_VERSION = nil end})
    equal(old.ddt.sectionsRegistered, nil)
    assert(old.settings.DDT_DOTS and old.settings.DDT_CONTROL, "the own pages")
end)

test("settings sections: a host page's variables are prefixed, ours unchanged, none registered twice", function()
    local state = fixture({before = SectionToolkit})
    local own = {}
    for variable in pairs(state.settings) do own[#own + 1] = variable end
    local prefix = "DYRE_WARLOCKTOOLSFOREVER__"
    for _, key in ipairs({"tracker", "dots", "control"}) do
        equal(Host(state, key, "WarlockToolsForever"), "rows", key)
    end
    -- The cues: rows only where the class has a cue in this client.
    Host(state, "cues", "WarlockToolsForever")
    equal(#state.duplicates, 0, "no variable twice: " .. table.concat(state.duplicates, ","))
    local hosted = Prefixed(state, prefix)
    -- Every own row has its twin on the host pages, and nothing else is new.
    equal(#hosted, #own, "one host row per own row")
    for _, variable in ipairs(own) do
        assert(state.settings[prefix .. variable], "host twin of " .. variable)
        local page = state.settings[variable].category
        equal(page == "DoT Tracker" or page == "DoTs" or page == "Crowd Control" or page == "Debuff Cues", true,
            variable .. " stays on our page")
    end
    for _, variable in ipairs({"DDT_DOTS", "DDT_DOTS_THEME", "DDT_PREDICT", "DDT_DOTS_CURSE_MODE"}) do
        equal(state.settings[prefix .. variable].category, "tracker", variable)
    end
    for _, variable in ipairs({"DDT_DOTS_PLATES", "DDT_DOTS_ORDER_1", "DDT_DOTS_COLOR_CORRUPTION"}) do
        if state.settings[variable] then
            equal(state.settings[prefix .. variable].category, "dots", variable)
        end
    end
    for _, variable in ipairs({"DDT_CONTROL", "DDT_CONTROL_MACROS", "DDT_ANNOUNCE_FEAR",
            "DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE"}) do
        equal(state.settings[prefix .. variable].category, "control", variable)
    end
    -- A second host (another prefix) is fine too.
    equal(Host(state, "control", "MageToolsForever"), "rows")
    equal(#state.duplicates, 0)
end)

test("settings sections: host rows read and write our live settings, the same as our own page", function()
    local state = fixture({before = SectionToolkit})
    for _, key in ipairs({"tracker", "dots", "control"}) do Host(state, key, "WarlockToolsForever") end
    local s, db, prefix = state.settings, state.ddt.db, "DYRE_WARLOCKTOOLSFOREVER__"
    s[prefix .. "DDT_DOTS_THEME"].set("compact")
    equal(db.dots.theme, "compact")
    equal(s.DDT_DOTS_THEME.get(), "compact", "our own page sees it")
    s.DDT_PREDICT.set(false)
    equal(s[prefix .. "DDT_PREDICT"].get(), false, "the host page sees ours")
    s[prefix .. "DDT_DOTS_PLATES"].set(true)
    equal(db.dots.plateDots, true)
    s[prefix .. "DDT_ANNOUNCE_FEAR"].set(true)
    equal(db.control.announce.fear, true)
    s[prefix .. "DDT_CONTROL_MARKER_BANISH"].set(3)
    equal(db.control.markers.banish, 3)
    s[prefix .. "DDT_CONTROL"].set(false)
    equal(db.control.enabled, false)
    equal(state.toolkit.KindOwner("control:WARLOCK"), nil, "off steps aside, as from our page")
    -- The bar's size: the widget's own setting, one saved table.
    local scale = s[prefix .. "DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE"]
    scale.set(120)
    equal(state.ddt.controlWidget:GetSetting("scale"), 120)
    equal(s.DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE.get(), 120, "our own slider sees it")
    equal(scale.labelFormatter(120), "120%")
    -- The slot order swaps on the live table.
    local first, second = db.dots.order[1], db.dots.order[2]
    s[prefix .. "DDT_DOTS_ORDER_1"].set(second)
    equal(db.dots.order[1], second)
    equal(db.dots.order[2], first)
    -- Rows nest under the tracker's Enable on our page; on a host's own
    -- dots page they are greyed while the tracker is off.
    local plates = s[prefix .. "DDT_DOTS_PLATES"].initializer
    db.dots.enabled = true
    equal(plates.modify(), true)
    db.dots.enabled = false
    equal(plates.modify(), false, "greyed while the tracker is off")
end)

test("settings sections: version 1 keeps the bar's size rows on our page only; version 2 maps them", function()
    local state = fixture({before = function(s)
        SectionToolkit(s)
        s.toolkit.SETTINGS_SECTIONS_VERSION = 1
    end})
    equal(state.ddt.sectionsRegistered, true, "version 1 registers")
    equal(Host(state, "control", "WarlockToolsForever"), "rows")
    equal(#state.duplicates, 0)
    assert(state.settings.DYRE_WARLOCKTOOLSFOREVER__DDT_CONTROL, "the other rows")
    equal(#Prefixed(state, "DYRE_WARLOCKTOOLSFOREVER__DYRE_"), 0, "no size rows on the host page")
    assert(state.settings.DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE, "our own page keeps them")
    local two = fixture({before = SectionToolkit})
    Host(two, "control", "WarlockToolsForever")
    equal(#two.duplicates, 0)
    equal(#Prefixed(two, "DYRE_WARLOCKTOOLSFOREVER__DYRE_DYRESDEBUFFTRACKER_CONTROL_"),
        #Prefixed(two, "DYRE_DYRESDEBUFFTRACKER_CONTROL_"), "every size row, prefixed")
end)

test("settings sections: by class; nothing for a class without the kind; the host shows its link", function()
    local mage = fixture({before = SectionToolkit, class = "MAGE", className = "Mage",
        book = {{118, "Polymorph"}, {133, "Fireball"}}})
    equal(Host(mage, "control", "MageToolsForever"), "rows")
    assert(mage.settings.DYRE_MAGETOOLSFOREVER__DDT_ANNOUNCE_POLYMORPH, "Polymorph's announcement")
    equal(mage.settings.DYRE_MAGETOOLSFOREVER__DDT_ANNOUNCE_FEAR, nil, "no Warlock spells")
    equal(Host(mage, "tracker", "MageToolsForever"), "rows", "a Mage has DoTs")
    equal(#mage.duplicates, 0)
    local paladin = fixture({before = SectionToolkit, class = "PALADIN", className = "Paladin", book = {}})
    equal(Host(paladin, "tracker", "SomeHost"), "link", "a Paladin has no DoTs")
    equal(Host(paladin, "dots", "SomeHost"), "link")
    local shaman = fixture({before = SectionToolkit, class = "SHAMAN", className = "Shaman", book = {}})
    equal(Host(shaman, "control", "SomeHost"), "link", "a Shaman has no control spells")
    -- A context for another class draws nothing.
    local state = fixture({before = SectionToolkit})
    local category, layout = state.env.Settings.RegisterVerticalLayoutSubcategory({name = "Host"}, "x")
    equal(state.ddt.BuildSettingsSection("control", category, layout,
        {class = "MAGE", own = false, variable = function(name) return "X_" .. name end}), false)
    equal(state.settings.X_DDT_CONTROL, nil)
end)

test("settings sections: a host building before our PLAYER_LOGIN starts us once; no toolkit, no rows", function()
    local state = fixture({before = SectionToolkit, noLogin = true})
    equal(state.ddt.started, nil)
    equal(Host(state, "control", "WarlockToolsForever"), "rows")
    equal(state.ddt.started, true)
    local tracker = state.ddt.controlTracker
    assert(tracker, "the engines started")
    state.events.scripts.OnEvent(state.events, "PLAYER_LOGIN")
    equal(state.ddt.controlTracker, tracker, "started once")
    assert(state.settings.DDT_CONTROL, "our own page at our login")
    equal(#state.duplicates, 0)
    equal(#state.messages, 0)
    -- Without a usable Toolkit the section draws nothing.
    local old = fixture({before = function(s)
        SectionToolkit(s)
        s.env.C_AddOns.GetAddOnMetadata = function(addon, field)
            if field == "Version" and addon == "DyresToolkit" then return "2.9.0" end
            if field == "Group" then return "DyresToolkit" end
        end
    end, noLogin = true})
    equal(Host(old, "control", "WarlockToolsForever"), "link")
end)

-- Every modify predicate of a row (nil: always active).

local function Active(setting)
    local initializer = setting.initializer or setting
    return initializer.modify == nil or initializer.modify() == true
end

test("greyed by the whole chain: a row is off while any switch above it is off, on our page", function()
    local state = fixture({before = SectionToolkit})
    local s, db = state.settings, state.ddt.db
    db.dots.enabled, db.dots.plateDots, db.dots.curseMode = true, true, "smart"
    equal(Active(s.DDT_DOTS_PLATES_OFFSET), true)
    equal(Active(s.DDT_DOTS_CURSE_MARKER), true)
    db.dots.enabled = false
    -- Children and grandchildren of the tracker's Enable.
    -- Per-panel rows with a Toolkit that has them (TRACKER_PANEL_OPTIONS), else
    -- the tracker-wide ones (the CI copy).
    local perPanel = s.DDT_PANEL_TARGET_HEALTH ~= nil
    local health = perPanel and "DDT_PANEL_TARGET_HEALTH" or "DDT_DOTS_HEALTH"
    local function HealthOff()
        if perPanel then db.dots.panels.target.health = false else db.dots.health = false end
    end
    for _, variable in ipairs({"DDT_DOTS_THEME", "DDT_DOTS_PLATES", "DDT_DOTS_PLATES_OFFSET", "DDT_DOTS_CURSE_MODE",
            "DDT_DOTS_CURSE_MARKER", "DDT_DOTS_ORDER_1", "DDT_DOTS_ONPLATE_CORRUPTION", health,
            health .. "_TEXT"}) do
        assert(s[variable], variable)
        equal(Active(s[variable]), false, variable .. " while the tracker is off")
    end
    equal(Active(state.buttonRows["Each DoT: Reset order and colors"]), false, "its Reset")
    equal(Active(state.buttonRows[perPanel and "Target panel: Reset Target panel" or "Tracker size: Reset size"]), false)
    equal(Active(s.DDT_DOTS), true, "the switch itself")
    -- The middle switch off, the top on: the grandchild is greyed too.
    db.dots.enabled, db.dots.plateDots, db.dots.curseMode = true, false, "last"
    equal(Active(s.DDT_DOTS_PLATES_OFFSET), false)
    equal(Active(s.DDT_DOTS_ONPLATE_CORRUPTION), false)
    equal(Active(s.DDT_DOTS_CURSE_MARKER), false)
    HealthOff()
    equal(Active(s[health .. "_TEXT"]), false)
    -- Damage to come has its own switch; DIES and its place hang on it.
    db.predict.enabled, db.predict.dies = true, true
    equal(Active(s.DDT_PREDICT_DIES_X), true)
    db.predict.enabled = false
    equal(Active(s.DDT_PREDICT_DIES_X), false)
    db.predict.enabled, db.predict.dies = true, false
    equal(Active(s.DDT_PREDICT_DIES_X), false)
    -- The crowd-control switch: every row (John, 2026-11-27: "disable all
    -- the functionality, not just the bar"; Toolkit Control.lua: no messages,
    -- macros deleted).
    db.control.enabled = false
    for _, variable in ipairs({"DDT_CONTROL_PLATES", "DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE", "DDT_CONTROL_MACROS",
            "DDT_CONTROL_MARKER_BANISH", "DDT_ANNOUNCE_FEAR", "DDT_ANNOUNCE_SAY"}) do
        equal(Active(s[variable]), false, variable)
    end
    db.control.enabled, db.control.macros = true, false
    equal(Active(s.DDT_CONTROL_MARKER_BANISH), false, "the marker is the macro's")
    equal(Active(s.DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE), true)
end)

test("settings sections, version 3: the top switch on the host's top page, the rest greyed by the chain", function()
    local state = fixture({before = SectionToolkit})
    local s, db, prefix = state.settings, state.ddt.db, "DYRE_WARLOCKTOOLSFOREVER__"
    equal(Host(state, "tracker", "WarlockToolsForever", "Top", "master"), "rows")
    equal(Host(state, "control", "WarlockToolsForever", "Top", "master"), "rows")
    equal(Host(state, "dots", "WarlockToolsForever", "Top", "master"), nil, "dots has no single top switch")
    local top = Prefixed(state, prefix)
    equal(table.concat(top, ","), prefix .. "DDT_CONTROL," .. prefix .. "DDT_DOTS", "only the two switches")
    equal(s[prefix .. "DDT_DOTS"].category, "Top")
    -- Named for the top page, where several AddOns' switches sit together.
    equal(s[prefix .. "DDT_DOTS"].name, "DoT Tracker", "the section's title")
    equal(s[prefix .. "DDT_CONTROL"].name, "Crowd Control")
    equal(s[prefix .. "DDT_CONTROL"].tooltip, s.DDT_CONTROL.tooltip, "the same sentence, no page note")
    equal(s[prefix .. "DDT_DOTS"].tooltip, s.DDT_DOTS.tooltip)
    equal(s[prefix .. "DDT_DOTS"].tooltip:find("page", 1, true), nil, "no note on where the settings are")
    equal(s.DDT_DOTS.name, "Enable DoT tracker", "our own page keeps its label")
    equal(s.DDT_CONTROL.name, "Enable crowd control")
    assert(s.DDT_CONTROL.tooltip:find("removes the \"!\" macros from your action bars", 1, true), "says the macros go")
    assert(s[prefix .. "DDT_CONTROL"].tooltip:find("stops the group messages", 1, true), "says the messages stop")
    for _, key in ipairs({"tracker", "dots", "control"}) do
        equal(Host(state, key, "WarlockToolsForever", key, "rest"), "rows", key)
    end
    equal(#state.duplicates, 0, table.concat(state.duplicates, ","))
    equal(s[prefix .. "DDT_DOTS"].category, "Top", "the switch is not drawn again")
    equal(s[prefix .. "DDT_CONTROL"].category, "Top")
    -- On the sub-pages, greyed by the chain (the top switch is elsewhere).
    db.dots.enabled, db.control.enabled = false, false
    for _, variable in ipairs({"DDT_DOTS_THEME", "DDT_DOTS_CURSE_MARKER", "DDT_DOTS_PLATES_OFFSET",
            "DDT_CONTROL_PLATES", "DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE"}) do
        equal(Active(s[prefix .. variable]), false, variable)
    end
    s[prefix .. "DDT_DOTS"].set(true)
    equal(Active(s[prefix .. "DDT_DOTS_THEME"]), true, "the top page's switch turns them on")
    -- A Mage's Polymorph page: the bar's switch alone on MTF's top page.
    local mage = fixture({before = SectionToolkit, class = "MAGE", className = "Mage",
        book = {{118, "Polymorph"}, {133, "Fireball"}}})
    equal(Host(mage, "control", "MageToolsForever", "Top", "master"), "rows")
    equal(table.concat(Prefixed(mage, "DYRE_MAGETOOLSFOREVER__"), ","), "DYRE_MAGETOOLSFOREVER__DDT_CONTROL")
    equal(mage.settings.DYRE_MAGETOOLSFOREVER__DDT_CONTROL.name, "Crowd Control")
    equal(mage.settings.DYRE_MAGETOOLSFOREVER__DDT_CONTROL.tooltip:find("page", 1, true), nil)
    equal(Host(mage, "control", "MageToolsForever", "Polymorph", "rest"), "rows")
    equal(#mage.duplicates, 0)
    -- MTF's Polymorph sub-page with the bar off on the top page: every row and
    -- the bar's Reset grey (the switch stops the macros and messages too).
    local ms, mp = mage.settings, "DYRE_MAGETOOLSFOREVER__"
    mage.ddt.db.control.enabled = false
    for _, name in ipairs({"SCALE", "WIDTH", "BARHEIGHT", "TEXTSCALE", "OPACITY"}) do
        equal(Active(ms[mp .. "DYRE_DYRESDEBUFFTRACKER_CONTROL_" .. name]), false, name)
    end
    for _, variable in ipairs({"DDT_CONTROL_MACROS", "DDT_CONTROL_MARKER_POLYMORPH", "DDT_ANNOUNCE_POLYMORPH",
            "DDT_ANNOUNCE_SAY"}) do
        equal(Active(ms[mp .. variable]), false, variable)
        assert(Watched(ms[mp .. variable]):find(mp .. "DDT_CONTROL", 1, true), variable .. " watches the top switch")
    end
    -- The bar's Reset size (the Toolkit greys it through opts.modify; the CI
    -- copy's stub greys only the sliders).
    local reset = mage.buttonRows["Crowd Control: Reset size"]
    assert(reset, "the bar's Reset size on the host page")
    if reset.modify then
        equal(reset.modify(), false, "the bar's Reset size")
    end
    mage.ddt.db.control.enabled = true
    equal(Active(ms[mp .. "DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE"]), true)
    -- Nothing for the class: no top switch either.
    local paladin = fixture({before = SectionToolkit, class = "PALADIN", className = "Paladin", book = {}})
    equal(Host(paladin, "tracker", "SomeHost", "Top", "master"), nil)
    equal(#Prefixed(paladin, "DYRE_SOMEHOST__"), 0)
end)

test("settings sections, version 2: a part is ignored, the whole section is drawn as before", function()
    local state = fixture({before = function(s)
        SectionToolkit(s)
        s.toolkit.SETTINGS_SECTIONS_VERSION = 2
    end})
    equal(Host(state, "tracker", "WarlockToolsForever", "x", "master"), "rows")
    assert(state.settings.DYRE_WARLOCKTOOLSFOREVER__DDT_DOTS_THEME, "all rows with version 2")
    assert(state.settings.DYRE_WARLOCKTOOLSFOREVER__DDT_DOTS, "and the switch")
    equal(#state.duplicates, 0)
end)


test("live greying: every greyed row watches every switch in its chain, on our page and on a host's", function()
    local state = fixture({before = SectionToolkit})
    local s = state.settings
    equal(Watched(s.DDT_DOTS_CURSE_MARKER), "DDT_DOTS,DDT_DOTS_CURSE_MODE", "a grandchild")
    equal(Watched(s.DDT_DOTS_PLATES_OFFSET), "DDT_DOTS,DDT_DOTS_PLATES")
    equal(Watched(s.DDT_DOTS_ONPLATE_CORRUPTION), "DDT_DOTS,DDT_DOTS_PLATES")
    local health = s.DDT_PANEL_TARGET_HEALTH and "DDT_PANEL_TARGET_HEALTH" or "DDT_DOTS_HEALTH"
    equal(Watched(s[health .. "_TEXT"]), "DDT_DOTS," .. health)
    equal(Watched(s.DDT_DOTS_THEME), "DDT_DOTS")
    equal(Watched(s.DDT_PREDICT_DIES_X), "DDT_PREDICT,DDT_PREDICT_DIES", "also the switch it reads")
    equal(Watched(s.DDT_PREDICT_PLATE_DIES_Y), "DDT_PREDICT,DDT_PREDICT_DIES,DDT_PREDICT_PLATES")
    equal(Watched(state.buttonRows["Each DoT: Reset order and colors"]), "DDT_DOTS", "a Reset")
    equal(Watched(s.DDT_CONTROL_MARKER_BANISH), "DDT_CONTROL,DDT_CONTROL_MACROS")
    equal(Watched(s.DDT_CONTROL_MACROS), "DDT_CONTROL")
    equal(Watched(s.DDT_ANNOUNCE_SAY), "DDT_CONTROL")
    equal(Watched(s.DDT_CONTROL_PLATES), "DDT_CONTROL")
    equal(Watched(s.DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE), "DDT_CONTROL", "the bar's size")
    equal(Watched(s.DDT_DOTS), "", "a top switch watches nothing")
    equal(Watched(s.DDT_ANNOUNCE_FEAR), "DDT_CONTROL", "under the crowd-control switch")
    -- A host's sub-page watches the switch on its top page (the same prefix).
    local prefix = "DYRE_WARLOCKTOOLSFOREVER__"
    for _, key in ipairs({"tracker", "control"}) do Host(state, key, "WarlockToolsForever", "Top", "master") end
    for _, key in ipairs({"tracker", "dots", "control"}) do Host(state, key, "WarlockToolsForever", key, "rest") end
    equal(Watched(s[prefix .. "DDT_DOTS_THEME"]), prefix .. "DDT_DOTS")
    equal(Watched(s[prefix .. "DDT_DOTS_CURSE_MARKER"]), prefix .. "DDT_DOTS," .. prefix .. "DDT_DOTS_CURSE_MODE")
    equal(Watched(s[prefix .. "DDT_DOTS_PLATES"]), prefix .. "DDT_DOTS", "dots on a page of its own")
    equal(Watched(s[prefix .. "DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE"]), prefix .. "DDT_CONTROL")
    equal(Watched(s[prefix .. "DDT_CONTROL_PLATES"]), prefix .. "DDT_CONTROL")
    -- A Mage: Note set watches the chime switch.
    local mage = Mage({before = function(st)
        SectionToolkit(st)
        Sounds(st)
    end})
    equal(Watched(mage.settings.DDT_CHILL_NOTESET), "DDT_CHILL_CHIME")
    equal(Watched(mage.settings.DDT_CHILL_SIZE), "DDT_CHILL")
    equal(Watched(mage.settings.DDT_FROST_SIZE), "DDT_FROST")
    -- Without WatchSettings (an older Toolkit): no watch, no error.
    local old = fixture({before = function(st) st.toolkit.WatchSettings = nil end})
    equal(Watched(old.settings.DDT_DOTS_CURSE_MARKER), "")
    equal(Watched(old.settings.DYRE_DYRESDEBUFFTRACKER_CONTROL_SCALE), "")
end)

test("one name per section: titles registered, pages, and the top-page switches all use it", function()
    local state = Branded({before = SectionToolkit})
    local titles = {tracker = "DoT Tracker", dots = "DoTs", control = "Crowd Control", cues = "Debuff Cues"}
    for key, title in pairs(titles) do
        equal(state.toolkit.SettingsSectionTitle("DyresDebuffTracker", key), title, key)
        contains(table.concat(state.pages, "|"), "Debuff Tracker > " .. title)
    end
    Host(state, "tracker", "WarlockToolsForever", "Top", "master")
    Host(state, "control", "WarlockToolsForever", "Top", "master")
    equal(state.settings.DYRE_WARLOCKTOOLSFOREVER__DDT_DOTS.name, titles.tracker)
    equal(state.settings.DYRE_WARLOCKTOOLSFOREVER__DDT_CONTROL.name, titles.control)
end)

test("debuff cues section: the Warlock's Demonic Brand, the Mage's arcs and Winter's Chill; none for others", function()
    -- Warlock on Forever: the Brand, under its heading, on a host's Procs page.
    local warlock = Branded({before = SectionToolkit})
    local prefix = "DYRE_WARLOCKTOOLSFOREVER__"
    equal(Host(warlock, "cues", "WarlockToolsForever", "Procs", "master"), nil, "no single top switch")
    equal(Host(warlock, "cues", "WarlockToolsForever", "Procs", "rest"), "rows")
    -- Only each cue's own heading on a host's page: no "Debuff Cues" heading
    -- with nothing under it but another heading (John, 2026-11-27).
    equal(warlock.heading("Procs: Debuff Cues"), nil, "no section heading on the host's page")
    assert(warlock.heading("Procs: Demonic Brand"), "the cue's own heading on the host's page")
    for _, variable in ipairs({"DDT_BRAND", "DDT_BRAND_SIZE", "DDT_BRAND_OFFSET"}) do
        equal(warlock.settings[prefix .. variable].category, "Procs", variable)
    end
    equal(warlock.settings[prefix .. "DDT_FROST"], nil, "no Mage cues")
    equal(#warlock.duplicates, 0)
    warlock.ddt.db.brand.enabled = false
    equal(warlock.settings[prefix .. "DDT_BRAND_SIZE"].initializer.modify(), false, "greyed below Show")
    contains(Watched(warlock.settings[prefix .. "DDT_BRAND_SIZE"]), prefix .. "DDT_BRAND")
    -- A Warlock where the client has no Demonic Brand (Classic Era): nothing,
    -- and no page of our own.
    local era = fixture({before = SectionToolkit})
    equal(Host(era, "cues", "WarlockToolsForever", "Procs", "rest"), "link")
    equal(table.concat(era.pages, "|"):find("Debuff Cues", 1, true), nil)
    -- Mage: the frozen and chilled arcs and Winter's Chill, with the talent note
    -- shown only while the talent is not known.
    local mage = Mage({before = function(st) SectionToolkit(st); Sounds(st) end, talents = {}})
    equal(Host(mage, "cues", "MageToolsForever", "Procs", "rest"), "rows")
    equal(mage.heading("Procs: Debuff Cues"), nil, "no section heading on MTF's page")
    assert(mage.heading("Procs: Frozen and chilled"), "the frost cue's own heading")
    assert(mage.heading("Procs: Winter's Chill"), "Winter's Chill's own heading")
    -- Our own page is the same as before: its cue headings, and no extra
    -- "Debuff Cues" heading row on it.
    assert(mage.heading("Debuff Cues: Frozen and chilled"))
    assert(mage.heading("Debuff Cues: Winter's Chill"))
    equal(mage.heading("Debuff Cues: Debuff Cues"), nil)
    for _, variable in ipairs({"DDT_FROST", "DDT_FROST_SIZE", "DDT_CHILL", "DDT_CHILL_SIZE", "DDT_CHILL_CHIME"}) do
        assert(mage.settings["DYRE_MAGETOOLSFOREVER__" .. variable], variable)
    end
    equal(#mage.duplicates, 0)
    -- Not learned: every Winter's Chill row greyed, the tooltip says why; no
    -- note box (John, 2026-11-27: "only enabled if I have it. Not a generic
    -- banner"). The frozen and chilled arcs need no talent.
    equal(#mage.primers, 0, "no banner")
    local mp = "DYRE_MAGETOOLSFOREVER__"
    for _, variable in ipairs({"DDT_CHILL", "DDT_CHILL_SIZE", "DDT_CHILL_OFFSET", "DDT_CHILL_CHIME"}) do
        local row = mage.settings[mp .. variable]
        equal(row.initializer.modify(), false, variable)
        contains(row.tooltip(), " Greyed out: you have not learned Winter's Chill yet.")
    end
    equal(mage.buttonRows["Preview Winter's Chill: Preview"].modify(), false, "the Preview row too")
    equal(mage.buttonRows["Reset Winter's Chill: Reset"].modify(), false)
    equal(mage.settings[mp .. "DDT_FROST"].initializer.modify == nil
        or mage.settings[mp .. "DDT_FROST"].initializer.modify() == true, true, "the frost arcs need no talent")
    local learned = Mage({before = function(st) SectionToolkit(st); Sounds(st) end})
    Host(learned, "cues", "MageToolsForever", "Procs", "rest")
    local row = learned.settings[mp .. "DDT_CHILL_SIZE"]
    equal(row.initializer.modify(), true, "learned: active")
    equal(row.tooltip(), "The size of the arc.", "learned: one sentence")
    -- The Warlock: Demonic Brand greyed until its talent is known (read as the
    -- page draws), with the same wording.
    local talented = false
    local brand = Branded({before = SectionToolkit, talents = setmetatable({}, {__index = function(_, id)
        return id == 1293695 and talented or nil end})})
    Host(brand, "cues", "WarlockToolsForever", "Procs", "rest")
    local size = brand.settings[prefix .. "DDT_BRAND_SIZE"]
    brand.ddt.db.brand.enabled = true
    equal(size.initializer.modify(), false, "not learned: greyed")
    contains(size.tooltip(), " Greyed out: you have not learned Demonic Brand yet.")
    equal(brand.buttonRows["Reset Demonic Brand: Reset"].modify(), false)
    talented = true
    equal(size.initializer.modify(), true, "learned: active at the next draw")
    equal(size.tooltip(), "The size of the pentagram.")
    -- A class with no cues: nothing.
    local priest = fixture({before = SectionToolkit, class = "PRIEST", className = "Priest", book = {}})
    equal(Host(priest, "cues", "SomeHost", "Procs", "rest"), "link")
    equal(#Prefixed(priest, "DYRE_SOMEHOST__"), 0)
end)

test("greyed button rows grey their label too (Dyre's Toolkit GreyButtonLabel), on our pages and hosts", function()
    local function Spy(st)
        SectionToolkit(st)
        st.greyLabels = {}
        local real = st.toolkit.GreyButtonLabel
        st.toolkit.GreyButtonLabel = function(initializer)
            st.greyLabels[initializer] = true
            return real and real(initializer) or initializer
        end
    end
    local warlock = Branded({before = Spy})
    for _, label in ipairs({"Preview Demonic Brand: Preview", "Reset Demonic Brand: Reset",
            "Each DoT: Reset order and colors"}) do
        assert(warlock.buttonRows[label], label)
        equal(warlock.greyLabels[warlock.buttonRows[label]], true, label)
    end
    local reset = warlock.buttonRows["Target panel: Reset Target panel"] or warlock.buttonRows["Tracker size: Reset size"]
    equal(warlock.greyLabels[reset], true, "the tracker's Reset")
    local mage = Mage({before = function(st) Spy(st); Sounds(st) end})
    for _, label in ipairs({"Preview Winter's Chill: Preview", "Test the stack chime: Test",
            "Reset Winter's Chill: Reset"}) do
        equal(mage.greyLabels[mage.buttonRows[label]], true, label)
    end
    -- On a host page too (the rows are made again there).
    Host(warlock, "cues", "WarlockToolsForever", "Procs", "rest")
    equal(warlock.greyLabels[warlock.buttonRows["Reset Demonic Brand: Reset"]], true, "host row")
    -- Without the function (an older Toolkit): no error.
    local old = Branded({before = function(st) st.toolkit.GreyButtonLabel = nil end})
    assert(old.buttonRows["Reset Demonic Brand: Reset"], "the row is still made")
end)

test("Bindings.xml: every binding in the Dyre's AddOns section, the Smart curse name kept", function()
    local xml = assert(io.open("Bindings.xml", "rb")):read("*a")
    local count = 0
    for binding in xml:gmatch("<Binding%s.-/?>") do
        count = count + 1
        equal(binding:match('category="([^"]*)"'), "Dyre's AddOns", binding)
        assert(binding:match('header="DYRESDEBUFFTRACKER"'), "the header stays: " .. binding)
    end
    equal(count, 1, "one binding")
    assert(xml:find('name="CLICK DyresDebuffTrackerSmartCurse:LeftButton"', 1, true), "the saved keys' name")
    equal(xml:find('category="ADDONS"', 1, true), nil, "not the AddOns section")
end)

test("the TOC: optional toolkit, per-character settings, and the five files in order", function()
    local toc = assert(io.open("DyresDebuffTracker.toc", "rb")):read("*a")
    equal(toc:find("\r", 1, true), nil, "LF only")
    equal(toc:match("## Interface: ([^\n]+)"), "16001, 11509")
    equal(toc:match("## OptionalDeps: ([^\n]+)"), "DyresToolkit, DyresSounds",
        "always loads; says once what to install; Dyre's Sounds for the Winter's Chill chime, load order only")
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
