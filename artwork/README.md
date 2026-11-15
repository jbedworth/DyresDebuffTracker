# Dyre's Debuff Tracker artwork

## Logo

Original vector artwork: a gold clock dial with twelve ticks, a striped violet
damage-over-time sweep running three-quarters round it (the stripes of the
prediction block), and a bone-white skull with glowing red eyes at its center
(the red of the DIES badge), on the rich dark-brown field and fine gold border
the other Dyre's AddOns' logos share. No font or external-image dependencies.

- `dyres-debuff-tracker-logo.svg`: editable, resolution-independent source.
- `dyres-debuff-tracker-logo.png`: 1024 x 1024 PNG master.
- `dyres-debuff-tracker-logo-512.png`: 512 x 512 PNG for square project images.

`scripts/make_artwork.py` writes the SVG and renders both PNGs with headless
Chrome (or Edge), as the family's logos are rendered. Change the design in the
script, not in the SVG, and run it again:

```sh
python scripts/make_artwork.py --logo
```

## The TOC icon

`Textures/Icon.tga` (64 x 64, uncompressed 32-bit BGRA, top-left origin): the
dial and skull without the frame, rendered at 512 and averaged down. The TOC
uses it as `## IconTexture`; it is the one runtime texture.
`python scripts/make_artwork.py --icon` makes it again.

## Screenshots

`screenshots/*-raw.webp` are John's raw Classic Era screenshots (2026-10-30,
a Blackrock Grunt with Corruption and Curse of Agony, Threat Plates
nameplates). Never change or overwrite them. `python scripts/make_artwork.py
--screenshots` cuts the listing PNGs from them; the boxes are the script's
`CROPS` table, in source pixels (left, top, right, bottom):

| File | From | Box | Shows |
| --- | --- | --- | --- |
| overview-prediction.png | era-blackrock-grunt-raw.webp | 0, 0, 1906, 1072 | The whole scene, 16:9: tracker, nameplate, and target frame |
| tracker-prediction.png | era-blackrock-grunt-raw.webp | 120, 60, 680, 320 | The tracker row with its striped block, "84% \| 407" |
| nameplate-prediction.png | era-blackrock-grunt-raw.webp | 1040, 160, 1540, 300 | The block on a nameplate's health bar (85%) |
| overview-dies.png | era-blackrock-grunt-dies-raw.webp | 0, 0, 1957, 1101 | The whole scene, 16:9, with DIES on all three |
| tracker-dies.png | era-blackrock-grunt-dies-raw.webp | 20, 16, 566, 282 | DIES on the tracker row |
| nameplate-dies.png | era-blackrock-grunt-dies-raw.webp | 1070, 250, 1640, 385 | DIES on the nameplate: RETAKE (see below) |
| target-frame-dies.png | era-blackrock-grunt-dies-raw.webp | 1490, 880, 2000, 1080 | DIES left of the target frame's bar |

`screenshots/forever-hunter-serpent-sting-tracker.webp` is John's raw
Forever screenshot (2026-11-14, a level 9 Hunter in combat with a Strigid
Owl): the tracker row with Serpent Sting's timer bar (6 s), the first
in-game shot of a class other than Warlock. No DIES shows in it. Never
change or overwrite it.

`nameplate-dies.png` (and the plate in `overview-dies.png`) shows the badge
running into Threat Plates' target-of-target text ("DIESJuk'taz ]"), fixed in
Dyre's Toolkit 2.4.0. Take that shot again with 2.4.0 before using it.

This artwork is covered by the MIT License. Copyright (c) 2026 John Bedworth.
It never enters the runtime package (except Textures/Icon.tga).
