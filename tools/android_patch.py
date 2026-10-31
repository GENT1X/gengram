import os, re, sys

app = 'android/app'
manifest = f'{app}/src/main/AndroidManifest.xml'
s = open(manifest, encoding='utf-8').read()
perms = [
    'INTERNET', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_REMOTE_MESSAGING',
    'POST_NOTIFICATIONS', 'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
    'RECORD_AUDIO', 'WAKE_LOCK', 'RECEIVE_BOOT_COMPLETED',
]
add = ''.join(
    f'    <uses-permission android:name="android.permission.{p}"/>\n'
    for p in perms if f'android.permission.{p}"' not in s)
s = s.replace('<application', add + '    <application', 1)
extra = '''        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="remoteMessaging"
            android:exported="false" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
'''
if 'ForegroundService' not in s:
    s = s.replace('</application>', extra + '    </application>', 1)
s = s.replace('android:label="gengram"', 'android:label="GenGram"')
open(manifest, 'w', encoding='utf-8').write(s)

gradle = None
for name in ('build.gradle.kts', 'build.gradle'):
    if os.path.exists(f'{app}/{name}'):
        gradle = f'{app}/{name}'
        break
g = open(gradle, encoding='utf-8').read()
kts = gradle.endswith('.kts')
g = re.sub(r'minSdk(Version)?\s*=?\s*(flutter\.minSdkVersion|\d+)',
           'minSdk = 24' if kts else 'minSdkVersion 24', g)
if 'coreLibraryDesugaring' not in g:
    if kts:
        g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', g, 1)
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    else:
        g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', g, 1)
        g += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'
open(gradle, 'w', encoding='utf-8').write(g)

kt_dir = None
for root, _, files in os.walk(f'{app}/src/main'):
    if 'MainActivity.kt' in files:
        kt_dir = root
        break
pkg = re.search(r'package\s+([\w.]+)', open(f'{kt_dir}/MainActivity.kt', encoding='utf-8').read()).group(1)
open(f'{kt_dir}/MainActivity.kt', 'w', encoding='utf-8').write(f'''package {pkg}

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    private var keys: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        keys = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gengram/keys")
    }}

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {{
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {{
            keys?.invokeMethod("volumeUp", null)
        }}
        return super.onKeyDown(keyCode, event)
    }}
}}
''')
print('patched', gradle, pkg)
