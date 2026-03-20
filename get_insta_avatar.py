import requests
import re
import sys

def get_avatar(username):
    url = f"https://www.instagram.com/{username}/"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        # Look for profile pic in meta tags
        match = re.search(r'property="og:image" content="([^"]+)"', response.text)
        if match:
            return match.group(1)
    return None

if __name__ == "__main__":
    avatar = get_avatar("kaue.marquesb")
    if avatar:
        print(avatar)
    else:
        sys.exit(1)
