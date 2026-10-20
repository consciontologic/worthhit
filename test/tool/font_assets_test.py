"""Fast fingerprint checks for the full-glyph web font exports.

The optional font-tools environment performs the decompressed-table audit when
exports are generated. CI checks the exact audited bytes without that dependency.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "assets/fonts"
EXPECTED = {
    "SpaceGrotesk": (735, 1001, ["wght"]),
    "NotoSans": (3094, 4515, ["wght", "wdth"]),
    "NotoSansArabic": (1561, 1711, ["wght", "wdth"]),
    "NotoSansSC": (30890, 31036, ["wght"]),
}


class FontAssetTests(unittest.TestCase):
    def test_table_audit_only_normalizes_the_documented_container_fields(self):
        spec = importlib.util.spec_from_file_location("font_assets", ROOT / "tool/font_assets.py")
        font_assets = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(font_assets)
        head = bytes(range(54))
        normalized = font_assets.normalized_table("head", head)
        self.assertEqual(normalized[:8], head[:8])
        self.assertEqual(normalized[8:12], b"\0" * 4)
        self.assertEqual(normalized[12:16], head[12:16])
        self.assertEqual(int.from_bytes(normalized[16:18], "big"),
                         int.from_bytes(head[16:18], "big") & ~(1 << 11))
        self.assertEqual(normalized[18:], head[18:])
        for tag in ("glyf", "cmap", "fvar", "name", "GSUB", "GPOS"):
            self.assertEqual(font_assets.normalized_table(tag, head), head)

    def test_flutter_packages_full_woff2_faces_instead_of_source_ttf(self):
        assets = re.findall(r"asset: (assets/fonts/\S+)",
                            (ROOT / "pubspec.yaml").read_text())
        self.assertEqual(set(assets), {
            f"assets/fonts/{name}.woff2" for name in EXPECTED
        })

    def test_font_sources_licenses_and_audited_exports_match_fingerprints(self):
        records = json.loads((FONTS / "sources.json").read_text())
        by_file = {record["file"]: record for record in records}
        for record in records:
            with self.subTest(source=record["file"]):
                data = (FONTS / record["file"]).read_bytes()
                self.assertEqual(len(data), record["bytes"])
                self.assertEqual(hashlib.sha256(data).hexdigest(), record["sha256"])
        for name, (codepoints, glyphs, axes) in EXPECTED.items():
            with self.subTest(font=name):
                self.assertIn(f"{name}-OFL.txt", by_file)
                export = by_file[f"{name}.ttf"]["woff2"]
                self.assertEqual(export["file"], f"{name}.woff2")
                data = (FONTS / export["file"]).read_bytes()
                self.assertEqual(data[:4], b"wOF2")
                self.assertEqual(len(data), export["bytes"])
                self.assertEqual(hashlib.sha256(data).hexdigest(), export["sha256"])
                self.assertLess(len(data), by_file[f"{name}.ttf"]["bytes"])
                self.assertEqual(export["converter"], {
                    "fonttools": "4.67.0", "brotli": "1.2.0",
                    "transformed_tables": [],
                })
                audit = export["audit"]
                self.assertEqual(audit["codepoints"], codepoints)
                self.assertEqual(audit["glyphs"], glyphs)
                self.assertEqual([axis["tag"] for axis in audit["axes"]], axes)
                self.assertEqual(audit["all_rendering_tables_preserved"], True)
                self.assertEqual(audit["omitted_empty_dsig"], name == "SpaceGrotesk")
                self.assertEqual(audit["head_exceptions"],
                                 ["checkSumAdjustment", "flags.bit11"])


if __name__ == "__main__":
    unittest.main()
