# Tracking engine move into Dyre's Toolkit (plan, 2026-11-01)

## John's decision (2026-11-01)

- Keep class-named AddOns on CurseForge (WTF, MTF, and later Priest, Druid,
  Hunter, Paladin... Tools Forever), AND keep Dyre's Debuff Tracker.
- Move the core DoT and crowd-control tracking code from WTF and MTF into
  Dyre's Toolkit now. The Toolkit becomes the engine.
- DDT becomes a generic UX wrapper on the Toolkit engine, so classes that
  have no Tools AddOn yet get the tools sooner.
- This replaces the old phase 2 ("Warlock parity in DDT").

## Lead decisions

1. **The engines never own SavedVariables.** Each one takes a `store` table
   (for example `WarlockToolsForeverDB.tracker`) and the owning AddOn keeps
   its sanitizers, reset, lock/placeholder code, and migrations. One
   exception: the learned tick store moves to `DyresToolkitDB.ticks`, with a
   one-time copy from `WarlockToolsForeverAccountDB.ticks`.
2. **Frame names are passed in, never generated.** Keep every current name
   (WarlockToolsForeverTracker, ...TrackerFocus, ...TrackerList (Tracker
   1505-1506), ...Control, ...ControlClick<n>, ...ControlRow<n>,
   ...ControlFocus, MageToolsForeverPolymorph, ...Bar).
2a. **Unit orders are spec fields.** Tracker and Control use different
   orders (WTF session, 2026-11-01); keep each one, or WTF's behaviour
   changes:
   - Tracker: FindUnit plates, memory, target, focus (FIND_ORDER, 889-890);
     LockCast target, focus, mouseover, plates, with stopAtName and allowDead
     (CAST_LOOK, 1137).
   - Control: FindUnit default order (235-239); LockCast focus, mouseover,
     target, plates, with memory and secretHostile (CAST_LOOK, 262; the
     focus-only lock at 245).
3. **Class spell tables live in the Toolkit** (one data file, for example
   `ClassData.lua`), because DDT needs every class and two AddOns need the
   Warlock and Mage tables. WTF and MTF read their class's table from there.
   Every ID beyond WTF's and MTF's checked IDs must be checked per client
   before it ships.
4. **Hard-coded class rules become data:** the Agony ramp (`weights`), the
   Fear plate timer (`plateTimer` flag), the Seduction pet check
   (`PetKnows` on the spell def).
5. **Contract stays 2.** New functions are additions. Every dependent's
   required-function list (WTF `REQUIRED_NAMESPACE`/`SHARED_FUNCTIONS`, DDT
   `TOOLKIT_FUNCTIONS`) gains the functions it uses.
6. **Backward compatible at every stage.** The released WTF 1.4.1 and MTF
   1.2.3 must keep working with each new Toolkit. A stage is done only when
   the Toolkit, WTF, and MTF suites all pass.
7. One focusWorks flag for the family: MTF carries its own
   `MTF.accountDB.focusWorks` over once with `NoteFocusWorks`, then stops
   reading it. `/mtf reset_focus` and `/wtf reset_focus` then agree.
7a. **A class Tools AddOn wins over DDT for its class** (lead, 2026-11-01,
   with stage A review). DDT is the wrapper for classes without a Tools
   AddOn, so it registers at priority 5 (WTF 1.4.1 is at 10) for HealthBars,
   and the stage B owner registry (control bars, macros, announcements)
   uses the same rule. This replaces "DDT at priority 20".
8. Standing rules apply: event-driven only, no popups in combat, no
   SetRaidTarget (markers only through `/tm` in macro text), macros change
   only out of combat, gate every value that may be secret, no byte-identical
   copy tests, Lua 5.1, no commits (the lead commits on John's "ship it").

## Stages and owners

| Stage | Work | Owner |
| --- | --- | --- |
| A | Toolkit `Spells.lua` (spellbook-by-name sets, KnowsAny, PetKnows), `Macros.lua` (character macro helpers, MarkLine, FocusCastMacro, CreateMacroKeeper with adopt-by-name), `Announce.lua` (GroupChannel, FormatAnnouncement with a values table, SendGroup with throttle, RAID_MARKERS), `ClassData.lua` (Warlock and Mage tables first) | DDT session, in src/DyresToolkit |
| B | Toolkit `Control.lua`: `CreateControlTracker(spec)`, merging WTF Control.lua and MTF Polymorph.lua (incl. Polymorph's no-focus aura countdown, made generic) | DDT session |
| C | Toolkit `DotTracker.lua`, `PlateDots.lua`, `DotPredict.lua` from WTF Tracker/Dots/Predict | DDT session |
| D | WTF and MTF switch to the engines and delete their copies; MTF also deletes AuraEngine.lua and moves to `## OptionalDeps` | WTF and MTF sessions, after each Toolkit stage lands |
| E | DDT: the generic wrapper (settings pages, class detection, all classes from ClassData) | DDT session |

The lead reviews each stage before the next starts.

## Split map (survey, 2026-11-01; line numbers at WTF 1.4.1 / MTF 1.2.3)

### Classification

- **Tracker.lua**: SLOTS 76-97 is class data. Generic: capabilities
  104-117, spellbook sets 123-183, filters/KnowsSlot/SlotIcon 218-248,
  ApplyCastButtons 703-731, IsLiveHostile/ReadName 842-858 (ReadName
  returns "" here, nil in the Toolkit: keep ""), FindUnit/Bind/death/unseen/
  RefreshBindings 889-977, Track/cast handling 1070-1140, spell sets and
  rows 1143-1239, events 1324-1417. UI: 186-215 (bars are forbidden after
  handing to the engine), 250-702, 732-887, 979-1068, 1420-1481. Settings
  setters 1241-1322. Init 1483-1534 creates frame names (1507).
- **Dots.lua**: generic except UI 47-129.
- **Predict.lua**: class data RANKS 21-33, FAMILIES 38-44, Weight 87-100
  (Agony ramp). Generic: CLEU gate and engine 46-85, 348-505, tick maths
  102-184, drawing on HealthBars 186-346, HealthBars source 507-578.
- **Control.lua**: class data CONTROL_SPELLS 54-60, CONTROL_MACROS 799-803.
  Generic: RAID_MARKERS 62-74, sanitizers incl. MARKERS_VERSION 112-154,
  spell sets 185-233, units/locks 235-304, Track/Forget/MarkLine 381-438,
  announce 637-669, casts 671-772, macros 804-922 (Seduction entry, spell 6358 with pet = true, at 795;
  PetKnows at 820; the debug line 1214 also calls PetKnows(6358)),
  Fear plate timers 924-1014 (hard-coded "fear"), events 1016-1101.
  UI: 306-380, 440-636.
- **Announce.lua**: no CC logic; Control calls SendGroupAnnouncement 56-66,
  GroupChannel 41-54, FormatAnnouncement 68-74. CC texts and switches are
  in WTF Core 253-257 and 499-500. Summon/soulstone stays in WTF.
- **Polymorph.lua**: class data POLYMORPH_IDS/LONGEST/MOON 56-98. Duplicates
  of Toolkit Units: 101-122, 161-207. Generic: 124-158, 209-357 (incl. the
  no-focus aura read and countdown 282-315), macros 544-576, announce
  578-599, casts/events 601-718. UI 359-542, 720-793.

### Duplication (WTF Control vs MTF Polymorph)

Spellbook-by-name scan (three copies, with Tracker), unit and lock helpers,
focus learning (MTF writes its own flag), Track/Forget with a longest + 5 s
timeout, the cast pipeline, focus loss, death by GUID on UNIT_HEALTH, the
secure focus recast click, macro text, macro upkeep with macroDirty,
announce with a 3 s throttle (MTF has no Say option and a different
FormatAnnouncement signature), the bar-row initializer and its constants,
and AuraEngine.lua against Toolkit Auras.lua.

### Dependencies to replace with spec fields

- Tracker/Dots: `WTF.db.tracker.*`, `WTF.db.locked`, Core helpers
  (DOT_SLOTS, OrderedDotSlots, SlotColor, PanelColor, TRACKER_SIZE_SPECS,
  TRACKER_PANELS, sanitizers, PANEL_OPACITY_*), Layout movers, Report.
- Predict: `WTF.db.predict.*`, PREDICT_COLORS, `WTF.accountDB.ticks`,
  RefreshTrackerPrediction.
- Control: `WTF.db.control.*`, `WTF.db.announce.{key}Group(Text)`, macro
  helpers from Stones.lua 256-270, CreateMover, RegisterMovable, PanelColor.
- Polymorph: `MTF.db.polymorph`, `MTF.db.announce.polymorphGroup(Text)`,
  `MTF.db.locked`, `MTF.accountDB.focusWorks`, MTF size/opacity specs, macro
  helpers in Conjure.lua 358+.

### Risks

- Tests: WTF tests/run.lua has 42 references to these frames and to
  controlRows/fearPlateTimers; MTF tests ~20, and they load AuraEngine.lua.
  WTF's CI-only tests/toolkit copies need the new Toolkit files.
- WTF asks for contract 1 (Core 75); the Toolkit is at 2.
- MTF's TOC uses `## Dependencies: DyresToolkit` (family rule: OptionalDeps).
- Once DDT and a class AddOn are both on, macros and announcements must be
  adopted, never duplicated, and only one AddOn draws (HealthBars source
  priority; the control engine needs the same "one owner" rule).
