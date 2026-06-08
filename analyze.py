import sys
from PIL import Image

img = Image.open('/Users/p016324/.gemini/antigravity/brain/62667cb7-cd53-4318-9577-2cb7099208cd/vigr_logo_v_motion_notext_1780959705385.png').convert("RGBA")
# Sample a few pixels around the V to see the background color
print("Top Left:", img.getpixel((300, 300)))
print("Top Right:", img.getpixel((700, 300)))
print("Bottom Left:", img.getpixel((300, 700)))
print("Bottom Right:", img.getpixel((700, 700)))
print("Way outside (glass box edge?):", img.getpixel((100, 100)))
