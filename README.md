# git-pr-prompt

A small, dependency-light zsh prompt that shows your git working-tree state **and
the status of the branch's GitHub pull request** — open, draft, merged, closed,
approved, changes requested — without ever blocking your shell.

PR data comes from the [`gh` CLI](https://cli.github.com/), is fetched in a
background job, cached on disk, and painted into the prompt the moment it
arrives (the prompt redraws itself via `SIGUSR1`).

```
alvaro ~/codebase/underwriting (PRE-1470-recycled *+? ↑2 ≡1) ⊙ ✓ ❯
        └─ path            └─ branch  └─ local state        └─ open PR, approved
```

## Symbols

| Symbol | Meaning |
|--------|---------|
| `*` | unstaged changes to tracked files |
| `+` | staged changes |
| `?` | untracked files |
| `↑n` / `↓n` | commits ahead of / behind upstream |
| `≡n` | stash entries |
| `⊙` | PR open |
| `◌` | PR is a draft |
| `⊕` | PR merged |
| `⊘` | PR closed without merging |
| `✓` | review approved |
| `✗` | changes requested |

## Requirements

- zsh 5.3+
- git
- [`gh`](https://cli.github.com/) authenticated (`gh auth login`) — optional; the
  git part works fine without it, and the PR segment simply stays empty.

## Install

**Manual**

```bash
git clone https://github.com/<you>/git-pr-prompt.git ~/.zsh/git-pr-prompt
echo 'source ~/.zsh/git-pr-prompt/git-pr-prompt.plugin.zsh' >> ~/.zshrc
```

Or run the bundled installer from the clone, which backs up your `~/.zshrc`
first and appends the `source` line only if it isn't already there:

```bash
./install.sh
```

**oh-my-zsh**

```bash
git clone https://github.com/<you>/git-pr-prompt.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/git-pr-prompt
# then add git-pr-prompt to plugins=(...) in ~/.zshrc
```

**zinit** — `zinit light <you>/git-pr-prompt`

**antidote / zplug** — add `<you>/git-pr-prompt` to your plugin list.

## Configuration

Set any of these **before** sourcing the plugin. Defaults shown.

| Variable | Default | Purpose |
|----------|---------|---------|
| `ZGP_PR_ENABLED` | `1` | Set `0` to disable all `gh` queries |
| `ZGP_PR_CACHE_TTL` | `30` | Seconds before a cached PR answer is refreshed |
| `ZGP_PR_CACHE_DIR` | `$TMPDIR/git-pr-prompt-cache` | Cache location |
| `ZGP_ASYNC_REDRAW` | `1` | Redraw the prompt when PR data lands |
| `ZGP_SET_PROMPT` | `1` | Set `0` to keep your own `PROMPT` (see below) |
| `ZGP_SHOW_STASH` | `1` | Show the `≡n` stash counter |
| `ZGP_SHOW_UNTRACKED` | `1` | Show the `?` untracked marker |
| `ZGP_SKIP_BRANCHES` | `(main master production)` | Branches never queried for a PR |

Symbols and colors are associative arrays — override individual keys only:

```zsh
typeset -A ZGP_SYMBOLS=(pr_open '●' pr_merged '✔')
typeset -A ZGP_COLORS=(branch cyan flags 214)
source ~/.zsh/git-pr-prompt/git-pr-prompt.plugin.zsh
```

Colors accept anything zsh's `%F{...}` accepts: names (`red`, `cyan`) or
256-color numbers (`242`).

### Using your own PROMPT

The git segment is exported as `$ZGP_GIT_INFO`, already colored and refreshed on
every `precmd`. Drop it wherever you like:

```zsh
ZGP_SET_PROMPT=0
source ~/.zsh/git-pr-prompt/git-pr-prompt.plugin.zsh
PROMPT='%F{green}%n@%m%f %F{blue}%~%f${ZGP_GIT_INFO}
❯ '
```

`setopt prompt_subst` is required (the plugin sets it).

## Commands

- `zgp-pr-cache-clear` — drop every cached PR answer; useful right after
  opening, approving, or merging a PR if you don't want to wait out the TTL.

## How it works

1. `precmd` runs `vcs_info` for the branch name and a handful of cheap local
   `git` calls for the flag string. No network.
2. The PR segment is read straight from a per-repo-and-branch cache file, so the
   prompt is drawn immediately even on a cold cache.
3. If the cache entry is older than `ZGP_PR_CACHE_TTL`, a disowned background
   job runs `gh pr view --json state,isDraft,reviewDecision`, writes the
   rendered segment atomically, and sends `SIGUSR1` to the shell, which triggers
   `zle reset-prompt`.

The cache file is touched before the query is launched, so several terminals in
the same repo don't stampede the GitHub API.

## Troubleshooting

**No PR icon appears.** Check `gh auth status`, and that the branch isn't in
`ZGP_SKIP_BRANCHES`. Then verify the query directly:

```bash
gh pr view "$(git branch --show-current)" --json state,isDraft,reviewDecision
```

**Prompt feels slow.** The git flag calls are the only synchronous work. In very
large repos, `ZGP_SHOW_UNTRACKED=0` is usually the biggest win.

**Prompt doesn't refresh on its own.** Something else in your config may already
define `TRAPUSR1`; the plugin deliberately does not override it. Either remove
that handler or set `ZGP_ASYNC_REDRAW=0` and accept a one-prompt lag.

## License

MIT — see [LICENSE](LICENSE).
