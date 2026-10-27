import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class LocalIpInfo {
  const LocalIpInfo({
    required this.adapter,
    required this.address,
    required this.prefixLength,
    required this.gateway,
    required this.dhcpEnabled,
  });

  final String adapter;
  final String address;
  final int prefixLength;
  final String gateway;
  final bool dhcpEnabled;

  String get addressWithPrefix => '$address/$prefixLength';

  bool get canFix =>
      address.isNotEmpty && prefixLength >= 1 && prefixLength <= 32;
}

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

  /// Primary physical LAN configuration, ignoring virtual VPN adapters.
  static Future<LocalIpInfo?> localIpInfo() async {
    if (!Platform.isWindows) return null;
    final output = await _run([
      '-NoProfile',
      '-Command',
      r'''
$ErrorActionPreference = 'SilentlyContinue'
$physical = @(Get-NetAdapter | Where-Object {
  $_.Status -eq 'Up' -and $_.Virtual -eq $false
} | Select-Object -ExpandProperty ifIndex)
if ($physical.Count -eq 0) { Write-Output 'FOUND=0'; exit 0 }
$configs = @(Get-NetIPConfiguration | Where-Object {
  $physical -contains $_.InterfaceIndex -and
  $_.IPv4Address -ne $null -and
  $_.IPv4Address[0].IPAddress -notlike '169.254.*'
})
$cfg = @($configs | Where-Object { $_.IPv4DefaultGateway -ne $null } |
  Sort-Object { $_.NetAdapter.InterfaceMetric } | Select-Object -First 1)
if (-not $cfg) {
  $cfg = @($configs | Sort-Object { $_.NetAdapter.InterfaceMetric } |
    Select-Object -First 1)
}
if (-not $cfg) { Write-Output 'FOUND=0'; exit 0 }
$ip = @($cfg.IPv4Address)[0]
$gw = @($cfg.IPv4DefaultGateway)[0]
$dhcp = (Get-NetIPInterface -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4).Dhcp
Write-Output 'FOUND=1'
Write-Output ('ADAPTER=' + $cfg.InterfaceAlias)
Write-Output ('ADDRESS=' + $ip.IPAddress)
Write-Output ('PREFIX=' + $ip.PrefixLength)
if ($gw) { Write-Output ('GATEWAY=' + $gw.NextHop) }
Write-Output ('DHCP=' + $dhcp)
''',
    ]);
    if (output.isEmpty) return null;

    final values = <String, String>{};
    for (final line in output.split(RegExp(r'\r?\n'))) {
      final index = line.indexOf('=');
      if (index <= 0) continue;
      values[line.substring(0, index)] = line.substring(index + 1).trim();
    }
    if (values['FOUND'] != '1') return null;

    final adapter = values['ADAPTER'] ?? '';
    final address = values['ADDRESS'] ?? '';
    final gateway = values['GATEWAY'] ?? '';
    final prefix = int.tryParse(values['PREFIX'] ?? '') ?? 0;
    if (adapter.isEmpty ||
        !_isIPv4(address) ||
        (gateway.isNotEmpty && !_isIPv4(gateway)) ||
        prefix < 1 ||
        prefix > 32) {
      return null;
    }
    return LocalIpInfo(
      adapter: adapter,
      address: address,
      prefixLength: prefix,
      gateway: gateway,
      dhcpEnabled: (values['DHCP'] ?? '').toLowerCase() == 'enabled',
    );
  }

  static Future<bool> fixLocalIp(LocalIpInfo info) =>
      _applyLocalIpMode(info, automatic: false);

  static Future<bool> useAutomaticLocalIp(LocalIpInfo info) =>
      _applyLocalIpMode(info, automatic: true);

  static Future<bool> _applyLocalIpMode(
    LocalIpInfo info, {
    required bool automatic,
  }) async {
    if (!Platform.isWindows) return false;
    if (!automatic &&
        (!info.canFix ||
            !_isIPv4(info.address) ||
            (info.gateway.isNotEmpty && !_isIPv4(info.gateway)))) {
      return false;
    }
    try {
      final adapter = _psQuote(info.adapter);
      final script = automatic
          ? '''
\$ErrorActionPreference = 'Stop'
\$adapter = $adapter
& netsh.exe interface ipv4 set address "name=\$adapter" source=dhcp
if (\$LASTEXITCODE -ne 0) { throw "Falha ao usar DHCP (\$LASTEXITCODE)." }
& ipconfig.exe /renew "\$adapter" | Out-Null
'''
          : '''
\$ErrorActionPreference = 'Stop'
\$adapter = $adapter
\$ip = '${info.address}'
\$mask = '${_prefixToMask(info.prefixLength)}'
\$gateway = '${info.gateway}'
\$arguments = @('interface','ipv4','set','address', "name=\$adapter", 'static', \$ip, \$mask)
if (\$gateway -ne '') { \$arguments += \$gateway }
& netsh.exe @arguments
if (\$LASTEXITCODE -ne 0) { throw "Falha ao fixar o IP (\$LASTEXITCODE)." }
''';
      final encodedScript = _encodeUtf16Le(script);
      final command = '''
\$p = Start-Process -FilePath powershell -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand','$encodedScript')
if (\$p.ExitCode -ne 0) { exit \$p.ExitCode }
''';
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-EncodedCommand',
        _encodeUtf16Le(command),
      ]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('local IP mode failed: $e');
      return false;
    }
  }

  static String _prefixToMask(int prefix) {
    final value = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ].join('.');
  }

  static String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

  static bool _isIPv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null || number < 0 || number > 255) return false;
    }
    return true;
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
