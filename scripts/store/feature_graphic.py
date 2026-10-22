"""Play Store feature graphic (1024x500) in the same style as the screenshots.

Usage:
  python feature_graphic.py LEFT.png RIGHT.png --font Inter.ttf --out feature.png
"""

import argparse

from PIL import Image, ImageDraw

from frame_screenshots import background, clean_status_bar, font, phone, wrap

W, H = 1024, 500


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("left")
    parser.add_argument("right")
    parser.add_argument("--font", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--title", default="ZSWatch")
    parser.add_argument("--subtitle", default="Companion app for the open-source smartwatch")
    args = parser.parse_args()
    img = background(W, H)
    d = ImageDraw.Draw(img)
    d.text((64, 190), args.title, font=font(args.font, 76, "Bold"), fill=(255, 255, 255), anchor="ls")
    sub = font(args.font, 26, "Regular")
    y = 235
    for line in wrap(d, args.subtitle, sub, 420):
        d.text((66, y), line, font=sub, fill=(159, 179, 191), anchor="ls")
        y += 36
    for i, path in enumerate((args.left, args.right)):
        shot = clean_status_bar(Image.open(path), "android", args.font)
        device = phone(shot, "android", 230)
        x = 560 + i * 215
        top = 60 + (1 - i) * 50
        img.paste(device, (x, top), device)
    img.save(args.out)
    print(args.out)


if __name__ == "__main__":
    main()
