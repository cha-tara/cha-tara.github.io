import 'dart:convert';
import 'package:flutter/material.dart';
import 'social_feed.dart';

class MasterChi extends StatefulWidget {
  final VoidCallback onScan;
  final void Function(Map<String, dynamic>) onStart;
  const MasterChi({super.key, required this.onScan, required this.onStart});

  @override
  State<MasterChi> createState() => _MasterChiState();
}

class _MasterChiState extends State<MasterChi> {
  final question = TextEditingController();
  bool? recommendTea;
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
    final recommendation = recommendTea;
    if (text.isEmpty || loading || recommendation == null) return;
    setState(() => loading = true);
    try {
      if (!await FeedApi.requireAccount(context) || !mounted) return;
      setState(() {
        error = null;
        result = null;
      });
      final response = await FeedApi().request('POST', 'master', data: {
        'question': recommendation
            ? 'Подбери чай и способ заваривания под это настроение или пожелание: $text'
            : text,
      });
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (mounted) setState(() => result = decoded);
    } on FeedError catch (e) {
      if (mounted)
        setState(() => error = e.status == 429
            ? 'Лимит запросов исчерпан. Попробуйте позже.'
            : 'Не удалось получить ответ. Попробуйте ещё раз.');
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'Не удалось получить ответ. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget action({
    bool? recommendation,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final active = recommendTea == recommendation && recommendation != null;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: const Color(0xffe2dfcd),
          child: Icon(icon, color: const Color(0xff657052), size: 24),
        ),
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Georgia', fontSize: 21, height: 1.08)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 6), child: Text(subtitle)),
        selected: active,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: recommendation == null
            ? widget.onScan
            : loading
                ? null
                : () {
                    if (recommendTea == recommendation) return;
                    setState(() {
                      recommendTea = recommendation;
                      question.clear();
                      result = null;
                      error = null;
                    });
                  },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tea = result?['tea'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      action(
        icon: Icons.camera_alt_outlined,
        title: 'Распознать по фото',
        subtitle: 'Помощь с чаем и этикеткой',
      ),
      action(
        recommendation: true,
        icon: Icons.spa_outlined,
        title: 'Подобрать чай',
        subtitle: 'Чай под ваше настроение',
      ),
      action(
        recommendation: false,
        icon: Icons.chat_bubble_outline,
        title: 'Задать вопрос',
        subtitle: 'Поговорить с Мастером Чи',
      ),
      if (recommendTea != null) ...[
        const SizedBox(height: 12),
        TextField(
          controller: question,
          minLines: 2,
          maxLines: 4,
          maxLength: recommendTea == true ? 1000 : 1200,
          decoration: InputDecoration(
              hintText: recommendTea == true
                  ? 'Расскажите о настроении или пожеланиях'
                  : 'Что вы хотите узнать о чае?'),
        ),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: loading ? null : ask,
            child: Text(loading
                ? 'Мастер Чи думает…'
                : recommendTea == true
                    ? 'Получить рекомендацию'
                    : 'Отправить вопрос')),
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: Text(error!)),
        if (result != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result!['answer'] as String),
                        if (tea is String && tea.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                              onPressed: () => widget.onStart(result!),
                              child: const Text('Начать сессию')),
                        ]
                      ]))),
      ],
    ]);
  }
}
