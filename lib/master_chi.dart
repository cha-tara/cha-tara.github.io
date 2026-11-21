import 'dart:convert';
import 'package:flutter/material.dart';
import 'social_feed.dart';

class MasterChi extends StatefulWidget {
  final void Function(Map<String, dynamic>) onStart;
  const MasterChi({super.key, required this.onStart});

  @override
  State<MasterChi> createState() => _MasterChiState();
}

class _MasterChiState extends State<MasterChi> {
  final question = TextEditingController();
  Map<String, dynamic>? result;
  String? error;
  bool loading = false;

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> ask() async {
    final text = question.text.trim();
    if (text.isEmpty || loading) return;
    if (!await FeedApi.requireAccount(context) || !mounted) return;
    setState(() { loading = true; error = null; result = null; });
    try {
      final response = await FeedApi().request('POST', 'master', data: {'question': text});
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (mounted) setState(() => result = decoded);
    } on FeedError catch (e) {
      if (mounted) setState(() => error = e.status == 429 ? 'Лимит запросов исчерпан. Попробуйте позже.' : 'Не удалось получить ответ. Попробуйте ещё раз.');
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось получить ответ. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tea = result?['tea'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: question, minLines: 2, maxLines: 4, maxLength: 1200,
        decoration: const InputDecoration(hintText: 'Расскажите о настроении или задайте вопрос о чае')),
      const SizedBox(height: 8),
      FilledButton(onPressed: loading ? null : ask, child: Text(loading ? 'Мастер Чи думает…' : 'Спросить Мастера Чи')),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(error!)),
      if (result != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(result!['answer'] as String),
        if (tea is String && tea.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: () => widget.onStart(result!), child: const Text('Начать сессию')),
        ]
      ]))),
    ]);
  }
}
