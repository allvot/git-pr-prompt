# git-pr-prompt

A small, dependency-light zsh prompt that shows your git working-tree state **and
the status of the branch's GitHub pull request** — open, draft, merged, closed,
approved, changes requested — without ever blocking your shell.

PR data comes from the [`gh` CLI](https://cli.github.com/), is fetched in a
background job, cached on disk, and painted into the prompt the moment it
arrives (the prompt redraws itself via `SIGUSR1`).

```
alvaro ~/codebase/underwriting (PRE-1470 *+? ↑2 ≡1) ⊙ ✓ ❯
        └─ path            └─ branch └─ local state  └─ PR open, approved
```

With a Nerd Font installed you get GitHub's real Octicon glyphs instead —
 open,  draft,  merged,  closed — single-width characters, not emoji.
Detection is automatic; see [Symbols](#symbols).

## Symbols

The default is **`ZGP_SYMBOL_SET=auto`**: real GitHub icon glyphs if your
terminal has a Nerd Font, and the geometric set if it doesn't — so it looks
right out of the box either way, with no tofu boxes.

| | `nerdfont` | `minimal` (fallback) | `emoji` | `github` |
|---|---|---|---|---|
| PR open |  | `⊙` | 🔀 | 🟢 |
| draft |  | `◌` | 🚧 | ⚪ |
| merged |  | `⊕` | 🎉 | 🟣 |
| closed unmerged |  | `⊘` | 🚫 | 🔴 |
| approved |  | `✓` | ✅ | ✅ |
| changes requested |  | `✗` | ❌ | ❌ |
| awaiting review |  | `·` | 👀 | 👀 |
| **needs** | a Nerd Font | nothing | emoji font | emoji font |
| **width** | 1 cell | 1 cell | 2 cells | 2 cells |

- **`nerdfont`** — GitHub's *actual* icon set. These are real Octicons, single
  characters rather than emoji, so they're single-width and take your theme
  colors: `nf-oct-git_pull_request` U+F407, `…_draft` U+F4DD,
  `nf-oct-git_merge` U+F419, `…_closed` U+F4DC, `nf-oct-check_circle_fill`
  U+F4A4, `nf-oct-x_circle` U+F52F, `nf-oct-eye` U+F441. Bundled in every
  [Nerd Font](https://nerdfonts.com) — same family Starship and powerlevel10k
  draw from. Install one with
  `brew install --cask font-jetbrains-mono-nerd-font`, set it as your terminal
  font, then run `zgp-font-check`.
- **`minimal`** — plain Unicode geometry. Renders in any font, no install. Also
  the backstop preset: it supplies any key another preset leaves undefined.
- **`emoji`** / **`github`** — for terminals without a patched font where you'd
  rather have color than precision. `github` mirrors GitHub's own state colors
  (open green, draft gray, merged purple, closed red).

Run **`zsh tools/preview.zsh`** to see all four rendered in your own terminal
and font, then pick with `ZGP_SYMBOL_SET=nerdfont` (or `auto` to keep the
detection).

`nerdfont` also restyles the local flags ( modified,  staged,  untracked,
 ahead,  behind,  stashed). The other presets share these:

| Symbol | Meaning |
|--------|---------|
| `*` | unstaged changes to tracked files |
| `+` | staged changes |
| `?` | untracked files |
| `↑n` / `↓n` | commits ahead of / behind upstream |
| `≡n` | stash entries |

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
| `ZGP_SYMBOL_SET` | `auto` | `auto` / `nerdfont` / `minimal` / `emoji` / `github` |
| `ZGP_HAS_NERDFONT` | *detected* | Force detection: `1` yes, `0` no |
| `ZGP_SHOW_REVIEW_PENDING` | `1` | Show the "awaiting review" icon |
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
- `zgp-font-check` — re-run Nerd Font detection and print sample glyphs. Run it
  after installing a font or changing your terminal font. `zgp-font-check --yes`
  / `--no` overrides the guess permanently.

## Picking different glyphs

`tools/glyphs.zsh` browses 357 git-, PR- and review-related glyphs bundled from
the Nerd Fonts index — Octicons, Codicons, Font Awesome, Devicons, Material —
with names and codepoints, so you can shop for a better character:

```bash
zsh tools/glyphs.zsh pull_request   # filter by name
zsh tools/glyphs.zsh merge
zsh tools/glyphs.zsh --families
```

Seeing a glyph in your prompt and not sure what it is? Ask — it takes a pasted
character, `f407`, or `U+F407`, and tells you the name and which prompt symbol
uses it:

```bash
zsh tools/glyphs.zsh --what        # →  U+F418  oct-git_branch
                                    #    → used by this prompt as branch_prefix
```

Then override just the keys you want, before sourcing the plugin:

```zsh
typeset -A ZGP_SYMBOLS=(
  pr_open   $'\uea64'   # cod-git_pull_request  — VS Code's take
  pr_draft  $'\uebdb'   # cod-git_pull_request_draft
  pr_merged $'\ueafe'   # cod-git_merge
  pr_closed $'\uebda'   # cod-git_pull_request_closed
)
source ~/.zsh/git-pr-prompt/git-pr-prompt.plugin.zsh
```

Overridable keys: `pr_open` `pr_draft` `pr_merged` `pr_closed`
`review_approved` `review_changes` `review_pending` `dirty` `staged`
`untracked` `ahead` `behind` `stash` `branch_prefix` `prompt_char`.

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

**Boxes (□) or blanks instead of icons.** Font detection guessed wrong. Run
`zgp-font-check --no` to pin the geometric set, then `exec zsh`. To get the
glyphs instead, install a patched font
(`brew install --cask font-jetbrains-mono-nerd-font`), select it in your
terminal, and run `zgp-font-check`.

**Prompt feels slow.** The git flag calls are the only synchronous work. In very
large repos, `ZGP_SHOW_UNTRACKED=0` is usually the biggest win.

**Prompt doesn't refresh on its own.** Something else in your config may already
define `TRAPUSR1`; the plugin deliberately does not override it. Either remove
that handler or set `ZGP_ASYNC_REDRAW=0` and accept a one-prompt lag.

## License

MIT — see [LICENSE](LICENSE).
