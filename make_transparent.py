import sys
from PIL import Image

def make_transparent(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()
    new_data = []
    
    for item in data:
        # Get pixel luminance
        r, g, b, a = item
        lum = (r + g + b) / 3
        # If the pixel is very dark, make it transparent
        # We also feather the alpha based on brightness
        alpha = min(255, int(max(0, lum - 15) * 2))
        if lum < 15:
            new_data.append((r, g, b, 0))
        else:
            new_data.append((r, g, b, alpha))
            
    img.putdata(new_data)
    img.save(output_path, "PNG")

make_transparent('/Users/p016324/.gemini/antigravity/brain/62667cb7-cd53-4318-9577-2cb7099208cd/vigr_logo_v_motion_notext_1780959705385.png', 'Resources/Assets.xcassets/VigrLogoTransparent.imageset/VigrLogoTransparent.png')
