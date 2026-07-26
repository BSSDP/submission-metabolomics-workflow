#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


REQUIRED_DIRS = [
    "00_project_docs",
    "00_project_management",
    "00_raw_data",
    "02_metadata",
    "03_processed_data",
    "04_analysis",
    "05_figures/unassigned",
    "05_figures/figure_source_data",
    "06_tables",
    "07_manuscript",
    "08_code/configs",
    "08_code/pipelines",
    "09_logs",
    "10_archive",
    "ref",
]
REQUIRED_FILES = [
    "00_project_management/PROJECT_RULES.md",
    "00_project_management/MANUSCRIPT_STORYLINE.md",
    "00_project_management/ANALYSIS_REGISTRY.tsv",
    "00_project_management/RESULT_LEDGER.tsv",
    "00_project_management/FIGURE_MAP.tsv",
    "00_project_management/TABLE_MAP.tsv",
    "00_project_management/METHODS_LEDGER.md",
    "00_project_management/CHANGELOG.md",
    "00_project_management/DECISION_LOG.md",
    "00_project_management/REVIEWER_RISK_LEDGER.md",
    "00_project_management/PROFILE_SELECTION.md",
    "02_metadata/input_manifest.tsv",
    "02_metadata/cohort_registry.tsv",
    "02_metadata/contrast_plan.tsv",
    "02_metadata/clinical_variable_dictionary.tsv",
    "08_code/configs/project.yml",
    "08_code/configs/color_palette.yml",
    "08_code/configs/figure_style.yml",
]
PROFILE_VALUES = {
    "untargeted_dual_ion",
    "untargeted_single_assay",
    "targeted_panel",
    "hybrid_discovery_targeted",
    "external_results_only",
}


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.exists() or path.stat().st_size == 0:
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def has_section(text: str, name: str) -> bool:
    return bool(re.search(rf"(?m)^{re.escape(name)}:\s*$", text))


def is_relative_project_path(value: str) -> bool:
    return bool(value) and not Path(value).is_absolute() and not re.match(
        r"^[A-Za-z]:[\\/]", value
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a metabolomics project.")
    parser.add_argument("project_root", type=Path)
    parser.add_argument(
        "--stage",
        choices=("scaffold", "ready", "submission"),
        default="ready",
        help="scaffold checks structure; ready checks input registration; submission checks formal outputs.",
    )
    args = parser.parse_args()
    root = args.project_root.resolve()
    errors: list[str] = []
    warnings: list[str] = []

    for relative in REQUIRED_DIRS:
        if not (root / relative).is_dir():
            errors.append(f"Missing directory: {relative}")
    for relative in REQUIRED_FILES:
        if not (root / relative).is_file():
            errors.append(f"Missing file: {relative}")

    config_path = root / "08_code" / "configs" / "project.yml"
    config_text = ""
    if config_path.exists():
        config_text = config_path.read_text(encoding="utf-8")
        for section in ["project", "inputs", "clinical", "design", "preprocessing", "differential", "modeling"]:
            if not has_section(config_text, section):
                errors.append(f"project.yml lacks section: {section}")
        profile = re.search(r'(?m)^  analysis_profile:\s*["\']?([^"\'\s#]+)', config_text)
        if not profile or profile.group(1) not in PROFILE_VALUES:
            errors.append("project.yml has an invalid project.analysis_profile")
        if "__" in config_text:
            errors.append("project.yml still contains an unreplaced template token")
        absolute_paths = re.findall(r'(?m)^\s*[^#\n]+:\s*["\']?([A-Za-z]:[\\/][^"\'\n#]+)', config_text)
        if absolute_paths:
            errors.append("project.yml contains absolute path(s): " + ", ".join(absolute_paths[:3]))

    manifest = root / "02_metadata" / "input_manifest.tsv"
    manifest_rows = read_tsv(manifest)
    if manifest.exists() and not manifest_rows:
        errors.append("input_manifest.tsv has no registered inputs")
    for row in manifest_rows:
        value = row.get("file_path", "").strip()
        if not is_relative_project_path(value):
            errors.append(f"Input manifest has missing/absolute path: {value or '<blank>'}")
            continue
        if args.stage in {"ready", "submission"} and not (root / value).is_file():
            warnings.append(f"Registered input is not present yet: {value}")

    contrast_rows = read_tsv(root / "02_metadata" / "contrast_plan.tsv")
    active_contrasts = [row for row in contrast_rows if row.get("status", "").lower() not in {"", "configure", "planned"}]
    if args.stage in {"ready", "submission"} and not active_contrasts:
        warnings.append("No active contrast is registered in contrast_plan.tsv")

    analysis_root = root / "04_analysis"
    if analysis_root.exists():
        for script in list(analysis_root.rglob("*.R")) + list(analysis_root.rglob("*.py")):
            card = script.parent / "ANALYSIS_CARD.md"
            if not card.exists():
                warnings.append(f"Analysis script lacks ANALYSIS_CARD.md: {script.relative_to(root)}")

    figure_map = root / "00_project_management" / "FIGURE_MAP.tsv"
    rows = read_tsv(figure_map)
    figure_ids = [row.get("figure_id", "") for row in rows if row.get("figure_id")]
    duplicates = sorted({x for x in figure_ids if figure_ids.count(x) > 1})
    if duplicates:
        errors.append("Duplicate figure_id values: " + ", ".join(duplicates))
    if args.stage == "submission":
        for row in rows:
            if row.get("status") != "done":
                continue
            for field in ["source_data_file", "output_pdf", "output_svg", "output_png"]:
                value = row.get(field, "")
                if not value or value == "NA" or not (root / value).is_file():
                    errors.append(f"Done figure {row.get('figure_id')} lacks {field}: {value}")

    prefix_to_stems: dict[str, set[str]] = {}
    figure_dir = root / "05_figures"
    if figure_dir.exists():
        for path in figure_dir.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".pdf", ".svg", ".png", ".tiff", ".tif"}:
                continue
            match = re.match(r"^(\d+)_", path.name)
            if not match:
                warnings.append(f"Figure lacks numeric prefix: {path.relative_to(root)}")
                continue
            stem = re.sub(r"\.(pdf|svg|png|tiff|tif)$", "", path.name, flags=re.I)
            prefix_to_stems.setdefault(match.group(1), set()).add(stem)
        reused = [prefix for prefix, stems in prefix_to_stems.items() if len(stems) > 1]
        if reused:
            errors.append("Numeric prefixes reused by different figures: " + ", ".join(reused))

    raw_root = root / "00_raw_data"
    if raw_root.exists():
        forbidden = [
            path for path in raw_root.rglob("*")
            if path.is_file() and (path.name.endswith(("_source.tsv", "_result.tsv", "_model.joblib")) or path.suffix.lower() in {".pdf", ".svg", ".tiff"})
        ]
        if forbidden:
            errors.append("Generated-looking files found under raw data: " + "; ".join(str(path.relative_to(root)) for path in forbidden[:10]))

    print(f"Project: {root}")
    print(f"Stage: {args.stage}")
    for item in warnings:
        print(f"WARNING: {item}")
    for item in errors:
        print(f"ERROR: {item}")
    if errors:
        print(f"Validation failed with {len(errors)} error(s).")
        return 1
    print(f"Validation passed with {len(warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
