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
export PATH="$HOME/.local/bin:$PATH"
if [[ $(uname -m) == x86_64 ]] && ! command -v mise >/dev/null; then
  "$root/install-mise-intel.zsh"
fi
"$root/install.zsh"
print 'Open a new terminal, or run: exec zsh -l'
