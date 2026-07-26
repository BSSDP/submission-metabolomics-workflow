#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Return the next figure prefix.")
    parser.add_argument("project_root", type=Path)
    args = parser.parse_args()
    figure_root = args.project_root.resolve() / "05_figures"
    numbers = []
    if figure_root.exists():
        for path in figure_root.rglob("*"):
            if path.is_file():
                match = re.match(r"^(\d+)_", path.name)
                if match:
                    numbers.append(int(match.group(1)))
    next_number = max(numbers, default=0) + 1
    print(f"{next_number:02d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

