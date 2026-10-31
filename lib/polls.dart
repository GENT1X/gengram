import 'package:flutter/material.dart';

import 'accounts.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

String _t(dynamic v) => v is Map ? '${v['text'] ?? ''}' : '${v ?? ''}';

Map<String, dynamic> _formatted(String text) =>
    {'@type': 'formattedText', 'text': text, 'entities': <dynamic>[]};

class PollView extends StatefulWidget {
  const PollView({super.key, required this.msg, required this.mine});

  final Map<String, dynamic> msg;
  final bool mine;

  @override
  State<PollView> createState() => _PollViewState();
}

class _PollViewState extends State<PollView> {
  final Set<int> _picked = {};
  bool _busy = false;

  Map get _poll => (widget.msg['content'] as Map)['poll'] as Map;

  Future<void> _vote(List<int> ids) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await accounts.active.td.request({
      '@type': 'setPollAnswer',
      'chat_id': widget.msg['chat_id'],
      'message_id': widget.msg['id'],
      'option_ids': ids,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _picked.clear();
    });
    if (r['@type'] == 'error') tgToast('Не проголосовалось: ${r['message']}');
  }

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    final closed = poll['is_closed'] == true;
    final options = ((poll['options'] as List?) ?? const []).cast<Map>();
    final voted = options.any((o) => o['is_chosen'] == true);
    final type = poll['type'] as Map?;
    final quiz = type?['@type'] == 'pollTypeQuiz';
    final multi = type?['allow_multiple_answers'] == true;
    final results = closed || voted;
    final int? correct = quiz ? (type?['correct_option_id'] as int?) : null;
    final total = (poll['total_voter_count'] as int?) ?? 0;
    final kind = quiz
        ? 'Викторина'
        : (poll['is_anonymous'] == true ? 'Анонимный опрос' : 'Публичный опрос');

    return SizedBox(
      width: 290,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_t(poll['question']),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(closed ? '$kind · завершён' : (multi ? '$kind · несколько ответов' : kind),
              style: const TextStyle(fontSize: 12.5, color: Color(0xAAFFFFFF))),
          const SizedBox(height: 8),
          for (var i = 0; i < options.length; i++)
            _option(i, options[i], results, multi, correct),
          if (multi && !results && !closed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _picked.isEmpty || _busy
                      ? null
                      : () => _vote(_picked.toList()..sort()),
                  child: const Text('Проголосовать'),
                ),
              ),
            ),
          if (voted && !closed && !quiz)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : () => _vote(const []),
                child: const Text('Отменить голос'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                total == 0
                    ? 'Пока нет голосов'
                    : '$total ${tgPlural(total, 'голос', 'голоса', 'голосов')}',
                style: const TextStyle(fontSize: 12.5, color: Color(0xAAFFFFFF))),
          ),
        ],
      ),
    );
  }

  Widget _option(int i, Map o, bool results, bool multi, int? correct) {
    final chosen = o['is_chosen'] == true;
    final pct = ((o['vote_percentage'] as int?) ?? 0).clamp(0, 100);
    final text = _t(o['text']);
    final isCorrect = correct != null && correct == i;
    final wrong = correct != null && chosen && !isCorrect;
    Widget lead;
    if (results) {
      lead = SizedBox(
        width: 22,
        child: chosen || isCorrect
            ? Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                size: 18, color: wrong ? Tg.danger : const Color(0xFF63D27A))
            : Text('$pct%', style: const TextStyle(fontSize: 11)),
      );
    } else {
      final on = _picked.contains(i);
      lead = Icon(
          multi
              ? (on ? Icons.check_box : Icons.check_box_outline_blank)
              : Icons.radio_button_unchecked,
          size: 20);
    }
    return InkWell(
      onTap: results || _busy
          ? null
          : () {
              if (multi) {
                setState(() => _picked.contains(i) ? _picked.remove(i) : _picked.add(i));
              } else {
                _vote([i]);
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                lead,
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
                if (results && (chosen || isCorrect))
                  Text('$pct%',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            if (results)
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: pct / 100,
                    backgroundColor: const Color(0x33FFFFFF),
                    color: wrong ? Tg.danger : (isCorrect ? const Color(0xFF63D27A) : Tg.link),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>?> showCreatePoll(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _CreatePoll(),
  );
}

class _CreatePoll extends StatefulWidget {
  const _CreatePoll();

  @override
  State<_CreatePoll> createState() => _CreatePollState();
}

class _CreatePollState extends State<_CreatePoll> {
  final _question = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _anonymous = true;
  bool _multi = false;
  bool _quiz = false;
  int _correct = -1;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final q = _question.text.trim();
    final texts = <String>[];
    var correct = -1;
    for (var i = 0; i < _options.length; i++) {
      final t = _options[i].text.trim();
      if (t.isEmpty) continue;
      if (i == _correct) correct = texts.length;
      texts.add(t);
    }
    if (q.isEmpty) {
      tgToast('Введите вопрос');
      return;
    }
    if (texts.length < 2) {
      tgToast('Нужно минимум два варианта');
      return;
    }
    if (_quiz && correct < 0) {
      tgToast('Отметьте правильный ответ');
      return;
    }
    Navigator.pop(context, {
      '@type': 'inputMessagePoll',
      'question': _formatted(q),
      'options': [for (final t in texts) _formatted(t)],
      'is_anonymous': _anonymous,
      'type': _quiz
          ? {
              '@type': 'pollTypeQuiz',
              'correct_option_id': correct,
              'explanation': _formatted(''),
            }
          : {'@type': 'pollTypeRegular', 'allow_multiple_answers': _multi},
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Tg.theme,
      child: AlertDialog(
        backgroundColor: Tg.panelOver,
        title: const Text('Новый опрос'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _question,
                  maxLength: 255,
                  decoration: const InputDecoration(hintText: 'Вопрос'),
                ),
                for (var i = 0; i < _options.length; i++)
                  Row(
                    children: [
                      if (_quiz)
                        IconButton(
                          icon: Icon(
                              _correct == i
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _correct == i ? const Color(0xFF63D27A) : null),
                          onPressed: () => setState(() => _correct = i),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _options[i],
                          maxLength: 100,
                          decoration: InputDecoration(
                              hintText: 'Вариант ${i + 1}', counterText: ''),
                        ),
                      ),
                      if (_options.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _options.removeAt(i).dispose();
                            if (_correct == i) _correct = -1;
                            if (_correct > i) _correct--;
                          }),
                        ),
                    ],
                  ),
                if (_options.length < 10)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _options.add(TextEditingController())),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить вариант'),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Анонимное голосование'),
                  value: _anonymous,
                  onChanged: (v) => setState(() => _anonymous = v),
                ),
                if (!_quiz)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Несколько ответов'),
                    value: _multi,
                    onChanged: (v) => setState(() => _multi = v),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Режим викторины'),
                  value: _quiz,
                  onChanged: (v) => setState(() {
                    _quiz = v;
                    if (v) _multi = false;
                  }),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(onPressed: _submit, child: const Text('Создать')),
        ],
      ),
    );
  }
}
