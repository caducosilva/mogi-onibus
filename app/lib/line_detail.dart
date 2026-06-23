import 'package:flutter/material.dart';

import 'models.dart';

const _dayOrder = ['util', 'sabado', 'domingo'];
const _dayLabels = {
  'util': 'Dia Útil',
  'sabado': 'Sábado',
  'domingo': 'Dom./Feriado',
};

class LineDetailPage extends StatefulWidget {
  final BusLine line;
  const LineDetailPage({super.key, required this.line});

  @override
  State<LineDetailPage> createState() => _LineDetailPageState();
}

class _LineDetailPageState extends State<LineDetailPage> {
  late final List<String> _days;

  @override
  void initState() {
    super.initState();
    _days =
        _dayOrder.where((d) => widget.line.horarios.containsKey(d)).toList();
  }

  String _todayKey() {
    final wd = DateTime.now().weekday; // 1=Seg ... 7=Dom
    if (wd == 7) return 'domingo';
    if (wd == 6) return 'sabado';
    return 'util';
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    final initial = _days.indexOf(_todayKey());
    return DefaultTabController(
      length: _days.length,
      initialIndex: initial >= 0 ? initial : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.nome.isNotEmpty ? l.nome : 'Linha ${l.linha}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Linha ${l.linha}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70)),
            ],
          ),
          bottom: TabBar(
            isScrollable: false,
            tabs: [for (final d in _days) Tab(text: _dayLabels[d] ?? d)],
          ),
        ),
        body: Column(
          children: [
            _InfoHeader(line: l),
            Expanded(
              child: TabBarView(
                children: [
                  for (final d in _days)
                    _DaySchedule(line: l, day: d, isToday: d == _todayKey()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoHeader extends StatelessWidget {
  final BusLine line;
  const _InfoHeader({required this.line});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: cs.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line.pontoA.isNotEmpty || line.pontoB.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(line.pontoA,
                      style: t.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.swap_horiz, size: 18, color: cs.primary),
                ),
                Expanded(
                  child: Text(line.pontoB,
                      textAlign: TextAlign.end,
                      style: t.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          if (line.empresa.isNotEmpty || line.obs.isNotEmpty)
            const SizedBox(height: 6),
          if (line.empresa.isNotEmpty)
            Text(line.empresa,
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          if (line.obs.isNotEmpty)
            Text(line.obs,
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DaySchedule extends StatelessWidget {
  final BusLine line;
  final String day;
  final bool isToday;
  const _DaySchedule(
      {required this.line, required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final dirs = line.horarios[day] ?? {};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _DirectionBlock(
          icon: Icons.arrow_forward,
          title: 'Ida',
          subtitle: line.pontoA.isNotEmpty ? line.pontoA : 'Ponto A',
          times: dirs['ida'] ?? const [],
          highlightNext: isToday,
        ),
        const SizedBox(height: 24),
        _DirectionBlock(
          icon: Icons.arrow_back,
          title: 'Volta',
          subtitle: line.pontoB.isNotEmpty ? line.pontoB : 'Ponto B',
          times: dirs['volta'] ?? const [],
          highlightNext: isToday,
        ),
      ],
    );
  }
}

class _DirectionBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> times;
  final bool highlightNext;
  const _DirectionBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.times,
    required this.highlightNext,
  });

  int _nextIndex() {
    if (!highlightNext) return -1;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    for (var i = 0; i < times.length; i++) {
      final m = _toMin(times[i]);
      if (m >= nowMin) return i;
    }
    return -1;
  }

  int _toMin(String t) {
    final p = t.split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final next = _nextIndex();

    String? eta;
    if (next >= 0) {
      final now = TimeOfDay.now();
      final diff = _toMin(times[next]) - (now.hour * 60 + now.minute);
      eta = diff <= 0
          ? 'agora'
          : (diff < 60 ? 'em $diff min' : 'em ${diff ~/ 60}h${diff % 60}min');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(title, style: t.titleMedium),
            const SizedBox(width: 8),
            Expanded(
              child: Text(subtitle,
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        if (next >= 0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_bus, color: cs.onPrimaryContainer),
                const SizedBox(width: 10),
                Text('Próximo: ${times[next]}',
                    style: t.titleMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(eta!,
                    style: t.bodyMedium?.copyWith(color: cs.onPrimaryContainer)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (times.isEmpty)
          Text('Sem horários neste dia.',
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
        else
          LayoutBuilder(builder: (ctx, c) {
            const spacing = 8.0;
            const minChip = 64.0;
            final cols = ((c.maxWidth + spacing) / (minChip + spacing))
                .floor()
                .clamp(3, 6);
            final chipW =
                (c.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < times.length; i++)
                  SizedBox(
                    width: chipW,
                    child: _TimeChip(
                      time: times[i],
                      isNext: i == next,
                      isPast: highlightNext && next >= 0 && i < next,
                    ),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  final bool isNext;
  final bool isPast;
  const _TimeChip(
      {required this.time, required this.isNext, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg, fg;
    if (isNext) {
      bg = cs.primary;
      fg = cs.onPrimary;
    } else if (isPast) {
      bg = cs.surfaceContainerHigh;
      fg = cs.onSurfaceVariant.withValues(alpha: 0.45);
    } else {
      bg = cs.secondaryContainer;
      fg = cs.onSecondaryContainer;
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        time,
        style: TextStyle(
          color: fg,
          fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
          fontSize: 15,
          fontFeatures: const [FontFeature.tabularFigures()],
          decoration: isPast ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
