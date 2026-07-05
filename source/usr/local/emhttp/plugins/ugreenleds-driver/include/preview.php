<?php
// fork: live LED color preview — writes directly to sysfs, settings.cfg untouched

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
  http_response_code(400);
  exit;
}

$target = $_POST['target'] ?? '';

if (!in_array($target, array('disk', 'netdev', 'reset'), true)) {
  http_response_code(400);
  exit;
}

function ugreenleds_valid_color($v) {
  if (!preg_match('/^([0-9]{1,3}) ([0-9]{1,3}) ([0-9]{1,3})$/', trim((string)$v), $m)) return false;
  return (int)$m[1] <= 255 && (int)$m[2] <= 255 && (int)$m[3] <= 255;
}

// fork: target=reset restores the configured healthy-disk color (e.g. page closed without Apply)
if ($target === 'reset') {
  $cfg = @parse_ini_file('/boot/config/plugins/ugreenleds-driver/settings.cfg');
  $color = is_array($cfg) ? ($cfg['COLOR_DISK_HEALTH'] ?? '') : '';
  if (!ugreenleds_valid_color($color)) {
    http_response_code(400);
    exit;
  }
  foreach (glob('/sys/class/leds/disk*/color') as $file) {
    @file_put_contents($file, trim((string)$color));
  }
  exit;
}

$color = trim((string)($_POST['color'] ?? ''));

if (!ugreenleds_valid_color($color)) {
  http_response_code(400);
  exit;
}

if ($target === 'disk') {
  foreach (glob('/sys/class/leds/disk*/color') as $file) {
    @file_put_contents($file, $color);
  }
} else {
  @file_put_contents('/sys/class/leds/netdev/color', $color);
}
