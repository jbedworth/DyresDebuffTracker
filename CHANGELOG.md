# Changelog

## 1.2.0

### Features

- Hide empty DoT slots: a new checkbox on the DoTs page (off by default).
  A DoT shows only while it is on the mob. The empty places stay, so the
  DoTs do not move. The target and focus rows then do not recast a DoT when
  you click them. It needs a Dyre's Toolkit with this option (newer than
  2.10.2); with an older one the checkbox does not show.
- Your Debuff Tracker settings, frame places, and sizes are now part of
  your Dyre's Toolkit profile: copy them from another character (or the
  defaults), and export or import them as text, on the Toolkit's settings
  page. They apply at once, with no reload. Your control macros and the
  spell each pinned slot last cast stay with each character. This needs
  Dyre's Toolkit 2.10.0 or newer; with an older one, nothing changes.

## 1.1.1

### Features

- Warrior: Hamstring on the crowd-control bar, one bar per mob, so you
  see each slowed mob's time left. It needs a Dyre's Toolkit with
  Hamstring in its Warrior table (2.10.2 or newer).
- Druid: Entangling Roots already shows one bar per rooted mob; a test
  now checks it.

## 1.1.0

### Features

- Tracker size: a slider on the DoTs page, from 75% to 125% (default
  100%). It sets the length of the DoT bars in the Bars look and the size
  of the DoT icons in the Compact look; one setting for both. A change in
  combat applies when combat ends.
- Grow: Down or Up for each DoT panel (Target, Focus, and Others), on the
  DoTs page. Up puts the first DoT where you placed the panel and the next
  ones above it (Bars look), and the Others list stacks new mobs upward.
  The name keeps its place. Needs Dyre's Toolkit 2.9.2 or later;
  with an older one the settings do not show.

## 1.0.1

### Features

- First public release. Needs Dyre's Toolkit 2.9.1 or later.
- The DoT tracker: rows for your target, your focus, and other mobs you
  DoTed, with a timer bar per DoT, mob health, and optional dots on
  nameplates.
- Damage to come: a striped block on the mob's health bar (target frame,
  nameplates, and the tracker's rows) and a red skull with DIES when your
  DoTs will kill it, with its place on the target frame and nameplates.
- Crowd control: a timer bar per controlled mob, optional nameplate timers,
  control macros ("! Fear", "! Banish", "! Seduction",
  "! Polymorph", "! Hibernate", "! Shackle", "! Sap", "! Repentance"), and
  optional party or raid messages.
- Every class with DoTs or crowd control: Warlock, Mage, Druid, Hunter,
  Priest, Rogue, Shaman, Warrior, and Paladin, from Dyre's Toolkit's class
  tables. Rupture and Rip use the combo points you spent. Serpent Sting,
  Fireball, Pyroblast, and Frostfire Bolt keep their DoT after a long
  flight.
- Hunter's Serpent Sting is tested in game on WoW: Forever. The Warlock and
  Mage parts are Warlock Tools Forever's and Mage Tools Forever's engine
  code. The other class spells, their IDs, and their durations are not yet
  checked in game.

### Other changes

- With Dyre's Toolkit older than 2.9.1, the AddOn stays off and says once
  to update it.
- A class Tools AddOn (Warlock Tools Forever, Mage Tools Forever) wins for
  its own class.

## 1.0.0

### Other changes

- Released on GitHub only; its CurseForge upload did not run. 1.0.1 is the
  same AddOn.
