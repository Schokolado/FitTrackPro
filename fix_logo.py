import sys
from PIL import Image

def process_image(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    
    # 1. Crop the center to remove the glass box edges
    # Image is 1024x1024. Let's keep the center 600x600
    left = 212
    top = 212
    right = 812
    bottom = 812
    img = img.crop((left, top, right, bottom))
    
    # 2. Make dark background transparent
    data = img.getdata()
    new_data = []
    
    for item in data:
        r, g, b, a = item
        # Since the logo is cyan/pink, the background is very dark blue/grey
        lum = (r + g + b) / 3
        
        # Increase threshold to remove any remaining background glow
        if lum < 30:
            new_data.append((r, g, b, 0))
        else:
            # Alpha feathering for smooth edges
            alpha = min(255, int(max(0, lum - 30) * 3))
            new_data.append((r, g, b, alpha))
            
    img.putdata(new_data)
    img.save(output_path, "PNG")

process_image('/Users/p016324/.gemini/antigravity/brain/62667cb7-cd53-4318-9577-2cb7099208cd/vigr_logo_v_motion_notext_1780959705385.png', 'Resources/Assets.xcassets/VigrLogoTransparent.imageset/VigrLogoTransparent.png')
print("Done")
