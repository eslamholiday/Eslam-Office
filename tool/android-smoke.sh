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

# Exercise the new input settings and its real, non-posting form preview.
python3 - <<'PY'
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

def adb(*args):
    return subprocess.check_output(['adb', *args])

def tap(label):
    adb('shell', 'uiautomator', 'dump', '/sdcard/eslam-inputs.xml')
    xml = adb('shell', 'cat', '/sdcard/eslam-inputs.xml')
    root = ET.fromstring(xml)
    nodes = [n for n in root.iter('node')
             if label in (n.get('text', '') + ' ' + n.get('content-desc', ''))]
    assert nodes, f'Missing control: {label}'
    nodes.sort(key=lambda n: len(n.get('text', '') + n.get('content-desc', '')))
    points = [int(v) for v in re.findall(r'\d+', nodes[0].get('bounds', ''))]
    assert len(points) == 4, label
    adb('shell', 'input', 'tap', str((points[0] + points[2]) // 2), str((points[1] + points[3]) // 2))
    time.sleep(1)

tap('الإعدادات')
tap('تخصيص كل الإدخالات والقوائم')
tap('التذاكر والتغيير')
Path('smoke-output/input-settings.png').write_bytes(adb('exec-out', 'screencap', '-p'))
tap('معاينة النموذج')
Path('smoke-output/ticket-input-preview.png').write_bytes(adb('exec-out', 'screencap', '-p'))
adb('shell', 'uiautomator', 'dump', '/sdcard/eslam-preview.xml')
preview = adb('shell', 'cat', '/sdcard/eslam-preview.xml').decode()
Path('smoke-output/ticket-input-preview.xml').write_text(preview)
assert 'معاينة' in preview and ('حساب الزبون' in preview or 'ابحث عن حقل' in preview)
# Back out of the non-posting preview and customization; exercise appearance.
adb('shell', 'input', 'keyevent', '4'); time.sleep(1)
adb('shell', 'input', 'keyevent', '4'); time.sleep(1)
adb('shell', 'input', 'keyevent', '4'); time.sleep(1)
tap('الثيمات والألوان والخطوط')
Path('smoke-output/appearance.png').write_bytes(adb('exec-out', 'screencap', '-p'))
adb('shell', 'input', 'keyevent', '4'); time.sleep(1)
# Scroll the settings hub to the feedback controls, then test actual channels.
adb('shell', 'input', 'swipe', '550', '1600', '550', '900', '450'); time.sleep(1)
tap('الاهتزاز')
tap('تجربة الاهتزاز')
Path('smoke-output/haptics.png').write_bytes(adb('exec-out', 'screencap', '-p'))
tap('الصوت')
Path('smoke-output/sounds.png').write_bytes(adb('exec-out', 'screencap', '-p'))
logs = adb('logcat', '-d').decode(errors='replace')
Path('smoke-output/input-logcat.txt').write_text(logs)
assert not re.search(r'FATAL EXCEPTION|SQLiteException|A RenderFlex overflowed', logs)
PY
