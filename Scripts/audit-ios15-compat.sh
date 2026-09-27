#!/usr/bin/env bash
set -euo pipefail

ROOT="${SEAL_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

fail=0

expect_literal() {
  local file="$1" pattern="$2" description="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "ERROR: $description ($file must contain: $pattern)" >&2
    fail=1
  fi
}

expect_no_match() {
  local pattern="$1" description="$2"
  if grep -R -nE --include='*.swift' "$pattern" Seal SealTunnel SealTests SealUITests > /tmp/soulsign-ios15-audit.txt 2>/dev/null; then
    echo "ERROR: $description" >&2
    cat /tmp/soulsign-ios15-audit.txt >&2
    fail=1
  fi
}

expect_literal project.yml 'iOS: "15.0"' 'Global XcodeGen deployment target is not iOS 15.0'
for target in Seal SealTunnel DeviceSupport SealTests SealUITests; do
  if ! python3 - "$target" <<'PY'
import re, sys
from pathlib import Path
text = Path('project.yml').read_text(encoding='utf-8')
target = re.escape(sys.argv[1])
m = re.search(rf'^  {target}:\n(?:(?:    .*|\s*)\n)*?    deploymentTarget: "([^"]+)"', text, re.M)
raise SystemExit(0 if m and m.group(1) == '15.0' else 1)
PY
  then
    echo "ERROR: project.yml target $target is not deploymentTarget 15.0" >&2
    fail=1
  fi
done
expect_literal Config/Base.xcconfig 'IPHONEOS_DEPLOYMENT_TARGET = 15.0' 'Base xcconfig is not iOS 15.0'
expect_literal Vendor/Minimuxer/RustBridge/Makefile 'IPHONEOS_DEPLOYMENT_TARGET ?= 15.0' 'RustBridge default target is not iOS 15.0'

# Direct uses of these APIs would raise the minimum runtime to iOS 16.
expect_no_match 'NavigationStack|NavigationPath|\.navigationDestination\s*\(' 'Found iOS 16 navigation API'
expect_no_match 'NavigationLink\s*\(\s*value\s*:' 'Found iOS 16 value-based NavigationLink'
expect_no_match '\.presentationDetents\s*\(|\.presentationDragIndicator\s*\(' 'Found iOS 16 sheet detent API'
expect_no_match 'PhotosPickerItem|\.photosPicker\s*\(' 'Found iOS 16 PhotosPicker API'
expect_no_match 'ShareLink\s*\(' 'Found iOS 16 ShareLink API'
expect_no_match '\.scrollDismissesKeyboard\s*\(' 'Found iOS 16 scrollDismissesKeyboard API'
expect_no_match '\.toolbar\s*\(\s*\.hidden\s*,\s*for\s*:' 'Found iOS 16 toolbar visibility API'
expect_no_match 'Task\.sleep\s*\(\s*for\s*:' 'Found Clock-based Task.sleep(for:) usage; use nanoseconds for iOS 15 back deployment'
expect_no_match '\.appending\s*\(\s*path\s*:' 'Found URL.appending(path:), which requires iOS 16; use appendingPathComponent'
expect_no_match 'URL\s*\(\s*filePath\s*:' 'Found URL(filePath:), which requires iOS 16; use URL(fileURLWithPath:)'
expect_no_match 'PresentationDetent' 'Found PresentationDetent, which requires iOS 16'

if (( fail != 0 )); then
  exit 1
fi

echo "SoulSign iOS 15 source compatibility audit passed."
