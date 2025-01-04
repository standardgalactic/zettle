import browser_cookie3
import json

# Fetch cookies from Chrome
cookies = browser_cookie3.chrome(domain_name='youtube.com')

# Write cookies to a file in Netscape format expected by yt-dlp
with open('cookies.txt', 'w') as file:
    for c in cookies:
        file.write(f"{c.domain}\t{'TRUE' if c.domain_initial_dot else 'FALSE'}\t{c.path}\t{'TRUE' if c.secure else 'FALSE'}\t{int(c.expires.timestamp()) if c.expires else 0}\t{c.name}\t{c.value}\n")
