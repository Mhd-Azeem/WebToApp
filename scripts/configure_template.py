import argparse
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--url', required=True)
p.add_argument('--name', required=True)
p.add_argument('--package', required=True)
p.add_argument('--orientation', choices=['auto','portrait','landscape'], default='auto')
a = p.parse_args()
root = Path(__file__).resolve().parents[1] / 'android-template'
main = root / 'app/src/main/java/com/webtoapp/template/MainActivity.kt'
manifest = root / 'app/src/main/AndroidManifest.xml'
gradle = root / 'app/build.gradle.kts'

s = main.read_text()
s = s.replace('private const val HOME_URL = "https://example.com"', f'private const val HOME_URL = "{a.url.replace(chr(34), "")}"')
main.write_text(s)

s = manifest.read_text().replace('android:label="WebToApp"', f'android:label="{a.name.replace(chr(34), "")}"')
orient = {'auto':'unspecified','portrait':'portrait','landscape':'landscape'}[a.orientation]
s = s.replace('android:screenOrientation="unspecified"', f'android:screenOrientation="{orient}"')
manifest.write_text(s)

s = gradle.read_text().replace('applicationId = "com.webtoapp.template"', f'applicationId = "{a.package}"')
gradle.write_text(s)
