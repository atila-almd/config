#!/usr/bin/env python3
"""Compose the common System Definition with an explicitly selected profile."""
import argparse
import pathlib
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("python-yaml (PyYAML) is required by the blendOS bootstrap")

ROOT = pathlib.Path(__file__).resolve().parent.parent


class UniqueLoader(yaml.SafeLoader):
    pass


def mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)


def load(path):
    value = yaml.load(path.read_text(), Loader=UniqueLoader)
    if not isinstance(value, dict):
        raise ValueError(f"expected a YAML mapping: {path}")
    return value


def compose(profile):
    if not re.fullmatch(r"[a-z][a-z0-9-]*", profile):
        raise ValueError("invalid Machine Profile name")
    path = ROOT / "profiles" / f"{profile}.yaml"
    if not path.is_file():
        raise ValueError(f"Machine Profile '{profile}' is not configured; hardware approval is required")
    fragment = load(path)
    if set(fragment) - {"profile", "ready", "hardware", "packages", "services", "user-services"}:
        raise ValueError("unsupported Machine Profile field")
    if fragment.get("profile") != profile or fragment.get("ready") is not True:
        raise ValueError("Machine Profile is not approved/ready")
    if not isinstance(fragment.get("hardware"), dict) or not fragment["hardware"]:
        raise ValueError("Machine Profile must describe its approved hardware")
    base = load(ROOT / "system.yaml")
    if base.get("track") != "custom" or "impl" in base:
        raise ValueError("expected this repository's custom blendOS v4 System Definition")
    for section in ("packages", "services", "user-services"):
        items = fragment.get(section, [])
        if not isinstance(items, list) or any(not isinstance(x, str) or not re.fullmatch(r"[A-Za-z0-9@_.+-]+", x) for x in items):
            raise ValueError(f"invalid profile {section}")
        original = base.get(section, [])
        if not isinstance(original, list):
            raise ValueError(f"invalid common {section}")
        base[section] = list(dict.fromkeys(original + items))
    return base


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile")
    args = parser.parse_args()
    try:
        value = compose(args.profile)
    except (OSError, ValueError, yaml.YAMLError) as error:
        sys.exit(str(error))
    print(f"# Generated Local State: system.yaml + profiles/{args.profile}.yaml")
    print(yaml.safe_dump(value, sort_keys=False), end="")


if __name__ == "__main__":
    main()
