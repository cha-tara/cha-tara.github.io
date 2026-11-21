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
  static const moods = ['Спокойствие', 'Бодрость', 'Уют', 'Сосредоточенность'];
  static const tastes = ['Цветочный', 'Фруктовый', 'Травянистый', 'Древесный'];

  final question = TextEditingController();
  final optionsHeading = GlobalKey();
  String? mood;
  String? taste;
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
    if (loading) return;
    final prompt = recommendation
        ? [
            if (mood != null) 'Настроение: $mood',
            if (taste != null) 'Вкус: $taste',
            if (text.isNotEmpty) 'Пожелания: $text',
          ].join('\n')
        : text;
    if (prompt.isEmpty) {
      setState(() => error = recommendation
          ? 'Выберите настроение, вкус или добавьте пожелание.'
          : 'Введите вопрос о чае.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    try {
      if (!await FeedApi.requireAccount(context) || !mounted) return;
      setState(() {
        error = null;
        result = null;
      });
      final response = await FeedApi().request('POST', 'master', data: {
        'mode': recommendation ? 'recommendation' : 'question',
        'question': prompt,
      });
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => result = decoded);
      if (recommendation) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final heading = optionsHeading.currentContext;
          if (heading != null) {
            Scrollable.ensureVisible(heading,
                duration: const Duration(milliseconds: 250));
          }
        });
      }
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

  Widget preference(String title, List<String> values, String? selected,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(value),
                selected: value == selected,
                onSelected: loading
                    ? null
                    : (active) => setState(() {
                          onChanged(active ? value : null);
                          result = null;
                          error = null;
                        }),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget optionCard(Map<String, dynamic> option) {
    final tea = option['tea'] as String;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tea, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(option['reason'] as String),
            const SizedBox(height: 8),
            Text('${option['grams']} г · ${option['water']} мл · '
                '${option['temperature']} °C · ${option['seconds']} сек'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, option),
              child: const Text('Начать сессию'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = result?['options'] as List<dynamic>?;
    final answer = result?['answer'] as String?;
    return FormScreen(
        title: widget.title,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.recommendation) ...[
            preference('Настроение', moods, mood, (value) => mood = value),
            preference('Вкус', tastes, taste, (value) => taste = value),
          ],
          TextField(
            controller: question,
            enabled: !loading,
            onChanged: (_) {
              if (result != null || error != null) {
                setState(() {
                  result = null;
                  error = null;
                });
              }
            },
            minLines: 2,
            maxLines: 4,
            maxLength: widget.recommendation ? 1000 : 1200,
            decoration: InputDecoration(
                hintText: widget.recommendation
                    ? 'Другие пожелания (по желанию)'
                    : 'Что вы хотите узнать о чае?'),
          ),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: loading ? null : ask,
              child: Text(loading
                  ? 'Мастер Чи думает…'
                  : widget.recommendation
                      ? 'Показать варианты'
                      : 'Отправить вопрос')),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(top: 16), child: Text(error!)),
          if (options != null) ...[
            const SizedBox(height: 16),
            Text('Выберите чай',
                key: optionsHeading,
                style: Theme.of(context).textTheme.titleLarge),
            for (final option in options)
              optionCard(option as Map<String, dynamic>),
          ],
          if (answer != null)
            Card(
                child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(answer),
            )),
        ]));
  }
}
