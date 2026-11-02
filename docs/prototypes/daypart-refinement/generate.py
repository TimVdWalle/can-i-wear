"""Edited native captures for design review only; does not run or modify the app."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
NATIVE = ROOT / '.build/verification/ui-polish-focused-3-attachments'
CARD = (28, 28, 30)
FONT = '/System/Library/Fonts/Helvetica.ttc'


def text_layer(source, box, background, finished):
    crop = source.crop(box).convert('RGB')
    pixels = list(crop.get_flattened_data())
    # Native glyph rasterization, font size and placement are retained.
    foreground = max(pixels, key=lambda p: sum(p))
    direction = [foreground[i] - background[i] for i in range(3)]
    denominator = sum(v * v for v in direction)
    mask = Image.new('L', crop.size)
    mask.putdata([
        round(255 * max(0, min(1, sum((p[i] - background[i]) * direction[i]
                                    for i in range(3)) / denominator)))
        for p in pixels
    ])
    color = (190, 190, 194) if finished else foreground
    layer = Image.new('RGB', crop.size, color)
    return layer, mask


def render(source, rows, gallery=False, light=False):
    growth = 42 if gallery else 48  # 14 / 16 logical points at native 3x.
    main_card = (255, 255, 255) if light else CARD
    result = Image.new('RGB', (source.width, source.height + growth * len(rows)))
    previous = 0
    shift = 0
    for top, bottom, tiles in rows:
        result.paste(source.crop((0, previous, source.width, top)), (0, previous + shift))
        # Extend the existing parent card, without scaling its artwork or text.
        scanline = source.crop((0, top - 2, source.width, top - 1))
        result.paste(scanline.resize((source.width, growth)), (0, top + shift))
        result.paste(source.crop((0, top, source.width, bottom)), (0, top + shift + growth))
        for left, right, finished in tiles:
            old_fill = source.getpixel(((left + right) // 2, top + 8))
            old_badge = source.getpixel((left + 15, bottom - 25))
            fill = ((231, 231, 234) if light else (50, 50, 54)) if finished else old_fill
            badge = ((211, 211, 216) if light else (65, 65, 70)) if finished else old_badge
            width, height = right - left, bottom - top + growth
            tile = Image.new('RGB', (width, height), main_card)
            draw = ImageDraw.Draw(tile)
            draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=30, fill=fill)
            pill_top = height - 24 - 66
            draw.rounded_rectangle((6, pill_top, width - 7, height - 25), radius=33, fill=badge)
            if gallery:
                lines = [(top + 18, top + 61, 9, old_fill),
                         (top + 73, top + 108, 24, old_badge)]
            else:
                lines = [(top + 20, top + 61, 9, old_fill),
                         (top + 73, top + 109, 15, old_fill),
                         (top + 126, top + 162, 30, old_badge)]
            for y0, y1, delta, old_background in lines:
                layer, mask = text_layer(source, (left + 7, y0, right - 7, y1), old_background, finished)
                if finished and light:
                    layer = Image.new('RGB', layer.size, (91, 91, 96))
                tile.paste(layer, (7, y0 - top + delta), mask)
            result.paste(tile, (left, top + shift))
        previous = bottom
        shift += growth
    result.paste(source.crop((0, previous, source.width, source.height)), (0, previous + shift))
    return result.crop((0, 0, source.width, source.height))


def caption(draw, xy, text, size=29, color='#EEEEF0'):
    draw.text(xy, text, font=ImageFont.truetype(FONT, size), fill=color)


def main():
    mini = Image.open(NATIVE / '343DB4A9-2B7A-48F1-B5A0-B76770479596.png').convert('RGB')
    gallery = Image.open(NATIVE / 'EEC8D16B-558B-4120-AFC8-8E4907C1C452.png').convert('RGB')
    # The gallery capture has a transient empty title area; reuse the identical
    # native header from the mini capture instead of inventing a different one.
    gallery.paste(mini.crop((0, 0, 1170, 440)), (0, 0))
    mini_rows = [(y, y + 183, [(84, 408, True), (423, 747, False), (762, 1086, False)])
                 for y in (817, 1440, 2037)]
    gallery_tiles = [(84, 229, True), (235, 381, False), (387, 533, False),
                     (640, 785, True), (791, 937, False), (943, 1087, False)]
    gallery_rows = [(y, y + 130, gallery_tiles) for y in (1171, 2095)]
    mini_after = render(mini, mini_rows)
    gallery_after = render(gallery, gallery_rows, gallery=True)
    mini_after.save(OUT / 'mini-proposed.png')
    gallery_after.save(OUT / 'gallery-proposed.png')

    board = Image.new('RGB', (1600, 1720), '#141416')
    draw = ImageDraw.Draw(board)
    caption(draw, (40, 28), 'Daypart refinement — PROPOSAL', 38)
    caption(draw, (40, 86), 'Lighter finished gray + more space inside the tiles. Active colors and fonts unchanged.', 24, '#B9B9C0')
    caption(draw, (40, 148), 'CURRENT', 26, '#A8A8AF')
    caption(draw, (820, 148), 'PROPOSED', 26, '#B7DDC4')
    caption(draw, (40, 198), '2–3 items · mini heroes', 30)
    for image, x, bottom in [(mini, 40, 1032), (mini_after, 820, 1080)]:
        crop = image.crop((48, 445, 1122, bottom))
        crop.thumbnail((740, 500), Image.Resampling.LANCZOS)
        board.paste(crop, (x, 252))
    caption(draw, (40, 740), '4+ items · gallery', 30)
    for image, x, bottom in [(gallery, 40, 1332), (gallery_after, 820, 1374)]:
        crop = image.crop((48, 445, 1122, bottom))
        crop.thumbnail((740, 650), Image.Resampling.LANCZOS)
        board.paste(crop, (x, 794))
    caption(draw, (40, 1480), 'Finished tiles: neutral gray instead of near-black.', 28)
    caption(draw, (40, 1528), 'Daypart tiles: wider vertical gaps, more edge padding, padded status pills.', 28)
    caption(draw, (40, 1624), 'Edited native captures for review only — not implemented or device-validated.', 24, '#A8A8AF')
    board.save(OUT / 'comparison.png')


if __name__ == '__main__':
    main()
