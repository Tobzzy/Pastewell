#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
cd "$project_dir"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
archive_name="Pastewell-$version-macOS-universal.zip"
dist_dir="$project_dir/dist"

./build-app.sh
mkdir -p "$dist_dir"
rm -f "$dist_dir/$archive_name" "$dist_dir/$archive_name.sha256"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent Pastewell.app "$dist_dir/$archive_name"

cd "$dist_dir"
/usr/bin/shasum -a 256 "$archive_name" > "$archive_name.sha256"

print "Created $dist_dir/$archive_name"
print "Created $dist_dir/$archive_name.sha256"
