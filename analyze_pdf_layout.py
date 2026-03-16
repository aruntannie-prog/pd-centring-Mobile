import fitz  # PyMuPDF
import sys
import json

def analyze_pdf(filepath):
    doc = fitz.open(filepath)
    page = doc[0]

    # Extract text with coordinates and styling
    blocks = page.get_text("dict")["blocks"]
    text_info = []
    for b in blocks:
        if "lines" in b:
            for l in b["lines"]:
                for s in l["spans"]:
                    text = s["text"].strip()
                    if text:
                        text_info.append({
                            "text": text,
                            "bbox": s["bbox"], # (x0, y0, x1, y1)
                            "size": s["size"],
                            "font": s["font"],
                            "color": s["color"]
                        })

    # Extract drawings (lines, rects)
    drawings = page.get_drawings()
    lines = []
    rects = []
    for path in drawings:
        for item in path["items"]:
            if item[0] == "l": # line
                lines.append({
                    "start": (item[1].x, item[1].y),
                    "end": (item[2].x, item[2].y),
                    "width": path["width"],
                    "color": path["color"]
                })
            elif item[0] == "re": # rect
                rects.append({
                    "rect": (item[1].x0, item[1].y0, item[1].x1, item[1].y1),
                    "width": path["width"],
                    "color": path["color"],
                    "fill": path["fill"]
                })

    with open('pdf_layout_blueprint.json', 'w', encoding='utf-8') as f:
        json.dump({
            "page_width": page.rect.width,
            "page_height": page.rect.height,
            "text": text_info,
            "lines": lines,
            "rects": rects
        }, f, indent=2, ensure_ascii=False)
        print("Successfully extracted rigorous PDF coordinates to pdf_layout_blueprint.json")

analyze_pdf(r"C:\Users\arun_\Downloads\Vijayalashmi Constructions.1948SD.pdf")
