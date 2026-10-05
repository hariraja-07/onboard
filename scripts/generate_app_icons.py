#!/usr/bin/env python3
"""
Generates the project application icon for the Onboard project across all platforms.
Visual theme: Modern college transit coach + attendance checkmark badge + barcode motif.
Primary palette: #175CD3 (Brand Blue), #1B7F4B (Success Green), #FFFFFF.
"""

import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_master_icon(size=2048) -> Image.Image:
    # 2048x2048 canvas for 2x supersampling down to 1024x1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Background Gradient (Deep brand blue to rich indigo)
    c_top = (28, 104, 230)
    c_bot = (10, 42, 102)
    for y in range(size):
        t = y / size
        r = int(c_top[0] * (1 - t) + c_bot[0] * t)
        g = int(c_top[1] * (1 - t) + c_bot[1] * t)
        b = int(c_top[2] * (1 - t) + c_bot[2] * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # 1b. Subtle background ambient rings radiating from center
    center = (size // 2, int(size * 0.48))
    for radius in [680, 840, 1000, 1160]:
        box = [center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius]
        draw.ellipse(box, outline=(255, 255, 255, 14), width=7)

    # 2. Drop shadow under the bus
    shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_layer)
    s_draw.rounded_rectangle([510, 1400, 1538, 1540], radius=65, fill=(0, 12, 35, 130))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(32))
    img.alpha_composite(shadow_layer)
    draw = ImageDraw.Draw(img)

    # 3. Wheels / Tires (placed within safe zone)
    wheel_color = (20, 24, 32, 255)
    rim_color = (68, 78, 92, 255)
    # Left wheel
    draw.rounded_rectangle([570, 1360, 720, 1490], radius=32, fill=wheel_color)
    draw.rounded_rectangle([600, 1385, 690, 1465], radius=18, fill=rim_color)
    # Right wheel
    draw.rounded_rectangle([1328, 1360, 1478, 1490], radius=32, fill=wheel_color)
    draw.rounded_rectangle([1358, 1385, 1448, 1465], radius=18, fill=rim_color)

    # 4. Side Mirrors (tucked closer to fit circular/squircle mask)
    mirror_color = (242, 246, 252, 255)
    mirror_glass = (18, 35, 60, 255)
    # Left arm & mirror
    draw.line([(550, 790), (475, 765)], fill=(195, 208, 225, 255), width=22)
    draw.rounded_rectangle([448, 715, 502, 885], radius=22, fill=mirror_color)
    draw.rounded_rectangle([460, 730, 492, 870], radius=14, fill=mirror_glass)
    # Right arm & mirror
    draw.line([(1498, 790), (1573, 765)], fill=(195, 208, 225, 255), width=22)
    draw.rounded_rectangle([1546, 715, 1600, 885], radius=22, fill=mirror_color)
    draw.rounded_rectangle([1556, 730, 1588, 870], radius=14, fill=mirror_glass)

    # 5. Bus Main Body Shell
    body_box = [530, 420, 1518, 1420]
    draw.rounded_rectangle(body_box, radius=155, fill=(255, 255, 255, 255))

    # Top Roof Cap / Aerodynamic Accent
    draw.rounded_rectangle([570, 435, 1478, 482], radius=24, fill=(225, 233, 245, 255))

    # 6. Destination Route Display (LED Matrix Screen)
    dest_box = [670, 490, 1378, 590]
    draw.rounded_rectangle(dest_box, radius=30, fill=(12, 20, 34, 255))
    
    # Render "ONBOARD" text in LED amber/mint
    font_path = "/usr/share/fonts/google-noto/NotoSans-Bold.ttf"
    try:
        font = ImageFont.truetype(font_path, 52)
        # Amber side dots
        draw.rounded_rectangle([700, 520, 735, 560], radius=10, fill=(245, 196, 107, 255))
        draw.rounded_rectangle([1313, 520, 1348, 560], radius=10, fill=(245, 196, 107, 255))
        # Text centered
        text = "ONBOARD"
        bbox = draw.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (dest_box[0] + dest_box[1]) // 2 + (dest_box[2] - dest_box[0] - tw) // 2
        # Text in bright mint LED
        draw.text(((2048 - tw) // 2, dest_box[1] + (100 - th) // 2 - 4), text, font=font, fill=(111, 225, 165, 255))
    except Exception:
        # Fallback LED pill
        draw.rounded_rectangle([780, 526, 1268, 554], radius=14, fill=(111, 225, 165, 255))

    # 7. Panoramic Windshield
    windshield_box = [575, 615, 1473, 1010]
    draw.rounded_rectangle(windshield_box, radius=68, fill=(16, 32, 58, 255))

    # Windshield glass reflection gleam
    gleam_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(gleam_layer)
    g_draw.polygon([(680, 615), (860, 615), (740, 1010), (575, 1010), (575, 800)], fill=(255, 255, 255, 36))
    g_draw.polygon([(920, 615), (990, 615), (870, 1010), (800, 1010)], fill=(255, 255, 255, 20))
    img.alpha_composite(gleam_layer)
    draw = ImageDraw.Draw(img)

    # Rearview Mirror inside windshield
    draw.rounded_rectangle([974, 630, 1074, 672], radius=14, fill=(35, 45, 60, 255))
    draw.line([(1024, 615), (1024, 630)], fill=(70, 80, 95, 255), width=8)

    # 8. Grille & Attendance Barcode Scanner Section
    draw.line([(550, 1040), (1498, 1040)], fill=(215, 224, 236, 255), width=10)

    # Headlights
    # Left Headlight
    draw.rounded_rectangle([570, 1070, 715, 1150], radius=28, fill=(255, 250, 225, 255), outline=(210, 218, 230, 255), width=8)
    draw.rounded_rectangle([600, 1090, 685, 1130], radius=16, fill=(245, 196, 107, 255))
    # Right Headlight
    draw.rounded_rectangle([1333, 1070, 1478, 1150], radius=28, fill=(255, 250, 225, 255), outline=(210, 218, 230, 255), width=8)
    draw.rounded_rectangle([1363, 1090, 1448, 1130], radius=16, fill=(245, 196, 107, 255))

    # Center Grille: Attendance Barcode Slats
    barcode_x_start = 785
    barcode_widths = [14, 26, 14, 38, 14, 20, 38, 14, 28, 14, 22, 34, 14, 26]
    spacing = 16
    curr_x = barcode_x_start
    for bw in barcode_widths:
        if curr_x + bw > 1265:
            break
        draw.rounded_rectangle([curr_x, 1070, curr_x + bw, 1150], radius=7, fill=(23, 92, 211, 255))
        curr_x += bw + spacing

    # 9. Bumper & License / Plate Section
    bumper_box = [550, 1195, 1498, 1360]
    draw.rounded_rectangle(bumper_box, radius=62, fill=(236, 241, 249, 255), outline=(206, 216, 229, 255), width=8)

    # Fog Lights
    draw.rounded_rectangle([590, 1252, 675, 1305], radius=22, fill=(245, 196, 107, 220))
    draw.rounded_rectangle([1373, 1252, 1458, 1305], radius=22, fill=(245, 196, 107, 220))

    # Transit Plate "BUS 01" / Attendance
    plate_box = [860, 1235, 1188, 1325]
    draw.rounded_rectangle(plate_box, radius=22, fill=(23, 92, 211, 255), outline=(255, 255, 255, 255), width=6)
    try:
        plate_font = ImageFont.truetype(font_path, 42)
        plate_text = "BUS 01"
        pb = draw.textbbox((0, 0), plate_text, font=plate_font)
        ptw = pb[2] - pb[0]
        pth = pb[3] - pb[1]
        draw.text(((2048 - ptw) // 2, plate_box[1] + (90 - pth) // 2 - 4), plate_text, font=plate_font, fill=(255, 255, 255, 255))
    except Exception:
        draw.rounded_rectangle([890, 1270, 1158, 1292], radius=10, fill=(255, 255, 255, 255))

    # 10. Attendance Verification Checkmark Badge
    # Placed in the safe zone at bottom-right of the bus
    bx, by = 1380, 1360
    badge_radius = 230

    # Badge Shadow
    b_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bs_draw = ImageDraw.Draw(b_shadow)
    bs_draw.ellipse([bx - badge_radius - 15, by - badge_radius + 15, bx + badge_radius + 15, by + badge_radius + 50], fill=(0, 15, 40, 140))
    b_shadow = b_shadow.filter(ImageFilter.GaussianBlur(30))
    img.alpha_composite(b_shadow)
    draw = ImageDraw.Draw(img)

    # Outer crisp white ring
    draw.ellipse([bx - badge_radius, by - badge_radius, bx + badge_radius, by + badge_radius], fill=(255, 255, 255, 255))

    # Inner Vibrant Green Badge (#1B7F4B)
    inner_r = badge_radius - 24
    badge_surface = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bsurf_draw = ImageDraw.Draw(badge_surface)
    bsurf_draw.ellipse([bx - inner_r, by - inner_r, bx + inner_r, by + inner_r], fill=(27, 127, 75, 255))
    # Top subtle highlight on badge
    bsurf_draw.ellipse([bx - inner_r + 18, by - inner_r + 8, bx + inner_r - 18, by], fill=(52, 184, 115, 160))
    img.alpha_composite(badge_surface)
    draw = ImageDraw.Draw(img)

    # Crisp Bold White Checkmark in Badge
    chk_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    chk_draw = ImageDraw.Draw(chk_layer)
    chk_w = 42
    p1 = (bx - 78, by - 2)
    p2 = (bx - 16, by + 64)
    p3 = (bx + 82, by - 56)
    
    chk_draw.line([p1, p2], fill=(255, 255, 255, 255), width=chk_w)
    chk_draw.line([p2, p3], fill=(255, 255, 255, 255), width=chk_w)
    chk_draw.ellipse([p1[0] - chk_w // 2, p1[1] - chk_w // 2, p1[0] + chk_w // 2, p1[1] + chk_w // 2], fill=(255, 255, 255, 255))
    chk_draw.ellipse([p2[0] - chk_w // 2, p2[1] - chk_w // 2, p2[0] + chk_w // 2, p2[1] + chk_w // 2], fill=(255, 255, 255, 255))
    chk_draw.ellipse([p3[0] - chk_w // 2, p3[1] - chk_w // 2, p3[0] + chk_w // 2, p3[1] + chk_w // 2], fill=(255, 255, 255, 255))
    img.alpha_composite(chk_layer)

    # Downsample from 2048x2048 to 1024x1024 with Lanczos
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

def export_all_icons(master_1024: Image.Image, root_dir: str):
    """Resizes and exports master icon to all platform paths."""
    # Convert an RGB version for platforms requiring opaque images (iOS App Store, etc.)
    master_rgb = master_1024.convert("RGB")

    # 1. assets/icon/app_icon.png
    assets_path = os.path.join(root_dir, "assets", "icon", "app_icon.png")
    os.makedirs(os.path.dirname(assets_path), exist_ok=True)
    master_1024.save(assets_path, "PNG")
    print(f"Saved: {assets_path}")

    # 2. Android Mipmaps
    android_res = os.path.join(root_dir, "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in android_sizes.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)
        out_file = os.path.join(folder_path, "ic_launcher.png")
        resized = master_1024.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_file, "PNG")
        print(f"Saved: {out_file} ({px}x{px})")

    # 3. iOS AppIcon.appiconset
    ios_iconset = os.path.join(root_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_iconset):
        ios_files = {
            "Icon-App-20x20@1x.png": (20, 20),
            "Icon-App-20x20@2x.png": (40, 40),
            "Icon-App-20x20@3x.png": (60, 60),
            "Icon-App-29x29@1x.png": (29, 29),
            "Icon-App-29x29@2x.png": (58, 58),
            "Icon-App-29x29@3x.png": (87, 87),
            "Icon-App-40x40@1x.png": (40, 40),
            "Icon-App-40x40@2x.png": (80, 80),
            "Icon-App-40x40@3x.png": (120, 120),
            "Icon-App-60x60@2x.png": (120, 120),
            "Icon-App-60x60@3x.png": (180, 180),
            "Icon-App-76x76@1x.png": (76, 76),
            "Icon-App-76x76@2x.png": (152, 152),
            "Icon-App-83.5x83.5@2x.png": (167, 167),
            "Icon-App-1024x1024@1x.png": (1024, 1024),
        }
        for filename, (w, h) in ios_files.items():
            out_file = os.path.join(ios_iconset, filename)
            # iOS App Store / marketing icon must be RGB without alpha
            if filename == "Icon-App-1024x1024@1x.png":
                resized = master_rgb.resize((w, h), Image.Resampling.LANCZOS)
            else:
                resized = master_1024.resize((w, h), Image.Resampling.LANCZOS)
            resized.save(out_file, "PNG")
            print(f"Saved iOS: {out_file} ({w}x{h})")

    # 4. Web Icons & Favicon
    web_dir = os.path.join(root_dir, "web")
    if os.path.exists(web_dir):
        # favicon
        fav_path = os.path.join(web_dir, "favicon.png")
        fav = master_1024.resize((32, 32), Image.Resampling.LANCZOS)
        fav.save(fav_path, "PNG")
        print(f"Saved Web favicon: {fav_path} (32x32)")

        web_icons_dir = os.path.join(web_dir, "icons")
        os.makedirs(web_icons_dir, exist_ok=True)
        web_sizes = {
            "Icon-192.png": 192,
            "Icon-512.png": 512,
            "Icon-maskable-192.png": 192,
            "Icon-maskable-512.png": 512,
        }
        for fname, px in web_sizes.items():
            out_file = os.path.join(web_icons_dir, fname)
            resized = master_rgb.resize((px, px), Image.Resampling.LANCZOS)
            resized.save(out_file, "PNG")
            print(f"Saved Web: {out_file} ({px}x{px})")

    # 5. macOS AppIcon.appiconset
    macos_iconset = os.path.join(root_dir, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(macos_iconset):
        macos_sizes = {
            "app_icon_16.png": 16,
            "app_icon_32.png": 32,
            "app_icon_64.png": 64,
            "app_icon_128.png": 128,
            "app_icon_256.png": 256,
            "app_icon_512.png": 512,
            "app_icon_1024.png": 1024,
        }
        for fname, px in macos_sizes.items():
            out_file = os.path.join(macos_iconset, fname)
            resized = master_1024.resize((px, px), Image.Resampling.LANCZOS)
            resized.save(out_file, "PNG")
            print(f"Saved macOS: {out_file} ({px}x{px})")

    # 6. Windows app_icon.ico
    win_res = os.path.join(root_dir, "windows", "runner", "resources")
    if os.path.exists(win_res):
        ico_file = os.path.join(win_res, "app_icon.ico")
        master_1024.save(
            ico_file,
            format="ICO",
            sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        )
        print(f"Saved Windows ICO: {ico_file}")

if __name__ == "__main__":
    proj_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    print(f"Generating Onboard app icons for project at: {proj_root}")
    master = create_master_icon(2048)
    export_all_icons(master, proj_root)
    print("Done generating all app icons!")
