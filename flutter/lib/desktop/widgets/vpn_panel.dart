import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/vpn_tools.dart';

class VpnPanel extends StatefulWidget {
  const VpnPanel({Key? key}) : super(key: key);

  @override
  State<VpnPanel> createState() => _VpnPanelState();
}

class _VpnPanelState extends State<VpnPanel> {
  VpnStatus? _radmin;
  VpnStatus? _tailscale;
  bool _loading = true;
  bool _refreshing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait([
        VpnTools.radminStatus(),
        VpnTools.tailscaleStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _radmin = results[0];
        _tailscale = results[1];
        _loading = false;
      });
    } catch (e) {
      debugPrint('VPN refresh failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _copyIp(VpnStatus status) async {
    if (status.primaryIp.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: status.primaryIp));
    if (!mounted) return;
    showToast('IP copiado: ${status.primaryIp}');
  }

  Future<void> _openApp(VpnStatus status) async {
    final ok = await VpnTools.openApp(status.appPath);
    if (!mounted || ok) return;
    showToast('Abra o ${status.name} pelo menu Iniciar.');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);
    final borderColor =
        isDark ? const Color(0xFF24252B) : const Color(0xFFE1E1E1);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: MyTheme.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.vpn_lock_rounded,
                    size: 17, color: MyTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VPN',
                      style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    Text(
                      'Radmin VPN ou Tailscale',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              if (_loading || _refreshing)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: muted,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Atualizar',
                onPressed: _refreshing ? null : _refresh,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.refresh_rounded, size: 18, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Conecte no aplicativo oficial e use o IP virtual no NÓ. '
            'O painel apenas detecta a conexão existente.',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final radmin =
                  _vpnCard(context, 'Radmin VPN', _radmin, Icons.lan_rounded);
              final tailscale = _vpnCard(
                  context, 'Tailscale', _tailscale, Icons.hub_rounded);
              if (constraints.maxWidth < 700) {
                return Column(
                  children: [
                    radmin,
                    const SizedBox(height: 10),
                    tailscale,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: radmin),
                  const SizedBox(width: 10),
                  Expanded(child: tailscale),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _vpnCard(
    BuildContext context,
    String title,
    VpnStatus? status,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);
    final statusColor = _statusColor(status);
    final detail = status?.detail ??
        (_loading ? 'Verificando...' : 'Não foi possível verificar');
    final connected = status?.connected ?? false;
    final installed = status?.installed ?? false;
    final ips = status?.ips ?? const <String>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B2B) : const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(connected ? 0.4 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
          if (ips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ips.join('  ·  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
          if (status != null && status.supported && !connected) ...[
            const SizedBox(height: 4),
            Text(
              installed
                  ? 'Abra o aplicativo e conecte-se à rede.'
                  : 'Instale o aplicativo e conecte-se à rede.',
              style: TextStyle(fontSize: 10.5, color: muted),
            ),
          ],
          if (status?.appPath != null || ips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              children: [
                if (ips.isNotEmpty)
                  _smallButton(
                    icon: Icons.copy_rounded,
                    label: 'Copiar IP',
                    onPressed: () => _copyIp(status!),
                  ),
                if (status?.appPath != null)
                  _smallButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'Abrir',
                    onPressed: () => _openApp(status!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11.5),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }

  Color _statusColor(VpnStatus? status) {
    if (status == null) return Colors.grey;
    if (!status.supported) return Colors.grey;
    if (status.connected) return Colors.green;
    if (status.installed) return Colors.orange;
    return Colors.grey;
  }
}
