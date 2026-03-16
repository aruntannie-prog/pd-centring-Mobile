import fitz  # PyMuPDF
from PIL import Image, ImageDraw

def create_blank_template(pdf_path, output_png):
    # Load PDF
    doc = fitz.open(pdf_path)
    page = doc[0]
    
    # Render at 300 DPI for high quality
    pix = page.get_pixmap(dpi=300)
    pix.save(output_png)
    
    # Open with PIL to draw white boxes
    img = Image.open(output_png)
    draw = ImageDraw.Draw(img)
    
    # Scale factor from PyMuPDF points to 300 DPI PNG pixels
    scale = 300 / 72.0
    
    # Bounding boxes to erase (in PDF points, from our JSON analysis)
    # We add a little padding to ensure complete erasure
    def erase_pt(bbox):
        # bbox is (x0, y0, x1, y1)
        # multiply by scale
        px_bbox = [coord * scale for coord in bbox]
        # expand by 2 pixels
        px_bbox[0] -= 2
        px_bbox[1] -= 2
        px_bbox[2] += 2
        px_bbox[3] += 2
        draw.rectangle(tuple(px_bbox), fill="white")

    # The dynamic areas to erase:
    erase_pt([88, 112, 112, 126]) # 1948
    erase_pt([70, 129, 152, 160]) # Vijayalashmi Constructions
    erase_pt([432, 129, 489, 144]) # 8056843759
    erase_pt([105, 205, 120, 220]) # PD (Vehicle)
    erase_pt([439, 203, 491, 218]) # 30-04-2022
    
    # Left table quantities
    erase_pt([245, 273, 252, 288]) # 1 (Runner)
    erase_pt([120, 273, 127, 288]) # 10 (12" Palagai)
    erase_pt([120, 289, 127, 303]) # 2
    erase_pt([120, 304, 127, 318]) # 1
    erase_pt([120, 319, 127, 334]) # 1
    erase_pt([120, 334, 127, 349]) # 3
    erase_pt([120, 349, 127, 364]) # 4
    erase_pt([88, 364, 116, 379])  # 21 (total sum left)
    
    # Col 2 quantities
    erase_pt([183, 273, 190, 288]) # 1 (9" Palagai)
    erase_pt([183, 289, 190, 303]) # 1
    erase_pt([183, 304, 190, 318]) # 1
    erase_pt([183, 319, 190, 334]) # 2
    erase_pt([183, 334, 190, 349]) # 1
    erase_pt([183, 349, 190, 364]) # 5
    erase_pt([183, 364, 190, 379]) # 2
    erase_pt([148, 380, 183, 394]) # 13 (col2 sum)
    
    # Col 3 quantities
    erase_pt([59, 273, 65, 288])   # 3 (6" Palagai)
    erase_pt([23, 289, 49, 303])   # 3 (Total sum)
    
    # Joint piece quantity
    erase_pt([90, 412, 124, 427])  # 0.00 kg
    
    # Amount text boxes
    erase_pt([529, 355, 566, 370]) # 3201.00 Rent
    erase_pt([529, 373, 566, 388]) # 750.00 Down Vehicle
    erase_pt([529, 394, 550, 409]) # 0.00 Deposit
    erase_pt([529, 412, 566, 426]) # 3951.00 Total
    erase_pt([529, 429, 550, 442]) # 0.00 Advance
    erase_pt([529, 446, 566, 459]) # 3951.00 Balance
    
    # Specific fixed text that we WILL render dynamically if we want (e.g. rate breakdown text)
    # The rate breakdown text "7.00 DZy 79.50 ft 636.00" spans right side of table
    # Let's erase the entire block from the inner rect containing the rates (so we can print our own dynamically):
    # Inner Right Panel bounds: x=248 to x=526, y=244 to 462.
    # Exclude the "Joint Piece" (which is left side)
    # The Breakdown area spans X: 249 to 525, Y: 245 to 350
    erase_pt([250, 245, 525, 350])
    
    # Additional customer address box lower down
    erase_pt([391, 113, 550, 128]) # Date 01-04-2022
    erase_pt([73, 164, 300, 203]) # Murali ... Address
    erase_pt([431, 163, 550, 178]) # Thoribakkam
    
    img.save(output_png)
    print(f"Template created at {output_png}")

create_blank_template(
    r"C:\Users\arun_\Downloads\Vijayalashmi Constructions.1948SD.pdf",
    "assets/images/invoice_template_blank.png"
)
