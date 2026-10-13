#!/bin/zsh
set -eu
root=${0:A:h}
backup="$HOME/.shell-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup" "$HOME/.config"
for pair in 'zprofile:.zprofile' 'zshrc:.zshrc' 'starship.toml:.config/starship.toml'; do
  src=${pair%%:*}
  dest=${pair#*:}
  if [[ -e "$HOME/$dest" || -L "$HOME/$dest" ]]; then
    mkdir -p "$backup/${dest:h}"
    cp -pP "$HOME/$dest" "$backup/$dest"
    print -r -- "$dest" >> "$backup/existing"
  else
    print -r -- "$dest" >> "$backup/created"
  fi
  cp "$root/config/$src" "$HOME/$dest"
done
print -r -- "Installed. Backup and rollback records: $backup"
