import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

/// Resultado de uma verificação no GitHub.
class RemoteCheck {
  final SchedulesData data;
  final String remoteVersion;
  final bool isNewer;
  RemoteCheck(
      {required this.data, required this.remoteVersion, required this.isNewer});
}

/// Carrega horários (cache local > asset embarcado) e verifica atualizações
/// remotas no GitHub.
class ScheduleRepository {
  static const _cacheKey = 'schedules_cache_json';
  static const _cacheVersionKey = 'schedules_cache_versao';

  /// Carrega a melhor fonte disponível imediatamente: o cache baixado, ou,
  /// na ausência dele, o JSON embarcado no APK.
  Future<SchedulesData> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        return SchedulesData.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {
        // cache corrompido — cai para o asset
      }
    }
    final bundled = await rootBundle.loadString('assets/schedules.json');
    return SchedulesData.fromJson(jsonDecode(bundled) as Map<String, dynamic>);
  }

  /// Versão dos horários atualmente em uso (cache ou asset).
  Future<String> currentVersion() async {
    final data = await loadLocal();
    return data.dataVersao;
  }

  /// Consulta o GitHub. Retorna o resultado da verificação (com a versão
  /// remota e se há novidade), ou null se a internet falhou.
  Future<RemoteCheck?> checkRemote() async {
    try {
      final resp = await http
          .get(Uri.parse(AppConfig.schedulesRawUrl))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final jsonMap =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final remote = SchedulesData.fromJson(jsonMap);
      final local = await currentVersion();
      final newer = _isNewer(remote.dataVersao, local);
      // guarda o payload bruto para aplicar caso o usuário aceite
      _pendingRaw = utf8.decode(resp.bodyBytes);
      await _setLastChecked(DateTime.now().toIso8601String());
      return RemoteCheck(
          data: remote, remoteVersion: remote.dataVersao, isNewer: newer);
    } catch (_) {
      return null;
    }
  }

  String? _pendingRaw;

  /// Quando os horários foram baixados/verificados pela última vez (ISO).
  Future<String?> lastCheckedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCheckKey);
  }

  Future<void> _setLastChecked(String iso) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckKey, iso);
  }

  static const _lastCheckKey = 'schedules_last_check_iso';

  /// Persiste no cache os horários remotos verificados por [checkRemote].
  Future<void> applyPending(SchedulesData remote) async {
    if (_pendingRaw == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, _pendingRaw!);
    await prefs.setString(_cacheVersionKey, remote.dataVersao);
    _pendingRaw = null;
  }

  /// Compara versões no formato AAAA-MM-DD (ordenação lexicográfica funciona).
  bool _isNewer(String remote, String local) {
    if (remote.isEmpty) return false;
    if (local.isEmpty) return true;
    return remote.compareTo(local) > 0;
  }
}
