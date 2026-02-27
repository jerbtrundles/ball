from PIL import Image
import collections

def analyze(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    border = []
    for x in range(w):
        border.append(img.getpixel((x, 0)))
        border.append(img.getpixel((x, h-1)))
    for y in range(1, h-1):
        border.append(img.getpixel((0, y)))
        border.append(img.getpixel((w-1, y)))
    
    cnt = collections.Counter(border)
    print(f"File: {path}")
    print("Border colors:", cnt.most_common(5))

import glob
for f in glob.glob(r"c:\ball\assets\images\logos\logo_*.png")[:3]:
    analyze(f)
