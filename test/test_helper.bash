bats_require_minimum_version 1.5.0

setup() {
  TEST_ROOT=$(cd "$BATS_TEST_TMPDIR" && pwd -P)
  PROJECT_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)
  ORIGIN="$TEST_ROOT/origin.git"

  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  export PATH="$PROJECT_ROOT:$PATH"
  export HOME="$TEST_ROOT/home"
  export GIT_CONFIG_GLOBAL="$TEST_ROOT/gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CEILING_DIRECTORIES="$TEST_ROOT"
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid

  mkdir -p "$HOME"
  : > "$GIT_CONFIG_GLOBAL"

  git init -q --bare -b main "$ORIGIN"
  git clone -q "$ORIGIN" "$TEST_ROOT/repo" 2>/dev/null
  cd "$TEST_ROOT/repo"
  git symbolic-ref HEAD refs/heads/main
  commit_file base
  git push -q -u origin main
  git remote set-head origin main >/dev/null
}


# Fixtures
commit_file() {
  local file="file-${1//\//-}"
  echo "$1" >> "$file"
  git add "$file"
  git commit -q -m "$1"
}

local_branch() {
  git switch -q -c "$1" main
  commit_file "$1"
  git switch -q main
}

push_branch() {
  git push -q -u "${2:-origin}" "$1"
}

tracked_branch() {
  local_branch "$1"
  push_branch "$1"
}

gone_branch() {
  tracked_branch "$1"
  git -C "$ORIGIN" branch -q -D "$1"
}

merged_branch() {
  local current
  current=$(git branch --show-current)
  git switch -q -c "$1"
  commit_file "$1"
  git switch -q "$current"
  git merge -q --no-ff --no-edit "$1"
}

squashed_branch() {
  local current
  current=$(git branch --show-current)
  git switch -q -c "$1"
  commit_file "$1"
  commit_file "$1"
  git switch -q "$current"
  git merge -q --squash "$1" >/dev/null
  git commit -q -m "Squash $1"
}

stale_branch() {
  local when="$(( $(date +%s) - ${2:-120} * 86400 )) +0000"
  local file="file-${1//\//-}"
  git switch -q -c "$1" main
  echo "$1" > "$file"
  git add "$file"
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git commit -q -m "$1"
  git switch -q main
}

add_remote() {
  git init -q --bare -b main "$TEST_ROOT/$1.git"
  git remote add "$1" "$TEST_ROOT/$1.git"
  git push -q "$1" main
  git fetch -q "$1"
  git remote set-head "$1" main >/dev/null
}

checkout_in_worktree() {
  git worktree add -q "${2:-$TEST_ROOT/worktree-${1//\//-}}" "$1"
}


# Running
answer() {
  local reply=$1
  shift
  printf '%s\n' "$reply" | git trim "$@"
}

no_answer() {
  git trim "$@" </dev/null
}


# Assertions
assert_branch() {
  git show-ref --verify -q "refs/heads/$1" || {
    echo "expected local branch to exist: $1"
    return 1
  }
}

refute_branch() {
  if git show-ref --verify -q "refs/heads/$1"; then
    echo "expected local branch to be removed: $1"
    return 1
  fi
}

assert_remote_branch() {
  git -C "${2:-$ORIGIN}" show-ref --verify -q "refs/heads/$1" || {
    echo "expected remote branch to exist: $1"
    return 1
  }
}

refute_remote_branch() {
  if git -C "${2:-$ORIGIN}" show-ref --verify -q "refs/heads/$1"; then
    echo "expected remote branch to be removed: $1"
    return 1
  fi
}

assert_output() {
  if [ "$output" != "$1" ]; then
    printf 'expected output:\n%s\nactual output:\n%s\n' "$1" "$output"
    return 1
  fi
}

assert_output_contains() {
  if [[ "$output" != *"$1"* ]]; then
    printf 'expected output to contain:\n%s\nactual output:\n%s\n' "$1" "$output"
    return 1
  fi
}

refute_output_contains() {
  if [[ "$output" == *"$1"* ]]; then
    printf 'expected output not to contain:\n%s\nactual output:\n%s\n' "$1" "$output"
    return 1
  fi
}
