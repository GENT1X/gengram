import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'app_state.dart';

typedef _FindC = IntPtr Function(IntPtr, IntPtr, Pointer<Utf16>, Pointer<Utf16>);
typedef _FindD = int Function(int, int, Pointer<Utf16>, Pointer<Utf16>);
typedef _OwnerC = Uint32 Function(IntPtr, Pointer<Uint32>);
typedef _OwnerD = int Function(int, Pointer<Uint32>);
typedef _AffinityC = Int32 Function(IntPtr, Uint32);
typedef _AffinityD = int Function(int, int);

const _excludeFromCapture = 0x11;

bool setCaptureProtection(bool on) {
  if (!Platform.isWindows) return false;
  Pointer<Utf16>? name;
  Pointer<Uint32>? owner;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final find = user32.lookupFunction<_FindC, _FindD>('FindWindowExW');
    final ownerOf = user32.lookupFunction<_OwnerC, _OwnerD>('GetWindowThreadProcessId');
    final affinity =
        user32.lookupFunction<_AffinityC, _AffinityD>('SetWindowDisplayAffinity');
    name = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    owner = calloc<Uint32>();
    var hwnd = 0;
    while (true) {
      hwnd = find(0, hwnd, name, nullptr);
      if (hwnd == 0) return false;
      ownerOf(hwnd, owner);
      if (owner.value == pid) break;
    }
    return affinity(hwnd, on ? _excludeFromCapture : 0) != 0;
  } catch (_) {
    return false;
  } finally {
    if (name != null) calloc.free(name);
    if (owner != null) calloc.free(owner);
  }
}

String hideInStream(String value) => settings.streamer && value.isNotEmpty
    ? '•' * (value.length > 12 ? 12 : value.length)
    : value;
