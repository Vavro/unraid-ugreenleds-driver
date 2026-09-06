# Unraid UGREEN LED Driver Plugin (Settings UI Fork)

This is a fork of [ich777/unraid-ugreenleds-driver](https://github.com/ich777/unraid-ugreenleds-driver), which itself is based on [miskcoo/ugreen_dx4600_leds_controller](https://github.com/miskcoo/ugreen_dx4600_leds_controller). All credit for the original LED driver, disk/network monitoring daemon, and kernel module support goes to **ich777** and **miskcoo** — this fork only adds a configuration UI and a few new features on top of their work.

This fork is a reviewed, fail-closed build for DrogonNAS on Unraid 7.3.2. It
does not follow mutable upstream branches at runtime. The plugin payload,
I2C tools, update helper, and kernel module are pinned to reviewed artifacts
and verified with SHA-256.

**Install URL:** `https://raw.githubusercontent.com/Vavro/unraid-ugreenleds-driver/v2026.09.06.4/ugreenleds-driver.plg`

## What This Fork Adds

The upstream plugin only shows a README on the Plugins tab — there is no way to change `settings.cfg` without editing it over SSH. This fork adds:

- **Settings UI page** under **Settings → Utilities → UGREEN LEDs** — edit every `settings.cfg` option from the webGUI, no SSH required
- **Night mode** — automatically dim the disk, power, and network LEDs during a configurable time window, then restore day brightness
- **Configurable disk LED invert** — choose between "activity only" (LEDs off when idle, flash on I/O) and "always on" (original upstream behavior)
- **Daemon status indicator** — see at a glance whether the `ugreen-leds` daemon is running, plus your detected NAS model
- **Live color preview** — color pickers push changes straight to the LEDs so you can see them before clicking Apply

Everything else — disk/network monitoring, supported models, LED color meanings — is unchanged from upstream. See the [original README](https://github.com/ich777/unraid-ugreenleds-driver/blob/master/README.md) for background on how the daemon and sysfs LED interface work.

## Supported UGREEN Models

Same as upstream:
- **DXP6800** series (tested on DXP6800 Pro)
- **DX4600** series (tested on DX4600 Pro)
- **DX4700** series
- **DXP2800** series
- **DXP4800** series
- **DXP8800** series (tested on DXP8800 Plus)
- **DXP480T** series (tested on DXP480T Plus) — static white LED only, no settings UI effect

## New settings.cfg Keys

| Key | Default | Description |
|-----|---------|-------------|
| `BRIGHTNESS_NIGHT` | `"15"` | Brightness (0-255) used for disk/power/network LEDs during the night window |
| `BRIGHTNESS_POWER_DAY` | `"128"` | Power LED brightness (0-255) outside the night window |
| `NIGHT_MODE_ENABLED` | `"false"` | Enable/disable night mode |
| `NIGHT_START_HOUR` | `"22"` | Hour (0-23) night mode begins |
| `NIGHT_END_HOUR` | `"7"` | Hour (0-23) night mode ends |
| `DISK_LED_INVERT` | `"1"` | `1` = always on, blink on activity (upstream default); `0` = off when idle, on during activity |

These are added automatically to existing installs the first time you update — no manual editing needed.

## Installation

From **Plugins → Install Plugin** in the Unraid webGUI, paste:

```
https://raw.githubusercontent.com/Vavro/unraid-ugreenleds-driver/v2026.09.06.4/ugreenleds-driver.plg
```

Or from the CLI:

```bash
plugin install https://raw.githubusercontent.com/Vavro/unraid-ugreenleds-driver/v2026.09.06.1/ugreenleds-driver.plg
```

## Update policy

This fork intentionally does not update itself from `master`.

- The plugin update URL points to immutable tag `v2026.09.06.4`.
- Installation is restricted to Unraid 7.3.2 and kernel 6.18.38-Unraid.
- A newer Unraid kernel must fail closed until its driver artifact and source
  are reviewed and a new tagged plugin release is published.
- Updating the helper requires reviewing a new upstream commit and changing
  both its commit pin and SHA-256 in the plugin descriptor.
- Do not move or rewrite published release tags.

The upstream projects remain the source for future changes, but updates are
merged manually after review rather than consumed automatically.

## Migration from a Manual `/boot/config/go` Patch

If you previously worked around the missing invert/night-mode support by patching `/boot/config/go` (e.g. a `sed` command forcing `invert`, or your own LED dimming cron lines), **remove those lines** after installing this plugin. The plugin now owns:

- the disk LED `invert` value (via `DISK_LED_INVERT` in `settings.cfg`, applied by the daemon itself)
- the night-mode dimming schedule (via `night-mode.cron`, regenerated on every Apply/boot)

Leaving your old `go` file edits in place will conflict with the plugin's settings UI and cron management.

## Support

Issues and questions for this fork: https://github.com/Vavro/unraid-ugreenleds-driver/issues

For questions about the underlying driver/daemon behavior unrelated to the settings UI, the upstream support thread is also a good resource: https://forums.unraid.net/topic/92865-support-ich777-amd-vendor-reset-coraltpu-hpsahba/
