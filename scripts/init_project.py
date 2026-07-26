#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from pathlib import Path


PROFILES = (
    "untargeted_dual_ion",
    "untargeted_single_assay",
    "targeted_panel",
    "hybrid_discovery_targeted",
    "external_results_only",
)
DESIGNS = (
    "case_control",
    "multigroup",
    "ordinal_group",
    "paired_or_longitudinal",
    "diagnostic",
    "prognostic",
)


def replace_template_tokens(destination: Path, project_name: str, profile: str, design: str) -> None:
    replacements = {
        "__PROJECT_NAME__": project_name,
        "__ANALYSIS_PROFILE__": profile,
        "__STUDY_DESIGN__": design,
    }
    for path in destination.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".md", ".tsv", ".yml", ".yaml"}:
            continue
        text = path.read_text(encoding="utf-8")
        for token, value in replacements.items():
            text = text.replace(token, value)
        path.write_text(text, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Initialize a portable publication-oriented metabolomics project."
    )
    parser.add_argument("project_root", type=Path)
    parser.add_argument("--profile", choices=PROFILES, default="untargeted_dual_ion")
    parser.add_argument("--design", choices=DESIGNS, default="case_control")
    parser.add_argument("--project-name", default="metabolomics_project")
    parser.add_argument(
        "--force-empty",
        action="store_true",
        help="Allow an existing empty destination directory.",
    )
    args = parser.parse_args()

    skill_root = Path(__file__).resolve().parents[1]
    template = skill_root / "assets" / "project_template"
    destination = args.project_root.resolve()
    if not template.is_dir():
        raise SystemExit(f"Template is missing: {template}")
    if destination.exists():
        entries = list(destination.iterdir())
        if entries or not args.force_empty:
            raise SystemExit(
                "Destination exists. Use a new path, or --force-empty for an "
                "existing empty directory."
            )
    else:
        destination.mkdir(parents=True)

    for source in template.rglob("*"):
        target = destination / source.relative_to(template)
        if source.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

    replace_template_tokens(destination, args.project_name, args.profile, args.design)
    selection = destination / "00_project_management" / "PROFILE_SELECTION.md"
    selection.write_text(
        "# Project profile selection\n\n"
        f"- Project: `{args.project_name}`\n"
        f"- Analysis profile: `{args.profile}`\n"
        f"- Study design: `{args.design}`\n\n"
        "This selection defines the starting contract only. Configure the input "
        "manifest, cohorts, contrasts, adjustment plan, and eligible modules "
        "before analysis. The bundled `run_all.R` is a dual-ion untargeted "
        "baseline and must be adapted for other profiles.\n",
        encoding="utf-8",
    )
    print(f"Initialized project: {destination}")
    print(f"Profile: {args.profile}; design: {args.design}")
    print("Next: register raw inputs and configure project.yml before running modules.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
