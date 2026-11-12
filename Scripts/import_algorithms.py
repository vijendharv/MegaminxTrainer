#!/usr/bin/env python3
"""Import case notes from an XLSX export, without copying the Info tab's excluded sections.

Usage: python3 Scripts/import_algorithms.py /path/to/export.xlsx
The workbook is read only; bundled case IDs, setups, and resource names stay stable.
"""
import argparse
import json
from pathlib import Path
import re
from xml.etree import ElementTree as ET
from zipfile import ZipFile

NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
ROOT = Path(__file__).resolve().parents[1] / "MegaminxTrainer" / "Resources"


def read_cells(archive, sheet, strings):
    cells = {}
    for cell in ET.fromstring(archive.read(f"xl/worksheets/sheet{sheet}.xml")).findall(".//s:c", NS):
        value = cell.find("s:v", NS)
        if value is not None and value.text is not None:
            cells[cell.attrib["r"]] = strings[int(value.text)] if cell.attrib.get("t") == "s" else value.text
    return cells


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path)
    args = parser.parse_args()
    outputs = []
    with ZipFile(args.workbook) as archive:
        strings = ["".join(node.itertext()) for node in ET.fromstring(archive.read("xl/sharedStrings.xml"))]
        for sheet, filename, expected in [(2, "cases.json", 178), (3, "pll-cases.json", 151)]:
            cells = read_cells(archive, sheet, strings)
            notes = {}
            for comment in ET.fromstring(archive.read(f"xl/comments{sheet - 1}.xml")).findall(".//s:comment", NS):
                column, row = re.fullmatch(r"([A-Z]+)(\d+)", comment.attrib["ref"]).groups()
                name = cells.get(f"{column}{int(row) + 1}")
                algorithms = [line.strip() for line in "".join(comment.find("s:text", NS).itertext()).splitlines() if line.strip()]
                if not name or name in notes or not algorithms:
                    raise ValueError(f"Ambiguous note mapping at {comment.attrib['ref']}")
                notes[name] = algorithms
            if len(notes) != expected:
                raise ValueError(f"Expected {expected} case notes, found {len(notes)}")
            descriptions = [value for key, value in cells.items() if re.fullmatch(r"[A-Z]+3", key)]
            if len(descriptions) != (37 if sheet == 2 else 26):
                raise ValueError("Unexpected number of group descriptions")
            cases = json.loads((ROOT / filename).read_text())
            used = set()
            for case in cases:
                # The source trainer's Q1A is Q1+ in the workbook. Its three
                # algorithms match the trainer entry exactly; preserve ID 90.
                if sheet == 3 and case["id"] == 90:
                    if case["name"] not in ("Q1A", "Q1+"):
                        raise ValueError("Unexpected name for PLL case 90")
                    case["name"] = "Q1+"
                case["groupDescription"] = descriptions[case["group"] - 1].strip()
                if not case["setup"]:  # PLL skip has no algorithm note.
                    case["algorithms"] = []
                    continue
                case["algorithms"] = notes[case["name"]]
                used.add(case["name"])
            if used != set(notes):
                raise ValueError(f"Unmapped notes: {set(notes) - used}")
            outputs.append((filename, cases))
    # Write only after both catalogs have been fully mapped.
    for filename, cases in outputs:
        (ROOT / filename).write_text(json.dumps(cases, indent=2, ensure_ascii=False) + "\n")
        print(f"{filename}: {len(cases)} cases, {sum(len(c['algorithms']) for c in cases)} algorithms")


if __name__ == "__main__":
    main()
