# Modern development environment: design

Date: 2026-10-15
Status: awaiting review

## Intent

Turn this repository into a modern, opinionated macOS development environment
built from popular community tools, while keeping the existing strengths:
portable across Intel and Apple Silicon, installed by `bootstrap.zsh`, backed up
by `install.zsh`, Homebrew as the package source, and secrets kept out of the
repository in `~/.zshrc.local`.

The owner is happy to change their workflow to suit newer tools and is not tied
to the macOS originals. Most Git work happens in Tower today; the terminal Git
experience should be easy enough that lazygit can replace Tower.

### Success criteria

- Every tool in this design installs from `./bootstrap.zsh` on a clean Mac
  (Intel or Apple Silicon) with no manual step except those listed under
  "Manual steps".
- Interactive shell startup is under 150 ms on this Mac, measured by
  `shell-bench`. Baseline before this work: 0.62-0.95 s (5 runs of
  `zsh -i -c exit`, 2026-10-15), so startup work is a required part of this
  change, not an optional extra.
- Every tool shares the Catppuccin Mocha theme.
- Scripts and non-interactive shells behave exactly as before: command
  takeovers apply to interactive shells only.
- `install.zsh` keeps backing up every file it replaces and recording created
  files, so the change can be rolled back.

### Decisions taken

| Decision | Choice |
|---|---|
| Structure | Split `config/zshrc` into modules under `config/zsh/` |
| Plugin source | Homebrew, plus one pinned `fzf-tab` clone; no framework, no antidote (revisit if a third GitHub-only plugin is wanted) |
| Command takeovers | Take over every command a modern tool replaces, including those with incompatible syntax |
| History | Atuin for Ctrl-R, local only, no sync, no network calls |
| Git UI | lazygit replaces Tower |
| Pull strategy | `pull.rebase = true` with `rebase.autoStash` |
| Editor | VS Code |
| Font | JetBrains Mono Nerd Font |
| Theme | Catppuccin Mocha everywhere |

### Accepted trade-off

Commands copied from documentation that use original syntax for `find`, `sed`,
`ps`, `grep`, `du`, `df` or `dig` will fail or behave differently. The owner has
accepted this. The original is always reachable with `command <name>` or
`\<name>`, and the README says so at the top of the command table.

## Structure

`config/zshrc` becomes a short loader that sources, in order:

| Module | Contents |
|---|---|
| `config/zsh/env.zsh` | Homebrew resolution, `PATH`/`fpath`, `EDITOR`/`VISUAL`, `MANPAGER`, `BAT_THEME`, fzf defaults |
| `config/zsh/options.zsh` | History and directory options |
| `config/zsh/completion.zsh` | Cached `compinit`, zstyles |
| `config/zsh/plugins.zsh` | fzf-tab, autosuggestions (syntax highlighting stays last in `zshrc`) |
| `config/zsh/keybindings.zsh` | Emacs mode, history search, word movement, edit-command-line |
| `config/zsh/tools.zsh` | Activation of mise, zoxide, fzf, Atuin, Starship |
| `config/zsh/aliases.zsh` | Command takeovers and short aliases |
| `config/zsh/git.zsh` | Git aliases and `ghpr` |
| `config/zsh/functions.zsh` | `mkcd`, `croot`, `extract`, `path`, `reload`, `shell-bench`, `shell-doctor` |

Order inside `zshrc`: env, options, completion, plugins, keybindings, tools,
functions, git, aliases, Starship, `~/.zshrc.local`, then
zsh-syntax-highlighting last (it must wrap every widget defined earlier).

zsh expands aliases when a function is defined, so the takeover aliases load
after every function in this repository. Functions in the modules still call
`command <name>` for any command that has a takeover, so the original syntax is
guaranteed regardless of load order.

Every module guards tool-specific lines with `(( $+commands[tool] ))`, so a
missing tool degrades to the macOS original rather than an error.

`install.zsh` copies `config/zsh/` to `~/.config/zsh/` and the new tool configs
listed below, with the same backup and `existing`/`created` records as today.

## Section 1: modern CLI tools

Brewfile additions: `eza`, `fd`, `dust`, `duf`, `procs`, `sd`, `doggo`, `jq`,
`tlrc`, `btop`, `atuin`, `cask "font-jetbrains-mono-nerd-font"`.

Takeovers (interactive only, each guarded by the tool being installed):

| Command | Replacement |
|---|---|
| `ls` | `eza --group-directories-first --icons=auto`; plus `ll` (long, all, Git status), `la`, `lt` (tree, 2 levels) |
| `cat` | `bat --paging=never` (`catc` removed) |
| `top` | `btop` |
| `cd` | zoxide via `zoxide init zsh --cmd cd` (`cd` and `cdi`) |
| `diff` | `delta` |
| `du` | `dust` |
| `df` | `duf` |
| `ps` | `procs` |
| `find` | `fd` |
| `grep` | `rg` |
| `sed` | `sd` |
| `dig` | `doggo` |

`man` is unchanged but uses bat as `MANPAGER`. `CLICOLOR`/`LSCOLORS` stay as the
fallback when eza is missing. `shell-doctor` lists which takeovers are active.

## Section 2: shell productivity

**Atuin** replaces Ctrl-R. Config at `~/.config/atuin/config.toml`:
`auto_sync = false`, `update_check = false`, `secrets_filter = true`, up-arrow
binding disabled (`atuin init zsh --disable-up-arrow`). `~/.zsh_history` keeps
being written. The up arrow keeps prefix search.

**fzf**: `FZF_DEFAULT_COMMAND` and `FZF_CTRL_T_COMMAND` use
`fd --hidden --exclude .git` (respects `.gitignore`); Ctrl-T previews with bat;
Option-C uses `fd --type d` and previews with `eza --tree`; colours from
Catppuccin Mocha.

**fzf-tab**: cloned by `bootstrap.zsh` into `~/.local/share/zsh/fzf-tab` at a
pinned commit recorded in the script, checked out by hash. Previews: directory
contents with eza, file contents with bat, Git branches with `git log`,
processes with `command ps` output.

**Completion**: `compinit` rebuilds its dump at most once every 24 hours,
otherwise runs `compinit -C`. Security checks stay on for the daily rebuild
(`-i`, as today).

**Options**: add `EXTENDED_HISTORY`, `HIST_VERIFY`, `AUTO_PUSHD`,
`PUSHD_IGNORE_DUPS`, `PUSHD_SILENT`; keep every existing option.

**Keybindings**: Ctrl-X Ctrl-E (`edit-command-line` in `$EDITOR`),
Option-Left/Right word movement, Option-Backspace delete word, Ctrl-Z toggles
back to a suspended job. Existing bindings unchanged.

**Helpers**: `..`, `...`, `....`, `reload` (`exec zsh`), `extract`, `path`, and
`shell-bench` (time 10 interactive starts, print mean and max). `mkcd`, `croot`,
`shell-doctor` stay.

**Startup**: reach the 150 ms target. Expected contributors to check with
`zprof`: uncached `compinit`, repeated `brew shellenv` (already done in
`.zprofile` for login shells), and `eval` of tool init scripts. Cache generated
init scripts (mise, zoxide, Atuin, Starship, fzf) to files regenerated when the
tool binary is newer than the cache, if measurement shows they matter.

## Section 3: Git workflow

**Delta** (`config/git-tools`): dark (`light = false`), Catppuccin Mocha syntax
theme, `hyperlinks = true` with
`hyperlinks-file-link-format = "vscode://file/{path}:{line}"`, `navigate`,
`line-numbers`, zdiff3-friendly merge conflict display.

**Git defaults** in the included `shell-tools.gitconfig` (identity and
credentials untouched): `push.autoSetupRemote`, `fetch.prune`, `pull.rebase`,
`rebase.autoStash`, `rebase.autosquash`, `rerere.enabled`,
`diff.algorithm = histogram`, `merge.conflictStyle = zdiff3`,
`branch.sort = -committerdate`, `init.defaultBranch = main`, `commit.verbose`,
`help.autocorrect = prompt`. No `core.editor`; Git uses `$EDITOR`.

**Aliases**: keep `gs`, `gd`, `gds`, `gl`; add `ga`, `gc`, `gco`, `gsw`, `gb`,
`gp`, `gpl`, `grb`, `gst`, `gcp`. `lg` stays; add `gg` for lazygit.

**lazygit** (Tower replacement): config installed to
`~/Library/Application Support/lazygit/config.yml` with delta as pager,
Catppuccin Mocha colours, Nerd Font icons, VS Code as editor, mouse events on.
README gets a "Tower to lazygit" quick reference: stage file/line, commit,
amend, push/pull, branch switch, interactive rebase (reorder, squash, fixup,
drop), cherry-pick, stash, undo.

**gh**: no extensions installed. `ghpr` lists open PRs with `gh pr list` in fzf
and checks out the selection with `gh pr checkout`.

**Commit signing**: README documents SSH signing (`gpg.format = ssh`,
`user.signingkey`, `commit.gpgsign`) for the owner's own `~/.gitconfig`; not
enabled by the installer.

Dropped: fzf Git helpers (`gbf`, `glf`, `gaf`), since lazygit covers them.

## Section 4: terminal and editor

**Ghostty** (`config/ghostty.config`):
`font-family = JetBrainsMono Nerd Font`, `font-size = 14`,
`theme = Catppuccin Mocha` (exact name verified with `ghostty +list-themes`),
`shell-integration-features = cursor,sudo,title`, `copy-on-select = clipboard`,
`mouse-hide-while-typing = true`, `window-save-state = always`,
`macos-titlebar-style = tabs`, quick terminal on global Cmd-backtick. Existing
padding, Option-as-Alt and shell command kept. Split shortcuts documented, not
changed.

**Theme across tools**: Catppuccin theme files for bat, delta, btop, eza and
lazygit are vendored into `config/themes/` from the official Catppuccin
repositories at a recorded commit, reviewed in the PR, and installed by
`install.zsh`. Nothing is fetched at install time. Starship gets a
`palette = 'catppuccin_mocha'` palette block and its module styles move to
palette names; the no-dimmed-text rule stays. fzf colours are set in
`FZF_DEFAULT_OPTS`. eza uses the vendored Catppuccin `theme.yml` installed to
`~/.config/eza/`. The `LSCOLORS` fallback keeps its current values.

**VS Code**: `EDITOR`/`VISUAL` = `code --wait` when the `code` command exists
and the session is not over SSH, otherwise `vim`. `PATH` gains
`/Applications/Visual Studio Code.app/Contents/Resources/app/bin` when present.
Not added to the Brewfile (an existing non-Homebrew install would make
`brew bundle` fail). Aliases `c.` (open folder in VS Code) and `o.` (open
folder in Finder).

## Manual steps (documented in the README)

- Install VS Code on a new Mac.
- Set VS Code `terminal.integrated.fontFamily` to `JetBrainsMono Nerd Font`.
- Grant Ghostty Accessibility permission for the global quick terminal.
- Optional: SSH commit signing in `~/.gitconfig`.

## Testing

- `zsh -n` on every module and on `zshrc`.
- `shell-bench` before and after; result under 150 ms.
- Non-interactive check: `zsh -c 'type ls find'` reports the system binaries.
- Interactive check: `zsh -i -c 'type ls find cat'` reports the aliases.
- Fallback check: with a tool removed from `PATH`, the shell starts without
  errors and the original command runs.
- `install.zsh` run against a scratch `HOME` to confirm every destination is
  backed up or recorded as created.
- Manual visual check in Ghostty and VS Code terminal: theme, icons, prompt.

## Out of scope

- Oh My Zsh, antidote or any plugin framework.
- History sync of any kind.
- gh extensions.
- Editing VS Code settings files.
- Changing macOS defaults or app associations.
