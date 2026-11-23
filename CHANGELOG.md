# Changelog

## 1.6.0

### Features

- **Winter's Chill** (Mages, both clients): five blue frost balls above an
  enemy's nameplate while your Winter's Chill is on it. One more ball turns
  white with each stack, up to 5, as combo points. The game lights the
  balls, so they work in combat. Only your own Winter's Chill shows. On by default. "Winter's Chill" on the DoTs page:
  **Show**, **Size** (50% to 200%), **Height above nameplate** (0 to 60
  pixels; the default 36 sits above the frozen and chilled arcs),
  **Preview** (or `/ddt preview chill`: three of five balls white on your
  target's nameplate, to set the size and height), and **Reset Winter's
  Chill**. On Classic Era the balls count stacks with Dyre's Toolkit 2.11.0
  or later; with an older Toolkit only the first ball turns white. After
  you install this version, restart the game (not only /reload): the game
  loads new image files only at start.
- **Winter's Chill stack chime** (Mages, Classic Era): a note as each stack
  of your Winter's Chill goes on a mob, rising from 1 to 4, and a held high
  note at 5, only on your target, as the combo point chimes. A stack that
  drops, the debuff ending, or your chill on another mob plays nothing.
  Another Mage's Winter's Chill does not chime. On by default. In the
  "Winter's Chill" section: **Stack chime**, **Note set** (Bassoon or Sax),
  and **Test chime**. It needs Dyre's Sounds. This chime moves here from
  Dyre's Buff Reminders, which removes its own in 1.13.3. Your Dyre's Buff
  Reminders chime settings (on or off, and the note set) are copied here
  once, and a chat line says so. While an older Dyre's Buff Reminders is
  loaded, this chime waits, so you never hear two, and one chat line says
  to update it. WoW: Forever has no chime yet.

## 1.5.0

### Features

- **Demonic Brand** (Warlocks, WoW: Forever): a glowing red pentagram above
  an enemy's nameplate while your Demonic Brand is on it. Your Searing Pain
  puts the Brand on; recast it when the pentagram goes. Only your own Brand
  shows, because only your demon uses it. On by default. "Demonic Brand" on
  the DoTs page: **Show**, **Size** (50% to 200%), **Height above
  nameplate** (0 to 60 pixels), **Preview**, and **Reset Demonic Brand**.
  Changes apply at once. **Preview** (or `/ddt preview brand`) shows the
  pentagram on your target's nameplate with no Brand on it, so you can set
  the size and height; press it again, or change target, to end it.
  Classic Era has no Demonic Brand, so nothing changes there. After you
  install this version, restart the game (not only /reload): the game loads
  new image files only at start.
- Every slider on the settings pages has a gold mark at its default value,
  so you can see where the default is.

## 1.4.0

### Features

- The DoTs page has a **Panels** section with one part each for the
  **Target**, **Focus**, and **Others** panels. Each panel has its own
  switch, **Show mob health** and **Health text**, **Show panel frame**,
  **Outline width** (Target and Focus), **Grow**, **Tracker size** and the
  look's sizes and name position, color, opacity, and a **Reset** button.
  Your current settings become each panel's starting values. With a Dyre's
  Toolkit older than 2.13.0 the page keeps one set of these settings for
  all panels.
- Warlocks: Dyre's Debuff Tracker is now the home of your DoT tracker, DoT
  damage prediction, and crowd-control bar. Every setting Warlock Tools
  Forever had for them is here too: each DoT's color and place in the row,
  its dot on nameplates, each panel's color and opacity, the sizes of each
  look (icon size, name width, bar width, line height, text size, name
  position), the nameplate dots' height and opacity, the curse slot's smart
  curse with its letter, the "! Curse" macro and its key binding (Key
  Bindings, Dyre's Debuff Tracker), and the block's fill, opacity, and
  outline. These rows are on the DoTs page for every class, except the curse
  slot, which is for Warlocks.
- Warlocks: when Warlock Tools Forever 1.11.0 hands these parts over, your
  Warlock Tools Forever settings for them are copied here once, and a chat
  line says so: the tracker, the prediction, the bar, the "! Fear",
  "! Banish", "! Seduction", and "! Curse" macros (kept in place, so your
  action bars keep them), and the Fear, Banish, Enslave Demon, and Howl of
  Terror group messages with their texts. A part you had turned off in
  Warlock Tools Forever keeps this AddOn's own settings. Warlock Tools
  Forever's settings are not changed. Your Smart curse key moves to this
  AddOn's "Smart curse (Warlock)" binding at your first login, out of
  combat, unless that binding already has a key.
- Mages: Dyre's Debuff Tracker is now the home of the Polymorph bar. It
  works as Mage Tools Forever's did: one bar, its purple, your focus first
  (on Classic Era the mob under your mouse, else your target), the time
  left as text where no unit shows the mob, and the click whenever you know
  Polymorph. When Mage Tools Forever 1.6.0 hands it over, your bar's place,
  size, width, bar height, text size, and opacity, "! Polymorph", the moon,
  and the Polymorph group message are copied here once.
- Every class: the crowd-control bar has Bar width, Bar height, Text size,
  and Opacity on the Crowd control page, with Reset size. The defaults keep
  today's look.
- Show only the DoTs (GitHub issue 1): two new settings for each panel.
  "Show panel frame" (on by default): turn it off to remove the background
  and border behind each mob's name and DoTs, at once, also in combat. It
  needs a Dyre's Toolkit with this option (newer than 2.12.0); with an
  older one the checkbox does not show. "Outline width" (0 to 20 pixels,
  default 3): the colored outline around the Target and Focus panels; 0
  removes it. A change in combat applies when combat ends.

### Fixes

- The DoTs page's sliders show their number (Outline width showed none, so
  3 could look like 0).

### Other changes

- **What moved:** from Warlock Tools Forever into Dyre's Debuff Tracker: the DoT tracker, the nameplate DoT dots, the DoT damage prediction, the smart curse with its key, the crowd-control bar, the "! Fear", "! Banish", "! Seduction" and "! Curse" macros, and the Fear, Banish, Enslave Demon and Howl of Terror group messages. From Mage Tools Forever: the Polymorph bar, "! Polymorph" and the Polymorph group message. Your settings come with them.

## 1.3.0

### Features

- Mage: frozen and chilled arcs above enemy nameplates, on by default. An
  arc of ice crystals shows while the mob is Frozen, so Shatter works on it (Frost
  Nova from any Mage, and Frostbite's freeze). A thin arc of frost and snowflakes shows
  while your own Chill is on it, so Frostbite and Fingers of Frost can proc
  (Frostbolt, Cone of Cold, Improved Blizzard, and the Frost Armor and Ice
  Armor chill). A mob that is both shows both, Frozen above. The game draws
  them, so they work in combat. Turn them off, or set their height and
  size, under "Frozen and chilled" on the DoTs page. They follow Plater,
  Threat Plates, and the other nameplate AddOns.
- Show or hide each DoT panel: three new checkboxes on the DoTs page, "Show
  Target panel", "Show Focus panel", and "Show Others panel" (all on by
  default). Turn off the Target panel if your target frame already shows
  your DoTs, and keep Focus and Others. A change applies at once. It needs a
  Dyre's Toolkit with this option (newer than 2.10.2); with an older one the
  checkboxes do not show.

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
