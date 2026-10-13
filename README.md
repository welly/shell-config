# Development shell

A small macOS zsh configuration with Homebrew-managed Starship,
zsh-autosuggestions and zsh-syntax-highlighting. No plugin manager or special font.

## Apply

```sh
brew install starship zsh-autosuggestions zsh-syntax-highlighting
./install.zsh
exec zsh -l
```

Source files live in `config/`. Installation copies them, so this workspace can
move without breaking your shell. Re-run the installer after edits. Each run
backs up existing files under `~/.shell-backups/` and records newly created files.
To undo, restore the files named in that backup's `existing` file to the same
paths under your home directory, and remove the files named in `created`.
History and the macOS system startup files are preserved.

## Everyday use

- Tab: completion; up/down: history matching the beginning of your command.
- Right arrow: accept a suggested command; Ctrl-R: search history.
- Leading space: omit a command from history. Avoid putting credentials in commands.
- `ll`: detailed listing; `mkcd directory`: create and enter a directory.
- `gs`, `gd`, `gds`, `gl`: Git status, diff, staged diff, recent graph.
- `dc`, `dps`: Docker Compose, running containers.
- `dd`, `dphp`, `dcomposer`, `dnpm`, `dssh`: DDEV and its container tools.
- `nvm use`: load existing nvm and select the project's `.nvmrc` version.
  `nvm install` installs the version if needed; `nvm use default` selects your default.
  Until nvm is invoked, Node uses the existing PATH installation.
- `codex` and `claude`: existing commands, unchanged. Codex's Homebrew completion
  is picked up automatically.

Personal overrides go in `~/.zshrc.local`; it is sourced before syntax highlighting.
Starship uses `~/.config/starship.toml`. History is shared across sessions, with
50,000 entries and duplicates removed. Completions exclude insecure directories.

Docker and DDEV were not installed/on PATH during setup. Shortcuts become usable
when those tools are installed. PHP and Composer shortcuts explicitly use DDEV;
no host PHP or Composer is installed by this setup. Docker Desktop's conventional
`~/.docker/bin` and completion paths are included when available.

Upstream documentation:
- https://starship.rs/
- https://github.com/zsh-users/zsh-autosuggestions
- https://github.com/zsh-users/zsh-syntax-highlighting
- https://github.com/nvm-sh/nvm
- https://docs.ddev.com/en/stable/users/usage/cli/

## Work Mac / portability

Clone this repository on your work Mac:

```sh
git clone https://github.com/welly/shell-config.git
cd shell-config
```

You can also copy the entire directory to any location. On that Mac, install Homebrew from
https://brew.sh if needed, then run:

```sh
./bootstrap.zsh
```

`Brewfile` declares only the three shell dependencies. Both Intel `/usr/local`
and Apple Silicon `/opt/homebrew` are detected automatically. No username,
workspace path, credentials, Git identity, or AI account settings are copied.
Your work Mac's existing startup files are backed up before replacement.
Keep machine-specific changes in `~/.zshrc.local`.

Node, Docker, DDEV, Codex and Claude are separate development tools and are not
installed by bootstrap. Existing installations are discovered through PATH.
For nvm on a new machine, follow https://github.com/nvm-sh/nvm#installing-and-updating
using `PROFILE=/dev/null` to avoid duplicate shell initialization; this configuration
already loads `~/.nvm/nvm.sh` when you run `nvm`. An existing Node installation
continues to work without nvm.

The setup does not automatically switch Node versions on directory changes:
run `nvm use` inside projects with an `.nvmrc`.

## Prompt

The two-line Starship prompt highlights the repository root and relative path,
branch (or detached commit), merge/rebase state, and counts of modified, staged,
untracked, conflicted and stashed files. Ahead/behind counts use the locally
known upstream state; run `git fetch` to refresh it. A clean repository has no
status badge. Project runtimes and Docker context appear when relevant.
Long commands show elapsed time; failures show the exit code and a red arrow.
No Nerd Font is required.

Example:

```text
shell-config/config git:main [new:1 modified:2 staged:1 ahead:1 ]
❯
```
