# CurseForge listing

Copy-ready text for the CurseForge project form. Keep it aligned with what is
released and built; do not advertise clients, classes, or features that are
not. The CurseForge project exists (ID 1777574, John, 2026-10-31). The first
upload was 1.0.1 (2026-11-14), through CI. This text matches 1.8.0
(2026-11-27, CurseForge file 9842891).

What is tested in game, and what is not (keep the description to this):
- Tested in game in this AddOn: Hunter's Serpent Sting on WoW: Forever (John,
  2026-11-14: "I can report that DDT is working for Hunter's Serpent
  Sting").
- The Warlock and Mage parts are the engine code that Warlock Tools Forever
  and Mage Tools Forever ran before they handed it over; John plays them.
- Not yet checked in game: every other class spell (Druid, Hunter's
  Immolation Trap and crowd control, Priest, Rogue, Shaman, Warrior,
  Paladin, Mage's Fireball, Pyroblast, and Frostfire Bolt DoTs), their spell
  IDs, and their durations; the Demonic Brand talent check. TESTING.md lists
  them.

## Project fields

| Field | Value |
| --- | --- |
| Name | Dyre's Debuff Tracker |
| Project ID | 1777574 (the repository's `CURSEFORGE_PROJECT_ID` variable) |
| Class | Addons |
| Main category | Buffs & Debuffs. Keep it identical to the TOC `## Category`, which groups the AddOn in the in-game AddOn list. |
| Additional categories | Combat (CurseForge allows up to 4; unrelated ones can send the project back for changes). |
| Author shown | Dyre, set through the CurseForge account's username |
| License | MIT License |
| Logo | artwork/dyres-debuff-tracker-logo.png (1024 x 1024); artwork/dyres-debuff-tracker-logo-512.png if a smaller square is wanted |
| Source | https://github.com/jbedworth/DyresDebuffTracker |
| Issues | https://github.com/jbedworth/DyresDebuffTracker/issues |
| Donation | Ko-fi, https://ko-fi.com/dyre_janelle (the project's Donation field) |
| Relations | Required dependency: Dyre's Toolkit (`dyres-toolkit`), 2.9.1 or later. The TOC lists it as `## OptionalDeps` (family rule), so the AddOn loads without it and says once what to install. Each upload sets it; the project's Default Relations should list it too. Dyre's Sounds is optional (only the Mage's Winter's Chill chime uses it); uploads do not list it. |
| Game versions | WoW: Forever (1.60.1) and Classic Era (1.15.9); each upload sets both (scripts/publish_curseforge.py). |

## Summary

See every DoT on every mob, know when they'll kill it, and keep your crowd control on timers. For WoW: Forever and Classic Era.

## Screenshots

The gallery is being captured again in game (2026-11-27), on the current
look. The shot list is
`C:\Users\jbed\Dropbox\Projects\src\screenshots\shotlists\DDT.md`. The old
PNGs in artwork/screenshots/ (Classic Era, 2026-10-29) show an older tracker
look; replace them on the project with the new shots.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
I play a Warlock, and I got tired of guessing. Is my Corruption still on that mob? Will my DoTs kill it, or do I need to cast one more? I made Dyre's Debuff Tracker to answer both at a glance, and then I added the crowd-control timers I wanted too.

It shows every DoT you have on every mob. A striped block on the mob's health bar shows the damage your DoTs still have to deal. When that's enough to kill it, a red skull says **DIES**, so you can move on to the next one.

For crowd control, you get a timer bar for each mob you Fear, Banish, Polymorph, or Sap, a macro for each control spell, and an optional message to your group as you cast.

### The DoT tracker
- **Three panels**: one for your target, one for your focus, and one for every other mob you've DoTed.
- Each mob gets a row with a timer bar for each of your DoTs, each in its own color, so you can see which one runs out next.
- **Two looks**, Compact with icons or Bars with timer bars. Tracker size goes from 75% to 125%.
- Each row can show the mob's health as a number, a percent, or both.
- **Each panel has its own settings**: its on/off switch, frame, outline, size, color, and opacity.
- A panel can grow down or up. Pick Up for a panel that sits above your target frame.
- **Hide empty DoT slots** if you only want to see the DoTs that are ticking. The DoTs keep their places in the row, so nothing jumps around.
- **Show only the DoTs**: turn off the panel frame and the outline to keep just the bars. Thanks to t0ddharris on GitHub for this one.
- **Nameplate dots** put one dot per DoT above each nameplate, lit while that DoT is on the mob.
- You pick each DoT's place in the row and its color.
- **Smart curse** for Warlocks: the curse slot casts Tongues on a mob with mana, else Elements, else Weakness. Hold Shift, Ctrl, or Alt to pick one yourself. It has its own "! Curse" macro and a key binding.

### Damage to come, and DIES
- The striped block shows on your target frame, on nameplates, and on the tracker. It's as wide as the damage your DoTs still have to deal.
- **DIES** and a red skull show when that damage is enough to kill the mob. Stop casting and save your mana for the next one.
- The AddOn measures each DoT's real tick as it ticks, with your talents, spell power, and resists included, and remembers it for your next cast.
- Rupture and Rip use the combo points you spent.
- You set the block's fill, color, opacity, and outline, and where DIES sits.

### Crowd control
- **Control bars**: each mob you control gets a bar with its name and time left, so you know which one breaks next. A bar empties if the spell breaks early.
- You can also show a timer under each controlled mob's nameplate.
- **Control macros** for each control spell you know: "! Fear", "! Banish", "! Seduction", "! Polymorph", "! Hibernate", "! Shackle", "! Sap", and "! Repentance".
- Each macro casts on the mob under your mouse, else on your target. It can also put the raid marker you pick on the mob, so your group knows to leave it alone.
- **Group messages** tell your party or raid the mob's name as you cast. Each spell has its own switch, and Say is an option.
- One switch turns off all crowd control: the bar, the messages, and the macros.

### Debuff cues on nameplates
- **Frozen and chilled** for Mages: an arc of ice crystals above a mob while it's Frozen, so you know your Shatter talent works on it. A thin frost arc shows while your chill is on it, so your Frostbite and Fingers of Frost can proc.
- **Winter's Chill** for Mages: an ice arc with five segments that fills one segment per stack. A chime plays as each stack goes on, with Dyre's Sounds installed.
- **Demonic Brand** for Warlocks on WoW: Forever: a red pentagram while your Brand is on the mob. Cast Searing Pain again when it goes away.
- The settings list every cue for your class. A cue that needs a talent you haven't learned is greyed out until you learn it, and the Preview button lets you place it before then.

### Classes
- **Warlock**: your curse, your Bane, Corruption, Immolate, and Siphon Life. Fear, Banish, Enslave Demon, and Howl of Terror.
- **Mage**: the DoT parts of Fireball, Pyroblast, and Frostfire Bolt. Polymorph.
- **Hunter**: Serpent Sting and Immolation Trap. Scare Beast, Wyvern Sting, and Freezing Trap.
- **Druid**: Moonfire, Insect Swarm, Entangling Roots, Rake, Rip, Pounce, and Lacerate. Hibernate and Entangling Roots.
- **Priest**: Shadow Word: Pain, Devouring Plague, and Holy Fire. Shackle Undead and Psychic Scream.
- **Rogue**: Rupture and Garrote. Sap and Blind.
- **Shaman**: Flame Shock.
- **Warrior**: Rend. Hamstring and Intimidating Shout.
- **Paladin**: Turn Undead and Repentance.

I play a Warlock and a Mage, and I've checked Serpent Sting on a Hunter. Nobody has checked the other classes' spells in game yet, so if something looks wrong on your class, please tell me.

### Settings and commands
Type `/ddt`, or open Options > AddOns > Dyre's AddOns > Debuff Tracker. There's a page each for DoT Tracker, DoTs, Crowd Control, and Debuff Cues, and each part has its own on/off switch, so you turn on only what you want.

If you play Warlock Tools Forever or Mage Tools Forever, you'll find these same settings on their pages too. A change in one place is a change in both.

You move the frames with Dyre's Toolkit's layout mode. Your settings are part of your Dyre's Toolkit profile, so you can copy them to your other characters.

### Works with your frames
Blizzard's frames, Shadowed Unit Frames, BetterBlizzFrames, Threat Plates, Plater, and Platynator.

### What gets installed with it
Dyre's Debuff Tracker needs Dyre's Toolkit 2.9.1 or later, and the CurseForge app installs it for you. Dyre's Toolkit 2.17.0 or later gives you the newest settings pages.

### Compatibility
WoW Classic Era and Anniversary, and WoW: Forever. On WoW: Forever the game hides DoT damage from AddOns, so the damage to come there is an estimate.

Let me know what you think! You can also report a bug at https://github.com/jbedworth/DyresDebuffTracker/issues.

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

Source (MIT): https://github.com/jbedworth/DyresDebuffTracker
```
