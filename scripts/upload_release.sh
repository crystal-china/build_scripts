#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/.."
last_tag=${1:-$(git tag --sort=committerdate | tail -n1)}

if [ -z "$last_tag" ]; then
  echo "No Git tag found; pass a release tag as the first argument." >&2
  exit 1
fi

set -- pkg/prebuilt_libs-*.tar.xz
if [ ! -f "$1" ]; then
  echo "No package found in pkg; run bin/tasks package first." >&2
  exit 1
fi

gh release upload --repo crystal-china/crystal_build_scripts "$last_tag" "$@"
