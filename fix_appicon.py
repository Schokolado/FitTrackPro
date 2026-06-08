import sys
from PIL import Image

# 1. Create a pure black background 1024x1024
bg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 255))

# 2. Open the cropped transparent logo (600x600)
logo = Image.open('Resources/Assets.xcassets/VigrLogoTransparent.imageset/VigrLogoTransparent.png')

# 3. Paste the logo into the center
# (1024 - 600) / 2 = 212
bg.paste(logo, (212, 212), logo)

# 4. Save
bg.save('app_icon_pure.png', "PNG")
