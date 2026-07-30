import os
import sys
from PIL import Image

MAX_SIZE = (360, 360)

def convert_gif_to_webp(input_path, output_path):
    try:
        with Image.open(input_path) as im:
            frames = []
            durations = []
            
            try:
                while True:
                    # Create a new image to paste the current frame into (handles transparency)
                    new_frame = Image.new("RGBA", im.size)
                    new_frame.paste(im, (0,0), im.convert("RGBA"))
                    
                    # Resize while maintaining aspect ratio
                    new_frame.thumbnail(MAX_SIZE, Image.Resampling.LANCZOS)
                    
                    frames.append(new_frame)
                    
                    # Handle duration
                    durations.append(im.info.get('duration', 100))
                    
                    im.seek(im.tell() + 1)
            except EOFError:
                pass
            
            if frames:
                # Save as animated WEBP
                frames[0].save(
                    output_path,
                    format='WEBP',
                    save_all=True,
                    append_images=frames[1:],
                    duration=durations,
                    loop=0,
                    quality=80,
                    method=4
                )
                
                in_size = os.path.getsize(input_path) / 1024
                out_size = os.path.getsize(output_path) / 1024
                print(f"Converted {os.path.basename(input_path)}: {in_size:.1f}KB -> {out_size:.1f}KB")
                return True
    except Exception as e:
        print(f"Error converting {input_path}: {e}")
        return False

def main():
    if len(sys.argv) < 3:
        print("Usage: python convert_media.py <input_dir> <output_dir>")
        sys.exit(1)
        
    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    
    os.makedirs(output_dir, exist_ok=True)
    
    count = 0
    for filename in os.listdir(input_dir):
        if filename.lower().endswith('.gif'):
            in_path = os.path.join(input_dir, filename)
            out_name = os.path.splitext(filename)[0] + '.webp'
            out_path = os.path.join(output_dir, out_name)
            
            if convert_gif_to_webp(in_path, out_path):
                count += 1
                
    print(f"\nDone. Successfully converted {count} files.")

if __name__ == '__main__':
    main()
