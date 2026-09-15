#!/usr/bin/env bash
#
# Refuse to scan an overlay whose EAPIs the runner's bash is too old to support,
# and say so in terms of bash rather than letting `pmaint regen` exit 1 with
# "EAPI '9' is not supported" and no hint as to why.
#
# Inputs (env):
#   INPUT_ON_UNSUPPORTED_EAPI  error | warn | ignore

# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

on_unsupported=${INPUT_ON_UNSUPPORTED_EAPI:-error}

# EAPI assignments as they actually appear in ebuilds: bare, double- or
# single-quoted. `|| true` because grep exits 1 on no match, which is a valid
# state (an overlay with no ebuilds yet) rather than an error.
mapfile -t used < <(
	grep -rhoE '^EAPI=[^[:space:]#]*' --include='*.ebuild' . 2>/dev/null |
		sed -e 's/^EAPI=//' -e 's/["'"'"']//g' |
		sort -u || true
)

if ((${#used[@]} == 0)); then
	echo "no ebuilds found; skipping EAPI preflight"
	exit 0
fi
echo "EAPIs in use: ${used[*]}"

probe_rc=0
probe=$("$(python_bin)" "$(action_dir)/scripts/eapi_probe.py" "${used[@]}") || probe_rc=$?
bash_ver=$(sed -n 's/^bash=//p' <<<"$probe")

# The probe failing is a bug in the action, not a finding about the repo. Say
# which, rather than exiting with python's status and no explanation.
if ((probe_rc != 0)) || [[ -z $bash_ver ]]; then
	fail "EAPI preflight probe failed (exit $probe_rc); this is a bug in pkgcheck-action"
	exit 1
fi
mapfile -t disabled < <(sed -n 's/^disabled=//p' <<<"$probe")

if ((${#disabled[@]} == 0)); then
	echo "all EAPIs in use are supported by pkgcore on bash $bash_ver"
	exit 0
fi

# Name the offending ebuilds. Being told "EAPI 9 is unsupported" is much less
# useful than being told which files that means.
for entry in "${disabled[@]}"; do
	eapi=${entry%%:*}
	needs=${entry#*:}

	echo
	echo "EAPI $eapi requires bash >= $needs; this runner has bash $bash_ver."
	echo "pkgcore disables the EAPI entirely in that case, so 'pmaint regen'"
	echo "fails on these ebuilds and the scan reports InvalidEapi against them:"
	grep -rlE "^EAPI=[\"']?${eapi}[\"']?[[:space:]]*\$" --include='*.ebuild' . 2>/dev/null |
		sed 's|^\./|  |' | head -20 || true
	echo
	echo "Fix by running on a host with a new enough bash -- ubuntu-26.04 ships"
	echo "bash 5.3 and works -- or set on-unsupported-eapi: warn to scan anyway."

	msg="EAPI $eapi needs bash >= $needs but this runner has $bash_ver; results for those ebuilds will be wrong"
	case $on_unsupported in
	error) fail "$msg" ;;
	warn) warn "$msg" ;;
	ignore) echo "$msg" ;;
	*)
		fail "on-unsupported-eapi must be error, warn or ignore (got '$on_unsupported')"
		exit 2
		;;
	esac
done

[[ $on_unsupported == error ]] && exit 1
exit 0
