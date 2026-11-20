# Verification and test plan

How Dyre's Debuff Tracker is checked: the automated suites, and what John
checks in the client. Mock tests do not prove in-client behavior.

## Automated checks

- `tests/run.lua` (Lua 5.1 mocks), run from this folder:
  `../WarlockToolsForever/.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/lua5.1.exe tests/run.lua`.
  It loads Dyre's Toolkit's real files from `../DyresToolkit`, else (CI, or
  `DDT_TOOLKIT_COPY=1`) the Toolkit v2.10.2 copy in `tests/toolkit`.
- The release tooling's Python tests: `python -m unittest discover -s tests
  -p "test_*.py"`, and `python scripts/build_release.py --output dist`.
- Dyre's Toolkit's own suite (`../DyresToolkit/tests/run.lua`) holds the
  class data and prediction engine tests: one row per new spell (IDs,
  durations, tick intervals, flags) and the finisher, late-start, mask,
  trap, and no-base-damage cases.
- `luac5.1 -p` on every Lua file.

## In-client checks: frozen and chilled arcs (Mage)

The IDs come from local sources only (Frost.lua names them):
TalentsForeverBook's Data.lua (Forever beta 1.60.1.70755) for the ranks, and
LibClassicDurations' classAbilities.lua (Era) for the debuff IDs.

- [ ] Frozen (any Mage, filter `HARMFUL`): Frost Nova 122, 865, 6131, 10230;
      Frostbite's freeze 12494. On Forever, check that Frostbite's freeze
      still has ID 12494.
- [ ] Chilled (yours only, filter `HARMFUL|PLAYER`): Frostbolt 116, 205,
      837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304; Cone of Cold
      120, 8492, 10159, 10160, 10161; Improved Blizzard 12484, 12485, 12486.
      Does Frostbolt's slow on Forever show the frost arc? If not, note the
      debuff's name and ID (its tooltip on a nameplate AddOn's icon).
- [ ] Armor chill (any source, filter `HARMFUL`, its own slot): Frost Armor
      and Ice Armor "Chilled" 6136, 7321. Seen on Forever (2026-11-19): 6136
      showed on a mob and the `HARMFUL|PLAYER` slot drew nothing. Let a mob
      hit you with Frost Armor up: the frost arc shows.
- [ ] Not in the lists, for want of a local source: the Water Elemental's
      Freeze (if Forever has one), a Frostfire Bolt chill (does its debuff,
      401502, 1237312, 1237313, slow the mob?), and Forever's own Frostbolt
      ranks or a Frostbolt debuff with a new ID. Note any ID you see on a
      frozen or chilled mob that is not above.
- [ ] First, with enemy nameplates on and a mob in view: `/ddt debug`. The
      `frost` line shows `on=true`, `plates` at least 1, `shown` for each mob
      you can attack, `visible` the same as `shown`, and in `anchors` the
      nameplate AddOn you use (for example `EllesmereUI=1`), else `plate`.
      `visible` under `shown` means a nameplate AddOn hides the Blizzard
      plate the arcs sit on. `frost off: this client lacks ...` names what is
      missing.
- [ ] Out of combat and in combat, on Forever and on Era: Frostbolt a mob,
      then Frost Nova it. The frost arc shows, and the ice-crystal arc shows above
      it. Each goes when its debuff ends. No Lua error.
- [ ] Another Mage's Frost Nova shows the ice-crystal arc; another Mage's
      Frostbolt does not show the frost arc.
- [ ] Pull more than ten mobs in combat: every hostile plate gets its arcs.
      Friendly plates get none.
- [ ] With Plater, Threat Plates, Platynator, or EllesmereUI: the arcs sit just above
      their health bar. With Blizzard's plates: above Blizzard's bar.
- [ ] "Arc height", "Arc size", and the switch apply at once. A Warlock or
      other class has no "Frozen and chilled" rows.

## In-client checks: panel switches

- [ ] With the Toolkit's panel change: the DoTs page shows "Show Target
      panel", "Show Focus panel", and "Show Others panel", all on. DoT your
      target, your focus, and a third mob. Turn off the Target panel: it
      goes at once, and Focus and Others stay. Do the same for Focus and
      Others. Turn each on again: it comes back. Also with the frames
      unlocked (samples): a panel that is off does not show.
- [ ] Turn off a panel in combat: no Lua error; it hides when combat ends
      at the latest.
- [ ] The switches follow the Toolkit profile (Copy settings from, Export
      and Import).
- [ ] With Dyre's Toolkit 2.10.2: the checkboxes do not show, and all three
      panels work as before.

## In-client checks: Hide empty DoT slots

- [ ] With the Toolkit's hide-empty change: turn on "Hide empty DoT slots"
      on the DoTs page. Know two DoTs, put one on your target: one slot
      shows, and the other place stays empty (no dim icon, no bar line or
      label). In combat, cast the second DoT: it shows in its own place, and
      nothing moves. Click the target and focus rows: nothing is cast. Turn
      it off: the dim icons and the recast clicks come back (out of combat).
- [ ] With Dyre's Toolkit 2.10.2: the checkbox does not show.

## In-client checks: the profile (Toolkit 2.10.0)

- [ ] On character A, change DDT settings (theme, Tracker size, Grow, a
      panel's place, the control bar's scale, a marker, an announce text).
      On character B (also another class), use the Toolkit page's "Copy
      settings from" A, then Copy: the DoT panels and the control bar move
      and resize at once, with no reload and no error; the DoTs and Crowd
      control pages show A's values. B's own "! ..." macros stay, and B's
      pinned Curse and Bane slots still recast B's last spells. A Warlock's
      DoT order copied to a Druid shows the Druid's slots.
- [ ] "Copy settings from" Defaults: every DDT setting goes back to its
      default, at once.
- [ ] Export profile, change a DDT setting, Import profile with the line:
      the setting comes back, at once.
- [ ] With Dyre's Toolkit 2.9.x: DDT works as before, with no error.

## In-client checks: the class spells (the class gate, 2026-11-14)

Every spell ID added for Druid, Hunter, Priest, Rogue, Shaman, Warrior,
Paladin, and Mage's DoTs is copied from a local file (the sources are in
Dyre's Toolkit's ClassData.lua head) and **not yet checked in client**. Each
class table's `checks` holds the same list.

For each ID: `/dump C_Spell.GetSpellName(id)` must give the name below, on
the client named. For a debuff, also read the aura's spell ID on the mob
(`/ddt debug` lists the slot IDs; the aura's own ID shows in any aura
tooltip AddOn) and its duration.

### Forever only: IDs and durations with no source

| Class | Spell | IDs | Check |
| --- | --- | --- | --- |
| Druid | Lacerate | 414644, 1235826, 1235827 (trainer, G2G-F); 1328616, 1328617, 414647 (WT group; 1328617 is TFB's talent) | Which ID the debuff shows; its duration; its tick interval (3 s assumed). With no tooltip duration, it gets no prediction. |
| Mage | Frostfire Bolt | 401502, 1237312, 1237313 (G2G-F) | The name; the debuff ID; its duration; its tick interval (3 s assumed); on a hit, `/ddt debug` shows its ticks counting ("tick N of M"), which needs UNIT_COMBAT school 20 (Fire + Frost, from Does It Die). |
| Hunter | Wyvern Sting | 24335 (G2G-F) | The name; the debuff ID; its duration (12 s on Era). |
| Rogue | Blind | 2094 | In Good-to-Go's class list, not a trainer spell there: is it learnable, and is the ID the same? |
| Paladin | Repentance | 20066 | TalentsForeverBook says "moved": the name and its duration. |
| Mage | Pyroblast | 11366 | TalentsForeverBook says "changed": the debuff ID and duration. |
| Priest | Devouring Plague | 2944 | A trainer spell at 20 on Forever (WT Camelot); the Undead racial on Era. |

### Debuff IDs assumed the same as Era's

| Class | Spell | IDs (LCD) | Check |
| --- | --- | --- | --- |
| Druid | Pounce Bleed | 9007, 9824, 9826 | The bleed's own debuff IDs on Forever. |
| Hunter | Immolation Trap | 13797, 14298, 14299, 14300, 14301 (the casts are 13795, 14302-14305) | The debuff IDs on Forever. |
| Paladin | Turn Undead | 2878, 5627, 10326 | Rank 3 is 10326 (G2G-F); LCD lists 5627 twice. |

### Durations

Every new spell's Forever duration is Era's (LibClassicDurations) until
checked. One rank each is enough when the ranks share a duration:

- Druid: Moonfire 8921 (9 s; 12 s from rank 2), Insect Swarm 5570 (12),
  Entangling Roots 339 (12, up to 27 at rank 6), Rake 1822 (9), Rip 1079 (12
  at any combo points), Pounce Bleed (18), Hibernate 2637 (20/30/40).
- Hunter: Serpent Sting 1978 (15), Immolation Trap (15), Scare Beast 1513
  (10/15/20), Wyvern Sting (12), Freezing Trap (10/15/20, +15% per Clever
  Traps rank).
- Mage: Fireball 133 (4; 143 and 145: 6; later 8), Pyroblast 11366 (12).
- Priest: Shadow Word: Pain 589 (18, +3 per Improved rank), Devouring
  Plague 2944 (24), Holy Fire 14914 (10), Shackle Undead 9484 (30/40/50),
  Psychic Scream (8).
- Rogue: Rupture 1943 (6 + 2 per combo point), Garrote 703 (18), Sap 6770
  (25/35/45), Blind 2094 (10).
- Shaman: Flame Shock 8050 (12).
- Warrior: Rend 772 (9/12/15/18/21), Intimidating Shout 5246 (8), Hamstring
  1715 (15; ranks 7372, 7373).
- Paladin: Turn Undead 2878 (10/15/20), Repentance 20066 (6).

### Behavior to see in client

- Tracker size (DoTs page): at 75% and 125% the Bars rows are 218 and 363
  px wide (290 at 100%), and Compact's icons 17 and 28 px (22). The rows
  follow at once out of combat; a change in combat applies when combat
  ends, with no error. A theme switch keeps the percent. The slider shows
  "N%" and the gold default mark at 100%.
- Grow (DoTs page, needs the Toolkit's grow change): Bars look, place the
  Target panel just above the target frame, set "Grow: Target" to Up, and
  DoT your target with two or more DoTs. The first DoT is the lowest line,
  where the panel was placed; the next ones are above it; the name stays
  where its position puts it. Down gives the old order again. "Grow:
  Others" Up: new mobs' rows stack upward. A change in combat applies when
  combat ends. With Toolkit 2.9.1 the three Grow settings do not show.

- Each class: the DoT tracker shows its slots, the crowd-control bar shows
  its bar spells, and the marker spells' macros are written ("! Hibernate",
  "! Shackle", "! Sap", "! Repentance"). Paladin has no DoT tracker; Shaman
  has no crowd-control bar; Warrior's bar shows Hamstring and only announces
  Intimidating Shout.
- Hamstring (Warrior) and Entangling Roots (Druid) on two mobs: two bars,
  one per mob, each with its own time left (15 s for Hamstring). A recast
  on the same mob keeps its bar. A Warrior's Focus box shows Hamstring.
- Prediction: a new DoT shows no damage to come until its first tick on
  Era (no base damage in the data, lead decision 5a); on Forever, from its
  tooltip when the tooltip reads, else after a fight's damage meter.
- Finishers: Rupture's and Rip's damage to come uses the combo points at the
  cast. On Forever the points may be hidden in combat: then it uses 1
  point (it errs low). `/ddt debug` says "points N" or "points unknown".
- Late starts on Forever: Serpent Sting, Fireball, Pyroblast, and Frostfire
  Bolt keep their DoT after a long flight (not dropped as missed ticks).
  - Serpent Sting: John, 2026-11-14, Forever, his Hunter: "I can report that
    DDT is working for Hunter's Serpent Sting". The ID, duration, and
    prediction amount are not noted as checked one by one.
- Immolation Trap: on Forever no damage to come from the trap (no mob at
  the cast); on Era it starts when the trap's debuff lands.
- On Forever, bleeds (Rake, Rip, Pounce, Lacerate, Rupture, Garrote, Rend)
  share the physical school with melee swings: watch for a bleed kept after
  it ended.
