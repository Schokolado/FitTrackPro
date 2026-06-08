import sys
from PIL import Image
import math

img = Image.open('/Users/p016324/.gemini/antigravity/brain/62667cb7-cd53-4318-9577-2cb7099208cd/vigr_logo_v_motion_notext_1780959705385.png').convert("RGBA")
data = img.getdata()
new_data = []

bg_r, bg_g, bg_b = 12, 15, 24
cx, cy = 512, 512

for y in range(img.height):
    for x in range(img.width):
        # Distance from center
        dist = math.hypot(x - cx, y - cy)
        
        # Radial mask: 1.0 inside 260, fades to 0.0 at 380
        if dist < 260:
            mask = 1.0
        elif dist > 380:
            mask = 0.0
        else:
            # smoothstep
            t = 1.0 - ((dist - 260) / 120.0)
            mask = t * t * (3 - 2 * t)
            
        if mask == 0:
            new_data.append((0, 0, 0, 0))
            continue
            
        r, g, b, a = img.getpixel((x, y))
        nr = max(0, r - bg_r)
        ng = max(0, g - bg_g)
        nb = max(0, b - bg_b)
        alpha = max(nr, ng, nb)
        
        if alpha < 5:
            new_data.append((0, 0, 0, 0))
        else:
            out_r = min(255, int((nr / alpha) * 255))
            out_g = min(255, int((ng / alpha) * 255))
            out_b = min(255, int((nb / alpha) * 255))
            
            # Multiply alpha by the mask to fade out the box edges completely
            final_alpha = min(255, int(alpha * 1.5 * mask))
            
            new_data.append((out_r, out_g, out_b, final_alpha))

img.putdata(new_data)
img.save('VigrLogoTransparent_masked.png', "PNG")
print("Done")
