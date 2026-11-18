import 'dart:math' as math;
import 'package:flutter/material.dart';

// Adapted from «Круг основных дескрипторов чая», draft 2.0, Елена Иванова.
class DescriptorGroup {
  final String name;
  final Color color;
  final List<String> notes;
  const DescriptorGroup(this.name, this.color, this.notes);
}

const groups = [
  DescriptorGroup('Основной вкус', Color(0xffa9a778),
      ['Сладкий', 'Кислый', 'Солёный', 'Горький', 'Умами']),
  DescriptorGroup('Тело', Color(0xff849584), [
    'Сочный',
    'Терпкий',
    'Вязкий',
    'Шершавый',
    'Маслянистый',
    'Гладкий',
    'Подвижный',
    'Лёгкий',
    'Плотный'
  ]),
  DescriptorGroup('Баланс', Color(0xffa5a482),
      ['Сбалансированный', 'Гармоничный', 'Резкий', 'Грубый']),
  DescriptorGroup('Букет', Color(0xffb29878), [
    'Сложный',
    'Богатый',
    'Простой',
    'Однообразный',
    'Характерный',
    'Нетипичный',
  ]),
  DescriptorGroup('Экстрактивность', Color(0xff8c956d), [
    'Полный (крепкий)',
    'Пустой (слабый, водянистый)',
  ]),
  DescriptorGroup('Послевкусие', Color(0xffb2a184),
      ['Интенсивное', 'Слабое', 'Длительное', 'Быстро уходящее']),
  DescriptorGroup('Тип послевкусия', Color(0xffb2a184),
      ['Вкус', 'Аромат', 'Ощущение', 'Температура']),
  DescriptorGroup('Цветочный', Color(0xffbd827c),
      ['Жасмин', 'Сирень', 'Роза', 'Липа, нарцисс', 'Пион, клевер']),
  DescriptorGroup('Сладкий', Color(0xffc79563), [
    'Молоко, сливки',
    'Мёд',
    'Сахар, карамель',
    'Злаки, солод',
    'Шоколад, какао'
  ]),
  DescriptorGroup('Фруктовый', Color(0xffd6a65f), [
    'Цитрусы',
    'Яблоко, слива',
    'Вишня, черешня',
    'Персик, абрикос',
    'Груша, айва',
    'Виноград',
    'Финик, банан',
    'Дыня, арбуз',
    'Манго, личи',
    'Косточка'
  ]),
  DescriptorGroup('Ягодный', Color(0xffad7172),
      ['Варенье', 'Смородина', 'Малина', 'Земляника', 'Черника', 'Шиповник']),
  DescriptorGroup('Древесный', Color(0xff957862), [
    'Лист',
    'Кора, шишка',
    'Хвоя',
    'Смола',
    'Дёготь',
    'Опилки, бумага',
    'Дым, копоть',
    'Уголь',
    'Бочка',
    'Ароматная древесина'
  ]),
  DescriptorGroup('Пряный', Color(0xffae8061), [
    'Корица',
    'Гвоздика',
    'Анис',
    'Ваниль',
    'Перец',
    'Мята',
    'Базилик',
    'Камфора',
    'Кориандр',
    'Корни (хрен, сельдерей)'
  ]),
  DescriptorGroup('Кофейный', Color(0xff806c60), ['Кофе']),
  DescriptorGroup('Ореховый', Color(0xffb59b6a), [
    'Фундук',
    'Кешью',
    'Миндаль',
    'Грецкий орех',
    'Кедровый орех',
    'Семена',
    'Масло'
  ]),
  DescriptorGroup('Травянистый', Color(0xff859774),
      ['Лекарственные травы', 'Хмель', 'Сено, солома', 'Трава']),
  DescriptorGroup('Овощной', Color(0xffa5a779),
      ['Тыква, морковь', 'Томат', 'Горошек', 'Цукини']),
  DescriptorGroup('Минеральный', Color(0xff899a96), [
    'Соль',
    'Пепел',
    'Камни, песок',
    'Рыба',
    'Водоросли',
    'Море',
    'Известь',
    'Лёд'
  ]),
  DescriptorGroup('Почвенный', Color(0xff8d806e),
      ['Мох', 'Палая листва', 'Глина', 'Торф', 'Земля']),
  DescriptorGroup('Грибной', Color(0xffa1937c), ['Грибы']),
  DescriptorGroup('Животный', Color(0xffaa8d80), ['Кожа', 'Мускус', 'Амбра']),
  DescriptorGroup('Металлический', Color(0xff969b99), ['Металл']),
  DescriptorGroup(
      'Бальзамический', Color(0xff998777), ['Уксус', 'Квас, пиво', 'Вино']),
  DescriptorGroup('Алкогольный', Color(0xff987f86), ['Спирт']),
  DescriptorGroup('Химический', Color(0xff8f9190),
      ['Резина', 'Креозот', 'Бензин', 'Лекарства, бинты', 'Лак', 'Духи, мыло']),
];

class DescriptorWheel extends StatefulWidget {
  final String type;
  final int infusion;
  final Set<String> selected;
  final void Function(String, bool) onChanged;
  const DescriptorWheel(
      {super.key,
      required this.type,
      required this.infusion,
      required this.selected,
      required this.onChanged});
  @override
  State<DescriptorWheel> createState() => _DescriptorWheelState();
}

class _DescriptorWheelState extends State<DescriptorWheel> {
  int active = 0;
  String keyFor(String note) =>
      'Пролив ${widget.infusion} · ${widget.type}: $note';

  Widget noteOptions(DescriptorGroup group) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final note in group.notes)
          FilterChip(
            label: Text(note),
            selected: widget.selected.contains(keyFor(note)),
            selectedColor: group.color.withValues(alpha: .35),
            onSelected: (selected) => widget.onChanged(keyFor(note), selected),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = groups[active];
    final showBasicTastes = widget.type == 'Вкус';
    final selectedForCurrent = widget.selected
        .where(
            (s) => s.startsWith('Пролив ${widget.infusion} · ${widget.type}: '))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Колесо вкусов и ароматов',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(
          'Пролив ${widget.infusion} · ${widget.type}. Выберите сектор, затем отметьте знакомые оттенки.',
          style: const TextStyle(color: Color(0xff77786b), height: 1.35)),
      const SizedBox(height: 16),
      if (showBasicTastes) ...[
        const Text('Основные вкусы',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        noteOptions(groups.first),
        const SizedBox(height: 16),
      ],
      Center(child: LayoutBuilder(builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 310.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (event) {
            final p = event.localPosition - Offset(size / 2, size / 2);
            final distance = p.distance;
            if (distance < size * .20 || distance > size * .5) return;
            final angle = (math.atan2(p.dy, p.dx) + math.pi / 2 + 2 * math.pi) %
                (2 * math.pi);
            setState(
                () => active = (angle / (2 * math.pi) * groups.length).floor());
          },
          child: CustomPaint(
            size: Size.square(size),
            painter: _WheelPainter(active),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                  child: Container(
                width: size * .38,
                height: size * .38,
                decoration: const BoxDecoration(
                    color: Color(0xfffaf7ed), shape: BoxShape.circle),
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(group.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff292b22))),
                )),
              )),
            ),
          ),
        );
      })),
      const SizedBox(height: 16),
      const Text('Выберите группу',
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      DropdownButtonFormField<int>(
        key: ValueKey(active),
        initialValue: active,
        isExpanded: true,
        decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        items: List.generate(groups.length,
            (i) => DropdownMenuItem(value: i, child: Text(groups[i].name))),
        onChanged: (i) {
          if (i != null) setState(() => active = i);
        },
      ),
      const SizedBox(height: 18),
      if (!showBasicTastes || active != 0) ...[
        Text(group.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        noteOptions(group),
      ],
      if (selectedForCurrent.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('Отмечено', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
            spacing: 6,
            children: selectedForCurrent
                .map((s) => InputChip(
                    label: Text(s.split(': ').last),
                    onDeleted: () => widget.onChanged(s, false)))
                .toList())
      ],
      const SizedBox(height: 8),
      const Text(
          'По мотивам «Круга основных дескрипторов чая», Елена Иванова, draft 2.0.',
          style: TextStyle(fontSize: 11, color: Color(0xff77786b))),
    ]);
  }
}

class _WheelPainter extends CustomPainter {
  final int active;
  _WheelPainter(this.active);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi / groups.length;
    for (var i = 0; i < groups.length; i++) {
      final paint = Paint()
        ..color = groups[i].color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
          rect, -math.pi / 2 + i * sweep + .012, sweep - .024, true, paint);
      if (i == active) {
        final outline = Paint()
          ..color = const Color(0xff343c2c)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 2),
            -math.pi / 2 + i * sweep + .012, sweep - .024, false, outline);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.active != active;
}
