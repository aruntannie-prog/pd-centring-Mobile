import fitz  # PyMuPDF
import sys
import os

pdf_path = "Vijayalashmi Constructions.1948SD.pdf"
if not os.path.exists(pdf_path):
    print(f"Error: {pdf_path} not found.")
    sys.exit(1)

doc = fitz.open(pdf_path)
page = doc.load_page(0)  # first page
pix = page.get_pixmap(dpi=150)
output_path = "invoice_original_snapshot.png"
pix.save(output_path)
print(f"Saved snapshot to {output_path}")
