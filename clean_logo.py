import sys
from PIL import Image

def process(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()
    new_data = []
    
    # Base background color found via sampling
    bg_r, bg_g, bg_b = 12, 15, 24
    
    for item in data:
        r, g, b, a = item
        
        # 1. Subtract background
        nr = max(0, r - bg_r)
        ng = max(0, g - bg_g)
        nb = max(0, b - bg_b)
        
        # 2. Extract intensity (max channel)
        alpha = max(nr, ng, nb)
        
        # 3. Noise gate and un-premultiply
        if alpha < 5:
            new_data.append((0, 0, 0, 0))
        else:
            # Un-premultiply to recover the pure additive color
            # This turns dark glowing pixels into fully bright pixels with low alpha
            # which blends perfectly over white WITHOUT black fringing.
            out_r = min(255, int((nr / alpha) * 255))
            out_g = min(255, int((ng / alpha) * 255))
            out_b = min(255, int((nb / alpha) * 255))
            
            # Boost alpha slightly to retain glow punch
            out_a = min(255, int(alpha * 1.2))
            
            new_data.append((out_r, out_g, out_b, out_a))
            
    img.putdata(new_data)
    
    # We shouldn't crop too hard, just let the alpha handle it.
    # The image is 1024x1024. The V fits comfortably.
    img.save(output_path, "PNG")

process('/Users/p016324/.gemini/antigravity/brain/62667cb7-cd53-4318-9577-2cb7099208cd/vigr_logo_v_motion_notext_1780959705385.png', 'VigrLogoTransparent_clean.png')
print("Done")
