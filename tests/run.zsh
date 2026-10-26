#!/bin/zsh
# Run every tests/test_*.zsh in its own zsh process.
set -u
root=${0:A:h}
failed=0
for t in $root/test_*.zsh(N); do
  if zsh "$t"; then
    print -r -- "ok   ${t:t}"
  else
    print -r -- "FAIL ${t:t}"
    failed=1
  fi
done
exit $failed
