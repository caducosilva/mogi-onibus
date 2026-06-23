import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'models.dart';
import 'schedule_repository.dart';
import 'update_service.dart';
import 'line_detail.dart';

void main() => runApp(const MogiOnibusApp());

class MogiOnibusApp extends StatelessWidget {
  const MogiOnibusApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1B5E20); // verde Mogi
    return MaterialApp(
      title: 'Ônibus Mogi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

enum SyncStatus { idle, checking, upToDate, available, offline }

class _HomePageState extends State<HomePage> {
  final _repo = ScheduleRepository();
  final _updates = UpdateService();
  SchedulesData? _data;
  String _query = '';
  bool _loading = true;

  SyncStatus _status = SyncStatus.idle;
  RemoteCheck? _remote;
  String? _lastChecked; // ISO

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = await _repo.loadLocal();
    final last = await _repo.lastCheckedAt();
    setState(() {
      _data = data;
      _lastChecked = last;
      _loading = false;
    });
    // verificações de atualização em segundo plano, após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduleUpdate(showPopup: true);
      _checkAppUpdate();
    });
  }

  /// Verifica horários no GitHub. Atualiza o status na tela e, se [showPopup],
  /// abre o popup quando há novidade.
  Future<void> _checkScheduleUpdate({bool showPopup = false}) async {
    setState(() => _status = SyncStatus.checking);
    final remote = await _repo.checkRemote();
    if (!mounted) return;
    final last = await _repo.lastCheckedAt();
    setState(() {
      _remote = remote;
      _lastChecked = last;
      if (remote == null) {
        _status = SyncStatus.offline;
      } else {
        _status =
            remote.isNewer ? SyncStatus.available : SyncStatus.upToDate;
      }
    });
    if (remote != null && remote.isNewer && showPopup) {
      await _promptApplySchedule();
    }
  }

  Future<void> _promptApplySchedule() async {
    final remote = _remote;
    if (remote == null) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.update),
        title: const Text('Novos horários disponíveis'),
        content: Text(
            'Há uma atualização de horários (${_friendlyDate(remote.remoteVersion)}).\n'
            'Deseja atualizar agora? É rápido e funciona offline depois.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Agora não')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Atualizar')),
        ],
      ),
    );
    if (accept == true) {
      await _repo.applyPending(remote.data);
      if (!mounted) return;
      setState(() {
        _data = remote.data;
        _status = SyncStatus.upToDate;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horários atualizados!')),
      );
    }
  }

  Future<void> _checkAppUpdate() async {
    final rel = await _updates.checkAppUpdate();
    if (rel == null || !mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update),
        title: Text('Nova versão do app (${rel.tag})'),
        content: SingleChildScrollView(
          child: Text(rel.body.isNotEmpty
              ? rel.body
              : 'Uma nova versão do aplicativo está disponível.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Depois')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Baixar')),
        ],
      ),
    );
    if (go == true) {
      final url = rel.apkUrl ?? rel.htmlUrl;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines =
        _data?.linhas.where((l) => l.matches(_query)).toList() ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ônibus Mogi'),
        actions: [
          IconButton(
            tooltip: 'Sobre',
            icon: const Icon(Icons.info_outline),
            onPressed: _showAbout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar linha (nº, nome, bairro)...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (_data != null) _buildSyncCard(context, lines.length),
                Expanded(
                  child: lines.isEmpty
                      ? Center(
                          child: Text('Nenhuma linha encontrada.',
                              style: Theme.of(context).textTheme.bodyMedium),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          itemCount: lines.length,
                          itemBuilder: (ctx, i) =>
                              _LineCard(line: lines[i]),
                        ),
                ),
              ],
            ),
    );
  }

  /// "2026-06-23" -> "23/06/2026"
  String _friendlyDate(String iso) {
    final p = iso.split('T').first.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  /// "...T14:31:00" -> "23/06 às 14:31"
  String _friendlyDateTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)} às ${two(d.hour)}:${two(d.minute)}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildSyncCard(BuildContext context, int lineCount) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // status visual
    late IconData icon;
    late Color tint;
    late String statusText;
    Widget? action;
    switch (_status) {
      case SyncStatus.checking:
        icon = Icons.sync;
        tint = cs.primary;
        statusText = 'Verificando atualizações...';
        break;
      case SyncStatus.available:
        icon = Icons.notifications_active;
        tint = cs.tertiary;
        statusText =
            'Nova atualização disponível (${_friendlyDate(_remote!.remoteVersion)})';
        action = FilledButton.tonal(
          onPressed: _promptApplySchedule,
          child: const Text('Atualizar'),
        );
        break;
      case SyncStatus.upToDate:
        icon = Icons.check_circle;
        tint = Colors.green;
        statusText = 'Você está com os horários mais recentes';
        break;
      case SyncStatus.offline:
        icon = Icons.cloud_off;
        tint = cs.error;
        statusText = 'Sem internet — usando horários salvos';
        action = TextButton(
          onPressed: () => _checkScheduleUpdate(showPopup: true),
          child: const Text('Tentar'),
        );
        break;
      case SyncStatus.idle:
        icon = Icons.event;
        tint = cs.onSurfaceVariant;
        statusText = '';
        break;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.directions_bus, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horários atualizados em ${_friendlyDate(_data!.dataVersao)}',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(icon, size: 14, color: tint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          statusText.isNotEmpty
                              ? statusText
                              : '$lineCount linhas disponíveis',
                          style: t.bodySmall?.copyWith(color: tint),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (_lastChecked != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Verificado no GitHub: ${_friendlyDateTime(_lastChecked!)}',
                        style: t.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            action ??
                IconButton(
                  tooltip: 'Verificar agora',
                  icon: const Icon(Icons.refresh),
                  onPressed: _status == SyncStatus.checking
                      ? null
                      : () => _checkScheduleUpdate(showPopup: true),
                ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Ônibus Mogi',
      applicationVersion: 'Horários: ${_data?.dataVersao ?? '—'}',
      children: [
        const SizedBox(height: 8),
        const Text(
            'App não oficial com os horários de ônibus de Mogi das Cruzes. '
            'Dados extraídos do portal da Secretaria de Mobilidade e Trânsito.'),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.public),
          label: const Text('Fonte oficial'),
          onPressed: () => launchUrl(Uri.parse(AppConfig.fonteOficial),
              mode: LaunchMode.externalApplication),
        ),
        TextButton.icon(
          icon: const Icon(Icons.code),
          label: const Text('Código / atualizações (GitHub)'),
          onPressed: () => launchUrl(Uri.parse(AppConfig.sourceUrl),
              mode: LaunchMode.externalApplication),
        ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  final BusLine line;
  const _LineCard({required this.line});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LineDetailPage(line: line)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 56),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  line.linha,
                  textAlign: TextAlign.center,
                  style: t.titleSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  line.nome.isNotEmpty ? line.nome : line.titulo,
                  style: t.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
