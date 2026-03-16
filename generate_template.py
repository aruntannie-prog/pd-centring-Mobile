import json

def generate_full_dart():
    data = json.load(open('pdf_layout_blueprint.json', encoding='utf-8'))
    
    dart_code = """
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pd_centring/models/bill.dart';

class InvoiceTemplateGenerator {
  static pw.Widget buildTemplate(Bill bill, pw.Font tamilFont, pw.Font englishFont, pw.Font englishBold) {
    return pw.Container(
      width: 595.28,
      height: 841.89,
      child: pw.Stack(
        children: [
"""
    
    # 1. DRAW ALL LINES
    for l in data['lines']:
        x1, y1 = l['start']
        x2, y2 = l['end']
        width = l['width']
        
        # Round values
        x1, x2, y1, y2, width = round(x1, 2), round(x2, 2), round(y1, 2), round(y2, 2), round(width, 2)
        
        if abs(y1 - y2) < 1:
            w = abs(x1 - x2)
            dart_code += f"          pw.Positioned(left: {min(x1,x2)}, top: {y1}, child: pw.Container(width: {w}, height: {width}, color: PdfColors.black)),\n"
        elif abs(x1 - x2) < 1:
            h = abs(y1 - y2)
            dart_code += f"          pw.Positioned(left: {x1}, top: {min(y1,y2)}, child: pw.Container(width: {width}, height: {h}, color: PdfColors.black)),\n"

    # 2. DRAW EXPECTED STATIC TEXT
    legacy_to_unicode = {
        "LŽƒÊ<z": "பில் எண்",
        "^IIY": "தேதி",
        "]LNƫ": "பெயர்",
        "^LX}J Lƫ": "போன் நம்பர்",
        "TzœÊ<z": "செல்லுமிடம்",
        "ƬyG}Ê^IIY": "ரிட்டன் தேதி",
        "ÊO}Kƫ": "ரன்னர்",
        "ãÌLQ_B": "12\''பலகை",
        "àÌLQ_B": "9\''பலகை",
        "ÛÜÌLQ_B": "6\''பலகை",
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
    
    # Dynamic values to omit:
    dynamic_starts = ["1948", "Vijayalashmi", "Constructions", "8056843759", "PD", "30-04-2022", "01-04-2022", "Murali", "Nanmangalam", "cross street"]
    
    quantities = []
    
    for t in data['text']:
        text = t['text'].strip()
        if not text: continue
        
        # Detect if it's an amount/quantity
        is_qty_or_amount = False
        try:
            if text.isdigit() or (text.replace(".","",1).isdigit() and "x" not in text):
                is_qty_or_amount = True
        except:
            pass
            
        if any(text.startswith(d) for d in dynamic_starts) or is_qty_or_amount or "kg" in text:
            continue
            
        mapped = legacy_to_unicode.get(text, text)
        mapped = mapped.replace("'", "\\'")
        
        # Override the gibberish Tamil blocks with our cleaner Unicode versions
        if text.startswith("LQ_BÖÊ«yžÖ") or text.startswith("(Damage)"): continue
        if text.startswith("L¸I_G|IX^QX"): continue
        if text.startswith("6I‚”Ê:zGXKÊLH{_I"): continue
        if text.startswith("]D´{IÊ^Tzž") or text.startswith("LŽœtB~Lž") or text == "Ø": continue
        if text.startswith("U“yÊBQ_TÊ8ƒQXMƒ") or text.startswith("]BXžtBÊ^Tzž") or text.startswith("LXƫyœNŽG"): continue
        if text.startswith("^T_QÊ^JO") or text.startswith("MX_QÊßØÚÚ") or text.startswith("MHŽt”^Mƒ"): continue
        
        # Custom mapping for some fixed title blobs
        if "ESTIMATOIN BILL" in mapped: mapped = "ESTIMATION BILL"
        if "9443135118" in mapped or "9566155418" in mapped: pass # these are company phones, keep them!
        
        is_bold = "Bold" in t['font']
        x, y = round(t['bbox'][0], 2), round(t['bbox'][1], 2)
        size = t['size']
        
        # Guess font based on content (Tamil chars vs English)
        is_tamil = any("\u0B80" <= c <= "\u0BFF" for c in mapped)
        if mapped in legacy_to_unicode.values():
            is_tamil = True
            
        font_var = "tamilFont" if is_tamil else ("englishBold" if is_bold else "englishFont")
        dart_code += f"          pw.Positioned(left: {x}, top: {y}, child: pw.Text('{mapped}', style: pw.TextStyle(font: {font_var}, fontSize: {size}, fontWeight: pw.FontWeight.{'bold' if is_bold else 'normal'}))),\n"

    # Add back the clean footer blocks using native positioning
    dart_code += """
          pw.Positioned(left: 30, top: 800, child: pw.Text('குறிப்பு: வாடகை பொருள் உடைந்தால்,\\nதொலைந்தால் முழு பணம் வசூலிக்கப்படும்.', style: pw.TextStyle(font: tamilFont, fontSize: 8))),
          pw.Positioned(left: 260, top: 800, child: pw.Text('பொருட்கள் நல்ல முறையில்\\nதிரும்ப ஒப்படைக்கப்பட வேண்டும்.', style: pw.TextStyle(font: tamilFont, fontSize: 8))),
          pw.Positioned(left: 420, top: 800, child: pw.Text('நேரம்: காலை 8:00 முதல்\\nமாலை 5:00 வரை', style: pw.TextStyle(font: tamilFont, fontSize: 8))),
          pw.Positioned(left: 40, top: 308, child: pw.Text('பொருள் எடுப்பவர் கையொப்பம்', style: pw.TextStyle(font: tamilFont, fontSize: 10, fontWeight: pw.FontWeight.bold))),
    """

    dart_code += """        ],
      ),
    );
  }
}
"""
    with open('lib/services/invoice_template_widget.dart', 'w', encoding='utf-8') as f:
        f.write(dart_code)
    print("Generated invoice_template_widget.dart successfully")

generate_full_dart()
