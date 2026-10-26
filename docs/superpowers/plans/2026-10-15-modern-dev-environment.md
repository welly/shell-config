# Modern Development Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the shell-config repository into a modern macOS development environment: modern CLI tools taking over familiar commands, Atuin history, fzf-tab completion, Git defaults with lazygit as the Tower replacement, and Catppuccin Mocha across Ghostty, Starship and every tool, with interactive startup under 150 ms.

**Architecture:** `config/zshrc` becomes a short loader that sources focused modules from `~/.config/zsh/` (env, options, completion, plugins, keybindings, tools, functions, git, aliases). `install.zsh` keeps copying files with backups, now including the modules and the new tool configs. A small zsh test suite under `tests/` runs every check against a throwaway `HOME`, so tests never touch the real one.

**Tech Stack:** zsh, Homebrew (Brewfile), Starship, Ghostty, fzf, fzf-tab, Atuin, zoxide, eza, bat, fd, ripgrep, delta, lazygit, Catppuccin Mocha.

**Spec:** `docs/superpowers/specs/2026-10-15-modern-dev-environment-design.md`. Read it before starting; this plan argues from it.

## Global Constraints

- Platform: macOS on Intel and Apple Silicon; zsh only. Every path to Homebrew goes through `$HOMEBREW_PREFIX`, never a hard-coded `/opt/homebrew`.
- Package source: Homebrew (Brewfile). Exceptions: the `fzf-tab` clone pinned to a commit, and Catppuccin theme files vendored into `config/themes/` at a recorded commit. Nothing else is fetched at install time.
- Command takeovers apply to interactive shells only, and each is guarded by `(( $+commands[tool] ))` so a missing tool falls back to the macOS original with no error.
- Functions in this repository call `command <name>` for any command that has a takeover (`ls cat top cd diff du df ps find grep sed dig`).
- Load order in `zshrc`: env, options, completion, plugins, keybindings, tools, functions, git, aliases, Starship, `~/.zshrc.local`, zsh-syntax-highlighting last.
- Atuin: `auto_sync = false`, `update_check = false`, `secrets_filter = true`, `--disable-up-arrow`. No account, no sync.
- `install.zsh` backs up every destination it replaces into `~/.shell-backups/<timestamp>/` and records it in `existing` or `created`.
- Startup: mean of 10 runs of `zsh -i -c exit` under 150 ms on the owner's Mac.
- Theme: Catppuccin Mocha everywhere, accent blue. No `dimmed` styles anywhere.
- Secrets never enter the repository; personal settings stay in `~/.zshrc.local`.
- **Claude never commits.** A hook denies `git commit`. At each "Stage" step the executor runs `git add` and stops; the owner runs the commit with the given message. Commit messages carry no AI attribution trailer.
- Network fetches in this plan (each listed in its task, approved with the plan): `git clone` of `Aloxaf/fzf-tab`; `gh api` and `curl` from `raw.githubusercontent.com` for `catppuccin/delta`, `catppuccin/btop`, `catppuccin/eza` and `catppuccin/lazygit`; `brew bundle`.

## Review Focus

1. **A takeover tool is missing** (new Mac part-way through bootstrap, or a tool uninstalled): the shell starts with empty stderr and `ls`, `cat`, `find` run the originals. Test: `tests/test_fallback.zsh` in Task 3.
2. **Repository functions that call takeover names**: `extract`, `shell-doctor` and the rest must keep original syntax. Test: `tests/test_functions_use_originals.zsh` in Task 3, extended in Task 4.
3. **Running `install.zsh` twice, or over an older install**: every run makes a backup, the Git include is not duplicated, and the `btop.conf` theme line is set once. Tests: `tests/test_install.zsh` in Task 0, extended in Tasks 1 and 8.
4. **Stale init cache after a tool upgrade or a change to `tools.zsh`**: the cache regenerates. Test: `tests/test_startup_cache.zsh` in Task 2.
5. **Shells that are not a local terminal** (SSH sessions, `zsh -i -c` from scripts or VS Code tasks): empty stderr, and `EDITOR` falls back to `vim` over SSH. Tests: `tests/test_shell_starts.zsh` (Task 0), `tests/test_editor.zsh` (Task 10).

---

## File Structure

| Path | Responsibility |
|---|---|
| `config/zshrc` | Loader: interactive guard, module loop, Starship, `~/.zshrc.local`, syntax highlighting |
| `config/zsh/env.zsh` | Homebrew, `PATH`/`fpath`, `EDITOR`/`VISUAL`, pagers, theme and fzf variables |
| `config/zsh/options.zsh` | History and directory options |
| `config/zsh/completion.zsh` | Cached `compinit` and completion styles |
| `config/zsh/plugins.zsh` | fzf-tab and zsh-autosuggestions |
| `config/zsh/keybindings.zsh` | Key bindings and small ZLE widgets |
| `config/zsh/tools.zsh` | `_cached_init` helper; mise, zoxide, fzf, Atuin |
| `config/zsh/functions.zsh` | `mkcd`, `croot`, `extract`, `path`, `reload`, `shell-bench`, `shell-doctor` |
| `config/zsh/git.zsh` | Git aliases, `ghpr` |
| `config/zsh/aliases.zsh` | Command takeovers and general aliases |
| `config/atuin.toml` | Atuin config |
| `config/lazygit.yml` | lazygit config |
| `config/themes/` | Vendored Catppuccin files plus `SOURCES.md` |
| `config/git-tools` | Git and delta defaults (installed as `shell-tools.gitconfig`) |
| `config/starship.toml` | Prompt, on the Catppuccin palette |
| `config/ghostty.config` | Ghostty |
| `install.zsh` | Copies config with backups; builds bat cache; sets the btop theme |
| `install-plugins.zsh` | Clones fzf-tab at the pinned commit (new) |
| `bootstrap.zsh` | Calls `install-plugins.zsh` |
| `Brewfile` | New tools and the font |
| `tests/lib.zsh`, `tests/run.zsh`, `tests/test_*.zsh`, `tests/bench.zsh` | Test suite (new) |
| `README.md` | User documentation |

---

### Task 0: Branch, test harness and baseline

**Files:**
- Create: `tests/lib.zsh`, `tests/run.zsh`, `tests/test_install.zsh`, `tests/test_shell_starts.zsh`

**Interfaces:**
- Produces: `tests/lib.zsh` with `$REPO`, `$SANDBOX`, `fail MSG`, `assert_eq ACTUAL EXPECTED [MSG]`, `assert_contains HAYSTACK NEEDLE [MSG]`, `assert_not_contains HAYSTACK NEEDLE [MSG]`, `make_sandbox`, `sbx_i CMD` (interactive shell in sandbox; stdout returned, stderr in `$SANDBOX/stderr`), `sbx_c CMD` (non-interactive), `finish`. Every later test uses these.

- [ ] **Step 1: Create the branch**

```bash
git switch -c modern-env
```

- [ ] **Step 2: Write the test library**

`tests/lib.zsh`:

```zsh
# Shared helpers for the shell-config tests. Tests run against a throwaway HOME.
REPO=${${(%):-%x}:A:h:h}
typeset -gi TEST_FAILS=0
typeset -g SANDBOX=''

fail() { print -u2 -r -- "FAIL: $*"; (( TEST_FAILS++ )); }
assert_eq() { [[ $1 == "$2" ]] || fail "${3:-assert_eq}: expected [$2] got [$1]"; }
assert_contains() { [[ $1 == *"$2"* ]] || fail "${3:-assert_contains}: [$2] not in [$1]"; }
assert_not_contains() { [[ $1 != *"$2"* ]] || fail "${3:-assert_not_contains}: [$2] found in [$1]"; }

# Create a sandbox HOME and run the installer into it.
make_sandbox() {
  SANDBOX=$(command mktemp -d "${TMPDIR:-/tmp}/shell-config-test.XXXXXX")
  command mkdir -p "$SANDBOX/home"
  HOME=$SANDBOX/home "$REPO/install.zsh" >"$SANDBOX/install.log" 2>&1 \
    || fail "install.zsh failed: $(<$SANDBOX/install.log)"
}

# Interactive shell in the sandbox. Extra environment can be passed with `env` in CMD.
sbx_i() { HOME=$SANDBOX/home XDG_CACHE_HOME= XDG_CONFIG_HOME= XDG_DATA_HOME= ZDOTDIR= zsh -i -c "$1" 2>"$SANDBOX/stderr"; }
sbx_c() { HOME=$SANDBOX/home ZDOTDIR= zsh -c "$1" 2>"$SANDBOX/stderr"; }

finish() {
  [[ -n $SANDBOX && -d $SANDBOX ]] && command rm -rf -- "$SANDBOX"
  exit $(( TEST_FAILS > 0 ))
}
```

- [ ] **Step 3: Write the runner**

`tests/run.zsh` (make executable with `chmod +x tests/run.zsh`):

```zsh
#!/bin/zsh
# Run every tests/test_*.zsh in its own zsh process.
set -u
root=${0:A:h}
failed=0
for t in $root/test_*.zsh(N); do
  if zsh "$t"; then
    print -r -- "ok   ${t:t}"
  else
    print -r -- "FAIL ${t:t}"
    failed=1
  fi
done
exit $failed
```

- [ ] **Step 4: Write characterisation tests for today's behaviour**

`tests/test_install.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
for f in .zshrc .zprofile .config/starship.toml .config/ghostty/config.ghostty .config/git/shell-tools.gitconfig; do
  [[ -f $SANDBOX/home/$f ]] || fail "not installed: $f"
done

# A second run backs up what the first run installed.
command sleep 1   # backup directories are named by the second
HOME=$SANDBOX/home "$REPO/install.zsh" >/dev/null 2>&1 || fail "second install failed"
records=($SANDBOX/home/.shell-backups/*/existing(N))
(( $#records >= 1 )) || fail "second install wrote no existing record"
assert_contains "$(<${records[-1]})" ".zshrc" "second install backed up .zshrc"

count=$(HOME=$SANDBOX/home git config --global --get-all include.path | command grep -c shell-tools)
assert_eq "$count" 1 "shell-tools include is not duplicated"
finish
```

`tests/test_shell_starts.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
assert_eq "$(sbx_i 'print -r -- ok')" ok "interactive shell runs"
assert_eq "$(<$SANDBOX/stderr)" "" "interactive shell stderr is empty"
for a in gs gd gds gl ll dc dps lg; do
  assert_contains "$(sbx_i "alias $a")" "$a=" "alias $a defined"
done
for fn in mkcd croot shell-doctor; do
  assert_eq "$(sbx_i "(( \$+functions[$fn] )) && print yes")" yes "function $fn defined"
done
assert_contains "$(sbx_c 'whence -p ls')" "/bin/ls" "non-interactive ls is the system binary"
assert_eq "$(sbx_c 'alias ls')" "" "non-interactive shell has no ls alias"
finish
```

- [ ] **Step 5: Run the suite on the current config**

Run: `zsh tests/run.zsh`
Expected: `ok   test_install.zsh` and `ok   test_shell_starts.zsh`. These describe today's behaviour, so they must pass before any change. If either fails, fix the test, not the config, and note why in the task report.

- [ ] **Step 6: Stage**

```bash
git add tests/
```

Owner commits: `git commit -m "Add shell config test harness"`

---

### Task 1: Split zshrc into modules

Behaviour-preserving refactor. Task 0's tests must stay green.

**Files:**
- Modify: `config/zshrc` (rewrite as loader), `install.zsh` (install modules)
- Create: `config/zsh/{env,options,completion,plugins,keybindings,tools,functions,git,aliases}.zsh`
- Modify: `tests/test_install.zsh`

**Interfaces:**
- Consumes: Task 0 test helpers.
- Produces: the module files and load order every later task edits; `install.zsh`'s `pairs` array (later tasks append to it as `'source-under-config:dest-under-home'`).

- [ ] **Step 1: Add the failing test**

Append to `tests/test_install.zsh` before `finish`:

```zsh
for m in env options completion plugins keybindings tools functions git aliases; do
  [[ -f $SANDBOX/home/.config/zsh/$m.zsh ]] || fail "module not installed: $m.zsh"
done
```

- [ ] **Step 2: Run it to see it fail**

Run: `zsh tests/test_install.zsh`
Expected: FAIL lines `module not installed: env.zsh` (and the rest).

- [ ] **Step 3: Create the modules by moving existing lines**

`config/zsh/env.zsh`:

```zsh
# Environment: Homebrew, search paths.

# Resolve Homebrew for interactive shells that aren't login shells, too.
if [[ -z $HOMEBREW_PREFIX ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

typeset -U path fpath
[[ -d "$HOME/.config/zsh/completions" ]] && fpath=("$HOME/.config/zsh/completions" $fpath)
path=("$HOME/.local/bin" "$HOME/.docker/bin" $path)
[[ -d "$HOMEBREW_PREFIX/share/zsh/site-functions" ]] && fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
[[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)
```

`config/zsh/options.zsh`:

```zsh
# History and shell options.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt AUTO_CD INTERACTIVE_COMMENTS
unsetopt BEEP
```

`config/zsh/completion.zsh`:

```zsh
# Completion security checks remain enabled; skip insecure directories.
autoload -Uz compinit
compinit -i
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%B%d%b'
```

`config/zsh/plugins.zsh`:

```zsh
# Plugins from Homebrew. Syntax highlighting loads last, from zshrc.
[[ -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
```

`config/zsh/keybindings.zsh`:

```zsh
# Emacs key bindings with prefix history search on the arrow keys.
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^R' history-incremental-search-backward
```

`config/zsh/tools.zsh`:

```zsh
# One runtime manager; reads project versions after setup.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi
if [[ -o zle && -t 0 && -t 1 ]] && (( $+commands[fzf] )); then
  eval "$(fzf --zsh)"
fi
```

`config/zsh/functions.zsh`:

```zsh
# Shell helpers. Call `command <name>` for any command with a takeover alias.
mkcd() { [[ $# -eq 1 ]] || { print -u2 'Usage: mkcd directory'; return 2; }; command mkdir -p -- "$1" && builtin cd -- "$1"; }

croot() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { print -u2 'Not inside a Git repository'; return 1; }
  builtin cd -- "$root"
}

shell-doctor() {
  print -- "zsh: $ZSH_VERSION; config: ${ZDOTDIR:-$HOME}; terminal: $TERM"
  local tool
  for tool in brew starship mise node fzf zoxide bat rg git gh lazygit delta ddev docker; do
    if (( $+commands[$tool] )); then
      print -- "$tool: ${commands[$tool]}"
    else
      print -- "$tool: missing"
    fi
  done
}
```

`config/zsh/git.zsh`:

```zsh
# Git shortcuts. lazygit is the main Git interface.
alias gs='git status --short --branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias lg='lazygit'
```

`config/zsh/aliases.zsh`:

```zsh
# macOS ls colours; bold cyan directories instead of the default dark blue.
export CLICOLOR=1
export LSCOLORS='Gxfxcxdxbxegedabagacad'

alias ll='ls -lah'
alias dc='docker compose'
alias dps='docker ps'
alias dd='ddev'
alias dphp='ddev php'
alias dcomposer='ddev composer'
alias dnpm='ddev npm'
alias dssh='ddev ssh'
alias catc='bat --paging=never'
```

- [ ] **Step 4: Rewrite `config/zshrc` as the loader**

```zsh
# Interactive development shell. Portable macOS configuration.
[[ -o interactive ]] || return

# Modules load in this order; aliases load after every function so zsh does not
# expand takeover aliases inside function bodies.
for _module in env options completion plugins keybindings tools functions git aliases; do
  [[ -r "$HOME/.config/zsh/$_module.zsh" ]] && source "$HOME/.config/zsh/$_module.zsh"
done
unset _module

if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
else
  PROMPT='%F{cyan}%~%f %# '
fi

# Personal overrides; keep tokens out of this workspace.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Syntax highlighting must be loaded after other widgets and plugins.
[[ -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
```

- [ ] **Step 5: Install the modules**

In `install.zsh`, replace the `for pair in '...' ...; do` header line with:

```zsh
pairs=(
  'zprofile:.zprofile'
  'zshrc:.zshrc'
  'starship.toml:.config/starship.toml'
  'ghostty.config:.config/ghostty/config.ghostty'
  'git-tools:.config/git/shell-tools.gitconfig'
)
for module in "$root"/config/zsh/*.zsh; do
  pairs+=("zsh/${module:t}:.config/zsh/${module:t}")
done
for pair in $pairs; do
```

The loop body is unchanged: it already copies `"$root/config/$src"` to `"$HOME/$dest"` and creates `"$HOME/${dest:h}"`.

- [ ] **Step 6: Run the suite**

Run: `zsh -n config/zshrc config/zsh/*.zsh install.zsh && zsh tests/run.zsh`
Expected: no syntax output; `ok` for both test files.

- [ ] **Step 7: Stage**

```bash
git add config/zshrc config/zsh install.zsh tests/test_install.zsh
```

Owner commits: `git commit -m "Split zshrc into focused modules"`

---

### Task 2: Fast startup (cached compinit, cached tool init, shell-bench)

**Files:**
- Modify: `config/zsh/completion.zsh`, `config/zsh/tools.zsh`, `config/zsh/functions.zsh`, `config/zshrc` (Starship via cache)
- Create: `tests/test_startup_cache.zsh`, `tests/bench.zsh`

**Interfaces:**
- Produces: `_cached_init NAME COMMAND...` in `tools.zsh`. It returns 1 if COMMAND's binary is missing; otherwise it sets `REPLY` to `${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init-NAME.zsh`, regenerating it when missing, older than the binary, or older than `tools.zsh`. The caller runs `source $REPLY` at top level. Tasks 3, 5 and `zshrc` use it. Also produces `shell-bench [RUNS]`, which prints `mean N ms, max N ms over R runs`.

- [ ] **Step 1: Measure the baseline**

Run: `for i in {1..5}; do /usr/bin/time -p zsh -i -c exit 2>&1 | awk '/real/{print $2}'; done`
Record the numbers in the task report. The spec baseline was 0.62-0.95 s.

Then profile, with a temporary ZDOTDIR that loads zprof before the real `~/.zshrc`:

```bash
prof=$(mktemp -d); printf 'zmodload zsh/zprof\nsource ~/.zshrc\n' > $prof/.zshrc; ZDOTDIR=$prof zsh -i -c 'zprof | head -20'; rm -r $prof
```

Record the top five entries in the task report.

- [ ] **Step 2: Write the failing test**

`tests/test_startup_cache.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
cache=$SANDBOX/home/.cache/zsh
sbx_i 'true' >/dev/null
assert_eq "$(<$SANDBOX/stderr)" "" "first start stderr is empty"
dumps=($cache/zcompdump-*(N))
(( $#dumps == 1 )) || fail "compinit dump not cached in $cache"
for tool in zoxide starship; do
  (( $+commands[$tool] )) || continue
  [[ -s $cache/init-$tool.zsh ]] || fail "init-$tool.zsh not cached"
done

# A stale cache regenerates.
if [[ -s $cache/init-starship.zsh ]]; then
  command touch -t 200001010000 $cache/init-starship.zsh
  sbx_i 'true' >/dev/null
  year=$(command stat -f %Sm -t %Y $cache/init-starship.zsh)
  [[ $year != 2000 ]] || fail "stale starship init was not regenerated"
fi

# shell-bench reports a mean.
assert_contains "$(sbx_i 'shell-bench 2')" "mean " "shell-bench output"
finish
```

- [ ] **Step 3: Run it to see it fail**

Run: `zsh tests/test_startup_cache.zsh`
Expected: FAIL `compinit dump not cached`, `init-zoxide.zsh not cached`, and the `shell-bench output` failure.

- [ ] **Step 4: Cache compinit**

Replace the first two code lines of `config/zsh/completion.zsh` (`autoload -Uz compinit` and `compinit -i`) with:

```zsh
autoload -Uz compinit
_zcompdump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION
[[ -d ${_zcompdump:h} ]] || command mkdir -p -- ${_zcompdump:h}
_zcompdump_stale=($_zcompdump(N.mh+24))
if [[ -s $_zcompdump && -z $_zcompdump_stale ]]; then
  compinit -C -d $_zcompdump
else
  # Daily full rebuild keeps the security check; skip insecure directories.
  compinit -i -d $_zcompdump
fi
unset _zcompdump _zcompdump_stale
```

- [ ] **Step 5: Cache tool init scripts**

Replace `config/zsh/tools.zsh` with:

```zsh
# Tool activation. Generated init scripts are cached; a cache regenerates when
# the tool binary or this file is newer than it.
_shell_tools_file=${(%):-%x}

# Usage: _cached_init NAME COMMAND... && source $REPLY
_cached_init() {
  local name=$1; shift
  local bin=${commands[$1]}
  [[ -n $bin ]] || return 1
  REPLY=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init-$name.zsh
  if [[ ! -s $REPLY || $bin -nt $REPLY || $_shell_tools_file -nt $REPLY ]]; then
    command mkdir -p -- ${REPLY:h}
    "$@" >| $REPLY || { command rm -f -- $REPLY; return 1; }
  fi
}

# One runtime manager; reads project versions after setup.
_cached_init mise mise activate zsh && source $REPLY
_cached_init zoxide zoxide init zsh && source $REPLY
if [[ -o zle && -t 0 && -t 1 ]]; then
  _cached_init fzf fzf --zsh && source $REPLY
fi
```

In `config/zshrc`, replace `eval "$(starship init zsh)"` with:

```zsh
  _cached_init starship starship init zsh && source $REPLY
```

`_cached_init` is still defined at that point, because `tools.zsh` loaded earlier.

- [ ] **Step 6: Add shell-bench**

Append to `config/zsh/functions.zsh`:

```zsh
# Time interactive shell startup.
shell-bench() {
  local -i runs=${1:-10} i
  local -F start ms total=0 max=0
  zmodload -F zsh/datetime p:EPOCHREALTIME
  for (( i = 0; i < runs; i++ )); do
    start=$EPOCHREALTIME
    zsh -i -c exit >/dev/null 2>&1
    ms=$(( (EPOCHREALTIME - start) * 1000 ))
    (( total += ms ))
    (( ms > max )) && max=$ms
  done
  printf 'mean %.0f ms, max %.0f ms over %d runs\n' $(( total / runs )) $max $runs
}
```

`tests/bench.zsh` (machine-specific, so not part of `run.zsh`):

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
sbx_i true >/dev/null   # warm the caches
out=$(sbx_i 'shell-bench 10')
print -r -- "$out"
mean=${${out#mean }%% ms*}
(( mean < 150 )) || fail "mean startup ${mean} ms is not under 150 ms"
finish
```

- [ ] **Step 7: Run the tests**

Run: `zsh tests/run.zsh && zsh tests/bench.zsh`
Expected: all `ok`. The bench prints the mean; record it. If it's still 150 ms or more, run the profile from Step 1 again and fix the top entry before moving on. Likely culprits are `mise activate`, which can be swapped for `mise activate zsh --shims` if mise's hook dominates, and `/etc/zshrc`. Note what was changed in the task report.

- [ ] **Step 8: Stage**

```bash
git add config/zsh config/zshrc tests/test_startup_cache.zsh tests/bench.zsh
```

Owner commits: `git commit -m "Cache completion and tool init for fast startup"`

---

### Task 3: Modern CLI tools take over

**Files:**
- Modify: `Brewfile`, `config/zsh/aliases.zsh`, `config/zsh/env.zsh`, `config/zsh/tools.zsh`, `config/zsh/functions.zsh`
- Create: `tests/test_takeovers.zsh`, `tests/test_fallback.zsh`, `tests/test_functions_use_originals.zsh`

**Interfaces:**
- Consumes: `_cached_init` (Task 2).
- Produces: the takeover alias set and the `cd` function from zoxide. `shell-doctor` prints a line per takeover in the form `NAME -> TOOL` or `NAME: original`.

- [ ] **Step 1: Install the tools**

Add to `Brewfile` under `# Navigation, search and Git`:

```ruby
brew "eza"
brew "fd"
brew "dust"
brew "duf"
brew "procs"
brew "sd"
brew "doggo"
brew "jq"
brew "tlrc"
brew "btop"
```

Run: `brew bundle --file=Brewfile`
Expected: each formula installs or reports `Using`.

- [ ] **Step 2: Write the failing tests**

`tests/test_takeovers.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
typeset -A want=(
  ls eza cat bat top btop diff delta du dust df duf
  ps procs find fd grep rg sed sd dig doggo
)
for name tool in ${(kv)want}; do
  (( $+commands[$tool] )) || { print "skip $name ($tool not installed)"; continue; }
  assert_contains "$(sbx_i "alias $name")" "$tool" "$name takes over with $tool"
done
assert_eq "$(sbx_i 'whence -w cd')" "cd: function" "cd is zoxide's function"
assert_eq "$(<$SANDBOX/stderr)" "" "stderr empty"
for a in ll la lt; do
  assert_contains "$(sbx_i "alias $a")" "eza" "$a uses eza"
done
assert_contains "$(sbx_i 'shell-doctor')" "ls -> eza" "shell-doctor lists takeovers"
assert_contains "$(sbx_c 'whence -p find')" "/usr/bin/find" "scripts keep find"
finish
```

`tests/test_fallback.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
# No Homebrew on PATH from the first line of startup: every takeover must fall back silently.
out=$(HOMEBREW_PREFIX=/nonexistent PATH=/usr/bin:/bin:/usr/sbin:/sbin sbx_i 'alias ls; alias cat; alias find; ls -d /')
assert_eq "$(<$SANDBOX/stderr)" "" "stderr empty without Homebrew tools"
assert_not_contains "$out" "eza" "ls not aliased without eza"
assert_contains "$out" "/" "ls runs"
finish
```

`tests/test_functions_use_originals.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
# Function bodies must not contain any replacement tool.
# shell-doctor is excluded: it prints tool names but never runs them.
bodies=$(sbx_i 'functions mkcd croot shell-bench')
for tool in eza 'bat ' btop dust duf procs 'fd ' 'rg ' 'sd ' doggo; do
  assert_not_contains "$bodies" "$tool" "repository functions avoid $tool"
done
finish
```

- [ ] **Step 3: Run them to see them fail**

Run: `zsh tests/test_takeovers.zsh`
Expected: FAIL for each `takes over` assertion and for `cd is zoxide's function`.

- [ ] **Step 4: Write the takeovers**

Replace `config/zsh/aliases.zsh` with:

```zsh
# Modern tools take over familiar names in interactive shells only. Scripts and
# non-interactive shells get the originals. Reach an original with
# `command name` or `\name`.

# macOS ls colours, used when eza is not installed.
export CLICOLOR=1
export LSCOLORS='Gxfxcxdxbxegedabagacad'

if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza --group-directories-first --icons=auto -la --git'
  alias la='eza --group-directories-first --icons=auto -a'
  alias lt='eza --group-directories-first --icons=auto --tree --level=2'
else
  alias ll='ls -lah'
fi
(( $+commands[bat] )) && alias cat='bat --paging=never'
(( $+commands[btop] )) && alias top='btop'
(( $+commands[delta] )) && alias diff='delta'
(( $+commands[dust] )) && alias du='dust'
(( $+commands[duf] )) && alias df='duf'
(( $+commands[procs] )) && alias ps='procs'
(( $+commands[fd] )) && alias find='fd'
(( $+commands[rg] )) && alias grep='rg'
(( $+commands[sd] )) && alias sed='sd'
(( $+commands[doggo] )) && alias dig='doggo'

alias dc='docker compose'
alias dps='docker ps'
alias dd='ddev'
alias dphp='ddev php'
alias dcomposer='ddev composer'
alias dnpm='ddev npm'
alias dssh='ddev ssh'
```

(`catc` is removed; `cat` now does what it did.)

- [ ] **Step 5: zoxide replaces cd; bat renders man pages**

In `config/zsh/tools.zsh`, change the zoxide line to:

```zsh
_cached_init zoxide zoxide init zsh --cmd cd && source $REPLY
```

Append to `config/zsh/env.zsh`:

```zsh
# Colour man pages through bat.
if (( $+commands[bat] )); then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT='-c'
fi
```

- [ ] **Step 6: shell-doctor lists takeovers and new tools**

In `config/zsh/functions.zsh`, replace the `shell-doctor` function with:

```zsh
shell-doctor() {
  print -- "zsh: $ZSH_VERSION; config: ${ZDOTDIR:-$HOME}; terminal: $TERM"
  local tool name
  for tool in brew starship mise node fzf zoxide eza bat fd rg dust duf procs sd doggo jq tldr btop atuin git gh lazygit delta ddev docker code; do
    if (( $+commands[$tool] )); then
      print -- "$tool: ${commands[$tool]}"
    else
      print -- "$tool: missing"
    fi
  done
  print -- '--- takeovers (originals: command NAME)'
  for name in ls cat top diff du df ps find grep sed dig; do
    if (( $+aliases[$name] )); then
      print -- "$name -> ${${aliases[$name]}%% *}"
    else
      print -- "$name: original"
    fi
  done
  if (( $+functions[cd] )); then print -- 'cd -> zoxide'; else print -- 'cd: original'; fi
}
```

- [ ] **Step 7: Run the suite**

Run: `zsh -n config/zsh/*.zsh && zsh tests/run.zsh`
Expected: all `ok`. In `test_shell_starts.zsh`, `lg` is still defined in `git.zsh` and `ll` still exists, so it stays green.

- [ ] **Step 8: Stage**

```bash
git add Brewfile config/zsh tests/
```

Owner commits: `git commit -m "Let modern CLI tools take over familiar commands"`

---

### Task 4: Shell options, key bindings and helpers

**Files:**
- Modify: `config/zsh/options.zsh`, `config/zsh/keybindings.zsh`, `config/zsh/functions.zsh`, `config/zsh/aliases.zsh`, `tests/test_functions_use_originals.zsh`
- Create: `tests/test_productivity.zsh`

**Interfaces:**
- Produces: functions `extract FILE...`, `path`, `reload`; aliases `..`, `...`, `....`; widget `_fg_or_push_input` on Ctrl-Z; `edit-command-line` on Ctrl-X Ctrl-E.

- [ ] **Step 1: Write the failing test**

`tests/test_productivity.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
opts=$(sbx_i 'setopt')
for o in extendedhistory histverify autopushd pushdignoredups pushdsilent sharehistory autocd; do
  assert_contains "$opts" "$o" "option $o set"
done
assert_contains "$(sbx_i "bindkey '^X^E'")" "edit-command-line" "Ctrl-X Ctrl-E"
assert_contains "$(sbx_i "bindkey '^Z'")" "_fg_or_push_input" "Ctrl-Z"
assert_contains "$(sbx_i "bindkey '^[[1;3D'")" "backward-word" "Option-Left"
assert_contains "$(sbx_i "bindkey '^[[1;3C'")" "forward-word" "Option-Right"
for a in .. ... ....; do
  assert_contains "$(sbx_i "alias -- $a")" "cd" "alias $a"
done
assert_contains "$(sbx_i 'path')" "/usr/bin" "path lists entries"

# extract handles tar.gz and zip, and rejects unknown types.
work=$SANDBOX/work; command mkdir -p $work/src && print hi > $work/src/a.txt
( builtin cd $work && command tar -czf a.tar.gz src && command zip -qr b.zip src && command rm -r src )
sbx_i "builtin cd $work && extract a.tar.gz" >/dev/null
[[ -f $work/src/a.txt ]] || fail "extract tar.gz"
command rm -r $work/src
sbx_i "builtin cd $work && extract b.zip" >/dev/null
[[ -f $work/src/a.txt ]] || fail "extract zip"
print x > $work/c.unknown
sbx_i "builtin cd $work && extract c.unknown; print status=\$?" | command grep -q 'status=1' || fail "extract rejects unknown type"
finish
```

Add `extract path reload` to the function list in `tests/test_functions_use_originals.zsh`:

```zsh
bodies=$(sbx_i 'functions mkcd croot shell-bench extract path reload')
```

- [ ] **Step 2: Run it to see it fail**

Run: `zsh tests/test_productivity.zsh`
Expected: FAIL for the options, bindings, aliases, `path` and `extract`.

- [ ] **Step 3: Options**

Append to `config/zsh/options.zsh`:

```zsh
setopt EXTENDED_HISTORY HIST_VERIFY
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
```

- [ ] **Step 4: Key bindings**

Append to `config/zsh/keybindings.zsh`:

```zsh
# Ctrl-X Ctrl-E: edit the current command in $EDITOR.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Option-Left/Right move by word (Ghostty sends these with option-as-alt).
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word
bindkey '^[^?' backward-kill-word

# Ctrl-Z on an empty line resumes the last suspended job; otherwise it parks the line.
_fg_or_push_input() {
  if [[ -z $BUFFER ]]; then
    BUFFER=fg
    zle accept-line
  else
    zle push-input
  fi
}
zle -N _fg_or_push_input
bindkey '^Z' _fg_or_push_input
```

- [ ] **Step 5: Helpers**

Append to `config/zsh/functions.zsh`:

```zsh
# Unpack archives by extension.
extract() {
  (( $# )) || { print -u2 'Usage: extract archive...'; return 2; }
  local f
  for f in "$@"; do
    [[ -f $f ]] || { print -u2 "extract: not a file: $f"; return 1; }
    case ${f:l} in
      *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.zst) command tar -xf "$f" ;;
      *.zip) command unzip -q "$f" ;;
      *.gz) command gunzip -k "$f" ;;
      *.bz2) command bunzip2 -k "$f" ;;
      *.xz) command unxz -k "$f" ;;
      *) print -u2 "extract: unsupported archive: $f"; return 1 ;;
    esac || return
  done
}

# Print PATH one entry per line.
path() { print -rl -- $path; }

# Restart the shell with the current configuration.
reload() { exec zsh; }
```

Append to `config/zsh/aliases.zsh`:

```zsh
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
```

- [ ] **Step 6: Run the suite**

Run: `zsh -n config/zsh/*.zsh && zsh tests/run.zsh`
Expected: all `ok`.

- [ ] **Step 7: Stage**

```bash
git add config/zsh tests/
```

Owner commits: `git commit -m "Add shell options, key bindings and helpers"`

---

### Task 5: Atuin history and fzf defaults

**Files:**
- Create: `config/atuin.toml`, `tests/test_history_fzf.zsh`
- Modify: `Brewfile`, `config/zsh/tools.zsh`, `config/zsh/env.zsh`, `install.zsh`

**Interfaces:**
- Consumes: `_cached_init` (Task 2), `pairs` in `install.zsh` (Task 1).
- Produces: `FZF_DEFAULT_OPTS` (Catppuccin colours), `FZF_DEFAULT_COMMAND`, `FZF_CTRL_T_COMMAND`, `FZF_CTRL_T_OPTS`, `FZF_ALT_C_COMMAND`, `FZF_ALT_C_OPTS`. Task 6's fzf-tab inherits `FZF_DEFAULT_OPTS`.

- [ ] **Step 1: Install Atuin**

Add `brew "atuin"` to `Brewfile` under `# Navigation, search and Git`, then run `brew bundle --file=Brewfile`.

- [ ] **Step 2: Write the failing test**

`tests/test_history_fzf.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
conf=$SANDBOX/home/.config/atuin/config.toml
[[ -f $conf ]] || fail "atuin config not installed"
for line in 'auto_sync = false' 'update_check = false' 'secrets_filter = true'; do
  assert_contains "$(<$conf)" "$line" "atuin: $line"
done
if (( $+commands[atuin] )); then
  assert_contains "$(sbx_i "bindkey '^R'")" "atuin" "Ctrl-R is Atuin"
  assert_contains "$(sbx_i "bindkey '^[[A'")" "up-line-or-beginning-search" "Up arrow unchanged"
fi
assert_eq "$(<$SANDBOX/stderr)" "" "stderr empty"
env_out=$(sbx_i 'print -r -- $FZF_DEFAULT_COMMAND; print -r -- $FZF_ALT_C_COMMAND; print -r -- $FZF_DEFAULT_OPTS')
assert_contains "$env_out" "fd --type f --hidden" "fzf files via fd"
assert_contains "$env_out" "fd --type d --hidden" "fzf dirs via fd"
assert_contains "$env_out" "bg+:#313244" "fzf Catppuccin colours"
finish
```

- [ ] **Step 3: Run it to see it fail**

Run: `zsh tests/test_history_fzf.zsh`
Expected: FAIL `atuin config not installed` and the fzf assertions.

- [ ] **Step 4: Atuin config**

`config/atuin.toml`:

```toml
# Local-only shell history: no account, no sync, no network calls.
auto_sync = false
update_check = false
# Never record commands that look like they contain credentials.
secrets_filter = true

search_mode = "fuzzy"
filter_mode = "global"
style = "compact"
inline_height = 20
# Enter puts the command on the line for review instead of running it.
enter_accept = false
```

Add to the `pairs` array in `install.zsh`:

```zsh
  'atuin.toml:.config/atuin/config.toml'
```

Append to `config/zsh/tools.zsh` (after the fzf block, so Atuin's Ctrl-R wins):

```zsh
# Atuin takes Ctrl-R only; the up arrow keeps prefix search.
_cached_init atuin atuin init zsh --disable-up-arrow && source $REPLY
```

- [ ] **Step 5: Check the Atuin keys against the installed version**

Run: `atuin --version` and then `HOME=$(mktemp -d) zsh -c 'mkdir -p ~/.config/atuin && cp config/atuin.toml ~/.config/atuin/config.toml && atuin search --limit 1 >/dev/null; echo exit=$?'`
Expected: `exit=0` and no warnings about unknown keys. If a key is reported as unknown, check it against `atuin`'s documented config for that version and correct `config/atuin.toml`. Never drop `auto_sync`, `update_check` or `secrets_filter`.

- [ ] **Step 6: fzf defaults**

Append to `config/zsh/env.zsh`:

```zsh
# fzf: fd for file and directory lists, previews, Catppuccin Mocha colours.
export FZF_DEFAULT_OPTS="--height=60% --layout=reverse --border \
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A,border:#6C7086,label:#CDD6F4"
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons=always {}'"
```

- [ ] **Step 7: Run the suite**

Run: `zsh -n config/zsh/*.zsh && zsh tests/run.zsh`
Expected: all `ok`.

- [ ] **Step 8: Stage**

```bash
git add Brewfile config/atuin.toml config/zsh install.zsh tests/
```

Owner commits: `git commit -m "Add local-only Atuin history and fzf previews"`

---

### Task 6: fzf-tab completion

**Files:**
- Create: `install-plugins.zsh`, `tests/test_fzf_tab.zsh`, `tests/net_test_install_plugins.zsh`
- Modify: `bootstrap.zsh`, `config/zsh/plugins.zsh`

**Interfaces:**
- Produces: `install-plugins.zsh [DATA_DIR]`, which clones fzf-tab into `${DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}}/zsh/fzf-tab` and checks out the pinned commit. `plugins.zsh` loads `${XDG_DATA_HOME:-$HOME/.local/share}/zsh/fzf-tab/fzf-tab.plugin.zsh` when present.

- [ ] **Step 1: Choose the pin**

Run: `git ls-remote --tags https://github.com/Aloxaf/fzf-tab | sort -t/ -k3 -V | tail -3`
Take the newest release tag's commit SHA (for annotated tags use the `^{}` line). Record the tag and SHA in the task report. They go into Step 4 as `fzf_tab_tag` and `fzf_tab_commit`.

- [ ] **Step 2: Write the failing tests**

`tests/test_fzf_tab.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
# Without fzf-tab: no errors, standard menu completion.
sbx_i true >/dev/null
assert_eq "$(<$SANDBOX/stderr)" "" "stderr empty without fzf-tab"
assert_contains "$(sbx_i "zstyle -L ':completion:*' menu")" "select" "menu select without fzf-tab"

# With fzf-tab (from the real install, if bootstrap has run).
real=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/fzf-tab
if [[ -r $real/fzf-tab.plugin.zsh ]] && (( $+commands[fzf] )); then
  command mkdir -p $SANDBOX/home/.local/share/zsh
  command ln -s $real $SANDBOX/home/.local/share/zsh/fzf-tab
  assert_eq "$(sbx_i '(( $+functions[fzf-tab-complete] )) && print yes')" yes "fzf-tab loaded"
  assert_contains "$(sbx_i "zstyle -L ':completion:*' menu")" "no" "menu disabled for fzf-tab"
  assert_eq "$(<$SANDBOX/stderr)" "" "stderr empty with fzf-tab"
else
  print 'skip fzf-tab loaded checks (run ./install-plugins.zsh first)'
fi
finish
```

`tests/net_test_install_plugins.zsh` (needs network, so the `net_` prefix keeps it out of `run.zsh`):

```zsh
source ${0:A:h}/lib.zsh
SANDBOX=$(command mktemp -d "${TMPDIR:-/tmp}/shell-config-net.XXXXXX")
"$REPO/install-plugins.zsh" "$SANDBOX/data" || fail "install-plugins failed"
want=$(command sed -n "s/^fzf_tab_commit='\(.*\)'/\1/p" "$REPO/install-plugins.zsh")
assert_eq "$(git -C $SANDBOX/data/zsh/fzf-tab rev-parse HEAD)" "$want" "fzf-tab at pinned commit"
"$REPO/install-plugins.zsh" "$SANDBOX/data" || fail "second run failed"
finish
```

- [ ] **Step 3: Run them to see them fail**

Run: `zsh tests/net_test_install_plugins.zsh`
Expected: FAIL `install-plugins failed` (the script does not exist yet).

- [ ] **Step 4: Write the installer**

`install-plugins.zsh` (make executable with `chmod +x install-plugins.zsh`). Use the tag and SHA from Step 1:

```zsh
#!/bin/zsh
# Zsh plugins that Homebrew does not package, pinned to reviewed commits.
set -eu
data=${1:-${XDG_DATA_HOME:-$HOME/.local/share}}

fzf_tab_tag='TAG_FROM_STEP_1'
fzf_tab_commit='SHA_FROM_STEP_1'
dir="$data/zsh/fzf-tab"

if [[ ! -d $dir/.git ]]; then
  mkdir -p "${dir:h}"
  git clone --quiet https://github.com/Aloxaf/fzf-tab.git "$dir"
fi
if [[ $(git -C "$dir" rev-parse HEAD) != $fzf_tab_commit ]]; then
  git -C "$dir" fetch --quiet --tags origin
  git -C "$dir" -c advice.detachedHead=false checkout --quiet "$fzf_tab_commit"
fi
print -r -- "fzf-tab $fzf_tab_tag ($fzf_tab_commit)"
```

Replace `TAG_FROM_STEP_1` and `SHA_FROM_STEP_1` with the real values before running anything.

In `bootstrap.zsh`, add before the `"$root/install.zsh"` line:

```zsh
"$root/install-plugins.zsh"
```

- [ ] **Step 5: Load fzf-tab**

Replace `config/zsh/plugins.zsh` with:

```zsh
# Plugins. fzf-tab must load after compinit and before plugins that wrap widgets;
# syntax highlighting loads last, from zshrc.
_fzf_tab=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/fzf-tab/fzf-tab.plugin.zsh
if [[ -r $_fzf_tab ]] && (( $+commands[fzf] )); then
  source $_fzf_tab
  zstyle ':completion:*' menu no
  zstyle ':completion:*:descriptions' format '[%d]'
  zstyle ':fzf-tab:*' switch-group '<' '>'
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=always $realpath'
  zstyle ':fzf-tab:complete:(cat|bat|less|code|vim):*' fzf-preview 'bat --color=always --style=numbers --line-range=:200 $realpath'
  zstyle ':fzf-tab:complete:git-(checkout|switch):*' fzf-preview 'git log --oneline --graph --color=always -20 $word'
  zstyle ':completion:*:*:*:*:processes' command 'command ps -u $USER -o pid,user,comm -w -w'
  zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview '[[ $group == "[process ID]" ]] && command ps -p $word -o command -w -w'
  zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap
fi
unset _fzf_tab

[[ -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
```

- [ ] **Step 6: Install and run the tests**

Run: `./install-plugins.zsh && zsh tests/net_test_install_plugins.zsh && zsh tests/run.zsh`
Expected: `fzf-tab <tag> (<sha>)`, then all `ok`, and `test_fzf_tab.zsh` runs its loaded checks rather than skipping them.

- [ ] **Step 7: Stage**

```bash
git add install-plugins.zsh bootstrap.zsh config/zsh/plugins.zsh tests/
```

Owner commits: `git commit -m "Add fzf-tab completion pinned to a release"`

---

### Task 7: Git defaults, aliases and lazygit

**Files:**
- Modify: `config/git-tools`, `config/zsh/git.zsh`, `config/zsh/env.zsh`, `install.zsh`, `tests/test_functions_use_originals.zsh`
- Create: `config/lazygit.yml`, `tests/test_git.zsh`

**Interfaces:**
- Consumes: `pairs` (Task 1).
- Produces: `LG_CONFIG_FILE` exported from `env.zsh`, holding a comma-separated list of lazygit config files that starts with `$HOME/.config/lazygit/config.yml`. Task 8 appends the theme file to it.

- [ ] **Step 1: Write the failing test**

`tests/test_git.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
g() { HOME=$SANDBOX/home git config --global --includes --get "$1"; }
assert_eq "$(g pull.rebase)" true "pull.rebase"
assert_eq "$(g rebase.autoStash)" true "rebase.autoStash"
assert_eq "$(g rebase.autoSquash)" true "rebase.autoSquash"
assert_eq "$(g push.autoSetupRemote)" true "push.autoSetupRemote"
assert_eq "$(g fetch.prune)" true "fetch.prune"
assert_eq "$(g rerere.enabled)" true "rerere.enabled"
assert_eq "$(g diff.algorithm)" histogram "diff.algorithm"
assert_eq "$(g merge.conflictStyle)" zdiff3 "merge.conflictStyle"
assert_eq "$(g branch.sort)" -committerdate "branch.sort"
assert_eq "$(g init.defaultBranch)" main "init.defaultBranch"
assert_eq "$(g commit.verbose)" true "commit.verbose"
assert_eq "$(g help.autocorrect)" prompt "help.autocorrect"
assert_eq "$(g delta.dark)" true "delta dark"
assert_eq "$(g delta.hyperlinks)" true "delta hyperlinks"
assert_eq "$(g delta.hyperlinks-file-link-format)" 'vscode://file/{path}:{line}' "delta opens VS Code"
assert_eq "$(g core.editor)" "" "core.editor unset (uses EDITOR)"

for a in gs gd gds gl ga gc gco gsw gb gp gpl grb gst gcp lg gg; do
  assert_contains "$(sbx_i "alias $a")" "$a=" "alias $a"
done
assert_eq "$(sbx_i '(( $+functions[ghpr] )) && print yes')" yes "ghpr defined"
[[ -f $SANDBOX/home/.config/lazygit/config.yml ]] || fail "lazygit config not installed"
assert_contains "$(sbx_i 'print -r -- $LG_CONFIG_FILE')" ".config/lazygit/config.yml" "LG_CONFIG_FILE"
finish
```

- [ ] **Step 2: Run it to see it fail**

Run: `zsh tests/test_git.zsh`
Expected: FAIL on every Git default except the existing delta settings, on the new aliases, on `ghpr` and on the lazygit config.

- [ ] **Step 3: Git and delta defaults**

Replace `config/git-tools` with:

```ini
[core]
    pager = delta
[interactive]
    diffFilter = delta --color-only
[delta]
    navigate = true
    line-numbers = true
    dark = true
    hyperlinks = true
    hyperlinks-file-link-format = "vscode://file/{path}:{line}"
[merge]
    conflictStyle = zdiff3
[diff]
    algorithm = histogram
    colorMoved = default
[push]
    autoSetupRemote = true
[fetch]
    prune = true
[pull]
    rebase = true
[rebase]
    autoStash = true
    autoSquash = true
[rerere]
    enabled = true
[branch]
    sort = -committerdate
[init]
    defaultBranch = main
[commit]
    verbose = true
[help]
    autocorrect = prompt
```

- [ ] **Step 4: Aliases and ghpr**

Replace `config/zsh/git.zsh` with:

```zsh
# Git shortcuts for quick one-liners. lazygit (lg, gg) is the main Git interface.
alias gs='git status --short --branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch'
alias gp='git push'
alias gpl='git pull'
alias grb='git rebase'
alias gst='git stash'
alias gcp='git cherry-pick'
alias lg='lazygit'
alias gg='lazygit'

# Pick an open pull request with fzf and check it out.
ghpr() {
  (( $+commands[gh] && $+commands[fzf] )) || { print -u2 'ghpr needs gh and fzf'; return 1; }
  local pr
  pr=$(gh pr list --limit 50 | fzf --prompt='PR> ' --preview 'gh pr view {1}') || return
  gh pr checkout ${pr%%[[:space:]]*}
}
```

Add `ghpr` to the function list in `tests/test_functions_use_originals.zsh`:

```zsh
bodies=$(sbx_i 'functions mkcd croot shell-bench extract path reload ghpr')
```

- [ ] **Step 5: Confirm lazygit's pager setting for the installed version**

lazygit 0.66 lists `git.diffRenderers` in `lazygit --config` and no longer shows `git.paging`. Read the documentation for the installed version:

```bash
v=$(lazygit --version | sed -n 's/.*version=\([0-9.]*\).*/\1/p')
gh api "repos/jesseduffield/lazygit/contents/docs/Custom_Pagers.md?ref=v$v" --jq .content | base64 -d | sed -n '1,80p'
```

Use the delta example from that document, with `--dark --paging=never`, in Step 6. If the document shows `git.paging`, use the first form in Step 6; if it shows a `diffRenderers` list, use the second.

- [ ] **Step 6: lazygit config**

`config/lazygit.yml` (pager block per Step 5):

```yaml
# lazygit as the Tower replacement. Colours come from the Catppuccin theme file.
gui:
  nerdFontsVersion: "3"
  mouseEvents: true
  showFileTree: true
os:
  editPreset: vscode
git:
  # Form 1 (git.paging):
  paging:
    colorArg: always
    pager: delta --dark --paging=never
  # Form 2 (diffRenderers): replace the paging block above with the list form
  # from Custom_Pagers.md for this version, keeping the same delta command.
```

Keep only the form that applies, and delete the comment lines for the other.

Add to the `pairs` array in `install.zsh`:

```zsh
  'lazygit.yml:.config/lazygit/config.yml'
```

Append to `config/zsh/env.zsh`:

```zsh
# lazygit reads config from ~/.config instead of Application Support.
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"
```

- [ ] **Step 7: Check the lazygit config loads**

Run: `LG_CONFIG_FILE=$PWD/config/lazygit.yml script -q /dev/null lazygit --version`
Expected: a version line with no config error. Then open `lg` in a Git repository in Ghostty and confirm diffs render through delta. Press `q` to quit.

- [ ] **Step 8: Run the suite**

Run: `zsh -n config/zsh/*.zsh && zsh tests/run.zsh`
Expected: all `ok`.

- [ ] **Step 9: Stage**

```bash
git add config/git-tools config/lazygit.yml config/zsh install.zsh tests/
```

Owner commits: `git commit -m "Add Git defaults, aliases and lazygit config"`

---

### Task 8: Catppuccin Mocha across tools (delta, bat, btop, eza, lazygit)

**Files:**
- Create: `config/themes/SOURCES.md`, `config/themes/delta/catppuccin.gitconfig`, `config/themes/btop/catppuccin_mocha.theme`, `config/themes/eza/theme.yml`, `config/themes/lazygit/catppuccin-mocha-blue.yml`, `tests/test_themes.zsh`
- Modify: `config/git-tools`, `config/zsh/env.zsh`, `install.zsh`

**Interfaces:**
- Consumes: `LG_CONFIG_FILE` (Task 7), `pairs` (Task 1).
- Produces: `BAT_THEME='Catppuccin Mocha'` (built into bat 0.26.1, so nothing is vendored for bat), `EZA_CONFIG_DIR=$HOME/.config/eza`, and delta feature `catppuccin-mocha`.

- [ ] **Step 1: Write the failing test**

`tests/test_themes.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
h=$SANDBOX/home
for f in .config/git/catppuccin-delta.gitconfig .config/btop/themes/catppuccin_mocha.theme \
         .config/eza/theme.yml .config/lazygit/catppuccin.yml; do
  [[ -s $h/$f ]] || fail "theme not installed: $f"
done
assert_eq "$(HOME=$h git config --global --includes --get delta.features)" catppuccin-mocha "delta feature"
assert_eq "$(HOME=$h git config --global --includes --get delta.syntax-theme)" "Catppuccin Mocha" "delta syntax theme"
assert_contains "$(<$h/.config/btop/btop.conf)" 'color_theme = "catppuccin_mocha"' "btop theme"

# Running the installer again keeps exactly one theme line.
command sleep 1
HOME=$h "$REPO/install.zsh" >/dev/null 2>&1
assert_eq "$(command grep -c '^color_theme' $h/.config/btop/btop.conf)" 1 "one btop theme line"

envs=$(sbx_i 'print -r -- $BAT_THEME; print -r -- $EZA_CONFIG_DIR; print -r -- $LG_CONFIG_FILE')
assert_contains "$envs" "Catppuccin Mocha" "BAT_THEME"
assert_contains "$envs" "$h/.config/eza" "EZA_CONFIG_DIR"
assert_contains "$envs" "config.yml,$h/.config/lazygit/catppuccin.yml" "lazygit theme merged"
assert_eq "$(<$SANDBOX/stderr)" "" "stderr empty"
finish
```

- [ ] **Step 2: Run it to see it fail**

Run: `zsh tests/test_themes.zsh`
Expected: FAIL `theme not installed` for all four files, plus the env assertions.

- [ ] **Step 3: Vendor the theme files**

For each repository, resolve the current commit and confirm the file path before downloading:

```bash
for repo in catppuccin/delta catppuccin/btop catppuccin/eza catppuccin/lazygit; do
  print "$repo $(gh api repos/$repo/commits/HEAD --jq .sha)"
done
gh api repos/catppuccin/eza/git/trees/HEAD?recursive=1 --jq '.tree[].path' | grep -i mocha
gh api repos/catppuccin/lazygit/git/trees/HEAD?recursive=1 --jq '.tree[].path' | grep -i 'mocha/blue'
```

Expected paths: `catppuccin.gitconfig` (delta), `themes/catppuccin_mocha.theme` (btop), the Mocha blue `.yml` under `themes` (eza), and `themes-mergable/mocha/blue.yml` (lazygit; mergeable, so it layers on `config.yml`). Use the paths the trees show if they differ.

Download each file at its recorded commit:

```bash
mkdir -p config/themes/{delta,btop,eza,lazygit}
fetch() { curl -fsSL "https://raw.githubusercontent.com/$1/$2/$3" -o "$4"; }
fetch catppuccin/delta   DELTA_SHA   catppuccin.gitconfig              config/themes/delta/catppuccin.gitconfig
fetch catppuccin/btop    BTOP_SHA    themes/catppuccin_mocha.theme     config/themes/btop/catppuccin_mocha.theme
fetch catppuccin/eza     EZA_SHA     EZA_MOCHA_BLUE_PATH               config/themes/eza/theme.yml
fetch catppuccin/lazygit LAZYGIT_SHA themes-mergable/mocha/blue.yml    config/themes/lazygit/catppuccin-mocha-blue.yml
```

Substitute the SHAs and the eza path from the previous command.

- [ ] **Step 4: Review the vendored files**

Read every downloaded file in full. Each must contain only colour and style definitions. Reject and report the file if it has any of the following:
- In the gitconfig: `[include]`, `[includeIf]`, `[alias]`, `[core]`, `[credential]`, any `!` command, or any key outside `[delta "catppuccin-*"]` sections.
- In the YAML files: keys outside `gui.theme` (lazygit) or colour keys (eza).
- In the btop file: anything other than `theme[...]="..."` lines and comments.

Check the licence: `gh api repos/catppuccin/delta --jq .license.spdx_id` (repeat for each repo). Expected `MIT`.

Write `config/themes/SOURCES.md`:

```markdown
# Vendored Catppuccin themes

Reviewed and pinned. Update by repeating Task 8 Steps 3-4 of
docs/superpowers/plans/2026-10-15-modern-dev-environment.md.

| File | Repository | Path | Commit | Licence |
|---|---|---|---|---|
| delta/catppuccin.gitconfig | catppuccin/delta | catppuccin.gitconfig | DELTA_SHA | MIT |
| btop/catppuccin_mocha.theme | catppuccin/btop | themes/catppuccin_mocha.theme | BTOP_SHA | MIT |
| eza/theme.yml | catppuccin/eza | EZA_MOCHA_BLUE_PATH | EZA_SHA | MIT |
| lazygit/catppuccin-mocha-blue.yml | catppuccin/lazygit | themes-mergable/mocha/blue.yml | LAZYGIT_SHA | MIT |

bat ships Catppuccin Mocha built in (bat 0.26.1), so it is not vendored.
```

Fill in the real SHAs and the eza path.

- [ ] **Step 5: Wire the themes in**

Append to `config/git-tools`:

```ini
[delta]
    features = catppuccin-mocha
    syntax-theme = Catppuccin Mocha
[include]
    path = ~/.config/git/catppuccin-delta.gitconfig
```

Add to the `pairs` array in `install.zsh`:

```zsh
  'themes/delta/catppuccin.gitconfig:.config/git/catppuccin-delta.gitconfig'
  'themes/btop/catppuccin_mocha.theme:.config/btop/themes/catppuccin_mocha.theme'
  'themes/eza/theme.yml:.config/eza/theme.yml'
  'themes/lazygit/catppuccin-mocha-blue.yml:.config/lazygit/catppuccin.yml'
```

In `install.zsh`, after the `pairs` loop and before the `.gitconfig` block, add:

```zsh
# btop owns btop.conf and rewrites it on exit; set only the theme line.
btop_conf="$HOME/.config/btop/btop.conf"
if [[ -f $btop_conf ]]; then
  mkdir -p "$backup/.config/btop"
  cp -p "$btop_conf" "$backup/.config/btop/btop.conf"
  print -r -- '.config/btop/btop.conf' >> "$backup/existing"
  if command grep -q '^color_theme' "$btop_conf"; then
    command sed -i '' 's/^color_theme.*/color_theme = "catppuccin_mocha"/' "$btop_conf"
  else
    print -r -- 'color_theme = "catppuccin_mocha"' >> "$btop_conf"
  fi
else
  print -r -- 'color_theme = "catppuccin_mocha"' > "$btop_conf"
  print -r -- '.config/btop/btop.conf' >> "$backup/created"
fi
```

`install.zsh` is a script, so `sed` and `grep` here are the originals. `command` is used for consistency.

In `config/zsh/env.zsh`, replace the `LG_CONFIG_FILE` line with:

```zsh
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/catppuccin.yml"
```

Append to `config/zsh/env.zsh`:

```zsh
# Catppuccin Mocha for bat (built in) and eza (vendored theme.yml).
export BAT_THEME='Catppuccin Mocha'
export EZA_CONFIG_DIR="$HOME/.config/eza"
```

- [ ] **Step 6: Run the suite**

Run: `zsh -n install.zsh config/zsh/*.zsh && zsh tests/run.zsh`
Expected: all `ok`.

- [ ] **Step 7: Stage**

```bash
git add config/themes config/git-tools config/zsh/env.zsh install.zsh tests/
```

Owner commits: `git commit -m "Vendor Catppuccin Mocha themes for delta, btop, eza and lazygit"`

---

### Task 9: Starship on the Catppuccin palette

**Files:**
- Modify: `config/starship.toml`
- Create: `tests/test_starship.zsh`

- [ ] **Step 1: Write the failing test**

`tests/test_starship.zsh`:

```zsh
source ${0:A:h}/lib.zsh
conf=$REPO/config/starship.toml
(( $+commands[starship] )) || { print 'skip: starship missing'; exit 0; }
err=$(STARSHIP_CONFIG=$conf starship prompt 2>&1 >/dev/null)
assert_eq "$err" "" "starship reports no config warnings"
assert_contains "$(<$conf)" "palette = 'catppuccin_mocha'" "palette selected"
assert_contains "$(<$conf)" "[palettes.catppuccin_mocha]" "palette defined"
# Colours live only in the palette block; module styles use palette names.
outside=$(command awk '/^\[palettes\./{p=1;next} /^\[/{p=0} !p' $conf | command grep -cE "#[0-9A-Fa-f]{6}")
assert_eq "$outside" 0 "no hex colours outside the palette"
assert_eq "$(command grep -c dimmed $conf)" 0 "no dimmed styles"
finish
```

- [ ] **Step 2: Run it to see it fail**

Run: `zsh tests/test_starship.zsh`
Expected: FAIL `palette selected`, `palette defined`, and a non-zero hex count.

- [ ] **Step 3: Move the prompt onto the palette**

In `config/starship.toml`:

Replace line 2 (`# Light RGB colours for black/dark backgrounds; avoid dimmed text.`) with:

```toml
# Catppuccin Mocha palette; module styles use palette names. Avoid dimmed text.
```

After `add_newline = true`, add:

```toml
palette = 'catppuccin_mocha'
```

Change these style values (key → new value):

| Section | Key | New value |
|---|---|---|
| `[username]` | `style_user` | `'bold blue'` |
| `[username]` | `style_root` | `'bold red'` |
| `[hostname]` | `style` | `'bold blue'` |
| `[time]` | `style` | `'subtext1'` |
| `[directory]` | `repo_root_style` | `'bold teal'` |
| `[directory]` | `style` | `'teal'` |
| `[directory]` | `read_only_style` | `'bold red'` |
| `[git_branch]` | `style` | `'bold mauve'` |
| `[git_commit]` | `style` | `'bold yellow'` |
| `[git_state]` | `style` | `'bold yellow'` |
| `[git_status]` | `style` | `'bold yellow'` |
| `[nodejs]` | `style` | `'bold green'` |
| `[php]` | `style` | `'bold lavender'` |
| `[docker_context]` | `style` | `'bold sapphire'` |
| `[cmd_duration]` | `format` | `'[took $duration](subtext1) '` |
| `[status]` | `format` | `'[exit:$status](bold red) '` |
| `[character]` | `success_symbol` | `'[❯](bold green)'` |
| `[character]` | `error_symbol` | `'[❯](bold red)'` |

Append at the end of the file:

```toml
[palettes.catppuccin_mocha]
rosewater = '#f5e0dc'
flamingo = '#f2cdcd'
pink = '#f5c2e7'
mauve = '#cba6f7'
red = '#f38ba8'
maroon = '#eba0ac'
peach = '#fab387'
yellow = '#f9e2af'
green = '#a6e3a1'
teal = '#94e2d5'
sky = '#89dceb'
sapphire = '#74c7ec'
blue = '#89b4fa'
lavender = '#b4befe'
text = '#cdd6f4'
subtext1 = '#bac2de'
subtext0 = '#a6adc8'
overlay2 = '#9399b2'
overlay1 = '#7f849c'
overlay0 = '#6c7086'
surface2 = '#585b70'
surface1 = '#45475a'
surface0 = '#313244'
base = '#1e1e2e'
mantle = '#181825'
crust = '#11111b'
```

- [ ] **Step 4: Run the suite**

Run: `zsh tests/run.zsh`
Expected: all `ok`.

- [ ] **Step 5: Stage**

```bash
git add config/starship.toml tests/test_starship.zsh
```

Owner commits: `git commit -m "Move the prompt onto the Catppuccin Mocha palette"`

---

### Task 10: Ghostty, Nerd Font and VS Code

**Files:**
- Modify: `Brewfile`, `config/ghostty.config`, `config/zsh/env.zsh`, `config/zsh/aliases.zsh`
- Create: `tests/test_ghostty.zsh`, `tests/test_editor.zsh`

**Interfaces:**
- Produces: `EDITOR` and `VISUAL`; aliases `c.` and `o.`.

- [ ] **Step 1: Install the font and confirm the names**

Add to `Brewfile` after `cask "ghostty"`:

```ruby
cask "font-jetbrains-mono-nerd-font"
```

Run: `brew bundle --file=Brewfile`
Then: `/Applications/Ghostty.app/Contents/MacOS/ghostty +list-fonts | grep -i 'jetbrainsmono nerd font' | head -3`
Expected: a family named `JetBrainsMono Nerd Font`. If it differs, use the printed name in Step 3.
The theme name `Catppuccin Mocha` is confirmed to ship with Ghostty (`ghostty +list-themes --plain` on 2026-10-15).

- [ ] **Step 2: Write the failing tests**

`tests/test_ghostty.zsh`:

```zsh
source ${0:A:h}/lib.zsh
ghostty=/Applications/Ghostty.app/Contents/MacOS/ghostty
[[ -x $ghostty ]] || { print 'skip: Ghostty missing'; exit 0; }
conf=$REPO/config/ghostty.config
out=$($ghostty +validate-config --config-file=$conf 2>&1) || fail "invalid Ghostty config: $out"
for line in 'font-family = JetBrainsMono Nerd Font' 'theme = Catppuccin Mocha' \
            'shell-integration-features = cursor,sudo,title' 'copy-on-select = clipboard' \
            'window-save-state = always' 'keybind = global:cmd+grave_accent=toggle_quick_terminal'; do
  assert_contains "$(<$conf)" "$line" "ghostty: $line"
done
finish
```

`tests/test_editor.zsh`:

```zsh
source ${0:A:h}/lib.zsh
make_sandbox
command mkdir -p $SANDBOX/bin
print '#!/bin/sh' > $SANDBOX/bin/code && command chmod +x $SANDBOX/bin/code
assert_eq "$(PATH=$SANDBOX/bin:$PATH sbx_i 'print -r -- $EDITOR')" "code --wait" "EDITOR is VS Code locally"
assert_eq "$(SSH_CONNECTION='1 2 3 4' sbx_i 'print -r -- $EDITOR')" "vim" "EDITOR is vim over SSH"
assert_eq "$(sbx_i 'print -r -- $VISUAL')" "$(sbx_i 'print -r -- $EDITOR')" "VISUAL matches EDITOR"
assert_contains "$(sbx_i 'alias c.')" "code ." "c. alias"
assert_contains "$(sbx_i 'alias o.')" "open ." "o. alias"
finish
```

- [ ] **Step 3: Run them to see them fail**

Run: `zsh tests/test_ghostty.zsh; zsh tests/test_editor.zsh`
Expected: FAIL on every Ghostty line and on the editor assertions.

- [ ] **Step 4: Ghostty config**

Replace `config/ghostty.config` with:

```
# Portable appearance and explicit shell.
command = /bin/zsh --login
font-family = JetBrainsMono Nerd Font
font-size = 14
theme = Catppuccin Mocha
window-padding-x = 12
window-padding-y = 10
macos-option-as-alt = true
macos-titlebar-style = tabs
shell-integration-features = cursor,sudo,title
copy-on-select = clipboard
mouse-hide-while-typing = true
window-save-state = always
# Drop-down terminal from any app; needs Accessibility permission. Replaces the
# macOS Cmd-backtick window cycling shortcut.
quick-terminal-position = top
keybind = global:cmd+grave_accent=toggle_quick_terminal
```

- [ ] **Step 5: VS Code as editor**

Append to `config/zsh/env.zsh`:

```zsh
# VS Code: CLI from the app bundle; editor for Git and Ctrl-X Ctrl-E. Vim over SSH.
_vscode_bin='/Applications/Visual Studio Code.app/Contents/Resources/app/bin'
[[ -d $_vscode_bin ]] && path+=("$_vscode_bin")
unset _vscode_bin
if (( $+commands[code] )) && [[ -z $SSH_CONNECTION ]]; then
  export EDITOR='code --wait'
else
  export EDITOR='vim'
fi
export VISUAL=$EDITOR
```

Append to `config/zsh/aliases.zsh`:

```zsh
alias c.='code .'
alias o.='open .'
```

- [ ] **Step 6: Run the suite**

Run: `zsh -n config/zsh/*.zsh && zsh tests/run.zsh`
Expected: all `ok`.

- [ ] **Step 7: Stage**

```bash
git add Brewfile config/ghostty.config config/zsh tests/
```

Owner commits: `git commit -m "Configure Ghostty theme and font, and VS Code as editor"`

---

### Task 11: README

**Files:**
- Modify: `README.md`
- Create: `tests/test_readme.zsh`

- [ ] **Step 1: Write the failing test**

`tests/test_readme.zsh`:

```zsh
source ${0:A:h}/lib.zsh
readme=$(<$REPO/README.md)
names=( ${(f)"$(command grep -hoE '^ *(\(\([^)]*\)\) && )?alias [^=]+' $REPO/config/zsh/*.zsh | command sed -E 's/.*alias //')"} )
names+=( ${(f)"$(command grep -hoE '^[a-z][a-z0-9.-]*\(\)' $REPO/config/zsh/*.zsh | command sed 's/()//')"} )
for n in ${(u)names}; do
  assert_contains "$readme" "\`$n" "README documents $n"
done
for phrase in 'command find' 'Tower' 'atuin import zsh' 'terminal.integrated.fontFamily' 'Accessibility' 'gpg.format'; do
  assert_contains "$readme" "$phrase" "README mentions $phrase"
done
assert_not_contains "$readme" "catc" "README drops catc"
finish
```

- [ ] **Step 2: Run it to see it fail**

Run: `zsh tests/test_readme.zsh`
Expected: FAIL for most of the new aliases and every phrase.

- [ ] **Step 3: Rewrite the README sections**

Update `README.md` as follows. Keep "Install on another Mac", "Update" and "Runtime management" as they are, apart from the edits listed.

1. Intro paragraph: list the new tools (eza, fd, ripgrep, bat, dust, duf, procs, sd, doggo, jq, tldr, btop, Atuin, fzf-tab, lazygit), Catppuccin Mocha, and the JetBrains Mono Nerd Font. Remove "No special font required."
2. "Install on another Mac": add VS Code as a prerequisite (installed from code.visualstudio.com, not Homebrew). After `./bootstrap.zsh`, add `atuin import zsh` (a one-time import of existing history).
3. New section **"Manual steps"**:
   - In VS Code settings, set `"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"`; otherwise icons show as boxes in VS Code's terminal.
   - Allow Ghostty under System Settings > Privacy & Security > Accessibility to enable the Cmd-` quick terminal. It replaces macOS's Cmd-` window cycling.
   - Run `atuin import zsh` once.
4. **"Commands"**: start with this note:
   > Modern tools take over familiar commands in interactive shells. Scripts are unaffected. Commands copied from documentation that use the original syntax (`find . -name`, `sed -i`, `ps aux`, `grep -E`) may fail: run the original with `command find`, `command sed` and so on, or `\find`. `shell-doctor` lists every takeover.

   Then one table row for each of these, grouped as Takeovers, Navigation, History and search, Git, Docker and DDEV, Helpers: `ls`, `ll`, `la`, `lt`, `cat`, `top`, `cd`/`cdi`, `diff`, `du`, `df`, `ps`, `find`, `grep`, `sed`, `dig`, `..`, `...`, `....`, `c.`, `o.`, Ctrl-R (Atuin), Ctrl-T, Option-C, Tab (fzf-tab, `<`/`>` switch groups), Ctrl-X Ctrl-E, Ctrl-Z, Option-Left/Right, `gs`, `gd`, `gds`, `gl`, `ga`, `gc`, `gco`, `gsw`, `gb`, `gp`, `gpl`, `grb`, `gst`, `gcp`, `lg`, `gg`, `ghpr`, `dc`, `dps`, `dd`, `dphp`, `dcomposer`, `dnpm`, `dssh`, `mkcd`, `croot`, `extract`, `path`, `reload`, `shell-bench`, `shell-doctor`, `tldr`. Remove `catc` and `z project`/`zi`.
5. New section **"Tower to lazygit"**, a table of the lazygit keys for: stage file (space), stage lines (enter on a file, then space on lines, `v` for a range), commit (`c`), amend (`A`), push (`P`), pull (`p`), new branch (`n` in branches), switch branch (space in branches), interactive rebase (`e` on a commit; `s` squash, `f` fixup, `d` drop, Ctrl-J/Ctrl-K move), cherry-pick (`C` to copy, `V` to paste), stash (`s` in files), undo (`z`), all actions (`?`), options menu (`x`). Mouse: click panels and items, scroll; menus are clickable.
6. **"Git"** section (replacing the delta paragraph): delta is dark with Catppuccin and clickable links that open files in VS Code; the defaults list (rebase on pull with autostash, auto upstream on first push, prune on fetch, rerere, histogram diffs, zdiff3 conflicts, recent branches first); and SSH commit signing for your own `~/.gitconfig`:
   ```ini
   [gpg]
       format = ssh
   [user]
       signingkey = ~/.ssh/id_ed25519.pub
   [commit]
       gpgsign = true
   ```
7. **"Customisation"**: list the module files under `~/.config/zsh/`, `~/.config/atuin/config.toml` (local only: no sync, no update checks, secrets filter), `~/.config/lazygit/config.yml`, `config/themes/SOURCES.md` (theme pins), `install-plugins.zsh` (fzf-tab pin), and the Ghostty settings (font, Catppuccin theme, quick terminal, splits Cmd-D / Cmd-Shift-D / Cmd-[ / Cmd-]). Replace the Starship line's "light RGB colours" with "Catppuccin Mocha palette, no dimmed text".
8. New section **"Tests"**: `zsh tests/run.zsh` (offline suite), `zsh tests/bench.zsh` (startup budget, under 150 ms), `zsh tests/net_test_install_plugins.zsh` (needs network).
9. Upstream links: add eza, Atuin, fzf-tab, lazygit and Catppuccin.

- [ ] **Step 4: Run the suite**

Run: `zsh tests/run.zsh`
Expected: all `ok`.

- [ ] **Step 5: Stage**

```bash
git add README.md tests/test_readme.zsh
```

Owner commits: `git commit -m "Document the modern environment"`

---

### Task 12: Final verification

**Files:** none changed unless a check fails.

- [ ] **Step 1: Full offline suite**

Run: `zsh -n config/zshrc config/zsh/*.zsh install.zsh install-plugins.zsh bootstrap.zsh && zsh tests/run.zsh`
Expected: no syntax output; every test `ok`.

- [ ] **Step 2: Network test and startup budget**

Run: `zsh tests/net_test_install_plugins.zsh && zsh tests/bench.zsh`
Expected: pass, with a printed mean under 150 ms. Record the mean next to the 0.62-0.95 s baseline in the task report.

- [ ] **Step 3: Install for real**

Run: `./bootstrap.zsh`
Expected: `brew bundle` completes, then the fzf-tab line, then `Installed. Backup and rollback records: ...`.

- [ ] **Step 4: Manual check in Ghostty (owner)**

Open a new Ghostty window and confirm each of these:
- The Catppuccin background shows.
- The prompt uses palette colours, and nothing is dimmed.
- `ls` shows icons.
- `ll` shows Git status in this repository.
- Ctrl-R opens Atuin. Up arrow does prefix search.
- Ctrl-T shows a bat preview.
- `cd <Tab>` opens fzf-tab with eza previews.
- `gg` opens lazygit, with themed delta diffs and a working mouse.
- `man ls` is coloured.
- `btop` uses Catppuccin.
- Cmd-` opens the quick terminal once Accessibility is granted.
- In VS Code's terminal, after the font setting, icons render.
- `git commit` (with nothing staged, then abort) opens VS Code.

- [ ] **Step 5: Request final review**

Hand the branch to a fresh `qa-reviewer` (Sonnet) for whole-branch review against the spec, and to `security-analyst` (Opus) for the vendored theme files, the fzf-tab pin and the Atuin settings. Fix findings before merge.

- [ ] **Step 6: Merge (owner)**

The owner merges `modern-env` into `main` and pushes.
