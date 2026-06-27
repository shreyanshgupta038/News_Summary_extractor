import requests
import re
import json
from lxml import html

# TOI requires a very specific User-Agent
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
}


class SmartScraper:
    def __init__(self, url):
        self.url = url
        self.tree = None
        if 'timesofindia' in url:
            self.desk = "TOI News Desk"
        elif 'firstpost' in url:
            self.desk = "Firstpost News Desk"
        else:
            self.desk = "News Desk"

    def fetch(self):
        try:
            session = requests.Session()
            response = session.get(self.url, headers=HEADERS, verify=False, timeout=20)
            response.raise_for_status()

            content = response.text

            # Remove heavy JS blocks
            content = re.sub(
                r'<(script|style|header|footer|nav|aside|iframe)[^>]*>.*?</\1>',
                '',
                content,
                flags=re.DOTALL | re.IGNORECASE
            )

            self.tree = html.fromstring(content)

        except Exception as e:
            raise Exception(f"Error fetching URL: {e}")

    def get_authors(self):
        scripts = self.tree.xpath('//script[@type="application/ld+json"]/text()')
        for s in scripts:
            try:
                data = json.loads(s)
                items = data if isinstance(data, list) else [data]
                for item in items:
                    author_data = item.get('author')
                    if isinstance(author_data, dict):
                        return author_data.get('name')
                    if isinstance(author_data, list):
                        return author_data[0].get('name')
                    if item.get('publisher'):
                        return item['publisher'].get('name')
            except:
                continue

        meta_auth = self.tree.xpath(
            '//div[contains(@class, "author")]/text() | '
            '//a[contains(@class, "auth_name")]/text()'
        )

        if meta_auth:
            return meta_auth[0].strip()

        return "TOI News Desk"

    def get_date(self):
        date = self.tree.xpath(
            '//meta[@property="article:published_time"]/@content | '
            '//meta[@name="lastModifiedDate"]/@content | '
            '//time/@datetime'
        )

        return date[0] if date else "Date not found"

    def get_title(self):
        title = self.tree.xpath(
            '//h1/text() | //meta[@property="og:title"]/@content'
        )

        return title[0].strip() if title else "Title not found"

    def get_content(self):
        article_body = []

        toi_containers = self.tree.xpath(
            '//div[contains(@class, "_s30J")] | '
            '//div[contains(@class, "articleBody")] | '
            '//div[contains(@class, "artText")]'
        )

        if toi_containers:
            for container in toi_containers:
                text = container.text_content().strip()
                text = re.sub(r'\s+', ' ', text)

                if len(text) > 100:
                    article_body.append(text)

        if not article_body:
            paragraphs = self.tree.xpath('//p')
            for p in paragraphs:
                text = p.text_content().strip()
                if len(text) > 40:
                    junk_keywords = [
                        'follow us',
                        'subscribe',
                        'newsletter',
                        'copyright',
                        'click here'
                    ]
                    if not any(jk in text.lower() for jk in junk_keywords):
                        article_body.append(text)

        if article_body:
            return "\n\n".join(list(dict.fromkeys(article_body)))

        return "Content could not be isolated."


# ✅ THIS is the only function backend should use
def scrape_article(url: str):
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    scraper = SmartScraper(url)
    scraper.fetch()

    return {
        "author": scraper.get_authors(),
        "date": scraper.get_date(),
        "title": scraper.get_title(),
        "content": scraper.get_content()
    }