import 'dart:convert';
import 'package:flutter/material.dart';
import 'form_screen.dart';
import 'social_feed.dart';

class MasterChi extends StatelessWidget {
  final void Function(Map<String, dynamic>) onStart;
  const MasterChi({super.key, required this.onStart});

  Future<void> open(
    BuildContext context, {
    required bool recommendation,
    required String title,
  }) async {
    final brewing = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) =>
            _MasterChiForm(recommendation: recommendation, title: title),
      ),
    );
    if (context.mounted && brewing != null) onStart(brewing);
  }

  Widget action({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      action(
        onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => const FormScreen(
            title: 'Распознать по фото',
            child: Text('Распознавание по фото пока недоступно.'),
          ),
        )),
        icon: Icons.camera_alt_outlined,
        title: 'Распознать по фото',
        subtitle: 'Помощь с чаем и этикеткой',
      ),
      action(
        onTap: () =>
            open(context, recommendation: true, title: 'Подобрать чай'),
        icon: Icons.spa_outlined,
        title: 'Подобрать чай',
        subtitle: 'Чай под ваше настроение',
      ),
      action(
        onTap: () =>
            open(context, recommendation: false, title: 'Задать вопрос'),
        icon: Icons.chat_bubble_outline,
        title: 'Задать вопрос',
        subtitle: 'Поговорить с Мастером Чи',
      ),
    ]);
  }
}

class _MasterChiForm extends StatefulWidget {
  final bool recommendation;
  final String title;

  const _MasterChiForm({required this.recommendation, required this.title});

  @override
  State<_MasterChiForm> createState() => _MasterChiFormState();
}

class _MasterChiFormState extends State<_MasterChiForm> {
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
    final recommendation = widget.recommendation;
    if (text.isEmpty || loading) return;
    FocusScope.of(context).unfocus();
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

  @override
  Widget build(BuildContext context) {
    final tea = result?['tea'];
    return FormScreen(
        title: widget.title,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: question,
            minLines: 2,
            maxLines: 4,
            maxLength: widget.recommendation ? 1000 : 1200,
            decoration: InputDecoration(
                hintText: widget.recommendation
                    ? 'Расскажите о настроении или пожеланиях'
                    : 'Что вы хотите узнать о чае?'),
          ),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: loading ? null : ask,
              child: Text(loading
                  ? 'Мастер Чи думает…'
                  : widget.recommendation
                      ? 'Получить рекомендацию'
                      : 'Отправить вопрос')),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(top: 16), child: Text(error!)),
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
                                onPressed: () => Navigator.pop(context, result),
                                child: const Text('Начать сессию')),
                          ]
                        ]))),
        ]));
  }
}
