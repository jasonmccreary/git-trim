#!/usr/bin/env bats

load test_helper

# Current branch
@test "--merged never removes the current branch" {
  git switch -q -c current

  run -0 git trim --merged

  assert_branch current
}

@test "--pruned never removes the current branch" {
  gone_branch current
  git switch -q current

  run -0 git trim --pruned

  assert_branch current
}

@test "--stale never removes the current branch" {
  stale_branch current
  git switch -q current

  run -0 git trim --stale

  assert_branch current
}

@test "--squashed never removes the current branch" {
  squashed_branch current
  git switch -q current

  run -0 git trim --squashed

  assert_branch current
}

@test "--untracked never removes the current branch" {
  local_branch current
  git switch -q current

  run -0 git trim --untracked

  assert_branch current
}

@test "--all never removes the current branch" {
  local_branch current
  git switch -q current

  run -0 answer y --all

  assert_branch current
}

@test "--reset never removes the current branch" {
  local_branch current
  git switch -q current

  run -0 answer y --reset

  assert_branch current
}

# Default branch
@test "--merged never removes the default branch" {
  git switch -q -c feature

  run -0 git trim --merged

  assert_branch main
}

@test "--pruned never removes the default branch" {
  tracked_branch trunk
  git remote set-head origin trunk >/dev/null
  git -C "$ORIGIN" branch -q -D trunk

  run -0 git trim --pruned

  assert_branch trunk
}

@test "--stale never removes the default branch" {
  stale_branch trunk
  push_branch trunk
  git remote set-head origin trunk >/dev/null

  run -0 git trim --stale

  assert_branch trunk
}

@test "--squashed never removes the default branch" {
  git switch -q -c feature

  run -0 git trim --squashed

  assert_branch main
}

@test "--untracked never removes the default branch" {
  git switch -q -c feature
  git branch -q --unset-upstream main

  run -0 git trim --untracked

  assert_branch main
}

@test "--all never removes the default branch" {
  git switch -q -c feature

  run -0 answer y --all

  assert_branch main
}

@test "--reset never removes the default branch" {
  local_branch trunk
  git update-ref refs/remotes/origin/trunk trunk
  git remote set-head origin trunk >/dev/null

  run -0 answer y --reset

  assert_branch trunk
}

@test "the default branch of every remote is protected" {
  add_remote upstream
  merged_branch develop
  git push -q upstream develop
  git remote set-head upstream develop >/dev/null

  run -0 git trim --merged

  assert_branch develop
}

@test "--remote never removes the default branch" {
  git switch -q -c feature
  push_branch feature

  run -0 git trim --merged --remote

  assert_remote_branch main
}

@test "--stale --remote never removes the default branch" {
  stale_branch trunk
  push_branch trunk
  git remote set-head origin trunk >/dev/null

  run -0 git trim --stale --remote

  assert_remote_branch trunk
}

@test "--all --remote never removes the default branch" {
  git switch -q -c feature
  push_branch feature
  git switch -q main
  git switch -q -c other

  run -0 answer y --all --remote

  assert_remote_branch main
  refute_remote_branch feature
}

@test "gt.protectDefault=false allows removing the default branch" {
  git config gt.protectDefault false
  git switch -q -c feature

  run -0 git trim --merged

  refute_branch main
}

@test "gt.protectDefault=true keeps the default branch" {
  git config gt.protectDefault true
  git switch -q -c feature

  run -0 git trim --merged

  assert_branch main
}

# gt.exclude
@test "gt.exclude keeps the listed branches" {
  git config gt.exclude "dev staging"
  merged_branch dev
  merged_branch staging
  merged_branch done

  run -0 git trim --merged

  assert_branch dev
  assert_branch staging
  refute_branch done
}

@test "gt.exclude supports glob patterns" {
  git config gt.exclude "dev staging save/*"
  merged_branch save/one
  merged_branch save/two
  merged_branch saved
  merged_branch dev

  run -0 git trim --merged

  assert_branch save/one
  assert_branch save/two
  assert_branch dev
  refute_branch saved
}

@test "gt.exclude matches whole branch names" {
  git config gt.exclude "dev"
  merged_branch dev
  merged_branch dev-tools
  merged_branch my-dev

  run -0 git trim --merged

  assert_branch dev
  refute_branch dev-tools
  refute_branch my-dev
}

@test "gt.exclude can be set globally" {
  git config --global gt.exclude "dev"
  merged_branch dev
  merged_branch done

  run -0 git trim --merged

  assert_branch dev
  refute_branch done
}

@test "gt.exclude globs do not expand against files on disk" {
  git config gt.exclude "save/*"
  mkdir save
  touch save/on-disk
  merged_branch save/one

  run -0 git trim --merged

  assert_branch save/one
}

@test "gt.exclude applies to every mode" {
  git config gt.exclude "keep-*"
  git switch -q -c keep-merged
  git switch -q main
  gone_branch keep-pruned
  stale_branch keep-stale
  squashed_branch keep-squashed
  local_branch keep-untracked

  for mode in --merged --pruned --stale --squashed --untracked; do
    run git trim "$mode"
    [ "$status" -eq 0 ]
  done
  run -0 answer y --all
  run -0 answer y --reset

  for branch in keep-merged keep-pruned keep-stale keep-squashed keep-untracked; do
    assert_branch "$branch"
  done
}

@test "gt.exclude applies to remote branches" {
  git config gt.exclude "dev save/*"
  merged_branch dev
  merged_branch save/one
  merged_branch done
  git push -q origin dev save/one done

  run -0 git trim --merged --remote

  assert_remote_branch dev
  assert_remote_branch save/one
  refute_remote_branch done
}

@test "gt.exclude matches whole remote branch names" {
  known_bug "remote exclusions match any path suffix"
  git config gt.exclude "dev"
  merged_branch feature/dev
  push_branch feature/dev

  run -0 git trim --merged --remote

  refute_remote_branch feature/dev
}

# Worktrees
@test "--merged skips a branch checked out in a worktree" {
  merged_branch done
  checkout_in_worktree done

  run -0 git trim --merged

  assert_branch done
  assert_output "Skipping branch done (checked out in worktree at $TEST_ROOT/worktree-done)."
}

@test "--pruned skips a branch checked out in a worktree" {
  gone_branch gone
  checkout_in_worktree gone

  run -0 git trim --pruned

  assert_branch gone
  assert_output_contains "Skipping branch gone"
}

@test "--stale skips a branch checked out in a worktree" {
  stale_branch old
  checkout_in_worktree old

  run -0 git trim --stale

  assert_branch old
  assert_output_contains "Skipping branch old"
}

@test "--squashed skips a branch checked out in a worktree" {
  squashed_branch squashed
  checkout_in_worktree squashed

  run -0 git trim --squashed

  assert_branch squashed
  assert_output_contains "Skipping branch squashed"
}

@test "--untracked skips a branch checked out in a worktree" {
  local_branch never-pushed
  checkout_in_worktree never-pushed

  run -0 git trim --untracked

  assert_branch never-pushed
  assert_output_contains "Skipping branch never-pushed"
}

@test "--all skips a branch checked out in a worktree" {
  local_branch wip
  checkout_in_worktree wip

  run -0 answer y --all

  assert_branch wip
  assert_output_contains "Skipping branch wip"
}

@test "--reset skips a branch checked out in a worktree" {
  local_branch wip
  checkout_in_worktree wip

  run -0 answer y --reset

  assert_branch wip
  assert_output_contains "Skipping branch wip"
}

@test "--tracked keeps the remote branch of a skipped worktree branch" {
  merged_branch done
  push_branch done
  checkout_in_worktree done

  run -0 git trim --merged --tracked

  assert_branch done
  assert_remote_branch done
}

@test "--squashed --remote skips a branch checked out in a worktree" {
  squashed_branch squashed
  push_branch squashed
  checkout_in_worktree squashed

  run -0 git trim --squashed --remote

  assert_remote_branch squashed
}

@test "other branches are still removed alongside a worktree branch" {
  merged_branch done
  merged_branch in-worktree
  checkout_in_worktree in-worktree

  run -0 git trim --merged

  refute_branch done
  assert_branch in-worktree
}
