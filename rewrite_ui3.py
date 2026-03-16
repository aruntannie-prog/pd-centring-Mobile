import re

with open('lib/screens/add_customer.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 4. Remove sliding OTP UI stack block to shrink code properly
otp_screen_start = text.find('// OTP Screen (Screen 2) sliding up')
otp_screen_end_tag = '    );\\n  }\\n\\n  // ==== Screen 1 Builders ===='
otp_screen_end = text.find(otp_screen_end_tag, otp_screen_start) 

if otp_screen_start != -1 and otp_screen_end != -1:
    text = text[:otp_screen_start] + text[otp_screen_end:]
else:
    print('Failed to locate OTP block bounds')

with open('lib/screens/add_customer.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Removed AnimatedPositioned OTP logic")
