import sys
from PIL import Image

# Read original
img = Image.open('/Users/p016324/.gemini/antigravity/brain/62667cb7-cd53-4318-9577-2cb7099208cd/vigr_logo_v_motion_notext_1780959705385.png').convert("RGBA")
data = img.getdata()
new_data = []

bg_r, bg_g, bg_b = 12, 15, 24

for x in range(img.width):
    for y in range(img.height):
        r, g, b, a = img.getpixel((x, y))
        nr = max(0, r - bg_r)
        ng = max(0, g - bg_g)
        nb = max(0, b - bg_b)
        alpha = max(nr, ng, nb)
        
        # We also want to mask out the box manually. The V is exactly in the center.
        # Let's compute distance from center
        cx, cy = 512, 512
        dist = ((x - cx)**2 + (y - cy)**2)**0.5
        
        # If distance is > 220, it's outside the V core. But the V has motion lines to the left.
        # Motion lines might go up to dist 300.
        # Let's just use a higher alpha threshold for the whole image
        # Box edges usually have alpha around 20-30.
        if alpha < 45:
            new_data.append((0, 0, 0, 0))
        else:
            # We must feather it to avoid jagged edges on the V
            alpha_f = min(255, int((alpha - 45) * 1.5))
            
            # Un-premultiply
            out_r = min(255, int((nr / alpha) * 255))
            out_g = min(255, int((ng / alpha) * 255))
            out_b = min(255, int((nb / alpha) * 255))
            
            new_data.append((out_r, out_g, out_b, alpha_f))

img.putdata(new_data)
img.save('VigrLogoTransparent_clean.png', "PNG")
