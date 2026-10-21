import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_hbb/desktop/widgets/network_tools.dart';

class DiscoveredHost {
  DiscoveredHost({required this.ip, this.mac});

  final String ip;
  final String? mac;
}

/// LAN discovery helpers: subnet scan for the direct-IP port and the ARP table.
class LanScanner {
  LanScanner._();

  /// Scans the /24 of every local IPv4 address and returns the hosts that
  /// accept a TCP connection on the direct-IP port.
  static Future<List<DiscoveredHost>> scan({
    int port = NetworkTools.directPort,
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final ips = await NetworkTools.localIPv4s();
    final ownIps = ips.toSet();
    final subnets = <String>{};
    for (final ip in ips) {
      final parts = ip.split('.');
      if (parts.length == 4) subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
    }
    if (subnets.isEmpty) return const [];

    final found = <String>{};
    for (final subnet in subnets) {
      final tasks = <Future<void>>[];
      for (var i = 1; i <= 254; i++) {
        final target = '$subnet.$i';
        if (ownIps.contains(target)) continue;
        tasks.add(Future(() async {
          if (await NetworkTools.probe(target, port: port, timeout: timeout)) {
            found.add(target);
          }
        }));
        // Keep the number of concurrent sockets reasonable.
        if (tasks.length >= 64) {
          await Future.wait(tasks);
          tasks.clear();
        }
      }
      if (tasks.isNotEmpty) await Future.wait(tasks);
    }
    if (found.isEmpty) return const [];

    final arp = await arpTable();
    return found
        .map((ip) => DiscoveredHost(ip: ip, mac: arp[ip]))
        .toList()
      ..sort((a, b) => a.ip.compareTo(b.ip));
  }

  /// Parses `arp -a` into a map of IP -> MAC address.
  static Future<Map<String, String>> arpTable() async {
    if (!Platform.isWindows) return const {};
    try {
      final result = await Process.run('arp', ['-a']);
      final out = (result.stdout ?? '').toString();
      final map = <String, String>{};
      final pattern =
          RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+([0-9a-fA-F:-]{14,17})');
      for (final match in pattern.allMatches(out)) {
        final ip = match.group(1);
        final mac = match.group(2);
        if (ip == null || mac == null) continue;
        final compact =
            mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();
        if (compact.length != 12 || compact == '000000000000') continue;
        final firstOctet = int.tryParse(compact.substring(0, 2), radix: 16);
        // Skip broadcast/multicast entries, which are not host adapters.
        if (firstOctet == null || (firstOctet & 1) == 1) continue;
        map[ip] = mac;
      }
      return map;
    } catch (e) {
      debugPrint('arpTable failed: $e');
      return const {};
    }
  }

  /// Resolves a hostname to its first IPv4 address.
  static Future<String?> resolve(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      final address = addresses.firstWhere(
        (a) => a.type == InternetAddressType.IPv4,
        orElse: () => addresses.first,
      );
      return address.address;
    } catch (_) {
      return null;
    }
  }
}
