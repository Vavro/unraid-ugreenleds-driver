#!/bin/bash
set -euo pipefail

output="${1:-/mnt/user/media/incomming/scripts/state/unraid-plugin-environment.txt}"
temporary="${output}.tmp"
mkdir -p "$(dirname "${output}")"

{
  echo "captured_at=$(date --iso-8601=seconds)"
  echo "kernel=$(uname -r)"
  if [ -r /etc/unraid-version ]; then
    sed 's/^/unraid_/' /etc/unraid-version
  fi

  echo
  echo "[commands]"
  for command_name in \
    uname sha256sum wget install modinfo installpkg depmod at update_cron \
    pgrep pkill plugin; do
    command_path="$(command -v "${command_name}" 2>/dev/null || true)"
    printf '%s=%s\n' "${command_name}" "${command_path:-missing}"
  done

  plugin_command="$(command -v plugin 2>/dev/null || true)"
  if [ -n "${plugin_command}" ] && [ -r "${plugin_command}" ]; then
    echo
    echo "[plugin-manager-capabilities]"
    grep -nE 'SHA256|plugin.*min|plugin.*max|version_compare' \
      "${plugin_command}" | head -80 || true
  fi

  echo
  echo "[array]"
  grep -E \
    '^(sbSyncErrs|sbSyncExit|mdState|mdNumDisks|mdNumDisabled|mdNumReplaced|mdNumInvalid|mdNumMissing|mdNumWrong|mdResyncAction|mdResyncSize|mdResyncCorr|mdResync|mdResyncPos|mdResyncDt|mdResyncDb)=' \
    /proc/mdstat 2>/dev/null || true

  echo
  echo "[docker]"
  docker ps --format \
    'name={{.Names}} image={{.Image}} status={{.Status}}' 2>/dev/null || true

  echo
  echo "[led-sysfs]"
  find /sys/class/leds -mindepth 1 -maxdepth 1 -printf '%f\n' \
    2>/dev/null | sort || true

  echo
  echo "[i2c-adapters]"
  for adapter in /sys/class/i2c-adapter/i2c-*; do
    [ -e "${adapter}" ] || continue
    adapter_name="$(cat "${adapter}/name" 2>/dev/null || true)"
    printf '%s=%s\n' "$(basename "${adapter}")" "${adapter_name}"
  done

  echo
  echo "[existing-ugreen-components]"
  find /boot/config/plugins -maxdepth 2 \
    \( -iname '*ugreen*' -o -iname '*led*' \) -print 2>/dev/null | sort || true
  modinfo led-ugreen 2>&1 || true
  pgrep -af 'ugreen-leds|plugin_update_helper' || true

  echo
  echo "[at-smoke-test]"
  marker="/tmp/ugreen-plugin-at-test-$$"
  rm -f "${marker}"
  printf 'printf observed > %q\n' "${marker}" | at now -M >/dev/null 2>&1 || true
  sleep 2
  if [ -f "${marker}" ] && [ "$(cat "${marker}")" = "observed" ]; then
    echo "at_executes_commands=true"
  else
    echo "at_executes_commands=false"
  fi
  rm -f "${marker}"
} > "${temporary}"

chmod 0644 "${temporary}"
mv -f "${temporary}" "${output}"
echo "${output}"
