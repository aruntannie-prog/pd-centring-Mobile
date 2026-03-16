import sys

with open('lib/screens/add_customer.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

idx = 0
for i, line in enumerate(lines):
    if 'void _showOtpDialog()' in line:
        idx = i
        break

top_half = "".join(lines[:idx])
top_half = top_half.replace('_showOtpDialog();', 'setState(() => _showOtpScreen = true);\\n          _startOtpTimer();')

# To avoid multiline bugs in PowerShell string injection, 
# I am stopping here. I will just run Python logic via write_to_file and run.
