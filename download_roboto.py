import urllib.request
import os

os.makedirs('assets/fonts', exist_ok=True)

urls = [
    ('https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto-Regular.ttf', 'assets/fonts/Roboto-Regular.ttf'),
    ('https://raw.githubusercontent.com/google/fonts/main/apache/roboto/Roboto-Regular.ttf', 'assets/fonts/Roboto-Regular.ttf'),
    ('https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Regular.ttf', 'assets/fonts/Roboto-Regular.ttf'),
]

bold_urls = [
    ('https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto-Bold.ttf', 'assets/fonts/Roboto-Bold.ttf'),
    ('https://raw.githubusercontent.com/google/fonts/main/apache/roboto/Roboto-Bold.ttf', 'assets/fonts/Roboto-Bold.ttf'),
    ('https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Bold.ttf', 'assets/fonts/Roboto-Bold.ttf'),
]

def download_any(url_list, dest):
    for u in url_list:
        try:
            print(f"Trying {u}...")
            urllib.request.urlretrieve(u, dest)
            print(f"Success! Saved to {dest}")
            return True
        except Exception as e:
            print(f"Failed: {e}")
    return False

download_any(urls, 'assets/fonts/Roboto-Regular.ttf')
download_any(bold_urls, 'assets/fonts/Roboto-Bold.ttf')
