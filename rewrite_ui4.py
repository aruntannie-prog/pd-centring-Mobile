import re

with open('lib/screens/add_customer.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Remove the residual _verifyPhone block
vp_start = text.find('// Store the ConfirmationResult for Web')
vp_end_tag = '    }\\n  }\\n\\n  \\n  // --- New OTP UI State ---'
vp_end = text.find(vp_end_tag)

if vp_start != -1 and vp_end != -1:
    text = text[:vp_start] + text[vp_end + len(vp_end_tag):]

# Remove the new OTP UI state logic block
otp_ui_start = text.find('bool _showOtpScreen = false;')
otp_ui_end_tag = '  @override\\n  Widget build(BuildContext context) {'
otp_ui_end = text.find(otp_ui_end_tag)

if otp_ui_start != -1 and otp_ui_end != -1:
    text = text[:otp_ui_start] + text[otp_ui_end:]

# Remove residual AnimatedPositioned layout which was causing syntax bracket mismatches
ap_start = text.find('              // OTP Screen (Screen 2) sliding up')
ap_end_tag = '  // ==== Screen 1 Builders ===='
ap_end_index = text.find(ap_end_tag)

if ap_start != -1 and ap_end_index != -1:
    text = text[:ap_start] + text[ap_end_index:]

with open('lib/screens/add_customer.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Cleaned up dart file successfully")
