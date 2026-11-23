"""Run from the AddOn folder: python scripts/make_artwork.py [--logo] [--icon] [--screenshots] [--arcs] [--brand] [--chill]

Makes Dyre's Debuff Tracker's artwork, reproducibly (no option: all six):
- artwork/dyres-debuff-tracker-logo.svg, the 1024 x 1024 vector source: the
  family's dark-brown field and fine gold border (as Dyre's Debuff Tracker's and
  Warlock Tools Forever's logos), a gold clock dial with twelve ticks, a
  striped violet DoT sweep three-quarters round it (the prediction block's
  stripes), and a bone skull with red eyes (the DIES badge's red).
- artwork/dyres-debuff-tracker-logo.png (1024) and -512.png, rendered from the
  SVG with headless Chrome, as the family's logos are.
- Textures/Icon.tga, the TOC icon: the dial without the frame, rendered at
  512 and averaged down to 64 x 64, uncompressed 32-bit BGRA, top-left origin
  (as WTF's Textures/Stripes.tga).
- Textures/FrozenArc.tga and Textures/ChilledArc.tga, the Mage's arcs above
  enemy nameplates (John, 2026-11-18): SVG rendered with headless Chrome at
  4x on black and on white (the two shots give the alpha), averaged down to
  256 x 64, uncompressed 32-bit BGRA, top-left origin; fixed seeds. Frozen: a
  cracked ice crust with faceted crystal shards, tallest in the middle, a blue
  glow, and sparkles. Chilled: a thin band of frost mist, rime needles, and
  six snowflakes. Both curve up, as an arc over the plate. Our own art: nothing is copied from another AddOn.
- Textures/BrandPentagram.tga and Textures/BrandGlow.tga, the Warlock's
  Demonic Brand mark above enemy nameplates (John, 2026-11-21: "a glowing
  red pentagram that renders above the nameplate"), 128 x 128, the same TGA
  format. Pentagram: a five-point star drawn in one stroke inside a circle,
  red with a bright core and a dark rim, as SVG rendered with headless
  Chrome as the arcs are. Glow: a soft red halo, computed here (no Chrome),
  drawn behind the star with additive blending. Our own art.
- Textures/ChillArc.tga and Textures/ChillArcFill.tga (256 x 64), the
  Mage's Winter's Chill stacks above enemy nameplates (John, 2026-11-23:
  "a 5 part ice-arc above the mob's head, similar to the effects we do for
  chilled and frozen, a little higher up, and segmented into 5 parts"),
  the same TGA format, SVG rendered with headless Chrome as the arcs are.
  Five segments of an ice band on the arcs' curve, one per 51.2-pixel
  fifth, with radial cuts, rime spikes, a bright top rim, a darker lower
  facet, a rough rime edge and specks, and four small icicles hanging from
  each segment's bottom edge (John, 2026-11-23: "make the arc look more
  frosty, with small icicle points dripping down"); near white, as the game tints it (blue while empty, white
  while lit). No segment comes within CHILL_CLEAR pixels of a fifth's
  edge, so the game's crop there cuts no segment. ChillArc is the whole
  arc; ChillArcFill is segments 2 to 5 drawn across the whole texture, the
  status bar's fill, which the game crops (not stretches) as it fills. Our
  own art.
- artwork/screenshots/*.png, listing crops of John's raw screenshots (the
  CROPS table: source file, box in source pixels), cut by headless Chrome,
  which decodes WebP. The raw files are never changed.

Standard library only, plus Chrome or Edge (CHROME, else the usual paths)."""
import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "artwork"
SHOTS = ART / "screenshots"
LOGO = ART / "dyres-debuff-tracker-logo.svg"
ICON = ROOT / "Textures" / "Icon.tga"
ICON_SIZE, ICON_RENDER = 64, 512
ARC_W, ARC_H, ARC_SAMPLES = 256, 64, 4
# The band's circle: its center far below the texture, so the band is a gentle
# curve; the top of the band is at y 34 in the middle.
ARC_CX, ARC_CY, ARC_R = 128, 386, 352
CHROMES = (r"C:\Program Files\Google\Chrome\Application\chrome.exe",
           r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
           "/usr/bin/google-chrome", "/usr/bin/chromium")

# The dial's center and radii, and the sweep's share of the circle.
CX, CY = 512, 528
DIAL, SWEEP_R, SWEEP = 330, 300, 0.75

# Listing crops: (output name, source WebP, (left, top, right, bottom)).
CROPS = (
    ("overview-prediction.png", "era-blackrock-grunt-raw.webp", (0, 0, 1906, 1072)),
    ("tracker-prediction.png", "era-blackrock-grunt-raw.webp", (120, 60, 680, 320)),
    ("nameplate-prediction.png", "era-blackrock-grunt-raw.webp", (1040, 160, 1540, 300)),
    ("overview-dies.png", "era-blackrock-grunt-dies-raw.webp", (0, 0, 1957, 1101)),
    ("tracker-dies.png", "era-blackrock-grunt-dies-raw.webp", (20, 16, 566, 282)),
    ("nameplate-dies.png", "era-blackrock-grunt-dies-raw.webp", (1070, 250, 1640, 385)),
    ("target-frame-dies.png", "era-blackrock-grunt-dies-raw.webp", (1490, 880, 2000, 1080)),
)


def point(angle, radius):
    """A point on a circle around the dial's center; angle 0 is 12 o'clock, clockwise."""
    return CX + radius * math.sin(angle), CY - radius * math.cos(angle)


def ticks():
    lines = []
    for hour in range(12):
        angle = hour * math.pi / 6
        inner = DIAL - (46 if hour % 3 == 0 else 30)
        x1, y1 = point(angle, inner)
        x2, y2 = point(angle, DIAL - 10)
        width = 12 if hour % 3 == 0 else 7
        lines.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                     f'stroke="url(#gold)" stroke-width="{width}" stroke-linecap="round"/>')
    return "\n    ".join(lines)


def sweep():
    """The DoT sweep: from 12 o'clock clockwise, SWEEP of the circle."""
    x, y = point(SWEEP * 2 * math.pi, SWEEP_R)
    large = 1 if SWEEP > 0.5 else 0
    return f"M{CX} {CY} L{CX} {CY - SWEEP_R} A{SWEEP_R} {SWEEP_R} 0 {large} 1 {x:.1f} {y:.1f} Z"


def svg(frame=True, view="0 0 1024 1024", size=1024):
    border = """
  <rect x="46" y="46" width="932" height="932" rx="94" fill="none" stroke="url(#gold)" stroke-width="5"/>
  <rect x="62" y="62" width="900" height="900" rx="80" fill="none" stroke="#b48b45" stroke-opacity="0.28" stroke-width="2"/>
  <path d="M512 91 L525 108 L512 125 L499 108 Z M512 899 L525 916 L512 933 L499 916 Z" fill="url(#gold)"/>""" if frame else ""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="{view}" role="img" aria-labelledby="title description">
  <title id="title">Dyre's Debuff Tracker</title>
  <desc id="description">An original emblem: a gold clock dial with a striped violet damage-over-time sweep running three-quarters round it, and a bone-white skull with glowing red eyes at its center, on a rich dark-brown field framed by a fine gold border.</desc>
  <defs>
    <radialGradient id="background" cx="50%" cy="42%" r="70%">
      <stop offset="0" stop-color="#49301c"/>
      <stop offset="0.6" stop-color="#2b190f"/>
      <stop offset="1" stop-color="#170e09"/>
    </radialGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#f4d38b"/>
      <stop offset="0.32" stop-color="#d5a956"/>
      <stop offset="0.64" stop-color="#96703a"/>
      <stop offset="1" stop-color="#e9bf6a"/>
    </linearGradient>
    <radialGradient id="violet" cx="50%" cy="50%" r="60%">
      <stop offset="0" stop-color="#b57cf2"/>
      <stop offset="0.6" stop-color="#8a3fd6"/>
      <stop offset="1" stop-color="#4f1a8c"/>
    </radialGradient>
    <pattern id="stripes" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
      <rect width="20" height="40" fill="#ffffff" fill-opacity="0.22"/>
    </pattern>
    <radialGradient id="bone" cx="45%" cy="35%" r="70%">
      <stop offset="0" stop-color="#fbf4e4"/>
      <stop offset="0.7" stop-color="#e2d4b4"/>
      <stop offset="1" stop-color="#b9a582"/>
    </radialGradient>
    <radialGradient id="ember" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="#ffd0c0"/>
      <stop offset="0.35" stop-color="#ff2a1a"/>
      <stop offset="1" stop-color="#7a0508" stop-opacity="0"/>
    </radialGradient>
    <filter id="shadow" x="-35%" y="-35%" width="170%" height="170%">
      <feDropShadow dx="0" dy="14" stdDeviation="12" flood-color="#080502" flood-opacity="0.7"/>
    </filter>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="10"/>
    </filter>
  </defs>
  <path d="M0 0H1024V1024H0Z" fill="url(#background)"/>{border}
  <g filter="url(#shadow)">
    <circle cx="{CX}" cy="{CY}" r="{DIAL}" fill="#1c100a" stroke="url(#gold)" stroke-width="12"/>
    <path d="{sweep()}" fill="url(#violet)"/>
    <path d="{sweep()}" fill="url(#stripes)"/>
    <circle cx="{CX}" cy="{CY}" r="{SWEEP_R}" fill="none" stroke="#b48b45" stroke-opacity="0.35" stroke-width="3"/>
    {ticks()}
  </g>
  <g filter="url(#shadow)">
    <path d="M512 318 C620 318 690 392 690 486 C690 548 662 590 630 612 L630 662 C630 690 610 704 584 704
             L440 704 C414 704 394 690 394 662 L394 612 C362 590 334 548 334 486 C334 392 404 318 512 318 Z"
          fill="url(#bone)" stroke="#5a4630" stroke-width="6"/>
    <ellipse cx="448" cy="500" rx="54" ry="60" fill="#1a0b06"/>
    <ellipse cx="576" cy="500" rx="54" ry="60" fill="#1a0b06"/>
    <circle cx="448" cy="506" r="34" fill="url(#ember)" filter="url(#glow)"/>
    <circle cx="576" cy="506" r="34" fill="url(#ember)" filter="url(#glow)"/>
    <circle cx="448" cy="506" r="12" fill="#ff3b2a"/>
    <circle cx="576" cy="506" r="12" fill="#ff3b2a"/>
    <path d="M512 568 L536 616 L488 616 Z" fill="#1a0b06"/>
    <path d="M440 650 H584" stroke="#5a4630" stroke-width="5"/>
    <path d="M466 636 V702 M494 636 V704 M530 636 V704 M558 636 V702" stroke="#5a4630" stroke-width="5" stroke-linecap="round"/>
  </g>
</svg>
"""


def chrome():
    for path in (os.environ.get("CHROME"),) + CHROMES:
        if path and Path(path).is_file():
            return path
    sys.exit("No Chrome or Edge found; set CHROME to its path.")


def shoot(source, out, width, height):
    """Headless Chrome screenshot of a file at width x height CSS pixels."""
    subprocess.run([chrome(), "--headless=new", "--hide-scrollbars", "--disable-gpu",
                    "--allow-file-access-from-files", "--force-device-scale-factor=1",
                    f"--window-size={width},{height}", f"--screenshot={out}", Path(source).as_uri()],
                   check=True, capture_output=True)


def read_png(path):
    """8-bit RGB or RGBA, not interlaced (what Chrome writes): (width, height, rows of RGBA)."""
    data = Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat = 8, b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and color in (2, 6) and interlace == 0, (depth, color, interlace)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    channels = 4 if color == 6 else 3
    raw, stride, rows, prev = zlib.decompress(idat), width * channels, [], bytearray(width * channels)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up, corner = prev[i], prev[i - channels] if i >= channels else 0
            if kind == 1:
                line[i] = (line[i] + left) & 255
            elif kind == 2:
                line[i] = (line[i] + up) & 255
            elif kind == 3:
                line[i] = (line[i] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                line[i] = (line[i] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 255
        prev = line
        if channels == 3:
            line = bytearray(b for i in range(width) for b in (line[3 * i], line[3 * i + 1], line[3 * i + 2], 255))
        rows.append(line)
    return width, height, rows


def write_icon(png):
    width, height, rows = read_png(png)
    assert width == height == ICON_RENDER, (width, height)
    step = ICON_RENDER // ICON_SIZE
    header = bytes((0, 0, 2)) + bytes(9) + ICON_SIZE.to_bytes(2, "little") + ICON_SIZE.to_bytes(2, "little") \
        + bytes((32, 0x28))
    pixels = bytearray()
    for y in range(ICON_SIZE):
        for x in range(ICON_SIZE):
            total = [0, 0, 0, 0]
            for dy in range(step):
                row = rows[y * step + dy]
                for dx in range(step):
                    at = 4 * (x * step + dx)
                    for c in range(4):
                        total[c] += row[at + c]
            r, g, b, a = (round(v / (step * step)) for v in total)
            pixels += bytes((b, g, r, a))
    ICON.parent.mkdir(exist_ok=True)
    ICON.write_bytes(header + pixels)


def on_arc(x, lift=0.0):
    """Point on the band's top edge above x, raised by lift; and the outward normal angle."""
    a = math.asin((x - ARC_CX) / ARC_R)
    r = ARC_R + lift
    return (ARC_CX + r * math.sin(a), ARC_CY - r * math.cos(a)), a


def shard(rng, x, height, width, light, mid, dark):
    (bx, by), a = on_arc(x, -2)
    tilt = a + rng.uniform(-0.18, 0.18)
    ux, uy = math.sin(tilt), -math.cos(tilt)   # up along the shard
    vx, vy = -uy, ux                            # across
    tip = (bx + ux * height, by + uy * height)
    shoulder = 0.28 + rng.uniform(-0.05, 0.08)
    left = (bx + ux * height * shoulder - vx * width / 2, by + uy * height * shoulder - vy * width / 2)
    right = (bx + ux * height * shoulder + vx * width / 2, by + uy * height * shoulder + vy * width / 2)
    base_l = (bx - vx * width * 0.3, by - vy * width * 0.3)
    base_r = (bx + vx * width * 0.3, by + vy * width * 0.3)
    ridge = (bx + ux * height * 0.15, by + uy * height * 0.15)
    p = lambda *q: " ".join(f"{x:.2f},{y:.2f}" for x, y in q)
    return (f'<polygon points="{p(base_l, left, tip, ridge)}" fill="{light}"/>'
            f'<polygon points="{p(base_r, right, tip, ridge)}" fill="{mid}"/>'
            f'<polygon points="{p(base_l, left, tip, right, base_r)}" fill="none" stroke="{dark}" stroke-width="0.6"/>'
            f'<polyline points="{p(ridge, tip)}" fill="none" stroke="#ffffff" stroke-width="0.5" opacity="0.9"/>')


def band_path(rng, top_lift, bottom_lift, jag):
    xs = [16 + i * 4 for i in range(57)]
    top = [on_arc(x, top_lift + rng.uniform(-jag, jag))[0] for x in xs]
    bottom = [on_arc(x, bottom_lift + rng.uniform(-jag, jag))[0] for x in reversed(xs)]
    return "M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in top + bottom) + "Z"


def star(x, y, r, thin=0.18):
    pts = []
    for i in range(8):
        a = i * math.pi / 4
        rr = r if i % 2 == 0 else r * thin
        pts.append(f"{x + rr * math.sin(a):.2f},{y - rr * math.cos(a):.2f}")
    return f'<polygon points="{" ".join(pts)}" fill="#fff"/>'


def ice_defs():
    return f'''<defs>
<filter id="glow" filterUnits="userSpaceOnUse" x="0" y="0" width="{ARC_W}" height="{ARC_H}"><feGaussianBlur stdDeviation="2.4"/></filter>
<filter id="soft" filterUnits="userSpaceOnUse" x="0" y="0" width="{ARC_W}" height="{ARC_H}"><feGaussianBlur stdDeviation="0.7"/></filter>
<filter id="frost" filterUnits="userSpaceOnUse" x="0" y="0" width="{ARC_W}" height="{ARC_H}">
<feTurbulence type="fractalNoise" baseFrequency="0.35" numOctaves="2" seed="7"/>
<feDisplacementMap in="SourceGraphic" scale="3.5" xChannelSelector="R" yChannelSelector="G"/></filter>
<linearGradient id="bandfill" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#f4fbff"/><stop offset="0.45" stop-color="#9fd4f7"/><stop offset="1" stop-color="#2f74c8"/></linearGradient>
<linearGradient id="ends" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset="0.1" stop-color="#fff"/>
<stop offset="0.9" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
<mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="{ARC_W}" height="{ARC_H}"><rect width="{ARC_W}" height="{ARC_H}" fill="url(#ends)"/></mask></defs>'''


def frozen_svg():
    rng = random.Random(4471)
    band = band_path(rng, 1.5, -7, 0.9)
    shards = []
    # (x, height, width): tallest in the middle, smaller to the ends.
    plan = [(128, 34, 11), (104, 24, 9), (152, 25, 9), (82, 17, 8), (175, 18, 8),
            (60, 11, 7), (197, 12, 7), (40, 7, 6), (217, 7, 6),
            (116, 13, 6), (141, 14, 6), (93, 9, 5), (164, 10, 5)]
    for x, h, w in sorted(plan, key=lambda s: s[1]):
        shards.append(shard(rng, x + rng.uniform(-1.5, 1.5), h, w, "#eef9ff", "#8cc6f0", "#3d86d6"))
    shards.sort(key=len)
    sparkle = [star(128, 6.5, 6), star(100, 19, 3.2), star(158, 17.5, 3.4)]
    art = (f'<path d="{band}" fill="url(#bandfill)" stroke="#e8f6ff" stroke-width="0.6"/>'
           + "".join(shards))
    cracks = "".join(
        f'<path d="M{on_arc(x, -1)[0][0]:.1f},{on_arc(x, -1)[0][1]:.1f} l{rng.uniform(-3, 3):.1f},{rng.uniform(3, 5):.1f}" '
        f'stroke="#ffffff" stroke-width="0.4" opacity="0.7"/>' for x in range(30, 230, 9))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{ARC_W*ARC_SAMPLES}" height="{ARC_H*ARC_SAMPLES}" viewBox="0 0 {ARC_W} {ARC_H}">{ice_defs()}
<g mask="url(#m)">
<g filter="url(#glow)" opacity="0.85" fill="#5fb8ff">{art.replace('fill="url(#bandfill)"', 'fill="#5fb8ff"')}</g>
{art}{cracks}
<g filter="url(#soft)">{"".join(sparkle)}</g>{"".join(sparkle)}
</g></svg>'''


def chilled_svg():
    rng = random.Random(1372)
    mist = band_path(rng, 0, -4, 1.2)
    needles = []
    for i in range(46):
        x = 22 + i * 4.7 + rng.uniform(-1, 1)
        (bx, by), a = on_arc(x, -1)
        t = a + rng.uniform(-0.5, 0.5)
        h = rng.uniform(2.5, 6.5) * (1 - abs(x - ARC_CX) / 150)
        needles.append(f'<line x1="{bx:.2f}" y1="{by:.2f}" x2="{bx + math.sin(t) * h:.2f}" '
                       f'y2="{by - math.cos(t) * h:.2f}" stroke="#e6f6ff" stroke-width="0.7" stroke-linecap="round"/>')
    flakes = []
    for x in (44, 76, 108, 148, 180, 212):
        (fx, fy), _ = on_arc(x + rng.uniform(-3, 3), 6 + rng.uniform(-1, 2))
        r = 3.6 if 90 < x < 170 else 3.0
        arms = "".join(
            f'<line x1="{fx:.2f}" y1="{fy:.2f}" x2="{fx + r * math.cos(k * math.pi / 3):.2f}" '
            f'y2="{fy + r * math.sin(k * math.pi / 3):.2f}"/>' for k in range(6))
        flakes.append(f'<g stroke="#ffffff" stroke-width="0.8" stroke-linecap="round">{arms}</g>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{ARC_W*ARC_SAMPLES}" height="{ARC_H*ARC_SAMPLES}" viewBox="0 0 {ARC_W} {ARC_H}">{ice_defs()}
<g mask="url(#m)">
<path d="{mist}" fill="#7cc8ff" opacity="0.55" filter="url(#glow)"/>
<path d="{mist}" fill="#cdeeff" opacity="0.75" filter="url(#frost)"/>
<g filter="url(#soft)" opacity="0.8">{"".join(needles)}</g>{"".join(needles)}
<g filter="url(#glow)" opacity="0.9">{"".join(flakes)}</g>{"".join(flakes)}
</g></svg>'''


BRAND_SIZE = 128


def pentagram_svg():
    """A five-point star in one stroke (every second point of a pentagon) in a circle."""
    c, r_ring, r_star = 64, 54, 53
    pts = [(c + r_star * math.sin(k * 4 * math.pi / 5), c - r_star * math.cos(k * 4 * math.pi / 5)) for k in range(5)]
    star = "M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in pts) + "Z"
    n = BRAND_SIZE
    layer = lambda color, width: (
        f'<circle cx="{c}" cy="{c}" r="{r_ring}" fill="none" stroke="{color}" stroke-width="{width}"/>'
        f'<path d="{star}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{n*ARC_SAMPLES}" height="{n*ARC_SAMPLES}" viewBox="0 0 {n} {n}">
<defs><filter id="g" filterUnits="userSpaceOnUse" x="0" y="0" width="{n}" height="{n}"><feGaussianBlur stdDeviation="2.2"/></filter></defs>
<g filter="url(#g)" opacity="0.9">{layer("#ff1a0a", 9)}</g>
{layer("#5a0000", 8)}{layer("#e0140c", 5.5)}{layer("#ffb08a", 1.8)}
</svg>'''


def glow_texture():
    """A soft red halo: full at the middle, gone at the edge (rows of r, g, b, a floats)."""
    n, c, texture = BRAND_SIZE, (BRAND_SIZE - 1) / 2, []
    for y in range(n):
        row = []
        for x in range(n):
            d = min(1.0, math.hypot(x - c, y - c) / (n / 2))
            a = max(0.0, 1 - d) ** 2.2 * 0.9
            row.append((1.0, 0.12 + 0.25 * (1 - d) ** 3, 0.05, a))
        texture.append(row)
    return texture


# The Winter's Chill arc: five segments of an ice band, one per 51.2-pixel
# cell of the 256-pixel texture (the game's 64 x 16 at a quarter size). The
# same curve as the frozen and chilled arcs (radius ARC_R, so the arcs run
# side by side), but a thicker band: its top is at y CHILL_TOP in the middle,
# with room below for the icicles (John, 2026-11-23: "make the arc look more
# frosty, with small icicle points dripping down").
CHILL_SEGMENTS, CHILL_TOP = 5, 8
# Icicles per segment, and their length range in texture pixels (4 = 1 game pixel).
CHILL_ICICLES, CHILL_ICICLE_LONG = 4, (9.0, 19.5)
CHILL_OUTER, CHILL_INNER = ARC_R + 10, ARC_R - 10
CHILL_CY = CHILL_TOP + CHILL_OUTER
CHILL_CELL_W = ARC_W / CHILL_SEGMENTS
# No pixel of a segment comes nearer than this to a cell's edge, so the game's
# crop of the stack bar's fill at a cell's edge never cuts into the next segment.
CHILL_CLEAR = 3
# The outer tips of segments 1 and 5, at the band's middle.
CHILL_TIP = 6


def chill_point(angle, radius):
    """A point on the arc's circle; angle 0 is straight up, clockwise."""
    return ARC_CX + radius * math.sin(angle), CHILL_CY - radius * math.cos(angle)


def chill_edge(xb, right):
    """The radial cut nearest to the cell edge xb with every point of the band
    at least CHILL_CLEAR from it: right=True for a segment's right end."""
    target = xb - CHILL_CLEAR if right else xb + CHILL_CLEAR
    d = target - ARC_CX
    # The band's widest point on this side: the outer radius where the cut
    # leans away from the middle, else the inner.
    radius = CHILL_OUTER if (d >= 0) == right else CHILL_INNER
    return math.asin(d / radius)


def chill_tip_angle(x, radius):
    return math.asin((x - ARC_CX) / radius)


def chill_segment(i):
    """The path of segment i (0 to 4), and its angles (left, right)."""
    left_x, right_x = i * CHILL_CELL_W, (i + 1) * CHILL_CELL_W
    mid = (CHILL_OUTER + CHILL_INNER) / 2
    p = lambda pt: f"{pt[0]:.2f},{pt[1]:.2f}"
    ro, ri = CHILL_OUTER, CHILL_INNER
    if i == 0:
        a = chill_tip_angle(CHILL_TIP + 12, mid)
        start = [chill_point(chill_tip_angle(CHILL_TIP, mid), mid)]
    else:
        a = chill_edge(left_x, False)
        start = []
    if i == CHILL_SEGMENTS - 1:
        b = chill_tip_angle(ARC_W - CHILL_TIP - 12, mid)
        end = [chill_point(chill_tip_angle(ARC_W - CHILL_TIP, mid), mid)]
    else:
        b = chill_edge(right_x, True)
        end = []
    d = "M" + p((start or [chill_point(a, ro)])[0])
    if start:
        d += " L" + p(chill_point(a, ro))
    d += f" A{ro} {ro} 0 0 1 " + p(chill_point(b, ro))
    for pt in end:
        d += " L" + p(pt)
    d += " L" + p(chill_point(b, ri))
    d += f" A{ri} {ri} 0 0 0 " + p(chill_point(a, ri)) + " Z"
    return d, a, b


def chill_arc_svg(x0=0.0, width=ARC_W):
    """The five segments, near white (the game tints them: blue while empty,
    white while lit), drawn from x0 over width texture pixels into the whole
    256 x 64 (the stack bar's fill draws segments 2 to 5 only)."""
    rng = random.Random(1257)
    mid = (CHILL_OUTER + CHILL_INNER) / 2
    p = lambda pt: f"{pt[0]:.2f},{pt[1]:.2f}"
    parts, clips = [], []
    for i in range(CHILL_SEGMENTS):
        left_x, right_x = i * CHILL_CELL_W, (i + 1) * CHILL_CELL_W
        clips.append(f'<clipPath id="c{i}" clipPathUnits="userSpaceOnUse"><rect x="{left_x + CHILL_CLEAR:.2f}" y="0" '
                     f'width="{CHILL_CELL_W - 2 * CHILL_CLEAR:.2f}" height="{ARC_H}"/></clipPath>')
        d, a, b = chill_segment(i)
        # The lower facet: the band's bottom half, a shade darker.
        facet = (f"M{p(chill_point(a, mid - 1))} A{mid - 1} {mid - 1} 0 0 1 {p(chill_point(b, mid - 1))} "
                 f"L{p(chill_point(b, CHILL_INNER))} A{CHILL_INNER} {CHILL_INNER} 0 0 0 {p(chill_point(a, CHILL_INNER))} Z")
        ridge = f"M{p(chill_point(a, mid + 2))} A{mid + 2} {mid + 2} 0 0 1 {p(chill_point(b, mid + 2))}"
        rim = f"M{p(chill_point(a, CHILL_OUTER - 1.3))} A{CHILL_OUTER - 1.3} {CHILL_OUTER - 1.3} 0 0 1 {p(chill_point(b, CHILL_OUTER - 1.3))}"
        # Rime: two small ice spikes on the band's top, and a crack.
        spikes = []
        for k in (0.33, 0.67):
            t = a + (b - a) * (k + rng.uniform(-0.08, 0.08))
            h, w = rng.uniform(3.5, 6.0), rng.uniform(1.0, 1.6)
            base_l, base_r = chill_point(t - w / CHILL_OUTER, CHILL_OUTER - 0.5), chill_point(t + w / CHILL_OUTER, CHILL_OUTER - 0.5)
            tip = chill_point(t + rng.uniform(-0.004, 0.004), CHILL_OUTER + h)
            spikes.append(f'<polygon points="{p(base_l)} {p(tip)} {p(base_r)}" fill="#f6fbff" stroke="#7fa6cc" stroke-width="0.4"/>')
        # Icicles hanging from the band's bottom edge, longest in the middle
        # of the segment; each a thin tapered drip with a bright core line.
        icicles = []
        for j in range(CHILL_ICICLES):
            k = (j + 0.5) / CHILL_ICICLES + rng.uniform(-0.05, 0.05)
            t = a + (b - a) * k
            long = CHILL_ICICLE_LONG[0] + (CHILL_ICICLE_LONG[1] - CHILL_ICICLE_LONG[0]) \
                * (1 - abs(k - 0.5) * 2) * rng.uniform(0.75, 1.0) * (0.75 if i in (0, CHILL_SEGMENTS - 1) else 1.0)
            w = rng.uniform(1.5, 2.1) / CHILL_INNER  # half the base width, as an angle
            top = CHILL_INNER + 1.5
            pts = [chill_point(t - w, top), chill_point(t - w * 0.55, CHILL_INNER - long * 0.45),
                   chill_point(t, CHILL_INNER - long), chill_point(t + w * 0.45, CHILL_INNER - long * 0.5),
                   chill_point(t + w, top)]
            icicles.append(f'<polygon points="{" ".join(p(q) for q in pts)}" fill="url(#iciclefill)" '
                           f'stroke="#6f97c0" stroke-width="0.45" stroke-linejoin="round"/>'
                           f'<path d="M{p(chill_point(t - w * 0.2, CHILL_INNER))} L{p(chill_point(t - w * 0.1, CHILL_INNER - long * 0.7))}" '
                           f'stroke="#ffffff" stroke-width="0.5" opacity="0.9"/>')
        # Rime specks on the band: small frost crystals.
        specks = "".join(
            f'<circle cx="{q[0]:.2f}" cy="{q[1]:.2f}" r="{rng.uniform(0.35, 0.7):.2f}" fill="#ffffff" opacity="0.9"/>'
            for q in (chill_point(a + (b - a) * rng.uniform(0.08, 0.92), rng.uniform(CHILL_INNER + 2, CHILL_OUTER - 3))
                      for _ in range(7)))
        t = a + (b - a) * rng.uniform(0.4, 0.6)
        crack = (f'<path d="M{p(chill_point(t, CHILL_OUTER - 2))} L{p(chill_point(t + 0.006, mid + 1))} '
                 f'L{p(chill_point(t - 0.004, CHILL_INNER + 3))}" fill="none" stroke="#ffffff" stroke-width="0.5" opacity="0.8"/>')
        parts.append(
            f'<g clip-path="url(#c{i})">'
            f'<path d="{d}" fill="#d8ecff" opacity="0.75" filter="url(#glow)"/>'
            + "".join(spikes) + "".join(icicles)
            + f'<path d="{d}" fill="url(#chillfill)" stroke="#6f97c0" stroke-width="1.1" stroke-linejoin="round"/>'
            f'<path d="{facet}" fill="#a8c2dc" opacity="0.45"/>'
            f'<path d="{d}" fill="none" stroke="#ffffff" stroke-width="1.1" opacity="0.7" filter="url(#rime)"/>'
            f'<path d="{ridge}" fill="none" stroke="#ffffff" stroke-width="0.8" opacity="0.85"/>'
            f'<path d="{rim}" fill="none" stroke="#ffffff" stroke-width="1.3"/>'
            + specks + crack + '</g>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{ARC_W*ARC_SAMPLES}" height="{ARC_H*ARC_SAMPLES}" viewBox="{x0:.2f} 0 {width:.2f} {ARC_H}" preserveAspectRatio="none">
<defs>
<filter id="glow" filterUnits="userSpaceOnUse" x="0" y="0" width="{ARC_W}" height="{ARC_H}"><feGaussianBlur stdDeviation="1.8"/></filter>
<filter id="rime" filterUnits="userSpaceOnUse" x="0" y="0" width="{ARC_W}" height="{ARC_H}">
<feTurbulence type="fractalNoise" baseFrequency="0.6" numOctaves="2" seed="12"/>
<feDisplacementMap in="SourceGraphic" scale="2.2" xChannelSelector="R" yChannelSelector="G"/></filter>
<linearGradient id="iciclefill" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#c8dcef"/></linearGradient>
<linearGradient id="chillfill" gradientUnits="userSpaceOnUse" x1="0" y1="{CHILL_TOP}" x2="0" y2="{CHILL_TOP + 40}">
<stop offset="0" stop-color="#ffffff"/><stop offset="0.45" stop-color="#e4f0fb"/><stop offset="1" stop-color="#b6cde3"/></linearGradient>
{"".join(clips)}</defs>
{"".join(parts)}</svg>'''


def svg_texture(svg, work, width=ARC_W, height=ARC_H):
    """The SVG on black and on white (the two shots give the alpha), averaged
    ARC_SAMPLES x ARC_SAMPLES: rows of (r, g, b, a) floats 0-1."""
    shots = []
    for name, background in (("black", "#000"), ("white", "#fff")):
        page, png = work / f"arc-{name}.html", work / f"arc-{name}.png"
        page.write_text(f'<html><body style="margin:0;background:{background}">{svg}</body></html>',
                        encoding="utf-8")
        shoot(page, png, width * ARC_SAMPLES, height * ARC_SAMPLES)
        shots.append(read_png(png)[2])
    black, white = shots
    n, texture = ARC_SAMPLES, []
    for y in range(height):
        row = []
        for x in range(width):
            color, alpha = [0.0, 0.0, 0.0], 0.0
            for sy in range(n):
                for sx in range(n):
                    i, j = y * n + sy, 4 * (x * n + sx)
                    b, w = black[i][j:j + 3], white[i][j:j + 3]
                    alpha += max(0.0, min(1.0, 1 - sum(w[c] - b[c] for c in range(3)) / 765))
                    for c in range(3):
                        color[c] += b[c] / 255  # on black: the color times its alpha
            alpha /= n * n
            row.append(tuple(min(1.0, v / (n * n) / alpha) if alpha > 0.002 else 0.0 for v in color)
                       + (alpha,))
        texture.append(row)
    return texture


def write_tga(path, texture):
    """Uncompressed 32-bit BGRA, top-left origin."""
    width, height = len(texture[0]), len(texture)
    header = bytes((0, 0, 2)) + bytes(9) + width.to_bytes(2, "little") + height.to_bytes(2, "little")         + bytes((32, 0x28))
    out = bytearray()
    for row in texture:
        for r, g, b, a in row:
            out += bytes(round(255 * v) for v in (b, g, r, a))
    path.parent.mkdir(exist_ok=True)
    path.write_bytes(header + out)


def make_arcs(work):
    write_tga(ROOT / "Textures" / "FrozenArc.tga", svg_texture(frozen_svg(), work))
    write_tga(ROOT / "Textures" / "ChilledArc.tga", svg_texture(chilled_svg(), work))


def make_brand(work):
    write_tga(ROOT / "Textures" / "BrandPentagram.tga",
              svg_texture(pentagram_svg(), work, BRAND_SIZE, BRAND_SIZE))
    write_tga(ROOT / "Textures" / "BrandGlow.tga", glow_texture())


def make_chill(work):
    write_tga(ROOT / "Textures" / "ChillArc.tga", svg_texture(chill_arc_svg(), work))
    # Segments 2 to 5, stretched across the whole texture: the stack bar's
    # fill, drawn over cells 2 to 5 in the game, so its aspect is right there.
    write_tga(ROOT / "Textures" / "ChillArcFill.tga",
              svg_texture(chill_arc_svg(CHILL_CELL_W, ARC_W - CHILL_CELL_W), work))


def make_logo(work):
    LOGO.write_text(svg(), encoding="utf-8", newline="\n")
    shoot(LOGO, ART / "dyres-debuff-tracker-logo.png", 1024, 1024)
    small = work / "logo-512.svg"
    small.write_text(svg(size=512), encoding="utf-8", newline="\n")
    shoot(small, ART / "dyres-debuff-tracker-logo-512.png", 512, 512)


def make_icon(work):
    # The dial alone, edge to edge: the frame would be a few pixels at 64.
    side = 2 * (DIAL + 14)
    view = f"{CX - side // 2} {CY - side // 2} {side} {side}"
    source = work / "icon.svg"
    source.write_text(svg(frame=False, view=view, size=ICON_RENDER), encoding="utf-8", newline="\n")
    png = work / "icon.png"
    shoot(source, png, ICON_RENDER, ICON_RENDER)
    write_icon(png)


def make_screenshots(work):
    for name, source, (left, top, right, bottom) in CROPS:
        width, height = right - left, bottom - top
        page = work / (name + ".html")
        page.write_text(
            f'<html><body style="margin:0;overflow:hidden;background:#000">'
            f'<div style="width:{width}px;height:{height}px;overflow:hidden;position:relative">'
            f'<img src="{(SHOTS / source).as_uri()}" style="position:absolute;left:{-left}px;top:{-top}px">'
            f'</div></body></html>', encoding="utf-8")
        shoot(page, SHOTS / name, width, height)


def main(args):
    wanted = set(args) or {"--logo", "--icon", "--screenshots", "--arcs", "--brand", "--chill"}
    with tempfile.TemporaryDirectory() as temp:
        work = Path(temp)
        if "--arcs" in wanted:
            make_arcs(work)
        if "--brand" in wanted:
            make_brand(work)
        if "--chill" in wanted:
            make_chill(work)
        if "--logo" in wanted:
            make_logo(work)
        if "--icon" in wanted:
            make_icon(work)
        if "--screenshots" in wanted:
            make_screenshots(work)


if __name__ == "__main__":
    main(sys.argv[1:])
