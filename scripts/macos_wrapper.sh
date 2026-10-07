#!/usr/bin/env bash

set -eu

script_path="$(command realpath "${BASH_SOURCE[0]}")"
ROOT="$(command realpath "${script_path%/*}/..")"
name="${script_path##*/}"

export DYLD_LIBRARY_PATH="$ROOT/lib"

exec "$ROOT/bin.real/$name" "$@"
