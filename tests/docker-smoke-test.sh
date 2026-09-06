#!/bin/bash
set -euo pipefail

source /repo/tests/fixtures/unraid-7.3.2.env
export KERNEL_VERSION

PLUGIN=/repo/ugreenleds-driver.plg
PLUGIN_PACKAGE=/repo/packages/ugreenleds-driver-2026.09.06.2.txz
I2C_PACKAGE=/repo/packages/i2c-tools-4.3-x86_64-1.txz
EXPECTED_PLUGIN_SHA=0d68803a1fbf304d3dfb3c41f3085cab12bec95a052c2fbe7673d3eddf0f0875
EXPECTED_I2C_SHA=9730e890d81743f4827715ae38019715fe8252c9bc6d95af4b5f64339238106c
EXPECTED_HELPER_SHA=e528862eb9499b952d44cdd9b3ee1a44f3c7803cc7ea979272a5bb18e365b043
EXPECTED_KERNEL_SHA=744a5bcb62fa0d8a831897617800b29c330026981e14e3041829383329648afa
KERNEL_PACKAGE=ugreen_leds-20260705-6.18.38-Unraid-1.txz

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_hash() {
  local expected="$1"
  local path="$2"
  echo "${expected}  ${path}" | sha256sum -c - >/dev/null ||
    fail "Unexpected SHA-256 for ${path}"
}

xmllint --noout "${PLUGIN}"

SETTINGS_PAGE=/repo/source/usr/local/emhttp/plugins/ugreenleds-driver/ugreenleds-driver.page
if grep -F 'parent.window.location.reload()' "${SETTINGS_PAGE}" >/dev/null; then
  fail "Settings POST handlers can replay submissions through location.reload()"
fi
test "$(grep -Fc 'parent.window.location.replace(parent.window.location.pathname + parent.window.location.search)' "${SETTINGS_PAGE}")" -eq 2 ||
  fail "Apply and restart handlers must redirect to an explicit GET"

for index in 1 2 3 4; do
  script="/tmp/inline-${index}.sh"
  xmllint --noent \
    --xpath "string((//FILE[@Run='/bin/bash']/INLINE)[${index}])" \
    "${PLUGIN}" > "${script}"
  bash -n "${script}"
done

assert_hash "${EXPECTED_PLUGIN_SHA}" "${PLUGIN_PACKAGE}"
assert_hash "${EXPECTED_I2C_SHA}" "${I2C_PACKAGE}"

mkdir -p \
  /boot/config/plugins/ugreenleds-driver/packages \
  /usr/local/sbin

tar -xJf "${PLUGIN_PACKAGE}" -C /

for text_file in \
  /usr/bin/ugreen-leds \
  /usr/local/emhttp/plugins/ugreenleds-driver/ugreenleds-driver.page \
  /usr/local/emhttp/plugins/ugreenleds-driver/include/apply.sh \
  /usr/local/emhttp/plugins/ugreenleds-driver/include/preview.php; do
  if grep -q $'\r' "${text_file}"; then
    fail "Packaged text file contains CRLF endings: ${text_file}"
  fi
done

bash -n /usr/bin/ugreen-leds
bash -n /usr/local/emhttp/plugins/ugreenleds-driver/include/apply.sh
grep -F 'restore_power_led' /usr/bin/ugreen-leds >/dev/null ||
  fail "The daemon does not restore normal power LED state on restart"

rm -f \
  /usr/bin/uname \
  /sbin/modinfo \
  /sbin/installpkg \
  /sbin/depmod \
  /usr/bin/at \
  /usr/local/sbin/update_cron

cat > /usr/bin/uname <<'EOF'
#!/bin/bash
if [ "${1:-}" = "-r" ]; then
  printf '%s\n' "${MOCK_KERNEL:-${KERNEL_VERSION}}"
else
  exec /bin/busybox uname "$@"
fi
EOF

cat > /sbin/modinfo <<'EOF'
#!/bin/bash
test -f /tmp/module-installed
EOF

cat > /usr/bin/at <<'EOF'
#!/bin/bash
cat >> /tmp/at-commands
EOF

cat > /usr/local/sbin/update_cron <<'EOF'
#!/bin/bash
exit 0
EOF

cat > /sbin/installpkg <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> /tmp/installpkg-paths
test "$#" -eq 1 || exit 1
test -f "$1" || exit 1
touch /tmp/module-installed
EOF

cat > /sbin/depmod <<'EOF'
#!/bin/bash
exit 0
EOF

chmod +x \
  /usr/bin/uname \
  /sbin/modinfo \
  /usr/bin/at \
  /usr/local/sbin/update_cron \
  /sbin/installpkg \
  /sbin/depmod

for expected_path in \
  "${SHA256SUM_PATH}" \
  "${WGET_PATH}" \
  "${INSTALL_PATH}" \
  "${MODINFO_PATH}" \
  "${INSTALLPKG_PATH}" \
  "${DEPMOD_PATH}" \
  "${AT_PATH}" \
  "${UPDATE_CRON_PATH}" \
  "${PGREP_PATH}" \
  "${PKILL_PATH}"; do
  test -x "${expected_path}" ||
    fail "Observed Unraid command path is unavailable in the harness: ${expected_path}"
done

MAIN_SCRIPT=/tmp/inline-3.sh
rm -f /tmp/module-installed
: > /tmp/installpkg-paths
if modinfo led-ugreen -0 >/dev/null 2>&1; then
  fail "The pre-install modinfo mock should report the module as absent"
fi

bash "${MAIN_SCRIPT}"

PLUGIN_STATE=/boot/config/plugins/ugreenleds-driver
KERNEL_PATH="${PLUGIN_STATE}/packages/6.18.38/${KERNEL_PACKAGE}"

test -f "${PLUGIN_STATE}/settings.cfg" ||
  fail "The default settings file was not created"
bash /usr/local/emhttp/plugins/ugreenleds-driver/include/apply.sh cron ||
  fail "The packaged settings helper did not execute successfully"
assert_hash "${EXPECTED_HELPER_SHA}" "${PLUGIN_STATE}/plugin_update_helper"
assert_hash "${EXPECTED_HELPER_SHA}" /usr/bin/plugin_update_helper
assert_hash "${EXPECTED_KERNEL_SHA}" "${KERNEL_PATH}"
grep -Fx "${KERNEL_PATH}" /tmp/installpkg-paths >/dev/null ||
  fail "The exact pinned kernel package was not passed to installpkg"
grep -Fx "/usr/bin/ugreen-leds" /tmp/at-commands >/dev/null ||
  fail "The LED daemon was not scheduled"
grep -Fx "/usr/bin/plugin_update_helper" /tmp/at-commands >/dev/null ||
  fail "The update helper was not scheduled"
test "$(wc -l < /tmp/installpkg-paths)" -eq 1 ||
  fail "The first run should install the kernel package exactly once"

printf 'corrupt\n' > "${PLUGIN_STATE}/plugin_update_helper"
printf 'corrupt\n' > /usr/bin/plugin_update_helper
printf 'corrupt\n' > "${KERNEL_PATH}"
bash "${MAIN_SCRIPT}"

assert_hash "${EXPECTED_HELPER_SHA}" "${PLUGIN_STATE}/plugin_update_helper"
assert_hash "${EXPECTED_HELPER_SHA}" /usr/bin/plugin_update_helper
assert_hash "${EXPECTED_KERNEL_SHA}" "${KERNEL_PATH}"
test "$(wc -l < /tmp/installpkg-paths)" -eq 1 ||
  fail "A loaded module should not be reinstalled"

if MOCK_KERNEL=6.18.39-Unraid bash "${MAIN_SCRIPT}" >/tmp/wrong-kernel.log 2>&1; then
  fail "The installer accepted an unsupported kernel"
fi
grep -F "supports kernel ${KERNEL_VERSION}, not 6.18.39-Unraid" \
  /tmp/wrong-kernel.log >/dev/null ||
  fail "The unsupported-kernel failure was not explicit"

echo "PASS: hardened plugin installer smoke test"
