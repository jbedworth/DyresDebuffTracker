local addonName, DDT = ...

-- Frozen and chilled arcs above enemy nameplates, for Mages (John,
-- 2026-11-18: "knowing which mobs are frozen or chilled (for shatter to
-- work) ... a frozen/icy arc above the chilled and frozen mobs nameplates (2
-- different looking visuals, I think a mob can be both frozen and chilled)").
-- Frozen: Shatter works now. Chilled: your Chill can proc Frostbite and
-- Fingers of Frost on it. A mob that is both shows both, Frozen above.
--
-- On Forever, target auras are secret to AddOn code in combat, so nothing
-- here reads them: each plate gets an aura container (Dyre's Toolkit's
-- CreateAuraContainer: the game's engine on Forever, plain Lua on Classic
-- Era) with one HARMFUL slot per look. The engine decides which arc shows;
-- the arcs are the slots' own buttons, set up only in initializeFrame. This
-- follows the Toolkit's PlateDots.lua: a pool of holders, one per plate,
-- parented to the plate on NAME_PLATE_UNIT_ADDED (also in combat) and given
-- back on NAME_PLATE_UNIT_REMOVED. Holders are made ahead, out of combat;
-- only when the pool runs dry in combat is one made then, as PlateDots does.
-- Each holder sits on the bar the Toolkit's FindPlateBar finds (Plater,
-- Threat Plates, and the others, as DIES does), else on the plate.
-- Events only: no OnUpdate, no polling.
-- The same builder draws the Warlock's Demonic Brand pentagram and the
-- Mage's Winter's Chill arc (below).

-- The debuffs, from local sources only (never guessed):
--   TFB  TalentsForeverBook's Data.lua (Forever beta build 1.60.1.70755,
--        2026-11-15), in the _forever_ AddOns folder: the spell ranks.
--   LCD  LibClassicDurations' classAbilities.lua (in ShadowedUnitFrames and
--        PallyPower, _classic_era_ AddOns folder): the debuff IDs.
-- Not here, for want of a local source (TESTING.md asks for them in the
-- client): the Water Elemental's Freeze (no Forever or Era data has it) and
-- a Frostfire Bolt chill (TFB has the bolt, 401502/1237312/1237313, but no
-- source says it slows; the Toolkit's ClassData marks its debuff UNCHECKED).
DDT.FROST_SPELLS = {
    -- Any Mage's freeze: Shatter works on every Frozen target, whoever froze it.
    frozen = {filter = "HARMFUL", ids = {
        122, 865, 6131, 10230, -- Frost Nova, 4 ranks (TFB; LCD)
        12494, -- Frostbite's freeze (LCD; TFB: Frostbite 11071 "Gives your Chill effects a chance to Freeze")
    }},
    -- Only your own chills: Frostbite and Fingers of Frost proc from "your
    -- Chill effects" (TFB), so another Mage's chill gives you nothing.
    chilled = {filter = "HARMFUL|PLAYER", ids = {
        116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304, -- Frostbolt, 11 ranks (TFB; LCD)
        120, 8492, 10159, 10160, 10161, -- Cone of Cold, 5 ranks (TFB; LCD)
        12484, 12485, 12486, -- Improved Blizzard's Chilled (LCD; TFB: Improved Blizzard 11185 "Adds a Chill effect")
    }},
    -- Frost Armor's and Ice Armor's Chilled (LCD), drawn with the chilled
    -- arc. Its own slot with no PLAYER: in client on Forever (John,
    -- 2026-11-19) a mob had Chilled 6136 and no arc showed in the PLAYER
    -- slot, while the frozen slot (no PLAYER) worked. The game seems not to
    -- count you as this chill's source. The cost: another Mage's armor chill
    -- on a mob that hits them shows the arc too.
    chilledArmor = {filter = "HARMFUL", ids = {6136, 7321}},
}
-- Frozen above chilled (frozen is drawn last, over it); both chilled slots
-- draw the same arc in the same place.
DDT.FROST_ORDER = {"chilled", "chilledArmor", "frozen"}
-- The arcs' height above the plate's health bar, in pixels, and their size, in percent.
DDT.FROST_OFFSET = {min = 0, max = 60, default = 10}
DDT.FROST_SIZE = {min = 50, max = 200, default = 100}

local TEXTURES = "Interface\\AddOns\\" .. addonName .. "\\Textures\\"
local ART = {frozen = TEXTURES .. "FrozenArc", chilled = TEXTURES .. "ChilledArc",
    chilledArmor = TEXTURES .. "ChilledArc"}
-- Textures/*.tga are 256 x 64, drawn here at a quarter size (scripts/make_artwork.py).
local ARC_WIDTH, ARC_HEIGHT = 64, 16
-- Frozen's arc sits this far above Chilled's, so both show.
local FROZEN_RAISE = 7
local MAX_NAMEPLATE_UNITS = 40
-- Holders made ahead, out of combat.
DDT.FROST_PREWARM = 10

-- Demonic Brand, for Warlocks (John, via the lead, 2026-11-21: "Demonic Brand
-- (for Demonology Warlocks): we need to add it. It's a debuff on your current
-- target, but it should render like the frost/frozen debuff indicators";
-- then, the same day: "Make it a glowing red pentagram that renders above
-- the nameplate, and make it so the size and height can be adjusted").
-- A Forever talent (Demonology, 3 ranks, added in 1.60.1): your Searing Pain
-- brands the target for 10 sec, and your pet's next 2/4/6 attacks on it deal
-- extra Fire or Shadow damage. Any Warlock can take the talent, so every
-- Warlock gets the pentagram; talents are never read. Sources (web, 2026-11-21; not
-- yet checked in the client, TESTING.md asks for a /dump):
--   Wowhead spell=1293696 "Demonic Brand": the debuff, 10 sec, Magic, flags
--        "Aura Points On Client" and "Nameplate Personal Buffs/Debuffs".
--   Wowhead spell=1293695: the hidden talent passive; "Modifies Charges" of
--        1293696 (rank 1/2/3: 2/4/6) and the threat of Searing Pain.
--   warcraft.wiki.gg Demonic_Brand: Tier 4 Demonology, 3 ranks, 10 sec.
--   warcraftmaps.com spell/1293695: client build 1.60.1.70938.
-- Only your own Brand: only your pet's attacks use it, so the slot has PLAYER
-- (Searing Pain is your cast, so the game should name you its source).
DDT.BRAND_SPELLS = {
    brand = {filter = "HARMFUL|PLAYER", ids = {1293696}},
}
DDT.BRAND_ORDER = {"brand"}
-- The client knows the debuff only on Forever; elsewhere no pentagram and no rows.
DDT.BRAND_SPELL = 1293696
-- Height: pixels from the plate's bar to the halo's bottom (the star sits
-- 10 more above it, clear of the plate's name). Size: percent of a 28-pixel
-- star in a 48-pixel halo.
DDT.BRAND_OFFSET = {min = 0, max = 60, default = 10}
DDT.BRAND_SIZE = {min = 50, max = 200, default = 100}

-- Winter's Chill, for Mages (John, 2026-11-22: "add a similar halo above the
-- nameplate (we do for chilled/frozen) with up to 5 cells (one per charge)
-- (like a rogue/druid combo-point counter)"; then the same day: "I'm thinking
-- blue frostballs that turn white as the stack builds"). A Frost talent: your Frost
-- spells may put Winter's Chill on the target, up to 5 stacks. Sources (web,
-- 2026-11-22; not yet checked in the client, TESTING.md asks for a /dump):
--   Wowhead forever/spell=11180: the talent; its proc triggers spell 12579.
--   Wowhead forever/spell=12579: the debuff, 15 sec, Magic, flags "DoT
--        Stacking Rule" and "Nameplate Personal Buffs/Debuffs"; more damage
--        taken from the caster's Cone of Cold (Forever).
--   Wowhead classic/spell=12579: the same ID on Classic Era, 15 sec, 2% more
--        critical strike chance against the target per stack.
--   warcraft.wiki.gg Winter's_Chill: 5 stacks, on both clients.
-- Only your own: on Forever it helps only your Cone of Cold, and "DoT
-- Stacking Rule" gives each Mage a debuff of their own. (On Classic Era any
-- Mage's Winter's Chill helps you; the slot still shows only yours.)
DDT.CHILL_SPELLS = {
    chill = {filter = "HARMFUL|PLAYER", ids = {12579}},
}
DDT.CHILL_ORDER = {"chill"}
DDT.CHILL_SPELL = 12579
DDT.CHILL_MOST = 5
-- Height: pixels from the plate's bar to the arc's 64 x 16 box; the default
-- stays 36 (John, 2026-11-23: "Keep the default at 36"), clear of the frozen
-- arc at the defaults (TESTING.md has the measured gap). Size: percent.
DDT.CHILL_OFFSET = {min = 0, max = 60, default = 36}
DDT.CHILL_SIZE = {min = 50, max = 200, default = 100}
-- One segment's cell, in pixels at 100%: a fifth of the 64-pixel arc.
DDT.CHILL_CELL = 64 / 5
-- The game tints the near-white art: blue while empty, white while lit.
DDT.CHILL_COLORS = {empty = {0.25, 0.5, 1, 0.9}, lit = {1, 1, 1, 1}}
-- The stacks the preview shows: some segments lit, some empty.
DDT.CHILL_PREVIEW = 3

-- A set, not a list: the engine matches nothing with a list (the Toolkit's
-- Procs.lua, from DSU's Shield.lua, found in client).
local function Set(list)
    local set = {}
    for _, id in ipairs(list) do
        set[id] = true
    end
    return set
end

-- The Mage's arcs: 256 x 64 art at a quarter size, Frozen raised above Chilled.
local FROST_LOOK = {width = ARC_WIDTH, height = ARC_HEIGHT + FROZEN_RAISE,
    Draw = function(button, holder, key)
        button:SetPoint("BOTTOM", holder, "BOTTOM", 0, key == "frozen" and FROZEN_RAISE or 0)
        button:SetSize(ARC_WIDTH, ARC_HEIGHT)
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(ART[key])
        texture:SetAllPoints(button)
    end}

-- The Brand's pentagram (John, 2026-11-21: "a glowing red pentagram that
-- renders above the nameplate"): a soft red halo behind a red five-point
-- star in a circle (Textures/BrandGlow.tga and BrandPentagram.tga, 128 x
-- 128, scripts/make_artwork.py --brand). The halo pulses with an
-- AnimationGroup (alpha, bouncing): the client runs it, no OnUpdate. It
-- plays only while the engine shows the button.
DDT.BRAND_STAR, DDT.BRAND_GLOW = 28, 48
DDT.BRAND_PULSE = {from = 0.45, to = 1, seconds = 0.9}
local BRAND_LOOK = {width = DDT.BRAND_GLOW, height = DDT.BRAND_GLOW,
    Draw = function(button, holder)
        button:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)
        button:SetSize(DDT.BRAND_GLOW, DDT.BRAND_GLOW)
        local glow = button:CreateTexture(nil, "BACKGROUND")
        glow:SetTexture(TEXTURES .. "BrandGlow")
        glow:SetBlendMode("ADD")
        glow:SetAllPoints(button)
        local star = button:CreateTexture(nil, "ARTWORK")
        star:SetTexture(TEXTURES .. "BrandPentagram")
        star:SetPoint("CENTER", button, "CENTER", 0, 0)
        star:SetSize(DDT.BRAND_STAR, DDT.BRAND_STAR)
        if type(glow.CreateAnimationGroup) == "function" then
            local pulse = glow:CreateAnimationGroup()
            local fade = pulse and pulse:CreateAnimation("Alpha")
            if fade then
                fade:SetFromAlpha(DDT.BRAND_PULSE.from)
                fade:SetToAlpha(DDT.BRAND_PULSE.to)
                fade:SetDuration(DDT.BRAND_PULSE.seconds)
                fade:SetSmoothing("IN_OUT")
                pulse:SetLooping("BOUNCE")
                pulse:Play()
            end
            holder.pulse = pulse
        end
    end}

-- Winter's Chill stacks, one segment of an ice arc per stack (John,
-- 2026-11-23, via the lead: "a 5 part ice-arc above the mob's head, similar
-- to the effects we do for chilled and frozen, a little higher up, and
-- segmented into 5 parts instead of discreet balls"; before: "blue
-- frostballs that turn white as the stack builds"). The arc is 64 x 16 at
-- 100%, as the frozen and chilled arcs, on their curve; each segment is one
-- 12.8-pixel fifth (DDT.CHILL_CELL) of it, and no segment's art comes within
-- 0.75 pixels of a fifth's edge (scripts/make_artwork.py CHILL_CLEAR), so a
-- crop at that edge cuts no other segment. AddOn code cannot
-- read the stack count in combat on Forever, so the game lights the segments:
-- the engine's SetApplicationBar(bar, {minApplications, maxApplications})
-- sets the bar's range to them, its value to the stacks, and shows it from
-- minApplications up (Blizzard_CustomAuraButton.lua ApplyApplicationBar;
-- options in AuraContainerUtilDocumentation.lua; Gethe wow-ui-source
-- 943764493e6b). The Toolkit's plain-Lua container (Classic Era) does the
-- same. The whole arc in blue (Textures/ChillArc.tga, tinted); segment 1 is
-- white (the same art, its first fifth) whenever the debuff shows, so a
-- stack count of 0 or 1 for one stack both read as one. The bar covers
-- segments 2 to 5 (range 1 to 5); its fill is Textures/ChillArcFill.tga,
-- segments 2 to 5 drawn across the whole texture, which the game crops as
-- the bar fills, and each stack's fill ends between two segments, so whole
-- segments turn white. A client without SetApplicationBar (or a call that
-- fails) shows segment 1 only.
local CHILL_ARC, CHILL_FILL = TEXTURES .. "ChillArc", TEXTURES .. "ChillArcFill"
local CHILL_LOOK = {width = ARC_WIDTH, height = ARC_HEIGHT,
    Draw = function(button, holder, _, preview)
        local cell, colors = DDT.CHILL_CELL, DDT.CHILL_COLORS
        button:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)
        button:SetSize(ARC_WIDTH, ARC_HEIGHT)
        -- The whole arc, blue: the empty segments.
        local empty = button:CreateTexture(nil, "BORDER")
        empty:SetTexture(CHILL_ARC)
        empty:SetVertexColor(unpack(colors.empty))
        empty:SetAllPoints(button)
        -- Segment 1, white: the first fifth of the same art.
        local first = button:CreateTexture(nil, "ARTWORK")
        first:SetTexture(CHILL_ARC)
        first:SetTexCoord(0, 1 / DDT.CHILL_MOST, 0, 1)
        first:SetVertexColor(unpack(colors.lit))
        first:SetSize(cell, ARC_HEIGHT)
        first:SetPoint("LEFT", button, "LEFT", 0, 0)
        local bar = CreateFrame("StatusBar", nil, button)
        bar:SetPoint("LEFT", button, "LEFT", cell, 0)
        bar:SetSize((DDT.CHILL_MOST - 1) * cell, ARC_HEIGHT)
        bar:EnableMouse(false)
        bar:SetStatusBarTexture(CHILL_FILL)
        bar:SetStatusBarColor(unpack(colors.lit))
        bar:SetMinMaxValues(1, DDT.CHILL_MOST)
        bar:SetValue(1)
        holder.bar = bar
        if preview then
            bar:SetValue(DDT.CHILL_PREVIEW)
        elseif not (type(button.SetApplicationBar) == "function" and pcall(button.SetApplicationBar, button, bar,
                {minApplications = 1, maxApplications = DDT.CHILL_MOST})) then
            bar:Hide()
        end
    end}

-- toolkit: Dyre's Toolkit; store: function() -> the settings ({enabled,
-- offset, size}), read live; spec: {spells, order, offset, size, look}.
-- Returns the arcs, else nil and what the client or Toolkit lacks.
local function CreateArcs(toolkit, store, spec)
    if type(toolkit) ~= "table" or type(toolkit.CreateAuraContainer) ~= "function"
            or type(toolkit.AuraEngineKind) ~= "function" or not toolkit.AuraEngineKind() then
        return nil, type(toolkit) == "table" and toolkit.AURA_ENGINE_MISSING or "Dyre's Toolkit"
    end
    if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
        return nil, "C_NamePlate.GetNamePlateForUnit"
    end
    local arcs = {free = {}, byUnit = {}, all = {}}
    local events = CreateFrame("Frame")
    local sets = {}
    for _, key in ipairs(spec.order) do
        sets[key] = Set(spec.spells[key].ids)
    end

    -- Places the engine's button; the only time it may be touched.
    local function ArcInitializer(holder, key)
        return function(button)
            button:ClearAllPoints()
            button:SetMouseClickEnabled(false)
            button:SetMouseMotionEnabled(false)
            spec.look.Draw(button, holder, key)
            holder.arcs[key] = button
        end
    end

    local function CreateHolder()
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(spec.look.width, spec.look.height)
        holder:EnableMouse(false)
        holder.arcs = {}
        local container = toolkit.CreateAuraContainer(holder)
        container:SetPoint("TOPLEFT")
        container:SetSize(1, 1)
        for _, key in ipairs(spec.order) do
            container:AddAuraSlot(key, spec.spells[key].filter, {
                candidateFilters = {includeSpellIDs = sets[key]},
                initializeFrame = ArcInitializer(holder, key),
            })
        end
        holder.container = container
        arcs.all[#arcs.all + 1] = holder
        holder:Hide()
        return holder
    end

    -- spec.gate: an extra condition (the Winter's Chill talent); the preview ignores it.
    local function On()
        local settings = store()
        return type(settings) == "table" and settings.enabled ~= false and (spec.gate == nil or spec.gate())
    end

    local function IsHostile(unit)
        local canAttack = UnitCanAttack("player", unit)
        return not toolkit.IsSecret(canAttack) and canAttack == true
    end

    -- On the bar showing the plate's health (a plate AddOn's, else Blizzard's), else on the plate.
    local function Place(holder, plate, unit)
        local settings = store()
        local bar, info
        if type(toolkit.FindPlateBar) == "function" then
            bar, info = toolkit.FindPlateBar(unit)
        end
        holder.on = bar and (type(info) == "table" and info.name or "bar") or "plate"
        local scale = (settings.size or spec.size.default) / 100
        holder:SetScale(scale)
        holder:ClearAllPoints()
        -- The offset is in the holder's own scale: divided, it stays in pixels at every size.
        holder:SetPoint("BOTTOM", bar or plate, "TOP", 0, (settings.offset or spec.offset.default) / scale)
    end

    local function Detach(unit)
        local holder = arcs.byUnit[unit]
        if not holder then
            return
        end
        arcs.byUnit[unit] = nil
        holder.container:SetUnit("none")
        holder.unit = nil
        holder:Hide()
        holder:SetParent(UIParent)
        arcs.free[#arcs.free + 1] = holder
    end

    local function Attach(unit)
        if not On() then
            return
        end
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if not plate or plate:IsForbidden() then
            return
        end
        Detach(unit)
        local holder = table.remove(arcs.free) or CreateHolder()
        holder:SetParent(plate)
        Place(holder, plate, unit)
        holder.unit = unit
        arcs.byUnit[unit] = holder
        holder.container:SetUnit(unit)
        holder.container:UpdateAllAuras()
        holder:SetShown(IsHostile(unit))
    end

    -- Out of combat: holders made ahead, so a plate in combat seldom makes one.
    function arcs:Prewarm()
        if InCombatLockdown() or not On() then
            return
        end
        local count = #self.free
        for _ in pairs(self.byUnit) do
            count = count + 1
        end
        while count < DDT.FROST_PREWARM do
            self.free[#self.free + 1] = CreateHolder()
            count = count + 1
        end
    end

    -- A preview, to tune Size and Height with no debuff (John's Warlock
    -- cannot apply Demonic Brand; the lead, 2026-11-21): our own copy of the
    -- look on the target's plate, never an engine button, so nothing is
    -- protected and it works for a Warlock without the talent. Not saved;
    -- it ends on a second press, a new target, the plate going, or logout.
    -- It shows also while "Show" is off: it is for tuning.
    local preview
    local function PreviewFrame()
        if not preview then
            preview = CreateFrame("Frame", nil, UIParent)
            preview:SetSize(spec.look.width, spec.look.height)
            preview:EnableMouse(false)
            preview.arcs = {}
            for _, key in ipairs(spec.order) do
                local button = CreateFrame("Frame", nil, preview)
                button:EnableMouse(false)
                spec.look.Draw(button, preview, key, true)
                preview.arcs[key] = button
            end
            preview:Hide()
        end
        return preview
    end

    -- True when a preview was showing (now gone).
    function arcs:StopPreview()
        if not (preview and preview.plate) then
            return false
        end
        preview.plate = nil
        preview:Hide()
        preview:ClearAllPoints()
        preview:SetParent(UIParent)
        return true
    end

    -- True when it shows now; false when the target has no nameplate.
    function arcs:StartPreview()
        local plate = C_NamePlate.GetNamePlateForUnit("target")
        if not plate or plate:IsForbidden() then
            return false
        end
        local frame = PreviewFrame()
        frame:SetParent(plate)
        Place(frame, plate, "target")
        frame.plate = plate
        frame:Show()
        return true
    end

    -- "started", "stopped", or "no plate".
    function arcs:TogglePreview()
        if self:StopPreview() then
            return "stopped"
        end
        return self:StartPreview() and "started" or "no plate"
    end

    function arcs:Previewing()
        return preview ~= nil and preview.plate ~= nil, preview
    end

    -- Settings changed (on/off, offset, size): every plate again.
    function arcs:Refresh()
        if preview and preview.plate then
            Place(preview, preview.plate, "target")
        end
        for unit in pairs(self.byUnit) do
            Detach(unit)
        end
        for index = 1, MAX_NAMEPLATE_UNITS do
            local unit = "nameplate" .. index
            if UnitExists(unit) then
                Attach(unit)
            end
        end
        self:Prewarm()
    end

    -- /ddt debug: one line. Reads only our own holders, never an aura or an
    -- engine button (their shown state may be secret). shown: on a mob you can
    -- attack; visible: the plate and its parents show too; anchors: what each
    -- holder sits on (FindPlateBar's adapter, else the plate).
    function arcs:DebugLines()
        local plates, shown, visible, places = 0, 0, 0, {}
        for _, holder in pairs(self.byUnit) do
            plates = plates + 1
            shown = shown + (holder:IsShown() and 1 or 0)
            visible = visible + (holder:IsVisible() and 1 or 0)
            local on = holder.on or "?"
            places[on] = (places[on] or 0) + 1
        end
        local names = {}
        for name, count in pairs(places) do
            names[#names + 1] = name .. "=" .. count
        end
        table.sort(names)
        return {string.format("on=%s engine=%s holders=%d plates=%d shown=%d visible=%d anchors=[%s]",
            tostring(On()), tostring(toolkit.AuraEngineKind()), #self.all, plates, shown, visible,
            table.concat(names, " "))}
    end

    events:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            if not toolkit.IsSecret(unit) then
                Attach(unit)
                -- Again once every AddOn's handler has run: a nameplate AddOn
                -- may only now take the plate over (DotPredict's rule).
                if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                    C_Timer.After(0, function()
                        local holder = arcs.byUnit[unit]
                        local plate = holder and C_NamePlate.GetNamePlateForUnit(unit)
                        if plate and not plate:IsForbidden() then
                            Place(holder, plate, unit)
                        end
                    end)
                end
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if not toolkit.IsSecret(unit) then
                Detach(unit)
                if preview and preview.plate and C_NamePlate.GetNamePlateForUnit(unit) == preview.plate then
                    arcs:StopPreview()
                end
            end
        elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_LOGOUT" then
            arcs:StopPreview()
        elseif event == "UNIT_FLAGS" then
            local holder = not toolkit.IsSecret(unit) and arcs.byUnit[unit]
            if holder then
                holder:SetShown(IsHostile(unit))
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            arcs:Prewarm()
        end
    end)
    for _, event in ipairs({"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_FLAGS",
        "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_LOGOUT"}) do
        events:RegisterEvent(event)
    end
    arcs:Refresh()
    return arcs
end

-- The Mage's frozen and chilled arcs; store: function() -> DDT.db.frost.
function DDT.CreateFrostArcs(toolkit, store)
    return CreateArcs(toolkit, store, {spells = DDT.FROST_SPELLS, order = DDT.FROST_ORDER,
        offset = DDT.FROST_OFFSET, size = DDT.FROST_SIZE, look = FROST_LOOK})
end

-- True when this client knows the spell. A static spell lookup: no aura, no talent.
function DDT.SpellKnown(spellID)
    local name
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        name = C_Spell.GetSpellName(spellID)
    elseif type(GetSpellInfo) == "function" then
        name = GetSpellInfo(spellID)
    end
    return type(name) == "string" and name ~= ""
end

-- True when this client knows the Demonic Brand debuff (Forever).
function DDT.BrandKnown()
    return DDT.SpellKnown(DDT.BRAND_SPELL)
end

-- True when this client knows the Winter's Chill debuff (both clients).
function DDT.ChillKnown()
    return DDT.SpellKnown(DDT.CHILL_SPELL)
end

-- The Winter's Chill talent (John, 2026-11-23, via the lead: "make sure this
-- only shows if the player has the talent for it"). Its ranks, by ID:
--   11180 rank 1: TalentsForeverBook Data.lua (Forever beta build
--         1.60.1.70755), "Winter's Chill", max 5, node 105763, spell 11180;
--         classicdb.ch spell=11180 "Rank 1".
--   28592, 28593, 28594, 28595 ranks 2 to 5: classicdb.ch spell=28592 to
--         28595, "Winter's Chill" "Rank 2" to "Rank 5" (Classic Era).
-- Forever lists only 11180 for all five ranks; a Forever ID not listed here
-- is found by the talent's name (the name of 11180 in this client's language).
DDT.CHILL_TALENTS = {11180, 28592, 28593, 28594, 28595}
-- The events that can change the talent, where the client has them
-- (registered only when valid: a feature test, not a version test).
DDT.CHILL_TALENT_EVENTS = {"SPELLS_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_REGEN_ENABLED"}
local chillTalent = {events = CreateFrame("Frame"), known = nil, pending = false, read = false}

-- Whether this character knows spell id, by the same three APIs and order as
-- Dyre's Toolkit's Procs.lua KnowsTalent (a local there, so not callable).
-- Second result: whether any of the three APIs exists.
local function KnowsSpell(id)
    local any = false
    if type(IsPlayerSpell) == "function" then
        any = true
        if IsPlayerSpell(id) == true then return true, true end
    end
    if type(C_SpellBook) == "table" and type(C_SpellBook.IsSpellKnown) == "function" then
        any = true
        if C_SpellBook.IsSpellKnown(id) == true then return true, true end
    end
    if type(IsSpellKnown) == "function" then
        any = true
        if IsSpellKnown(id) == true then return true, true end
    end
    return false, any
end

-- The spell ID this client gives the talent's name, else nil.
local function TalentIDByName()
    local name
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        name = C_Spell.GetSpellName(DDT.CHILL_TALENTS[1])
    elseif type(GetSpellInfo) == "function" then
        name = GetSpellInfo(DDT.CHILL_TALENTS[1])
    end
    if type(name) ~= "string" or name == "" or DDT.toolkit and DDT.toolkit.IsSecret(name) then
        return nil
    end
    local id
    if type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
        local info = C_Spell.GetSpellInfo(name)
        id = type(info) == "table" and info.spellID or nil
    elseif type(GetSpellInfo) == "function" then
        id = select(7, GetSpellInfo(name))
    end
    -- The debuff has the same name: never count it as the talent.
    if type(id) ~= "number" or id == DDT.CHILL_SPELL then
        return nil
    end
    return id
end

-- true (known), false (not known), or nil (no API to read it).
function DDT.ReadChillTalent()
    local any = false
    for _, id in ipairs(DDT.CHILL_TALENTS) do
        local known, api = KnowsSpell(id)
        if known then return true end
        any = any or api
    end
    if not any then
        return nil
    end
    local id = TalentIDByName()
    if id and KnowsSpell(id) then
        return true
    end
    return false
end

-- Whether the arc and the chime may work: known, or not readable (a broken
-- check never hides them for everyone).
function DDT.ChillTalentKnown()
    return chillTalent.known ~= false
end

-- "known", "not known", or "unreadable", for /ddt debug.
function DDT.ChillTalentText()
    if chillTalent.known == nil then return "unreadable" end
    return chillTalent.known and "known" or "not known"
end

-- Reads the talent out of combat; in combat keeps the last answer and reads
-- it again when combat ends. A change refreshes the arc and the chime.
function DDT.CheckChillTalent()
    if InCombatLockdown() then
        chillTalent.pending = true
        return false
    end
    chillTalent.pending = false
    local known = DDT.ReadChillTalent()
    local changed = not chillTalent.read or known ~= chillTalent.known
    chillTalent.known, chillTalent.read = known, true
    if changed and type(DDT.RefreshChill) == "function" and DDT.db then
        DDT.RefreshChill()
    end
    return changed
end

chillTalent.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not chillTalent.pending then
        return
    end
    DDT.CheckChillTalent()
end)

-- At login, for a Mage, before the arc is made.
function DDT.StartChillTalent()
    for _, event in ipairs(DDT.CHILL_TALENT_EVENTS) do
        local valid = type(C_EventUtils) ~= "table" or type(C_EventUtils.IsEventValid) ~= "function"
            or C_EventUtils.IsEventValid(event) == true
        if valid then
            pcall(chillTalent.events.RegisterEvent, chillTalent.events, event)
        end
    end
    if InCombatLockdown() then
        chillTalent.pending = true
    else
        chillTalent.known, chillTalent.read = DDT.ReadChillTalent(), true
    end
end

-- The Warlock's Demonic Brand pentagram; store: function() -> DDT.db.brand.
function DDT.CreateBrandArcs(toolkit, store)
    if not DDT.BrandKnown() then
        return nil, "Demonic Brand (" .. DDT.BRAND_SPELL .. ")"
    end
    return CreateArcs(toolkit, store, {spells = DDT.BRAND_SPELLS, order = DDT.BRAND_ORDER,
        offset = DDT.BRAND_OFFSET, size = DDT.BRAND_SIZE, look = BRAND_LOOK})
end

-- The Mage's Winter's Chill arc; store: function() -> DDT.db.wintersChill.
function DDT.CreateChillArcs(toolkit, store)
    if not DDT.ChillKnown() then
        return nil, "Winter's Chill (" .. DDT.CHILL_SPELL .. ")"
    end
    return CreateArcs(toolkit, store, {spells = DDT.CHILL_SPELLS, order = DDT.CHILL_ORDER,
        offset = DDT.CHILL_OFFSET, size = DDT.CHILL_SIZE, look = CHILL_LOOK, gate = DDT.ChillTalentKnown})
end
