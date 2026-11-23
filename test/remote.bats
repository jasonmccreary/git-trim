#!/usr/bin/env bats

load test_helper

# --remote
@test "--merged --remote removes the remote branch and keeps the local one" {
  merged_branch done
  push_branch done

  run -0 git trim --merged --remote

  refute_remote_branch done
  assert_branch done
  assert_output_contains "Deleted branch done (on origin)."
}

@test "--remote keeps remote branches that are not merged" {
  tracked_branch wip

  run -0 git trim --merged --remote

  assert_remote_branch wip
  assert_output "There are no merged branches to trim."
}

@test "--remote splits the remote name at the first slash" {
  merged_branch feature/login/form
  push_branch feature/login/form

  run -0 git trim --merged --remote

  refute_remote_branch feature/login/form
  assert_output_contains "Deleted branch feature/login/form (on origin)."
}

@test "--remote removes branches from every remote" {
  add_remote upstream
  merged_branch done
  git push -q origin done
  git push -q upstream done

  run -0 git trim --merged --remote

  refute_remote_branch done
  refute_remote_branch done "$TEST_ROOT/upstream.git"
}

@test "--remote ignores the remote HEAD" {
  merged_branch done
  push_branch done

  run -0 git trim --merged --remote

  refute_output_contains "HEAD"
  assert_remote_branch main
}

@test "--remote skips branches already removed from the remote" {
  merged_branch done
  push_branch done
  git -C "$ORIGIN" branch -q -D done

  run -0 git trim --merged --remote

  assert_output "There are no merged branches to trim."
}

@test "--merged --remote keeps the current branch on the remote" {
  git switch -q -c current
  push_branch current

  run -0 git trim --merged --remote

  assert_remote_branch current
  assert_remote_branch main
}

@test "--merged --remote matches the current branch exactly" {
  known_bug "the current branch is filtered by substring"
  merged_branch main-old
  push_branch main-old

  run -0 git trim --merged --remote

  refute_remote_branch main-old
}

@test "--stale --remote removes stale remote branches only" {
  stale_branch old
  push_branch old
  stale_branch local-old
  tracked_branch recent

  run -0 git trim --stale --remote

  refute_remote_branch old
  assert_branch old
  assert_branch local-old
  assert_remote_branch recent
  assert_remote_branch main
}

@test "--stale --remote keeps the current branch on the remote" {
  stale_branch old
  push_branch old
  git switch -q old

  run -0 git trim --stale --remote

  assert_remote_branch old
}

@test "--stale --remote matches the current branch exactly" {
  stale_branch old
  stale_branch old-two
  push_branch old
  push_branch old-two
  git switch -q old

  run -0 git trim --stale --remote

  assert_remote_branch old
  refute_remote_branch old-two
}

@test "--squashed --remote removes squash-merged remote branches" {
  squashed_branch squashed
  push_branch squashed
  tracked_branch wip

  run -0 git trim --squashed --remote

  refute_remote_branch squashed
  assert_branch squashed
  assert_remote_branch wip
  assert_remote_branch main
}

@test "--all --remote removes remote branches after confirming" {
  tracked_branch live
  local_branch never-pushed

  run -0 answer y --all --remote

  refute_remote_branch live
  assert_remote_branch main
  assert_branch live
  assert_branch never-pushed
}

@test "--all --remote removes nothing unless confirmed" {
  tracked_branch live

  run -0 answer n --all --remote

  assert_remote_branch live
}

# --tracked
@test "--merged --tracked removes the local and remote branch" {
  merged_branch done
  push_branch done

  run -0 git trim --merged --tracked

  refute_branch done
  refute_remote_branch done
  assert_output_contains "Deleted branch done (on origin)."
  assert_output_contains "Deleted branch done"
}

@test "--tracked removes the upstream even when its name differs" {
  merged_branch local-name
  git push -q origin local-name:remote-name
  git branch -q -u origin/remote-name local-name

  run -0 git trim --merged --tracked

  refute_branch local-name
  refute_remote_branch remote-name
}

@test "--tracked uses the remote the branch tracks" {
  add_remote upstream
  merged_branch done
  git push -q origin done
  push_branch done upstream

  run -0 git trim --merged --tracked

  refute_branch done
  refute_remote_branch done "$TEST_ROOT/upstream.git"
  assert_remote_branch done
}

@test "--tracked still removes a local branch without an upstream" {
  merged_branch done

  run -0 git trim --merged --tracked

  refute_branch done
}

@test "--merged alone leaves the remote branch in place" {
  merged_branch done
  push_branch done

  run -0 git trim --merged

  refute_branch done
  assert_remote_branch done
}

@test "--squashed --tracked removes the local and remote branch" {
  squashed_branch squashed
  push_branch squashed

  run -0 git trim --squashed --tracked

  refute_branch squashed
  refute_remote_branch squashed
}

@test "--all --tracked removes the local and remote branch" {
  known_bug "--all deletes the branch config before reading its upstream"
  tracked_branch live

  run -0 answer y --all --tracked

  refute_branch live
  refute_remote_branch live
}

@test "--stale --tracked removes the local and remote branch" {
  known_bug "--stale ignores --tracked"
  stale_branch old
  push_branch old

  run -0 git trim --stale --tracked

  refute_branch old
  refute_remote_branch old
}
