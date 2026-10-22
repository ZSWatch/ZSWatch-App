"""Frames raw app screenshots into store images: caption, phone frame, background.

Usage:
  python frame_screenshots.py spec.json --font Inter.ttf --out DIR

spec.json:
  {"platform": "ios" | "android",
   "screens": [{"file": "home.png", "title": "...", "subtitle": "..."}, ...]}

Needs Pillow. Use a font licensed for marketing use (e.g. Inter, OFL); SF Pro
may only be used for Apple-platform UI mockups.
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# App Store 6.9" portrait, and a 9:16 Play Store phone image.
SIZES = {"ios": (1320, 2868), "android": (1080, 1920)}
TOP = (11, 37, 48)
BOTTOM = (5, 8, 12)
GLOW = (0, 188, 212)
TITLE = (255, 255, 255)
SUBTITLE = (159, 179, 191)


def font(path, size, weight):
    f = ImageFont.truetype(path, size)
    try:
        f.set_variation_by_name(weight)
    except (OSError, ValueError):
        pass
    return f


def background(w, h):
    img = Image.new("RGB", (w, h))
    px = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        px.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([w * 0.05, h * 0.3, w * 0.95, h * 0.85], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12))
    img.paste(Image.new("RGB", (w, h), GLOW), mask=glow)
    return img


def wrap(draw, text, f, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=f) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line] if line else lines


def clean_status_bar(shot, platform, font_path):
    """Replaces the captured status bar with a neutral 9:41 one."""
    shot = shot.convert("RGB")
    w, h = shot.size
    bar = round(h * 88 / 1792) if platform == "ios" else round(h * 0.035)
    fill = shot.getpixel((4, 4))
    d = ImageDraw.Draw(shot)
    d.rectangle([0, 0, w, bar], fill=fill)
    f = font(font_path, round(bar * 0.36), "SemiBold")
    cy = bar * (0.55 if platform == "ios" else 0.5)
    d.text((w * 0.1, cy), "9:41", font=f, fill=(255, 255, 255), anchor="lm")
    # Signal, Wi-Fi and battery, drawn from the right edge.
    s = bar * 0.26
    x = w * 0.93
    d.rounded_rectangle([x - s * 2.1, cy - s * 0.5, x, cy + s * 0.5], radius=s * 0.18, outline=(255, 255, 255), width=max(2, round(s * 0.09)))
    d.rounded_rectangle([x - s * 1.95, cy - s * 0.36, x - s * 0.5, cy + s * 0.36], radius=s * 0.1, fill=(255, 255, 255))
    d.rectangle([x + s * 0.08, cy - s * 0.17, x + s * 0.2, cy + s * 0.17], fill=(255, 255, 255))
    x -= s * 2.6
    for i, r in enumerate((1.0, 0.68, 0.36)):
        d.arc([x - s * r, cy - s * r * 0.9, x + s * r, cy + s * r * 1.1], 225, 315, fill=(255, 255, 255), width=max(2, round(s * 0.18)))
    d.ellipse([x - s * 0.12, cy + s * 0.55, x + s * 0.12, cy + s * 0.79], fill=(255, 255, 255))
    x -= s * 3.2
    for i in range(4):
        bh = s * (0.35 + 0.22 * i)
        d.rounded_rectangle([x + i * s * 0.42, cy + s * 0.5 - bh, x + i * s * 0.42 + s * 0.28, cy + s * 0.5], radius=s * 0.06, fill=(255, 255, 255))
    return shot


def phone(shot, platform, width):
    """Draws a generic modern phone around the screenshot."""
    bezel = round(width * 0.03)
    screen_w = width - 2 * bezel
    shot = shot.resize((screen_w, round(shot.height * screen_w / shot.width)), Image.LANCZOS)
    height = shot.height + 2 * bezel
    radius = round(width * 0.13)
    pad = round(width * 0.02)  # Room for side buttons.
    img = Image.new("RGBA", (width + 2 * pad, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    btn = (58, 62, 68, 255)
    if platform == "ios":
        for top, length in ((0.17, 0.05), (0.25, 0.09), (0.36, 0.09)):
            d.rounded_rectangle([pad - pad * 0.7, height * top, pad + 4, height * (top + length)], radius=pad * 0.3, fill=btn)
        d.rounded_rectangle([pad + width - 4, height * 0.27, pad + width + pad * 0.7, height * 0.4], radius=pad * 0.3, fill=btn)
    else:
        d.rounded_rectangle([pad + width - 4, height * 0.2, pad + width + pad * 0.7, height * 0.27], radius=pad * 0.3, fill=btn)
        d.rounded_rectangle([pad + width - 4, height * 0.32, pad + width + pad * 0.7, height * 0.45], radius=pad * 0.3, fill=btn)
    d.rounded_rectangle([pad, 0, pad + width, height], radius=radius, fill=(70, 75, 82, 255))
    d.rounded_rectangle([pad + 3, 3, pad + width - 3, height - 3], radius=radius - 3, fill=(14, 15, 17, 255))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width, shot.height], radius=radius - bezel, fill=255)
    img.paste(shot, (pad + bezel, bezel), mask)
    cx = pad + width / 2
    if platform == "ios":
        iw, ih = width * 0.29, width * 0.085
        top = bezel + width * 0.028
        d.rounded_rectangle([cx - iw / 2, top, cx + iw / 2, top + ih], radius=ih / 2, fill=(0, 0, 0, 255))
    else:
        r = width * 0.02
        top = bezel + width * 0.035
        d.ellipse([cx - r, top - r, cx + r, top + r], fill=(0, 0, 0, 255))
    return img


def compose(spec_screen, platform, font_path, src_dir):
    w, h = SIZES[platform]
    img = background(w, h)
    d = ImageDraw.Draw(img)
    title_font = font(font_path, round(w * 0.072), "Bold")
    sub_font = font(font_path, round(w * 0.036), "Regular")
    y = h * 0.055
    for line in wrap(d, spec_screen["title"], title_font, w * 0.86):
        d.text((w / 2, y), line, font=title_font, fill=TITLE, anchor="mt")
        y += title_font.size * 1.15
    y += h * 0.008
    for line in wrap(d, spec_screen.get("subtitle", ""), sub_font, w * 0.8):
        d.text((w / 2, y), line, font=sub_font, fill=SUBTITLE, anchor="mt")
        y += sub_font.size * 1.35
    shot = Image.open(src_dir / spec_screen["file"])
    shot = clean_status_bar(shot, platform, font_path)
    device = phone(shot, platform, round(w * 0.8))
    # Same phone position on every image; captions get up to two lines each.
    top = round(max(y + h * 0.02, h * 0.205))
    shadow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(w - device.width) / 2 + 20, top + 40, (w + device.width) / 2 - 20, top + device.height + 40],
        radius=device.width * 0.13, fill=170)
    shadow = shadow.filter(ImageFilter.GaussianBlur(w * 0.03))
    img.paste(Image.new("RGB", (w, h), (0, 0, 0)), mask=shadow)
    # The phone may run off the bottom edge; the screen top is what matters.
    img.paste(device, ((w - device.width) // 2, top), device)
    return img


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("spec")
    parser.add_argument("--font", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    spec_path = Path(args.spec)
    spec = json.loads(spec_path.read_text())
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for i, screen in enumerate(spec["screens"], 1):
        img = compose(screen, spec["platform"], args.font, spec_path.parent)
        name = out / f"{i:02d}_{Path(screen['file']).stem}.png"
        img.save(name)
        print(name)


if __name__ == "__main__":
    main()
