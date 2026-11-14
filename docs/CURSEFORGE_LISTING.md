# CurseForge listing

Copy-ready text for the CurseForge project form. Keep it aligned with what is
built and tested; do not advertise clients, classes, or features that are not.
The CurseForge project exists (ID 1777574, John, 2026-10-31). The first
upload is 1.0.0 (John, 2026-11-14: "ship it"), through CI.

What is tested in game, and what is not (keep the description to this):
- Tested in game in this AddOn: Hunter's Serpent Sting on WoW: Forever (John,
  2026-11-14: "I can report that DDT is working for Hunter's Serpent
  Sting").
- The Warlock and Mage parts are the engine code that Warlock Tools Forever
  and Mage Tools Forever run; not seen in game in this AddOn yet.
- Not yet checked in game: every other class spell (Druid, Hunter's
  Immolation Trap and crowd control, Priest, Rogue, Shaman, Warrior,
  Paladin, Mage's Fireball, Pyroblast, and Frostfire Bolt DoTs), their spell
  IDs, and their durations. TESTING.md lists them.

## Project fields

| Field | Value |
| --- | --- |
| Name | Dyre's Debuff Tracker |
| Project ID | 1777574 (the repository's `CURSEFORGE_PROJECT_ID` variable, once it exists) |
| Class | Addons |
| Main category | Buffs & Debuffs. Keep it identical to the TOC `## Category`, which groups the AddOn in the in-game AddOn list. |
| Additional categories | Combat (CurseForge allows up to 4; unrelated ones can send the project back for changes). |
| Author shown | Dyre, set through the CurseForge account's username |
| License | MIT License |
| Logo | artwork/dyres-debuff-tracker-logo.png (1024 x 1024); artwork/dyres-debuff-tracker-logo-512.png if a smaller square is wanted |
| Source | https://github.com/jbedworth/DyresDebuffTracker (once the author creates it) |
| Issues | https://github.com/jbedworth/DyresDebuffTracker/issues |
| Donation | Ko-fi, https://ko-fi.com/dyre_janelle (the project's Donation field) |
| Relations | Required dependency: Dyre's Toolkit (`dyres-toolkit`), 2.9.1 or later. The TOC lists it as `## OptionalDeps` (family rule), so the AddOn loads without it and says once what to install. Each upload sets it; the project's Default Relations should list it too. |
| Game versions | WoW: Forever (1.60.1) and Classic Era (1.15.9); each upload sets both (scripts/publish_curseforge.py). |

## Summary

See your DoTs tick and know when they'll finish the job, and keep your crowd control on a timer: DoT timers per mob, the damage still to come, a red skull when it's enough to kill, and crowd-control bars with macros, for every class.

## Screenshots

Upload the PNGs in artwork/screenshots/ (taken on Classic Era; cut by
scripts/make_artwork.py, see artwork/README.md):

| File | Title | Description |
| --- | --- | --- |
| artwork/screenshots/overview-prediction.png | DoTs and damage to come | The DoT tracker, a nameplate, and the target frame, each with the striped block for the damage your DoTs still have to deal. |
| artwork/screenshots/tracker-prediction.png | The DoT tracker | One row per mob: its health, the damage to come, and a timer bar for each of your DoTs. |
| artwork/screenshots/nameplate-prediction.png | On nameplates | The block on a Threat Plates nameplate's health bar. |
| artwork/screenshots/tracker-dies.png | DIES | When your DoTs will kill the mob, the row says so with a red skull. |
| artwork/screenshots/target-frame-dies.png | On your target frame | DIES beside the target frame's health bar. |

Not yet: `nameplate-dies.png` and `overview-dies.png` show the DIES badge
running into a nameplate text, fixed in Dyre's Toolkit 2.4.0; take them again
first. Still to take in client: the crowd-control bars (a Fear, a Banish, a
Polymorph) and a nameplate Fear timer; the settings pages;
Plater and Shadowed Unit Frames.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Dyre's Debuff Tracker** shows every DoT you have up, on every mob, and tells you when they'll finish the job. A striped block on the mob's health bar shows the damage your DoTs still have to deal, and a red skull says **DIES** when that's enough to kill it. It also keeps your crowd control in check: a timer bar for every mob you control, a macro for each control spell, and a heads-up to your group as you cast.

### The DoT tracker
- A row for your target, one for your focus, and up to eight more for the other mobs you've DoTed.
- Each row has a timer bar for each of your DoTs, in its own color, and dims the ones that are missing.
- Optional mob health on each row, with the damage to come drawn on it.
- Optional dots above each nameplate: one per DoT, colored while it's up.

### Damage to come, and DIES
- A striped block on the mob's health bar, as wide as the damage your DoTs still have to deal: on your target frame, on nameplates, and on the tracker's rows.
- When that damage is at least the health left, a red skull and **DIES**. Stop casting and move on.
- It learns each DoT's real tick as it ticks (your talents, spell power, and resists included), and remembers it for your next cast. Rupture and Rip use the combo points you spent.
- Pick its color, DIES on or off, nameplates on or off, and where DIES shows.

### Works with your frames
Blizzard's frames, Shadowed Unit Frames, BetterBlizzFrames (also with smooth bars), Threat Plates, Plater, and Platynator. The DIES badge stays clear of what each one shows beside the bar.

### Crowd control
- A bar for each mob you control, with its name and time left, so you know which one breaks next. It empties if the spell breaks early, and goes when the mob dies.
- Several controlled mobs at once, each on its own row, and an optional timer under each controlled mob's nameplate.
- Macros kept for you, once you know the spell: **"! Fear"**, **"! Banish"**, **"! Seduction"** (with a Succubus or Incubus that knows it), **"! Polymorph"**, **"! Hibernate"**, **"! Shackle"**, **"! Sap"**, and **"! Repentance"**. Each casts on the mob under your mouse, else your target.
- A raid marker on your target, from the macro itself, so your group leaves it alone. Pick the marker, or none.
- Tell your party or raid as you cast, with the mob's name. Each spell has its own switch.

### Classes
- **Warlock**: your curse, your Bane, Corruption, Immolate, Siphon Life; Fear, Banish, Enslave Demon, Howl of Terror.
- **Mage**: the DoT parts of Fireball, Pyroblast, and Frostfire Bolt; Polymorph.
- **Hunter**: Serpent Sting (tested in game on WoW: Forever), Immolation Trap; Scare Beast, Wyvern Sting, Freezing Trap.
- **Druid**: Moonfire, Insect Swarm, Entangling Roots, Rake, Rip, Pounce, Lacerate; Hibernate, Entangling Roots.
- **Priest**: Shadow Word: Pain, Devouring Plague, Holy Fire; Shackle Undead, Psychic Scream.
- **Rogue**: Rupture, Garrote; Sap, Blind.
- **Shaman**: Flame Shock. **Warrior**: Rend; Intimidating Shout. **Paladin**: Turn Undead, Repentance.

New in 1.0.0 and not yet checked in game: every class spell above but Serpent Sting and the Warlock and Mage spells that Warlock Tools Forever and Mage Tools Forever already track. Tell us what you see.

### With Dyre's Toolkit
Needs Dyre's Toolkit 2.9.1 or later; the CurseForge app installs it with Dyre's Debuff Tracker. The class tables and the prediction engine are in the toolkit. Frames move with the toolkit's layout mode, and the settings are under Options > AddOns > Dyre's AddOns > Debuff Tracker.

### Compatibility
World of Warcraft Classic Era and Anniversary, and WoW: Forever. The game hides DoT damage from AddOns on WoW: Forever, so damage to come there is an estimate.

With Warlock Tools Forever or Mage Tools Forever on, that AddOn shows its own class's trackers.

### Support
Found a bug or have an idea? Open an issue: https://github.com/jbedworth/DyresDebuffTracker/issues

If Dyre's Debuff Tracker helps you, you can buy me a coffee: https://ko-fi.com/dyre_janelle

Source, issues, and license (MIT): https://github.com/jbedworth/DyresDebuffTracker
```
