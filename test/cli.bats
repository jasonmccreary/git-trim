#!/usr/bin/env bats

load test_helper

@test "git trim defaults to removing pruned branches" {
  gone_branch gone
  tracked_branch live
  local_branch untracked

  run -0 git trim

  refute_branch gone
  assert_branch live
  assert_branch untracked
}

@test "--dry-run alone still defaults to pruned" {
  gone_branch gone

  run -0 git trim --dry-run

  assert_output "gone will be deleted."
  assert_branch gone
}

@test "--porcelain alone still defaults to pruned" {
  gone_branch gone

  run -0 git trim --porcelain

  assert_output "$(printf 'delete\tgone')"
  refute_branch gone
}

@test "choosing a mode replaces the default pruned mode" {
  gone_branch gone
  merged_branch done

  run -0 git trim --merged

  refute_branch done
  assert_branch gone
}

@test "-p is short for --pruned" {
  gone_branch gone
  run -0 git trim -p
  refute_branch gone
}

@test "-m is short for --merged" {
  merged_branch done
  run -0 git trim -m
  refute_branch done
}

@test "-s is short for --stale" {
  stale_branch old
  run -0 git trim -s
  refute_branch old
}

@test "-q is short for --squashed" {
  squashed_branch squashed
  run -0 git trim -q
  refute_branch squashed
}

@test "-u is short for --untracked" {
  local_branch untracked
  run -0 git trim -u
  refute_branch untracked
}

@test "-t is short for --tracked" {
  merged_branch done
  push_branch done

  run -0 git trim -m -t

  refute_branch done
  refute_remote_branch done
}

@test "-r is short for --remote" {
  merged_branch done
  push_branch done

  run -0 git trim -m -r

  assert_branch done
  refute_remote_branch done
}

@test "-h lists every option" {
  run -129 git-trim -h

  assert_output_contains "git trim [options]"
  for option in --all --dry-run --porcelain --merged --pruned --remote "reset[=" --stale --squashed --tracked --untracked; do
    assert_output_contains "$option"
  done
}

@test "an unknown option fails without removing anything" {
  merged_branch done

  run -129 git trim --bogus

  assert_output_contains "unknown option"
  assert_branch done
}

@test "works from a subdirectory" {
  merged_branch done
  mkdir -p nested/dir
  cd nested/dir

  run -0 git trim --merged

  refute_branch done
}

@test "fails outside a repository" {
  cd "$HOME"

  run git trim

  [ "$status" -ne 0 ]
  assert_output_contains "not a git repository"
}

@test "works when invoked directly from the path" {
  merged_branch done

  run -0 git-trim --merged

  refute_branch done
}

@test "the script is executable" {
  [ -x "$PROJECT_ROOT/git-trim" ]
}

@test "the npm package exposes the script" {
  run -0 grep '"git-trim": "git-trim"' "$PROJECT_ROOT/package.json"
}

@test "the zsh plugin adds the script to the path" {
  command -v zsh >/dev/null || skip "zsh is not installed"

  run -0 env PATH=/usr/bin:/bin zsh -f -c "source '$PROJECT_ROOT/git-trim.plugin.zsh'; print -r -- \$commands[git-trim]"

  assert_output "$PROJECT_ROOT/git-trim"
}
