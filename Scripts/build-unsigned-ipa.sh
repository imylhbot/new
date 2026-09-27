#!/usr/bin/env bash
set -euo pipefail

configuration="${SEAL_IPA_CONFIGURATION:-Release}"
derived_data="$PWD/build/DerivedData"
source_packages="${SEAL_SOURCE_PACKAGES_DIR:-$PWD/build/SourcePackages}"
product="$derived_data/Build/Products/${configuration}-iphoneos/SoulSign.app"
package_root="$PWD/build/package"
archive="$PWD/build/SoulSign.ipa"
build_log="$PWD/build/xcodebuild.log"

mkdir -p "$PWD/build" "$source_packages"

if [[ "${SEAL_SKIP_XCODEGEN:-0}" != "1" ]]; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required to regenerate SoulSign.xcodeproj from project.yml" >&2
    exit 1
  fi
  xcodegen generate
fi

rm -rf "$package_root" "$archive" "$archive.sha256" "$build_log"

update_repository="${SOULSIGN_UPDATE_REPOSITORY:-${GITHUB_REPOSITORY:-}}"

# Keep a full log for diagnostics, but print a compact error summary if Xcode fails.
set +e
xcodebuild build \
  -project SoulSign.xcodeproj \
  -scheme Seal \
  -configuration "$configuration" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$source_packages" \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  SOULSIGN_UPDATE_REPOSITORY="$update_repository" \
  2>&1 | tee "$build_log"
build_status=${PIPESTATUS[0]}
set -e

if [[ $build_status -ne 0 ]]; then
  echo
  echo "================ SoulSign Xcode error summary ================" >&2
  grep -E ':[0-9]+:[0-9]+: error:|(^|[[:space:]])error:|fatal error:|The following build commands failed' "$build_log" \
    | tail -n 200 >&2 || true
  echo "===============================================================" >&2
  exit "$build_status"
fi

test -d "$product"
mkdir -p "$package_root/Payload"
ditto "$product" "$package_root/Payload/SoulSign.app"

# Copy Anisette ADI libraries into app bundle.
anisette_src="$PWD/Seal/Resources/Anisette"
anisette_dst="$package_root/Payload/SoulSign.app/Anisette"
if [ -d "$anisette_src" ]; then
  mkdir -p "$anisette_dst"
  cp "$anisette_src"/libCoreADI.so "$anisette_dst/" 2>/dev/null || true
  cp "$anisette_src"/libstoreservicescore.so "$anisette_dst/" 2>/dev/null || true
  echo "Copied Anisette libraries:"
  ls -la "$anisette_dst/"
else
  echo "WARNING: $anisette_src not found, Anisette libraries will be missing" >&2
fi

(cd "$package_root" && /usr/bin/zip -qry "$archive" Payload)
shasum -a 256 "$archive" > "$archive.sha256"
