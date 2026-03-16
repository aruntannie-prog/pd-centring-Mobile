import json

def generate_dart():
    data = json.load(open('pdf_layout_blueprint.json', encoding='utf-8'))
    
    dart_code = """
  // AUTO-GENERATED FIXED TEMPLATE
  static pw.Widget _buildFixedTemplate(Bill bill, pw.Font tamilFont, pw.Font englishFont) {
    return pw.Container(
      width: 595.28,
      height: 841.89,
      child: pw.Stack(
        children: [
"""
    
    # Render all lines
    for l in data['lines']:
        x1, y1 = l['start']
        x2, y2 = l['end']
        width = l['width']
        # pw.Positioned line drawing
        # In pdf package, absolute lines can be drawn with CustomPaint or a positioned Container
        if abs(y1 - y2) < 1:
            # Horizontal line
            dart_code += f"          pw.Positioned(left: {min(x1,x2)}, top: {y1}, child: pw.Container(width: {abs(x1-x2)}, height: {width}, color: PdfColors.black)),\n"
        elif abs(x1 - x2) < 1:
            # Vertical line
            dart_code += f"          pw.Positioned(left: {x1}, top: {min(y1,y2)}, child: pw.Container(width: {width}, height: {abs(y1-y2)}, color: PdfColors.black)),\n"

    # Identify dynamic fields to skip their static rendering
    dynamic_texts = ["1948", "Vijayalashmi", "Constructions", "8056843759", "PD", "30-04-2022", 
                     "7.0 x", "8.0 x", "7.5 x", "4.5 x", "4.0 x", "3.0 x", "1.5 x", "21", "13",
                     "9.5 x", "6.5 x", "5.0 x", "3201.00", "0.00", "0.00 kg", "3951.00", "1", "2", "3", "4", "5", "-", "Thoribakkam"]
    
    # We will just map the legacy text directly to the unicode Tamil equivalent!
    legacy_to_unicode = {
        "LŽƒÊ<z": "பில் எண்",
        "^IIY": "தேதி",
        "]LNƫ": "பெயர்",
        "^LX}J Lƫ": "போன் நம்பர்",
        "TzœÊ<z": "செல்லுமிடம்",
        "ƬyG}Ê^IIY": "ரிட்டன் தேதி",
        "ÊO}Kƫ": "முகவரி",
        "ãÌLQ_B": "12''பலகை",
        "àÌLQ_B": "9''பலகை",
        "ÛÜÌLQ_B": "6''பலகை",
        "]LX¯RGtB": "பொருளடக்கம்",
        "Joint Piece": "Joint Piece",
        "]IX_B": "தொகை",
        "°": "ரூ",
        "TXG_B": "வாடகை",
        "Tzœ]IX_B": "வண்டித் தொகை",
        "]G~LXDYy": "டெப்பாசிட்",
        "]MX{IÊ]IX_B": "மொத்த தொகை",
        "TOº": "வரவு",
        "M‘IYÊ]IX_B": "மீதி தொகை"
    }

    for t in data['text']:
        text = t['text']
        # skip dynamic
        if any(text.startswith(d) for d in dynamic_texts):
            continue
            
        mapped_text = legacy_to_unicode.get(text, text)
        is_bold = "Bold" in t['font']
        font_var = "tamilFont" if mapped_text in legacy_to_unicode.values() else "englishFont"
        x, y = t['bbox'][0], t['bbox'][1]
        size = t['size']
        
        # y is the top of the bbox in PyMuPDF, pdf package Positioned top is also top
        dart_code += f"          pw.Positioned(left: {x}, top: {y}, child: pw.Text('{mapped_text}', style: pw.TextStyle(font: {font_var}, fontSize: {size}, fontWeight: pw.FontWeight.{'bold' if is_bold else 'normal'}))),\n"

    dart_code += """        ],
      ),
    );
  }
"""
    with open('dart_template.dart', 'w', encoding='utf-8') as f:
        f.write(dart_code)
    print("Generated dart_template.dart")

generate_dart()
