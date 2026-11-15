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
  (`DDT.ApplyTrackerSize`, at every SanitizeDB and slider change); the name
  width, line height, and text scale stay. The slider ("Tracker size" on
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
  size (DDT has no name position setting on its pages; `namePosition` is
  only saved), each calling the tracker's `Rebuild` (out of combat, else at
  combat's end). Shown only when `TRACKER_GROW` exists (Toolkit 2.9.1 lacks
  it); the saved value is kept and repaired either way.
  `DDT.TOOLKIT_VERSION` stays 2.9.1: the gate hides only the Grow settings
  on 2.9.1, and the rest works (lead, 2026-11-14, at the 2.9.2 release).
- Not built yet: the other DoT sizes, panel opacity and colors, DoT order, and
  announcement text editors (the engines read them from the store; the
  defaults are WTF's), and the in-client check.

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
  DDT_TOOLKIT_COPY=1) the copy of Toolkit v2.9.2 in tests/toolkit. The copy
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
  them. Install only the TOC, the Lua files the TOC lists, Textures/Icon.tga,
  and LICENSE. It needs Dyre's Toolkit 2.9.1 installed beside it.

## Project structure

- Runtime: DyresDebuffTracker.toc, Core.lua, Engines.lua, Options.lua
  (loaded in that order), Textures/Icon.tga (the TOC icon, the one runtime
  texture).
- scripts/make_artwork.py: makes the logo (SVG, rendered to PNG with headless
  Chrome as the family's logos are), Textures/Icon.tga, and the listing
  screenshot crops. Change the art there, not in its outputs; see
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
