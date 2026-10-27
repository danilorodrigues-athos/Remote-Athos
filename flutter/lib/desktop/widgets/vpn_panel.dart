import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/network_tools.dart';
import 'package:flutter_hbb/desktop/widgets/vpn_tools.dart';

class VpnPanel extends StatefulWidget {
  const VpnPanel({Key? key}) : super(key: key);

  @override
  State<VpnPanel> createState() => _VpnPanelState();
}

class _VpnPanelState extends State<VpnPanel> {
  VpnStatus? _radmin;
  LocalIpInfo? _localIp;
  bool _loading = true;
  bool _refreshing = false;
  bool _changingIp = false;
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
      final results = await Future.wait<Object?>([
        VpnTools.radminStatus(),
        NetworkTools.localIpInfo(),
      ]);
      if (!mounted) return;
      setState(() {
        _radmin = results[0] as VpnStatus;
        _localIp = results[1] as LocalIpInfo?;
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

  Future<void> _copyLocalIp() async {
    final info = _localIp;
    if (info == null) return;
    await Clipboard.setData(ClipboardData(text: info.address));
    if (!mounted) return;
    showToast('IP copiado: ${info.address}');
  }

  Future<void> _openApp(VpnStatus status) async {
    final ok = await VpnTools.openApp(status.appPath);
    if (!mounted || ok) return;
    showToast('Abra o ${status.name} pelo menu Iniciar.');
  }

  Future<void> _toggleLocalIp() async {
    final info = _localIp;
    if (info == null || _changingIp) return;
    final fixing = info.dhcpEnabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fixing ? 'Fixar IP?' : 'Usar IP automático?'),
        content: Text(
          fixing
              ? 'Fixar o IP ${info.addressWithPrefix} no adaptador '
                  '"${info.adapter}"?\n\n'
                  'O Windows deixará de usar DHCP nesse adaptador. Confirme '
                  'que o IP está fora da faixa distribuída pelo roteador para '
                  'evitar conflito.'
              : 'Voltar a obter IP automaticamente no adaptador '
                  '"${info.adapter}"?\n\n'
                  'O computador pode receber outro endereço.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(fixing ? 'Fixar IP' : 'Usar automático'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _changingIp = true);
    final ok = fixing
        ? await NetworkTools.fixLocalIp(info)
        : await NetworkTools.useAutomaticLocalIp(info);
    if (!mounted) return;
    setState(() => _changingIp = false);
    showToast(ok
        ? (fixing
            ? 'IP ${info.address} fixado.'
            : 'IP automático reativado.')
        : 'Não foi possível alterar o IP. Aceite o UAC e tente novamente.');
    await _refresh();
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
                child: Icon(Icons.lan_rounded,
                    size: 17, color: MyTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REDE LOCAL',
                      style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    Text(
                      'Radmin VPN e IP da máquina',
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
            'Detecta o Radmin VPN conectado e mostra o IP da rede local. '
            'Use Fixar IP para manter o endereço atual neste computador.',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final radmin =
                  _vpnCard(context, 'Radmin VPN', _radmin, Icons.lan_rounded);
              final localIp = _localIpCard(context);
              if (constraints.maxWidth < 700) {
                return Column(
                  children: [
                    radmin,
                    const SizedBox(height: 10),
                    localIp,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: radmin),
                  const SizedBox(width: 10),
                  Expanded(child: localIp),
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

  Widget _localIpCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);
    final info = _localIp;
    final statusColor = info == null
        ? Colors.grey
        : (info.dhcpEnabled ? Colors.orange : Colors.green);
    final detail = info == null
        ? (_loading ? 'Verificando...' : 'Não detectado')
        : (info.dhcpEnabled ? 'Automático (DHCP)' : 'Fixo');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B2B) : const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer_rounded, size: 17, color: statusColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'IP local',
                  style: TextStyle(
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
          if (info != null) ...[
            const SizedBox(height: 4),
            Text(
              info.addressWithPrefix,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Adaptador: ${info.adapter}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: muted),
            ),
            if (info.gateway.isNotEmpty)
              Text(
                'Gateway: ${info.gateway}',
                style: TextStyle(fontSize: 10.5, color: muted),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              children: [
                _smallButton(
                  icon: Icons.copy_rounded,
                  label: 'Copiar IP',
                  onPressed: _copyLocalIp,
                ),
                _smallButton(
                  icon: info.dhcpEnabled
                      ? Icons.push_pin_rounded
                      : Icons.autorenew_rounded,
                  label: _changingIp
                      ? 'Aplicando...'
                      : (info.dhcpEnabled
                          ? 'Fixar IP'
                          : 'Usar automático'),
                  onPressed: _changingIp ? null : _toggleLocalIp,
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
    required VoidCallback? onPressed,
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
