import sys
from PIL import Image

img = Image.open('VigrLogoTransparent_clean.png')
img = img.resize((64, 64))

chars = " .:-=+*#%@"
out = ""
for y in range(64):
    for x in range(64):
        a = img.getpixel((x, y))[3]
        idx = int((a / 255.0) * (len(chars) - 1))
        out += chars[idx]
    out += "\n"
print(out)
