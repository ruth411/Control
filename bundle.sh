#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
bundle_path="$script_dir/build/Control.app"
swift build -c release
binary_path="$script_dir/.build/release/Control"

rm -rf "$bundle_path"
mkdir -p "$bundle_path/Contents/MacOS" "$bundle_path/Contents/Resources"
cp "$script_dir/Info.plist" "$bundle_path/Contents/Info.plist"
cp "$binary_path" "$bundle_path/Contents/MacOS/Control"
chmod +x "$bundle_path/Contents/MacOS/Control"
