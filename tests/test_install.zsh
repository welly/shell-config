source ${0:A:h}/lib.zsh
make_sandbox
for f in .zshrc .zprofile .config/starship.toml .config/ghostty/config.ghostty .config/git/shell-tools.gitconfig; do
  [[ -f $SANDBOX/home/$f ]] || fail "not installed: $f"
done
assert_contains "$(<$SANDBOX/home/.config/ghostty/config.ghostty)" "global:cmd+shift+backquote=toggle_visibility" "Ghostty visibility hotkey installed"

# A second run backs up what the first run installed.
command sleep 1   # backup directories are named by the second
HOME=$SANDBOX/home "$REPO/install.zsh" >/dev/null 2>&1 || fail "second install failed"
records=($SANDBOX/home/.shell-backups/*/existing(N))
(( $#records >= 1 )) || fail "second install wrote no existing record"
assert_contains "$(<${records[-1]})" ".zshrc" "second install backed up .zshrc"

count=$(HOME=$SANDBOX/home git config --global --get-all include.path | command grep -c shell-tools)
assert_eq "$count" 1 "shell-tools include is not duplicated"
finish
