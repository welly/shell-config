# Portable macOS development setup

Zsh with Starship, autosuggestions, syntax highlighting, fzf and zoxide.
Homebrew installs Git, gh, lazygit, delta, bat, ripgrep, DDEV and Ghostty.
Mise uses Homebrew on Apple Silicon; on Intel, bootstrap installs its official
versioned binary in `~/.local/bin`, checking the pinned SHA-256 checksum.
This avoids very long Intel source builds. Update that binary with `mise self-update`.
Supports Intel and Apple Silicon Macs. No special font required.

## Install on another Mac

Install Homebrew from https://brew.sh, then:

```sh
git clone https://github.com/welly/shell-config.git
cd shell-config
./bootstrap.zsh
mise use --global node@lts
exec zsh -l
```

Open Ghostty. Choose Make Ghostty the Default Terminal from its app menu if
wanted; bootstrap does not change macOS app associations.
DDEV still needs a running Docker provider (OrbStack or your workplace's preferred
provider). PHP and Composer use the DDEV container, without host installations.
AI tools and account credentials are installed/configured separately.

## Update

```sh
git pull
./bootstrap.zsh
exec zsh -l
```

`install.zsh` copies the files under `config/`, backing up existing destinations
and `.gitconfig` to `~/.shell-backups/`. The source directory can move afterwards.
Restore files listed in a backup's `existing` record to the same home-relative
paths, and remove files listed in `created`, to undo its file changes.
The installer enables Node version-file support in mise; to undo that setting,
run `mise settings unset idiomatic_version_file_enable_tools` if it was previously
unset. Existing mise configuration is not replaced.

## Commands

| Command/key | Use |
|---|---|
| Ctrl-R | Fuzzy command history |
| Ctrl-T | Select a file |
| Option-C | Select a directory in Ghostty |
| Right arrow | Accept a history suggestion |
| `z project` / `zi` | Jump to visited directories / interactive selection |
| `croot` | Enter current Git repository root |
| `mkcd directory` | Create and enter a directory |
| `ll` | Detailed listing |
| `catc file` | Syntax-highlighted file display |
| `rg pattern` | Search project text |
| `lg` | Open lazygit |
| `gs`, `gd`, `gds`, `gl` | Git status, diff, staged diff, history |
| `dc`, `dps` | Docker Compose / running containers |
| `dd`, `dphp`, `dcomposer`, `dnpm`, `dssh` | DDEV and container tools |
| `shell-doctor` | Show shell and dependency paths |

Git diffs use delta with line numbers and a light appearance matching the current
Terminal screenshot. Edit `~/.config/git/shell-tools.gitconfig` for a dark theme.
Git identity and credentials are preserved. To separate work/personal identities,
use Git `includeIf` rules for your own directories and email addresses.

## Runtime management

Mise replaces nvm shell initialization; the previous nvm files and Homebrew Node
are preserved. To reuse an existing nvm installation without downloading again:

```sh
mise link node@26.11.1 "$HOME/.nvm/versions/node/v26.11.1"
mise use --global node@26.11.1
```

Use the version you have installed. A linked installation still lives under
`.nvm`, so keep that directory while the link is in use. Mise selects installed versions when entering projects. `.nvmrc`
and `.node-version` support is enabled; use `mise install` if a version is missing.
Use `mise use node@VERSION` to pin a project's version in `mise.toml`, or
`mise use --global node@lts` for a default. Node defaults are personal settings,
not overwritten by bootstrap.

Mise also supports other runtimes, project environment variables and tasks.
Review project configuration before trusting it. Direnv is not included because
mise covers the initial environment-management requirements.

## Customization

- `~/.zshrc.local`: personal overrides and machine-specific settings.
- `~/.config/starship.toml`: two-line prompt with user, host, full path, Git state,
  local time, relevant runtimes, duration and failure exit code. Uses light RGB
  colours without dimming for readability on black or dark terminal backgrounds.
- `~/.config/ghostty/config.ghostty`: font size, padding, Option key and zsh.
  Ghostty also loads its macOS Application Support configuration; settings there
  may override this file. Reload with Command-Shift-comma.
- History is shared, deduplicated, and stores 50,000 entries. Leading-space
  commands are omitted. Keep credentials outside the repository.

Upstream: https://mise.jdx.dev, https://ghostty.org/docs,
https://github.com/junegunn/fzf, https://github.com/ajeetdsouza/zoxide,
https://docs.ddev.com, https://dandavison.github.io/delta/.
