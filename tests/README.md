# Plugin validation

The Docker smoke test validates the installer without loading the kernel module
or requiring an Unraid license:

- Parses the plugin XML and expands its internal entities.
- Runs `bash -n` against every embedded shell script.
- Downloads and verifies the pinned helper and kernel package.
- Uses command paths observed on DrogonNAS running Unraid 7.3.2.
- Exercises first installation, cached installation, corruption recovery, and
  rejection of an unsupported kernel.
- Confirms the exact kernel package passed to `installpkg`, helper placement,
  and commands submitted through `at`.

Run from the repository root:

```powershell
docker build --quiet -f tests\Dockerfile -t ugreen-led-plugin-smoke:v2026.09.06.3 .
docker run --rm ugreen-led-plugin-smoke:v2026.09.06.3
```

`tests/fixtures/unraid-7.3.2.env` contains only non-sensitive observations from
the read-only environment probe. The probe intentionally excludes disk serial
numbers and other complete hardware identifiers.

The container cannot validate Unraid's running kernel, I2C/SMBus behavior,
physical LEDs, or the complete boot lifecycle. Those require staged validation
on the target NAS after parity and other critical storage operations finish.
