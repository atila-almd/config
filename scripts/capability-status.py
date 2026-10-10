#!/usr/bin/env python3
"""Validate Component Contract evidence and render the README status tables."""
import argparse
import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIELDS = ["capability", "package", "executable", "integration", "workflows", "profiles",
          "vm_status", "physical_status", "notes", "adaptation", "justification", "evidence"]
STATUSES = {"Planned", "Installed", "Integrated", "Blocked"}


def contracts():
    text = (ROOT / "components.tsv").read_text()
    rows = list(csv.reader((line for line in text.splitlines() if line and not line.startswith("#")), delimiter="\t"))
    seen = set()
    result = []
    for values in rows:
        if len(values) != len(FIELDS) or any(not x.strip() for x in values):
            raise ValueError("component rows need all 12 contract/status fields (use '-' for unused values)")
        row = dict(zip(FIELDS, values))
        if row["capability"] in seen:
            raise ValueError(f"duplicate capability: {row['capability']}")
        seen.add(row["capability"])
        if row["profiles"] not in {"all", "vm", "physical"}:
            raise ValueError(f"invalid profile scope: {row['capability']}")
        if any(row[x] not in STATUSES for x in ["vm_status", "physical_status"]):
            raise ValueError(f"invalid evidence status: {row['capability']}")
        if row["integration"].startswith("deferred:") and any(row[x] != "Blocked" for x in ["vm_status", "physical_status"]):
            raise ValueError(f"deferred integration must remain Blocked: {row['capability']}")
        if row["adaptation"] not in {"Configuration", "Composition", "Compatibility Shim", "Project Fork"}:
            raise ValueError(f"invalid adaptation: {row['capability']}")
        if row["adaptation"] in {"Compatibility Shim", "Project Fork"} and row["justification"] == "-":
            raise ValueError(f"adaptation needs a justification: {row['capability']}")
        evidence = row["evidence"].split("#", 1)[0]
        if not (ROOT / evidence).is_file():
            raise ValueError(f"missing evidence document: {row['capability']}")
        result.append(row)
    return result


def cell(value):
    return value.replace("|", "\\|").replace("\n", " ")


def table(rows, profile):
    lines = ["| Capability | Workflow(s) | Component | Integration Point | Status | Notes |",
             "| --- | --- | --- | --- | --- | --- |"]
    for row in rows:
        if row["profiles"] not in {"all", profile}:
            continue
        notes = row["notes"]
        if profile == "physical" and row["physical_status"] != "Integrated":
            notes += "; unverified on hardware"
        if row["adaptation"] in {"Compatibility Shim", "Project Fork"}:
            notes += f"; **{row['adaptation']}**: {row['justification']}"
        notes += f"; [evidence]({row['evidence']})"
        values = [row["capability"], row["workflows"], f"{row['package']} → {row['executable']}",
                  row["integration"], row[f"{profile}_status"], notes]
        lines.append("| " + " | ".join(cell(x) for x in values) + " |")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="regenerate both README tables")
    mode.add_argument("--check", action="store_true", help="reject stale README tables")
    parser.add_argument("--profile", choices=["vm", "physical"], default="physical")
    args = parser.parse_args()
    try:
        rows = contracts()
        if args.write or args.check:
            path = ROOT / "README.md"
            original = path.read_text()
            output = original
            for profile in ["physical", "vm"]:
                start = f"<!-- capabilities:{profile}:start -->"
                end = f"<!-- capabilities:{profile}:end -->"
                if output.count(start) != 1 or output.count(end) != 1:
                    raise ValueError(f"missing or duplicate README markers for {profile}")
                output = re.sub(re.escape(start) + r"[\s\S]*?" + re.escape(end),
                                lambda match: start + "\n" + table(rows, profile) + "\n" + end, output)
            if args.write:
                if output != original:
                    path.write_text(output)
            elif output != original:
                raise ValueError("README capability status is stale; run python3 scripts/capability-status.py --write")
            print(f"Capability status valid: {len(rows)} Component Contracts")
        else:
            print(table(rows, args.profile))
    except (OSError, ValueError) as error:
        sys.exit(str(error))


if __name__ == "__main__":
    main()
