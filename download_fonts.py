import urllib.request
import os

os.makedirs('assets/fonts', exist_ok=True)

url = 'https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansTamil/NotoSansTamil-Regular.ttf'
bold_url = 'https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansTamil/NotoSansTamil-Bold.ttf'

print("Downloading regular font...")
urllib.request.urlretrieve(url, 'assets/fonts/NotoSansTamil-Regular.ttf')

print("Downloading bold font...")
urllib.request.urlretrieve(bold_url, 'assets/fonts/NotoSansTamil-Bold.ttf')

print("Done.")
