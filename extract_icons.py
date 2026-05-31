import sys
from PIL import Image

def extract_icons(image_path):
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    
    pixels = img.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            lum = int(0.299 * r + 0.587 * g + 0.114 * b)
            
            # The background is very dark gray (e.g., #111111), and text/icons are white.
            # Map luminance to alpha.
            if lum < 50:
                alpha = 0
            else:
                alpha = max(0, min(255, int((lum - 50) * 255 / (200 - 50))))
            
            pixels[x, y] = (255, 255, 255, alpha)
            
    names = ["chest", "arms", "shoulders", "back", "abs", "cardio"]
    part_width = width // 6
    
    for i, name in enumerate(names):
        box = (i * part_width, 0, (i + 1) * part_width, height)
        part = img.crop(box)
        
        # Crop tight
        bbox = part.getbbox()
        if bbox:
            part = part.crop(bbox)
            
        part.save(f"icon_{name}.png")

if __name__ == "__main__":
    extract_icons(sys.argv[1])
