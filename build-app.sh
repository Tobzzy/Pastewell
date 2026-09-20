#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
cd "$project_dir"

developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
compiler="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
lipo_tool="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/lipo"
sdk="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
build_dir="$project_dir/.build/direct"
architectures=(${=ARCHITECTURES:-arm64 x86_64})

if [[ ! -x "$compiler" || ! -x "$lipo_tool" || ! -d "$sdk" ]]; then
    print -u2 "Pastewell could not find a complete Xcode installation at $developer_dir"
    exit 1
fi

mkdir -p "$build_dir"

binaries=()
for architecture in "${architectures[@]}"; do
    architecture_dir="$build_dir/$architecture"
    module_cache="$architecture_dir/ModuleCache"
    binary="$architecture_dir/Pastewell"
    mkdir -p "$module_cache"

    CLANG_MODULE_CACHE_PATH="$module_cache" \
    SWIFT_MODULECACHE_PATH="$module_cache" \
    "$compiler" \
        -O \
        -sdk "$sdk" \
        -target "$architecture-apple-macosx14.0" \
        -framework AppKit \
        -framework SwiftUI \
        -framework Carbon \
        "$project_dir"/Sources/Pastewell/*.swift \
        -o "$binary"
    binaries+=("$binary")
done

if (( ${#binaries[@]} == 1 )); then
    cp "$binaries[1]" "$build_dir/Pastewell"
else
    "$lipo_tool" -create "${binaries[@]}" -output "$build_dir/Pastewell"
fi

app_dir="$project_dir/Pastewell.app"
contents_dir="$app_dir/Contents"
binary_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

mkdir -p "$binary_dir" "$resources_dir"
cp "$build_dir/Pastewell" "$binary_dir/Pastewell"
cp "$project_dir/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$resources_dir/AppIcon.icns"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$app_dir"
else
    # Keep the designated requirement stable across local rebuilds. Without
    # this, ad-hoc signing uses the binary hash as its identity and macOS
    # Accessibility treats every build as a different app.
    codesign \
        --force \
        --deep \
        --sign - \
        --requirements '=designated => identifier "local.pastewell.clipboard"' \
        "$app_dir"
fi

print "Built $app_dir"
print "Architectures: ${architectures[*]}"
print "Launch it with: open \"$app_dir\""
