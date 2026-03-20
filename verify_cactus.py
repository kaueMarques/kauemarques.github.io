from playwright.sync_api import sync_playwright, expect
import os

def verify(page):
    # Go to home
    page.goto("http://localhost:4321")
    page.wait_for_timeout(1000)
    page.screenshot(path="/home/jules/verification/home_dark.png")

    # Check "Sobre" page
    page.get_by_role("link", name="Sobre").click()
    page.wait_for_timeout(1000)
    page.screenshot(path="/home/jules/verification/about.png")

    # Check "Blog" page
    page.get_by_role("link", name="Blog").first.click()
    page.wait_for_timeout(1000)
    page.screenshot(path="/home/jules/verification/blog.png")

    # Check a specific post
    page.get_by_text("Uma pincelada de spring batch").click()
    page.wait_for_timeout(1000)
    page.screenshot(path="/home/jules/verification/post.png")

if __name__ == "__main__":
    os.makedirs("/home/jules/verification/video", exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context(record_video_dir="/home/jules/verification/video")
        page = context.new_page()
        try:
            verify(page)
        finally:
            context.close()
            browser.close()
