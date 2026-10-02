#!/usr/bin/env bash
set -euo pipefail
mkdir -p smoke-output
apk_path="$(find apk -name '*.apk' -print -quit)"
adb install -r "$apk_path"
adb shell svc wifi disable
adb shell svc data disable
adb logcat -c
app_package=com.eslamholiday.eslam_office.preview
adb shell am start -W -n "$app_package/com.eslamholiday.eslam_office.MainActivity"
sleep 12
adb shell pidof "$app_package"
adb shell uiautomator dump /sdcard/window.xml
adb pull /sdcard/window.xml smoke-output/window.xml
adb exec-out screencap -p > smoke-output/startup.png
adb logcat -d > smoke-output/logcat.txt
if grep -E 'FATAL EXCEPTION|Unable to load asset|SQLiteException|A RenderFlex overflowed' smoke-output/logcat.txt; then
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
s=Path('smoke-output/window.xml').read_text()
assert 'الرئيسية' in s or 'أهلًا إسلام' in s, 'Home screen did not appear'
PY
adb shell am force-stop "$app_package"
adb shell am start -W -n "$app_package/com.eslamholiday.eslam_office.MainActivity"
sleep 5
adb shell pidof "$app_package"
