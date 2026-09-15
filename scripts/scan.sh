#!/usr/bin/env bash
#
# Regenerate metadata for the target repo, scan it, and report.
#
# One scan produces everything: `-R JsonStream` gives the machine-readable
# stream that the annotation and SARIF layers consume, `--exit` gives the CI
# exit status, and `pkgcheck replay` renders the same file for humans. This is
# deliberately not `pkgcheck ci`, which hardcodes FancyReporter for stdout and
# whose --failures file only ever receives error-level results.
#
# Inputs (env):
#   INPUT_SCOPE     auto | all | commits | staged
#   INPUT_BASE_REF  tree-ish for `commits` scope
#   INPUT_KEYWORDS  passed to -k
#   INPUT_EXIT_ON   checkset/keywords that trigger a non-zero exit
#   INPUT_NET       "true" to enable network checks

# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

scope=${INPUT_SCOPE:-auto}
results=${RUNNER_TEMP:-/tmp}/pkgcheck-results.jsonl

group "Regenerating repo metadata"
mkdir -p "$HOME/.cache/pkgcheck/repos"
regen_rc=0
"$(pmaint_bin)" regen --dir "$HOME/.cache/pkgcheck/repos" . || regen_rc=$?
endgroup

if ((regen_rc != 0)); then
	# regen warms a cache; it is not the authority on whether the repo is sound.
	# Anything it chokes on, the scan reports itself as a proper result
	# (InvalidEapi, SourcingError, ...) with --exit deciding the outcome, so
	# aborting here would turn a reported finding into an unexplained step
	# failure. It would also make on-unsupported-eapi: warn a lie, since regen
	# is precisely what fails on an EAPI the host's bash has disabled.
	warn "metadata regeneration reported errors (exit $regen_rc); results for the affected packages may be incomplete"
fi

if [[ $scope == auto ]]; then
	case ${GITHUB_EVENT_NAME:-} in
	pull_request | pull_request_target) scope=commits ;;
	*) scope=all ;;
	esac
	echo "scope: auto resolved to '$scope' for event '${GITHUB_EVENT_NAME:-none}'"
fi

args=(--color n -R JsonStream)
[[ -n ${INPUT_EXIT_ON:-} ]] && args+=(--exit "$INPUT_EXIT_ON")
[[ -n ${INPUT_KEYWORDS:-} ]] && args+=(-k "$INPUT_KEYWORDS")
[[ ${INPUT_NET:-false} == true ]] && args+=(--net)

case $scope in
all) ;;
commits)
	# pkgcheck's own default is the bare remote name; prefer the PR base when
	# one is available. Either way this needs full history -- actions/checkout
	# defaults to depth 1, which is the most likely way for this to go wrong.
	base=${INPUT_BASE_REF:-}
	if [[ -z $base && -n ${GITHUB_BASE_REF:-} ]]; then
		base="origin/$GITHUB_BASE_REF"
	fi
	if [[ -n $base ]] && ! git rev-parse --verify --quiet "$base" >/dev/null; then
		fail "base ref '$base' not found. Did you set 'fetch-depth: 0' on actions/checkout?"
		exit 1
	fi
	args+=(--commits ${base:+"$base"})
	;;
staged) args+=(--staged) ;;
*)
	fail "scope must be auto, all, commits or staged (got '$scope')"
	exit 2
	;;
esac

rc=0
group "Running pkgcheck scan (${args[*]})"
"$(pkgcheck_bin)" scan "${args[@]}" >"$results" || rc=$?
echo "scan exited $rc, $(wc -l <"$results") result(s)"
endgroup

# Same data the mappers will consume, rendered the way a human reads it.
if [[ -s $results ]]; then
	group "Results"
	"$(pkgcheck_bin)" replay --color y "$results" || true
	endgroup
fi

counts=$("$(python_bin)" "$(action_dir)/scripts/summarize.py" "$results")
echo "$counts"

set_output results-json "$results"
set_output error-count "$(sed -n 's/^error=//p' <<<"$counts")"
set_output warning-count "$(sed -n 's/^warning=//p' <<<"$counts")"
set_output result-count "$(sed -n 's/^total=//p' <<<"$counts")"
set_output exit-code "$rc"

exit "$rc"
