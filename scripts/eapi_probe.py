"""Report which of the given EAPIs pkgcore has disabled, and why.

pkgcore refuses to enable an EAPI whose ``bash_compat`` exceeds the system bash
(``pkgcore/ebuild/eapi.py``) and files it under ``unknown_eapis`` instead. The
practical consequence is not a soft one: ``pmaint regen`` exits non-zero on any
ebuild using that EAPI, before pkgcheck runs at all, and the scan then reports
``InvalidEapi`` -- an error-level keyword in the GentooCI checkset -- against a
perfectly valid ebuild.

ubuntu-24.04 ships bash 5.2.21 and EAPI 9 wants 5.3, so this is reachable on
GitHub's current default runner. Prints machine-readable lines and always exits
0; the caller decides how loud to be.

    bash=<version>
    disabled=<eapi>:<required bash>      (zero or more, only for EAPIs in use)
"""

import sys

from pkgcore.ebuild.eapi import EAPI, bash_version


def main(argv: list[str]) -> int:
    used = set(argv)

    # Only EAPIs pkgcore knows about but gated on bash land in unknown_eapis
    # with a bash_compat set. An EAPI this pkgcore has simply never heard of
    # gets no bash_compat, and is a real QA problem rather than our problem.
    disabled = {
        magic: eapi.options.bash_compat
        for magic, eapi in EAPI.unknown_eapis.items()
        if getattr(eapi.options, "bash_compat", None)
    }

    print(f"bash={bash_version()}")
    for magic in sorted(used & set(disabled), key=lambda m: (len(m), m)):
        print(f"disabled={magic}:{disabled[magic]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
