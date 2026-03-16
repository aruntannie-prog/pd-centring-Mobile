import os

def insert_rates():
    dart_file = "lib/data/rate_card.dart"
    rates_file = "dart_rates.txt"
    
    with open(rates_file, "r", encoding="utf-8") as f:
        rates_code = f.read()
        
    with open(dart_file, "r", encoding="utf-8") as f:
        content = f.read()
        
    # We want to insert the rates right before the closing bracket of rateCardItems
    # Search for exactly:
    # ];
    # /// Items grouped by category
    
    if "];" in content:
        # Find the last "];" before rateCardByCategory
        parts = content.split("];\n\n/// Items grouped")
        if len(parts) == 2:
            new_content = parts[0] + "\n  // ── GENERATED COLUMN & BEAM SHEETS & SHOES ──\n" + rates_code + "];\n\n/// Items grouped" + parts[1]
            
            with open(dart_file, "w", encoding="utf-8") as f:
                f.write(new_content)
            print("Successfully inserted rates into rate_card.dart")
        else:
            print("Could not find insertion point. Parts:", len(parts))
    else:
        print("Could not find end of array block")

insert_rates()
