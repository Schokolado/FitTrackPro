import os
import json
import shutil
import sys

def create_imageset(name, png_file):
    base_dir = f"Resources/Assets.xcassets/{name}.imageset"
    os.makedirs(base_dir, exist_ok=True)
    
    shutil.copy(png_file, os.path.join(base_dir, f"{name}.png"))
    
    contents = {
      "images" : [
        {
          "idiom" : "universal",
          "filename" : f"{name}.png",
          "scale" : "1x"
        },
        {
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "idiom" : "universal",
          "scale" : "3x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      },
      "properties" : {
        "template-rendering-intent" : "template"
      }
    }
    
    with open(os.path.join(base_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

names = {
    "chest": "IconChest",
    "arms": "IconArms",
    "shoulders": "IconShoulders",
    "back": "IconBack",
    "abs": "IconAbs",
    "cardio": "IconCardio"
}

for key, val in names.items():
    create_imageset(val, f"icon_{key}.png")

