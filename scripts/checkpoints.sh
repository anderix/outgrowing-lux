#!/usr/bin/env bash
# Author: David M. Anderson
# Built with AI assistance (Claude, Anthropic)
#
# Regenerates the Go chapters' examples from the vier-cli commits they show,
# then builds and tests each one.

set -euo pipefail

source=${VIER_CLI:-$HOME/repos/games/vier-cli}
book=$(cd "$(dirname "$0")/.." && pwd)

checkpoints=(
    "8dc18e1 ch02-runs"
    "edff5fb ch03-board"
    "7dbb6c8 ch04-winning"
    "2525acd ch05-commands"
    "c42f5c3 ch06-random"
    "9c1bdb0 ch07-search"
    "0a26d62 ch08-difficulty"
    "8b798fd ch09-saving"
    "524c347 ch10-flags"
    "80530a9 ch11-release"
)

left_out=(PLAN.md README.md SECURITY.md LICENSE .gitignore)

for checkpoint in "${checkpoints[@]}"; do
    read -r commit folder <<<"$checkpoint"
    target=$book/examples/$folder
    rm -rf "$target"
    mkdir -p "$target"
    git -C "$source" archive "$commit" | tar -x -C "$target"
    for name in "${left_out[@]}"; do
        rm -f "$target/$name"
    done
    echo "==> $folder from $commit"
    (cd "$target" && go vet ./... && go test ./... >/dev/null)
    echo "    builds and passes its tests"
done
