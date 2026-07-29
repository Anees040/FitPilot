import os
from PIL import Image

def generate_icons(logo_path):
    # iOS sizes
    ios_sizes = [
        ("Icon-App-20x20@1x.png", 20),
        ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@1x.png", 29),
        ("Icon-App-29x29@2x.png", 58),
        ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40),
        ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@1x.png", 76),
        ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167),
        ("Icon-App-1024x1024@1x.png", 1024),
    ]

    # Android legacy sizes
    android_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }

    try:
        img = Image.open(logo_path).convert("RGBA")
    except Exception as e:
        print("Could not open logo:", e)
        return

    # Android
    for density, size in android_sizes.items():
        out_dir = f"android/app/src/main/res/mipmap-{density}"
        os.makedirs(out_dir, exist_ok=True)
        # legacy
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(out_dir, "ic_launcher.png"))
        
        # adaptive foreground needs to be 108x108 where the icon is centered in a safe zone of 72x72.
        # So we create a 108x108 transparent image, resize the logo to 72x72, and paste it in the center.
        fg_size = int(size * (108 / 48))
        safe_size = int(size * (72 / 48))
        
        fg = Image.new("RGBA", (fg_size, fg_size), (0,0,0,0))
        logo_resized = img.resize((safe_size, safe_size), Image.Resampling.LANCZOS)
        offset = (fg_size - safe_size) // 2
        fg.paste(logo_resized, (offset, offset), logo_resized)
        
        fg.save(os.path.join(out_dir, "ic_launcher_foreground.png"))

    # Android background xml
    bg_dir = "android/app/src/main/res/values"
    os.makedirs(bg_dir, exist_ok=True)
    with open(os.path.join(bg_dir, "ic_launcher_background.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FAFAF8</color>\n</resources>')
    
    # Adaptive icon xml
    anydpi_dir = "android/app/src/main/res/mipmap-anydpi-v26"
    os.makedirs(anydpi_dir, exist_ok=True)
    xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>'''
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w") as f:
        f.write(xml)

    # iOS
    ios_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(ios_dir, exist_ok=True)
    for name, size in ios_sizes:
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        # iOS icons cannot have alpha channel. We compose over white/background.
        bg = Image.new("RGB", (size, size), (250, 250, 248))
        bg.paste(resized, (0, 0), resized)
        bg.save(os.path.join(ios_dir, name))
        
    print("Icons generated.")

if __name__ == "__main__":
    generate_icons("assets/images/logo.png")
