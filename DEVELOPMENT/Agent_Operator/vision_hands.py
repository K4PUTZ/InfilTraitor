import subprocess
import os
import re

TESSERACT_PATH = "/opt/homebrew/bin/tesseract"
CLICLICK_PATH = "/usr/local/bin/cliclick"

CACHE_DIR = "/Users/mateus/Agent_Operator/cache"

def capture_screen(output_path=os.path.join(CACHE_DIR, "screen.png")):
    subprocess.run(["screencapture", "-x", output_path], check=True)
    return output_path

def get_ocr_data(image_path):
    # tesseract image_path output_base hocr
    output_base = os.path.join(CACHE_DIR, "ocr_result")
    subprocess.run([TESSERACT_PATH, image_path, output_base, "hocr"], check=True)
    hocr_file = f"{output_base}.hocr"
    with open(hocr_file, "r") as f:
        data = f.read()
    return data

def find_text_coordinates(hocr_data, search_text):
    # Very basic hocr parser for demonstration
    # Look for ocrx_word with search_text
    # Example: <span class='ocrx_word' id='word_1_1' title='bbox 38 10 77 23; x_wconf 95'>Text</span>
    pattern = rf"<span[^>]*class='ocrx_word'[^>]*title='bbox (\d+) (\d+) (\d+) (\d+)[^']*'>({re.escape(search_text)})</span>"
    matches = re.findall(pattern, hocr_data, re.IGNORECASE)
    
    results = []
    for m in matches:
        x1, y1, x2, y2, text = m
        center_x = (int(x1) + int(x2)) // 2
        center_y = (int(y1) + int(y2)) // 2
        results.append({"text": text, "x": center_x, "y": center_y, "bbox": (x1, y1, x2, y2)})
    
    return results

def click_at(x, y):
    # macOS Retina scaling often needs adjustment. 
    # Usually cliclick uses logical pixels, but screencapture might be physical.
    # Let's test with 1:1 first.
    subprocess.run([CLICLICK_PATH, f"c:{x},{y}"], check=True)

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python3 vision_hands.py <text_to_find>")
        sys.exit(1)
        
    target = sys.argv[1]
    print(f"Searching for: {target}")
    
    img = capture_screen()
    hocr = get_ocr_data(img)
    coords = find_text_coordinates(hocr, target)
    
    if coords:
        print(f"Found '{target}' at {coords[0]['x']}, {coords[0]['y']}")
        click_at(coords[0]['x'], coords[0]['y'])
    else:
        print(f"Could not find '{target}'")
