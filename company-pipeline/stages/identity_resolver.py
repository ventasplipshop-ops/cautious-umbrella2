from playwright.sync_api import sync_playwright
from urllib.parse import quote
from timing import human_delay

BAD_DOMAINS = [
    "google",
    "youtube",
    "facebook",
    "instagram",
    "twitter",
    "linkedin",
    "wikipedia",
    "reddit",
    "tripadvisor"
]


def google_search(query):

    urls = []

    with sync_playwright() as p:

        browser = p.chromium.launch(
            headless=True,
            args=["--no-sandbox", "--disable-setuid-sandbox"]
        )

        page = browser.new_page(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122 Safari/537.36"
        )

        url = f"https://www.google.com/search?q={quote(query)}"

        print("[debug] opening:", url)

        page.goto(url, timeout=60000, wait_until="domcontentloaded")

        page.wait_for_timeout(4000)

        print("[debug] page url:", page.url)

        html = page.content()
        print("[debug] html size:", len(html))

        links = page.locator("a[href^='http']")

        count = links.count()

        print("[debug] total links:", count)

        for i in range(min(count, 30)):

            href = links.nth(i).get_attribute("href")

            if not href:
                continue

            if "google" in href:
                continue

            urls.append(href)

        browser.close()

    return urls
def detect_website(urls):

    for url in urls:

        if any(bad in url for bad in BAD_DOMAINS):
            continue

        return url

    return None


def run(seed):

    company = seed.company_name

    query = company

    if seed.country:
        query += f" {seed.country}"

    print("\n==============================")
    print("[stage] identity resolver")
    print("[company]", company)
    print("[query]", query)
    print("==============================")

    human_delay("short")

    urls = google_search(query)

    website = detect_website(urls)

    identity = {
        "company": company,
        "website": website,
        "urls_found": urls[:10]
    }

    print("\n[identity result]")
    print(identity)

    return identity