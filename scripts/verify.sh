#!/bin/bash
# Read-only source checks. Never installs tools, fixes code, or retries failed tests.
set -euo pipefail

usage() {
    cat <<'HELP'
Usage: bash scripts/verify.sh [docs|static|code|full]

  docs    Check unstaged and staged diffs for whitespace errors.
  static  Also run ShellCheck, tooling tests, SwiftLint, and plist validation.
  code    Default: static checks + simulator unit/integration tests + coverage.
  full    Static checks + Release build + all unit/integration/UI tests + coverage.

Setup: bash scripts/setup-tools.sh
Override simulator: VERIFY_DESTINATION='platform=iOS Simulator,name=iPhone 16e,OS=latest'
Logs, coverage, and result bundles: .build/verification/<unique run directory>/
HELP
}

if [[ $# -gt 1 ]]; then
    usage >&2
    exit 2
fi
profile="${1:-code}"
case "$profile" in
    -h|--help) usage; exit 0 ;;
    docs|static|code|full) ;;
    *) usage >&2; exit 2 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export PATH="$root/.build/tools/bin:$PATH"
mkdir -p .build/verification
run_dir="$(mktemp -d "$root/.build/verification/${profile}.XXXXXX")"
printf 'Verification profile: %s\nResults: %s\n' "$profile" "$run_dir"

# Invoked by the EXIT trap; ShellCheck cannot resolve trap callbacks (SC2329).
# shellcheck disable=SC2329
finish() {
    status=$?
    if [[ $status -eq 0 ]]; then
        printf 'PASS: %s profile\n' "$profile" | tee "$run_dir/status.txt"
    else
        printf 'FAIL: %s profile (exit %s). See %s\n' "$profile" "$status" "$run_dir" \
            | tee "$run_dir/status.txt" >&2
    fi
}
trap 'finish' EXIT

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Required tool missing: %s. Run bash scripts/setup-tools.sh; Xcode is also required for code/full.\n' "$1" >&2
        exit 1
    fi
}

run() {
    local label="$1"
    shift
    printf '\nChecking %s\n' "$label"
    "$@" 2>&1 | tee "$run_dir/$label.log"
}

failures=0
check() {
    if run "$@"; then
        return 0
    else
        failures=$((failures + 1))
        printf 'Failed check: %s (remaining independent checks will still run)\n' "$1" >&2
    fi
}

require git
check unstaged-whitespace git diff --check
check staged-whitespace git diff --cached --check
if [[ "$profile" == docs ]]; then
    exit "$((failures > 0))"
fi

require shellcheck
require swiftlint
require plutil
require python3
check shellcheck shellcheck scripts/*.sh
check tooling-tests python3 -m unittest discover -s scripts/tests
check swiftlint-version swiftlint version
check swiftlint swiftlint lint --config .swiftlint.yml --strict --no-cache
plist_index=0
while IFS= read -r -d '' plist; do
    plist_index=$((plist_index + 1))
    check "plist-$plist_index" plutil -lint "$plist"
done < <(find "Can I Wear" -type f -name '*.plist' -print0)
if [[ "$profile" == static ]]; then
    exit "$((failures > 0))"
fi

require xcodebuild
require xcrun
check xcode-version xcodebuild -version
destination="${VERIFY_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"
printf 'Destination: %s\n' "$destination" | tee "$run_dir/destination.txt"
common=(
    -project "Can I Wear.xcodeproj"
    -scheme "Can I Wear"
    -destination "$destination"
    -derivedDataPath "$root/.build/DerivedData"
    CODE_SIGNING_ALLOWED=NO
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
    GCC_TREAT_WARNINGS_AS_ERRORS=YES
)
if [[ "$profile" == full ]]; then
    check release-build xcodebuild "${common[@]}" -configuration Release build
fi

test_options=(-parallel-testing-enabled NO -enableCodeCoverage YES)
if [[ "$profile" == code ]]; then
    test_options+=(-only-testing:"Can I WearTests")
fi
bundle="$run_dir/Tests.xcresult"
if run tests xcodebuild "${common[@]}" -configuration Debug \
    "${test_options[@]}" -resultBundlePath "$bundle" test; then
    check coverage xcrun xccov view --report --only-targets "$bundle"
    check coverage-files xcrun xccov view --report --files-for-target "Can I Wear.app" "$bundle"
    if ! xcrun xccov view --report --json "$bundle" > "$run_dir/coverage.json"; then
        failures=$((failures + 1))
    fi
    printf '\nCoverage details: %s/coverage.json\n' "$run_dir"
else
    failures=$((failures + 1))
    printf 'Tests failed; no successful-run coverage claim is made.\n' >&2
fi
exit "$((failures > 0))"
