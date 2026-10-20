"""Public identity and crawler content checks without a browser dependency."""
import base64
import hashlib
import json
import re
import struct
import unittest
from html.parser import HTMLParser
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web"
PAGES = {"index.html": "", "about/index.html": "about/",
         "terms/index.html": "terms/", "liability/index.html": "liability/"}
TAG = "G-G4SYW37S81"
GOOGLE_HOSTS = {"https://www.googletagmanager.com", "https://www.google-analytics.com",
                "https://region1.google-analytics.com"}


class Document(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.elements = []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        self.elements.append((tag, dict(attrs)))


class WebMetadataTests(unittest.TestCase):
    def test_all_indexable_pages_have_unique_canonical_and_description(self):
        descriptions = set()
        for name, route in PAGES.items():
            canonical = "https://worthhit.com/" + route
            elements = Document(WEB / name).elements
            self.assertIn(("link", {"rel": "canonical", "href": canonical}), elements)
            description = [a["content"] for t, a in elements if t == "meta" and a.get("name") == "description"]
            self.assertEqual(len(description), 1)
            self.assertGreater(len(description[0]), 60)
            descriptions.add(description[0])
            self.assertTrue(any(t == "h1" for t, _ in elements))
        self.assertEqual(len(descriptions), len(PAGES))

    def test_sitemap_and_manifest_use_real_origin(self):
        urls = ElementTree.parse(WEB / "sitemap.xml").getroot()
        self.assertEqual(
            {x[0].text for x in urls},
            {"https://worthhit.com/" + route for route in PAGES.values()},
        )
        self.assertIn("https://worthhit.com/sitemap.xml", (WEB / "robots.txt").read_text())
        manifest = json.loads((WEB / "manifest.json").read_text())
        self.assertEqual(manifest["short_name"], "Worthhit")
        self.assertEqual(manifest["start_url"], "/")
        self.assertEqual(manifest["scope"], "/")
        for icon in manifest["icons"]:
            data = (WEB / icon["src"]).read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            width, height = struct.unpack(">II", data[16:24])
            self.assertEqual(f"{width}x{height}", icon["sizes"])
        social = (WEB / "social-card.png").read_bytes()
        self.assertEqual(struct.unpack(">II", social[16:24]), (1200, 630))

    def test_single_nonblocking_google_tag_is_first_in_every_head(self):
        for name, route in PAGES.items():
            source = (WEB / name).read_text()
            elements = Document(WEB / name).elements
            first = elements[elements.index(("head", {})) + 1]
            self.assertEqual(first[0], "script")
            self.assertEqual(first[1]["src"], "https://www.googletagmanager.com/gtag/js?id=" + TAG)
            self.assertIn("async", first[1])
            self.assertEqual(first[1]["referrerpolicy"], "no-referrer")
            self.assertEqual(source.count("gtag/js?id="), 1)
            self.assertEqual(source.count("gtag('config', '" + TAG + "'"), 1)
            self.assertIn("page_location: 'https://worthhit.com/" + route + "'", source)
            self.assertIn("page_referrer: ''", source)
            self.assertRegex(source, r"page_title: '[^']+'")
            self.assertIn("allow_google_signals: false", source)
            self.assertIn("allow_ad_personalization_signals: false", source)
            self.assertNotIn("gtag('event'", source)
            self.assertLess(source.index('<meta charset="UTF-8">'), 1024)
        bootstrap = (WEB / "flutter_bootstrap.js").read_text()
        self.assertNotIn("gtag", bootstrap)
        self.assertNotIn("dataLayer", bootstrap)

    def test_csp_hashes_every_inline_script_and_limits_google_hosts(self):
        header = (ROOT / "deploy/nginx/headers.conf").read_text()
        for name in PAGES:
            source = (WEB / name).read_text()
            metas = [attrs["content"] for tag, attrs in Document(WEB / name).elements
                     if tag == "meta" and attrs.get("http-equiv") == "Content-Security-Policy"]
            self.assertEqual(len(metas), 1)
            for attrs, script in re.findall(r"<script([^>]*)>(.*?)</script>", source, re.S):
                if 'src=' in attrs:
                    continue
                digest = base64.b64encode(hashlib.sha256(script.encode()).digest()).decode()
                for policy in [metas[0], header]:
                    self.assertIn("'sha256-" + digest + "'", policy)
            for policy in [metas[0], header]:
                directives = {chunk.strip().split()[0]: chunk.strip().split()[1:]
                              for chunk in policy.split(';') if chunk.strip()}
                scripts = directives.get('script-src', [])
                self.assertNotIn("'unsafe-inline'", scripts)
                self.assertIn("https://www.googletagmanager.com", scripts)
                self.assertEqual({value for value in directives['connect-src'] if 'google' in value}, GOOGLE_HOSTS)
                self.assertEqual({value for value in scripts if value.startswith('https:')}, {'https://www.googletagmanager.com'})
                self.assertNotIn("https:", policy.split())
                self.assertNotIn("doubleclick", policy)

    def test_information_pages_have_accessible_crosslinks_and_version(self):
        for name, route in PAGES.items():
            if not route:
                continue
            source = (WEB / name).read_text()
            elements = Document(WEB / name).elements
            links = {attrs.get('href'): attrs for tag, attrs in elements if tag == 'a'}
            self.assertIn('#content', links)
            self.assertTrue(any(tag == 'main' and attrs.get('id') == 'content' for tag, attrs in elements))
            self.assertTrue(any(tag == 'nav' and attrs.get('aria-label') == 'On this page' for tag, attrs in elements))
            for target in ['../', '../about/', '../terms/', '../liability/',
                           'https://github.com/consciontologic/worthhit']:
                self.assertIn(target, links)
            self.assertEqual(links['../' + route].get('aria-current'), 'page')
            self.assertEqual(source.count('data-app-version'), 1)
            version = re.search(r'^version: (\S+)', (ROOT / 'pubspec.yaml').read_text(), re.M)[1].split('+')[0]
            self.assertIn('<span data-app-version>' + version + '</span>', source)
            self.assertIn(('html', {'lang': 'en'}), elements)
            self.assertIn('Google Analytics', source)
        terms = (WEB / 'terms/index.html').read_text()
        self.assertIn('Enhanced measurement', terms)
        self.assertIn('cookies', terms)
        self.assertIn('must not publish API keys', terms)
        liability = (WEB / 'liability/index.html').read_text()
        self.assertIn('cannot be excluded or restricted', liability)

    def test_brand_variants_are_distinct_transparent_vectors(self):
        for variant, color in [("light", "#252A25"), ("dark", "#CAEF63")]:
            source = (ROOT / f"assets/brand/mark-{variant}.svg").read_text()
            self.assertIn(color, source)
            self.assertNotIn("<rect", source)
            self.assertNotIn("#fff", source.lower())
        hashes = [hashlib.sha256((ROOT / f"assets/brand/mark-{v}.png").read_bytes()).digest() for v in ["light", "dark"]]
        self.assertNotEqual(*hashes)


if __name__ == "__main__":
    unittest.main()
