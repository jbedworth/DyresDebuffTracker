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
- **Hide empty DoT slots** (off by default): a DoT shows only while it is on
  the mob. The empty places stay, so the DoTs do not move. The target and
  focus rows then do not recast a DoT when you click them. It needs a Dyre's
  Toolkit newer than 2.10.2; with an older one the checkbox does not show.
- **Show Target panel**, **Show Focus panel**, **Show Others panel** (all on
  by default): turn off a panel you do not need, for example the Target
  panel when your target frame already shows your DoTs. It needs a Dyre's
  Toolkit newer than 2.10.2; with an older one the checkboxes do not show.
- **Panels**: the Target, Focus, and Others panels each have their own
  settings (Dyre's Toolkit 2.13.0 or later): show the panel, mob health and
  its text, the frame, the outline (Target and Focus), grow, size, color,
  and opacity, with a Reset button each. With an older Toolkit one set of
  these settings is for all panels.
- **Show panel frame** (on by default): turn it off to remove the
  background and border behind each mob's name and DoTs. It needs a Dyre's
  Toolkit newer than 2.12.0; with an older one the checkbox does not show.
- **Outline width** (0 to 20 pixels, default 3): the colored outline around
  the Target and Focus panels; 0 removes it.
- Optional dots on nameplates: one per DoT, colored while it is up, with
  their height and opacity, and a switch for each DoT's dot.
- Each look's own sizes: Compact's icon size, name width, and text size;
  Bars' bar width, line height, and text size; and the name's place.
  **Reset size** puts the look back.
- **Panels**: each panel's color (its outline and health fill) and opacity.
- **Each DoT**: its place in the row (pick another DoT and the two swap),
  its color on the bars and on nameplate dots. **Reset order and colors**.
- **Curse slot** (Warlock): Last used, or the **Smart curse** (Tongues on a
  mob with mana, else Elements, else Weakness; Shift, Ctrl, and Alt pick
  one), with its letter on the icon, the "! Curse" macro, and a key binding.

## Moving from Warlock Tools Forever

Your Warlock's DoT tracker, damage prediction, and crowd-control bar are
kept here now, with "! Fear", "! Banish", "! Seduction", "! Curse", and the
Fear, Banish, Enslave Demon, and Howl of Terror group messages. When Warlock
Tools Forever 1.11.0 hands them over, the settings you had there are copied
here once, and a chat line says so. A part you had turned off there keeps
this AddOn's own settings. Your macros stay on your action bars. Your Smart
curse key moves to this AddOn's binding once.

## Moving from Mage Tools Forever

The Polymorph bar is kept here now, as it worked in Mage Tools Forever, with
"! Polymorph" and its group message. When Mage Tools Forever 1.6.0 hands it
over, your bar's settings are copied here once.

## Damage to come, and DIES

- A striped block on the mob's health bar, as wide as the damage your DoTs
  still have to deal: on your target frame, on nameplates, and on the
  tracker's rows.
- Its look: **Block fill** (stripes, solid, or the bar's texture), **Block
  color**, **Block opacity**, and **Block outline**.
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
- The bar's **Bar size**, **Bar width**, **Bar height**, **Text size**, and
  **Opacity**, with **Reset size**. A Mage's bar is one Polymorph bar.

## Mage: frozen and chilled

- An **arc of ice crystals** above an enemy nameplate while the mob is Frozen:
  Shatter works on it. Frost Nova (from any Mage) and Frostbite's freeze.
- A **thin arc of frost and snowflakes** while your own Chill is on the mob: your Frostbite
  and Fingers of Frost can proc. Frostbolt, Cone of Cold, Improved
  Blizzard, and the Frost Armor and Ice Armor chill. Another Mage's chill
  does not count, because it cannot proc your talents. One exception:
  the game does not name you as the source of the armor chill, so another
  Mage's armor chill also shows the arc.
- A mob that is both shows both, Frozen above. The game draws the arcs, so
  they work in combat.
- On by default for Mages. "Frozen and chilled" on the DoTs page: on or
  off, **Arc height** (0 to 60 pixels above the health bar), and **Arc
  size** (50% to 200%). They sit on the bar of Plater, Threat Plates, and
  the other nameplate AddOns that Dyre's Toolkit knows.

## Mage: Winter's Chill

- **Five frost balls** above an enemy's nameplate while your Winter's Chill
  is on the mob: blue, and one more turns white with each stack, up to 5,
  as combo points. Your Frost spells add the stacks. The game lights the
  balls, so they work in combat.
- Only your own Winter's Chill shows.
- On by default for Mages. "Winter's Chill" on the DoTs page: **Show**,
  **Size** (50% to 200%, default 100%), **Height above nameplate** (0 to 60
  pixels, default 36, above the frozen and chilled arcs), **Preview**, and
  **Reset Winter's Chill**. Changes apply at once.
- **Preview** (or `/ddt preview chill`): three of five balls white on your
  target's nameplate with no Winter's Chill on it, so you can set Size and
  Height. Press it again, change target, or log out to end it.
- On Classic Era the balls count stacks with Dyre's Toolkit 2.11.0 or
  later; with an older Toolkit only the first ball turns white.
- **Stack chime** (Classic Era): a note as each stack goes on, rising from 1
  to 4, and a held high note at 5, with **Note set** (Bassoon or Sax) and
  **Test chime**. On by default; it needs Dyre's Sounds. Only your own
  Winter's Chill on your target chimes. It moved here from Dyre's Buff Reminders (1.13.3
  removes its chime), and your settings there are copied once. While an
  older Dyre's Buff Reminders is loaded, this chime waits, so you never hear
  two. WoW: Forever has no chime yet.

## Warlock: Demonic Brand (WoW: Forever)

- A **glowing red pentagram** above an enemy's nameplate while your Demonic
  Brand is on the mob. Its red glow pulses. The Demonic Brand talent makes
  your Searing Pain brand the mob for 10 seconds, and your demon's next
  attacks on it deal extra damage. Recast Searing Pain when the pentagram
  goes.
- Only your own Brand shows. Another Warlock's Brand helps only their
  demon.
- On by default for Warlocks on WoW: Forever. "Demonic Brand" on the DoTs
  page: **Show**, **Size** (50% to 200%, default 100%), **Height above
  nameplate** (0 to 60 pixels, default 10), **Preview**, and **Reset
  Demonic Brand**. Changes apply at once.
- **Preview** (or `/ddt preview brand`): the pentagram on your target's
  nameplate with no Brand on it, also without the talent, so you can set
  Size and Height. Press it again, change target, or log out to end it. The game draws the pentagram, so it works in
  combat. It sits on the bar of Plater, Threat Plates, and the other
  nameplate AddOns that Dyre's Toolkit knows. Classic Era has no Demonic
  Brand, so it has no pentagram and no rows.

## Classes

| Class | DoTs | Crowd control |
| --- | --- | --- |
| Warlock | Your curse, your Bane (Agony, Doom, or Havoc on WoW: Forever; Curse of Agony on Classic Era), Corruption, Immolate, Siphon Life | Fear, Banish; Enslave Demon and Howl of Terror (message only) |
| Mage | The DoT parts of Fireball, Pyroblast, and Frostfire Bolt | Polymorph |
| Druid | Moonfire, Insect Swarm, Entangling Roots, Rake, Rip, Pounce, Lacerate | Hibernate, Entangling Roots (one bar per mob) |
| Hunter | Serpent Sting, Immolation Trap | Scare Beast, Wyvern Sting, Freezing Trap (message only) |
| Priest | Shadow Word: Pain, Devouring Plague, Holy Fire | Shackle Undead, Psychic Scream (message only) |
| Rogue | Rupture, Garrote | Sap, Blind |
| Shaman | Flame Shock | none |
| Warrior | Rend | Hamstring; Intimidating Shout (message only) |
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
- `/ddt preview chill` (Mage) and `/ddt preview brand` (Warlock): the
  Winter's Chill balls or the Demonic Brand pentagram on your target's
  nameplate, to set their size and height.
- `/debufftracker` works the same, in case another AddOn uses `/ddt`.

Frames move with Dyre's Toolkit's layout mode.

## Profile

With Dyre's Toolkit 2.10.0 or newer, this AddOn's settings, frame places,
and sizes are part of your Dyre's Toolkit profile. On the Toolkit's settings
page (Options > AddOns > Dyre's AddOns), copy every Dyre's AddOn's settings
from another character or the defaults, or export and import them as one
line of text. They apply at once, with no reload. Your control macros and
the spell each pinned slot last cast stay with each character.

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
