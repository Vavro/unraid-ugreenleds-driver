#!/bin/bash
# fork: apply/restart helper for the UGREEN LEDs settings page
# Usage: apply.sh {apply|restart|cron}
set -u

CFG="/boot/config/plugins/ugreenleds-driver/settings.cfg"
CRON_FILE="/boot/config/plugins/ugreenleds-driver/night-mode.cron"

do_cron() {
  # shellcheck disable=SC1090
  source "$CFG"

  if [ "${NIGHT_MODE_ENABLED:-false}" == "true" ] && [ "${NIGHT_START_HOUR:-22}" != "${NIGHT_END_HOUR:-7}" ]; then
    {
      echo "# ugreenleds-driver night mode — regenerated on every apply, do not edit by hand"
      echo "0 ${NIGHT_START_HOUR:-22} * * * /usr/local/emhttp/plugins/ugreenleds-driver/include/apply.sh restart"
      echo "0 ${NIGHT_END_HOUR:-7} * * * /usr/local/emhttp/plugins/ugreenleds-driver/include/apply.sh restart"
    } > "$CRON_FILE"
  else
    rm -f "$CRON_FILE"
  fi

  command -v update_cron >/dev/null 2>&1 && update_cron
}

do_restart() {
  pid="$(pgrep -f "/usr/bin/ugreen-leds")"
  [ -n "$pid" ] && kill $pid 2>/dev/null
  sleep 1
  # fork: clear stale lockfile (daemon killed without running its EXIT trap)
  if ! pgrep -f "/usr/bin/ugreen-leds" >/dev/null 2>&1; then
    rm -f /var/run/ugreen-leds.lock
  fi
  echo "/usr/bin/ugreen-leds" | at now -M
}

case "${1:-apply}" in
  cron)
    do_cron
    ;;
  restart)
    do_restart
    ;;
  apply)
    do_cron
    do_restart
    ;;
  *)
    echo "Usage: apply.sh {apply|restart|cron}" >&2
    exit 1
    ;;
esac
