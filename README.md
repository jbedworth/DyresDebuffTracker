# Dyre's Debuff Tracker

**Dyre's Debuff Tracker** shows the DoTs you have up on every mob and tells
you when they will kill. A striped block on the mob's health bar shows the
damage your DoTs still have to deal. A red skull says **DIES** when that is
enough to kill it. It also keeps your crowd control on timers, with control
macros and an optional message to your group.

For World of Warcraft Classic Era and Anniversary, and WoW: Forever (see
Compatibility).

## The DoT tracker

- A row for your target, one for your focus, and rows for the other mobs you
  DoTed. Each row has a timer bar per DoT, in its own color.
- Two looks: **Compact** and **Bars**. **Tracker size** (75% to 125%) sets
  the length of the bars, or the size of the icons in Compact. Optional mob
  health, as a number, a percent, or both.
- **Grow**, per panel (Target, Focus, Others): Down (the default) or Up. Up
  puts the first DoT where you placed the panel and the next ones above it,
  for a panel above your target frame; the Others list stacks new mobs
  upward. It needs a Dyre's Toolkit that has grow directions (2.9.2 or
  later); with an older one the settings do not show.
- Optional dots on nameplates: one per DoT, colored while it is up.

## Damage to come, and DIES

- A striped block on the mob's health bar, as wide as the damage your DoTs
  still have to deal: on your target frame, on nameplates, and on the
  tracker's rows.
- **DIES** and a red skull when that damage is at least the health left.
  Pick its place on the target frame and on nameplates, or leave it on Auto.
- It learns each DoT's real tick as it ticks (your talents, spell power,
  and resists included) and remembers it for your next cast. A new DoT shows
  its damage to come after its first ticks.
- Rupture and Rip use the combo points you spent. On WoW: Forever the game
  can hide your combo points in combat; then they count as 1 point, so the
  block errs low.

## Crowd control

- A timer bar for each mob you control, with its name and time left. It
  empties if the spell breaks early.
- Optional timers under each controlled mob's nameplate.
- Macros kept for you once you know the spell: **"! Fear"**, **"! Banish"**,
  **"! Seduction"**, **"! Polymorph"**, **"! Hibernate"**, **"! Shackle"**,
  **"! Sap"**, and **"! Repentance"**. Each casts on the mob under your
  mouse, else your target. A marker spell's macro puts the raid marker you
  pick on the mob (through `/tm`).
- **Tell your group**: a party or raid message as you cast, per spell, off
  by default. "Say" is an option.

## Classes

| Class | DoTs | Crowd control |
| --- | --- | --- |
| Warlock | Your curse, your Bane (Agony, Doom, or Havoc on WoW: Forever; Curse of Agony on Classic Era), Corruption, Immolate, Siphon Life | Fear, Banish; Enslave Demon and Howl of Terror (message only) |
| Mage | The DoT parts of Fireball, Pyroblast, and Frostfire Bolt | Polymorph |
| Druid | Moonfire, Insect Swarm, Entangling Roots, Rake, Rip, Pounce, Lacerate | Hibernate, Entangling Roots |
| Hunter | Serpent Sting, Immolation Trap | Scare Beast, Wyvern Sting, Freezing Trap (message only) |
| Priest | Shadow Word: Pain, Devouring Plague, Holy Fire | Shackle Undead, Psychic Scream (message only) |
| Rogue | Rupture, Garrote | Sap, Blind |
| Shaman | Flame Shock | none |
| Warrior | Rend | Intimidating Shout (message only) |
| Paladin | none | Turn Undead, Repentance |

**Tested in game:** Hunter's Serpent Sting on WoW: Forever (John,
2026-11-14). The Warlock and Mage parts are the same engine code as Warlock
Tools Forever's and Mage Tools Forever's. **Not yet checked in game:** every
other class spell above, its spell IDs, and its durations. TESTING.md lists
what is still to check.

A class Tools AddOn wins for its own class: with Warlock Tools Forever or
Mage Tools Forever on, that AddOn shows its class's trackers, and this
AddOn's pages say so.

## Commands

- `/ddt`: the settings (also under Options > AddOns > Dyre's AddOns >
  Debuff Tracker). Two pages, **DoTs** and **Crowd control**, each with its
  own Enable.
- `/ddt reset`: the frames go back to their default places.
- `/ddt reset_focus`: checks the focus target again for all of Dyre's
  AddOns.
- `/ddt debug`: what the trackers see.
- `/debufftracker` works the same, in case another AddOn uses `/ddt`.

Frames move with Dyre's Toolkit's layout mode.

## Requirements

- **Dyre's Toolkit 2.9.1 or later** (required). The class tables, the DoT
  and crowd-control engines, and the prediction (with combo-point finishers
  and late-starting DoTs) are in the toolkit, and 2.9.1 is the first with
  every class. With an older toolkit, or none, this AddOn stays off and says
  once what to install. The CurseForge app installs the toolkit with it.

## Compatibility

- **Classic Era and Anniversary**: from the combat log.
- **WoW: Forever**: the combat log is closed to AddOns there, so damage to
  come is an estimate, from the spell's tooltip or after a fight's damage
  meter. Bleeds share the physical school with melee swings there, so a
  bleed can show for a short time after it ends.
- Health bars: Blizzard's frames, Shadowed Unit Frames, BetterBlizzFrames,
  Threat Plates, Plater, and Platynator, through Dyre's Toolkit.

## Support

Dyre's Debuff Tracker is free. If you enjoy it, you can support its
development on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT License, Copyright (c) 2026 John Bedworth. The logo and icon are
original art under the same license.
