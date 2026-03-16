import fitz

pdf_path = r"c:\Users\arun_\Downloads\PD NEW RATE CARD.pdf"
doc = fitz.open(pdf_path)

with open("pdf_output.txt", "w", encoding="utf-8") as f:
    for i, page in enumerate(doc):
        text = page.get_text()
        f.write(f"--- PAGE {i+1} ---\n")
        f.write(text + "\n")
        
doc.close()
print("Wrote to pdf_output.txt")
