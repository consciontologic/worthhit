"""Public identity and crawler content checks without a browser dependency."""
import hashlib
import json
import struct
import unittest
from html.parser import HTMLParser
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web"


class Document(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.elements = []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        self.elements.append((tag, dict(attrs)))


class WebMetadataTests(unittest.TestCase):
    def test_both_indexable_pages_have_unique_canonical_and_description(self):
        descriptions = set()
        for path, canonical in [
            (WEB / "index.html", "https://worthhit.com/"),
            (WEB / "about/index.html", "https://worthhit.com/about/"),
        ]:
            elements = Document(path).elements
            self.assertIn(("link", {"rel": "canonical", "href": canonical}), elements)
            description = [a["content"] for t, a in elements if t == "meta" and a.get("name") == "description"]
            self.assertEqual(len(description), 1)
            self.assertGreater(len(description[0]), 60)
            descriptions.add(description[0])
            self.assertTrue(any(t == "h1" for t, _ in elements))
        self.assertEqual(len(descriptions), 2)

    def test_sitemap_and_manifest_use_real_origin(self):
        urls = ElementTree.parse(WEB / "sitemap.xml").getroot()
        self.assertEqual(
            {x[0].text for x in urls},
            {"https://worthhit.com/", "https://worthhit.com/about/"},
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
