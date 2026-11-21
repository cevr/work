#!/bin/sh
# pack.sh NAME [--pack DIR | --publish]: build and pack the binary package
# NAME of npm/ (a folder npm/NAME with its platform folders): the static binary of
# cmd/NAME for each platform package (CGO_ENABLED=0), the shared
# launcher into a wrapper that takes it, then each package's tarball. With
# no flag it publishes nothing: `npm pack --dry-run` lists each tarball's
# files and sizes. --pack DIR writes the tarballs into DIR. --publish runs
# npm publish (the owner's step).
# ERGO is the ergo binary (default: ergo on PATH).
set -eu
name=${1:?usage: pack.sh NAME [--pack DIR | --publish]}
mode=${2:-}
packdir=${3:-}
[ "$mode" != --pack ] || [ -n "$packdir" ] || { echo "pack.sh: --pack needs a folder" >&2; exit 2; }
root=$(cd "$(dirname "$0")/.." && pwd)
ergo=${ERGO:-ergo}
npm=$root/npm
[ -d "$npm/$name" ] && [ -f "$root/cmd/$name/main.ergo" ] || { echo "pack.sh: no package $name (npm/$name and cmd/$name)" >&2; exit 2; }
program=. launcher=shared
for plat in linux/amd64:linux-x64 linux/arm64:linux-arm64 darwin/arm64:darwin-arm64; do
	target=${plat%%:*}
	dir=$npm/$name-${plat#*:}
	mkdir -p "$dir/bin"
	(cd "$root/$program" && CGO_ENABLED=0 "$ergo" build "./cmd/$name" --platform "$target" -o "$dir/bin/$name")
	chmod 755 "$dir/bin/$name"
done
if [ "$launcher" = shared ]; then
	mkdir -p "$npm/$name/bin"
	cp "$npm/launcher/launcher.sh" "$npm/$name/bin/$name"
	chmod 755 "$npm/$name/bin/$name"
	cp "$npm/launcher/install.js" "$npm/$name/install.js"
fi
for pkg in "$name-linux-x64" "$name-linux-arm64" "$name-darwin-arm64" "$name"; do
	case "$mode" in
	--publish) (cd "$npm/$pkg" && npm publish --access public) ;;
	--pack) (cd "$npm/$pkg" && npm pack --pack-destination "$packdir") ;;
	*) (cd "$npm/$pkg" && npm pack --dry-run) ;;
	esac
done
