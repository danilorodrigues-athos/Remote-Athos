import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class VpnStatus {
  const VpnStatus({
    required this.name,
    required this.supported,
    required this.installed,
    required this.connected,
    required this.detail,
    this.ips = const [],
    this.appPath,
  });

  final String name;
  final bool supported;
  final bool installed;
  final bool connected;
  final String detail;
  final List<String> ips;
  final String? appPath;

  String get primaryIp => ips.isEmpty ? '' : ips.first;
}

/// Detects VPN clients already configured on the machine. It never creates
/// or joins a network; that stays in the official Radmin VPN/Tailscale apps.
class VpnTools {
  VpnTools._();

  static const _radminPaths = [
    r'C:\Program Files (x86)\Radmin VPN\RvRvpnGui.exe',
    r'C:\Program Files\Radmin VPN\RvRvpnGui.exe',
    r'C:\Program Files (x86)\Radmin VPN\RadminVPN.exe',
    r'C:\Program Files\Radmin VPN\RadminVPN.exe',
    r'C:\Program Files (x86)\Famatech\Radmin VPN\RvRvpnGui.exe',
    r'C:\Program Files\Famatech\Radmin VPN\RvRvpnGui.exe',
  ];

  static const _tailscalePaths = [
    r'C:\Program Files\Tailscale\tailscale.exe',
    r'C:\Program Files (x86)\Tailscale\tailscale.exe',
  ];

  static Future<VpnStatus> radminStatus() async {
    if (!Platform.isWindows) {
      return const VpnStatus(
        name: 'Radmin VPN',
        supported: false,
        installed: false,
        connected: false,
        detail: 'Disponível apenas no Windows',
      );
    }

    final appPath = await _findRadminApp();
    final interfaces = await _interfaces();
    var adapterFound = false;
    final ips = <String>[];

    for (final interface in interfaces) {
      final isRadminName =
          interface.name.toLowerCase().contains('radmin');
      if (isRadminName) adapterFound = true;
      for (final address in interface.addresses) {
        if (address.type != InternetAddressType.IPv4 ||
            address.isLoopback ||
            address.isLinkLocal) {
          continue;
        }
        if (isRadminName || _isRadminAddress(address.address)) {
          adapterFound = true;
          ips.add(address.address);
        }
      }
    }

    final installed = appPath != null || adapterFound;
    return VpnStatus(
      name: 'Radmin VPN',
      supported: true,
      installed: installed,
      connected: ips.isNotEmpty,
      detail: ips.isNotEmpty
          ? 'Conectado'
          : installed
              ? 'Desconectado'
              : 'Não instalado',
      ips: _sortedUnique(ips),
      appPath: appPath,
    );
  }

  static Future<VpnStatus> tailscaleStatus() async {
    final cli = await _findTailscaleCli();
    final appPath = await _findTailscaleGui(cli);
    final interfaces = await _interfaces();
    var adapterFound = false;
    final interfaceIps = <String>[];

    for (final interface in interfaces) {
      final isTailscaleName =
          interface.name.toLowerCase().contains('tailscale');
      if (isTailscaleName) adapterFound = true;
      for (final address in interface.addresses) {
        if (address.type != InternetAddressType.IPv4 ||
            address.isLoopback ||
            address.isLinkLocal) {
          continue;
        }
        if (isTailscaleName || _isTailscaleAddress(address.address)) {
          adapterFound = true;
          interfaceIps.add(address.address);
        }
      }
    }

    final installed = cli != null || adapterFound;
    if (cli == null) {
      return VpnStatus(
        name: 'Tailscale',
        supported: true,
        installed: installed,
        connected: interfaceIps.isNotEmpty,
        detail: interfaceIps.isNotEmpty
            ? 'Conectado'
            : installed
                ? 'Desconectado'
                : 'Não instalado',
        ips: _sortedUnique(interfaceIps),
        appPath: appPath,
      );
    }

    try {
      final result = await Process.run(cli, ['status', '--json'])
          .timeout(const Duration(seconds: 4));
      if (result.exitCode == 0) {
        final data = jsonDecode((result.stdout ?? '').toString());
        if (data is Map) {
          final ips = <String>[...interfaceIps];
          final self = data['Self'];
          if (self is Map) {
            final reported = self['TailscaleIPs'];
            if (reported is List) {
              for (final value in reported) {
                final ip = value?.toString() ?? '';
                if (_isIPv4(ip)) ips.add(ip);
              }
            }
          }
          final state = data['BackendState']?.toString() ?? '';
          final health = data['Health'];
          final starting = health is List &&
              health.any((item) => item
                  .toString()
                  .toLowerCase()
                  .contains('starting'));
          final connected = state == 'Running' || ips.isNotEmpty;
          return VpnStatus(
            name: 'Tailscale',
            supported: true,
            installed: true,
            connected: connected,
            detail: _tailscaleDetail(state, connected, starting: starting),
            ips: _sortedUnique(ips),
            appPath: appPath,
          );
        }
      }
    } catch (e) {
      debugPrint('tailscale status failed: $e');
    }

    return VpnStatus(
      name: 'Tailscale',
      supported: true,
      installed: true,
      connected: interfaceIps.isNotEmpty,
      detail:
          interfaceIps.isNotEmpty ? 'Conectado' : 'Serviço indisponível',
      ips: _sortedUnique(interfaceIps),
      appPath: appPath,
    );
  }

  static Future<bool> openApp(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      final args = path.toLowerCase().endsWith('rvrvpngui.exe')
          ? const <String>['/show']
          : const <String>[];
      await Process.start(
        path,
        args,
        workingDirectory: File(path).parent.path,
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (e) {
      debugPrint('open VPN app failed: $e');
      return false;
    }
  }

  static Future<String?> _findRadminApp() async {
    for (final path in _radminPaths) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  static Future<String?> _findTailscaleCli() async {
    for (final path in _tailscalePaths) {
      if (await File(path).exists()) return path;
    }
    if (Platform.isWindows) {
      return _which('where.exe');
    }
    return _which('which');
  }

  static Future<String?> _findTailscaleGui(String? cli) async {
    if (!Platform.isWindows || cli == null) return null;
    final dir = File(cli).parent.path;
    final gui = '$dir${Platform.pathSeparator}tailscale-ipn.exe';
    return await File(gui).exists() ? gui : null;
  }

  static Future<String?> _which(String command) async {
    try {
      final result = await Process.run(command, ['tailscale'])
          .timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) return null;
      final lines =
          (result.stdout ?? '').toString().split(RegExp(r'\r?\n'));
      for (final line in lines) {
        final path = line.trim().replaceAll('"', '');
        if (path.isNotEmpty && await File(path).exists()) return path;
      }
    } catch (e) {
      debugPrint('tailscale lookup failed: $e');
    }
    return null;
  }

  static Future<List<NetworkInterface>> _interfaces() async {
    try {
      return await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('VPN interfaces failed: $e');
      return const [];
    }
  }

  static bool _isRadminAddress(String ip) => ip.startsWith('26.');

  static bool _isTailscaleAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4 || parts[0] != '100') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 64 && second <= 127;
  }

  static bool _isIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
    }
    return true;
  }

  static List<String> _sortedUnique(Iterable<String> values) {
    final set = values.toSet().toList();
    set.sort();
    return set;
  }

  static String _tailscaleDetail(String state, bool connected,
      {bool starting = false}) {
    if (starting) return 'Iniciando';
    switch (state) {
      case 'Running':
        return 'Conectado';
      case 'Starting':
        return 'Iniciando';
      case 'NeedsLogin':
        return 'Login necessário';
      case 'Stopped':
        return 'Desconectado';
      case 'NoState':
        return 'Serviço parado';
      default:
        return connected ? 'Conectado' : 'Desconectado';
    }
  }
}
