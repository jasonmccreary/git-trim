#!/usr/bin/env bats

load test_helper

@test "--merged --dry-run lists branches without removing them" {
  merged_branch done

  run -0 git trim --merged --dry-run

  assert_output "done will be deleted."
  assert_branch done
}

@test "--pruned --dry-run lists branches without removing them" {
  gone_branch gone

  run -0 git trim --pruned --dry-run

  assert_output "gone will be deleted."
  assert_branch gone
}

@test "--stale --dry-run lists branches without removing them" {
  stale_branch old

  run -0 git trim --stale --dry-run

  assert_output "old will be deleted."
  assert_branch old
}

@test "--squashed --dry-run lists branches without removing them" {
  squashed_branch squashed

  run -0 git trim --squashed --dry-run

  assert_output "squashed will be deleted."
  assert_branch squashed
}

@test "--untracked --dry-run lists branches without removing them" {
  local_branch never-pushed

  run -0 git trim --untracked --dry-run

  assert_output "never-pushed will be deleted."
  assert_branch never-pushed
}

@test "--all --dry-run lists branches without removing them" {
  local_branch wip

  run -0 answer y --all --dry-run

  assert_output "wip will be deleted."
  assert_branch wip
}

@test "--reset --dry-run lists branches without removing them" {
  local_branch wip

  run -0 answer y --reset --dry-run

  assert_output "wip will be deleted."
  assert_branch wip
}

@test "--remote --dry-run lists remote branches without removing them" {
  merged_branch done
  push_branch done

  run -0 git trim --merged --remote --dry-run

  assert_output "done will be deleted from origin."
  assert_remote_branch done
}

@test "--tracked --dry-run lists both branches without removing them" {
  merged_branch done
  push_branch done

  run -0 git trim --merged --tracked --dry-run

  assert_output "done will be deleted from origin.
done will be deleted."
  assert_branch done
  assert_remote_branch done
}

@test "--dry-run lists a skipped worktree branch" {
  merged_branch done
  checkout_in_worktree done

  run -0 git trim --merged --dry-run

  assert_output "Skipping branch done (checked out in worktree at $TEST_ROOT/worktree-done)."
  assert_branch done
}

@test "--dry-run can come before the mode" {
  merged_branch done

  run -0 git trim --dry-run --merged

  assert_output "done will be deleted."
  assert_branch done
}

@test "--dry-run reports when there is nothing to trim" {
  run -0 git trim --merged --dry-run

  assert_output "There are no merged branches to trim."
}
