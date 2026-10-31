import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tg_style.dart';

final messageFilters = MessageFilters();

class FilterRule {
  const FilterRule(this.pattern, {this.regex = false, this.chatId = 0});

  final String pattern;
  final bool regex;
  final int chatId;

  Map<String, dynamic> toJson() =>
      {'p': pattern, 'r': regex, 'c': chatId};

  factory FilterRule.fromJson(Map j) => FilterRule('${j['p']}',
      regex: j['r'] == true, chatId: (j['c'] as int?) ?? 0);

  bool matches(String text) {
    if (pattern.isEmpty) return false;
    if (!regex) return text.toLowerCase().contains(pattern.toLowerCase());
    try {
      return RegExp(pattern, caseSensitive: false).hasMatch(text);
    } catch (_) {
      return false;
    }
  }
}

class MessageFilters extends ChangeNotifier {
  static const _key = 'message_filters';

  final List<FilterRule> rules = [];
  SharedPreferences? _p;

  Future<void> load() async {
    try {
      final p = _p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        rules.addAll([
          for (final e in (jsonDecode(raw) as List)) FilterRule.fromJson(e as Map)
        ]);
      }
    } catch (_) {}
  }

  bool hides(int chatId, String text) {
    if (rules.isEmpty || text.isEmpty) return false;
    for (final r in rules) {
      if ((r.chatId == 0 || r.chatId == chatId) && r.matches(text)) return true;
    }
    return false;
  }

  Future<void> add(FilterRule rule) async {
    rules.add(rule);
    await _save();
  }

  Future<void> removeAt(int i) async {
    rules.removeAt(i);
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      await _p?.setString(_key, jsonEncode([for (final r in rules) r.toJson()]));
    } catch (_) {}
  }
}

class FiltersPage extends StatefulWidget {
  const FiltersPage({super.key});

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  @override
  void initState() {
    super.initState();
    messageFilters.addListener(_changed);
  }

  @override
  void dispose() {
    messageFilters.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final text = TextEditingController();
    var regex = false;
    final rule = await showDialog<FilterRule>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Новый фильтр'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Слово или выражение'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Регулярное выражение'),
                value: regex,
                onChanged: (v) => setLocal(() => regex = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            TextButton(
              onPressed: () {
                final p = text.text.trim();
                if (p.isEmpty) return;
                Navigator.pop(ctx, FilterRule(p, regex: regex));
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
    if (rule != null) await messageFilters.add(rule);
  }

  @override
  Widget build(BuildContext context) {
    final rules = messageFilters.rules;
    return Theme(
      data: Tg.theme,
      child: Scaffold(
        backgroundColor: Tg.bg,
        appBar: AppBar(backgroundColor: Tg.panel, title: const Text('Фильтры сообщений')),
        floatingActionButton:
            FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
        body: rules.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                      'Входящие сообщения, в которых встречается слово или подходит выражение, скрываются из чатов. Нажмите «+», чтобы добавить.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Tg.textSecondary)),
                ),
              )
            : ListView.builder(
                itemCount: rules.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(rules[i].pattern, style: TextStyle(color: Tg.text)),
                  subtitle: Text(rules[i].regex ? 'Регулярное выражение' : 'Слово',
                      style: TextStyle(color: Tg.textSecondary)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => messageFilters.removeAt(i),
                  ),
                ),
              ),
      ),
    );
  }
}
