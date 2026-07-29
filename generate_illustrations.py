import os
from PIL import Image, ImageDraw, ImageFont

def create_illustration(filename, draw_func):
    img = Image.new('RGBA', (300, 300), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    draw_func(draw)
    img.save(f"assets/illustrations/{filename}")

def draw_range_slider(draw):
    # Minimalist line art for range slider
    draw.line([(50, 150), (250, 150)], fill="#1A1A1A", width=4)
    # Accent segment
    draw.line([(100, 150), (200, 150)], fill="#D9531E", width=4)
    # Handles
    draw.ellipse([(90, 140), (110, 160)], outline="#1A1A1A", width=4, fill=(255, 255, 255, 0))
    draw.ellipse([(190, 140), (210, 160)], outline="#1A1A1A", width=4, fill=(255, 255, 255, 0))
    # Little values
    draw.line([(100, 120), (100, 130)], fill="#1A1A1A", width=2)
    draw.line([(200, 120), (200, 130)], fill="#1A1A1A", width=2)

def draw_walker_rope(draw):
    # Walker
    draw.ellipse([(70, 70), (110, 110)], outline="#1A1A1A", width=4)
    draw.line([(90, 110), (90, 180)], fill="#1A1A1A", width=4)
    draw.line([(90, 130), (60, 160)], fill="#1A1A1A", width=4)
    draw.line([(90, 130), (120, 160)], fill="#1A1A1A", width=4)
    draw.line([(90, 180), (70, 240)], fill="#1A1A1A", width=4)
    draw.line([(90, 180), (110, 240)], fill="#1A1A1A", width=4)
    
    # Jump roper (with accent rope)
    draw.ellipse([(190, 70), (230, 110)], outline="#1A1A1A", width=4)
    draw.line([(210, 110), (210, 180)], fill="#1A1A1A", width=4)
    draw.line([(210, 130), (180, 160)], fill="#1A1A1A", width=4)
    draw.line([(210, 130), (240, 160)], fill="#1A1A1A", width=4)
    draw.line([(210, 180), (190, 220)], fill="#1A1A1A", width=4)
    draw.line([(210, 180), (230, 220)], fill="#1A1A1A", width=4)
    # Rope arc in accent
    draw.arc([(150, 40), (270, 260)], start=0, end=180, fill="#D9531E", width=3)

def draw_phone_check(draw):
    draw.rounded_rectangle([(80, 40), (220, 260)], radius=20, outline="#1A1A1A", width=4)
    draw.line([(80, 220), (220, 220)], fill="#1A1A1A", width=4)
    # Check mark
    draw.line([(120, 150), (140, 170), (180, 120)], fill="#D9531E", width=6)

def draw_empty_plate(draw):
    draw.ellipse([(60, 100), (240, 200)], outline="#1A1A1A", width=4)
    draw.ellipse([(90, 120), (210, 180)], outline="#1A1A1A", width=2)
    # Fork and knife
    draw.line([(40, 100), (40, 200)], fill="#D9531E", width=4)
    draw.line([(260, 100), (260, 200)], fill="#D9531E", width=4)

def draw_empty_plan(draw):
    # Resting figure
    draw.ellipse([(130, 100), (170, 140)], outline="#1A1A1A", width=4)
    draw.line([(150, 140), (150, 200)], fill="#1A1A1A", width=4)
    draw.line([(150, 160), (120, 140)], fill="#1A1A1A", width=4)
    draw.line([(150, 160), (180, 140)], fill="#1A1A1A", width=4)
    # Legs resting on a small box
    draw.line([(150, 200), (220, 200)], fill="#D9531E", width=4)
    draw.rectangle([(220, 180), (260, 220)], outline="#1A1A1A", width=4)

def draw_empty_search(draw):
    # Magnifying glass
    draw.ellipse([(100, 80), (180, 160)], outline="#1A1A1A", width=4)
    draw.line([(170, 150), (220, 200)], fill="#1A1A1A", width=6)
    # Question mark inside
    draw.text((125, 90), "?", fill="#D9531E", align="center")
    # Draw simple ? path if font is tricky
    draw.arc([(130, 100), (150, 120)], start=180, end=360, fill="#D9531E", width=4)
    draw.line([(150, 110), (150, 130), (140, 130), (140, 140)], fill="#D9531E", width=4)
    draw.ellipse([(138, 145), (142, 149)], fill="#D9531E")

def draw_empty_history(draw):
    # Calendar icon
    draw.rounded_rectangle([(80, 60), (220, 240)], radius=12, outline="#1A1A1A", width=4)
    draw.line([(80, 100), (220, 100)], fill="#1A1A1A", width=4)
    draw.line([(110, 40), (110, 80)], fill="#D9531E", width=6)
    draw.line([(190, 40), (190, 80)], fill="#D9531E", width=6)
    # Ghost inside
    draw.arc([(120, 130), (180, 190)], start=180, end=0, fill="#1A1A1A", width=3)
    draw.line([(120, 160), (120, 200)], fill="#1A1A1A", width=3)
    draw.line([(180, 160), (180, 200)], fill="#1A1A1A", width=3)
    draw.line([(120, 200), (140, 190), (160, 200), (180, 190)], fill="#1A1A1A", width=3)

def draw_empty_chart(draw):
    # Chart with flat line
    draw.line([(50, 250), (250, 250)], fill="#1A1A1A", width=4) # X axis
    draw.line([(50, 50), (50, 250)], fill="#1A1A1A", width=4) # Y axis
    # Dashed line
    for x in range(60, 250, 20):
        draw.line([(x, 150), (x+10, 150)], fill="#D9531E", width=3)

def main():
    os.makedirs("assets/illustrations", exist_ok=True)
    os.makedirs("assets/images", exist_ok=True)
    
    illustrations = [
        ("range_slider.png", draw_range_slider),
        ("walker_rope.png", draw_walker_rope),
        ("phone_check.png", draw_phone_check),
        ("empty_plate.png", draw_empty_plate),
        ("empty_plan.png", draw_empty_plan),
        ("empty_search.png", draw_empty_search),
        ("empty_history.png", draw_empty_history),
        ("empty_chart.png", draw_empty_chart),
    ]
    
    for filename, func in illustrations:
        create_illustration(filename, func)
        print(f"Created {filename}")

if __name__ == "__main__":
    main()
