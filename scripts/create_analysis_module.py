#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from datetime import date
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a traceable metabolomics analysis module.")
    parser.add_argument("project_root", type=Path)
    parser.add_argument("analysis_id", help="For example M09")
    parser.add_argument("module_name", help="Short underscore-separated name")
    parser.add_argument("--result-folder", default="R99_exploratory_or_extension")
    parser.add_argument("--language", choices=("R", "python"), default="R")
    args = parser.parse_args()

    root = args.project_root.resolve()
    if not (root / "00_project_management" / "ANALYSIS_CARD_TEMPLATE.md").is_file():
        raise SystemExit("Not a valid workflow project: analysis-card template missing.")
    safe_name = args.module_name.strip().replace(" ", "_")
    if not safe_name.replace("_", "").isalnum():
        raise SystemExit("module_name may contain letters, numbers, underscores, and spaces only.")
    module = root / "04_analysis" / args.result_folder / f"{args.analysis_id}_{safe_name}"
    if module.exists():
        raise SystemExit(f"Module already exists: {module}")
    for folder in (module, module / "outputs", module / "source_data", module / "figures", module / "logs"):
        folder.mkdir(parents=True, exist_ok=True)
    card = root / "00_project_management" / "ANALYSIS_CARD_TEMPLATE.md"
    shutil.copy2(card, module / "ANALYSIS_CARD.md")
    suffix = "R" if args.language == "R" else "py"
    script = module / f"{args.analysis_id}_{safe_name}_v001.{suffix}"
    if args.language == "R":
        script.write_text("#!/usr/bin/env Rscript\n\n# Register parameters and inputs in ANALYSIS_CARD.md before implementation.\n", encoding="utf-8")
    else:
        script.write_text("#!/usr/bin/env python3\n\n# Register parameters and inputs in ANALYSIS_CARD.md before implementation.\n", encoding="utf-8")
    registry = root / "00_project_management" / "ANALYSIS_REGISTRY.tsv"
    with registry.open("a", encoding="utf-8", newline="") as handle:
        handle.write(f"{args.analysis_id}\t{date.today().isoformat()}\tplanned\t\t\t\t\t\t{module.relative_to(root).as_posix()}\t\t\t\t\tproject_owner\tpending\n")
    print(f"Created analysis module: {module}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
