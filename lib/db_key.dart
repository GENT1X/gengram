import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final dbKeys = DbKeys();

class DbKeys {
  final _storage = const FlutterSecureStorage();

  String _name(int accountId) => 'gengram_dbkey_$accountId';

  Future<String> read(int accountId) async {
    try {
      return await _storage.read(key: _name(accountId)) ?? '';
    } catch (_) {
      return '';
    }
  }

  String generate() {
    final rnd = Random.secure();
    return base64Encode(List.generate(32, (_) => rnd.nextInt(256)));
  }

  Future<bool> save(int accountId, String key) async {
    try {
      await _storage.write(key: _name(accountId), value: key);
      return await _storage.read(key: _name(accountId)) == key;
    } catch (_) {
      return false;
    }
  }

  Future<void> forget(int accountId) async {
    try {
      await _storage.delete(key: _name(accountId));
    } catch (_) {}
  }
}
