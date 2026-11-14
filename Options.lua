local _, DDT = ...

-- Settings (stage E): a page under Dyre's Toolkit's "Dyre's AddOns", with two
-- pages of its own, DoTs and Crowd control, each with its own on/off switch
-- (John, 2026-10-29/30). Proxy settings read and write DyresDebuffTrackerDB
-- directly. Where a class Tools AddOn has a kind, its page says which one and
-- its settings are greyed (they apply once that AddOn's feature is off).

local REQUIRED_SETTINGS = {"RegisterProxySetting", "CreateCheckbox", "RegisterVerticalLayoutSubcategory"}
local NO_CLASS = "Dyre's Debuff Tracker has nothing for your class yet: more classes are coming."
local NO_DOTS = "Your class has no DoTs here yet."
local NO_CONTROL = "Your class has no crowd control here yet."
local THEMES = {{"compact", "Compact"}, {"bars", "Bars"}}
local HEALTH_TEXTS = {{"none", "None"}, {"number", "Number"}, {"percent", "Percent"}, {"both", "Number and percent"}}

local function HasSettingsAPI()
    if type(Settings) ~= "table" or type(Settings.VarType) ~= "table" then
        return false
    end
    for _, name in ipairs(REQUIRED_SETTINGS) do
        if type(Settings[name]) ~= "function" then
            return false
        end
    end
    return true
end

local function Heading(layout, text)
    if type(CreateSettingsListSectionHeaderInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

-- Greyed while this AddOn does not have the kind.
local function OnlyWhenOurs(initializer, kind)
    if initializer and type(initializer.AddModifyPredicate) == "function" then
        initializer:AddModifyPredicate(function() return DDT.Owns(kind) end)
    end
    return initializer
end

local function Nest(child, parent, predicate)
    if child and type(child.SetParentInitializer) == "function" then
        child:SetParentInitializer(parent, predicate)
    end
    return child
end

-- A checkbox for table()[key]; onChange runs after the value is stored.
local function Flag(category, variable, name, table, key, default, tooltip, onChange)
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, name, default,
        function() return table()[key] end,
        function(value)
            table()[key] = value == true
            onChange()
        end)
    return Settings.CreateCheckbox(category, setting, tooltip)
end

-- A dropdown of {value, label} choices, where the client has one.
local function Choice(category, variable, name, table, key, default, choices, tooltip, onChange)
    if type(Settings.CreateDropdown) ~= "function" or type(Settings.CreateControlTextContainer) ~= "function" then
        return nil
    end
    local kind = type(default) == "number" and Settings.VarType.Number or Settings.VarType.String
    local setting = Settings.RegisterProxySetting(category, variable, kind, name, default,
        function() return table()[key] end,
        function(value)
            table()[key] = value
            onChange()
        end)
    local function Options()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices) do
            container:Add(choice[1], choice[2])
        end
        return container:GetData()
    end
    return Settings.CreateDropdown(category, setting, Options, tooltip)
end

-- A slider for table()[key], whole numbers from low to high.
local function Slider(category, variable, name, table, key, default, low, high, tooltip, onChange)
    if type(Settings.CreateSlider) ~= "function" or type(Settings.CreateSliderOptions) ~= "function" then
        return nil
    end
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Number, name, default,
        function() return table()[key] end,
        function(value)
            if type(value) == "number" then
                table()[key] = math.max(low, math.min(high, math.floor(value + 0.5)))
                onChange()
            end
        end)
    local options = Settings.CreateSliderOptions(low, high, 1)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    return Settings.CreateSlider(category, setting, options, tooltip)
end

-- The line at the top of a page: who has this kind for your class.
local function Status(layout, kind, none)
    if not DDT.classData then
        Heading(layout, NO_CLASS)
        return false
    end
    local status = DDT.KindStatus(kind)
    if status == "none" then
        Heading(layout, none)
        return false
    end
    if status ~= "ours" then
        Heading(layout, status .. " has this for your class. These settings apply when it is off.")
    end
    return true
end

local function Dots() return DDT.db.dots end
local function Predict() return DDT.db.predict end
local function Control() return DDT.db.control end

local function DotsPage(parent)
    local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, "DoTs")
    DDT.dotsCategory = category
    if not Status(layout, "dots", NO_DOTS) then
        return
    end
    local function Changed() DDT.RefreshDots(false) end
    local function Rebuilt() DDT.RefreshDots(true) end
    local master = OnlyWhenOurs(Flag(category, "DDT_DOTS", "Enable", Dots, "enabled", true,
        "A row for your target, one for your focus, and up to eight more for the other mobs you DoT, each with "
            .. "a timer bar per DoT.", Changed), "dots")
    local function On() return DDT.db.dots.enabled end
    Nest(OnlyWhenOurs(Choice(category, "DDT_DOTS_THEME", "Theme", Dots, "theme", "bars", THEMES,
        "Compact: a row with the name and an icon per DoT. Bars: the name above one bar per DoT.", Rebuilt), "dots"),
        master, On)
    local health = Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_HEALTH", "Show mob health", Dots, "health", false,
        "The line with the mob's name is its health bar, with the damage to come drawn on it.", Rebuilt), "dots"),
        master, On)
    Nest(OnlyWhenOurs(Choice(category, "DDT_DOTS_HEALTH_TEXT", "Health text", Dots, "healthText", "none",
        HEALTH_TEXTS, "Text after the mob's name.", Rebuilt), "dots"), health,
        function() return DDT.db.dots.enabled and DDT.db.dots.health end)
    Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_PLATES", "Show DoT dots on nameplates", Dots, "plateDots", false,
        "In combat, a dot above each enemy nameplate for each of your DoTs, colored while it is up.", Changed),
        "dots"), master, On)
    if DDT.predictor then
        Heading(layout, "Damage to come")
        local predict = OnlyWhenOurs(Flag(category, "DDT_PREDICT", "Show Predictive DoT Damage", Predict, "enabled",
            true, "A striped block on the mob's health bar for the damage your DoTs still have to deal.", Changed),
            "dots")
        local function PredictOn() return DDT.db.predict.enabled end
        Nest(OnlyWhenOurs(Flag(category, "DDT_PREDICT_PLATES", "Also on nameplates", Predict, "plates", true,
            "The block on enemy nameplates too.", Changed), "dots"), predict, PredictOn)
        Nest(OnlyWhenOurs(Flag(category, "DDT_PREDICT_DIES", "Show DIES", Predict, "dies", true,
            "A red skull and DIES when the damage to come is enough to kill the mob.", Changed), "dots"),
            predict, PredictOn)
        local colors = {}
        for _, preset in ipairs(DDT.PREDICT_COLORS) do
            colors[#colors + 1] = {preset.key, preset.label}
        end
        Nest(OnlyWhenOurs(Choice(category, "DDT_PREDICT_COLOR", "Block color", Predict, "color", "purple", colors,
            "The block's color.", Changed), "dots"), predict, PredictOn)
        -- Where DIES goes (John, 2026-11-09): target and focus frames, then nameplates.
        local function DiesOn() return DDT.db.predict.enabled and DDT.db.predict.dies end
        local function PlateDiesOn() return DiesOn() and DDT.db.predict.plates end
        local range = DDT.DIES_OFFSET
        for _, part in ipairs({{"DIES", "dies", "target and focus", "your target and focus frames", DiesOn},
                {"PLATE_DIES", "plateDies", "nameplates", "nameplates", PlateDiesOn}}) do
            local id, key, short, long, on = part[1], part[2], part[3], part[4], part[5]
            Nest(OnlyWhenOurs(Choice(category, "DDT_PREDICT_" .. id .. "_PLACE", "DIES place: " .. short, Predict,
                key .. "Place", "auto", DDT.DIES_PLACES, "Where DIES shows on " .. long .. ". Auto puts it beside "
                    .. "the bar, on a side nothing else uses. Center puts it in the middle of the bar.", Changed),
                "dots"), predict, on)
            Nest(OnlyWhenOurs(Slider(category, "DDT_PREDICT_" .. id .. "_X", "DIES left/right: " .. short, Predict,
                key .. "X", 0, -range, range, "Moves DIES on " .. long .. ", in pixels: up to " .. range
                    .. " left or right.", Changed), "dots"), predict, on)
            Nest(OnlyWhenOurs(Slider(category, "DDT_PREDICT_" .. id .. "_Y", "DIES down/up: " .. short, Predict,
                key .. "Y", 0, -range, range, "Moves DIES on " .. long .. ", in pixels: up to " .. range
                    .. " down or up.", Changed), "dots"), predict, on)
        end
    end
end

local function ControlPage(parent)
    local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, "Crowd control")
    DDT.controlCategory = category
    if not Status(layout, "control", NO_CONTROL) then
        return
    end
    local spells = DDT.classData.control
    local function Changed() DDT.RefreshControl() end
    local master = OnlyWhenOurs(Flag(category, "DDT_CONTROL", "Enable", Control, "enabled", true,
        "A bar for each mob you control, with its name and time left, so you know which one breaks next.",
        Changed), "control")
    local function On() return DDT.db.control.enabled end
    Nest(OnlyWhenOurs(Flag(category, "DDT_CONTROL_MACROS", "Keep the control macros", Control, "macros", true,
        "A character macro for each control spell you know (\"! Fear\", \"! Polymorph\", ...): it makes the mob "
            .. "under your mouse your focus, marks it, and casts on it. Off deletes them.", Changed), "control"),
        master, On)
    for _, spell in ipairs(spells) do
        if spell.plateTimer then
            Nest(OnlyWhenOurs(Flag(category, "DDT_CONTROL_PLATES", "Timers on nameplates", Control, "plateTimers",
                true, "A thin bar under each controlled mob's nameplate with its time left.", Changed), "control"),
                master, On)
            break
        end
    end
    local markers = {}
    for _, marker in ipairs(DDT.toolkit.RAID_MARKERS) do
        markers[#markers + 1] = {marker.index, marker.label}
    end
    local function Markers() return DDT.db.control.markers end
    for _, spell in ipairs(spells) do
        if spell.marker then
            Nest(OnlyWhenOurs(Choice(category, "DDT_CONTROL_MARKER_" .. spell.key:upper(), spell.label .. " marker",
                Markers, spell.key, spell.marker, markers,
                "The raid marker the macro puts on your " .. spell.label .. " target, so your group leaves it alone.",
                Changed), "control"), master, On)
        end
    end
    Heading(layout, "Tell your group")
    local function Announce() return DDT.db.control.announce end
    for _, spell in ipairs(spells) do
        OnlyWhenOurs(Flag(category, "DDT_ANNOUNCE_" .. spell.key:upper(), spell.label, Announce, spell.key, false,
            "Tell your party or raid as you cast it: " .. DDT.db.control.texts[spell.key], Changed), "control")
    end
    OnlyWhenOurs(Flag(category, "DDT_ANNOUNCE_SAY", "Say instead of party or raid", Control, "say", false,
        "Messages go to Say, also when you are alone.", Changed), "control")
    if DDT.controlWidget then
        DDT.toolkit.AddWidgetSettings(category, layout, DDT.controlWidget, {labels = {scale = "Bar size"}})
    end
end

function DDT.InitializeOptions()
    if not HasSettingsAPI() then
        return
    end
    local category, layout = DDT.toolkit.RegisterSettingsCategory(DDT.TITLE)
    if not category then
        return
    end
    DDT.category = category
    if not DDT.classData then
        Heading(layout, NO_CLASS)
    elseif DDT.yieldsTo then
        Heading(layout, DDT.yieldsTo.title .. " has your DoTs and crowd control. Turn it off, or update it, to "
            .. "use Dyre's Debuff Tracker for them.")
    else
        Heading(layout, "DoTs and crowd control for your class; each has its own page below.")
    end
    DotsPage(category)
    ControlPage(category)
end
