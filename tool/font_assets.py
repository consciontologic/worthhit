"""Export and audit full-glyph WOFF2 text fonts without subsetting or renaming.

Optional regeneration/audit dependencies, installed only in a project-local venv:
  .local/brand-tools/bin/python -m pip install fonttools==4.67.0 Brotli==1.2.0
  .local/brand-tools/bin/python tool/font_assets.py --write
  .local/brand-tools/bin/python tool/font_assets.py

Production builds use committed exports; CI fingerprint tests need only stdlib.
WOFF2 table transforms are disabled to preserve original table bytes, including
glyph outlines, hints, names, cmap, layout and variations. Only the required WOFF2
head checksum and lossless-transform flag differ; the converter removes an empty
DSIG signature placeholder. Source TTF/OFL files stay intact.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONTS = ROOT / "assets/fonts"
CONVERTER = {"fonttools": "4.67.0", "brotli": "1.2.0", "transformed_tables": []}


def fingerprint(data):
    return {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}


def normalized_table(tag, data):
    if tag != "head":
        return data
    # checkSumAdjustment (8..11) depends on the container's table ordering;
    # WOFF2 sets flags bit 11 (16..17) to mark its lossless compression.
    flags = int.from_bytes(data[16:18], "big") & ~(1 << 11)
    return data[:8] + b"\0" * 4 + data[12:16] + flags.to_bytes(2, "big") + data[18:]


def audit(source, exported):
    from fontTools.ttLib import TTFont

    with TTFont(io.BytesIO(source), recalcBBoxes=False, recalcTimestamp=False) as old, \
            TTFont(io.BytesIO(exported), recalcBBoxes=False, recalcTimestamp=False) as new:
        if new.flavor != "woff2" or new.flavorData.transformedTables:
            raise ValueError("Expected WOFF2 with no table transforms.")
        tables = set(old.reader.tables)
        empty_dsig = "DSIG" in tables
        if empty_dsig:
            if old.reader["DSIG"] != b"\x00\x00\x00\x01\x00\x00\x00\x00":
                raise ValueError("Refusing to discard a nonempty DSIG signature.")
            tables.remove("DSIG")
        if old.sfntVersion != new.sfntVersion or tables != set(new.reader.tables):
            raise ValueError("Font type or table set changed.")
        for tag in tables:
            if normalized_table(tag, old.reader[tag]) != normalized_table(tag, new.reader[tag]):
                raise ValueError(f"Font table {tag} changed during conversion.")
        if old.getBestCmap() != new.getBestCmap() or old.getGlyphOrder() != new.getGlyphOrder():
            raise ValueError("Font character coverage or glyph order changed.")
        axes = [{"tag": axis.axisTag, "min": axis.minValue,
                 "default": axis.defaultValue, "max": axis.maxValue}
                for axis in old["fvar"].axes] if "fvar" in old else []
        return {
            "codepoints": len(old.getBestCmap()), "glyphs": old["maxp"].numGlyphs,
            "axes": axes, "all_rendering_tables_preserved": True,
            "omitted_empty_dsig": empty_dsig,
            "head_exceptions": ["checkSumAdjustment", "flags.bit11"],
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Regenerate exports and audit metadata")
    args = parser.parse_args()
    import brotli
    import fontTools
    from fontTools.ttLib.woff2 import compress

    if fontTools.__version__ != CONVERTER["fonttools"] or brotli.__version__ != CONVERTER["brotli"]:
        raise RuntimeError("Use the pinned project-local fonttools/Brotli versions in this tool's docstring.")
    records = json.loads((FONTS / "sources.json").read_text())
    for record in records:
        data = (FONTS / record["file"]).read_bytes()
        if fingerprint(data) != {key: record[key] for key in ("sha256", "bytes")}:
            raise ValueError(f"Source fingerprint mismatch: {record['file']}")
    total_source = total_export = 0
    outputs = []
    for record in records:
        if not record["file"].endswith(".ttf"):
            continue
        source = (FONTS / record["file"]).read_bytes()
        name = Path(record["file"]).with_suffix(".woff2").name
        if args.write:
            buffer = io.BytesIO()
            compress(io.BytesIO(source), buffer, transform_tables=set())
            exported = buffer.getvalue()
        else:
            exported = (FONTS / name).read_bytes()
        metadata = {"file": name, **fingerprint(exported),
                    "converter": CONVERTER, "audit": audit(source, exported)}
        if args.write:
            record["woff2"] = metadata
            outputs.append((FONTS / name, exported))
        elif record.get("woff2") != metadata:
            raise ValueError(f"Export fingerprint/audit metadata mismatch: {name}")
        total_source += len(source)
        total_export += len(exported)
        print(f"{name}: {len(source):,} -> {len(exported):,} bytes; "
              f"{metadata['audit']['codepoints']:,} codepoints, "
              f"{metadata['audit']['glyphs']:,} glyphs; all rendering tables preserved")
    if args.write:
        # Do not update committed files until every conversion passed its audit.
        for path, data in outputs:
            path.write_bytes(data)
        (FONTS / "sources.json").write_text(json.dumps(records, indent=2) + "\n")
    print(f"Total: {total_source:,} -> {total_export:,} bytes "
          f"({(1 - total_export / total_source) * 100:.1f}% smaller)")


if __name__ == "__main__":
    main()
