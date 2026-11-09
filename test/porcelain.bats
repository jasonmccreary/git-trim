#!/usr/bin/env bats

load test_helper

count_deletes() {
  git trim "$@" | awk -F'\t' '$1 == "delete" {n++} END {print n+0}'
}

count_trimmable() {
  git trim "$@" | awk -F'\t' '$1 == "delete" || $1 == "skip-worktree" {n++} END {print n+0}'
}

# Record format
@test "a local deletion prints a delete record" {
  merged_branch done

  run -0 --separate-stderr git trim --merged --porcelain

  assert_output "$(printf 'delete\tdone')"
  [ -z "$stderr" ]
  refute_branch done
}

@test "a remote deletion prints a delete-remote record" {
  merged_branch done
  push_branch done

  run -0 --separate-stderr git trim --merged --remote --porcelain

  assert_output "$(printf 'delete-remote\torigin\tdone')"
  [ -z "$stderr" ]
  refute_remote_branch done
}

@test "a worktree branch prints a skip-worktree record" {
  merged_branch done
  checkout_in_worktree done

  run -0 --separate-stderr git trim --merged --porcelain

  assert_output "$(printf 'skip-worktree\tdone\t%s' "$TEST_ROOT/worktree-done")"
  [ -z "$stderr" ]
  assert_branch done
}

@test "a worktree path may contain spaces and tabs" {
  local path
  path=$(printf '%s/work tree\twith tab' "$TEST_ROOT")
  merged_branch done
  checkout_in_worktree done "$path"

  run -0 git trim --merged --porcelain

  assert_output "$(printf 'skip-worktree\tdone\t%s' "$path")"
  [ "$(printf '%s\n' "$output" | cut -f3-)" = "$path" ]
}

@test "branch names with slashes stay in one field" {
  merged_branch feature/login/form
  push_branch feature/login/form

  run -0 git trim --merged --remote --porcelain

  assert_output "$(printf 'delete-remote\torigin\tfeature/login/form')"
}

@test "--tracked prints a record for each deletion" {
  merged_branch done
  push_branch done

  run -0 git trim --merged --tracked --porcelain

  assert_output "$(printf 'delete-remote\torigin\tdone\ndelete\tdone')"
  refute_branch done
  refute_remote_branch done
}

@test "multiple branches print one record each" {
  merged_branch one
  merged_branch two
  merged_branch three

  run -0 git trim --merged --porcelain

  assert_output "$(printf 'delete\tone\ndelete\tthree\ndelete\ttwo')"
}

@test "combined modes print every record" {
  merged_branch done
  stale_branch old

  run -0 git trim --merged --stale --porcelain

  assert_output "$(printf 'delete\tdone\ndelete\told')"
}

@test "an empty mode does not stop later modes" {
  stale_branch old

  run -0 git trim --merged --stale --porcelain

  assert_output "$(printf 'delete\told')"
  refute_branch old
}

@test "human-readable messages are never printed" {
  merged_branch done
  merged_branch in-worktree
  checkout_in_worktree in-worktree

  run -0 git trim --merged --porcelain

  refute_output_contains "Deleted branch"
  refute_output_contains "will be deleted"
  refute_output_contains "Skipping branch"
}

# Every mode
@test "--pruned --porcelain" {
  gone_branch gone
  run -0 git trim --pruned --porcelain
  assert_output "$(printf 'delete\tgone')"
  refute_branch gone
}

@test "--stale --porcelain" {
  stale_branch old
  run -0 git trim --stale --porcelain
  assert_output "$(printf 'delete\told')"
  refute_branch old
}

@test "--squashed --porcelain" {
  squashed_branch squashed
  run -0 git trim --squashed --porcelain
  assert_output "$(printf 'delete\tsquashed')"
  refute_branch squashed
}

@test "--untracked --porcelain" {
  local_branch never-pushed
  run -0 git trim --untracked --porcelain
  assert_output "$(printf 'delete\tnever-pushed')"
  refute_branch never-pushed
}

@test "--stale --remote --porcelain" {
  stale_branch old
  push_branch old
  run -0 git trim --stale --remote --porcelain
  assert_output "$(printf 'delete-remote\torigin\told')"
  refute_remote_branch old
}

@test "--squashed --remote --porcelain" {
  squashed_branch squashed
  push_branch squashed
  run -0 git trim --squashed --remote --porcelain
  assert_output "$(printf 'delete-remote\torigin\tsquashed')"
  refute_remote_branch squashed
}

@test "--all --remote --porcelain" {
  tracked_branch live
  run -0 answer y --all --remote --porcelain
  assert_output "$(printf 'delete-remote\torigin\tlive')"
  refute_remote_branch live
}

# Dry run
@test "--dry-run --porcelain prints the same records without removing" {
  merged_branch done
  push_branch done
  merged_branch in-worktree
  checkout_in_worktree in-worktree

  run -0 git trim --merged --tracked --dry-run --porcelain
  local preview=$output

  assert_branch done
  assert_remote_branch done

  run -0 git trim --merged --tracked --porcelain

  assert_output "$preview"
  refute_branch done
  refute_remote_branch done
}

@test "--remote --dry-run --porcelain does not touch the remote" {
  merged_branch done
  push_branch done

  run -0 git trim --merged --remote --dry-run --porcelain

  assert_output "$(printf 'delete-remote\torigin\tdone')"
  assert_remote_branch done
}

# Nothing to trim
@test "nothing is printed when there are no branches to trim" {
  for mode in --merged --pruned --stale --squashed --untracked; do
    run -0 --separate-stderr git trim "$mode" --porcelain
    assert_output ""
    [ -z "$stderr" ]
  done

  run -0 git trim --porcelain
  assert_output ""
  run -0 answer y --all --porcelain
  assert_output ""
  run -0 answer y --reset --porcelain
  assert_output ""
}

@test "the README example counts local deletions" {
  squashed_branch one
  squashed_branch two
  push_branch one

  run -0 count_deletes --squashed --dry-run --porcelain

  assert_output "2"
}

@test "the README example does not count remote deletions" {
  merged_branch done
  push_branch done

  run -0 count_deletes --merged --tracked --dry-run --porcelain

  assert_output "1"
}

@test "the README example prints zero with a success status" {
  run -0 count_deletes --squashed --dry-run --porcelain

  assert_output "0"
}

@test "the README hook counts squashed branches" {
  squashed_branch one
  squashed_branch two

  run -0 count_trimmable --squashed --dry-run --porcelain

  assert_output "2"
}

@test "the README hook counts branches checked out in a worktree" {
  squashed_branch done
  checkout_in_worktree done

  run -0 count_trimmable --squashed --dry-run --porcelain

  assert_output "1"
}

@test "the README hook prints zero with a success status" {
  run -0 count_trimmable --squashed --dry-run --porcelain

  assert_output "0"
}

# Failures
@test "a failed remote deletion exits nonzero with no record" {
  merged_branch done
  push_branch done
  git remote set-url --push origin "$TEST_ROOT/missing.git"

  run -1 --separate-stderr git trim --merged --remote --porcelain

  assert_output ""
  [ -n "$stderr" ]
  assert_remote_branch done
}

@test "a failed local deletion exits nonzero with no record" {
  merged_branch done
  touch .git/refs/heads/done.lock

  run -1 --separate-stderr git trim --merged --porcelain

  rm .git/refs/heads/done.lock
  assert_output ""
  [ -n "$stderr" ]
  assert_branch done
}

@test "a failure does not stop remaining deletions" {
  merged_branch blocked
  merged_branch done
  touch .git/refs/heads/blocked.lock

  run -1 --separate-stderr git trim --merged --porcelain

  rm .git/refs/heads/blocked.lock
  assert_output "$(printf 'delete\tdone')"
  assert_branch blocked
  refute_branch done
}

@test "a failure is still reported when a later mode is empty" {
  merged_branch done
  push_branch done
  git remote set-url --push origin "$TEST_ROOT/missing.git"

  run -1 git trim --merged --remote --untracked --porcelain
}

# Confirmation
@test "--all --porcelain exits nonzero without confirmation" {
  local_branch wip

  run -1 --separate-stderr no_answer --all --porcelain

  assert_output ""
  assert_branch wip
}

@test "--reset --porcelain exits nonzero without confirmation" {
  local_branch wip

  run -1 --separate-stderr no_answer --reset --porcelain

  assert_output ""
  assert_branch wip
}

@test "--all --porcelain exits nonzero when declined" {
  local_branch wip

  run -1 --separate-stderr answer n --all --porcelain

  assert_output ""
  [[ "$stderr" == *"Aborted"* ]]
  assert_branch wip
}

@test "--reset --porcelain exits nonzero when declined" {
  local_branch wip

  run -1 --separate-stderr answer n --reset --porcelain

  assert_output ""
  [[ "$stderr" == *"Aborted"* ]]
  assert_branch wip
}

@test "--all --porcelain removes branches when confirmed" {
  local_branch wip

  run -0 answer y --all --porcelain

  assert_output "$(printf 'delete\twip')"
  refute_branch wip
}

@test "--reset --porcelain removes branches when confirmed" {
  local_branch wip

  run -0 answer yes --reset --porcelain

  assert_output "$(printf 'delete\twip')"
  refute_branch wip
}

@test "--all --dry-run --porcelain skips the confirmation" {
  local_branch wip

  run -0 no_answer --all --dry-run --porcelain

  assert_output "$(printf 'delete\twip')"
  assert_branch wip
}

@test "--reset --dry-run --porcelain skips the confirmation" {
  local_branch wip

  run -0 no_answer --reset --dry-run --porcelain

  assert_output "$(printf 'delete\twip')"
  assert_branch wip
}

@test "declining in human mode still exits zero" {
  local_branch wip

  run -0 answer n --all

  assert_branch wip
}
