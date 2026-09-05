#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

TEST_DIR="$(mktemp -d)"
SCRIPT_PATH="$(cd "$(dirname "$0")/.." && pwd -P)/bauhaus-start-dev"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
assert_dir() { [[ -d "$1" ]] || fail "expected directory '$1'"; }
assert_not_dir() { [[ ! -d "$1" ]] || fail "did not expect directory '$1'"; }
assert_file_line() { grep -Fxq "$2" "$1" || fail "expected '$2' in '$1'"; }
assert_output() { [[ "$1" == *"$2"* ]] || fail "expected output to contain '$2'"; }
assert_remote_branch() { git --git-dir="$REMOTE" show-ref --verify --quiet "refs/heads/$1" || fail "expected remote branch '$1'"; }
assert_no_remote_branch() { ! git --git-dir="$REMOTE" show-ref --verify --quiet "refs/heads/$1" || fail "did not expect remote branch '$1'"; }
assert_upstream() { [[ "$(git -C "$1" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" == "$2" ]] || fail "expected '$1' to track '$2'"; }

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
assert_upstream "$PROJECT/main" origin/main
[[ "$(git -C "$PROJECT/feat-101" branch --show-current)" == feat-101 ]] || fail 'feature branch was not checked out'
[[ "$(git -C "$PROJECT/feat-101" status --porcelain)" == '' ]] || fail '.local-dev should be ignored'
git -C "$PROJECT/feat-101" push --set-upstream origin feat-101 >/dev/null
assert_remote_branch feat-101

printf '[TEST] Checking idempotency...\n'
bash "$SCRIPT_PATH" -r "$REMOTE" -b main -b feat-101 -d "$WORKSPACES" >/dev/null

printf '[TEST] Keeping a local worktree when its confirmation is declined...\n'
removal_output="$(printf 'n\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-101 -d "$WORKSPACES" --remove-local 2>&1)"
assert_output "$removal_output" "Remove local worktree 'feat-101'"
assert_output "$removal_output" 'Kept local worktree feat-101.'
assert_dir "$PROJECT/feat-101"

printf '[TEST] Keeping a local worktree when confirmation input ends...\n'
removal_output="$(bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-101 -d "$WORKSPACES" --remove-local </dev/null 2>&1)"
assert_output "$removal_output" 'Kept local worktree feat-101.'
assert_dir "$PROJECT/feat-101"

printf '[TEST] Removing only a local worktree after confirmation...\n'
printf 'y\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-101 -d "$WORKSPACES" --remove-local >/dev/null
assert_not_dir "$PROJECT/feat-101"
assert_remote_branch feat-101

printf '[TEST] Re-creating a worktree for remote-removal tests...\n'
bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-101 -d "$WORKSPACES" >/dev/null
assert_dir "$PROJECT/feat-101"

printf '[TEST] Keeping a remote branch when its confirmation is declined...\n'
removal_output="$(printf 'no\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-101 -d "$WORKSPACES" --remove-remote 2>&1)"
assert_output "$removal_output" "Remove remote branch 'feat-101'"
assert_output "$removal_output" 'Kept remote branch feat-101.'
assert_remote_branch feat-101
assert_dir "$PROJECT/feat-101"

printf '[TEST] Removing only a remote branch after confirmation...\n'
printf 'yes\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-101 -d "$WORKSPACES" --remove-remote >/dev/null
assert_no_remote_branch feat-101
assert_dir "$PROJECT/feat-101"

printf '[TEST] Removing local and remote resources with separate confirmations...\n'
bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-102 -d "$WORKSPACES" >/dev/null
git -C "$PROJECT/feat-102" push --set-upstream origin feat-102 >/dev/null
assert_remote_branch feat-102
printf 'y\ny\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-102 -d "$WORKSPACES" --remove-local --remove-remote >/dev/null
assert_not_dir "$PROJECT/feat-102"
assert_no_remote_branch feat-102

printf '[TEST] Treating combined local and remote confirmations independently...\n'
bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-104 -d "$WORKSPACES" >/dev/null
git -C "$PROJECT/feat-104" push --set-upstream origin feat-104 >/dev/null
printf 'n\ny\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-104 -d "$WORKSPACES" --remove-local --remove-remote >/dev/null
assert_dir "$PROJECT/feat-104"
assert_no_remote_branch feat-104

bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-105 -d "$WORKSPACES" >/dev/null
git -C "$PROJECT/feat-105" push --set-upstream origin feat-105 >/dev/null
printf 'y\nn\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-105 -d "$WORKSPACES" --remove-local --remove-remote >/dev/null
assert_not_dir "$PROJECT/feat-105"
assert_remote_branch feat-105

printf '[TEST] Keeping both resources when both confirmations are declined...\n'
bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-106 -d "$WORKSPACES" >/dev/null
git -C "$PROJECT/feat-106" push --set-upstream origin feat-106 >/dev/null
printf 'n\nn\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-106 -d "$WORKSPACES" --remove-local --remove-remote >/dev/null
assert_dir "$PROJECT/feat-106"
assert_remote_branch feat-106

printf '[TEST] Refusing to remove a dirty local worktree...\n'
bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-103 -d "$WORKSPACES" >/dev/null
printf 'uncommitted\n' >"$PROJECT/feat-103/dirty-file"
if printf 'y\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-103 -d "$WORKSPACES" --remove-local >/dev/null 2>&1; then
    fail 'dirty worktree was removed'
fi
assert_dir "$PROJECT/feat-103"

printf '[TEST] Rejecting an unregistered local worktree...\n'
if bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-missing -d "$WORKSPACES" --remove-local >/dev/null 2>&1; then
    fail 'unregistered local worktree removal was accepted'
fi

printf '[TEST] Reporting a missing remote branch without touching the local worktree...\n'
bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-107 -d "$WORKSPACES" >/dev/null
if printf 'y\n' | bash "$SCRIPT_PATH" -r "$REMOTE" -b feat-107 -d "$WORKSPACES" --remove-remote >/dev/null 2>&1; then
    fail 'missing remote branch removal was accepted'
fi
assert_dir "$PROJECT/feat-107"

printf '[TEST] Rejecting repository creation mixed with removal options...\n'
if bash "$SCRIPT_PATH" -r demo-org/conflicting-options --create-repo -b main --remove-local -d "$WORKSPACES" >/dev/null 2>&1; then
    fail '--create-repo and removal options were accepted together'
fi

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
