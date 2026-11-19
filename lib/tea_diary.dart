import 'package:flutter/material.dart';

class TeaDiary extends StatelessWidget {
  const TeaDiary({
    super.key,
    required this.entries,
    required this.onStart,
    required this.onDelete,
    this.onShare,
  });

  final List<Map<String, dynamic>> entries;
  final VoidCallback onStart;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>>? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'Чайный дневник',
          style:
              theme.textTheme.headlineMedium?.copyWith(fontFamily: 'Georgia'),
        ),
        const SizedBox(height: 6),
        Text(
          'Ваши чайные сессии и впечатления',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        if (entries.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Icon(Icons.menu_book_outlined,
                    size: 38, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Пока нет записей', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('Заварите чай и сохраните параметры и впечатления.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton(
                    onPressed: onStart, child: const Text('Начать сессию')),
              ]),
            ),
          ),
        for (final entry in entries)
          Padding(
            key: ObjectKey(entry),
            padding: const EdgeInsets.only(bottom: 14),
            child: _SessionCard(
              entry: entry,
              onDelete: () => onDelete(entry),
              onShare: onShare == null ? null : () => onShare!(entry),
            ),
          ),
      ],
    );
  }
}

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.entry,
    required this.onDelete,
    required this.onShare,
  });

  final Map<String, dynamic> entry;
  final VoidCallback onDelete;
  final VoidCallback? onShare;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  static final _descriptorPattern = RegExp(r'^Пролив (\d+) · ([^:]+): (.+)$');
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final palette = theme.colorScheme;
    final date = DateTime.tryParse(entry['date']?.toString() ?? '')?.toLocal();
    final tea = entry['tea']?.toString().trim() ?? '';
    final infusion = int.tryParse(entry['infusion']?.toString() ?? '');
    final notes = entry['notes']?.toString().trim() ?? '';
    final descriptors = entry['descriptors'];
    final tags = descriptors is List
        ? descriptors
            .whereType<String>()
            .where((tag) => tag.trim().isNotEmpty)
            .toList()
        : <String>[];
    final visibleTags = expanded ? tags : tags.take(4);
    final groups = <String, List<String>>{};
    for (final tag in visibleTags) {
      final match = _descriptorPattern.firstMatch(tag);
      final label =
          match == null ? 'Дескрипторы' : 'Пролив ${match[1]} · ${match[2]}';
      groups.putIfAbsent(label, () => []).add(match?[3] ?? tag);
    }

    final parameters = [
      (Icons.spa_outlined, 'Чай', 'grams', 'г'),
      (Icons.water_drop_outlined, 'Вода', 'water', 'мл'),
      (Icons.thermostat_outlined, 'Температура', 'temp', '°C'),
      (Icons.timer_outlined, 'Время', 'seconds', 'сек'),
    ];
    final available = parameters
        .where((item) => (entry[item.$3]?.toString().trim() ?? '').isNotEmpty)
        .toList();
    final canExpand = tags.length > 4 || notes.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: palette.outlineVariant.withValues(alpha: .5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.emoji_food_beverage_outlined,
                  size: 19, color: palette.primary),
              if (date != null)
                Text(
                    "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}",
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: palette.onSurfaceVariant)),
              if (infusion != null)
                Text('Пролив $infusion',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: palette.primary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tea.isEmpty ? 'Чайная сессия' : tea,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontFamily: 'Georgia', fontSize: 24),
          ),
          if (available.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) {
              const gap = 8.0;
              final textSize = MediaQuery.textScalerOf(context).scale(14);
              final columns = constraints.maxWidth >= 532 && textSize <= 17
                  ? 4
                  : constraints.maxWidth >= 264 && textSize <= 17
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in available)
                    SizedBox(
                      width: width,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          child: Row(
                            children: [
                              Icon(item.$1, size: 16, color: palette.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.$2,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                                color:
                                                    palette.onSurfaceVariant)),
                                    Text(
                                        '${entry[item.$3].toString().trim()} ${item.$4}',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ],
          if (notes.isNotEmpty || tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Впечатления', style: theme.textTheme.titleSmall),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(notes,
                  maxLines: expanded ? null : 2,
                  overflow:
                      expanded ? TextOverflow.visible : TextOverflow.ellipsis),
            ],
            for (final group in groups.entries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.key,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: palette.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 5, children: [
                      for (final tag in group.value)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.tertiaryContainer
                                .withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            child:
                                Text(tag, style: theme.textTheme.labelMedium),
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
            if (canExpand)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => expanded = !expanded),
                  child: Text(expanded ? 'Свернуть' : 'Все впечатления'),
                ),
              ),
          ],
          const SizedBox(height: 6),
          Divider(height: 12, color: palette.outlineVariant),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (widget.onShare != null)
              Flexible(
                child: TextButton.icon(
                  onPressed: widget.onShare,
                  icon: const Icon(Icons.ios_share_outlined, size: 18),
                  label: const Text('Поделиться'),
                ),
              )
            else
              const Spacer(),
            IconButton(
              onPressed: widget.onDelete,
              tooltip: 'Удалить запись',
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
          ]),
        ]),
      ),
    );
  }
}
