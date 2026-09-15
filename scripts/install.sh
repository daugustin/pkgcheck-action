#!/usr/bin/env bash
#
# Install pkgcheck into a venv and sync the gentoo repo.
#
# Inputs (env):
#   INPUT_PKGCHECK_VERSION  exact version to pin, or empty for "whatever pip resolves"

# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

spec=pkgcheck
if [[ -n ${INPUT_PKGCHECK_VERSION:-} ]]; then
	spec="pkgcheck==$INPUT_PKGCHECK_VERSION"
fi

group "Installing $spec"
python3 -m venv "$PKGCHECK_VENV"
"$PKGCHECK_VENV/bin/pip" install --disable-pip-version-check --quiet "$spec"
# stderr stays separate: pkgcore logs warnings there, and merging them captures
# a warning line instead of the version.
version=$("$(pkgcheck_bin)" --version 2>/dev/null)
echo "$version"
endgroup

echo "PKGCHECK_VENV=$PKGCHECK_VENV" >>"$GITHUB_ENV"
set_output version "$version"

# No repos.conf is written on purpose -- see the comment on PKGCHECK_VENV in
# lib.sh. pkgcore's bundled stub config already points `gentoo` at
# ~/.cache/pkgcore/repos/gentoo with a tarball sync-uri, and a config dir of our
# own would additionally need a resolvable make.profile, which cannot exist
# before the tree it would point into has been synced.
group "Syncing gentoo repo"
"$(pmaint_bin)" sync gentoo
endgroup
