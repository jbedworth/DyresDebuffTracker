local _, DDT = ...

-- The Mage's Winter's Chill stack chime (John, 2026-11-22, via the lead: "2,
-- remove it, build it right in DDT"). It moves here from Dyre's Buff
-- Reminders 1.9.0 to 1.13.2 (its Procs.lua "Winter's Chill stack chimes"),
-- which 1.13.3 removes: Winter's Chill is a debuff on a mob, so it belongs
-- with the frost balls (Frost.lua).
--
-- One note per stack of your own Winter's Chill: stacks 1 to 4 rise, and
-- stack 5 plays the set's held note, as Dyre's Buff Reminders' combo point
-- chimes do (Bassoon or Sax, from Dyre's Sounds). A refresh, a stack that
-- drops, or the debuff ending plays nothing.
--
-- Classic Era only for now: read from the combat log (SPELL_AURA_APPLIED is
-- stack 1, SPELL_AURA_APPLIED_DOSE gives the new count). Forever refuses the
-- combat log; its chime waits for John (the lead, 2026-11-22, question 2).
-- The log is registered only for a Mage, only while the chime is on, and
-- only where the Toolkit says the log is usable: an API gate, not a client
-- version. Classic's combat log gave spell IDs as 0 (warcraft.wiki.gg
-- "Patch 1.13.2/API changes"), so the debuff also counts by its name in your
-- language, read at start and on SPELLS_CHANGED (Dyre's Buff Reminders'
-- rule). Only your own auras count (source GUID), and only on your target
-- (dest GUID; John, 2026-11-23); the talent of that name is never an aura on
-- a mob.
--
-- While Dyre's Buff Reminders older than 1.13.3 is loaded, it still plays
-- its own chime, so this one waits (no log, no sound): no double chime.

DDT.CHILL_CHIME_SETS = {
    bassoon = {label = "Bassoon", notes = {"bassoon1", "bassoon2", "bassoon3", "bassoon4"}, full = "bassoon8"},
    sax = {label = "Sax", notes = {"sax1", "sax2", "sax3", "sax4"}, full = "sax8"},
}
DDT.CHILL_CHIME_ORDER = {"bassoon", "sax"}
DDT.CHILL_CHIME_DEFAULT = "bassoon"
-- Dyre's Sounds older than 1.4.0 has no bassoon: the sax note of the same number.
DDT.CHILL_CHIME_FALLBACK = {pattern = "^bassoon(%d)$", prefix = "sax"}
-- Dyre's Buff Reminders' release that hands the chime over.
DDT.DBR_ADDON, DDT.DBR_TITLE, DDT.DBR_HANDOVER = "DyresBuffReminders", "Dyre's Buff Reminders", "1.13.3"
-- Between the notes of "Test chime".
DDT.CHILL_CHIME_GAP = 0.3

local CLEU = "COMBAT_LOG_EVENT_UNFILTERED"
local SOUNDS_CONTRACT = 1
local chime = {events = CreateFrame("Frame"), registered = false}
DDT.chillChime = chime

-- A note set's key when it is one (bassoon or sax), else nil.
function DDT.ChillChimeSet(key)
    return type(key) == "string" and DDT.CHILL_CHIME_SETS[key] and key or nil
end

-- Dyre's Sounds with the contract and Play, else nil.
function DDT.SoundLibrary()
    local library = rawget(_G, "DyresSounds")
    if type(library) ~= "table" or type(library.RequireContract) ~= "function" then
        return nil
    end
    local ok, api = pcall(library.RequireContract, SOUNDS_CONTRACT)
    if not ok or type(api) ~= "table" or type(api.Play) ~= "function" then
        return nil
    end
    return api
end

-- Whether this client can hear the chime: a Mage where the combat log runs.
function DDT.ChillChimeUsable()
    local toolkit = DDT.toolkit
    return DDT.class == "MAGE" and type(toolkit) == "table" and type(toolkit.CombatLogUsable) == "function"
        and toolkit.CombatLogUsable() == true and type(UnitGUID) == "function"
end

-- The version of Dyre's Buff Reminders that still plays its own chime
-- (loaded and older than 1.13.3, or unreadable), else nil.
function DDT.ChillChimeWaitsFor()
    if not DDT.AddOnLoaded(DDT.DBR_ADDON) then
        return nil
    end
    local version = DDT.AddOnVersion(DDT.DBR_ADDON)
    if version and DDT.VersionAtLeast(version, DDT.DBR_HANDOVER) then
        return nil
    end
    return version or "unknown"
end

-- The note for a stack: a rising note below 5, the held note at 5.
function DDT.ChillChimeNote(stack, set)
    set = DDT.CHILL_CHIME_SETS[DDT.ChillChimeSet(set) or DDT.CHILL_CHIME_DEFAULT]
    if stack >= DDT.CHILL_MOST then
        return set.full
    end
    return set.notes[math.max(1, math.min(stack, #set.notes))]
end

-- One note; an older Dyre's Sounds without bassoon plays the sax note.
function DDT.PlayChillNote(key, speech)
    local library = DDT.SoundLibrary()
    if not library then
        chime.last = "no Dyre's Sounds"
        return false
    end
    if library.Play(key, speech) then
        return true
    end
    local number = key:match(DDT.CHILL_CHIME_FALLBACK.pattern)
    return number ~= nil and library.Play(DDT.CHILL_CHIME_FALLBACK.prefix .. number, speech) == true
end

-- "Test chime": stacks 1 to 5, one after another (C_Timer, no OnUpdate).
function DDT.TestChillChime()
    if not DDT.SoundLibrary() then
        DDT.Report("Winter's Chill chime: install Dyre's Sounds to hear it.")
        return false
    end
    local set = DDT.db.wintersChill.noteSet
    for stack = 1, DDT.CHILL_MOST do
        local function Play()
            DDT.PlayChillNote(DDT.ChillChimeNote(stack, set), "Winter's Chill " .. stack)
        end
        if stack == 1 or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
            Play()
        else
            C_Timer.After((stack - 1) * DDT.CHILL_CHIME_GAP, Play)
        end
    end
    return true
end

-- The debuff's name in the client's language; a secret one is not kept.
local function ReadName()
    local name
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        name = C_Spell.GetSpellName(DDT.CHILL_SPELL)
    elseif type(GetSpellInfo) == "function" then
        name = GetSpellInfo(DDT.CHILL_SPELL)
    end
    chime.name = type(name) == "string" and not DDT.toolkit.IsSecret(name) and name or nil
end

local function IsDebuff(spellID, spellName)
    local secret = DDT.toolkit.IsSecret
    if not secret(spellID) and spellID == DDT.CHILL_SPELL then
        return true
    end
    return chime.name ~= nil and not secret(spellName) and spellName == chime.name
end

local function EventInfo()
    if type(C_CombatLog) == "table" and type(C_CombatLog.GetCurrentEventInfo) == "function" then
        return C_CombatLog.GetCurrentEventInfo()
    end
    if type(CombatLogGetCurrentEventInfo) == "function" then
        return CombatLogGetCurrentEventInfo()
    end
end

chime.events:SetScript("OnEvent", function(_, event)
    if event == "SPELLS_CHANGED" then
        ReadName()
        return
    end
    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, spellName, _, _, amount = EventInfo()
    local secret = DDT.toolkit.IsSecret
    if secret(sourceGUID) or sourceGUID ~= chime.player or not IsDebuff(spellID, spellName) then
        return
    end
    -- Only your target's stacks (John, 2026-11-23: "Just like Rogue combo
    -- points, if we do chimes, it should only be for the player's primary
    -- target"). A chill on any other mob plays nothing.
    local target = UnitGUID("target")
    if secret(destGUID) or secret(target) or target == nil or destGUID ~= target then
        return
    end
    local stack
    if subevent == "SPELL_AURA_APPLIED" then
        stack = 1
    elseif subevent == "SPELL_AURA_APPLIED_DOSE" and not secret(amount) and type(amount) == "number"
            and amount >= 1 then
        stack = math.min(amount, DDT.CHILL_MOST)
    else
        return
    end
    chime.last = subevent .. " " .. stack
    local note = DDT.ChillChimeNote(stack, DDT.db.wintersChill.noteSet)
    DDT.PlayChillNote(note, "Winter's Chill " .. stack)
end)

-- Registers the combat log while the chime can and should play, else not.
function DDT.RefreshChillChime()
    local on = DDT.ChillChimeUsable() and type(DDT.db) == "table" and DDT.db.wintersChill.chime == true
        and DDT.ChillChimeWaitsFor() == nil
    if on then
        chime.player = UnitGUID("player")
        ReadName()
        chime.events:RegisterEvent(CLEU)
        chime.events:RegisterEvent("SPELLS_CHANGED")
    else
        chime.events:UnregisterEvent(CLEU)
        chime.events:UnregisterEvent("SPELLS_CHANGED")
    end
    chime.registered = on == true
    return chime.registered
end

-- At login, for a Mage: one line while Dyre's Buff Reminders still has it.
function DDT.StartChillChime()
    if DDT.class ~= "MAGE" then
        return
    end
    local waits = DDT.ChillChimeUsable() and DDT.ChillChimeWaitsFor()
    if waits then
        DDT.Report(string.format("The Winter's Chill chime waits: %s %s still plays its own. Update it to %s or "
            .. "later to hear this one.", DDT.DBR_TITLE, waits, DDT.DBR_HANDOVER))
    end
    DDT.RefreshChillChime()
end

function DDT.ChillChimeDebug()
    if DDT.class ~= "MAGE" then
        return "chime none (Mage only)"
    end
    if not DDT.ChillChimeUsable() then
        return "chime off: no combat log on this client (WoW: Forever's chime is not built yet)"
    end
    return string.format("chime on=%s registered=%s waitsFor=%s noteSet=%s sounds=%s name=%s last=%s",
        tostring(DDT.db.wintersChill.chime), tostring(chime.registered), tostring(DDT.ChillChimeWaitsFor() or "none"),
        tostring(DDT.db.wintersChill.noteSet), DDT.SoundLibrary() and "yes" or "no", tostring(chime.name),
        tostring(chime.last or "none"))
end
