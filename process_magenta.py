import glob
from PIL import Image

def is_bg(r, g, b, a):
    if a < 255:
        return True
    return r > 200 and g > 200 and b > 200 and max(r,g,b) - min(r,g,b) < 30

def process(path):
    print(f"Processing {path}...")
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    pixels = img.load()
    
    visited = set()
    queue = []
    
    # Add borders to queue
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h-1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w-1, y))
        
    # Flood fill
    bg_pixels = set()
    head = 0
    while head < len(queue):
        x, y = queue[head]
        head += 1
        
        if (x, y) in visited:
            continue
        visited.add((x, y))
        
        r, g, b, a = pixels[x, y]
        if is_bg(r, g, b, a):
            bg_pixels.add((x, y))
            # add neighbors
            for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    if (nx, ny) not in visited:
                        queue.append((nx, ny))
                        
    # Replace background pixels with magenta
    # Apply a slight smoothing for anti-aliasing edges? 
    # Let's just do hard replacement for now.
    for x, y in bg_pixels:
        pixels[x, y] = (255, 0, 255, 255) # Magenta
        
    img.save(path, format="PNG", optimize=False)
    
for f in glob.glob(r"c:\ball\assets\images\logos\logo_*.png"):
    process(f)

print("Done processing backgrounds.")
