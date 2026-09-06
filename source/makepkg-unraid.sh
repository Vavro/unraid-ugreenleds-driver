#!/bin/bash
# Build packages/ugreenleds-driver-<VERSION>.txz from source/usr.
# Runs on macOS (bsdtar/md5) or Unraid/Linux (GNU tar/md5sum).
# VERSION defaults to today, override to reproduce a past build:
#   VERSION=2026.09.06 ./makepkg-unraid.sh
set -euo pipefail

PLUGIN_NAME="ugreenleds-driver"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SRC_DIR/../packages"
VERSION="${VERSION:-$(date +'%Y.%m.%d')}"
PKG="$PKG_DIR/$PLUGIN_NAME-$VERSION.txz"

[ -d "$SRC_DIR/usr" ] || { echo "missing $SRC_DIR/usr" >&2; exit 1; }
for f in \
  usr/bin/ugreen-leds \
  usr/local/emhttp/plugins/ugreenleds-driver/ugreenleds-driver.page \
  usr/local/emhttp/plugins/ugreenleds-driver/include/preview.php \
  usr/local/emhttp/plugins/ugreenleds-driver/include/apply.sh
do
  [ -f "$SRC_DIR/$f" ] || { echo "missing required source file: $f" >&2; exit 1; }
done

mkdir -p "$PKG_DIR"
cd "$SRC_DIR"

# Tar the usr/ tree only (never compile.sh/makepkg-unraid.sh, they live outside it).
# Force root:root ownership since the build host isn't root, no leading ./, no xattrs.
if command -v bsdtar >/dev/null 2>&1; then
  # --no-xattrs/--no-mac-metadata are required: macOS stamps com.apple.provenance on
  # the sources, and bsdtar would otherwise embed it as pax headers in the archive.
  COPYFILE_DISABLE=1 bsdtar --uid 0 --gid 0 --uname root --gname root \
    --no-xattrs --no-mac-metadata -cJf "$PKG" usr
else
  tar --owner=root --group=root --numeric-owner --xattrs-exclude='*' -cJf "$PKG" usr
fi

cd "$PKG_DIR"
if command -v md5 >/dev/null 2>&1; then
  md5 -q "$(basename "$PKG")" | awk -v f="$(basename "$PKG")" '{print $1"  "f}' > "$(basename "$PKG").md5"
else
  md5sum "$(basename "$PKG")" > "$(basename "$PKG").md5"
fi

echo "built $PKG"
cat "$PKG.md5"
echo "remember to update &package-version; and &md5; in ugreenleds-driver.plg (not done by this script)"
