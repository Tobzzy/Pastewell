#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
cd "$project_dir"

if [[ -z "${SIGNING_IDENTITY:-}" || -z "${NOTARY_PROFILE:-}" ]]; then
    print -u2 "Set SIGNING_IDENTITY and NOTARY_PROFILE before notarizing."
    print -u2 "See DISTRIBUTING.md for setup instructions."
    exit 1
fi

./package-release.sh

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
archive_name="Pastewell-$version-macOS-universal.zip"

xcrun notarytool submit "dist/$archive_name" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
xcrun stapler staple Pastewell.app

rm -f "dist/$archive_name" "dist/$archive_name.sha256"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent Pastewell.app "dist/$archive_name"
(
    cd dist
    /usr/bin/shasum -a 256 "$archive_name" > "$archive_name.sha256"
)

spctl --assess --type execute --verbose=2 Pastewell.app
print "Notarized release created at dist/$archive_name"
