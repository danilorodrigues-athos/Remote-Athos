import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/client_catalog.dart';
import 'package:flutter_hbb/desktop/widgets/network_tools.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;
import '../widgets/button.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFF2F65BA);

class _DesktopHomePageState extends State<DesktopHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _leftPaneScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;
  var systemError = '';
  StreamSubscription? _uniLinksSubscription;
  var svcStopped = false.obs;
  var watchIsCanScreenRecording = false;
  var watchIsProcessTrust = false;
  var watchIsInputMonitoring = false;
  var watchIsCanRecordAudio = false;
  Timer? _updateTimer;
  bool isCardClosed = false;

  final RxBool _editHover = false.obs;
  final RxBool _block = false.obs;

  final GlobalKey _childKey = GlobalKey();

  int _railIndex = 0;
  bool _supportMode = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (bind.isIncomingOnly()) {
      return _buildBlock(child: buildLeftPane(context));
    }
    return _buildBlock(
        child: Stack(
      children: [
        Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF111827)
              : const Color(0xFFF3F3F3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRail(context),
              const VerticalDivider(width: 1),
              Expanded(
                child: _railIndex == 0
                    ? _buildHome(context)
                    : _railIndex == 4
                        ? const ClientsCatalogView()
                        : _buildPeersPane(context),
              ),
            ],
          ),
        ),
        if (_supportMode) _buildSupportOverlay(context),
      ],
    ));
  }

  Widget _buildRail(BuildContext context) {
    return Container(
      width: 58,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1F2E)
          : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _railButton(
            context,
            icon: Icons.home_rounded,
            tooltip: translate('Home'),
            selected: _railIndex == 0,
            onTap: () => setState(() => _railIndex = 0),
          ),
          _railButton(
            context,
            icon: Icons.history_rounded,
            tooltip: translate('Recent sessions'),
            selected: _railIndex == 1,
            onTap: () => _openPeerTab(1, 0),
          ),
          _railButton(
            context,
            icon: Icons.star_rounded,
            tooltip: translate('Favorites'),
            selected: _railIndex == 2,
            onTap: () => _openPeerTab(2, 1),
          ),
          _railButton(
            context,
            icon: Icons.contacts_rounded,
            tooltip: translate('Address book'),
            selected: _railIndex == 3,
            onTap: () => _openPeerTab(3, 3),
          ),
          _railButton(
            context,
            icon: Icons.groups_rounded,
            tooltip: 'Clientes',
            selected: _railIndex == 4,
            onTap: () => setState(() => _railIndex = 4),
          ),
          const Spacer(),
          _railButton(
            context,
            icon: Icons.settings_rounded,
            tooltip: translate('Settings'),
            selected: false,
            onTap: () {
              if (DesktopSettingPage.tabKeys.isNotEmpty) {
                DesktopSettingPage.switch2page(DesktopSettingPage.tabKeys[0]);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _railButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected
        ? MyTheme.accent
        : Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.45);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: selected ? MyTheme.accent.withOpacity(0.14) : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 21, color: color),
        ),
      ),
    );
  }

  void _openPeerTab(int railIndex, int tabIndex) {
    gFFI.peerTabModel.setCurrentTab(tabIndex);
    setState(() => _railIndex = railIndex);
  }

  Widget _buildPeersPane(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _railIndex == 1
                    ? translate('Recent sessions')
                    : _railIndex == 2
                        ? translate('Favorites')
                        : translate('Address book'),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.merge(const TextStyle(fontSize: 16)),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _railIndex = 0),
                child: Icon(Icons.close_rounded, size: 18, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 560, child: PeerTabPage()),
        ],
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 180, child: loadLogo()),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 860;
            if (narrow) {
              return Column(
                children: [
                  if (!isOutgoingOnly)
                    SizedBox(height: 420, child: _buildDeviceCard(context)),
                  if (!isOutgoingOnly) const SizedBox(height: 16),
                  SizedBox(height: 480, child: buildRightPane(context)),
                ],
              );
            }
            return SizedBox(
              height: 440,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isOutgoingOnly)
                    Expanded(flex: 5, child: _buildDeviceCard(context)),
                  if (!isOutgoingOnly) const SizedBox(width: 20),
                  Expanded(flex: 6, child: buildRightPane(context)),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 460,
              child: Obx(() => buildHelpCards(stateGlobal.updateUrl.value)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF24252B) : const Color(0xFFE1E1E1)),
      ),
      child: child,
    );
  }

  Widget _buildDeviceCard(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(
        builder: (context, model, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final muted =
              Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.5);
          final idColor =
              isDark ? Colors.white : const Color(0xFF29387A);
          final showOneTime = model.approveMode != 'click' &&
              model.verificationMethod != kUsePermanentPassword;
          return _card(
            context,
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
                      child: Icon(Icons.desktop_windows_rounded,
                          size: 17, color: MyTheme.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ESTE DISPOSITIVO',
                        style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                            color: muted),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _supportMode = true),
                      child: Tooltip(
                        message: 'Modo suporte',
                        child: Icon(Icons.present_to_all_rounded,
                            size: 18, color: muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    buildPopupMenu(context),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: model.serverId,
                        readOnly: true,
                        decoration: const InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: idColor,
                        ),
                      ).workaroundFreezeLinuxMint(),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: model.serverId.text));
                        showToast(translate("Copied"));
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2B3244)
                                  : const Color(0xFFE1E1E1)),
                        ),
                        child: Icon(Icons.copy_rounded,
                            size: 16, color: muted),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Este é o ID deste dispositivo. Compartilhe-o para receber conexões.',
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF2B3244)
                            : const Color(0xFFE1E1E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.key_rounded, size: 16, color: muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: model.serverPasswd,
                          readOnly: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(
                              fontSize: 15, letterSpacing: 1),
                        ).workaroundFreezeLinuxMint(),
                      ),
                      if (showOneTime)
                        InkWell(
                          onTap: () => bind.mainUpdateTemporaryPassword(),
                          child: Tooltip(
                            message: translate('Refresh Password'),
                            child: Icon(Icons.refresh_rounded,
                                size: 19, color: muted),
                          ),
                        ),
                      if (!bind.isDisableSettings())
                        InkWell(
                          onTap: () => DesktopSettingPage.switch2page(
                              SettingsTabKey.safety),
                          child: Tooltip(
                            message: translate('Change Password'),
                            child: Icon(Icons.edit_rounded,
                                    size: 18, color: muted)
                                .marginOnly(left: 10),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _DeviceStatusCard(),
                const SizedBox(height: 14),
                Divider(height: 1, color: muted?.withOpacity(0.3)),
                const SizedBox(height: 14),
                _tipRow(context, Icons.wifi_tethering_rounded,
                    'Ative o acesso por IP para conectar sem internet.'),
                _tipRow(context, Icons.lock_outline_rounded,
                    'Defina uma senha permanente em Configurações > Segurança.'),
                _tipRow(context, Icons.computer_rounded,
                    'Informe este ID na máquina que vai controlar este computador.'),
                const Spacer(),
                OnlineStatusWidget(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSupportOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);
    return Container(
      color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F3F3),
      padding: const EdgeInsets.all(28),
      child: FutureBuilder<List<String>>(
        future: NetworkTools.localIPv4s(),
        builder: (context, snapshot) {
          final ips = snapshot.data ?? const <String>[];
          final id = gFFI.serverModel.serverId.text;
          final passwd = gFFI.serverModel.serverPasswd.text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.headset_mic_rounded, size: 22, color: MyTheme.accent),
                  const SizedBox(width: 10),
                  Text(
                    'MODO SUPORTE',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _supportMode = false),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF24252B)
                          : const Color(0xFFE1E1E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _supportField('ID', id, Icons.tag_rounded),
                    const SizedBox(height: 18),
                    _supportField(
                      'Endereço local',
                      ips.isNotEmpty
                          ? '${ips.first}:${NetworkTools.directPort}'
                          : 'não detectado',
                      Icons.lan_rounded,
                    ),
                    const SizedBox(height: 18),
                    _supportField(
                      'Senha temporária',
                      passwd.isEmpty ? 'não configurada' : passwd,
                      Icons.key_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Leia o ID ou o endereço local para o técnico. A conexão por IP direto funciona mesmo sem internet.',
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _supportField(String label, String value, IconData icon) {
    final muted = Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, size: 18, color: MyTheme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                showToast(translate('Copied'));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _tipRow(BuildContext context, IconData icon, String text) {
    final muted = Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: MyTheme.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 11.5, color: muted)),
        ),
      ],
    ).marginOnly(bottom: 6);
  }

  Widget _buildBlock({required Widget child}) {
    return buildRemoteBlock(
        block: _block, mask: true, use: canBeBlocked, child: child);
  }

  Widget buildLeftPane(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    final isOutgoingOnly = bind.isOutgoingOnly();
    final children = <Widget>[
      if (!isOutgoingOnly) buildPresetPasswordWarning(),
      if (bind.isCustomClient())
        Align(
          alignment: Alignment.center,
          child: loadPowered(context),
        ),
      Align(
        alignment: Alignment.center,
        child: loadLogo(),
      ),
      buildTip(context),
      if (!isOutgoingOnly) buildIDBoard(context),
      if (!isOutgoingOnly) buildPasswordBoard(context),
      FutureBuilder<Widget>(
        future: Future.value(
            Obx(() => buildHelpCards(stateGlobal.updateUrl.value))),
        builder: (_, data) {
          if (data.hasData) {
            if (isIncomingOnly) {
              if (isInHomePage()) {
                Future.delayed(Duration(milliseconds: 300), () {
                  _updateWindowSize();
                });
              }
            }
            return data.data!;
          } else {
            return const Offstage();
          }
        },
      ),
    ];
    if (isIncomingOnly) {
      children.addAll([
        Divider(),
        OnlineStatusWidget(
          onSvcStatusChanged: () {
            if (isInHomePage()) {
              Future.delayed(Duration(milliseconds: 300), () {
                _updateWindowSize();
              });
            }
          },
        ).marginOnly(bottom: 6, right: 6)
      ]);
    }
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Container(
        width: isIncomingOnly ? 280.0 : 200.0,
        color: Theme.of(context).colorScheme.background,
        child: Stack(
          children: [
            Column(
              children: [
                SingleChildScrollView(
                  controller: _leftPaneScrollController,
                  child: Column(
                    key: _childKey,
                    children: children,
                  ),
                ),
                Expanded(child: Container())
              ],
            ),
            if (isOutgoingOnly)
              Positioned(
                bottom: 6,
                left: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    child: Obx(
                      () => Icon(
                        Icons.settings,
                        color: _editHover.value
                            ? textColor
                            : Colors.grey.withOpacity(0.5),
                        size: 22,
                      ),
                    ),
                    onTap: () => {
                      if (DesktopSettingPage.tabKeys.isNotEmpty)
                        {
                          DesktopSettingPage.switch2page(
                              DesktopSettingPage.tabKeys[0])
                        }
                    },
                    onHover: (value) => _editHover.value = value,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  buildRightPane(BuildContext context) {
    return ConnectionPage();
  }

  buildIDBoard(BuildContext context) {
    final model = gFFI.serverModel;
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 11),
      height: 57,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            decoration: const BoxDecoration(color: MyTheme.accent),
          ).marginOnly(top: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 25,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate("ID"),
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.color
                                  ?.withOpacity(0.5)),
                        ).marginOnly(top: 5),
                        buildPopupMenu(context)
                      ],
                    ),
                  ),
                  Flexible(
                    child: GestureDetector(
                      onDoubleTap: () {
                        Clipboard.setData(
                            ClipboardData(text: model.serverId.text));
                        showToast(translate("Copied"));
                      },
                      child: TextFormField(
                        controller: model.serverId,
                        readOnly: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(top: 10, bottom: 10),
                        ),
                        style: TextStyle(
                          fontSize: 22,
                        ),
                      ).workaroundFreezeLinuxMint(),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPopupMenu(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    RxBool hover = false.obs;
    return InkWell(
      onTap: DesktopTabPage.onAddSetting,
      child: Tooltip(
        message: translate('Settings'),
        child: Obx(
          () => CircleAvatar(
            radius: 15,
            backgroundColor: hover.value
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).colorScheme.background,
            child: Icon(
              Icons.more_vert_outlined,
              size: 20,
              color: hover.value ? textColor : textColor?.withOpacity(0.5),
            ),
          ),
        ),
      ),
      onHover: (value) => hover.value = value,
    );
  }

  buildPasswordBoard(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: gFFI.serverModel,
        child: Consumer<ServerModel>(
          builder: (context, model, child) {
            return buildPasswordBoard2(context, model);
          },
        ));
  }

  buildPasswordBoard2(BuildContext context, ServerModel model) {
    RxBool refreshHover = false.obs;
    RxBool editHover = false.obs;
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    return Container(
      margin: EdgeInsets.only(left: 20.0, right: 16, top: 13, bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            height: 52,
            decoration: BoxDecoration(color: MyTheme.accent),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    translate("One-time Password"),
                    style: TextStyle(
                        fontSize: 14, color: textColor?.withOpacity(0.5)),
                    maxLines: 1,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onDoubleTap: () {
                            if (showOneTime) {
                              Clipboard.setData(
                                  ClipboardData(text: model.serverPasswd.text));
                              showToast(translate("Copied"));
                            }
                          },
                          child: TextFormField(
                            controller: model.serverPasswd,
                            readOnly: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.only(top: 14, bottom: 10),
                            ),
                            style: TextStyle(fontSize: 15),
                          ).workaroundFreezeLinuxMint(),
                        ),
                      ),
                      if (showOneTime)
                        AnimatedRotationWidget(
                          onPressed: () => bind.mainUpdateTemporaryPassword(),
                          child: Tooltip(
                            message: translate('Refresh Password'),
                            child: Obx(() => RotatedBox(
                                quarterTurns: 2,
                                child: Icon(
                                  Icons.refresh,
                                  color: refreshHover.value
                                      ? textColor
                                      : Color(0xFFDDDDDD),
                                  size: 22,
                                ))),
                          ),
                          onHover: (value) => refreshHover.value = value,
                        ).marginOnly(right: 8, top: 4),
                      if (!bind.isDisableSettings())
                        InkWell(
                          child: Tooltip(
                            message: translate('Change Password'),
                            child: Obx(
                              () => Icon(
                                Icons.edit,
                                color: editHover.value
                                    ? textColor
                                    : Color(0xFFDDDDDD),
                                size: 22,
                              ).marginOnly(right: 8, top: 4),
                            ),
                          ),
                          onTap: () => DesktopSettingPage.switch2page(
                              SettingsTabKey.safety),
                          onHover: (value) => editHover.value = value,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  buildTip(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return Padding(
      padding:
          const EdgeInsets.only(left: 20.0, right: 16, top: 16.0, bottom: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              if (!isOutgoingOnly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    translate("Your Desktop"),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 10.0,
          ),
          if (!isOutgoingOnly)
            Text(
              translate("desk_tip"),
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (isOutgoingOnly)
            Text(
              translate("outgoing_only_desk_tip"),
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget buildHelpCards(String updateUrl) {
    if (!bind.isCustomClient() &&
        updateUrl.isNotEmpty &&
        !isCardClosed &&
        bind.mainUriPrefixSync().contains('rustdesk')) {
      final isToUpdate = (isWindows || isMacOS) && bind.mainIsInstalled();
      String btnText = isToUpdate ? 'Update' : 'Download';
      GestureTapCallback onPressed = () async {
        final Uri url = Uri.parse('https://rustdesk.com/download');
        await launchUrl(url);
      };
      if (isToUpdate) {
        onPressed = () {
          handleUpdate(updateUrl);
        };
      }
      return buildInstallCard(
          "Status",
          "${translate("new-version-of-{${getAppDisplayName()}}-tip")} (${bind.mainGetNewVersion()}).",
          btnText,
          onPressed,
          closeButton: true,
          help: isToUpdate ? 'Changelog' : null,
          link: isToUpdate
              ? 'https://github.com/rustdesk/rustdesk/releases/tag/${bind.mainGetNewVersion()}'
              : null);
    }
    if (systemError.isNotEmpty) {
      return buildInstallCard("", systemError, "", () {});
    }

    if (isWindows && !bind.isDisableInstallation()) {
      if (!bind.mainIsInstalled()) {
        return buildInstallCard(
            "", bind.isOutgoingOnly() ? "" : "install_tip", "Install",
            () async {
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainGotoInstall();
        });
      } else if (bind.mainIsInstalledLowerVersion()) {
        return buildInstallCard(
            "Status", "Your installation is lower version.", "Click to upgrade",
            () async {
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainUpdateMe();
        });
      }
    } else if (isMacOS) {
      final isOutgoingOnly = bind.isOutgoingOnly();
      if (!(isOutgoingOnly || bind.mainIsCanScreenRecording(prompt: false))) {
        return buildInstallCard("Permissions", "config_screen", "Configure",
            () async {
          bind.mainIsCanScreenRecording(prompt: true);
          // macOS shows the request prompt only once per app, so later
          // presses would do nothing without opening the settings pane.
          launchUrl(Uri.parse(
              'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'));
          watchIsCanScreenRecording = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!isOutgoingOnly && !bind.mainIsProcessTrusted(prompt: false)) {
        return buildInstallCard("Permissions", "config_acc", "Configure",
            () async {
          bind.mainIsProcessTrusted(prompt: true);
          watchIsProcessTrust = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!bind.mainIsCanInputMonitoring(prompt: false)) {
        return buildInstallCard("Permissions", "config_input", "Configure",
            () async {
          bind.mainIsCanInputMonitoring(prompt: true);
          watchIsInputMonitoring = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!isOutgoingOnly &&
          !svcStopped.value &&
          bind.mainIsInstalled() &&
          !bind.mainIsInstalledDaemon(prompt: false)) {
        return buildInstallCard("", "install_daemon_tip", "Install", () async {
          bind.mainIsInstalledDaemon(prompt: true);
        });
      }
      //// Disable microphone configuration for macOS. We will request the permission when needed.
      // else if ((await osxCanRecordAudio() !=
      //     PermissionAuthorizeType.authorized)) {
      //   return buildInstallCard("Permissions", "config_microphone", "Configure",
      //       () async {
      //     osxRequestAudio();
      //     watchIsCanRecordAudio = true;
      //   });
      // }
    } else if (isLinux) {
      if (bind.isOutgoingOnly()) {
        return Container();
      }
      final LinuxCards = <Widget>[];
      if (bind.isSelinuxEnforcing()) {
        // Check is SELinux enforcing, but show user a tip of is SELinux enabled for simple.
        final keyShowSelinuxHelpTip = "show-selinux-help-tip";
        if (bind.mainGetLocalOption(key: keyShowSelinuxHelpTip) != 'N') {
          LinuxCards.add(buildInstallCard(
            "Warning",
            "selinux_tip",
            "",
            () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link:
                'https://rustdesk.com/docs/en/client/linux/#permissions-issue',
            closeButton: true,
            closeOption: keyShowSelinuxHelpTip,
          ));
        }
      }
      if (bind.mainCurrentIsWayland()) {
        LinuxCards.add(buildInstallCard(
            "Warning", "wayland_experiment_tip", "", () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link: 'https://rustdesk.com/docs/en/client/linux/#x11-required'));
      } else if (bind.mainIsLoginWayland()) {
        LinuxCards.add(buildInstallCard("Warning",
            "Login screen using Wayland is not supported", "", () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link: 'https://rustdesk.com/docs/en/client/linux/#login-screen'));
      }
      if (LinuxCards.isNotEmpty) {
        return Column(
          children: LinuxCards,
        );
      }
    }
    if (bind.isIncomingOnly()) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: () {
            SystemNavigator.pop(); // Close the application
            // https://github.com/flutter/flutter/issues/66631
            if (isWindows) {
              exit(0);
            }
          },
          child: Text(translate('Quit')),
        ),
      ).marginAll(14);
    }
    return Container();
  }

  Widget buildInstallCard(String title, String content, String btnText,
      GestureTapCallback onPressed,
      {double marginTop = 20.0,
      String? help,
      String? link,
      bool? closeButton,
      String? closeOption}) {
    if (bind.mainGetBuildinOption(key: kOptionHideHelpCards) == 'Y' &&
        content != 'install_daemon_tip') {
      return const SizedBox();
    }
    void closeCard() async {
      if (closeOption != null) {
        await bind.mainSetLocalOption(key: closeOption, value: 'N');
        if (bind.mainGetLocalOption(key: closeOption) == 'N') {
          setState(() {
            isCardClosed = true;
          });
        }
      } else {
        setState(() {
          isCardClosed = true;
        });
      }
    }

    return Stack(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(
              0, marginTop, 0, bind.isIncomingOnly() ? marginTop : 0),
          child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF29387A),
                      Color(0xFF306EC1),
                    ],
                  )),
              padding: const EdgeInsets.all(20),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (title.isNotEmpty
                          ? <Widget>[
                              Center(
                                  child: Text(
                                translate(title),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ).marginOnly(bottom: 6)),
                            ]
                          : <Widget>[]) +
                      <Widget>[
                        if (content.isNotEmpty)
                          Text(
                            translate(content),
                            style: TextStyle(
                                height: 1.5,
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 13),
                          ).marginOnly(bottom: 20)
                      ] +
                      (btnText.isNotEmpty
                          ? <Widget>[
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FixedWidthButton(
                                      width: 150,
                                      padding: 8,
                                      isOutline: true,
                                      text: translate(btnText),
                                      textColor: Colors.white,
                                      borderColor: Colors.white,
                                      textSize: 20,
                                      radius: 10,
                                      onTap: onPressed,
                                    )
                                  ])
                            ]
                          : <Widget>[]) +
                      (help != null
                          ? <Widget>[
                              Center(
                                  child: InkWell(
                                      onTap: () async =>
                                          await launchUrl(Uri.parse(link!)),
                                      child: Text(
                                        translate(help),
                                        style: TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            color: Colors.white,
                                            fontSize: 12),
                                      )).marginOnly(top: 6)),
                            ]
                          : <Widget>[]))),
        ),
        if (closeButton != null && closeButton == true)
          Positioned(
            top: 18,
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: closeCard,
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(const Duration(seconds: 1), () async {
      await gFFI.serverModel.fetchID();
      final error = await bind.mainGetError();
      if (systemError != error) {
        systemError = error;
        setState(() {});
      }
      final v = await mainGetBoolOption(kOptionStopService);
      if (v != svcStopped.value) {
        svcStopped.value = v;
        setState(() {});
      }
      if (watchIsCanScreenRecording) {
        if (bind.mainIsCanScreenRecording(prompt: false)) {
          watchIsCanScreenRecording = false;
          setState(() {});
        }
      }
      if (watchIsProcessTrust) {
        if (bind.mainIsProcessTrusted(prompt: false)) {
          watchIsProcessTrust = false;
          setState(() {});
        }
      }
      if (watchIsInputMonitoring) {
        if (bind.mainIsCanInputMonitoring(prompt: false)) {
          watchIsInputMonitoring = false;
          // Do not notify for now.
          // Monitoring may not take effect until the process is restarted.
          // rustDeskWinManager.call(
          //     WindowType.RemoteDesktop, kWindowDisableGrabKeyboard, '');
          setState(() {});
        }
      }
      if (watchIsCanRecordAudio) {
        if (isMacOS) {
          Future.microtask(() async {
            if ((await osxCanRecordAudio() ==
                PermissionAuthorizeType.authorized)) {
              watchIsCanRecordAudio = false;
              setState(() {});
            }
          });
        } else {
          watchIsCanRecordAudio = false;
          setState(() {});
        }
      }
    });
    Get.put<RxBool>(svcStopped, tag: 'stop-service');
    rustDeskWinManager.registerActiveWindowListener(onActiveWindowChanged);

    screenToMap(window_size.Screen screen) => {
          'frame': {
            'l': screen.frame.left,
            't': screen.frame.top,
            'r': screen.frame.right,
            'b': screen.frame.bottom,
          },
          'visibleFrame': {
            'l': screen.visibleFrame.left,
            't': screen.visibleFrame.top,
            'r': screen.visibleFrame.right,
            'b': screen.visibleFrame.bottom,
          },
          'scaleFactor': screen.scaleFactor,
        };

    bool isChattyMethod(String methodName) {
      switch (methodName) {
        case kWindowBumpMouse: return true;
      }

      return false;
    }

    rustDeskWinManager.setMethodHandler((call, fromWindowId) async {
      if (!isChattyMethod(call.method)) {
        debugPrint(
          "[Main] call ${call.method} with args ${call.arguments} from window $fromWindowId");
      }
      if (call.method == kWindowMainWindowOnTop) {
        windowOnTop(null);
      } else if (call.method == kWindowRefreshCurrentUser) {
        gFFI.userModel.refreshCurrentUser();
      } else if (call.method == kWindowGetScreenList) {
        return jsonEncode(
            (await window_size.getScreenList()).map(screenToMap).toList());
      } else if (call.method == kWindowActionRebuild) {
        reloadCurrentWindow();
      } else if (call.method == kWindowEventShow) {
        await rustDeskWinManager.registerActiveWindow(call.arguments["id"]);
      } else if (call.method == kWindowEventHide) {
        await rustDeskWinManager.unregisterActiveWindow(call.arguments['id']);
      } else if (call.method == kWindowConnect) {
        await connectMainDesktop(
          call.arguments['id'],
          isFileTransfer: call.arguments['isFileTransfer'],
          isViewCamera: call.arguments['isViewCamera'],
          isTerminal: call.arguments['isTerminal'],
          isTcpTunneling: call.arguments['isTcpTunneling'],
          isRDP: call.arguments['isRDP'],
          password: call.arguments['password'],
          forceRelay: call.arguments['forceRelay'],
          connToken: call.arguments['connToken'],
        );
      } else if (call.method == kWindowBumpMouse) {
        return RdPlatformChannel.instance.bumpMouse(
          dx: call.arguments['dx'],
          dy: call.arguments['dy']);
      } else if (call.method == kWindowEventMoveTabToNewWindow) {
        final args = call.arguments.split(',');
        int? windowId;
        try {
          windowId = int.parse(args[0]);
        } catch (e) {
          debugPrint("Failed to parse window id '${call.arguments}': $e");
        }
        WindowType? windowType;
        try {
          windowType = WindowType.values.byName(args[3]);
        } catch (e) {
          debugPrint("Failed to parse window type '${call.arguments}': $e");
        }
        if (windowId != null && windowType != null) {
          await rustDeskWinManager.moveTabToNewWindow(
              windowId, args[1], args[2], windowType);
        }
      } else if (call.method == kWindowEventOpenMonitorSession) {
        final args = jsonDecode(call.arguments);
        final windowId = args['window_id'] as int;
        final peerId = args['peer_id'] as String;
        final display = args['display'] as int;
        final displayCount = args['display_count'] as int;
        final windowType = args['window_type'] as int;
        final screenRect = parseParamScreenRect(args);
        await rustDeskWinManager.openMonitorSession(
            windowId, peerId, display, displayCount, screenRect, windowType);
      } else if (call.method == kWindowEventRemoteWindowCoords) {
        final windowId = int.tryParse(call.arguments);
        if (windowId != null) {
          return jsonEncode(
              await rustDeskWinManager.getOtherRemoteWindowCoords(windowId));
        }
      }
    });
    _uniLinksSubscription = listenUniLinks();

    if (bind.isIncomingOnly()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWindowSize();
      });
    }
    WidgetsBinding.instance.addObserver(this);
  }

  _updateWindowSize() {
    RenderObject? renderObject = _childKey.currentContext?.findRenderObject();
    if (renderObject == null) {
      return;
    }
    if (renderObject is RenderBox) {
      final size = renderObject.size;
      if (size != imcomingOnlyHomeSize) {
        imcomingOnlyHomeSize = size;
        windowManager.setSize(getIncomingOnlyHomeSize());
      }
    }
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    Get.delete<RxBool>(tag: 'stop-service');
    _updateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      shouldBeBlocked(_block, canBeBlocked);
    }
  }
}

void setPasswordDialog({VoidCallback? notEmptyCallback}) async {
  final p0 = TextEditingController(text: "");
  final p1 = TextEditingController(text: "");
  var errMsg0 = "";
  var errMsg1 = "";
  final localPasswordSet =
      (await bind.mainGetCommon(key: "local-permanent-password-set")) == "true";
  final permanentPasswordSet =
      (await bind.mainGetCommon(key: "permanent-password-set")) == "true";
  final presetPassword = permanentPasswordSet && !localPasswordSet;
  var canSubmit = false;
  final RxString rxPass = "".obs;
  final rules = [
    DigitValidationRule(),
    UppercaseValidationRule(),
    LowercaseValidationRule(),
    // SpecialCharacterValidationRule(),
    MinCharactersValidationRule(8),
  ];
  final maxLength = bind.mainMaxEncryptLen();
  final statusTip = localPasswordSet
      ? translate('password-hidden-tip')
      : (presetPassword ? translate('preset-password-in-use-tip') : '');
  final showStatusTipOnMobile =
      statusTip.isNotEmpty && !isDesktop && !isWebDesktop;

  gFFI.dialogManager.show((setState, close, context) {
    updateCanSubmit() {
      canSubmit = p0.text.trim().isNotEmpty || p1.text.trim().isNotEmpty;
    }

    submit() async {
      if (!canSubmit) {
        return;
      }
      setState(() {
        errMsg0 = "";
        errMsg1 = "";
      });
      final pass = p0.text.trim();
      if (pass.isNotEmpty) {
        final Iterable violations = rules.where((r) => !r.validate(pass));
        if (violations.isNotEmpty) {
          setState(() {
            errMsg0 =
                '${translate('Prompt')}: ${violations.map((r) => r.name).join(', ')}';
          });
          return;
        }
      }
      if (p1.text.trim() != pass) {
        setState(() {
          errMsg1 =
              '${translate('Prompt')}: ${translate("The confirmation is not identical.")}';
        });
        return;
      }
      final ok = await bind.mainSetPermanentPasswordWithResult(password: pass);
      if (!ok) {
        setState(() {
          errMsg0 = '${translate('Prompt')}: ${translate("Failed")}';
        });
        return;
      }
      if (pass.isNotEmpty) {
        notEmptyCallback?.call();
      }
      close();
    }

    return CustomAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key, color: MyTheme.accent),
          Text(translate("Set Password")).paddingOnly(left: 10),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 6.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: translate('Password'),
                        errorText: errMsg0.isNotEmpty ? errMsg0 : null),
                    controller: p0,
                    autofocus: true,
                    onChanged: (value) {
                      rxPass.value = value.trim();
                      setState(() {
                        errMsg0 = '';
                        updateCanSubmit();
                      });
                    },
                    maxLength: maxLength,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: PasswordStrengthIndicator(password: rxPass)),
              ],
            ).marginOnly(top: 2, bottom: showStatusTipOnMobile ? 2 : 8),
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 8.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: translate('Confirmation'),
                        errorText: errMsg1.isNotEmpty ? errMsg1 : null),
                    controller: p1,
                    onChanged: (value) {
                      setState(() {
                        errMsg1 = '';
                        updateCanSubmit();
                      });
                    },
                    maxLength: maxLength,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ),
            if (statusTip.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.info, color: Colors.amber, size: 18)
                      .marginOnly(right: 6),
                  Expanded(
                      child: Text(
                    statusTip,
                    style: const TextStyle(fontSize: 13, height: 1.1),
                  ))
                ],
              ).marginOnly(top: 6, bottom: 2),
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 8.0,
            ),
            Obx(() => Wrap(
                  runSpacing: showStatusTipOnMobile ? 2.0 : 8.0,
                  spacing: 4,
                  children: rules.map((e) {
                    var checked = e.validate(rxPass.value.trim());
                    return Chip(
                        label: Text(
                          e.name,
                          style: TextStyle(
                              color: checked
                                  ? const Color(0xFF0A9471)
                                  : Color.fromARGB(255, 198, 86, 157)),
                        ),
                        backgroundColor: checked
                            ? const Color(0xFFD0F7ED)
                            : Color.fromARGB(255, 247, 205, 232));
                  }).toList(),
                ))
          ],
        ),
      ),
      actions: (() {
        final cancelButton = dialogButton(
          "Cancel",
          icon: Icon(Icons.close_rounded),
          onPressed: close,
          isOutline: true,
        );
        final removeButton = dialogButton(
          "Remove",
          icon: Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            setState(() {
              errMsg0 = "";
              errMsg1 = "";
            });
            final ok =
                await bind.mainSetPermanentPasswordWithResult(password: "");
            if (!ok) {
              setState(() {
                errMsg0 = '${translate('Prompt')}: ${translate("Failed")}';
              });
              return;
            }
            close();
          },
          buttonStyle: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(Colors.red)),
        );
        final okButton = dialogButton(
          "OK",
          icon: Icon(Icons.done_rounded),
          onPressed: canSubmit ? submit : null,
        );
        if (!isDesktop && !isWebDesktop && localPasswordSet) {
          return [
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cancelButton,
                    const SizedBox(width: 4),
                    removeButton,
                    const SizedBox(width: 4),
                    okButton,
                  ],
                ),
              ),
            ),
          ];
        }
        return [
          cancelButton,
          if (localPasswordSet) removeButton,
          okButton,
        ];
      })(),
      onSubmit: canSubmit ? submit : null,
      onCancel: close,
    );
  });
}

class _DeviceStatusCard extends StatefulWidget {
  const _DeviceStatusCard({Key? key}) : super(key: key);

  @override
  State<_DeviceStatusCard> createState() => _DeviceStatusCardState();
}

class _DeviceStatusCardState extends State<_DeviceStatusCard> {
  List<String> _ips = const [];
  bool _serviceInstalled = false;
  String _networkCategory = '';
  bool _portListening = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final ips = await NetworkTools.localIPv4s();
    final installed = bind.mainIsInstalled();
    final category = await NetworkTools.networkCategory();
    final listening = await NetworkTools.portListening(NetworkTools.directPort);
    if (!mounted) return;
    setState(() {
      _ips = ips;
      _serviceInstalled = installed;
      _networkCategory = category;
      _portListening = listening;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);
    final isPublic = _networkCategory.toLowerCase() == 'public';
    final address = _ips.isNotEmpty
        ? '${_ips.first}:${NetworkTools.directPort}'
        : 'não detectado';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B2B) : const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _row(
            icon: Icons.lan_rounded,
            label: 'IP local',
            value: address,
            trailing: InkWell(
              onTap: () {
                if (_ips.isEmpty) return;
                Clipboard.setData(ClipboardData(text: address));
                showToast(translate('Copied'));
              },
              child: Tooltip(
                message: 'Copiar',
                child: Icon(Icons.copy_rounded, size: 15, color: muted),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _row(
            icon: Icons.miscellaneous_services_rounded,
            label: 'Serviço',
            value: _serviceInstalled ? 'Ativo' : 'Não instalado',
            valueColor: _serviceInstalled ? Colors.green : Colors.orange,
            trailing: TextButton(
              onPressed: () async {
                await start_service(!_serviceInstalled);
                await _refresh();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11.5),
              ),
              child: Text(_serviceInstalled ? 'Desinstalar' : 'Instalar'),
            ),
          ),
          const SizedBox(height: 4),
          _row(
            icon: Icons.wifi_rounded,
            label: 'Rede',
            value: _networkCategory.isEmpty
                ? (_portListening ? 'Privada' : 'Desconhecido')
                : _networkCategory,
            valueColor: isPublic ? Colors.orange : null,
            trailing: TextButton(
              onPressed: () async {
                final ok = await NetworkTools.fixFirewall();
                showToast(ok
                    ? 'Regras aplicadas. Aceite o UAC, se aparecer.'
                    : 'Não foi possível aplicar as regras');
                await _refresh();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11.5),
              ),
              child: Text('Aplicar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
    Color? valueColor,
  }) {
    final muted =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);
    return Row(
      children: [
        Icon(icon, size: 15, color: MyTheme.accent),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 11.5, color: muted)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? (muted ?? Colors.black87)),
          ),
        ),
        if (trailing != null)
          SizedBox(
            height: 28,
            child: trailing,
          ),
      ],
    );
  }
}
