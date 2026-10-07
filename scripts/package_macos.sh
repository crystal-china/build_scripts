#!/usr/bin/env bash

set -euo pipefail

if (( $# < 2 || $# > 3 )); then
    echo "Usage: $0 <binary> <aarch64-sonoma|x86_64-sonoma> [output]" >&2

    exit 2
fi

script_path="$(command realpath "${BASH_SOURCE[0]}")"
ROOT="$(command realpath "${script_path%/*}/..")"
binary="$(command realpath "$1")"
platform="$2"
output="${3:-$1.sh}"

case "$platform" in
    aarch64-sonoma|x86_64-sonoma) ;;
    *)
        echo "Unsupported macOS platform: $platform" >&2

        exit 2
        ;;
esac

if [[ ! -f "$ROOT/vendor/package_payload/package_payload" ]]; then
    echo "Initialize package_payload with: git submodule update --init vendor/package_payload" >&2

    exit 1
fi

mkdir -p "$(dirname "$output")"

output="$(command realpath "$(dirname "$output")")/${output##*/}"
name="${output##*/}"

if [[ "$output" == "$binary" ]]; then
    echo "The packaged script must have a different path from the original binary" >&2

    exit 2
fi

workdir="$(mktemp -d "$(dirname "$output")/.macos-package.XXXXXX")"

trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/payload/bin" "$workdir/payload/bin.real" "$workdir/payload/lib"
cp "$ROOT/scripts/macos_wrapper.sh" "$workdir/payload/bin/$name"
cp "$binary" "$workdir/payload/bin.real/$name"
chmod +x "$workdir/payload/bin/$name" "$workdir/payload/bin.real/$name"
cp "$ROOT/prebuilt_libs/$platform"/libxml2.*.dylib "$workdir/payload/lib/"

TMPDIR="$workdir" bash "$ROOT/vendor/package_payload/package_payload" "$workdir/$name" "$workdir/payload"
mv "$workdir/$name" "$output"

printf 'Packaged macOS executable: %s\n' "$output"
