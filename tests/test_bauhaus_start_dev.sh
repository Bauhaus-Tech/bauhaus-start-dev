#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

TEST_DIR="$(mktemp -d)"
SCRIPT_PATH="$(cd "$(dirname "$0")/.." && pwd -P)/bauhaus-start-dev"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
assert_dir() { [[ -d "$1" ]] || fail "expected directory '$1'"; }
assert_file_line() { grep -Fxq "$2" "$1" || fail "expected '$2' in '$1'"; }
assert_output() { [[ "$1" == *"$2"* ]] || fail "expected output to contain '$2'"; }

REMOTE="$TEST_DIR/upstream.git"
SEED="$TEST_DIR/seed"
WORKSPACES="$TEST_DIR/workspaces"
export REMOTE

printf '[TEST] Creating an isolated upstream repository...\n'
git init --bare --initial-branch=main "$REMOTE" >/dev/null
git init --initial-branch=main "$SEED" >/dev/null
git -C "$SEED" config user.name 'Test User'
git -C "$SEED" config user.email 'test@example.invalid'
printf 'hello\n' >"$SEED/README.md"
git -C "$SEED" add README.md
git -C "$SEED" commit -m initial >/dev/null
git -C "$SEED" remote add origin "$REMOTE"
git -C "$SEED" push -u origin main >/dev/null

printf '[TEST] Creating main plus a new feature worktree...\n'
bash "$SCRIPT_PATH" --repo "$REMOTE" --branch main --branch feat-101 --directory "$WORKSPACES"

PROJECT="$WORKSPACES/upstream"
assert_dir "$PROJECT/.bare"
assert_dir "$PROJECT/main/.local-dev"
assert_dir "$PROJECT/feat-101/.local-dev"
assert_file_line "$PROJECT/.bare/info/exclude" '.local-dev/'
[[ "$(git -C "$PROJECT/feat-101" branch --show-current)" == feat-101 ]] || fail 'feature branch was not checked out'
[[ "$(git -C "$PROJECT/feat-101" status --porcelain)" == '' ]] || fail '.local-dev should be ignored'

printf '[TEST] Checking idempotency...\n'
bash "$SCRIPT_PATH" -r "$REMOTE" -b main -b feat-101 -d "$WORKSPACES" >/dev/null

printf '[TEST] Rejecting unsafe branch names...\n'
if bash "$SCRIPT_PATH" -r "$REMOTE" -b '../escape' -d "$WORKSPACES" >/dev/null 2>&1; then
    fail 'unsafe branch name was accepted'
fi

printf '[TEST] Simulating GitHub repository creation...\n'
GH_LOG="$TEST_DIR/gh.log"
: >"$GH_LOG"
gh() {
    printf '%s\n' "$*" >>"$GH_LOG"
    case "$1 $2" in
        'auth status') return 0 ;;
        'repo view') return 1 ;;
        'repo create'|'repo edit') return 0 ;;
        'repo clone') git clone --bare "$REMOTE" "$4"; return ;;
    esac
    return 1
}
export GH_LOG
export -f gh
bash "$SCRIPT_PATH" -r demo-org/demo-project --create-repo -b feat-102 -d "$WORKSPACES"
unset -f gh
assert_dir "$WORKSPACES/demo-project/main/.local-dev"
assert_dir "$WORKSPACES/demo-project/feat-102/.local-dev"
assert_file_line "$GH_LOG" 'repo create demo-org/demo-project --private --add-readme'
assert_file_line "$GH_LOG" "repo clone https://github.com/demo-org/demo-project.git $WORKSPACES/demo-project/.bare --no-upstream -- --bare"
assert_file_line "$GH_LOG" 'repo edit demo-org/demo-project --default-branch main'

printf '[TEST] Checking sourced-script safety...\n'
sourced_output="$(bash -c 'source "$1"; printf terminal-still-running' _ "$SCRIPT_PATH" 2>&1)"
assert_output "$sourced_output" 'terminal-still-running'
assert_output "$sourced_output" 'do not source it'

printf '[✔] All tests passed.\n'
