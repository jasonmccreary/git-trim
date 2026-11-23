#!/usr/bin/env bats

load test_helper

# merged
@test "--merged removes branches merged into the current branch" {
  merged_branch done
  local_branch wip

  run -0 git trim --merged

  refute_branch done
  assert_branch wip
  assert_output_contains "Deleted branch done"
}

@test "--merged compares against the current branch, not the default" {
  git switch -q -c feature
  commit_file feature
  git switch -q main
  merged_branch only-on-main
  git switch -q feature
  merged_branch only-on-feature

  run -0 git trim --merged

  assert_branch only-on-main
  refute_branch only-on-feature
}

@test "--merged reports when there is nothing to trim" {
  local_branch wip

  run -0 git trim --merged

  assert_output "There are no merged branches to trim."
  assert_branch wip
}

@test "--merged handles branch names with slashes" {
  merged_branch feature/login

  run -0 git trim --merged

  refute_branch feature/login
}

@test "--merged works from a detached HEAD" {
  merged_branch done
  git switch -q --detach

  run -0 git trim --merged

  refute_branch done
  assert_branch main
}

# pruned
@test "--pruned removes branches whose remote branch no longer exists" {
  gone_branch gone
  tracked_branch live
  local_branch never-pushed

  run -0 git trim --pruned

  refute_branch gone
  assert_branch live
  assert_branch never-pushed
  assert_output_contains "Deleted branch gone"
}

@test "--pruned fetches to discover remote deletions" {
  tracked_branch gone
  git -C "$ORIGIN" branch -q -D gone
  git show-ref --verify -q refs/remotes/origin/gone

  run -0 git trim --pruned

  refute_branch gone
  run ! git show-ref --verify -q refs/remotes/origin/gone
}

@test "--pruned reports when there is nothing to trim" {
  tracked_branch live

  run -0 git trim --pruned

  assert_output "There are no local branches to trim."
}

# stale
@test "--stale removes branches without commits in the last 3 months" {
  stale_branch old 120
  stale_branch recent 60

  run -0 git trim --stale

  refute_branch old
  assert_branch recent
  assert_output_contains "Deleted branch old"
}

@test "--stale keeps a branch with a recent commit on top of old ones" {
  stale_branch revived 120
  git switch -q revived
  commit_file revived
  git switch -q main

  run -0 git trim --stale

  assert_branch revived
}

@test "--stale reports when there is nothing to trim" {
  local_branch recent

  run -0 git trim --stale

  assert_output "There are no stale branches to trim."
}

# squashed
@test "--squashed removes branches squash-merged into the current branch" {
  squashed_branch squashed
  local_branch wip

  run -0 git trim --squashed

  refute_branch squashed
  assert_branch wip
  assert_output_contains "Deleted branch squashed"
}

@test "--squashed keeps a branch with commits after the squash" {
  squashed_branch continued
  git switch -q continued
  commit_file more
  git switch -q main

  run -0 git trim --squashed

  assert_branch continued
}

@test "--squashed ignores branches with unrelated history" {
  git switch -q --orphan unrelated
  commit_file unrelated
  git switch -q main

  run -0 git trim --squashed

  assert_branch unrelated
}

@test "--squashed reports when there is nothing to trim" {
  local_branch wip

  run -0 git trim --squashed

  assert_output "There are no squash-merged branches to trim."
}

# untracked
@test "--untracked removes branches not tracking a remote branch" {
  local_branch never-pushed
  tracked_branch live

  run -0 git trim --untracked

  refute_branch never-pushed
  assert_branch live
  assert_output_contains "Deleted branch never-pushed"
}

@test "--untracked keeps a branch whose remote branch is gone" {
  gone_branch gone

  run -0 git trim --untracked

  assert_branch gone
}

@test "--untracked reports when there is nothing to trim" {
  tracked_branch live

  run -0 git trim --untracked

  assert_output "There are no untracked branches to trim."
}

# all
@test "--all removes every branch except current and default after confirming" {
  git switch -q -c current
  git switch -q main
  local_branch never-pushed
  tracked_branch live
  merged_branch done
  git switch -q current

  run -0 answer y --all

  refute_branch never-pushed
  refute_branch live
  refute_branch done
  assert_branch current
  assert_branch main
  assert_remote_branch live
}

@test "--all accepts y and yes in any case" {
  for reply in y Y yes YES Yes; do
    local_branch "reply-$reply"

    run -0 answer "$reply" --all

    refute_branch "reply-$reply"
  done
}

@test "--all removes nothing unless confirmed" {
  local_branch wip

  for reply in n no "" maybe; do
    run -0 answer "$reply" --all
    assert_branch wip
  done

  run -0 no_answer --all
  assert_branch wip
}

@test "--all reports when there is nothing to trim" {
  run -0 answer y --all

  assert_output "No branches need to be trimmed."
}

# reset
@test "--reset removes local branches not on origin after confirming" {
  local_branch never-pushed
  gone_branch gone
  tracked_branch live

  run -0 answer y --reset

  refute_branch never-pushed
  refute_branch gone
  assert_branch live
  assert_branch main
}

@test "--reset=remote compares against the given remote" {
  add_remote upstream
  local_branch on-upstream
  git push -q upstream on-upstream
  tracked_branch on-origin

  run -0 answer y --reset=upstream

  assert_branch on-upstream
  refute_branch on-origin
}

@test "--reset names the remote when confirming" {
  add_remote upstream
  local_branch wip

  run -0 answer n --reset=upstream

  assert_branch wip
}

@test "--reset removes nothing unless confirmed" {
  local_branch wip

  for reply in n no "" maybe; do
    run -0 answer "$reply" --reset
    assert_branch wip
  done

  run -0 no_answer --reset
  assert_branch wip
}

@test "--reset reports when there is nothing to trim" {
  tracked_branch live

  run -0 answer y --reset

  assert_output "No branches need to be trimmed."
}

# combined
@test "--merged --stale removes both kinds of branch" {
  merged_branch done
  stale_branch old
  local_branch wip

  run -0 git trim --merged --stale

  refute_branch done
  refute_branch old
  assert_branch wip
}

@test "--pruned --untracked removes both kinds of branch" {
  gone_branch gone
  local_branch never-pushed
  tracked_branch live

  run -0 git trim --pruned --untracked

  refute_branch gone
  refute_branch never-pushed
  assert_branch live
}

@test "--merged --squashed removes both kinds of branch" {
  merged_branch done
  squashed_branch squashed
  local_branch wip

  run -0 git trim --merged --squashed

  refute_branch done
  refute_branch squashed
  assert_branch wip
}

@test "short options can be bundled" {
  merged_branch done
  stale_branch old

  run -0 git trim -ms

  refute_branch done
  refute_branch old
}

@test "a mode with nothing to trim does not stop later modes" {
  stale_branch old

  run -0 git trim --merged --stale

  assert_output_contains "There are no merged branches to trim."
  assert_output_contains "Deleted branch old"
  refute_branch old
}

@test "every mode with nothing to trim reports it" {
  run -0 git trim --merged --stale

  assert_output "There are no merged branches to trim.
There are no stale branches to trim."
}

@test "a confirmation still runs after an empty mode" {
  local_branch wip

  run -0 answer y --merged --reset

  refute_branch wip
}
