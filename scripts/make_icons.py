"""Builds Qout's launcher, splash and brand images from the icon sheet
(`docs/brand/icon-sheet.png`).

Run from `app/` with Pillow: `uv run --no-project --with pillow python
../scripts/make_icons.py ../docs/brand/icon-sheet.png .`, then move the
`store/` images to `docs/brand/`.

The mark (scanner corners + leaf with a check) is lifted from the sheet's
1024 px "master icon" tile (drawn there at 228 px), upscaled smoothly and
re-thresholded so the edges stay crisp at every size.
"""
import os
import sys

from PIL import Image, ImageDraw

SHEET, OUT = sys.argv[1], sys.argv[2]
GREEN = (0x2E, 0x7D, 0x32, 255)
MARK = (0xF4, 0xF7, 0xF3, 255)
WHITE = (255, 255, 255, 255)

sheet = Image.open(SHEET).convert('RGB')
TILE = (72, 72, 300, 300)  # the master icon on the sheet
tile = sheet.crop(TILE)
T = tile.width
INSET = 20  # skip the tile's rounded corners (sheet background outside)

# Mark coverage from the red channel: ~50 on the green, ~244 on the mark.
alpha = Image.new('L', tile.size, 0)
tp, ap = tile.load(), alpha.load()
for y in range(INSET, T - INSET):
    for x in range(INSET, T - INSET):
        r = tp[x, y][0]
        ap[x, y] = max(0, min(255, round((r - 60) * 255 / (235 - 60))))
box = alpha.point(lambda v: 255 if v > 128 else 0).getbbox()
print('mark bbox in tile', box, 'tile', T)

PAD = 3
crop = alpha.crop((box[0] - PAD, box[1] - PAD, box[2] + PAD, box[3] + PAD))
UP = 10
big = crop.resize((crop.width * UP, crop.height * UP), Image.BICUBIC)


def smooth(v):
    lo, hi = 0.42 * 255, 0.58 * 255
    if v <= lo:
        return 0
    if v >= hi:
        return 255
    t = (v - lo) / (hi - lo)
    return round(255 * t * t * (3 - 2 * t))


mask = big.point(smooth)
inner = (PAD * UP, PAD * UP, mask.width - PAD * UP, mask.height - PAD * UP)
mask = mask.crop(inner)  # exactly the mark's bounding box
bw, bh = box[2] - box[0], box[3] - box[1]
cx = (box[0] + box[2]) / 2 / T  # mark centre within the tile (0..1)
cy = (box[1] + box[3]) / 2 / T


def place(canvas, side, centre, colour):
    """Draws the mark with its bounding box `side` px on its longer edge."""
    scale = side / max(bw, bh)
    w, h = round(bw * scale), round(bh * scale)
    m = mask.resize((w, h), Image.LANCZOS)
    fill = Image.new('RGBA', (w, h), colour)
    canvas.paste(fill, (round(centre[0] - w / 2), round(centre[1] - h / 2)), m)


def tile_icon(size, radius=0.0):
    """The master look: green square (rounded by `radius`), mark as on the sheet."""
    big_size = size * 4
    img = Image.new('RGBA', (big_size, big_size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, big_size - 1, big_size - 1), radius=radius * big_size, fill=GREEN)
    img = img.resize((size, size), Image.LANCZOS)
    place(img, max(bw, bh) / T * size, (cx * size, cy * size), MARK)
    return img


def foreground(size, colour=MARK, share=0.44):
    """Adaptive foreground: transparent 108 dp canvas, mark box `share` of it
    (its corners stay inside the 66 dp safe circle)."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    place(img, share * size, (size / 2, size / 2), colour)
    return img


def disc(size):
    """Pre-Android 12 splash: the green circle with the mark (as Android 12
    draws it: mark box 66 % of the circle)."""
    big_size = size * 4
    img = Image.new('RGBA', (big_size, big_size), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((0, 0, big_size - 1, big_size - 1), fill=GREEN)
    img = img.resize((size, size), Image.LANCZOS)
    place(img, 0.66 * size, (size / 2, size / 2), MARK)
    return img


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


res = os.path.join('android', 'app', 'src', 'main', 'res')
for dpi, k in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    save(tile_icon(round(48 * k), radius=0.18), res, f'mipmap-{dpi}', 'ic_launcher.png')
    save(foreground(round(108 * k)), res, f'mipmap-{dpi}', 'ic_launcher_foreground.png')
    save(foreground(round(108 * k), WHITE), res, f'mipmap-{dpi}', 'ic_launcher_monochrome.png')
    save(disc(round(160 * k)), res, f'drawable-{dpi}', 'launch_image.png')

# In the app: the splash mark (drawn at 240 dp in a 160 dp circle) and the
# rounded icon.
save(foreground(1024), 'assets', 'brand', 'qout_mark.png')
save(tile_icon(1024, radius=0.18), 'assets', 'brand', 'qout_icon.png')
# For the stores: full squares (the stores round them).
save(tile_icon(1024), 'store', 'icon-1024.png')
save(tile_icon(512), 'store', 'play-store-icon-512.png')
print('done')


def splash_icon(size):
    """Android 12+ splash icon without an icon background (288 dp canvas,
    masked to a 192 dp circle): the 160 dp green circle and the 106 dp mark
    are drawn in, so no launcher's mask shape can change them."""
    big_size = size * 4
    img = Image.new('RGBA', (big_size, big_size), (0, 0, 0, 0))
    d = 160 / 288 * big_size
    o = (big_size - d) / 2
    ImageDraw.Draw(img).ellipse((o, o, o + d - 1, o + d - 1), fill=GREEN)
    img = img.resize((size, size), Image.LANCZOS)
    place(img, 0.44 * 240 / 288 * size, (size / 2, size / 2), MARK)
    return img


for dpi, k in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    save(splash_icon(round(288 * k)), res, f'drawable-{dpi}', 'splash_icon.png')
print('splash icons done')
