import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FeedApi {
  static const baseUrl = String.fromEnvironment('CHA_TARA_API_URL');
  static bool get enabled => baseUrl.isNotEmpty;

  static String randomHex(int size) {
    final random = Random.secure();
    return List.generate(
            size, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object>? data,
  }) async {
    final endpoint = Uri.parse(baseUrl);
    final local = endpoint.scheme == 'http' &&
        ['localhost', '127.0.0.1', '::1'].contains(endpoint.host);
    if (endpoint.host.isEmpty || (endpoint.scheme != 'https' && !local)) {
      throw StateError('Invalid feed API URL');
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'feed-token@${endpoint.origin}';
    var token = prefs.getString(key);
    if (token == null && method != 'GET') {
      token = randomHex(32);
      if (!await prefs.setString(key, token)) {
        throw StateError('Cannot save browser credential');
      }
    }

    final url = endpoint.replace(
      path: '${endpoint.path.replaceFirst(RegExp(r'/+$'), '')}/v1/$path',
      queryParameters: query,
    );
    final request = http.Request(method, url);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (data != null) {
      request.headers['Content-Type'] = 'application/json';
      request.bodyBytes = utf8.encode(jsonEncode(data));
    }
    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Feed API HTTP ${response.statusCode}');
      }
      return response;
    } finally {
      client.close();
    }
  }
}

class SocialFeed extends StatefulWidget {
  const SocialFeed({super.key});

  @override
  State<SocialFeed> createState() => _SocialFeedState();
}

class _SocialFeedState extends State<SocialFeed> {
  final api = FeedApi();
  final posts = <Map<String, dynamic>>[];
  bool following = false;
  bool loading = false;
  bool changing = false;
  bool failed = false;
  int? nextPage;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final response = await api.request('GET', 'feed', query: {
        'following': following.toString(),
        if (append && nextPage != null) 'before': nextPage.toString(),
      });
      final result =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (!append) posts.clear();
        posts.addAll((result['posts'] as List).cast<Map<String, dynamic>>());
        nextPage = result['next_before'] as int?;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> change(String method, String path) async {
    setState(() => changing = true);
    try {
      await api.request(method, path);
      if (mounted) await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Не удалось выполнить действие. Попробуйте ещё раз.')),
        );
      }
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = loading || changing;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('Чайная лента',
                style: Theme.of(context).textTheme.headlineSmall)),
        IconButton(
          tooltip: 'Обновить ленту',
          onPressed: busy ? null : () => load(),
          icon: const Icon(Icons.refresh),
        ),
      ]),
      Wrap(spacing: 8, children: [
        for (final option in [false, true])
          ChoiceChip(
            label: Text(option ? 'Подписки' : 'Все записи'),
            selected: following == option,
            onSelected: busy || following == option
                ? null
                : (_) {
                    setState(() {
                      following = option;
                      posts.clear();
                      nextPage = null;
                    });
                    load();
                  },
          ),
      ]),
      if (loading) const LinearProgressIndicator(),
      if (failed)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Не удалось загрузить ленту. Нажмите «Обновить ленту».'),
        ),
      if (!loading && !failed && posts.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(following
              ? 'Подпишитесь на автора во вкладке «Все записи».'
              : 'Здесь появятся записи, которыми поделились из дневника.'),
        ),
      for (final post in posts)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['name'] as String),
              const SizedBox(height: 4),
              Text(post['tea'] as String,
                  style: Theme.of(context).textTheme.titleLarge),
              if ((post['notes'] as String).isNotEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(post['notes'] as String)),
              if ((post['descriptors'] as List).isNotEmpty)
                Text((post['descriptors'] as List).join(' · ')),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (post['mine'] == true) {
                          final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                    title: const Text('Удалить публикацию?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Отмена')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Удалить')),
                                    ],
                                  ));
                          if (confirmed == true && mounted)
                            await change('DELETE', 'posts/${post['id']}');
                        } else {
                          await change(
                              post['followed'] == true ? 'DELETE' : 'PUT',
                              'follows/${post['author_id']}');
                        }
                      },
                child: Text(post['mine'] == true
                    ? 'Удалить публикацию'
                    : (post['followed'] == true
                        ? 'Отписаться'
                        : 'Подписаться')),
              ),
            ]),
          ),
        ),
      if (nextPage != null && !failed)
        TextButton(
            onPressed: busy ? null : () => load(append: true),
            child: const Text('Ещё записи')),
    ]);
  }
}

class PublishTeaSession extends StatefulWidget {
  final Map<String, dynamic> entry;
  const PublishTeaSession({super.key, required this.entry});

  @override
  State<PublishTeaSession> createState() => _PublishTeaSessionState();
}

class _PublishTeaSessionState extends State<PublishTeaSession> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  final requestId = FeedApi.randomHex(16);
  bool includeNotes = false;
  bool includeDescriptors = false;
  bool sending = false;
  bool failed = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> publish(
      String tea, String notes, List<String> descriptors) async {
    if (!form.currentState!.validate()) return;
    setState(() {
      sending = true;
      failed = false;
    });
    try {
      await FeedApi().request('POST', 'posts', data: {
        'request_id': requestId,
        'name': name.text.trim(),
        'tea': tea,
        if (includeNotes) 'notes': notes,
        if (includeDescriptors) 'descriptors': descriptors,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(() {
          sending = false;
          failed = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tea = widget.entry['tea'] as String;
    final notes = widget.entry['notes'] as String? ?? '';
    final descriptors = (widget.entry['descriptors'] as List? ?? [])
        .whereType<String>()
        .toList();
    return PopScope(
      canPop: !sending,
      child: AlertDialog(
        title: const Text('Поделиться сессией'),
        scrollable: true,
        content: Form(
            key: form,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('В публичной ленте появится «$tea».'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: name,
                    enabled: !sending,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'Имя в ленте'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Введите имя'
                        : null,
                  ),
                  if (notes.trim().isNotEmpty)
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeNotes,
                        onChanged: sending
                            ? null
                            : (v) => setState(() => includeNotes = v ?? false),
                        title: const Text('Включить заметку'),
                        subtitle: Text(notes,
                            maxLines: 3, overflow: TextOverflow.ellipsis)),
                  if (descriptors.isNotEmpty)
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeDescriptors,
                        onChanged: sending
                            ? null
                            : (v) =>
                                setState(() => includeDescriptors = v ?? false),
                        title: const Text('Включить дескрипторы'),
                        subtitle: Text(descriptors.join(' · '),
                            maxLines: 3, overflow: TextOverflow.ellipsis)),
                  if (failed)
                    const Text(
                        'Не удалось опубликовать запись. Проверьте соединение и попробуйте ещё раз.'),
                ])),
        actions: [
          TextButton(
              onPressed: sending ? null : () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: sending ? null : () => publish(tea, notes, descriptors),
            child: Text(sending ? 'Публикуем…' : 'Опубликовать'),
          ),
        ],
      ),
    );
  }
}
