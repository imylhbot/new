#!/usr/bin/env bash
set -euo pipefail

ipa="${1:-build/SoulSign.ipa}"
entries="$(unzip -Z1 "$ipa")"

grep -q '^Payload/SoulSign.app/Info.plist$' <<<"$entries"
grep -q '^Payload/SoulSign.app/PlugIns/SealTunnel.appex/Info.plist$' <<<"$entries"
grep -q '^Payload/SoulSign.app/PlugIns/SealTunnel.appex/SealTunnel$' <<<"$entries"
if grep -Eqi '\.(p12|mobileprovision)$|PairingFile\.plist$|Auth\.json$' <<<"$entries"; then
  echo "Sensitive signing material found in IPA" >&2
  exit 1
fi

unzip -p "$ipa" Payload/SoulSign.app/Info.plist > build/SoulSign-Info.plist
unzip -p "$ipa" Payload/SoulSign.app/PlugIns/SealTunnel.appex/Info.plist > build/SealTunnel-Info.plist
plutil -lint build/SoulSign-Info.plist
plutil -lint build/SealTunnel-Info.plist

extension_point="$(plutil -extract NSExtension.NSExtensionPointIdentifier raw build/SealTunnel-Info.plist)"
test "$extension_point" = "com.apple.networkextension.packet-tunnel"

echo "Unsigned SoulSign IPA verification passed with embedded SealTunnel.appex."
