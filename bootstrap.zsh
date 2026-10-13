#!/bin/zsh
# Run on either Intel or Apple Silicon macOS.
set -eu
root=${0:A:h}
if [[ $OSTYPE != darwin* ]]; then
  print -u2 'This bootstrap targets macOS.'
  exit 1
fi
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  print -u2 'Install Homebrew from https://brew.sh, then run this script again.'
  exit 1
fi
brew bundle --file="$root/Brewfile"
"$root/install.zsh"
print 'Open a new terminal, or run: exec zsh -l'
