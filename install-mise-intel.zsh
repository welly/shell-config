#!/bin/zsh
# Official pinned Intel binary, without a local Rust compilation.
set -eu
[[ $OSTYPE == darwin* && $(uname -m) == x86_64 ]] || { print -u2 'This installer targets Intel macOS.'; exit 1; }
version=2026.10.9
checksum=4773fdef758c8d121be63b7c26d31dd61c4a9b8e2ae5efd03b3bb9fe2b81cb8d
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
downloaded=false
for attempt in {1..5}; do
  if curl --silent --show-error --fail --location --continue-at - \
    --connect-timeout 20 --max-time 180 \
    "https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-macos-x64.tar.xz" \
    --output "$tmp/mise.tar.xz"; then
    downloaded=true
    break
  fi
  print -u2 "Download interrupted; resuming (attempt $attempt of 5)."
done
[[ $downloaded == true ]] || { print -u2 'Mise download failed; rerun bootstrap.'; exit 1; }
(cd "$tmp"; print -r -- "$checksum  mise.tar.xz" | shasum -a 256 -c -)
tar -xJf "$tmp/mise.tar.xz" -C "$tmp"
binaries=("$tmp"/**/mise(.N))
[[ ${#binaries} == 1 ]] || { print -u2 'Expected one mise executable in archive.'; exit 1; }
mkdir -p "$HOME/.local/bin"
install -m 755 "$binaries[1]" "$HOME/.local/bin/mise"
"$HOME/.local/bin/mise" --version
