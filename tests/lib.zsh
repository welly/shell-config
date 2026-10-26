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
sbx_i() ( builtin cd -q -- "$SANDBOX/home" && HOME=$SANDBOX/home XDG_CACHE_HOME= XDG_CONFIG_HOME= XDG_DATA_HOME= ZDOTDIR=$SANDBOX/home zsh -i -c "$1" 2>"$SANDBOX/stderr" )
sbx_c() ( builtin cd -q -- "$SANDBOX/home" && HOME=$SANDBOX/home ZDOTDIR=$SANDBOX/home zsh -c "$1" 2>"$SANDBOX/stderr" )

finish() {
  [[ -n $SANDBOX && -d $SANDBOX ]] && command rm -rf -- "$SANDBOX"
  exit $(( TEST_FAILS > 0 ))
}
