#!/usr/bin/env bash

set -euo pipefail

# ensure dir
cd -P -- "$(dirname -- "$0")/.."

find_app() {
    local appdir="$1"
    find "${appdir}" -mindepth 1 -maxdepth 1 -type d
}

find_app 'apps'
find_app 'lib-ee'

## find directories in lib-extra
find_app 'lib-extra'
## find symlinks in lib-extra
find 'lib-extra' -mindepth 1 -maxdepth 1 -type l -exec test -e {} \; -print
