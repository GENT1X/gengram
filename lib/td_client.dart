import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _CreateC = Int32 Function();
typedef _CreateD = int Function();
typedef _SendC = Void Function(Int32, Pointer<Utf8>);
typedef _SendD = void Function(int, Pointer<Utf8>);
typedef _RecvC = Pointer<Utf8> Function(Double);
typedef _RecvD = Pointer<Utf8> Function(double);
typedef _ExecC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _ExecD = Pointer<Utf8> Function(Pointer<Utf8>);

DynamicLibrary _openTdjson() {
  if (Platform.isWindows) return DynamicLibrary.open('tdjson.dll');
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('libtdjson.dylib');
  }
  return DynamicLibrary.open('libtdjson.so');
}

void _receiveLoop(SendPort out) {
  final lib = _openTdjson();
  final receive = lib.lookupFunction<_RecvC, _RecvD>('td_receive');
  while (true) {
    final ptr = receive(1.0);
    if (ptr.address == 0) continue;
    try {
      final json = jsonDecode(ptr.toDartString());
      if (json is Map<String, dynamic>) out.send(json);
    } catch (_) {
    }
  }
}

class _Hub {
  static bool _started = false;
  static late DynamicLibrary _lib;
  static late _SendD send;
  static late _CreateD create;
  static final Map<int, TdClient> clients = {};

  static Future<void> ensure() async {
    if (_started) return;
    _started = true;
    _lib = _openTdjson();
    create = _lib.lookupFunction<_CreateC, _CreateD>('td_create_client_id');
    send = _lib.lookupFunction<_SendC, _SendD>('td_send');

    try {
      final exec = _lib.lookupFunction<_ExecC, _ExecD>('td_execute');
      final query = jsonEncode(
          {'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 1})
          .toNativeUtf8();
      exec(query);
      malloc.free(query);
    } catch (_) {}

    final port = ReceivePort();
    await Isolate.spawn(_receiveLoop, port.sendPort);
    port.listen((message) {
      final json = message as Map<String, dynamic>;
      final id = json['@client_id'];
      if (id is int) clients[id]?._dispatch(json);
    });
  }
}

class TdClient {
  int _clientId = -1;
  bool _closed = false;
  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  int _extra = 0;

  Stream<Map<String, dynamic>> get updates => _updates.stream;

  Future<void> start() async {
    await _Hub.ensure();
    _clientId = _Hub.create();
    _Hub.clients[_clientId] = this;
    _sendRaw({'@type': 'getOption', 'name': 'version'});
  }

  void _dispatch(Map<String, dynamic> json) {
    final extra = json['@extra'];
    if (extra != null && _pending.containsKey(extra)) {
      _pending.remove(extra)!.complete(json);
    } else if (!_updates.isClosed) {
      _updates.add(json);
    }
  }

  void _sendRaw(Map<String, dynamic> request) {
    if (_closed || _clientId < 0) return;
    final ptr = jsonEncode(request).toNativeUtf8();
    _Hub.send(_clientId, ptr);
    malloc.free(ptr);
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> query) {
    if (_closed) {
      return Future.value({'@type': 'error', 'code': 500, 'message': 'closed'});
    }
    final extra = '${_extra++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[extra] = completer;
    _sendRaw({...query, '@extra': extra});
    return completer.future;
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _Hub.clients.remove(_clientId);
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete({'@type': 'error', 'code': 500, 'message': 'closed'});
      }
    }
    _pending.clear();
    _updates.close();
  }
}
