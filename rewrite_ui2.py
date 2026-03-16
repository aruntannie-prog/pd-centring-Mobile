import re

with open('lib/screens/add_customer.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Remove Firebase Auth imports
text = text.replace("import 'package:firebase_auth/firebase_auth.dart';", "")
text = text.replace("import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';", "")
text = text.replace("import 'dart:async';", "")

# 2. Hardcode phone as verified to true so the button is active and OTP UI logic is short-circuited
text = text.replace("bool _isPhoneVerified = false;", "bool _isPhoneVerified = true;")
text = text.replace("bool _isVerifying = false;", "bool _isVerifying = false;")

# 3. Disable Verify button UI in phone input by replacing hasVerify: true with hasVerify: false
text = text.replace("hasVerify: true, isVerified: _isPhoneVerified", "hasVerify: false, isVerified: false")

# 4. Remove sliding OTP UI stack block to shrink code
otp_screen_start = text.find('// OTP Screen (Screen 2) sliding up')
otp_screen_end_tag = '],\\n          ),'
otp_screen_end = text.find(otp_screen_end_tag, otp_screen_start) 

if otp_screen_start != -1 and otp_screen_end != -1:
    text = text[:otp_screen_start] + text[otp_screen_end:]

with open('lib/screens/add_customer.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Removed OTP logic")
