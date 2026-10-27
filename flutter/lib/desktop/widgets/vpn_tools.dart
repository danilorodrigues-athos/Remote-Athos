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
/// or joins a network; that stays in the official Radmin VPN/WireGuard apps.
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

  static const _wireguardPaths = [
    r'C:\Program Files\WireGuard\WireGuard.exe',
    r'C:\Program Files (x86)\WireGuard\WireGuard.exe',
  ];

  static const _wireguardCliPaths = [
    r'C:\Program Files\WireGuard\wg.exe',
    r'C:\Program Files (x86)\WireGuard\wg.exe',
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

  static Future<VpnStatus> wireguardStatus() async {
    if (!Platform.isWindows) {
      return const VpnStatus(
        name: 'WireGuard',
        supported: false,
        installed: false,
        connected: false,
        detail: 'Disponível apenas no Windows',
      );
    }

    var appPath = await _findWireGuardApp();
    final cli = await _findWireGuardCli(appPath);
    if (appPath == null && cli != null) {
      final gui = '${File(cli).parent.path}${Platform.pathSeparator}'
          'WireGuard.exe';
      if (await File(gui).exists()) appPath = gui;
    }

    final adapters = await _wireGuardAdapters();
    final tunnelNames = await _wireGuardTunnels(cli);
    final names = tunnelNames.map((name) => name.toLowerCase()).toSet();
    var adapterFound = adapters.found;
    final ips = <String>[...adapters.ips];

    if (!adapterFound || ips.isEmpty) {
      final interfaces = await _interfaces();
      for (final interface in interfaces) {
        final lowerName = interface.name.toLowerCase();
        final isWireGuard = lowerName.contains('wireguard') ||
            names.contains(lowerName);
        if (!isWireGuard) continue;
        adapterFound = true;
        for (final address in interface.addresses) {
          if (address.type != InternetAddressType.IPv4 ||
              address.isLoopback ||
              address.isLinkLocal) {
            continue;
          }
          ips.add(address.address);
        }
      }
    }

    final connected = adapterFound || tunnelNames.isNotEmpty;
    final installed = appPath != null || cli != null || connected;
    return VpnStatus(
      name: 'WireGuard',
      supported: true,
      installed: installed,
      connected: connected,
      detail: connected
          ? (ips.isEmpty ? 'Conectado (IP não detectado)' : 'Conectado')
          : installed
              ? 'Desconectado'
              : 'Não instalado',
      ips: _sortedUnique(ips),
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

  static Future<String?> _findWireGuardApp() async {
    for (final path in _wireguardPaths) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  static Future<String?> _findWireGuardCli(String? appPath) async {
    if (appPath != null) {
      final cli =
          '${File(appPath).parent.path}${Platform.pathSeparator}wg.exe';
      if (await File(cli).exists()) return cli;
    }
    for (final path in _wireguardCliPaths) {
      if (await File(path).exists()) return path;
    }
    return _which('wg.exe');
  }

  static Future<_WireGuardInfo> _wireGuardAdapters() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'''
$ErrorActionPreference = 'SilentlyContinue'
$adapters = @(Get-NetAdapter | Where-Object {
  $_.Status -eq 'Up' -and (
    $_.InterfaceDescription -like '*WireGuard*' -or
    $_.Name -like '*WireGuard*'
  )
})
foreach ($adapter in $adapters) {
  Write-Output ('NAME=' + $adapter.Name)
  $ips = @(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '169.254.*' } |
    Select-Object -ExpandProperty IPAddress)
  foreach ($ip in $ips) { Write-Output ('IP=' + $ip) }
}
''',
      ]).timeout(const Duration(seconds: 6));
      if (result.exitCode != 0) return const _WireGuardInfo.empty();
      var found = false;
      final ips = <String>[];
      final lines =
          (result.stdout ?? '').toString().split(RegExp(r'\r?\n'));
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.startsWith('NAME=')) {
          found = true;
        } else if (line.startsWith('IP=')) {
          final ip = line.substring(3).trim();
          if (_isIPv4(ip)) ips.add(ip);
        }
      }
      return _WireGuardInfo(found: found, ips: ips);
    } catch (e) {
      debugPrint('wireguard adapters failed: $e');
      return const _WireGuardInfo.empty();
    }
  }

  static Future<List<String>> _wireGuardTunnels(String? cli) async {
    if (cli == null) return const [];
    try {
      final result = await Process.run(cli, ['show', 'interfaces'])
          .timeout(const Duration(seconds: 4));
      if (result.exitCode != 0) return const [];
      return (result.stdout ?? '')
          .toString()
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('wireguard tunnels failed: $e');
      return const [];
    }
  }

  static Future<String?> _which(String executable) async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run('where.exe', [executable])
          .timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) return null;
      final lines =
          (result.stdout ?? '').toString().split(RegExp(r'\r?\n'));
      for (final line in lines) {
        final path = line.trim().replaceAll('"', '');
        if (path.isNotEmpty && await File(path).exists()) return path;
      }
    } catch (e) {
      debugPrint('VPN lookup failed: $e');
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
}

class _WireGuardInfo {
  const _WireGuardInfo({required this.found, required this.ips});

  const _WireGuardInfo.empty()
      : found = false,
        ips = const <String>[];

  final bool found;
  final List<String> ips;
}
