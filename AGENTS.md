# Agent Guidelines

## Project purpose and scope

Dyre's Debuff Tracker (folder and TOC `DyresDebuffTracker`, saved variables
`DyresDebuffTrackerDB`, chat prefix `DDT:`) is one AddOn for every class
(John, 2026-10-29/30; he first picked two AddOns, then changed his mind the
same day). It does three things:
- DoT tracking.
- DoT damage prediction: the purple block on health bars and the red skull
  "DIES" badge.
- Crowd-control tracking (Fear, Banish, Polymorph, Shackle, and others), with
  their group announcements.

DoTs and crowd control get separate settings pages, each with its own on/off
switch. John sees it as a peer to Dyre's Buff Reminders, with more features
than Does It Die.

Where it comes from: WTF 1.4.0 (Tracker.lua, Dots.lua, Predict.lua,
Control.lua, and the Fear, Banish, Enslave Demon, and Howl of Terror
announcements from Announce.lua) and MTF's Polymorph bar. WTF keeps Shards,
Stones, and the Stones/Summon announcements. WTF and MTF step aside later,
as they did for Dyre's Sounds.

## Status: first release 1.0.1 (1.0.0 reached GitHub only)

- CurseForge project 1777574 (created by John, 2026-10-31). John,
  2026-11-14: "ship it; we have a CF project (#1777574) for DDT". The
  release files (copied from Dyre's Crit Mayhem) are in place: the
  workflows, scripts/, the Python tests, README.md, CHANGELOG.md. The lead
  runs `git init`, commits, tags, and pushes; sessions never do.
- `artwork/screenshots/` holds John's raw listing screenshots
  (era-blackrock-grunt-raw.webp, era-blackrock-grunt-dies-raw.webp), to be
  clipped and reframed later. Never overwrite them. Artwork is never in a
  package file list (as Dyre's Crit Mayhem).

## Phases

1. Toolkit groundwork (done: Dyre's Toolkit 2.4.0 holds the shared code, and
   this folder is a stub that loads, needs the toolkit, and does nothing).
2. The engine move (John, 2026-11-01; replaces "Warlock parity in DDT"; the
   plan, decisions, and split map are in docs/ENGINE_SPLIT.md). The core DoT
   and crowd-control tracking moves from WTF and MTF into Dyre's Toolkit, and
   this AddOn becomes a generic UX wrapper on that engine. The class AddOns
   (WTF, MTF, later ones) stay on CurseForge. Stages, each reviewed by the
   lead before the next:
   - A: Toolkit Spells.lua, Macros.lua, Announce.lua, ClassData.lua (Warlock
     and Mage first). This session.
   - B: Toolkit Control.lua, `CreateControlTracker(spec)`, merging WTF
     Control.lua and MTF Polymorph.lua. This session.
   - C: Toolkit DotTracker.lua, PlateDots.lua, DotPredict.lua from WTF
     Tracker/Dots/Predict. This session.
   - D: WTF and MTF switch to the engines (their own sessions).
   - E: this AddOn's wrapper: settings pages, class detection, every class
     from ClassData. Built (0.1.0, 2026-11-01; see "The wrapper" below).
   Engine rules: engines never own SavedVariables (they take a `store`
   table; the one exception is the learned ticks, in `DyresToolkitDB.ticks`);
   frame names are passed in; class rules are data; contract stays 2; WTF
   1.4.1 and MTF 1.2.3 keep working with every new Toolkit. Predictions go
   through `DyresToolkit.HealthBars` damage sources (docs/HEALTHBARS_API.md
   there): this AddOn registers at priority 5, under WTF 1.4.1's 10, and
   draws only while `IsActiveSource("DyresDebuffTracker")` is true. A class
   Tools AddOn wins over this one for its own class (lead, 2026-11-01,
   replacing "priority 20"): this AddOn is the wrapper for classes with no
   Tools AddOn yet. The stage B owner registry (control bars, macros,
   announcements) uses the same rule, one owner per kind; where WTF or MTF
   owns a kind, this AddOn hides that kind's UI or says the class AddOn has
   it. Macros are adopted by name, never duplicated.
3. Crowd control in this AddOn's wrapper, with the control macros (John,
   2026-10-30; see "Phase 3: control macros" below); the macro and announce
   helpers come from stage A, the tracker from stage B.
4. More classes. Does It Die's baseline: Druid (Moonfire, Insect Swarm,
   Entangling Roots, Rake, Rip, Pounce, Lacerate), Hunter (Serpent Sting,
   Lacerate), Mage (the DoT parts of Fireball, Pyroblast, Frostfire Bolt),
   Priest (Shadow Word: Pain, Devouring Plague, Holy Fire), Rogue (Rupture,
   Garrote), Shaman (Flame Shock), Warlock (Corruption, Immolate, Bane of
   Agony, Siphon Life, Wrack), Warrior (Rend); finishers count spent combo
   points. John: "a starting point, not the end-goal".
   Built (the class gate; lead, 2026-11-14, John: "go with your
   recommendations"; the audit is the shared notes'
   ddt-class-spells-audit.md): the data is in Dyre's Toolkit's
   ClassData.lua for every class above but Shaman's Hex (not on either
   client), with Hunter Immolation Trap in place of Lacerate (a Druid spell
   on Forever), Wrack left out (a channel), and Gouge and Scatter Shot left
   out (too short). Crowd control: Shackle Undead and Psychic Scream,
   Hibernate and Entangling Roots (also a DoT slot), Scare Beast, Wyvern
   Sting, and Freezing Trap (announced only), Sap and Blind, Turn Undead and
   Repentance, Intimidating Shout (announced only); macros "! Hibernate",
   "! Shackle", "! Sap", "! Repentance". No ID is checked in client yet:
   TESTING.md lists what John checks.
5. Forever. Damage to come is built in Toolkit 2.6.0 (hidden ticks, an
   estimate; its docs/FOREVER_PREDICT.md), not yet checked in client.
6. Display extras.
7. Go public.

## Phase 3: control macros (John, 2026-10-30; planned, not built)

The control macros move here from WTF ("! Fear", "! Banish", "! Seduction")
and MTF ("! Polymorph"), and grow to every class. The Debuff Tracker detects
the player's class and keeps one character macro per control spell the
character knows, at its best rank; none for a spell it does not know.

| Class | Spells | Notes |
| --- | --- | --- |
| Warlock | Fear, Banish, Seduction, Howl of Terror, Enslave Demon | Seduction only with a Succubus or Incubus that knows it (WTF: spell 6358 in the pet spellbook, `pet:Succubus/Incubus` in the macro); Howl of Terror has no target |
| Mage | Polymorph and its variants | MTF's IDs: 118, 12824, 12825, 12826, 28272, 28271, 28270, plus spellbook spells of those names |
| Priest | Shackle Undead, Psychic Scream | Psychic Scream has no target |
| Druid | Hibernate, Entangling Roots | |
| Rogue | Sap, Gouge, Blind | |
| Hunter | Freezing Trap, Scare Beast | Freezing Trap is placed on the ground, with no target: only the cast line |
| Paladin | Turn Undead, Repentance where it exists | Repentance is a talent: only when learned |
| Shaman | Hex or the like | Only where the client has it (to check on Forever; not on Era) |

- Every spell ID and its availability per client (Era 1.15.9, Forever) is
  checked in client and in the pinned UI source before it is used; the IDs
  above from WTF and MTF are the only ones checked so far. Match by the
  spellbook's names too, as WTF and MTF do, so each client's own ranks count.
- Macro text keeps WTF's and MTF's rules: focus first; where focus does not
  work (the toolkit's shared `FocusWorks()` false, as on Era), the mob under
  the mouse, then the target. Every `@focus` condition has `exists`. `/use`,
  not `/cast`. A marker only through `/tm` in the macro text, with a marker
  setting per spell; AddOn code never calls SetRaidTarget.
- Macros change only out of combat; a change in combat (a new rank, a
  learned focus, a setting) waits for PLAYER_REGEN_ENABLED. A
  `OnFocusWorks` change rebuilds them, also out of combat.
- Character macros (`CreateMacro(..., true)`), leaving the last character
  slots free as WTF's Stones macros do, and a setting to turn macro upkeep
  off (off deletes ours).
- Migration from WTF and MTF, with no duplicates: adopt their macros by
  exact name ("! Fear", "! Banish", "! Seduction", "! Polymorph") and
  rewrite them in place, never a second copy; say once in chat that the
  Debuff Tracker keeps them now. WTF and MTF stop writing them in the same
  step (each owner session; coordinated by the lead).

## The wrapper (stage E, built)

- Core.lua: saved settings and their repair (`DDT.SanitizeDB(db,
  classData)`), the toolkit check, startup, and `/ddt` (`/debufftracker`):
  no word opens the settings, `reset` puts the frames back, `reset_focus`
  resets the family's focus check, `debug` prints what the engines see.
  `## SavedVariablesPerCharacter: DyresDebuffTrackerDB` (positions and
  character macros are per character): `dots` (WTF's db.tracker keys and
  defaults; the nameplate dots off by default, as WTF's), `predict`,
  `control` (enabled, plateTimers, macros, markers, announce per spell, off
  by default, texts, say, position, scale), `macrosOwned` (the macro
  keeper's `owned`).
- Engines.lua: the class from `UnitClass`, its table from `ClassSpells`;
  every class with a ClassData table (all nine since the class gate; a
  class with no DoTs, Paladin, gets no DoT tracker, and one with no control
  spells, Shaman, no bar). Every engine claims
  at priority 5 (`DDT.PRIORITY`), under a class Tools AddOn's 10. While
  your class's Tools AddOn is loaded at a version from before the owner
  registry (`DDT.CLASS_ADDONS`: WTF through 1.4.1, MTF through 1.2.3, or a
  version that cannot be read), this AddOn makes no engines for that class
  (lead, stage B answer 2); later versions claim, and the claims decide.
  Frames: DyresDebuffTrackerTarget/Focus/List (DoT sections, the toolkit's
  RegisterMovable), DyresDebuffTrackerControl (a toolkit widget, Bar size),
  ...ControlRow<n>, ...ControlClick<n>, ...ControlFocus (only for a class
  with a bar spell that has no click: Warlock's Fear). Where the combat
  log is restricted (Forever), Toolkit 2.6 gives a predictor that reads
  hidden ticks (`predictor.hidden`); Toolkit 2.5 gives none there, and the
  page leaves out its settings. A class Tools AddOn (10) still wins over
  this AddOn (5).
- Options.lua: "Debuff Tracker" under Dyre's AddOns, with two pages, DoTs
  and Crowd control, each with its own Enable. A page whose kind another
  AddOn has says which one and greys its settings (`DDT.KindStatus`,
  `DDT.Owns`); a class with no table or no data for the kind gets one note.
- Tracker size (John, 2026-11-14: "a 'Tracker size' slider, allowing the
  length of the dot bar to be adjusted, increasing or decreasing by up to
  25%"): `db.dots.trackerSize`, a percent from 75 to 125 on steps of 5
  (`DDT.TRACKER_SIZE`), repaired in SanitizeDB (`DDT.SanitizeTrackerSize`:
  not a number gives 100, else rounded to a step and clamped). It is the
  source of `sizes.bars.barWidth` (290 x percent) and
  `sizes.compact.iconSize` (22 x percent), rounded to whole pixels
  (`DDT.ApplyTrackerSize`, at every SanitizeDB and slider change, except
  while `trackerSize` is false: the sizes were set one by one, by the
  per-look sliders or the WTF import); the name width, line height, and
  text scale stay. The slider ("Tracker size" on
  the DoTs page, the gold default mark through the Toolkit's
  `AddDefaultTick`) calls the tracker's `Rebuild`, which the Toolkit runs
  out of combat (else at PLAYER_REGEN_ENABLED). No Toolkit change.
- Grow (John, 2026-11-14: "for each frame (Target, Focus, Other) we need
  to be able to set whether the DoTs should grow up or down from the
  origin"; "Keep the name above/below setting we already have where it is.
  The user can chose."): `db.dots.grow` = {target, focus, list}, each
  "down" (default) or "up" (`DDT.GROW`), repaired in SanitizeDB (anything
  else is "down"). The Toolkit's DoT tracker reads `store.grow` live
  (Toolkit 2.9.2, `DyresToolkit.TRACKER_GROW`). Three dropdowns on the
  DoTs page, "Grow: Target", "Grow: Focus", "Grow: Others", after Tracker
  size (the name position is a per-look row since the WTF move), each calling the tracker's `Rebuild` (out of combat, else at
  combat's end). Shown only when `TRACKER_GROW` exists (Toolkit 2.9.1 lacks
  it); the saved value is kept and repaired either way.
  `DDT.TOOLKIT_VERSION` stays 2.9.1: the gate hides only the Grow settings
  on 2.9.1, and the rest works (lead, 2026-11-14, at the 2.9.2 release).
- Hide empty DoT slots (treadpool, a player, 2026-11-17: "Would be
  cleaner if it only showed the DoTs that are actively ticking"; John:
  "Yes, build it"): `db.dots.hideEmpty`, boolean, default false, repaired
  in SanitizeDB; a setting, so in the profile (the profile refresh's
  `RefreshDots(true)` rebuilds). A checkbox on the DoTs page after Tracker
  size, shown only when `DyresToolkit.TRACKER_HIDE_EMPTY` is true (an
  unreleased Toolkit; 2.10.2 lacks it); a change calls `Rebuild` (out of
  combat). The Toolkit draws no placeholders, keeps every slot's place, and
  makes no secure slots on the target and focus rows (no recast clicks).
- Panel switches (a player, 2026-11-19: "Is there a way to disable the
  target dot window or hide it?"; John: "a 3 panels toggle show/off, default
  to show. A checkbox is fine for now."): `db.dots.show = {target, focus,
  list}`, booleans, default true, repaired in SanitizeDB (only false hides;
  anything else is true); under dots, so in the profile. Three checkboxes on
  the DoTs page before the Grow dropdowns, "Show Target panel", "Show Focus
  panel", "Show Others panel", shown only when
  `DyresToolkit.TRACKER_PANELS` is a table (an unreleased Toolkit; 2.10.2
  lacks it); a change calls `RefreshDots(false)`, which calls the tracker's
  `Refresh` (the Toolkit reads `store.show` live). The saved value is kept
  and repaired either way.
- Panel frame and outline (a player, 2026-11-20, GitHub issue 1: "When a
  target is selected, a frame appears with a purple border. I'd like to
  hide all of that and only show the debuff bars."; John: "Build parts 1
  and 2"): `db.dots.frame`, boolean, default true (only false hides), and
  `db.dots.outlineWidth`, whole pixels 0-20, default 3 (`DDT.OUTLINE_WIDTH`,
  the Toolkit's `TRACKER_OUTLINE`), both repaired in SanitizeDB and in the
  profile. "Show panel frame" shows only when `DyresToolkit.TRACKER_FRAME`
  is true (unreleased Toolkit; 2.12.0 lacks it); a change calls
  `RefreshDots(false)`, which now also calls the tracker's
  `ApplyPanelColors` when it exists (at once, also in combat). "Outline
  width" shows when `TRACKER_OUTLINE` exists (every supported Toolkit) and
  rebuilds. Before this, only WTF offered the outline width.
- Per-panel settings (John, 2026-11-21: "1) The show mob health checkbox,
  and text config (health #, %, etc.) settings are missing from the
  Target/Focus/Others boxes. 2) The panel settings need to be organized by
  the panel they control, and each needs it's own config (size, border
  width, etc.) In the "Panels" section, with a sub-section heading for
  Target, Focus, and Other."): `db.dots.panels` = {target, focus, list},
  each {health, healthText, frame, outlineWidth, trackerSize (percent or
  false), sizes {compact, bars}} (`DDT.SanitizePanel`, in SanitizeDB; a
  missing or bad value is the tracker-wide one, so older saves, older
  profiles, and the WTF import, which clears `panels`, start each panel
  from the tracker-wide values). The Toolkit reads `store.panels`
  (`TRACKER_PANEL_OPTIONS`, Toolkit 2.13.0; `DDT.PerPanel()`). With it the
  page has "Panels" and one heading per panel ("Target panel", "Focus
  panel", "Others panel": `PanelSections` in Options.lua) with the switch
  (`DDT_DOTS_SHOW_<KEY>`), `DDT_PANEL_<KEY>_HEALTH`, `_HEALTH_TEXT`,
  `_FRAME`, `_OUTLINE` (Target and Focus only: the list has no outline),
  Grow (`DDT_DOTS_GROW_<KEY>`), `_TRACKER_SIZE`, `_<LOOK>_<SIZE>`,
  `_<LOOK>_NAMEPOSITION`, color and opacity (`DDT_DOTS_PANEL_COLOR_`/
  `_OPACITY_<KEY>`), and "Reset <name> panel" (`DDT.ResetPanel`: the
  panel's own settings, switch, grow, color, opacity; its place stays).
  Tracker-wide rows that stay: Enable, Theme, Hide empty DoT slots, the
  nameplate dots, Each DoT, the Curse slot, Damage to come. Without the
  flag the page keeps the tracker-wide rows (Tracker size, sizes, Reset
  size, panel switches, frame, outline, Grow, health, panel colors and
  opacity), and `DDT.MirrorPanels` (in `RefreshDots`) copies the
  tracker-wide values into each panel on each change, so a later Toolkit
  update starts from them; not at login, so per-panel values saved with a
  newer Toolkit stay. Sliders always show a number (`DDT.WholeLabel`):
  without a formatter the client shows no value (John's Outline width read
  0 while 3 was saved, 2026-11-21).
- Profile (John, 2026-11-17: "start working on the global "all Dyre addons
  settings" syncing with DT's profile, so there is one place to go to
  persist your profile"; the design is the Toolkit's docs/PROFILES.md, John
  2026-11-15): Engines.lua `DDT.RegisterProfile`, called from `DDT.Start`
  after SanitizeDB and before the frames, only when the Toolkit has
  `RegisterProfilePart` (2.10.0); with an older Toolkit nothing changes, and
  `DDT.TOOLKIT_VERSION` is not raised. `current` is DyresDebuffTrackerDB
  (`DDT.db`). Key audit of DyresDebuffTrackerDB:
  - In the profile: `dots` (enabled, theme, sizes, trackerSize, grow, show,
    hideEmpty, frame, outlineWidth, panels, order, colors, panelColors, curseMode,
    curseMarker, health, healthText, position and sections (the panels'
    places), panelOpacity, onPlates, plateDots and its offset and opacity),
    `predict` (every setting, with the DIES places and offsets), and
    `control` (enabled, plateTimers, macros, say, position, scale, markers,
    announce, texts, width, barHeight, textScale, opacity), `frost` (the Mage's arcs: enabled, offset, size),
    `brand` (the Warlock's Demonic Brand pentagram: enabled, offset, size),
    `wintersChill` (the Mage's Winter's Chill balls: enabled, offset, size,
    chime, noteSet), `chimeImported` (DBR's chime settings copied once), and
    `toolsImported` (the class Tools AddOn's settings copied once).
  - `characterKeys` = {"macrosOwned"}: the names of the character macros
    this AddOn keeps (the control tracker's keeper `owned`); macros are per
    character, so another character's list must not land here.
  - The recast memory `dots.lastCurse`, `dots.lastBane`, `dots.lastControl`
    (each slot's `lastUsed` key; the DoT tracker writes the spell you last
    cast) is live state, but it sits inside `dots`, and `characterKeys`
    only skips top-level keys. So the part's sanitize
    (`DDT.ProfileSettings`) puts this character's live values back after
    repairing. An export still holds the exporter's values; an import never
    uses them.
  - No account table: DDT has none (John: account settings are not in a
    profile).
  `DDT.ProfileSettings(settings)`: any table (empty, partial, older, newer,
  another class's) through SanitizeDB with this character's class table;
  only dots, predict, control, frost, brand, wintersChill, toolsImported, chimeImported, and macrosOwned are kept; never errors.
  `DDT.ApplyProfile` (refresh; the Toolkit writes DDT.db in place and
  applies only out of combat): `ReapplyWidgets` (the control bar's place and
  scale), the DoT tracker's `ResetPosition` (the panels' places),
  `ApplyPanelColors`, `RefreshDots(true)` (owner claim from dots.enabled,
  then `Rebuild`: theme, sizes, grow, order, health, panel opacity; plate
  dots; predictor), the plate dots' colors and opacity, and the control
  tracker's `SetScale`, `Rebuild`, and `Refresh` (owner claim, clicks, plate
  timers, macros through the out-of-combat path). Nothing needs a reload.
- Demonic Brand pentagram, Warlock only, Forever only (John, via the lead,
  2026-11-21: "Demonic Brand (for Demonology Warlocks): we need to add it.
  It's a debuff on your current target, but it should render like the
  frost/frozen debuff indicators"; then the same day: "Make it a glowing red
  pentagram that renders above the nameplate, and make it so the size and
  height can be adjusted"; a player asked on WTF's CurseForge page, comment
  8766431). Frost.lua: the arc builder is shared (`CreateArcs`, local) with a
  per-spec `look` ({width, height, Draw}); `DDT.CreateBrandArcs` uses it with
  `DDT.BRAND_SPELLS` (one slot `brand`, filter `HARMFUL|PLAYER`: only your
  demon uses your Brand; ID 1293696, a set) and `BRAND_LOOK`: the engine's
  button is 48 x 48 (`DDT.BRAND_GLOW`), with Textures/BrandGlow.tga
  (BACKGROUND, blend ADD, the whole button) and BrandPentagram.tga
  (ARTWORK, 28 x 28, `DDT.BRAND_STAR`, centered); both 128 x 128, made by
  scripts/make_artwork.py --brand (our own art). The glow pulses with an
  AnimationGroup on the glow texture (Alpha 0.45 to 1, 0.9 s, BOUNCE,
  `DDT.BRAND_PULSE`), played once in `initializeFrame`; no OnUpdate. New
  TGA files need a full client restart, not /reload. Made in `DDT.Start`
  for every Warlock (any Warlock may take the talent; talents are never
  read), before the Tools AddOn check, only when `DDT.BrandKnown()` (a
  static `C_Spell.GetSpellName(1293696)`, else `GetSpellInfo`): Classic
  Era has no such spell, so no pentagram, no rows, no message. Plate rules
  as the Mage's arcs (pool, NAME_PLATE_UNIT_ADDED/REMOVED, FindPlateBar,
  hostile only); no GUID memory: the engine's container reads the plate's
  unit each time, so a plate that comes back shows the Brand again. Shown
  on any enemy plate with your Brand (in practice your Searing Pain
  target). `db.brand` = {enabled (true), offset (0 to 60, 10: pixels from
  the bar to the glow's bottom; the star is 10 more above it), size (50 to
  200 percent, 100)}, repaired in SanitizeDB; in the profile
  (`DDT.RefreshBrand`). Options (`BrandSection`, after "Frozen and
  chilled", last on the DoTs page, never greyed): "Show", "Size" (label
  "N%"), "Height above nameplate" (label "N"; `Slider` takes an optional
  label formatter), and "Reset Demonic Brand" (`DDT.ResetBrand`: the
  defaults written into the same table). `/ddt debug`: a `brand` line;
  `brand off: this client lacks Demonic Brand (1293696)`; not a Warlock:
  `brand none (Warlock only)`. IDs from the web (Wowhead spell=1293696 and
  1293695, warcraft.wiki.gg, warcraftmaps.com), not yet checked in client:
  TESTING.md has the /dump. No charge count (the debuff's applications,
  2/4/6 by rank). Preview (the lead, 2026-11-21: John's Warlock is
  Affliction and low level, so he cannot apply the Brand): the "Preview"
  button and `/ddt preview brand` (also `/ddt preview`) call
  `DDT.PreviewBrand` -> `arcs:TogglePreview()` ("started", "stopped", "no
  plate"; a chat line each, `DDT.BRAND_PREVIEW_TEXT`). It is our own frame
  drawn with the same `look.Draw` (not an engine button, no aura, nothing
  protected, so also in combat and without the talent), parented to
  `C_NamePlate.GetNamePlateForUnit("target")` and placed with the same
  `Place` (FindPlateBar("target"), Size, Height); `arcs:Refresh` places it
  again, so the sliders and Reset apply live; it stays while "Show" is off.
  It ends on a second press, PLAYER_TARGET_CHANGED, PLAYER_LOGOUT, or
  NAME_PLATE_UNIT_REMOVED for its plate. Not saved.
- Winter's Chill cells, Mage only, both clients (John, 2026-11-22: "add a
  similar halo above the nameplate (we do for chilled/frozen) with up to 5
  cells (one per charge) (like a rogue/druid combo-point counter)"; he
  noted DBR's Era chime is next to useless: it is a mob debuff; then the
  same day: "I'm thinking blue frostballs that turn white as the stack
  builds", and "DBR should remove it's broken chime"). Frost.lua
  `DDT.CreateChillArcs` with the shared `CreateArcs`: one slot `chill`,
  filter `HARMFUL|PLAYER`, ID 12579 (a set; `DDT.CHILL_SPELLS`); Wowhead
  forever/spell=11180 (the talent's proc triggers 12579), forever and
  classic spell=12579 (15 s, Magic; Forever flags "DoT Stacking Rule" and
  "Nameplate Personal Buffs/Debuffs"; Forever: Cone of Cold damage taken,
  Era: crit chance), warcraft.wiki.gg (5 stacks); not checked in client.
  Made for a Mage when `DDT.ChillKnown()` (`DDT.SpellKnown(12579)`), else
  one chat line and `chill off: ...` in `/ddt debug`. `CHILL_LOOK`: 13 x 13
  cells (`DDT.CHILL_CELL`), five balls (Textures/ChillBall.tga, BORDER,
  tinted blue, `DDT.CHILL_COLORS.empty`), ball 1 white (ARTWORK, the same
  art tinted white; shows whenever the engine shows the button, so a count
  of 0 or 1 at one stack both read as one), and a StatusBar over balls 2 to
  5 whose fill is Textures/ChillBalls.tga (four balls, 256 x 64, tinted
  white; the game crops a status bar's fill as it fills, so whole balls
  show: not checked in client, TESTING.md), handed to the engine's `SetApplicationBar(bar, {minApplications = 1,
  maxApplications = 5})`: the engine sets the range, the value (the stacks;
  in combat a secret the bar takes), and shows it from 1
  (Blizzard_CustomAuraButton.lua ApplyApplicationBar, Gethe 943764493e6b;
  one application bar per button). Each stack's fill ends between two
  balls. Both TGAs are 64-pixel cells with a 49-pixel ball (10 of 13 in
  game), made by scripts/make_artwork.py --chill (our own art); new TGA
  files need a full client restart. No SetApplicationBar, or a failing
  call: the bar hides (ball 1 only). Era's plain-Lua container
  gates the bar from Toolkit 2.11.0; older: cell 1 only
  (`DDT.TOOLKIT_VERSION` stays 2.9.1). `db.wintersChill` = {enabled (true),
  offset (0-60, 36: above the arcs' 33), size (50-200, 100)}, in SanitizeDB
  and the profile (`DDT.RefreshChill`). Options `ChillSection` after
  FrostSection: "Show", "Size", "Height above nameplate", "Preview"
  (`DDT.PreviewChill`; the preview frame's bar is set to
  `DDT.CHILL_PREVIEW` = 3; `look.Draw` gets a 4th argument, `preview`), and
  "Reset Winter's Chill". `/ddt preview chill`, and `/ddt preview` for a
  Mage.
- Winter's Chill stack chime, Mage (John, 2026-11-22, via the lead: "2,
  remove it, build it right in DDT"; DBR 1.13.3 removes its Era chime).
  Chime.lua, from DBR 1.9.0-1.13.2's Procs.lua design: the combat log
  (SPELL_AURA_APPLIED = stack 1, SPELL_AURA_APPLIED_DOSE = the count, capped
  at 5), your own source GUID, only on your target (dest GUID ==
  `UnitGUID("target")`; John, 2026-11-23: "Just like Rogue combo points, if
  we do chimes, it should only be for the player's primary target"), ID 12579 or the spell's name (Classic's log
  gave ID 0); notes 1-4 rise, 5 is the set's held note
  (`DDT.CHILL_CHIME_SETS` bassoon/sax from Dyre's Sounds, sax fallback for
  a Dyre's Sounds without bassoon). Gate: a Mage and the Toolkit's
  `CombatLogUsable()` (an API gate; Forever refuses the log, so no Forever
  chime and no rows: the lead holds Forever for John's answer to question
  2; Forever's only path is `C_UnitAuras.AddAuraSound`, one fixed sound per
  trigger (Added, ApplicationsIncreased), no stack condition, no source
  filter, so it cannot rise and another Mage's debuff may chime: the lead
  accepted that note for when it is built). The log is registered only
  while `db.wintersChill.chime` is on and DBR is not loaded at a version
  older than 1.13.3 (or unreadable): then one login line ("The Winter's
  Chill chime waits") and no second chime (lead's answer 4).
  `db.wintersChill.chime` (true) and `noteSet` ("bassoon"), in SanitizeDB
  and the profile. Rows (only where the chime is usable): "Stack chime",
  "Note set" (a pick plays its held note), "Test chime" (1 at once, 2-5 by
  C_Timer, 0.3 s apart); Reset Winter's Chill resets them too. `/ddt debug`
  has a `chime` line. The import `DDT.ImportChillChime` (Core.lua; the
  ImportFromTools rules): once per character (`db.chimeImported`, in the
  profile; a profile copy sets it), Mage only, from
  `DyresBuffRemindersDB.wintersChill` = {enabled, noteSet} (per character,
  DBR's TOC; DBR 1.13.3 keeps it as saved for one release), read only,
  DBR's rules (`enabled ~= false`; noteSet only bassoon or sax); waits
  while DBR older than 1.13.3 is loaded; DBR not loaded: done. TOC
  `## OptionalDeps: DyresToolkit, DyresSounds` (load order only).
- Frozen and chilled arcs, Mage only (John, 2026-11-18: "a frozen/icy arc
  above the chilled and frozen mobs nameplates (2 different looking
  visuals, I think a mob can be both frozen and chilled)"; lead's spec the
  same day). Frost.lua, `DDT.CreateFrostArcs(toolkit, store)`, made in
  `DDT.Start` for a Mage before the Tools AddOn check (no other AddOn draws
  them, so also while MTF has the DoTs; never greyed). Each enemy plate gets
  a holder with one Toolkit `CreateAuraContainer` and three HARMFUL slots
  whose `includeSpellIDs` are sets (a list matches nothing in client):
  `frozen`, filter `HARMFUL` (any source: Shatter works on every Frozen
  target), `chilled`, filter `HARMFUL|PLAYER` (Frostbite and Fingers of
  Frost proc from "your Chill effects", TFB), and `chilledArmor`, filter
  `HARMFUL`, for Frost Armor's and Ice Armor's Chilled (6136, 7321), drawn
  with the chilled arc in the same place (John, 2026-11-19, in client on
  Forever: a mob had Chilled 6136 and the PLAYER slot showed no arc, while
  the frozen slot worked; the game seems not to count you as that chill's
  source; the cost is that another Mage's armor chill shows it too). The engine shows the slots'
  buttons; the arcs (Textures/FrozenArc.tga, ChilledArc.tga, 256 x 64, made
  by scripts/make_artwork.py --arcs, our own art) are set up only in
  `initializeFrame`. No AddOn code reads an aura. As the Toolkit's
  PlateDots: holders pooled, parented to the plate on NAME_PLATE_UNIT_ADDED
  (also in combat), given back on NAME_PLATE_UNIT_REMOVED; ten made ahead
  out of combat (`DDT.FROST_PREWARM`, again at PLAYER_REGEN_ENABLED), and
  one made in combat only when the pool runs dry, as PlateDots does. Placed
  on `FindPlateBar`'s bar, else the plate, and again after a `C_Timer.After
  (0)` (DotPredict's rule for plate AddOns). Shown only on a unit you can
  attack (UNIT_FLAGS). `db.frost` = {enabled (true), offset (0 to 60, 10),
  size (50 to 200, 100)}, repaired in SanitizeDB; in the profile (the
  refresh calls `DDT.RefreshFrost`). The IDs and their sources are in
  Frost.lua and TESTING.md; no Water Elemental Freeze and no Frostfire Bolt
  chill (no local source). `/ddt debug` has a `frost` line
  (`arcs:DebugLines`; John, 2026-11-19, after he saw no arcs in client): on,
  the engine kind, holders, plates, shown (a mob you can attack), visible
  (the plate and its parents show too), and anchors (FindPlateBar's adapter
  per holder, else `plate`). It reads only our own holders, never an aura or
  an engine button. Not a Mage: `frost none (Mage only)`; a Mage whose
  client lacks a part: `frost off: this client lacks ...`.
- The Warlock move from WTF (John, via the lead, 2026-11-20: "Users of WTF
  should manage their DoT tracking features in DDT. The WTF DoT's settings
  pages should simply redirect users to DDT ... This includes DoT Colors,
  tracker panels, etc."; "Yes, full move"). DDT is the one home of the
  Warlock's DoT tracker, prediction, and control bar; MTF stays as it is.
  - Parity: every setting on WTF's DoT Tracker, DoTs, and Control pages has
    a DDT row (the "WTF parity" tests list them): each look's sizes and name
    position (`DDT_DOTS_<LOOK>_<KEY>`, shown only for the chosen look, with
    Reset size; a change sets `dots.trackerSize = false`, so no percent
    overwrites them, and Tracker size then shows the nearest percent), the
    plate dots' offset and opacity, each panel's color (`dots.panelColors`,
    WTF's defaults, `DDT.PANEL_COLORS`) and opacity, each slot's place
    (`DDT_DOTS_ORDER_<n>`, a pick swaps), color (`dots.colors`, AARRGGBB, the
    slot's ClassData color by default) and nameplate dot, Reset order and
    colors, the curse slot (Warlock: `dots.curseMode` "last"/"smart",
    `dots.curseMarker`), and the block's fill, opacity, and outline. The
    tracker gets `slotColor`/`panelColor` (`DDT.SlotColor`, `DDT.PanelColor`,
    read live). Left out: WTF's "How Fear and your focus work" chat button
    (help text, not a setting) and WTF's announcement page (part 4 below).
  - The smart curse: the tracker's `names.smartCurse` =
    "DyresDebuffTrackerSmartCurse" (Warlock only), Bindings.xml (CLICK
    binding, header DYRESDEBUFFTRACKER, "Smart curse (Warlock)"), and "! Curse"
    (`DDT.ApplyCurseMacro`): a Toolkit macro keeper sharing
    `db.macrosOwned`, written only while DDT owns `dots:WARLOCK` and
    `control.macros` is on (OnOwnerChanged reapplies it); deleted when the
    macros are off or Weakness is unknown (only one DDT wrote).
  - The import (`DDT.ImportFromTools`, Core.lua, from `DDT.Start` after the
    profile joins and before the engines; DBR 1.13.0's model): once per
    character (`db.toolsImported`, in the profile; a profile copy sets it),
    from the class's Tools AddOn (`DDT.TOOLS_IMPORT`: Warlock from
    `WarlockToolsForeverDB`, Mage from `MageToolsForeverDB`; read only; deep
    copies). It waits (not marked) while that AddOn is loaded at a version
    older than its handover (WTF 1.11.0, MTF 1.6.0) or unreadable: the
    older one still claims and its values can still change. Not loaded:
    marked done. WTF (keys `DDT.WTF_KEYS`, the WTF session's
    wtf-1.11.0-ddt-import-keys.md): a part wins only where WTF had it on
    (`tracker.enabled`, `predict.enabled`, `control.enabled` not false): its
    claim at 10 then beat DDT's 5, so DDT's values were never used; with it
    off DDT's part showed, so DDT's stay. The macros and markers always come
    (WTF owned `macros:WARLOCK` whatever its bar switch), and so do the
    Fear, Banish, Enslave, and Howl messages (`announce.<x>Group` and the
    master `announce.enabled`) and texts (WTF's credit suffix becomes
    DDT's), and Say (`announce.channel`). WTF's sizes set `trackerSize =
    false`. MTF (`DDT.MTF_KEYS`, MTF 1.5.1's `db.polymorph`, kept raw by
    1.6.0): the bar's enabled, position, scale, opacity, width, height (DDT
    `barHeight`), textScale while MTF's bar was on; `macro` -> `macros` and
    `mark` false -> `markers.polymorph = 0` always; `announce.polymorphGroup`
    (only while MTF's bar was on, as MTF sent it) and `polymorphGroupText`.
    One chat line when something came (MTF says its own line too).
  - The Smart curse key (`DDT.MoveCurseBinding`, Warlock, each login through
    the Toolkit's `OutOfCombat`): while `CLICK
    WarlockToolsForeverSmartCurse:LeftButton` has a key and DDT's `CLICK
    DyresDebuffTrackerSmartCurse:LeftButton` none, each key is set to DDT's
    (`SetBinding`, then `SaveBindings(GetCurrentBindingSet())`), with one
    line. It runs at the first DDT login, while WTF 1.10.x still defines its
    binding (WTF 1.11.0 removes it; whether the client keeps an undefined
    command's key is not verified).
  - Macros: the Toolkit keeper adopts an existing macro by name with
    `EditMacro` at the same index, so action bar slots keep it ("keeps your
    macro now", once); a test checks the index.
  - The control bar's look, every class (MTF's Polymorph settings):
    `db.control.width` 120-400 step 10 (200), `barHeight` 10-40 (16),
    `textScale` 50-200 step 5 (100), `opacity` 10-100 step 5 (100)
    (`DDT.CONTROL_LOOK`, `DDT.CONTROL_OPACITY`), repaired in SanitizeDB, in
    the profile. `DDT.ControlLook()` is the engine's `look`; the widget
    shows the sliders (AddWidgetSettings), measures the frame from them,
    and a change applies the look at once and rebuilds the slots once the
    slider rests (0.2 s, MTF's rule). The defaults draw the Toolkit's own
    look. A class's own behavior: `DDT.CONTROL_CLASS` (Mage: MTF 1.5.1's
    one row, purple, label, find order, locks, countdown, clickThrough,
    fixedClick "polymorph").
  - Ownership: DDT keeps priority 5 and still steps aside for a WTF that
    claims at 10, in either load order (the claims decide); the next WTF
    claims nothing, and DDT owns every Warlock kind.

## Dyre's Toolkit (required, through OptionalDeps)

- TOC `## OptionalDeps: DyresToolkit` (family rule, coordinator 2026-10-30:
  never `## Dependencies`, so the AddOn always loads and says once what to
  install; CurseForge will mark the toolkit required) and
  `## Group: DyresToolkit`. Core's `DDT.Toolkit()` is
  `DyresToolkit.RequireContract(2)` with every function in
  `DDT.TOOLKIT_FUNCTIONS` checked. Without them it stays off and says once:
  "needs Dyre's Toolkit 2.9.1 or later", naming only CurseForge. A readable
  Toolkit TOC version under 2.9.1 (`DDT.TOOLKIT_VERSION`) counts as missing:
  2.9.1 holds every class table and the finisher and late-start prediction,
  and its contract is still 2. An unreadable version is let through.
- No byte-for-byte copy tests of toolkit files (John, 2026-10-30): the
  suite loads ../DyresToolkit when it is there, else (CI, or
  DDT_TOOLKIT_COPY=1) the copy of Toolkit v2.10.2 in tests/toolkit. The copy
  may lag; refresh it from the Toolkit's release tag when DDT needs newer
  toolkit behavior.
- Use the toolkit's shared code; never copy it here: `CreateAuraContainer`
  (Auras.lua), `ReadGUID`/`FindUnit`/the plate memory/`LockCast`/focusWorks
  (Units.lua), `FindPlateBar`/`FindUnitBar`/`DrawPrediction`/`MoveDies`
  (HealthBars.lua), and widgets for every movable frame (no Layout.lua
  here). Code that two Dyre's AddOns need goes into the toolkit first; the
  coordinating session owns it (`src/DyresToolkit`): ask there.
- focusWorks is one flag for the whole family (`DyresToolkitDB.focusWorks`).

## Standing rules

- Event-driven only: no polling, no idle OnUpdate.
- No popups in combat.
- Never call SetRaidTarget. Marking happens only through `/tm` in macros.
- Lua 5.1. Never compare, print, or index a value that may be secret; gate
  on APIs, never on the client version.
- One package for both clients: `## Interface: 16001, 11509` (WoW: Forever
  and Classic Era 1.15.9).
- Add focused tests for every change (tests/run.lua, Lua 5.1 mocks; it loads
  the toolkit's real files from ../DyresToolkit, else tests/toolkit).
- Never commit, tag, push, or release; the coordinator does that only when
  John says "ship it". No Claude or Anthropic attribution anywhere.
- Install test builds only into
  `C:\Games\WoW\World of Warcraft\_forever_\Interface\AddOns` and
  `_classic_era_\Interface\AddOns` (never `_classic_beta_`), and cmp-check
  them. Install only the TOC, the Lua files the TOC lists, Bindings.xml, the
  Textures (Icon.tga, FrozenArc.tga, ChilledArc.tga, BrandPentagram.tga,
  BrandGlow.tga, ChillBall.tga, ChillBalls.tga), and LICENSE. It needs Dyre's Toolkit 2.9.1 installed beside it.

## Project structure

- Runtime: DyresDebuffTracker.toc, Core.lua, Engines.lua, Frost.lua,
  Chime.lua, Options.lua (loaded in that order), Bindings.xml (the smart curse key
  binding; the client loads it by name), Textures/Icon.tga (the TOC icon), and
  Textures/FrozenArc.tga and ChilledArc.tga (the Mage's arcs),
  BrandPentagram.tga and BrandGlow.tga (the Warlock's Demonic Brand), and
  ChillBall.tga and ChillBalls.tga (the Mage's Winter's Chill balls).
- scripts/make_artwork.py: makes the logo (SVG, rendered to PNG with headless
  Chrome as the family's logos are), Textures/Icon.tga, the arcs
  (`--arcs`, plain Python), and the listing screenshot crops. Change the art there, not in its outputs; see
  artwork/README.md.
- docs/CURSEFORGE_LISTING.md: the listing text; artwork/: the logo, John's
  raw screenshots, and the crops.
- Release: scripts/build_release.py (the ZIP, its sha256 sidecar, the
  manifest, release notes from the version's CHANGELOG.md section, and
  WowUp's release.json), publish_curseforge.py (relation: Dyre's Toolkit
  required; no Dyre's Sounds), verify_release.py, curseforge_versions.py;
  their tests in tests/test_*.py (`python -m unittest discover -s tests -p
  "test_*.py"`); .github/workflows/release.yml and gate-check.yml (the
  `release` environment). README.md (with the Ko-fi section) and
  CHANGELOG.md (`## version`, then `### Features` / `### Fixes` /
  `### Other changes`).
- TESTING.md: the automated checks and the in-client checklist (the class
  spells' unchecked IDs and durations).
- tests/run.lua: the Lua 5.1 mock suite. Run it from this folder:
  `../WarlockToolsForever/.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/lua5.1.exe tests/run.lua`.
- LICENSE: MIT, 2026 John Bedworth.
