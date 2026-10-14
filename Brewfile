brew "starship"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"

cask "ghostty"

# Navigation, search and Git
brew "fzf"
brew "zoxide"
brew "bat"
brew "ripgrep"
brew "git"
brew "gh"
brew "lazygit"
brew "git-delta"

# Project runtimes and container-based PHP
# Intel uses the official binary through bootstrap to avoid lengthy source builds.
brew "mise" unless Hardware::CPU.intel?
tap "ddev/ddev"
brew "ddev/ddev/ddev"
