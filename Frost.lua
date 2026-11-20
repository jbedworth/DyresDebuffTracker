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

-- A set, not a list: the engine matches nothing with a list (the Toolkit's
-- Procs.lua, from DSU's Shield.lua, found in client).
local function Set(list)
    local set = {}
    for _, id in ipairs(list) do
        set[id] = true
    end
    return set
end

-- toolkit: Dyre's Toolkit; store: function() -> DDT.db.frost, read live.
-- Returns the arcs, else nil and what the client or Toolkit lacks.
function DDT.CreateFrostArcs(toolkit, store)
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
    for _, key in ipairs(DDT.FROST_ORDER) do
        sets[key] = Set(DDT.FROST_SPELLS[key].ids)
    end

    -- Places the engine's button; the only time it may be touched.
    local function ArcInitializer(holder, key)
        return function(button)
            button:ClearAllPoints()
            button:SetPoint("BOTTOM", holder, "BOTTOM", 0, key == "frozen" and FROZEN_RAISE or 0)
            button:SetSize(ARC_WIDTH, ARC_HEIGHT)
            button:SetMouseClickEnabled(false)
            button:SetMouseMotionEnabled(false)
            local texture = button:CreateTexture(nil, "ARTWORK")
            texture:SetTexture(ART[key])
            texture:SetAllPoints(button)
            holder.arcs[key] = button
        end
    end

    local function CreateHolder()
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(ARC_WIDTH, ARC_HEIGHT + FROZEN_RAISE)
        holder:EnableMouse(false)
        holder.arcs = {}
        local container = toolkit.CreateAuraContainer(holder)
        container:SetPoint("TOPLEFT")
        container:SetSize(1, 1)
        for _, key in ipairs(DDT.FROST_ORDER) do
            container:AddAuraSlot(key, DDT.FROST_SPELLS[key].filter, {
                candidateFilters = {includeSpellIDs = sets[key]},
                initializeFrame = ArcInitializer(holder, key),
            })
        end
        holder.container = container
        arcs.all[#arcs.all + 1] = holder
        holder:Hide()
        return holder
    end

    local function On()
        local settings = store()
        return type(settings) == "table" and settings.enabled ~= false
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
        local scale = (settings.size or DDT.FROST_SIZE.default) / 100
        holder:SetScale(scale)
        holder:ClearAllPoints()
        -- The offset is in the holder's own scale: divided, it stays in pixels at every size.
        holder:SetPoint("BOTTOM", bar or plate, "TOP", 0, (settings.offset or DDT.FROST_OFFSET.default) / scale)
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

    -- Settings changed (on/off, offset, size): every plate again.
    function arcs:Refresh()
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
            end
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
        "PLAYER_REGEN_ENABLED"}) do
        events:RegisterEvent(event)
    end
    arcs:Refresh()
    return arcs
end
