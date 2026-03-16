import re

with open('lib/screens/add_customer.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# The file now has duplicate closing tags at the very bottom since I appended an extra } in my last replace.
# Let's clean up everything after the final valid closing brace of _buildSheetBtn
target = '}                '

# We will just write a clean function for _buildSheetBtn and close the class properly.
start_idx = text.find('  Widget _buildSheetBtn(IconData icon, String label, {required VoidCallback onTap}) {')

if start_idx != -1:
    clean_tail = '''  Widget _buildSheetBtn(IconData icon, String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderLight)
        ),
        child: Column(
          children: [
            Icon(icon, color: accentBlue, size: 28),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))
          ]
        )
      )
    );
  }
}
'''
    text = text[:start_idx] + clean_tail

with open('lib/screens/add_customer.dart', 'w', encoding='utf-8') as f:
    f.write(text)

