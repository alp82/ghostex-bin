#!/usr/bin/env bash
set -euo pipefail
mkdir /build
cp /repo/PKGBUILD /build/
chown builder:builder /build
cd /build
runuser -u builder -- makepkg --syncdeps --noconfirm
runuser -u builder -- makepkg --printsrcinfo > /out/.SRCINFO
mapfile -t packages < <(runuser -u builder -- makepkg --packagelist)
test "${#packages[@]}" -eq 1
package=${packages[0]}
namcap PKGBUILD "$package" | tee /out/namcap.log
# Upstream's self-contained binary tree belongs in /opt. Namcap currently
# flags ELF placement there; allow only that exact diagnostic.
# CEF/downloaded runtime and prebuilt hardening warnings remain in the report.
if grep ' E: ' /out/namcap.log | grep -Fvx "ghostex-bin E: ELF files outside of a valid path ('opt/')."; then
  exit 1
fi
pacman -U --noconfirm "$package"
desktop-file-validate /usr/share/applications/ghostex.desktop
test "$(readlink /usr/bin/gx)" = ghostex
test -f /usr/share/licenses/ghostex-bin/LICENSE
ghostex --help > /out/cli-help.txt
gx --help > /out/gx-help.txt
cmp /out/cli-help.txt /out/gx-help.txt
ldd /opt/ghostex/Ghostex | tee /out/ldd.txt
if grep -q 'not found' /out/ldd.txt; then exit 1; fi
: > /out/cef-ldd.txt
for binary in /opt/ghostex/ghostex-gpui-runtime /opt/ghostex/ghostex-gpui-cef-helper; do
  ldd "$binary" | tee -a /out/cef-ldd.txt
done
if grep 'not found' /out/cef-ldd.txt | grep -v 'libcef.so => not found'; then exit 1; fi
# Exercise reinstall/upgrade and verify pacman removes the owned files.
pacman -U --noconfirm "$package"
cp "$package" /out/
pacman -R --noconfirm ghostex-bin
test ! -e /usr/bin/ghostex
test ! -L /usr/bin/gx
test ! -e /opt/ghostex
test ! -e /usr/share/applications/ghostex.desktop
echo 'Package build, install, CLI, dependency, reinstall and removal checks passed.'
