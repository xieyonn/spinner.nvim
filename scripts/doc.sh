#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
DEPS="$ROOT/.deps"
PANVIMDOC="$DEPS/panvimdoc"
PANVIMDOC_URL="https://github.com/kdheepak/panvimdoc"

_main() {
    mkdir -p "$DEPS"
    if [[ ! -d "$PANVIMDOC" ]]; then
        local tag="$(git ls-remote --tags --sort="v:refname" "$PANVIMDOC_URL" | tail -n1 | awk -F'/' '{print $3}')"
        echo "Download panvimdoc:$tag to $PANVIMDOC"
        git clone --branch "$tag" --depth 1 "$PANVIMDOC_URL" "$PANVIMDOC" > /dev/null 2>&1
    fi

    if ! command -v pandoc > /dev/null 2>&1; then
        echo "Need install pandoc first."
        return 1
    fi

    local ARGS=(
        "--shift-heading-level-by=0"
        "--metadata=project:spinner"
        "--metadata=toc:true"
        "--metadata=description:Extensible spinner framework for Neovim plugins and UI"
        "--metadata=titledatepattern:'%Y %B %d'"
        "--metadata=dedupsubheadings:false"
        "--metadata=ignorerawblocks:true"
        "--metadata=docmapping:true"
        "--metadata=docmappingproject:true"
        "--metadata=treesitter:true"
        "--metadata=incrementheadinglevelby:0"
        "--lua-filter=$PANVIMDOC/scripts/include-files.lua"
        "--lua-filter=$PANVIMDOC/scripts/skip-blocks.lua"
    )

    echo "Generating docs"
    pandoc \
        "${ARGS[@]}" \
        -t "$PANVIMDOC/scripts/panvimdoc.lua" \
        -o "$ROOT/doc/spinner.txt" \
        "$ROOT/README.md"
}

_main "$@"
