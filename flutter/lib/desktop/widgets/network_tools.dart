import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// LAN helpers used by the device card and the clients catalog.
class NetworkTools {
  NetworkTools._();

  static const int directPort = 21118;

  /// IPv4 addresses of this machine, loopback and link-local excluded.
  static Future<List<String>> localIPv4s() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final result = <String>[];
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) result.add(address.address);
        }
      }
      return result;
    } catch (e) {
      debugPrint('localIPv4s failed: $e');
      return const [];
    }
  }

  /// Checks whether [host] accepts a TCP connection on [port].
  static Future<bool> probe(
    String host, {
    int port = directPort,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final addresses = await InternetAddress.lookup(host).timeout(timeout);
      if (addresses.isEmpty) return false;
      final address = addresses.firstWhere(
        (a) => a.type == InternetAddressType.IPv4,
        orElse: () => addresses.first,
      );
      final socket = await Socket.connect(address.address, port,
          timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _run(List<String> args) async {
    try {
      final result = await Process.run('powershell', args);
      return (result.stdout ?? '').toString().trim();
    } catch (e) {
      debugPrint('powershell failed: $e');
      return '';
    }
  }

  /// Returns the network profile category (`Private`, `Public` or empty).
  static Future<String> networkCategory() async {
    if (!Platform.isWindows) return '';
    return _run([
      '-NoProfile',
      '-Command',
      r"(Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne 'Unknown' } | Select-Object -First 1).NetworkCategory",
    ]);
  }

  /// Whether the direct-IP port is being listened on locally.
  static Future<bool> portListening(int port) async {
    if (!Platform.isWindows) return false;
    final out = await _run([
      '-NoProfile',
      '-Command',
      "(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0",
    ]);
    return out.toLowerCase() == 'true';
  }

  /// Whether an inbound firewall rule for the given display name exists.
  static Future<bool> firewallRuleExists(String displayName) async {
    if (!Platform.isWindows) return false;
    final out = await _run([
      '-NoProfile',
      '-Command',
      "(Get-NetFirewallRule -DisplayName '$displayName' -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0",
    ]);
    return out.toLowerCase() == 'true';
  }

  /// Creates the inbound firewall rules for the direct-IP port, asking for
  /// elevation through the Windows UAC prompt.
  static Future<bool> fixFirewall() async {
    if (!Platform.isWindows) return false;
    try {
      const script = r"""
$ErrorActionPreference = 'Stop'
$rules = @(
  @{n='NO 21118 TCP'; p='TCP'},
  @{n='NO 21118 UDP'; p='UDP'}
)
foreach ($r in $rules) {
  if (-not (Get-NetFirewallRule -DisplayName $r.n -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $r.n -Direction Inbound -Protocol $r.p -LocalPort 21118 -Action Allow -Profile Any | Out-Null
  }
}
'NO firewall rules applied.'
""";
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}no-fix-firewall.ps1';
      final file = File(path);
      await file.writeAsString(script, flush: true);
      final command =
          'Start-Process -FilePath powershell -Verb RunAs -ArgumentList \'-NoProfile -File "$path"\'';
      final encoded = _encodeUtf16Le(command);
      final result = await Process.run(
          'powershell', ['-NoProfile', '-EncodedCommand', encoded]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('fixFirewall failed: $e');
      return false;
    }
  }

  static String _encodeUtf16Le(String value) {
    final bytes = <int>[];
    for (final unit in value.codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }
    return base64Encode(bytes);
  }
}
