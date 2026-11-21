#!/usr/bin/env python3
"""Build the Algorithms-only catalog from matching sheet images and cell notes.

Usage: python3 Scripts/import_algorithm_reference.py WORKBOOK OLL_HTML PLL_HTML IMAGE_FOLDER
IMAGE_FOLDER contains original PNGs in OLL/<case-id>.png and PLL/<case-id>.png.
The PLL skip is the sheet's group O overview image (AD4), saved as PLL/81.png.
Trainer catalogs, setups, images, and saved progress are never written.
"""
from html.parser import HTMLParser
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile
import argparse
import hashlib
import json
import re
import shutil
from import_algorithms import read_cells, NS, ROOT

class SheetHTML(HTMLParser):
    """Recover cell coordinates, accounting for merged rows and columns."""

    def __init__(self):
        super().__init__()
        self.rows = []
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = {"tag": tag, "attrs": dict(attrs), "text": "", "images": []}
        elif tag == "img" and self.cell is not None:
            self.cell["images"].append(dict(attrs)["src"])

    def handle_data(self, text):
        if self.cell is not None:
            self.cell["text"] += text

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None:
            self.row.append(self.cell)
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None

    def grid(self):
        grid = {}
        for row in self.rows:
            if not row or not row[0]["text"].isdigit():
                continue
            row_number = int(row[0]["text"])
            column = 1
            for cell in row[1:]:
                while (row_number, column) in grid:
                    column += 1
                width = int(cell["attrs"].get("colspan", 1))
                height = int(cell["attrs"].get("rowspan", 1))
                for r in range(row_number, row_number + height):
                    for c in range(column, column + width):
                        grid[(r, c)] = cell
                column += width
        return grid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path)
    parser.add_argument("oll_html", type=Path)
    parser.add_argument("pll_html", type=Path)
    parser.add_argument("images", type=Path)
    args = parser.parse_args()
    prepared = []
    with ZipFile(args.workbook) as archive:
        strings = ["".join(node.itertext()) for node in ET.fromstring(archive.read("xl/sharedStrings.xml"))]
        for mode, index, html_file, filename, expected in [
            ("OLL", 2, args.oll_html, "cases.json", 178),
            ("PLL", 3, args.pll_html, "pll-cases.json", 151),
        ]:
            html = SheetHTML()
            html.feed(html_file.read_text())
            grid = html.grid()
            cells = read_cells(archive, index, strings)
            original = {c["name"]: c for c in json.loads((ROOT / filename).read_text())}
            records = []
            for comment in ET.fromstring(archive.read(f"xl/comments{index - 1}.xml")).findall(".//s:comment", NS):
                coordinate = comment.attrib["ref"]
                column, row = re.fullmatch(r"([A-Z]+)(\d+)", coordinate).groups()
                number = 0
                for char in column:
                    number = number * 26 + ord(char) - 64
                row = int(row)
                name = cells[f"{column}{row + 1}"]
                assert grid[(row + 1, number)]["text"] == name, f"HTML/workbook label mismatch: {name}"
                assert len(grid[(row, number)]["images"]) == 1, f"Missing diagram: {name}"
                algorithms = [line.strip() for line in "".join(comment.find("s:text", NS).itertext()).splitlines() if line.strip()]
                item = dict(original[name])
                item["algorithms"] = algorithms
                item["sheetCell"] = coordinate
                records.append(item)
            assert len(records) == expected
            if mode == "PLL":
                assert grid[(3, 30)]["text"] == "Skip!" and len(grid[(4, 30)]["images"]) == 1
                skip = dict(original["solved"])
                skip.update(name="Skip", algorithms=[], sheetCell="AD4")
                records.append(skip)
            for item in records:
                image = args.images / mode / f"{item['id']}.png"
                data = image.read_bytes()
                assert data.startswith(b"\x89PNG\r\n\x1a\n"), image
                item["imageSHA256"] = hashlib.sha256(data).hexdigest()
            records.sort(key=lambda c: c["id"])
            assert len({c["id"] for c in records}) == len(records)
            prepared.append((mode, records))
    # Validate the complete mapping before writing any reference resources.
    for mode, records in prepared:
        output = ROOT / "AlgorithmDiagrams" / mode
        output.mkdir(parents=True, exist_ok=True)
        for item in records:
            shutil.copyfile(args.images / mode / f"{item['id']}.png", output / f"{item['id']}.png")
        (output / "catalog.json").write_text(json.dumps(records, indent=2, ensure_ascii=False) + "\n")
        print(f"{mode}: {len(records)} matched image/note records")


if __name__ == "__main__":
    main()
