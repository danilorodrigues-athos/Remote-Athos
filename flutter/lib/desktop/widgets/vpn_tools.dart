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

/// Detects the Radmin VPN client already configured on the machine. It never
/// creates or joins a network; that stays in the official Radmin VPN app.
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

  static Future<bool> openApp(String? path) async {
    if (path == null) return false;
    try {
      await Process.start(path, const [], mode: ProcessStartMode.detached);
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

  static Future<List<NetworkInterface>> _interfaces() async {
    try {
      return await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
    } catch (e) {
      debugPrint('VPN interfaces failed: $e');
      return const [];
    }
  }

  static bool _isRadminAddress(String ip) => ip.startsWith('26.');

  static List<String> _sortedUnique(Iterable<String> values) {
    final set = values.toSet().toList();
    set.sort();
    return set;
  }
}
