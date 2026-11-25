#!/usr/bin/env bash
set -euo pipefail
mkdir -p smoke-output
apk_path="$(find apk -name 'app-debug.apk' -print -quit)"
adb install -r "$apk_path"
test_apk="$(find apk -name 'app-debug-androidTest.apk' -print -quit)"
adb install -r "$test_apk"
adb shell cmd notification allow_dnd com.eslamholiday.eslam_office.preview
adb shell am instrument -w com.eslamholiday.eslam_office.preview.test/com.eslamholiday.eslam_office.FeedbackSoundInstrumentation | tee smoke-output/native-audio.txt
python3 - <<'PY'
from pathlib import Path
result = Path('smoke-output/native-audio.txt').read_text()
assert 'INSTRUMENTATION_CODE: -1' in result and 'OK: 41 decoded/playback checks' in result, result
PY
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
import json
import sqlite3
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

def adb(*args):
    return subprocess.check_output(['adb', *args])

def dump():
    adb('shell', 'uiautomator', 'dump', '/sdcard/eslam-inputs.xml')
    return adb('shell', 'cat', '/sdcard/eslam-inputs.xml')

def tap(label, scroll=True):
    for attempt in range(9 if scroll else 1):
        xml = dump()
        root = ET.fromstring(xml)
        nodes = [n for n in root.iter('node')
                 if label in (n.get('text', '') + ' ' + n.get('content-desc', ''))]
        if nodes:
            break
        adb('shell', 'input', 'swipe', '550', '1700', '550', '800', '350')
        time.sleep(.5)
    if not nodes:
        Path('smoke-output/missing-control.xml').write_bytes(xml)
        Path('smoke-output/missing-control.png').write_bytes(adb('exec-out', 'screencap', '-p'))
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
adb('shell', 'input', 'keyevent', '4'); time.sleep(1)
tap('الصوت')
tap('نسيم هادئ')
Path('smoke-output/sound-packs.png').write_bytes(adb('exec-out', 'screencap', '-p'))
tap('زجاج كريستالي')
tap('التنقل والرجوع')
Path('smoke-output/sounds.png').write_bytes(adb('exec-out', 'screencap', '-p'))
# Seed only this disposable emulator database with artificial service records.
pkg = 'com.eslamholiday.eslam_office.preview'
adb('shell', 'am', 'force-stop', pkg)
seed = Path('smoke-output/test-office.db')
seed.write_bytes(adb('exec-out', 'run-as', pkg, 'cat', 'databases/eslam_office.db'))
db = sqlite3.connect(seed)
def party(kind, name):
    return db.execute('INSERT INTO parties(kind,name,phone,payload,archived) VALUES(?,?,?,?,0)',
                      (kind, name, '', '{}')).lastrowid
customer, supplier = party('customer', 'حساب تجريبي'), party('supplier', 'جهة تجريبية')
cities = [r[0] for r in db.execute('SELECT id FROM refs WHERE kind="city" ORDER BY id')]
country = db.execute('SELECT id FROM refs WHERE kind="country" ORDER BY id').fetchone()[0]
records = [
    dict(kind='ticket', lines=[dict(qty=1,base=10000,gross=11000,sell=15000)], sale=15000,cost=11000,profit=4000,commission=0,rate=0,qty=1,**{'from':cities[0],'to':cities[-1]},depart='2026-11-25',**{'return':'2026-11-29'}),
    dict(kind='hotel',hotelName='فندق تجريبي',city=cities[-1],checkIn='2026-11-25',checkOut='2026-11-29',qty=1,sell=20000,costUnit=16000,sale=20000,cost=16000,profit=4000),
    dict(kind='visa',visaType='سياحية',country=country,days='30',qty=1,sell=10000,costUnit=8000,sale=10000,cost=8000,profit=2000),
    dict(kind='settlement',partyType='customer',direction=-1,settlementMode='cash',amount=5000),
]
for record in records:
    record.update(currency='USD',date='2026-11-25',posted=True,customer=customer,paymentMethod='bank',notes='تفاصيل للتجربة فقط')
    if record['kind'] != 'settlement': record['supplier'] = supplier
    eid=db.execute('INSERT INTO entries(kind,currency,date,customer,supplier,posted,payload) VALUES(?,?,?,?,?,1,?)',
                   (record['kind'],'USD',record['date'],customer,record.get('supplier'),json.dumps(record,ensure_ascii=False))).lastrowid
    journal = [('receivable',customer,record['sale'],0),('revenue',None,0,record['sale']),('cogs',None,record['cost'],0),('payable',supplier,0,record['cost'])] if record['kind'] != 'settlement' else [('cash',None,5000,0),('receivable',customer,0,5000)]
    for account,pid,debit,credit in journal:
        db.execute('INSERT INTO ledger(entry_id,currency,account,party,debit,credit) VALUES(?,?,?,?,?,?)',(eid,'USD',account,pid,debit,credit))
db.commit(); db.close()
adb('push',str(seed),'/data/local/tmp/eslam-test-office.db')
adb('shell','run-as',pkg,'rm','-f','databases/eslam_office.db-wal','databases/eslam_office.db-shm')
adb('shell','run-as',pkg,'cp','/data/local/tmp/eslam-test-office.db','databases/eslam_office.db')
adb('shell','am','start','-W','-n',pkg+'/com.eslamholiday.eslam_office.MainActivity'); time.sleep(4)
tap('الزبائن')
tap('حساب تجريبي')
tap('كشف الحساب')
Path('smoke-output/statement-settings.png').write_bytes(adb('exec-out','screencap','-p'))
tap('معاينة الكشف'); time.sleep(5)
Path('smoke-output/statement-preview.png').write_bytes(adb('exec-out','screencap','-p'))
assert 'مشاركة الصورة' in dump().decode()
tap('مشاركة الصورة'); time.sleep(6)
state=dump().decode()
if 'مشاركة صفحات الكشف كصور' in state:
    tap('مشاركة الصور', scroll=False); time.sleep(5)
Path('smoke-output/image-share.png').write_bytes(adb('exec-out','screencap','-p'))
share_state = adb('shell','dumpsys','activity','activities').decode(errors='replace')
Path('smoke-output/image-share-state.txt').write_text(share_state)
assert 'ChooserActivity' in share_state or 'ResolverActivity' in share_state, 'Native PNG share sheet did not open'
logs = adb('logcat', '-d').decode(errors='replace')
Path('smoke-output/input-logcat.txt').write_text(logs)
assert not re.search(r'FATAL EXCEPTION|SQLiteException|A RenderFlex overflowed', logs)
PY
