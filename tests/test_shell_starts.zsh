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
