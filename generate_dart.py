import re

def generate_dart():
    with open("pdf_output.txt", "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f.readlines()]
    
    out = open("dart_rates.txt", "w", encoding="utf-8")
    
    idx = 0
    current_category = "columnBoxes"
    
    while idx < len(lines):
        line = lines[idx]
        if "ROUND BOX" in line:
            current_category = "other" # or "columnBoxes" but we already have some round boxes
            pass
            
        # Match sizes like 9" * 12" or 9” * 12”
        # The quotes might be smart quotes
        size_match = re.match(r'^(\d+)["”]\s*\*\s*(\d+)["”]$', line)
        if size_match:
            size_str = f'{size_match.group(1)}" x {size_match.group(2)}"'
            
            # The next 10 lines should be the rates for 10ft down to 2ft, and the Shoe rate
            rates = []
            for i in range(10):
                idx += 1
                if idx < len(lines):
                    # rate could be a number
                    rates.append(lines[idx])
            
            # 10ft, 9, 8, 7, 6, 5, 4, 3, 2, SHOE
            lengths = [10, 9, 8, 7, 6, 5, 4, 3, 2]
            
            # Generate column box records length-by-length
            for i, length in enumerate(lengths):
                rate = rates[i]
                if rate.isdigit() and int(rate) > 0:
                    name = f'{size_str} Box - {length}ft'
                    if current_category == "other":
                         name = f'{size_str} Round Box - {length}ft'
                         
                    out.write(f"  RateCardItem(\n")
                    out.write(f"    name: '{name}',\n")
                    out.write(f"    category: MaterialCategory.columnBoxes,\n")
                    out.write(f"    defaultUnit: 'nos',\n")
                    out.write(f"    flatRate: {rate},\n")
                    out.write(f"  ),\n")
            
            # Generate the Shoe record if valid
            shoe_rate = rates[9]
            if shoe_rate.isdigit() and int(shoe_rate) > 0:
                shoe_name = f'Shoe {size_str}'
                out.write(f"  RateCardItem(\n")
                out.write(f"    name: '{shoe_name}',\n")
                out.write(f"    category: MaterialCategory.other,\n")
                out.write(f"    defaultUnit: 'nos',\n")
                out.write(f"    flatRate: {shoe_rate},\n")
                out.write(f"  ),\n")
            
        idx += 1
        
    out.close()
    print("Generated dart_rates.txt")
    
generate_dart()
