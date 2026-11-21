"""Verify Algorithms-only images remain paired with the original sheet notes."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "MegaminxTrainer" / "Resources"
for mode, count, algorithm_count in [("OLL", 178, 302), ("PLL", 152, 239)]:
    folder = root / "AlgorithmDiagrams" / mode
    records = json.loads((folder / "catalog.json").read_text())
    assert len(records) == count
    assert len({c["id"] for c in records}) == count
    assert len({c["sheetCell"] for c in records}) == count
    assert sum(len(c["algorithms"]) for c in records) == algorithm_count
    for case in records:
        image = (folder / f"{case['id']}.png").read_bytes()
        assert image.startswith(b"\x89PNG\r\n\x1a\n")
        assert hashlib.sha256(image).hexdigest() == case["imageSHA256"], case["name"]
        assert case["groupDescription"]
        assert case["algorithms"] or (mode == "PLL" and case["name"] == "Skip")
    if mode == "OLL":
        four_b = next(c for c in records if c["name"] == "4B")
        assert four_b["sheetCell"] == "H7"
        assert four_b["algorithms"][1].startswith("y2' ")
        assert four_b["algorithms"][2].startswith("y' ")
        # These two case patterns differ from the trainer images. They must use
        # the sheet-specific files in Algorithms, not fall back to the trainer.
        for name in ["4E+", "11B-"]:
            case = next(c for c in records if c["name"] == name)
            trainer_image = (root / "Cases" / f"{case['id']}.png").read_bytes()
            assert hashlib.sha256(trainer_image).hexdigest() != case["imageSHA256"]
print("Passed: 330 reference images, 541 paired algorithms, cell mapping, image hashes, rotation preservation, distinct trainer assets")
