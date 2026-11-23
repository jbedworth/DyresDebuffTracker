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
local GROW_CHOICES = {{"down", "Down"}, {"up", "Up"}}
local HEALTH_TEXTS = {{"none", "None"}, {"number", "Number"}, {"percent", "Percent"}, {"both", "Number and percent"}}
-- Warlock Tools Forever's tracker settings, moved here (John, via the lead,
-- 2026-11-20: "This includes DoT Colors, tracker panels, etc."), with WTF's
-- labels, so a WTF player finds them by the same names.
local PANEL_NAMES = {{"target", "Target"}, {"focus", "Focus"}, {"list", "Others"}}
local SIZE_LABELS = {iconSize = "Icon size", nameWidth = "Name width", textScale = "Text size",
    barWidth = "Bar width", lineHeight = "Line height"}
local SIZE_TIPS = {nameWidth = "The room the name has beside the icons (name Left or Right): the row grows or "
    .. "shrinks with it. A longer name is cut with \"...\". Above or below the icons, the name spans the row."}
local NAME_POSITION_LABELS = {left = "Left", right = "Right", above = "Above", below = "Below"}
local FILLS = {{"stripes", "Stripes"}, {"solid", "Solid"}, {"bar", "Bar texture"}}
local OUTLINES = {{"none", "None"}, {"solid", "Solid"}}
local CURSE_MODES = {{"last", "Last used"}, {"smart", "Smart curse"}}
local SMART_CURSE_HELP = "Smart curse: with no modifier, Curse of Tongues on a mob with mana, else Curse of the "
    .. "Elements, else Curse of Weakness, chosen out of combat as your target changes. Shift casts Weakness, Ctrl "
    .. "Tongues (Weakness if you do not know Tongues), Alt Recklessness. The \"! Curse\" macro and the Smart curse "
    .. "key binding (Key Bindings, Dyre's Debuff Tracker) cast it too."

-- A slider's value as whole-number text.
function DDT.WholeLabel(value)
    return string.format("%d", math.floor((tonumber(value) or 0) + 0.5))
end

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

-- Shown only while the chosen look is this one (the list checks it again on
-- each setting change).
local function ShowFor(initializer, predicate)
    if initializer and type(initializer.AddShownPredicate) == "function" then
        initializer:AddShownPredicate(predicate)
    end
    return initializer
end

-- A color swatch (AARRGGBB, as WTF's), where the client has one.
local function Swatch(category, variable, name, table, key, default, tooltip, onChange)
    if type(Settings.CreateColorSwatch) ~= "function" then
        return nil
    end
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.String, name, default,
        function() return table()[key] end,
        function(value)
            table()[key] = DDT.SanitizeColor(value, default)
            onChange()
        end)
    return Settings.CreateColorSwatch(category, setting, tooltip)
end

-- A button row (pinned Blizzard_SettingControls.lua: CreateSettingsButtonInitializer).
local function Button(layout, name, text, onClick, tooltip)
    if type(CreateSettingsButtonInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        local initializer = CreateSettingsButtonInitializer(name, text, onClick, tooltip, true)
        layout:AddInitializer(initializer)
        return initializer
    end
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

-- The Toolkit's gold mark at the slider's default (John, 2026-11-21: "set
-- notches on the sliders default values"). range = {min, max, default}.
local function DefaultTick(initializer, range)
    if initializer and DDT.toolkit and type(DDT.toolkit.AddDefaultTick) == "function" then
        DDT.toolkit.AddDefaultTick(initializer, range)
    end
    return initializer
end

-- A slider for table()[key], whole numbers from low to high, with the gold
-- default mark. label: how the number shows (DDT.WholeLabel when nil).
local function Slider(category, variable, name, table, key, default, low, high, tooltip, onChange, label)
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
        -- Always a number: with no formatter the slider shows no value, and a
        -- thumb at 3 of 0-20 reads as 0 (John's Outline width, 2026-11-21).
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, label or DDT.WholeLabel)
    end
    return DefaultTick(Settings.CreateSlider(category, setting, options, tooltip),
        {min = low, max = high, step = 1, default = default})
end

-- "Tracker size": a percent slider on steps of 5, with the gold default mark.
local function TrackerSize(category, tooltip, onChange)
    if type(Settings.CreateSlider) ~= "function" or type(Settings.CreateSliderOptions) ~= "function" then
        return nil
    end
    local spec = DDT.TRACKER_SIZE
    local setting = Settings.RegisterProxySetting(category, "DDT_DOTS_TRACKER_SIZE", Settings.VarType.Number,
        "Tracker size", spec.default,
        function()
            local dots = DDT.db.dots
            if dots.trackerSize ~= false then
                return dots.trackerSize
            end
            -- Sizes set one by one: the nearest percent of the chosen look.
            local theme = dots.theme == "bars" and "bars" or "compact"
            local key = theme == "bars" and "barWidth" or "iconSize"
            return DDT.SanitizeTrackerSize(dots.sizes[theme][key] * 100 / DDT.SizeDefault(theme, key))
        end,
        function(value)
            if type(value) == "number" then
                DDT.db.dots.trackerSize = DDT.SanitizeTrackerSize(value)
                DDT.ApplyTrackerSize(DDT.db.dots)
                onChange()
            end
        end)
    local options = Settings.CreateSliderOptions(spec.min, spec.max, spec.step)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format("%d%%", value)
        end)
    end
    return DefaultTick(Settings.CreateSlider(category, setting, options, tooltip), spec)
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
local function Frost() return DDT.db.frost end
local function Brand() return DDT.db.brand end
local function Chill() return DDT.db.wintersChill end
local function Predict() return DDT.db.predict end
local function Control() return DDT.db.control end

-- The Mage's frozen and chilled arcs (Frost.lua; John, 2026-11-18). This
-- AddOn's own: never greyed for a Tools AddOn, which has none.
local function FrostSection(category, layout)
    if DDT.class ~= "MAGE" or not DDT.frostArcs then
        return
    end
    Heading(layout, "Frozen and chilled")
    local master = Flag(category, "DDT_FROST", "Show frozen and chilled arcs", Frost, "enabled", true,
        "Above each enemy nameplate: an arc of ice crystals while the mob is Frozen (Shatter works on it), and a "
            .. "thin arc of frost and snowflakes while your Chill is on it (Frostbite and Fingers of Frost can proc). A mob that is both "
            .. "shows both, Frozen above.", DDT.RefreshFrost)
    local function On() return DDT.db.frost.enabled end
    local offset, size = DDT.FROST_OFFSET, DDT.FROST_SIZE
    Nest(Slider(category, "DDT_FROST_OFFSET", "Arc height", Frost, "offset", offset.default, offset.min, offset.max,
        "How far above the nameplate's health bar the arcs sit, in pixels: " .. offset.min .. " to " .. offset.max
            .. ".", DDT.RefreshFrost), master, On)
    Nest(Slider(category, "DDT_FROST_SIZE", "Arc size", Frost, "size", size.default, size.min, size.max,
        "The arcs' size, in percent: " .. size.min .. " to " .. size.max .. ".", DDT.RefreshFrost), master, On)
end

-- The Mage's Winter's Chill balls (Frost.lua; John, 2026-11-22: "add a
-- similar halo above the nameplate ... with up to 5 cells (one per charge)").
-- This AddOn's own, as the arcs: never greyed. Every change applies at once.
local function ChillSection(category, layout)
    if DDT.class ~= "MAGE" or not DDT.chillArcs then
        return
    end
    Heading(layout, "Winter's Chill")
    local master = Flag(category, "DDT_CHILL", "Show", Chill, "enabled", true,
        "Five blue frost balls above an enemy's nameplate while your Winter's Chill is on it: one more turns white with each stack, up to "
            .. DDT.CHILL_MOST .. ", as combo points. Your Frost spells add the stacks.", DDT.RefreshChill)
    local function On() return DDT.db.wintersChill.enabled end
    local offset, size = DDT.CHILL_OFFSET, DDT.CHILL_SIZE
    Nest(Slider(category, "DDT_CHILL_SIZE", "Size", Chill, "size", size.default, size.min, size.max,
        "The balls' size, in percent: " .. size.min .. " to " .. size.max .. ".", DDT.RefreshChill,
        function(value) return string.format("%d%%", value) end), master, On)
    Nest(Slider(category, "DDT_CHILL_OFFSET", "Height above nameplate", Chill, "offset", offset.default, offset.min,
        offset.max, "How far above the nameplate's health bar the balls sit, in pixels: " .. offset.min .. " to "
            .. offset.max .. ". The default sits above the frozen and chilled arcs.", DDT.RefreshChill), master, On)
    Button(layout, "Winter's Chill", "Preview", DDT.PreviewChill,
        "Shows the balls on your target's nameplate with no Winter's Chill on it (" .. DDT.CHILL_PREVIEW .. " of "
            .. DDT.CHILL_MOST .. " white), so you can set Size and Height. Press again, or change target, to end it.")
    -- The stack chime (Chime.lua): where the combat log runs (Classic Era).
    if DDT.ChillChimeUsable() then
        Flag(category, "DDT_CHILL_CHIME", "Stack chime", Chill, "chime", true,
            "A note as each stack of your Winter's Chill goes on a mob: rising from 1 to " .. (DDT.CHILL_MOST - 1)
                .. ", and a held high note at " .. DDT.CHILL_MOST .. ". A stack that drops, or the debuff ending, "
                .. "plays nothing. Only your target's stacks chime; another Mage's Winter's Chill does not. Needs Dyre's Sounds.",
            DDT.RefreshChillChime)
        local function ChimeOn() return DDT.db.wintersChill.chime end
        local sets = {}
        for _, key in ipairs(DDT.CHILL_CHIME_ORDER) do
            sets[#sets + 1] = {key, DDT.CHILL_CHIME_SETS[key].label}
        end
        local noteSet = Choice(category, "DDT_CHILL_NOTESET", "Note set", Chill, "noteSet", DDT.CHILL_CHIME_DEFAULT,
            sets, "The chime's instrument, from Dyre's Sounds.", function()
                DDT.PlayChillNote(DDT.ChillChimeNote(DDT.CHILL_MOST, DDT.db.wintersChill.noteSet), "Winter's Chill")
            end)
        if noteSet and type(noteSet.AddModifyPredicate) == "function" then
            noteSet:AddModifyPredicate(ChimeOn)
        end
        Button(layout, "Winter's Chill", "Test chime", DDT.TestChillChime,
            "Plays the chime for stacks 1 to " .. DDT.CHILL_MOST .. ", one after another.")
    end
    Button(layout, "Winter's Chill", "Reset Winter's Chill", DDT.ResetChill,
        "Show, Size, Height, and the chime back to their defaults: on, " .. size.default .. "%, " .. offset.default
            .. " pixels, chime on, Bassoon.")
end

-- The Warlock's Demonic Brand pentagram (Frost.lua; John, via the lead,
-- 2026-11-21: "Make it a glowing red pentagram that renders above the
-- nameplate, and make it so the size and height can be adjusted"). This
-- AddOn's own, as the Mage's arcs: never greyed for a Tools AddOn. Only
-- where the client knows the debuff (Forever). Every change applies at once.
local function BrandSection(category, layout)
    if DDT.class ~= "WARLOCK" or not DDT.brandArcs then
        return
    end
    Heading(layout, "Demonic Brand")
    local master = Flag(category, "DDT_BRAND", "Show", Brand, "enabled", true,
        "A glowing red pentagram above an enemy's nameplate while your Demonic Brand is on it (your Searing Pain "
            .. "puts it there; your demon's next attacks on it deal extra damage). Recast Searing Pain when it goes.",
        DDT.RefreshBrand)
    local function On() return DDT.db.brand.enabled end
    local offset, size = DDT.BRAND_OFFSET, DDT.BRAND_SIZE
    Nest(Slider(category, "DDT_BRAND_SIZE", "Size", Brand, "size", size.default, size.min, size.max,
        "The pentagram's size, in percent: " .. size.min .. " to " .. size.max .. ".", DDT.RefreshBrand,
        function(value) return string.format("%d%%", value) end), master, On)
    Nest(Slider(category, "DDT_BRAND_OFFSET", "Height above nameplate", Brand, "offset", offset.default, offset.min,
        offset.max, "How far above the nameplate's health bar the pentagram's glow starts, in pixels: " .. offset.min
            .. " to " .. offset.max .. ".", DDT.RefreshBrand), master, On)
    Button(layout, "Demonic Brand", "Preview", DDT.PreviewBrand,
        "Shows the pentagram on your target's nameplate with no Demonic Brand on it, so you can set Size and "
            .. "Height. Press again, or change target, to end it.")
    Button(layout, "Demonic Brand", "Reset Demonic Brand", DDT.ResetBrand,
        "Show, Size, and Height back to their defaults: on, " .. size.default .. "%, " .. offset.default
            .. " pixels.")
end

-- A percent slider for a panel's Tracker size (DDT.TRACKER_SIZE); false
-- (sizes set one by one) shows the nearest percent of the chosen look.
local function PanelTrackerSize(category, variable, panel, tooltip, onChange)
    if type(Settings.CreateSlider) ~= "function" or type(Settings.CreateSliderOptions) ~= "function" then
        return nil
    end
    local spec = DDT.TRACKER_SIZE
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Number, "Tracker size",
        spec.default,
        function()
            local own = panel()
            if own.trackerSize ~= false then
                return own.trackerSize
            end
            local theme = DDT.db.dots.theme == "bars" and "bars" or "compact"
            local key = theme == "bars" and "barWidth" or "iconSize"
            return DDT.SanitizeTrackerSize(own.sizes[theme][key] * 100 / DDT.SizeDefault(theme, key))
        end,
        function(value)
            if type(value) == "number" then
                local own = panel()
                own.trackerSize = DDT.SanitizeTrackerSize(value)
                DDT.ApplyTrackerSize(own)
                onChange()
            end
        end)
    local options = Settings.CreateSliderOptions(spec.min, spec.max, spec.step)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format("%d%%", value)
        end)
    end
    return DefaultTick(Settings.CreateSlider(category, setting, options, tooltip), spec)
end

-- The Panels section (the Toolkit's TRACKER_PANEL_OPTIONS; John, 2026-11-21:
-- "The panel settings need to be organized by the panel they control, and
-- each needs it's own config (size, border width, etc.) In the "Panels"
-- section, with a sub-section heading for Target, Focus, and Other"; "The
-- show mob health checkbox, and text config ... are missing from the
-- Target/Focus/Others boxes"). One sub-section per panel, each with its own
-- switch, health, frame, outline (Target and Focus: the list has none),
-- grow, sizes, color, opacity, and Reset.
local function PanelSections(category, layout, master, On, Changed, Rebuilt)
    local toolkit = DDT.toolkit
    Heading(layout, "Panels")
    for _, entry in ipairs(PANEL_NAMES) do
        local key, name = entry[1], entry[2]
        local id = "DDT_PANEL_" .. key:upper() .. "_"
        local function Panel() return DDT.db.dots.panels[key] end
        local function PanelOn() return DDT.db.dots.enabled end
        Heading(layout, name .. " panel")
        if type(toolkit.TRACKER_PANELS) == "table" then
            local function Show() return DDT.db.dots.show end
            Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_SHOW_" .. key:upper(), "Show " .. name .. " panel", Show, key,
                true, key == "list" and "The panel for the other mobs you DoT. Your target and focus stay out of it."
                    or "The panel for your " .. key .. "'s DoTs.", Changed), "dots"), master, On)
        end
        local health = Nest(OnlyWhenOurs(Flag(category, id .. "HEALTH", "Show mob health", Panel, "health", false,
            "The line with the mob's name is its health bar, with the damage to come drawn on it. This panel only. "
                .. "A change in combat applies when combat ends.", Rebuilt), "dots"), master, On)
        Nest(OnlyWhenOurs(Choice(category, id .. "HEALTH_TEXT", "Health text", Panel, "healthText", "none",
            HEALTH_TEXTS, "Text after the mob's name: its health as a number, a percent, or both. This panel only.",
            Rebuilt), "dots"), health, function() return PanelOn() and Panel().health end)
        if toolkit.TRACKER_FRAME == true then
            Nest(OnlyWhenOurs(Flag(category, id .. "FRAME", "Show panel frame", Panel, "frame", true,
                "The background and border behind each mob's name and DoTs in this panel. Turn it off to see only "
                    .. "the name and the DoTs. Applies at once, also in combat.", Changed), "dots"), master, On)
        end
        if key ~= "list" and type(toolkit.TRACKER_OUTLINE) == "table" then
            local outline = DDT.OUTLINE_WIDTH
            Nest(OnlyWhenOurs(Slider(category, id .. "OUTLINE", "Outline width", Panel, "outlineWidth",
                outline.default, outline.min, outline.max, "The colored outline around the " .. name .. " panel, "
                    .. "in pixels: " .. outline.min .. " to " .. outline.max .. ". 0 draws none. A change in combat "
                    .. "applies when combat ends.", Rebuilt), "dots"), master, On)
        end
        if type(toolkit.TRACKER_GROW) == "table" then
            local function Grow() return DDT.db.dots.grow end
            Nest(OnlyWhenOurs(Choice(category, "DDT_DOTS_GROW_" .. key:upper(), "Grow", Grow, key, "down",
                GROW_CHOICES, "Up puts the first DoT where you placed the panel and the next ones above it (Bars "
                    .. "look). Down puts them below it." .. (key == "list" and " Up also stacks new mobs upward, in "
                    .. "both looks." or "") .. " The name keeps its place.", Rebuilt), "dots"), master, On)
        end
        Nest(OnlyWhenOurs(PanelTrackerSize(category, id .. "TRACKER_SIZE", Panel, "Bars: the length of this panel's "
            .. "DoT bars. Compact: the size of its DoT icons. From 75% to 125%. A change in combat applies when "
            .. "combat ends.", Rebuilt), "dots"), master, On)
        for _, theme in ipairs({"compact", "bars"}) do
            local function ThisLook() return DDT.db.dots.theme == theme end
            local function Sizes() return Panel().sizes[theme] end
            local look = theme == "bars" and "Bars" or "Compact"
            for _, spec in ipairs(DDT.SIZE_SPECS[theme]) do
                local label = SIZE_LABELS[spec.key]
                local setting = Settings.RegisterProxySetting(category, id .. theme:upper() .. "_" .. spec.key:upper(),
                    Settings.VarType.Number, label, spec.default,
                    function() return Sizes()[spec.key] end,
                    function(value)
                        if type(value) == "number" then
                            local saved = {}
                            for each, current in pairs(Sizes()) do
                                saved[each] = current
                            end
                            saved[spec.key] = value
                            Panel().sizes[theme] = DDT.SanitizeSizes(theme, saved)
                            Panel().trackerSize = false
                            Rebuilt()
                        end
                    end)
                if type(Settings.CreateSlider) == "function" and type(Settings.CreateSliderOptions) == "function" then
                    local options = Settings.CreateSliderOptions(spec.min, spec.max, spec.step)
                    if type(MinimalSliderWithSteppersMixin) == "table"
                            and type(options.SetLabelFormatter) == "function" then
                        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, spec.key == "textScale"
                            and function(value) return string.format("%d%%", value) end or DDT.WholeLabel)
                    end
                    Nest(ShowFor(OnlyWhenOurs(DefaultTick(Settings.CreateSlider(category, setting, options,
                        (SIZE_TIPS[spec.key] or ("This panel's " .. label:lower() .. " in the " .. look .. " look."))
                            .. " A change in combat applies when combat ends."), spec), "dots"), ThisLook), master, On)
                end
            end
            local positions = {}
            for _, position in ipairs(DDT.NAME_POSITIONS[theme]) do
                positions[#positions + 1] = {position, NAME_POSITION_LABELS[position]}
            end
            Nest(ShowFor(OnlyWhenOurs(Choice(category, id .. theme:upper() .. "_NAMEPOSITION", "Name position", Sizes,
                "namePosition", DDT.DEFAULT_NAME_POSITION[theme], positions,
                "Where the mob's name sits in this panel's rows.", Rebuilt), "dots"), ThisLook), master, On)
        end
        local function PanelColors() return DDT.db.dots.panelColors end
        local function PanelOpacity() return DDT.db.dots.panelOpacity end
        Nest(OnlyWhenOurs(Swatch(category, "DDT_DOTS_PANEL_COLOR_" .. key:upper(), "Panel color", PanelColors, key,
            DDT.PANEL_COLORS[key], key == "list"
                and "The row border and health fill of the other mobs' rows. It changes at once, also in combat."
                or "The outline and health fill of the " .. name .. " panel. It changes at once, also in combat.",
            Changed), "dots"), master, On)
        Nest(OnlyWhenOurs(Slider(category, "DDT_DOTS_PANEL_OPACITY_" .. key:upper(), "Panel opacity", PanelOpacity,
            key, 100, 10, 100, "How solid the " .. name .. " panel is, rows and all, in percent. It changes at once; "
                .. "its bars follow when combat ends.", DDT.RefreshPanelOpacity), "dots"), master, On)
        Button(layout, name .. " panel", "Reset " .. name .. " panel", function()
            DDT.ResetPanel(key)
        end, "This panel back to the defaults: shown, no health, its frame and outline, its size, color, and "
            .. "opacity. Its place stays.")
    end
end

local function DotsPage(parent)
    local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, "DoTs")
    DDT.dotsCategory = category
    if not Status(layout, "dots", NO_DOTS) then
        FrostSection(category, layout)
        ChillSection(category, layout)
        BrandSection(category, layout)
        return
    end
    local function Changed() DDT.RefreshDots(false) end
    local function Rebuilt() DDT.RefreshDots(true) end
    local master = OnlyWhenOurs(Flag(category, "DDT_DOTS", "Enable", Dots, "enabled", true,
        "A row for your target, one for your focus, and up to eight more for the other mobs you DoT, each with "
            .. "a timer bar per DoT.", Changed), "dots")
    local function On() return DDT.db.dots.enabled end
    -- Per-panel settings (TRACKER_PANEL_OPTIONS): the size, health, frame,
    -- outline, switch, and grow rows move into each panel's sub-section.
    -- With an older Toolkit the tracker-wide rows stay as they were.
    local perPanel = DDT.PerPanel()
    Nest(OnlyWhenOurs(Choice(category, "DDT_DOTS_THEME", "Theme", Dots, "theme", "bars", THEMES,
        "Compact: a row with the name and an icon per DoT. Bars: the name above one bar per DoT.", Rebuilt), "dots"),
        master, On)
    if not perPanel then
    Nest(OnlyWhenOurs(TrackerSize(category, "Bars: the length of the DoT bars. Compact: the size of the DoT "
        .. "icons. From 75% to 125%; one setting for both looks. A change in combat applies when combat ends.",
        Rebuilt), "dots"), master, On)
    -- Each look's own sizes and name place (WTF's, moved here). A change here
    -- sets the sizes one by one: Tracker size then shows the nearest percent.
    for _, theme in ipairs({"compact", "bars"}) do
        local function ThisLook() return DDT.db.dots.theme == theme end
        local function Sizes() return DDT.db.dots.sizes[theme] end
        local look = theme == "bars" and "Bars" or "Compact"
        for _, spec in ipairs(DDT.SIZE_SPECS[theme]) do
            local label = SIZE_LABELS[spec.key]
            local setting = Settings.RegisterProxySetting(category, "DDT_DOTS_" .. theme:upper() .. "_"
                .. spec.key:upper(), Settings.VarType.Number, label, spec.default,
                function() return Sizes()[spec.key] end,
                function(value)
                    if type(value) == "number" then
                        local saved = {}
                        for name, current in pairs(Sizes()) do
                            saved[name] = current
                        end
                        saved[spec.key] = value
                        DDT.db.dots.sizes[theme] = DDT.SanitizeSizes(theme, saved)
                        DDT.db.dots.trackerSize = false
                        Rebuilt()
                    end
                end)
            if type(Settings.CreateSlider) == "function" and type(Settings.CreateSliderOptions) == "function" then
                local options = Settings.CreateSliderOptions(spec.min, spec.max, spec.step)
                if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
                    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, spec.key == "textScale"
                        and function(value) return string.format("%d%%", value) end or DDT.WholeLabel)
                end
                Nest(ShowFor(OnlyWhenOurs(DefaultTick(Settings.CreateSlider(category, setting, options,
                    (SIZE_TIPS[spec.key] or ("The DoT tracker's " .. label:lower() .. " in the " .. look .. " look."))
                        .. " A change in combat applies when combat ends."), spec), "dots"), ThisLook), master, On)
            end
        end
        local positions = {}
        for _, key in ipairs(DDT.NAME_POSITIONS[theme]) do
            positions[#positions + 1] = {key, NAME_POSITION_LABELS[key]}
        end
        Nest(ShowFor(OnlyWhenOurs(Choice(category, "DDT_DOTS_" .. theme:upper() .. "_NAMEPOSITION", "Name position",
            Sizes, "namePosition", DDT.DEFAULT_NAME_POSITION[theme], positions,
            "Where the mob's name sits in each row.", Rebuilt), "dots"), ThisLook), master, On)
    end
    Button(layout, "Tracker size", "Reset size", function()
        local dots = DDT.db.dots
        dots.sizes[dots.theme] = DDT.SanitizeSizes(dots.theme, nil)
        dots.trackerSize = false
        Rebuilt()
    end, "Back to the chosen look's own sizes and name position.")
    end
    -- Hide empty DoT slots (treadpool, a player, 2026-11-17: "Would be cleaner
    -- if it only showed the DoTs that are actively ticking"; John: "Yes, build
    -- it"): only with a Toolkit that has it (TRACKER_HIDE_EMPTY).
    if DDT.toolkit and DDT.toolkit.TRACKER_HIDE_EMPTY == true then
        Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_HIDE_EMPTY", "Hide empty DoT slots", Dots, "hideEmpty", false,
            "Show a DoT only while it is on the mob. The empty places stay, so the DoTs do not move. The target "
                .. "and focus rows then do not recast a DoT when you click them.", Rebuilt), "dots"), master, On)
    end
    if not perPanel then
    -- Show or hide each panel (a player, 2026-11-19: "Is there a way to
    -- disable the target dot window or hide it?"; John: "a 3 panels toggle
    -- show/off, default to show. A checkbox is fine for now."): only with a
    -- Toolkit that has it (TRACKER_PANELS). The tracker reads it live.
    if DDT.toolkit and type(DDT.toolkit.TRACKER_PANELS) == "table" then
        local function Show() return DDT.db.dots.show end
        for _, panel in ipairs({{"target", "Target"}, {"focus", "Focus"}, {"list", "Others"}}) do
            Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_SHOW_" .. panel[1]:upper(), "Show " .. panel[2] .. " panel",
                Show, panel[1], true, panel[1] == "list"
                    and "The panel for the other mobs you DoT. Your target and focus stay out of it."
                    or "The panel for your " .. panel[1] .. "'s DoTs.", Changed), "dots"), master, On)
        end
    end
    -- GitHub issue 1 (a player, 2026-11-20: "When a target is selected, a
    -- frame appears with a purple border. I'd like to hide all of that and only
    -- show the debuff bars."; John: "Build parts 1 and 2"). The frame: only
    -- with a Toolkit that has it (TRACKER_FRAME). The outline: TRACKER_OUTLINE.
    if DDT.toolkit and DDT.toolkit.TRACKER_FRAME == true then
        Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_FRAME", "Show panel frame", Dots, "frame", true,
            "The background and border behind each mob's name and DoTs. Turn it off to see only the name and the "
                .. "DoTs. Applies at once, also in combat.", Changed), "dots"), master, On)
    end
    if DDT.toolkit and type(DDT.toolkit.TRACKER_OUTLINE) == "table" then
        local outline = DDT.OUTLINE_WIDTH
        Nest(OnlyWhenOurs(Slider(category, "DDT_DOTS_OUTLINE", "Outline width", Dots, "outlineWidth",
            outline.default, outline.min, outline.max, "The colored outline around the Target and Focus panels, "
                .. "in pixels: " .. outline.min .. " to " .. outline.max .. ". 0 draws none. A change in combat "
                .. "applies when combat ends.", Rebuilt), "dots"), master, On)
    end
    -- Grow direction per panel: only with a Toolkit that has it (TRACKER_GROW).
    if DDT.toolkit and type(DDT.toolkit.TRACKER_GROW) == "table" then
        local function Grow() return DDT.db.dots.grow end
        for _, panel in ipairs({{"target", "Target"}, {"focus", "Focus"}, {"list", "Others"}}) do
            Nest(OnlyWhenOurs(Choice(category, "DDT_DOTS_GROW_" .. panel[1]:upper(), "Grow: " .. panel[2], Grow,
                panel[1], "down", GROW_CHOICES, "Up puts the first DoT where you placed the panel and the next "
                    .. "ones above it (Bars look). Down puts them below it." .. (panel[1] == "list"
                    and " Up also stacks new mobs upward, in both looks." or "")
                    .. " The name keeps its place.", Rebuilt), "dots"), master, On)
        end
    end
    local health = Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_HEALTH", "Show mob health", Dots, "health", false,
        "The line with the mob's name is its health bar, with the damage to come drawn on it.", Rebuilt), "dots"),
        master, On)
    Nest(OnlyWhenOurs(Choice(category, "DDT_DOTS_HEALTH_TEXT", "Health text", Dots, "healthText", "none",
        HEALTH_TEXTS, "Text after the mob's name.", Rebuilt), "dots"), health,
        function() return DDT.db.dots.enabled and DDT.db.dots.health end)
    end
    local plates = Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_PLATES", "Show DoT dots on nameplates", Dots,
        "plateDots", false, "In combat, a dot above each enemy nameplate for each of your DoTs, colored while it "
            .. "is up.", Changed), "dots"), master, On)
    local function PlatesOn() return DDT.db.dots.enabled and DDT.db.dots.plateDots end
    Nest(OnlyWhenOurs(Slider(category, "DDT_DOTS_PLATES_OFFSET", "Dot height above nameplates", Dots,
        "plateDotsOffset", 50, 0, 120, "How far above the nameplate the dots sit, to clear other nameplate "
            .. "AddOns.", Changed), "dots"), plates, PlatesOn)
    Nest(OnlyWhenOurs(Slider(category, "DDT_DOTS_PLATES_OPACITY", "Nameplate dot opacity", Dots, "plateDotsOpacity",
        100, 10, 100, "How solid the dots above each nameplate are, in percent. It changes at once, also in combat.",
        DDT.RefreshPlateDotsOpacity), "dots"), plates, PlatesOn)
    if perPanel then
        PanelSections(category, layout, master, On, Changed, Rebuilt)
    else
    -- Each panel's color and opacity (WTF's, moved here).
    Heading(layout, "Panels")
    local function PanelColors() return DDT.db.dots.panelColors end
    local function PanelOpacity() return DDT.db.dots.panelOpacity end
    for _, panel in ipairs(PANEL_NAMES) do
        local key, name = panel[1], panel[2]
        Nest(OnlyWhenOurs(Swatch(category, "DDT_DOTS_PANEL_COLOR_" .. key:upper(), name .. " panel color",
            PanelColors, key, DDT.PANEL_COLORS[key], key == "list"
                and "The row border and health fill of the other mobs' rows. It changes at once, also in combat."
                or "The outline and health fill of the " .. name .. " panel. It changes at once, also in combat.",
            Changed), "dots"), master, On)
        Nest(OnlyWhenOurs(Slider(category, "DDT_DOTS_PANEL_OPACITY_" .. key:upper(), name .. " panel opacity",
            PanelOpacity, key, 100, 10, 100, "How solid the " .. name .. " panel is, rows and all, in percent. It "
                .. "changes at once; its bars follow when combat ends.", DDT.RefreshPanelOpacity), "dots"),
            master, On)
    end
    end
    -- Each DoT's place, color, and nameplate dot (WTF's DoTs page, moved here).
    local slots = DDT.classData.dots or {}
    if #slots > 0 then
        Heading(layout, "Each DoT")
        local choices = {}
        for _, slot in ipairs(slots) do
            choices[#choices + 1] = {slot.key, slot.label}
        end
        for index = 1, #slots do
            -- A slot picked here swaps places with the one that was there.
            local setting = Settings.RegisterProxySetting(category, "DDT_DOTS_ORDER_" .. index,
                Settings.VarType.String, "DoT " .. index, slots[index].key,
                function() return DDT.db.dots.order[index] end,
                function(value)
                    local order = DDT.db.dots.order
                    for other, key in ipairs(order) do
                        if key == value and other ~= index then
                            order[other], order[index] = order[index], value
                            break
                        end
                    end
                    Rebuilt()
                end)
            if type(Settings.CreateDropdown) == "function"
                    and type(Settings.CreateControlTextContainer) == "function" then
                Nest(OnlyWhenOurs(Settings.CreateDropdown(category, setting, function()
                    local container = Settings.CreateControlTextContainer()
                    for _, choice in ipairs(choices) do
                        container:Add(choice[1], choice[2])
                    end
                    return container:GetData()
                end, "The DoT in place " .. index .. " on each row. Pick another and the two swap places. A "
                    .. "change in combat applies when combat ends."), "dots"), master, On)
            end
        end
        local function Colors() return DDT.db.dots.colors end
        local function OnPlates() return DDT.db.dots.onPlates end
        for _, slot in ipairs(slots) do
            Nest(OnlyWhenOurs(Swatch(category, "DDT_DOTS_COLOR_" .. slot.key:upper(), slot.label .. " color",
                Colors, slot.key, DDT.SanitizeColor(slot.color, "ffffffff"), "The color of " .. slot.label
                    .. " on the tracker's bars and on nameplate dots. A change in combat reaches the bars when "
                    .. "combat ends.", DDT.RefreshDotColors), "dots"), master, On)
            Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_ONPLATE_" .. slot.key:upper(), slot.label
                .. " dot on nameplates", OnPlates, slot.key, slot.dot ~= false, "Show a " .. slot.label
                    .. " dot in the nameplate bubble.", Changed), "dots"), plates, PlatesOn)
        end
        Button(layout, "Each DoT", "Reset order and colors", function()
            local dots = DDT.db.dots
            local clean = DDT.SanitizeDB({}, DDT.classData).dots
            dots.order, dots.colors = clean.order, clean.colors
            DDT.RefreshDotColors()
        end, "Back to the DoTs' own order and colors.")
    end
    -- The Warlock's smart curse (WTF's, moved here; Toolkit 2.7.0).
    if DDT.class == "WARLOCK" and DDT.dotTracker and type(DDT.dotTracker.ApplySmartCurse) == "function" then
        Heading(layout, "Curse slot")
        local mode = Nest(OnlyWhenOurs(Choice(category, "DDT_DOTS_CURSE_MODE", "Curse slot click", Dots,
            "curseMode", "last", CURSE_MODES, "What a click on the target or focus row's Curse slot casts. Last "
                .. "used: the curse you cast last. " .. SMART_CURSE_HELP .. " A change in combat applies when "
                .. "combat ends.", DDT.ApplySmartCurse), "dots"), master, On)
        Nest(OnlyWhenOurs(Flag(category, "DDT_DOTS_CURSE_MARKER", "Show the smart curse letter", Dots,
            "curseMarker", true, "With Smart curse, a letter on the Curse slot's icon for that mob's best curse: "
                .. "T Tongues, E Elements, W Weakness. It changes also in combat.", DDT.ApplySmartCurse), "dots"),
            mode, function() return DDT.db.dots.enabled and DDT.db.dots.curseMode == "smart" end)
    end
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
        Nest(OnlyWhenOurs(Choice(category, "DDT_PREDICT_FILL", "Block fill", Predict, "fill", "stripes", FILLS,
            "Stripes: diagonal stripes. Solid: one flat color. Bar texture: the texture of the bar it sits on. The "
                .. "same look on the target frame, nameplates, and DoT tracker rows.", Changed), "dots"),
            predict, PredictOn)
        Nest(OnlyWhenOurs(Choice(category, "DDT_PREDICT_COLOR", "Block color", Predict, "color", "purple", colors,
            "The block's color.", Changed), "dots"), predict, PredictOn)
        Nest(OnlyWhenOurs(Slider(category, "DDT_PREDICT_OPACITY", "Block opacity", Predict, "opacity", 70, 20, 100,
            "How solid the block is, in percent.", Changed), "dots"), predict, PredictOn)
        Nest(OnlyWhenOurs(Choice(category, "DDT_PREDICT_OUTLINE", "Block outline", Predict, "outline", "solid",
            OUTLINES, "A thin line around the block, a little lighter than its color.", Changed), "dots"),
            predict, PredictOn)
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
    FrostSection(category, layout)
    ChillSection(category, layout)
    BrandSection(category, layout)
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
