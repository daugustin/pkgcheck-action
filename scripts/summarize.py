"""Count JsonStream results by severity.

Severity is read off the installed pkgcheck (``objects.KEYWORDS[name].level``)
rather than from a table in this repo, so it cannot drift from the pinned
version. Note that severity is independent of what fails the build: the
``--exit`` checkset decides that, and ``BadWhitespaceCharacter`` is warning-level
yet in ``GentooCI``. Do not derive one from the other.

Prints ``<level>=<count>`` lines plus ``total=<count>``.
"""

import json
import sys
from collections import Counter

from pkgcheck import objects

LEVELS = ("error", "warning", "info", "style")


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(f"usage: {sys.argv[0]} <results.jsonl>", file=sys.stderr)
        return 2

    counts: Counter[str] = Counter()
    total = 0
    with open(argv[0]) as f:
        for line in f:
            if not line.strip():
                continue
            keyword = json.loads(line)["__class__"]
            level = getattr(objects.KEYWORDS.get(keyword), "level", None)
            counts[level or "unknown"] += 1
            total += 1

    for level in LEVELS:
        print(f"{level}={counts[level]}")
    if unknown := counts["unknown"]:
        # Only reachable if the JSON was produced by a different pkgcheck than
        # the one installed here, which the version pin exists to prevent.
        print(f"unknown={unknown}")
    print(f"total={total}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
