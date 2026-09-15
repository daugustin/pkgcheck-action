# shellcheck shell=bash
#
# Shared helpers. Sourced by the action's step scripts; not executable.

set -euo pipefail

# Where the action installs pkgcheck. The location is load-bearing rather than
# arbitrary: pkgcore locates its portage config by walking up from sys.prefix
# looking for etc/portage, with no PORTAGE_CONFIGROOT to override it. Under
# $RUNNER_TOOL_CACHE or a venv outside $HOME, that walk reaches only
# /etc/portage, which does not exist on a runner, so pkgcore falls back to its
# bundled stub config. That fallback is exactly what we want -- it already
# defines a `gentoo` repo synced from a tarball -- so the action deliberately
# does NOT write a repos.conf of its own.
PKGCHECK_VENV=${PKGCHECK_VENV:-$HOME/.pkgcheck-action/venv}

pkgcheck_bin() { echo "$PKGCHECK_VENV/bin/pkgcheck"; }
pmaint_bin() { echo "$PKGCHECK_VENV/bin/pmaint"; }
python_bin() { echo "$PKGCHECK_VENV/bin/python"; }

group() { echo "::group::$*"; }
endgroup() { echo "::endgroup::"; }
notice() { echo "::notice::$*"; }
warn() { echo "::warning::$*"; }
fail() { echo "::error::$*"; }

# set_output <name> <value> — single-line values only.
set_output() { echo "$1=$2" >>"${GITHUB_OUTPUT:-/dev/stdout}"; }

# Resolve the directory the action was checked out to, so scripts can find
# their siblings whether invoked by the action or by the self-test.
action_dir() {
	echo "${GITHUB_ACTION_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
}
