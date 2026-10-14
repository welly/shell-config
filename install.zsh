#!/bin/zsh
set -eu
root=${0:A:h}
backup="$HOME/.shell-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup" "$HOME/.config"
for pair in 'zprofile:.zprofile' 'zshrc:.zshrc' 'starship.toml:.config/starship.toml' 'ghostty.config:.config/ghostty/config.ghostty' 'git-tools:.config/git/shell-tools.gitconfig'; do
  src=${pair%%:*}
  dest=${pair#*:}
  if [[ -e "$HOME/$dest" || -L "$HOME/$dest" ]]; then
    mkdir -p "$backup/${dest:h}"
    cp -pP "$HOME/$dest" "$backup/$dest"
    print -r -- "$dest" >> "$backup/existing"
  else
    print -r -- "$dest" >> "$backup/created"
  fi
  mkdir -p "$HOME/${dest:h}"
  cp "$root/config/$src" "$HOME/$dest"
done

if [[ -f "$HOME/.gitconfig" ]]; then
  cp -p "$HOME/.gitconfig" "$backup/.gitconfig"
  print '.gitconfig' >> "$backup/existing"
else
  print '.gitconfig' >> "$backup/created"
fi
# Add our Git display settings without replacing existing identity or credentials.
if ! git config --global --get-all include.path | command grep -Fxq "$HOME/.config/git/shell-tools.gitconfig"; then
  git config --global --add include.path "$HOME/.config/git/shell-tools.gitconfig"
fi
if (( $+commands[ddev] )); then
  mkdir -p "$HOME/.config/zsh/completions"
  completion_tmp=$(mktemp)
  if ddev completion zsh > "$completion_tmp" 2>/dev/null && [[ -s "$completion_tmp" ]]; then
    cp "$completion_tmp" "$HOME/.config/zsh/completions/_ddev"
  else
    print 'DDEV completion deferred: start a Docker provider and re-run install.zsh.'
  fi
  rm -f "$completion_tmp"
fi
if (( $+commands[mise] )); then
  mise settings add idiomatic_version_file_enable_tools node
fi

print -r -- "Installed. Backup and rollback records: $backup"
