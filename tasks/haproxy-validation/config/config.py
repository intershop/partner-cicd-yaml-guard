#!/usr/bin/env python3
import argparse
import ipaddress
import os
import re
import sys
from pathlib import Path


USERLIST = re.compile(r"^userlist \S+$")
USER = re.compile(r"^  user \S+ password (?P<hash>\S+) groups authenticated-users$")
HASHES = (
    re.compile(r"^\$2[aby]\$(0[4-9]|[12][0-9]|3[01])\$[./A-Za-z0-9]{53}$"),
    re.compile(r"^\$5\$(rounds=[1-9][0-9]{3,8}\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{43}$"),
    re.compile(r"^\$6\$(rounds=[1-9][0-9]{3,8}\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}$"),
)


def find_files(root: Path) -> tuple[list[Path], list[Path], list[Path]]:
    excluded = {".git", ".local", ".vscode"}
    ip_files = list(root.glob("**/acls/ip*.txt"))
    ip_files += list((root / "clusters" / "global-acls").glob("ip*.txt"))
    ip_files.append(root / "clusters" / "global-acls" / "global-block-list.txt")
    aux_files, cfg_files = [], []

    for directory, subdirs, names in os.walk(root):
        subdirs[:] = [name for name in subdirs if name not in excluded]
        for name in names:
            path = Path(directory) / name
            if path.suffix == ".cfg":
                cfg_files.append(path)
                if name == "haproxy-aux.cfg":
                    aux_files.append(path)

    ip_files = {
        path
        for path in ip_files
        if path.is_file()
        and not excluded.intersection(path.relative_to(root).parts)
    }
    return sorted(ip_files), sorted(aux_files), sorted(cfg_files)


def validate_ip_file(path: Path) -> list[str]:
    errors = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line != line.strip():
            errors.append(f"{path}:{number}: Leading or trailing whitespace.")
        elif not line:
            continue
        elif line.startswith("#"):
            if line != "#" and not line.startswith("# "):
                errors.append(f"{path}:{number}: Comment must start with '# '.")
        else:
            try:
                ipaddress.ip_network(line, strict=False)
            except ValueError:
                errors.append(f"{path}:{number}: Invalid IP address or subnet '{line}'.")
    return errors


def validate_aux_file(path: Path) -> list[str]:
    data = path.read_bytes()
    if not data:
        return []

    errors = [] if data.endswith(b"\n") else [f"{path}: File must end with a newline."]
    lines = data.decode("utf-8").splitlines()
    state, has_user = "userlist", False

    for number, line in enumerate(lines, 1):
        if not line:
            continue
        if line.startswith("#"):
            if line != "#" and not line.startswith("# "):
                errors.append(f"{path}:{number}: Comment must start with '# '.")
            continue
        if state == "userlist":
            if USERLIST.fullmatch(line):
                state, has_user = "group", False
            else:
                errors.append(f"{path}:{number}: Expected 'userlist <name>'.")
        elif state == "group":
            if line == "  group authenticated-users":
                state = "users"
            else:
                errors.append(f"{path}:{number}: Expected '  group authenticated-users'.")
        else:
            match = USER.fullmatch(line)
            if match:
                if any(pattern.fullmatch(match["hash"]) for pattern in HASHES):
                    has_user = True
                else:
                    errors.append(f"{path}:{number}: Invalid password hash.")
            elif USERLIST.fullmatch(line):
                if not has_user:
                    errors.append(f"{path}:{number}: Previous userlist has no users.")
                state, has_user = "group", False
            else:
                errors.append(f"{path}:{number}: Invalid user entry.")

    if state == "group":
        errors.append(f"{path}: Last userlist is missing its group.")
    elif state == "users" and not has_user:
        errors.append(f"{path}: Last userlist must contain a user.")
    return errors


def validate_cfg_newline(path: Path) -> list[str]:
    if path.stat().st_size and not path.read_bytes().endswith(b"\n"):
        return [f"{path}: File must end with a newline."]
    return []


def show_checked_files(label: str, paths: list[Path], root: Path) -> None:
    print(f"{label} ({len(paths)} checked):")
    for path in paths:
        print(f"  {path.relative_to(root).as_posix()}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate HAProxy files.")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    ip_files, aux_files, cfg_files = find_files(root)
    errors = []
    for path in ip_files:
        errors.extend(validate_ip_file(path))
    for path in aux_files:
        errors.extend(validate_aux_file(path))
    for path in cfg_files:
        errors.extend(validate_cfg_newline(path))

    show_checked_files("IP allowlists", ip_files, root)
    show_checked_files("haproxy-aux.cfg files", aux_files, root)
    show_checked_files(
        "Other .cfg files", [p for p in cfg_files if p not in aux_files], root
    )

    if errors:
        print("HAProxy validation failed:\n  - " + "\n  - ".join(errors))
        return 1
    print("HAProxy validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
