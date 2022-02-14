# git trim
A command to quickly remove merged, pruned, untracked, or stale branches within a repository.


## Usage
```sh
git trim
git trim --pruned
git trim -p
    # Removes local branches where its remote branch no longer exists

git trim --merged
git trim -m
   # Removes local branches already merged into the current branch

git trim --stale
git trim -s
   # Removes local branches without commits in the last 3 months

git trim --untracked
git trim -u
    # Removes local branches not tracking a remote branch

git trim --reset[=remote]
    # Removes all local branches except those existing on remote which defaults to "origin" (requires confirmation)

git trim --all
    # Removes all local branches except the current branch (requires confirmation)
```

Of course, you may combine these options where appropriate. For example, `git trim --merged --stale`, would remove both local branches which have been merged with the current branch or are _stale_.

There are two additional options which may also be combined with the options above: `--tracked` and `--remote`.

When the `--tracked` (or `-t`) option is used, the remote tracking branch is also removed. For example, `git trim --merged --tracked` will remove local branches merged into the current branch, and remove the remote branch it's tracking (if any).

When the `--remote` (or `-r`) option is used, `git trim` will remove remote branches instead of local branches. For example, `git trim --stale --remote` will remove remote branches without commits in the last 3 months (stale local branches will not be removed).

Finally, you may also append the `--dry-run` option to any `git-trim` command to simply list the branches which would be deleted instead of actually removing them.

## Installation

### Basic install
The preferred installation method is to simply save the `git-trim` script somewhere included in your path. For example, copy `git-trim` into an existing included path like `/usr/local/bin`, or add the parent directory to your `PATH` environment.

### Install via NPM
```sh
npm install --global git-trim
```

### Install via ZSH

#### [Oh-My-Zsh](http://ohmyz.sh/)

1. Run: `git clone https://github.com/jasonmccreary/git-trim.git $ZSH_CUSTOM/plugins/git-trim`
2. Add `git-trim` to your plugin list: edit `~/.zshrc` and change
   `plugins=(...)` to `plugins=(... git-trim)`


## Updating
Once installed, the easiest way to update is to overwrite your local copy with the latest contents of the `git-trim` script.

### Updating via NPM
```sh
npm update --global git-trim
```

### Updating via ZSH

#### Oh-My-Zsh
```sh
cd $ZSH_CUSTOM/plugins/git-trim
git fetch
git pull
```

## Configuration
By default, `git trim` will never remove the current branch. However, depending on your branching strategy, you may have additional branches you never want to remove. For example, a `dev` or `staging` branch.

If so, you may set a `gt.exclude` option to your Git configuration, either locally or globally, with a space delimited string of any additional branches you want to exclude from removal.

```sh
git config gt.exclude "dev staging"
    # Always exclude the "dev" and "staging" branches from removal
```


## Disclaimer
Some of the options in this command remove branches without warning. Once a branch is removed, it might not be recoverable. You are solely responsible when running this command.


## Credits
There are thousands of commands and aliases for cleaning up branches sprinkled across the internet. I'll specifically link the commands and posts shared in [this Twitter thread](https://twitter.com/gonedark/status/1486721735621677068), [another project](https://github.com/foriequal0/git-trim) for inspiring the name, and [git-open](https://github.com/paulirish/git-open) which I used as a code reference.


## Contributing
Feel free to open an issue or pull request to help contribute to the project. Currently the only code style requirement is an indentation of 2 spaces.


## License
Copyright [Jason McCreary](https://github.com/jasonmccreary/). Licensed under [MIT](http://opensource.org/licenses/MIT).
