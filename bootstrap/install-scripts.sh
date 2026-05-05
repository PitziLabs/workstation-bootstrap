#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
REPO_ROOT=$(dirname "$SCRIPT_DIR")

SCRIPTS_DIR="$REPO_ROOT/scripts"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$BIN_DIR" || {
    echo "error: could not create $BIN_DIR" >&2
    exit 1
}

installed=0
skipped=0
removed=0

# Install pass: symlink eligible files from scripts/ into ~/.local/bin/
for src in "$SCRIPTS_DIR"/*; do
    base=$(basename "$src")

    # Skip if name has an extension
    if [[ "$base" == *.* ]]; then
        echo "skipped $base (has extension)"
        ((skipped++)) || true
        continue
    fi

    # Skip if not a regular executable file
    if [[ ! -f "$src" ]] || [[ ! -x "$src" ]]; then
        echo "skipped $base (not a regular executable file)"
        ((skipped++)) || true
        continue
    fi

    dest="$BIN_DIR/$base"

    if [[ -L "$dest" ]]; then
        # Existing symlink — check if it points into our scripts dir
        existing_target=$(readlink -f "$dest" 2>/dev/null || true)
        scripts_canon=$(readlink -f "$SCRIPTS_DIR")
        if [[ "$existing_target" == "$scripts_canon"/* ]]; then
            # Managed by this repo — re-sync
            ln -sf "$src" "$dest"
            echo "updated $base"
            ((installed++)) || true
        else
            echo "warning: $BIN_DIR/$base exists and is not managed by this repo, skipping" >&2
            ((skipped++)) || true
        fi
    elif [[ -e "$dest" ]]; then
        # Regular file or other non-symlink — do not clobber
        echo "warning: $BIN_DIR/$base exists and is not managed by this repo, skipping" >&2
        ((skipped++)) || true
    else
        # Nothing there — create symlink
        ln -s "$src" "$dest"
        echo "symlinked $base"
        ((installed++)) || true
    fi
done

# Cleanup pass: remove dangling symlinks that point into our scripts dir
scripts_canon=$(readlink -f "$SCRIPTS_DIR")
for link in "$BIN_DIR"/*; do
    [[ -L "$link" ]] || continue
    link_target=$(readlink -f "$link" 2>/dev/null || true)
    # Dangling links resolve to empty string or to a non-existent path
    if [[ "$link_target" == "$scripts_canon"/* ]] && [[ ! -e "$link_target" ]]; then
        base=$(basename "$link")
        rm "$link"
        echo "removed dangling $base"
        ((removed++)) || true
    fi
done

echo "install-scripts: done ($installed installed, $skipped skipped, $removed removed)"
