"""Generate 240x240 watchface background PNGs and LVGL v9 binary files."""
import math, random, base64, struct, argparse, os, shutil, io
from PIL import Image, ImageDraw, ImageFilter

SIZE = 240
CENTER = SIZE // 2
RADIUS = SIZE // 2


def radial_gradient(cx, cy, x, y, max_r):
    d = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    return min(d / max_r, 1.0)


def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def smoothstep(t):
    return t * t * (3 - 2 * t)


def hash_noise_2d(xi, yi, seed=0):
    n = xi * 374761393 + yi * 668265263 + seed * 1447
    n = (n ^ (n >> 13)) * 1274126177
    n ^= n >> 16
    return (n & 0xFFFFFFFF) / 0xFFFFFFFF


def value_noise(x, y, seed=0):
    x0 = math.floor(x)
    y0 = math.floor(y)
    x1 = x0 + 1
    y1 = y0 + 1

    tx = smoothstep(x - x0)
    ty = smoothstep(y - y0)

    n00 = hash_noise_2d(x0, y0, seed)
    n10 = hash_noise_2d(x1, y0, seed)
    n01 = hash_noise_2d(x0, y1, seed)
    n11 = hash_noise_2d(x1, y1, seed)

    nx0 = n00 + (n10 - n00) * tx
    nx1 = n01 + (n11 - n01) * tx
    return nx0 + (nx1 - nx0) * ty


def fbm(x, y, octaves=4, seed=0):
    value = 0.0
    amplitude = 0.5
    frequency = 1.0
    total = 0.0
    for octave in range(octaves):
        value += value_noise(x * frequency, y * frequency, seed + octave * 17) * amplitude
        total += amplitude
        amplitude *= 0.5
        frequency *= 2.0
    return value / total if total else 0.0


def circle_mask(img):
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([0, 0, SIZE - 1, SIZE - 1], fill=255)
    final = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    final.paste(img, mask=mask)
    return final


def save_lvgl_bin(img, path):
    """Save image as LVGL v9 RGB565 binary (.bin) file with Floyd-Steinberg dithering."""
    w, h = img.size
    stride = w * 2
    # 12-byte header: magic, color_format, flags, width, height, stride, reserved
    header = struct.pack('<BBHHHHH', 0x19, 0x12, 0, w, h, stride, 0)

    # Work in floating-point to accumulate dithering error
    buf = [[list(img.getpixel((x, y))[:3]) for x in range(w)] for y in range(h)]

    pixels = bytearray(w * h * 2)
    idx = 0
    for y in range(h):
        for x in range(w):
            r = max(0, min(255, int(buf[y][x][0])))
            g = max(0, min(255, int(buf[y][x][1])))
            b = max(0, min(255, int(buf[y][x][2])))

            # Quantize to RGB565
            r5 = (r >> 3) & 0x1F
            g6 = (g >> 2) & 0x3F
            b5 = (b >> 3) & 0x1F

            rgb565 = (r5 << 11) | (g6 << 5) | b5
            pixels[idx] = rgb565 & 0xFF
            pixels[idx + 1] = (rgb565 >> 8) & 0xFF
            idx += 2

            # Quantization error per channel
            er = r - (r5 << 3 | r5 >> 2)
            eg = g - (g6 << 2 | g6 >> 4)
            eb = b - (b5 << 3 | b5 >> 2)

            # Distribute error using Floyd-Steinberg weights
            for ch, err in enumerate((er, eg, eb)):
                if x + 1 < w:
                    buf[y][x + 1][ch] += err * 7 / 16
                if y + 1 < h:
                    if x - 1 >= 0:
                        buf[y + 1][x - 1][ch] += err * 3 / 16
                    buf[y + 1][x][ch] += err * 5 / 16
                    if x + 1 < w:
                        buf[y + 1][x + 1][ch] += err * 1 / 16

    with open(path, 'wb') as f:
        f.write(header)
        f.write(pixels)


def make_deep_space():
    """Deep blue/purple nebula with star-like specks."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            c = lerp_color((15, 20, 55), (35, 10, 60), t)
            img.putpixel((x, y), c)

    # Add subtle nebula clouds
    overlay = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    random.seed(77)
    for _ in range(20):
        cx = random.randint(30, 210)
        cy = random.randint(30, 210)
        r = random.randint(30, 80)
        color = random.choice([
            (20, 10, 40),
            (10, 15, 45),
            (25, 5, 35),
        ])
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=25))

    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = overlay.getpixel((x, y))
            img.putpixel((x, y), tuple(min(255, a + b) for a, b in zip(bg, fg)))

    # Stars
    random.seed(42)
    for _ in range(60):
        sx, sy = random.randint(10, 230), random.randint(10, 230)
        if radial_gradient(CENTER, CENTER, sx, sy, RADIUS) < 0.98:
            brightness = random.randint(80, 200)
            img.putpixel((sx, sy), (brightness, brightness, brightness + 20))

    return circle_mask(img)


def make_ocean_gradient():
    """Dark teal to deep blue gradient with horizontal wave lines."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            yt = y / SIZE
            base = lerp_color((8, 30, 50), (5, 15, 40), yt)
            base = lerp_color(base, (3, 8, 18), t ** 0.6)
            # Subtle wave pattern
            wave = math.sin(y * 0.15 + x * 0.02) * 8
            base = tuple(min(255, max(0, c + int(wave))) for c in base)
            img.putpixel((x, y), base)

    img = img.filter(ImageFilter.GaussianBlur(radius=1))
    return circle_mask(img)


def make_ember_glow():
    """Dark with warm orange/red glow from bottom."""
    img = Image.new("RGB", (SIZE, SIZE))
    glow_cy = SIZE + 20

    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            base = lerp_color((15, 8, 10), (5, 3, 5), t)

            gt = radial_gradient(CENTER, glow_cy, x, y, 180)
            gt = max(0, 1 - gt) ** 1.5
            warm = (int(70 * gt), int(25 * gt), int(5 * gt))

            c = tuple(min(255, a + b) for a, b in zip(base, warm))
            img.putpixel((x, y), c)

    return circle_mask(img)


def make_aurora_green():
    """Dark with green/cyan aurora bands."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            base = lerp_color((5, 10, 18), (2, 4, 10), t)
            img.putpixel((x, y), base)

    # Aurora streaks
    overlay = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    random.seed(99)
    for i in range(12):
        y_base = 50 + i * 15
        phase = random.random() * 6
        for x in range(SIZE):
            wave = math.sin(x * 0.04 + phase) * 25 + math.sin(x * 0.02 + phase * 0.5) * 15
            y_pos = int(y_base + wave)
            intensity = random.uniform(0.5, 1.0)
            green = int(45 * intensity)
            blue = int(30 * intensity)
            for dy in range(-5, 6):
                yy = y_pos + dy
                if 0 <= yy < SIZE and 0 <= x < SIZE:
                    fade = max(0, 1 - abs(dy) / 6) ** 1.5
                    c = (0, int(green * fade), int(blue * fade))
                    orig = overlay.getpixel((x, yy))
                    overlay.putpixel((x, yy), tuple(min(255, a + b) for a, b in zip(orig, c)))

    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=4))

    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = overlay.getpixel((x, y))
            img.putpixel((x, y), tuple(min(255, a + b) for a, b in zip(bg, fg)))

    return circle_mask(img)


def make_purple_vortex():
    """Dark with subtle purple spiral/vortex pattern."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - CENTER, y - CENTER
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            angle = math.atan2(dy, dx)
            dist = math.sqrt(dx*dx + dy*dy)

            # Spiral pattern
            spiral = math.sin(angle * 3 + dist * 0.05) * 0.5 + 0.5
            r = int(15 + 25 * spiral * (1 - t))
            g = int(5 + 8 * spiral * (1 - t))
            b = int(25 + 40 * spiral * (1 - t))


            img.putpixel((x, y), (r, g, b))

    img = img.filter(ImageFilter.GaussianBlur(radius=3))
    return circle_mask(img)


def make_midnight_frost():
    """Dark background with icy blue crystalline shards radiating from center."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            base = lerp_color((8, 12, 22), (3, 5, 12), t)
            img.putpixel((x, y), base)

    # Ice crystal rays
    overlay = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    random.seed(55)
    for i in range(24):
        angle = (i / 24) * 2 * math.pi + random.uniform(-0.05, 0.05)
        length = random.randint(60, 110)
        brightness = random.uniform(0.4, 1.0)
        for d in range(length):
            x = int(CENTER + d * math.cos(angle))
            y = int(CENTER + d * math.sin(angle))
            if 0 <= x < SIZE and 0 <= y < SIZE:
                fade = (1 - d / length) ** 0.8
                b_val = int(55 * fade * brightness)
                g_val = int(40 * fade * brightness)
                r_val = int(15 * fade * brightness)
                for dy in range(-1, 2):
                    yy = y + dy
                    if 0 <= yy < SIZE:
                        orig = overlay.getpixel((x, yy))
                        overlay.putpixel((x, yy), tuple(min(255, a + b) for a, b in zip(orig, (r_val, g_val, b_val))))

    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=3))

    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = overlay.getpixel((x, y))
            img.putpixel((x, y), tuple(min(255, a + b) for a, b in zip(bg, fg)))

    return circle_mask(img)


def make_solar_flare():
    """Dark with golden radial light streaks from a corner."""
    img = Image.new("RGB", (SIZE, SIZE))
    sun_x, sun_y = 40, 40

    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            base = lerp_color((12, 10, 8), (4, 3, 2), t)

            gt = radial_gradient(sun_x, sun_y, x, y, 200)
            gt = max(0, 1 - gt) ** 2.0
            warm = (int(60 * gt), int(40 * gt), int(8 * gt))

            c = tuple(min(255, a + b) for a, b in zip(base, warm))

            # Subtle radial lines from sun
            dx, dy_v = x - sun_x, y - sun_y
            angle = math.atan2(dy_v, dx)
            ray = (math.sin(angle * 12) * 0.5 + 0.5) ** 3
            ray_c = int(25 * ray * (1 - gt) * (1 - t))
            c = tuple(min(255, v + ray_c) for v in c)

            img.putpixel((x, y), c)

    img = img.filter(ImageFilter.GaussianBlur(radius=1))
    return circle_mask(img)


def make_matrix_rain():
    """Dark green with subtle vertical digital rain columns."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            base = lerp_color((4, 10, 6), (2, 5, 3), t)
            img.putpixel((x, y), base)

    # Rain columns
    overlay = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    random.seed(33)
    for col in range(0, SIZE, 6):
        if random.random() < 0.5:
            continue
        start_y = random.randint(0, SIZE // 2)
        length = random.randint(40, 140)
        brightness = random.uniform(0.3, 1.0)
        for y in range(start_y, min(start_y + length, SIZE)):
            fade = 1 - (y - start_y) / length
            g_val = int(35 * fade * brightness)
            for dx in range(-1, 2):
                xx = col + dx
                if 0 <= xx < SIZE and 0 <= y < SIZE:
                    edge_fade = 0.5 if dx != 0 else 1.0
                    orig = overlay.getpixel((xx, y))
                    overlay.putpixel((xx, y), tuple(min(255, a + b) for a, b in zip(orig, (0, int(g_val * edge_fade), 0))))

    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=2))

    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = overlay.getpixel((x, y))
            img.putpixel((x, y), tuple(min(255, a + b) for a, b in zip(bg, fg)))

    return circle_mask(img)


def make_copper_mesh():
    """Dark with warm copper/bronze hexagonal mesh overlay."""
    img = Image.new("RGB", (SIZE, SIZE))
    hex_size = 24

    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            base = lerp_color((12, 8, 6), (4, 3, 2), t)

            # Hex grid distance
            row = y / (hex_size * 1.5)
            col = x / (hex_size * math.sqrt(3))
            if int(row) % 2:
                col -= 0.5
            cx_hex = round(col) * hex_size * math.sqrt(3)
            cy_hex = round(row) * hex_size * 1.5
            if int(round(row)) % 2:
                cx_hex += hex_size * math.sqrt(3) * 0.5
            dist = math.sqrt((x - cx_hex) ** 2 + (y - cy_hex) ** 2)
            edge = abs(dist - hex_size * 0.8)
            if edge < 2.5:
                line_fade = (1 - edge / 2.5) * (1 - t) ** 0.5
                copper = (int(40 * line_fade), int(22 * line_fade), int(6 * line_fade))
                base = tuple(min(255, a + b) for a, b in zip(base, copper))

            img.putpixel((x, y), base)

    img = img.filter(ImageFilter.GaussianBlur(radius=1))
    return circle_mask(img)


def make_starfield():
    """Pure deep black with a dense, layered starfield."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            base = lerp_color((3, 3, 6), (1, 1, 3), t)
            img.putpixel((x, y), base)

    # Dense starfield with varying sizes and brightness
    random.seed(17)
    # Dim distant stars
    for _ in range(200):
        sx, sy = random.randint(5, 235), random.randint(5, 235)
        if radial_gradient(CENTER, CENTER, sx, sy, RADIUS) < 0.98:
            b = random.randint(30, 70)
            img.putpixel((sx, sy), (b, b, b + 5))

    # Medium stars
    for _ in range(80):
        sx, sy = random.randint(5, 235), random.randint(5, 235)
        if radial_gradient(CENTER, CENTER, sx, sy, RADIUS) < 0.98:
            b = random.randint(90, 165)
            tint = random.choice([(0, 0, 10), (10, 5, 0), (0, 5, 5)])
            img.putpixel((sx, sy), (b + tint[0], b + tint[1], b + tint[2]))
            # Small glow around medium stars
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = sx + dx, sy + dy
                if 0 <= nx < SIZE and 0 <= ny < SIZE:
                    orig = img.getpixel((nx, ny))
                    img.putpixel((nx, ny), tuple(min(255, a + b // 5) for a in orig))

    # Bright stars
    for _ in range(15):
        sx, sy = random.randint(15, 225), random.randint(15, 225)
        if radial_gradient(CENTER, CENTER, sx, sy, RADIUS) < 0.95:
            b = random.randint(180, 240)
            img.putpixel((sx, sy), (b, b, min(255, b + 15)))

    return circle_mask(img)


def make_lava_flow():
    """Dark with red/orange flowing molten patterns from below."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            yt = y / SIZE
            base = lerp_color((10, 4, 4), (4, 2, 2), t)

            # Lava glow from bottom
            lava_t = max(0, (yt - 0.4) / 0.6) ** 1.2
            flow = math.sin(x * 0.06 + y * 0.03) * 0.3 + math.sin(x * 0.03 - y * 0.05) * 0.3 + 0.4
            flow = max(0, min(1, flow))
            r = int(75 * lava_t * flow)
            g = int(20 * lava_t * flow)
            b_val = int(3 * lava_t * flow)

            c = tuple(min(255, a + b) for a, b in zip(base, (r, g, b_val)))
            img.putpixel((x, y), c)

    img = img.filter(ImageFilter.GaussianBlur(radius=2))
    return circle_mask(img)


def make_topographic_lines():
    """Dark terrain-style contour lines with cool blue elevation hints."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            dx = x - CENTER
            dy = y - CENTER
            height = (
                math.sin(x * 0.045)
                + math.cos(y * 0.05)
                + math.sin((x + y) * 0.03)
                + math.cos(math.sqrt(dx * dx + dy * dy) * 0.09)
            )
            height = (height + 4) / 8
            base = lerp_color((8, 12, 18), (3, 5, 9), t)
            line = abs((height * 18) % 1.0 - 0.5)
            if line < 0.08:
                glow = int((1 - line / 0.08) * 42 * (1 - t * 0.4))
                base = tuple(min(255, a + b) for a, b in zip(base, (0, glow // 2, glow)))
            img.putpixel((x, y), base)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.6))
    return circle_mask(img)


def make_retro_sunburst():
    """Retro poster-like radial stripes with a warm sunset palette."""
    img = Image.new("RGB", (SIZE, SIZE))
    sun_x, sun_y = CENTER, 158
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            angle = math.atan2(y - sun_y, x - sun_x)
            stripe = int(((angle + math.pi) / (2 * math.pi)) * 24) % 2
            base = (40, 16, 14) if stripe == 0 else (112, 52, 28)
            dist = radial_gradient(sun_x, sun_y, x, y, 170)
            warm = lerp_color((255, 186, 82), base, min(dist, 1.0))
            color = lerp_color(warm, (8, 4, 4), t * 0.7)
            horizon = max(0, min(1, (y - 120) / 80))
            color = tuple(min(255, int(c * (0.92 + 0.08 * horizon))) for c in color)
            img.putpixel((x, y), color)

    overlay = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse([sun_x - 42, sun_y - 42, sun_x + 42, sun_y + 42], fill=(255, 186, 82))
    draw.rectangle([0, 170, SIZE, SIZE], fill=(22, 8, 10))
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=0.5))
    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = overlay.getpixel((x, y))
            img.putpixel((x, y), tuple(min(255, a + b) for a, b in zip(bg, fg)))

    return circle_mask(img)


def make_ink_wash():
    """Minimal monochrome ink wash with soft black brush blooms."""
    img = Image.new("RGB", (SIZE, SIZE), (224, 220, 210))
    random.seed(81)

    # Paper grain
    for y in range(SIZE):
        for x in range(SIZE):
            grain = random.randint(-8, 8)
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            paper = max(0, min(255, 224 + grain - int(t * 18)))
            img.putpixel((x, y), (paper, paper - 4, paper - 10))

    wash = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(wash)
    for _ in range(14):
        cx = random.randint(40, 200)
        cy = random.randint(35, 205)
        rx = random.randint(18, 52)
        ry = random.randint(10, 40)
        gray = random.randint(18, 45)
        draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(gray, gray, gray))
    wash = wash.filter(ImageFilter.GaussianBlur(radius=12))

    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = wash.getpixel((x, y))[0]
            mix = int(fg * 0.55)
            color = tuple(max(0, c - mix) for c in bg)
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            img.putpixel((x, y), color)

    return circle_mask(img)


def make_mosaic_gem():
    """Faceted jewel-like mosaic with angular color blocks."""
    img = Image.new("RGB", (SIZE, SIZE))
    palette = [
        (20, 34, 68),
        (36, 80, 124),
        (16, 110, 112),
        (120, 44, 92),
        (208, 108, 62),
    ]
    tile = 24
    random.seed(121)
    field = []
    for ty in range(-1, SIZE // tile + 2):
        row = []
        for tx in range(-1, SIZE // tile + 2):
            row.append(random.choice(palette))
        field.append(row)

    for y in range(SIZE):
        for x in range(SIZE):
            gx = x / tile
            gy = y / tile
            tx = int(gx)
            ty = int(gy)
            fx = gx - tx
            fy = gy - ty
            c00 = field[ty + 1][tx + 1]
            c10 = field[ty + 1][tx + 2]
            c01 = field[ty + 2][tx + 1]
            c11 = field[ty + 2][tx + 2]
            if fx + fy < 1:
                base = lerp_color(c00, c10, fx * 0.7 + fy * 0.3)
            else:
                base = lerp_color(c11, c01, (1 - fx) * 0.4 + (1 - fy) * 0.6)

            edge = min(fx, fy, 1 - fx, 1 - fy)
            bevel = max(0, min(1, edge / 0.18))
            shade = 0.72 + bevel * 0.4
            color = tuple(min(255, int(c * shade)) for c in base)
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            color = lerp_color(color, (4, 4, 8), t * 0.45)
            img.putpixel((x, y), color)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.6))
    return circle_mask(img)


def make_brushed_titanium():
    """Industrial metallic background with brushed diagonal texture."""
    img = Image.new("RGB", (SIZE, SIZE))
    random.seed(141)
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            diagonal = (x * 0.7 + y * 1.1) * 0.08
            band = math.sin(diagonal) * 10 + math.sin(diagonal * 0.37) * 6
            grain = random.randint(-8, 8)
            metal = int(96 + band + grain - t * 28)
            blue = int(metal + 8 - t * 8)
            color = (
                max(0, min(255, metal)),
                max(0, min(255, metal + 2)),
                max(0, min(255, blue)),
            )
            img.putpixel((x, y), color)

    overlay = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.arc([22, 22, 218, 218], start=18, end=126, fill=(34, 40, 52), width=4)
    draw.arc([30, 30, 210, 210], start=198, end=318, fill=(170, 178, 190), width=2)
    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = overlay.getpixel((x, y))
            img.putpixel((x, y), tuple(min(255, a + b) for a, b in zip(bg, fg)))

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    return circle_mask(img)


def make_forest_canopy():
    """Organic green light filtering through overlapping canopy shapes."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            sky = lerp_color((18, 38, 22), (6, 14, 8), t)
            img.putpixel((x, y), sky)

    leaves = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(leaves)
    random.seed(201)
    leaf_palette = [(18, 58, 18), (30, 78, 28), (12, 42, 14), (48, 88, 30)]
    for _ in range(40):
        cx = random.randint(10, 230)
        cy = random.randint(10, 230)
        rx = random.randint(18, 46)
        ry = random.randint(10, 26)
        angle = random.uniform(0, math.pi)
        color = random.choice(leaf_palette)
        points = []
        for i in range(18):
            a = (i / 18) * 2 * math.pi
            px = math.cos(a) * rx
            py = math.sin(a) * ry
            rot_x = px * math.cos(angle) - py * math.sin(angle)
            rot_y = px * math.sin(angle) + py * math.cos(angle)
            points.append((cx + rot_x, cy + rot_y))
        draw.polygon(points, fill=color)

    leaves = leaves.filter(ImageFilter.GaussianBlur(radius=2.2))
    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = leaves.getpixel((x, y))
            mixed = tuple(min(255, int(a * 0.7 + b * 0.8)) for a, b in zip(bg, fg))
            light = max(0, 1 - radial_gradient(120, 84, x, y, 120)) ** 2
            mixed = tuple(min(255, c + int(light * k)) for c, k in zip(mixed, (28, 38, 12)))
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            img.putpixel((x, y), mixed)

    return circle_mask(img)


def make_pixel_neon():
    """Retro pixel-art grid with neon blocks and scanline energy."""
    img = Image.new("RGB", (SIZE, SIZE))
    cell = 8
    random.seed(303)
    palette = [
        (8, 14, 26),
        (18, 32, 56),
        (16, 88, 108),
        (126, 36, 112),
        (250, 96, 54),
    ]
    for y in range(SIZE):
        for x in range(SIZE):
            gx = x // cell
            gy = y // cell
            idx = (gx * 7 + gy * 11 + (gx ^ gy)) % len(palette)
            base = palette[idx]
            fx = (x % cell) / cell
            fy = (y % cell) / cell
            shade = 0.8 + (1 - min(fx, fy, 1 - fx, 1 - fy)) * 0.22
            color = tuple(min(255, int(c * shade)) for c in base)
            scan = 0.82 if y % 4 == 0 else 1.0
            color = tuple(int(c * scan) for c in color)
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            color = lerp_color(color, (4, 4, 8), t * 0.45)
            img.putpixel((x, y), color)

    return circle_mask(img)


def make_paper_cut():
    """Layered paper-cut arcs in muted editorial colors."""
    img = Image.new("RGB", (SIZE, SIZE), (210, 204, 194))
    layers = [
        ((182, 76, 58), [(-20, 130, 210, 300)]),
        ((50, 92, 120), [(34, 96, 262, 274)]),
        ((34, 58, 66), [(-30, 28, 170, 220)]),
        ((234, 178, 96), [(96, -40, 290, 176)]),
    ]

    for color, ellipses in layers:
        layer = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
        draw = ImageDraw.Draw(layer)
        for box in ellipses:
            draw.ellipse(box, fill=color)
        shadow = layer.filter(ImageFilter.GaussianBlur(radius=8))
        for y in range(SIZE):
            for x in range(SIZE):
                bg = img.getpixel((x, y))
                sh = shadow.getpixel((x, y))
                if sh != (0, 0, 0):
                    bg = tuple(max(0, c - int(v * 0.12)) for c, v in zip(bg, sh))
                fg = layer.getpixel((x, y))
                if fg != (0, 0, 0):
                    bg = fg
                img.putpixel((x, y), bg)

    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            color = img.getpixel((x, y))
            color = lerp_color(color, (8, 6, 6), t * 0.2)
            img.putpixel((x, y), color)

    return circle_mask(img)


def make_voronoi_stained_glass():
    """Voronoi cells with jewel colors and bright lead-like seams."""
    img = Image.new("RGB", (SIZE, SIZE))
    palette = [
        (34, 54, 112),
        (24, 110, 116),
        (126, 42, 92),
        (220, 112, 56),
        (72, 138, 62),
    ]
    random.seed(404)
    seeds = []
    for _ in range(26):
        sx = random.randint(15, 225)
        sy = random.randint(15, 225)
        color = random.choice(palette)
        seeds.append((sx, sy, color))

    for y in range(SIZE):
        for x in range(SIZE):
            nearest = 10 ** 9
            second = 10 ** 9
            chosen = palette[0]
            for sx, sy, color in seeds:
                dx = x - sx
                dy = y - sy
                dist = dx * dx + dy * dy
                if dist < nearest:
                    second = nearest
                    nearest = dist
                    chosen = color
                elif dist < second:
                    second = dist

            edge = max(0.0, min(1.0, (math.sqrt(second) - math.sqrt(nearest)) / 10.0))
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            glow = 0.72 + 0.28 * edge
            color = tuple(min(255, int(c * glow)) for c in chosen)
            if edge < 0.18:
                seam = int((1 - edge / 0.18) * 90)
                color = tuple(max(0, c - seam) for c in color)
            color = lerp_color(color, (6, 6, 10), t * 0.35)
            img.putpixel((x, y), color)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.5))
    return circle_mask(img)


def make_domain_warp_marble():
    """Domain-warped FBM marble with cool mineral veining."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            nx = x / SIZE
            ny = y / SIZE
            warp_x = fbm(nx * 3.2 + 1.7, ny * 3.2 + 4.3, octaves=4, seed=11)
            warp_y = fbm(nx * 3.2 + 7.1, ny * 3.2 + 2.9, octaves=4, seed=23)
            marble = fbm(nx * 5.0 + warp_x * 1.6, ny * 5.0 + warp_y * 1.6, octaves=5, seed=37)
            veins = abs(math.sin((nx * 8.0 + ny * 4.0 + marble * 5.5) * math.pi))
            base = lerp_color((208, 214, 220), (110, 128, 144), marble)
            vein_dark = int((1 - veins) ** 6 * 140)
            color = (
                max(0, min(255, base[0] - vein_dark)),
                max(0, min(255, base[1] - vein_dark // 2)),
                max(0, min(255, base[2] - vein_dark // 3)),
            )
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            color = lerp_color(color, (20, 24, 28), t * 0.42)
            img.putpixel((x, y), color)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.8))
    return circle_mask(img)


def make_halftone_poster():
    """Graphic halftone poster dots over a bold sunset-style gradient."""
    img = Image.new("RGB", (SIZE, SIZE))
    cell = 10
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            vertical = y / SIZE
            base = lerp_color((244, 196, 98), (202, 88, 60), vertical)
            base = lerp_color(base, (62, 18, 34), t * 0.55)

            cx = (x // cell) * cell + cell / 2
            cy = (y // cell) * cell + cell / 2
            tone = 0.5 + 0.5 * math.sin(cx * 0.04 + cy * 0.03)
            radius = 1.0 + tone * 3.2
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            if dist < radius:
                ink = (18, 12, 22)
                color = lerp_color(base, ink, 0.78)
            else:
                color = base

            if y > 168:
                color = lerp_color(color, (18, 8, 14), min(1.0, (y - 168) / 50))
            img.putpixel((x, y), color)

    return circle_mask(img)


def make_guilloche_dial():
    """Engraved guilloche-style dial pattern with a dark fumé edge."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            dx = x - CENTER
            dy = y - CENTER
            r = math.sqrt(dx * dx + dy * dy)
            angle = math.atan2(dy, dx)
            t = min(r / RADIUS, 1.0)

            wave_a = math.sin(r * 0.24 + angle * 10)
            wave_b = math.sin(r * 0.17 - angle * 16)
            wave_c = math.sin(r * 0.11 + angle * 24)
            pattern = (wave_a + wave_b + wave_c) / 3.0
            shimmer = int((pattern * 0.5 + 0.5) * 62)

            base = (28 + shimmer // 2, 44 + shimmer, 74 + shimmer)
            color = lerp_color(base, (8, 12, 20), t * 0.6)

            # subtle center glow and outer fumé dial fade
            center_boost = max(0, 1 - r / 70) ** 1.7
            color = tuple(min(255, c + int(center_boost * k)) for c, k in zip(color, (10, 14, 18)))

            img.putpixel((x, y), color)

    return circle_mask(img)


def make_flow_field_silk():
    """Flow-field thread lines with a soft teal-to-violet glow."""
    img = Image.new("RGB", (SIZE, SIZE), (6, 8, 16))
    overlay = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    random.seed(515)

    for _ in range(320):
        x = random.uniform(20, 220)
        y = random.uniform(20, 220)
        hue = random.random()
        color = (18, 120, 132) if hue < 0.5 else (114, 44, 124)
        points = []
        for _ in range(28):
            if not (0 <= x < SIZE and 0 <= y < SIZE):
                break
            points.append((x, y))
            vx = fbm(x / 70, y / 70, octaves=4, seed=71) * 2 - 1
            vy = fbm(x / 70 + 4.1, y / 70 + 2.7, octaves=4, seed=91) * 2 - 1
            angle = math.atan2(vy, vx)
            x += math.cos(angle) * 4.0
            y += math.sin(angle) * 4.0

        if len(points) > 1:
            draw = ImageDraw.Draw(overlay)
            draw.line(points, fill=color, width=1)

    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=1.4))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            bg = img.getpixel((x, y))
            fg = overlay.getpixel((x, y))
            color = tuple(min(255, a + b) for a, b in zip(bg, fg))
            img.putpixel((x, y), color)

    return circle_mask(img)


def make_moire_interference():
    """Wave interference and moire rings for a graphic optical effect."""
    img = Image.new("RGB", (SIZE, SIZE))
    src1 = (84, 96)
    src2 = (156, 144)
    for y in range(SIZE):
        for x in range(SIZE):
            d1 = math.sqrt((x - src1[0]) ** 2 + (y - src1[1]) ** 2)
            d2 = math.sqrt((x - src2[0]) ** 2 + (y - src2[1]) ** 2)
            interference = math.sin(d1 * 0.23) + math.sin(d2 * 0.25)
            band = (interference * 0.5 + 0.5)
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            color = lerp_color((16, 20, 42), (210, 220, 242), band)
            color = lerp_color(color, (24, 10, 38), math.sin((x + y) * 0.035) * 0.15 + 0.15)
            color = lerp_color(color, (0, 0, 0), t * 0.32)
            img.putpixel((x, y), color)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    return circle_mask(img)


def make_low_poly_shards():
    """Low-poly triangular shards using a jittered grid and two-triangle tiles."""
    img = Image.new("RGB", (SIZE, SIZE))
    step = 30
    random.seed(616)
    points = {}
    for gy in range(-1, SIZE // step + 2):
        for gx in range(-1, SIZE // step + 2):
            px = gx * step + random.randint(-8, 8)
            py = gy * step + random.randint(-8, 8)
            points[(gx, gy)] = (px, py)

    base = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(base)
    palette = [(20, 34, 62), (40, 74, 110), (22, 108, 114), (88, 46, 102), (210, 118, 70)]
    for gy in range(-1, SIZE // step + 1):
        for gx in range(-1, SIZE // step + 1):
            p00 = points[(gx, gy)]
            p10 = points[(gx + 1, gy)]
            p01 = points[(gx, gy + 1)]
            p11 = points[(gx + 1, gy + 1)]
            tris = [(p00, p10, p11), (p00, p11, p01)]
            for tri in tris:
                cx = sum(p[0] for p in tri) / 3
                cy = sum(p[1] for p in tri) / 3
                noise = fbm(cx / 90, cy / 90, octaves=4, seed=101)
                color = palette[int(noise * (len(palette) - 1))]
                shade = 0.82 + 0.35 * ((math.sin(cx * 0.05) + math.cos(cy * 0.04)) * 0.5 + 0.5)
                shaded = tuple(min(255, int(c * shade)) for c in color)
                draw.polygon(tri, fill=shaded)

    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            color = base.getpixel((x, y))
            color = lerp_color(color, (6, 8, 12), t * 0.38)
            img.putpixel((x, y), color)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.35))
    return circle_mask(img)


def make_sdf_rings():
    """Signed-distance style concentric cutout rings and clean geometry."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            dx = x - CENTER
            dy = y - CENTER
            r = math.sqrt(dx * dx + dy * dy)
            t = min(r / RADIUS, 1.0)
            base = lerp_color((236, 232, 224), (166, 170, 180), t)

            ring1 = abs(r - 58)
            ring2 = abs(r - 86)
            ring3 = abs(r - 108)
            ring_strength = 0
            for ring in (ring1, ring2, ring3):
                if ring < 4:
                    ring_strength = max(ring_strength, 1 - ring / 4)

            angle = math.atan2(dy, dx)
            wedge = 1.0 if (0.45 < angle < 1.25 and 34 < r < 112) else 0.0
            color = base
            if ring_strength > 0:
                color = lerp_color(color, (42, 52, 78), ring_strength)
            if wedge > 0:
                color = lerp_color(color, (202, 92, 72), wedge)

            color = lerp_color(color, (8, 10, 14), t * 0.24)
            img.putpixel((x, y), color)

    return circle_mask(img)


def make_fume_guilloche_combo():
    """Fume dial with a brighter guilloche center and strong vignette edge."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            dx = x - CENTER
            dy = y - CENTER
            r = math.sqrt(dx * dx + dy * dy)
            angle = math.atan2(dy, dx)
            t = min(r / RADIUS, 1.0)
            wave = math.sin(r * 0.28 + angle * 12) + math.sin(r * 0.16 - angle * 18)
            wave = wave * 0.5 + 0.5
            core = lerp_color((34, 66, 118), (78, 132, 186), max(0, 1 - t / 0.72))
            shimmer = int(wave * 36)
            color = (core[0] + shimmer // 3, core[1] + shimmer // 2, min(255, core[2] + shimmer))
            color = lerp_color(color, (6, 8, 16), t * 0.5)
            img.putpixel((x, y), color)

    return circle_mask(img)


def make_topographic_metal_combo():
    """Topographic lines with metallic tinting and a tiny specular arc highlight."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            dx = x - CENTER
            dy = y - CENTER
            height = (
                math.sin(x * 0.05)
                + math.cos(y * 0.045)
                + math.sin((x + y) * 0.026)
                + math.cos(math.sqrt(dx * dx + dy * dy) * 0.11)
            )
            height = (height + 4) / 8
            metal = lerp_color((82, 92, 108), (24, 28, 36), t)
            line = abs((height * 20) % 1.0 - 0.5)
            if line < 0.07:
                shine = int((1 - line / 0.07) * 62 * (1 - t * 0.45))
                metal = tuple(min(255, a + b) for a, b in zip(metal, (shine // 2, shine // 2, shine)))
            img.putpixel((x, y), metal)

    draw = ImageDraw.Draw(img)
    draw.arc([18, 18, 222, 222], start=24, end=58, fill=(220, 232, 255), width=2)
    img = img.filter(ImageFilter.GaussianBlur(radius=0.5))
    return circle_mask(img)


def make_crt_neon_combo():
    """CRT scanlines, pixel grid structure, and neon block glow."""
    img = Image.new("RGB", (SIZE, SIZE))
    cell = 10
    palette = [(8, 16, 28), (18, 46, 80), (18, 110, 124), (132, 38, 118), (248, 108, 42)]
    for y in range(SIZE):
        for x in range(SIZE):
            gx = x // cell
            gy = y // cell
            base = palette[(gx * 5 + gy * 7 + (gx ^ gy)) % len(palette)]
            fx = (x % cell) / cell
            fy = (y % cell) / cell
            bezel = min(fx, fy, 1 - fx, 1 - fy)
            glow = 0.78 + (1 - bezel) * 0.28
            color = tuple(min(255, int(c * glow)) for c in base)
            if y % 4 == 0:
                color = tuple(int(c * 0.76) for c in color)
            if x % cell == 0 or y % cell == 0:
                color = tuple(int(c * 0.55) for c in color)
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            color = lerp_color(color, (4, 4, 8), t * 0.42)
            img.putpixel((x, y), color)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    return circle_mask(img)


def make_flow_field_ink_parchment_combo():
    """Ink-like flow lines over warm parchment grain."""
    img = Image.new("RGB", (SIZE, SIZE))
    random.seed(707)
    for y in range(SIZE):
        for x in range(SIZE):
            grain = random.randint(-10, 10)
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            paper = max(0, min(255, 220 + grain - int(t * 20)))
            img.putpixel((x, y), (paper, paper - 8, paper - 18))

    overlay = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    random.seed(708)
    for _ in range(260):
        x = random.uniform(20, 220)
        y = random.uniform(20, 220)
        points = []
        for _ in range(24):
            if not (0 <= x < SIZE and 0 <= y < SIZE):
                break
            points.append((x, y))
            vx = fbm(x / 62, y / 62, octaves=4, seed=131) * 2 - 1
            vy = fbm(x / 62 + 3.7, y / 62 + 5.2, octaves=4, seed=149) * 2 - 1
            angle = math.atan2(vy, vx)
            x += math.cos(angle) * 3.5
            y += math.sin(angle) * 3.5
        if len(points) > 1:
            draw.line(points, fill=(34, 28, 22), width=1)

    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=1.0))
    for y in range(SIZE):
        for x in range(SIZE):
            bg = img.getpixel((x, y))
            fg = overlay.getpixel((x, y))[0]
            color = tuple(max(0, c - int(fg * 0.65)) for c in bg)
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            img.putpixel((x, y), color)

    return circle_mask(img)


def make_reaction_diffusion_coral_combo():
    """Small-grid reaction-diffusion style coral pattern in deep ocean colors."""
    small = 64
    a = [[1.0 for _ in range(small)] for _ in range(small)]
    b = [[0.0 for _ in range(small)] for _ in range(small)]
    random.seed(909)
    for _ in range(8):
        cx = random.randint(12, small - 13)
        cy = random.randint(12, small - 13)
        for y in range(cy - 4, cy + 5):
            for x in range(cx - 4, cx + 5):
                if 0 <= x < small and 0 <= y < small:
                    b[y][x] = 1.0
                    a[y][x] = 0.0

    da = 1.0
    db = 0.5
    feed = 0.054
    kill = 0.062
    for _ in range(34):
        new_a = [[a[y][x] for x in range(small)] for y in range(small)]
        new_b = [[b[y][x] for x in range(small)] for y in range(small)]
        for y in range(1, small - 1):
            for x in range(1, small - 1):
                lap_a = (
                    a[y][x - 1] + a[y][x + 1] + a[y - 1][x] + a[y + 1][x]
                    - 4 * a[y][x]
                )
                lap_b = (
                    b[y][x - 1] + b[y][x + 1] + b[y - 1][x] + b[y + 1][x]
                    - 4 * b[y][x]
                )
                reaction = a[y][x] * b[y][x] * b[y][x]
                new_a[y][x] = max(0.0, min(1.0, a[y][x] + (da * lap_a - reaction + feed * (1 - a[y][x])) * 0.5))
                new_b[y][x] = max(0.0, min(1.0, b[y][x] + (db * lap_b + reaction - (kill + feed) * b[y][x]) * 0.5))
        a = new_a
        b = new_b

    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            sx = min(small - 1, int(x / SIZE * small))
            sy = min(small - 1, int(y / SIZE * small))
            v = b[sy][sx]
            t = radial_gradient(CENTER, CENTER, x, y, RADIUS)
            base = lerp_color((8, 20, 34), (4, 8, 18), t)
            coral = lerp_color((18, 118, 132), (244, 126, 86), v)
            color = tuple(min(255, int(a0 * (1 - v * 0.75) + c0 * (v * 0.92))) for a0, c0 in zip(base, coral))
            img.putpixel((x, y), color)

    img = img.filter(ImageFilter.GaussianBlur(radius=1.1))
    return circle_mask(img)


# Generate
background_groups = [
    (
        "Round-Display Combos",
        [
            ("Fume Guilloche", make_fume_guilloche_combo),
            ("Topo Metal Arc", make_topographic_metal_combo),
            ("CRT Neon Grid", make_crt_neon_combo),
            ("Flow Ink Parchment", make_flow_field_ink_parchment_combo),
            ("Reaction Coral", make_reaction_diffusion_coral_combo),
        ],
    ),
    (
        "Gradient And Atmosphere",
        [
            ("Deep Space", make_deep_space),
            ("Ocean", make_ocean_gradient),
            ("Ember", make_ember_glow),
            ("Aurora", make_aurora_green),
            ("Vortex", make_purple_vortex),
            ("Midnight Frost", make_midnight_frost),
            ("Solar Flare", make_solar_flare),
            ("Starfield", make_starfield),
            ("Lava Flow", make_lava_flow),
            ("Forest Canopy", make_forest_canopy),
        ],
    ),
    (
        "Structured Patterns",
        [
            ("Matrix Rain", make_matrix_rain),
            ("Copper Mesh", make_copper_mesh),
            ("Topographic", make_topographic_lines),
            ("Brushed Titanium", make_brushed_titanium),
            ("Pixel Neon", make_pixel_neon),
            ("Retro Sunburst", make_retro_sunburst),
            ("SDF Rings", make_sdf_rings),
        ],
    ),
    (
        "Material And Editorial",
        [
            ("Ink Wash", make_ink_wash),
            ("Paper Cut", make_paper_cut),
            ("Halftone Poster", make_halftone_poster),
            ("Warp Marble", make_domain_warp_marble),
            ("Guilloche Dial", make_guilloche_dial),
        ],
    ),
    (
        "Cellular And Faceted",
        [
            ("Mosaic Gem", make_mosaic_gem),
            ("Voronoi Glass", make_voronoi_stained_glass),
            ("Low Poly Shards", make_low_poly_shards),
        ],
    ),
    (
        "Experimental Field Methods",
        [
            ("Flow Field Silk", make_flow_field_silk),
            ("Moire Interference", make_moire_interference),
        ],
    ),
]

parser = argparse.ArgumentParser(description="Generate watchface backgrounds")
parser.add_argument("--output-dir", default="/tmp",
                    help="Directory to save .png and .bin files (default: /tmp)")
parser.add_argument("--deploy", action="store_true",
                    help="Copy .bin and .png to Flutter app assets and firmware S/ directory")
parser.add_argument("--name", default=None,
                    help="Only generate the background whose slug matches (e.g. 'deep_space')")
args = parser.parse_args()

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
FLUTTER_BG_DIR = os.path.join(REPO_ROOT, "zswatch_app", "assets", "backgrounds")

os.makedirs(args.output_dir, exist_ok=True)

generated_groups = []
for group_name, entries in background_groups:
    generated_entries = []
    for name, generator in entries:
        slug = name.lower().replace(' ', '_')
        if args.name and args.name != slug:
            continue
        generated_entries.append((name, generator()))
    if generated_entries:
        generated_groups.append((group_name, generated_entries))

# Save PNGs and LVGL binaries
for _, entries in generated_groups:
    for name, img in entries:
        slug = name.lower().replace(' ', '_')
        png_path = os.path.join(args.output_dir, f"bg_{slug}.png")
        bin_path = os.path.join(args.output_dir, f"bg_{slug}.bin")
        img.save(png_path)
        save_lvgl_bin(img, bin_path)
        print(f"Saved {png_path} ({os.path.getsize(png_path)} bytes)")
        print(f"Saved {bin_path} ({os.path.getsize(bin_path)} bytes)")

if args.deploy:
    print("\n--- Deploying ---")
    if os.path.isdir(FLUTTER_BG_DIR):
        for _, entries in generated_groups:
            for name, img in entries:
                slug = name.lower().replace(' ', '_')
                src_png = os.path.join(args.output_dir, f"bg_{slug}.png")
                src_bin = os.path.join(args.output_dir, f"bg_{slug}.bin")
                shutil.copy2(src_png, FLUTTER_BG_DIR)
                shutil.copy2(src_bin, FLUTTER_BG_DIR)
        print(f"Copied backgrounds to {FLUTTER_BG_DIR}")
    else:
        print(f"WARNING: Flutter backgrounds dir not found: {FLUTTER_BG_DIR}")


# Build HTML demo
html = """<!DOCTYPE html>
<html><head><style>
body { background: #111; color: #fff; font-family: sans-serif; margin: 0; padding: 24px; }
.intro { max-width: 1100px; margin: 0 auto 24px; }
.intro h1 { margin: 0 0 8px; font-size: 24px; }
.intro p { margin: 0; color: #bbb; }
.group { max-width: 1200px; margin: 0 auto 34px; }
.group h2 { margin: 0 0 16px; font-size: 18px; color: #f2f2f2; border-bottom: 1px solid #2d2d2d; padding-bottom: 8px; }
.grid { display: flex; flex-wrap: wrap; justify-content: center; gap: 30px; }
.card { text-align: center; }
.card h3 { margin: 10px 0; }
.watch { position: relative; width: 240px; height: 240px; border-radius: 50%; overflow: hidden; }
.watch img.bg { width: 240px; height: 240px; position: absolute; top: 0; left: 0; }
.overlay { position: absolute; top: 0; left: 0; width: 240px; height: 240px; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.date { color: #999; font-size: 11px; margin-top: -50px; letter-spacing: 1px; }
.weather { color: #ddd; font-size: 11px; margin-top: 4px; }
.weather .hum { color: #60AEF7; }
.time { display: flex; align-items: baseline; margin-top: 8px; }
.hour { color: #fff; font-size: 52px; font-weight: 900; font-family: 'Courier New', monospace; }
.colon { color: #FF8600; font-size: 52px; font-weight: 900; font-family: 'Courier New', monospace; }
.min { color: #FF8600; font-size: 52px; font-weight: 900; font-family: 'Courier New', monospace; }
.stats { display: flex; gap: 8px; align-items: center; margin-top: 12px; font-size: 10px; color: #aaa; }
.steps { color: #b97cf5; }
.music { color: #4CAF50; font-size: 9px; margin-top: 6px; }
.arc { position: absolute; top: 0; left: 0; width: 240px; height: 240px; border-radius: 50%; border: 4px solid #9D3BE0; border-right-color: #1a1a2a; border-bottom-color: #1a1a2a; box-sizing: border-box; }
</style></head><body>
<div class="intro">
    <h1>Watchface Background Generator</h1>
    <p>Grouped by procedural family so it is easier to compare generation methods, palettes, and texture strategies.</p>
</div>
"""

for group_name, entries in generated_groups:
        html += f"""
<section class="group">
    <h2>{group_name}</h2>
    <div class="grid">
"""
        for name, img in entries:
                buf = io.BytesIO()
                img.save(buf, format="PNG")
                b64 = base64.b64encode(buf.getvalue()).decode()

                html += f"""
<div class="card">
  <div class="watch">
    <img class="bg" src="data:image/png;base64,{b64}">
    <div class="arc"></div>
    <div class="overlay">
      <div class="date">SUN | 5 APR</div>
      <div class="weather">☀ 18° <span class="hum">💧62%</span></div>
      <div class="time"><span class="hour">16</span><span class="colon">:</span><span class="min">14</span></div>
      <div class="stats"><span class="steps">🏃 6543</span> | <span>💬3</span> | <span>🔋93%</span> <span style="color:#0082FC">●</span></div>
      <div class="music">🎵 Bohemian Rhapsody - Queen</div>
    </div>
  </div>
  <h3>{name}</h3>
</div>
"""
        html += """
    </div>
</section>
"""

html += "</body></html>"

html_path = os.path.join(args.output_dir, "watchface_backgrounds.html")
with open(html_path, "w") as f:
    f.write(html)
print(f"HTML saved to {html_path}")
