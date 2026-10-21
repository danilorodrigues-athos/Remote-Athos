import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:url_launcher/url_launcher.dart';

const kUpdateFolderOptionKey = 'no-update-folder';

class UpdatePackage {
  const UpdatePackage({required this.version, this.file, this.notes});

  final String version;
  final String? file;
  final String? notes;
}

/// Reads the update manifest from a shared folder. The folder is a local
/// option so a technician can point every machine at the same network share.
class UpdateChecker {
  static const _manifestNames = ['no-version.json', 'version.json'];

  static String get folder =>
      bind.mainGetLocalOption(key: kUpdateFolderOptionKey);

  static Future<void> setFolder(String path) async {
    await bind.mainSetLocalOption(key: kUpdateFolderOptionKey, value: path);
  }

  static Future<UpdatePackage?> find([String? overrideFolder]) async {
    final dir = (overrideFolder ?? folder).trim();
    if (dir.isEmpty) return null;
    for (final name in _manifestNames) {
      final file = File('$dir${Platform.pathSeparator}$name');
      if (!await file.exists()) continue;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) continue;
      final version = (decoded['version'] ?? '').toString().trim();
      if (version.isEmpty) continue;
      return UpdatePackage(
        version: version,
        file: decoded['file']?.toString(),
        notes: decoded['notes']?.toString(),
      );
    }
    return null;
  }
}

Future<void> showUpdateDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (_) => const _UpdateDialog(),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  late final TextEditingController _folderController;
  String _currentVersion = '';
  String _status = '';
  UpdatePackage? _found;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _folderController = TextEditingController(text: UpdateChecker.folder);
    _loadCurrentVersion();
  }

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    final version = await bind.mainGetVersion();
    if (!mounted) return;
    setState(() => _currentVersion = version);
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pasta de atualizações',
    );
    if (dir == null) return;
    await UpdateChecker.setFolder(dir);
    if (!mounted) return;
    setState(() {
      _folderController.text = dir;
      _found = null;
      _status = '';
    });
  }

  Future<void> _check() async {
    final dir = _folderController.text.trim();
    if (dir.isEmpty) {
      setState(() => _status = 'Escolha a pasta compartilhada primeiro.');
      return;
    }
    setState(() {
      _checking = true;
      _found = null;
      _status = '';
    });
    try {
      final found = await UpdateChecker.find(dir);
      final current = await bind.mainGetVersion();
      if (!mounted) return;
      setState(() {
        _currentVersion = current;
        _found = found;
        if (found == null) {
          _status = 'Nenhum pacote encontrado. Coloque o arquivo '
              'no-version.json na pasta.';
        } else if (versionCmp(found.version, current) > 0) {
          _status = 'Atualização disponível: ${found.version}';
        } else {
          _status = 'Você já está na versão mais recente ($current).';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Falha ao verificar: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openFolder() async {
    final dir = _folderController.text.trim();
    if (dir.isEmpty) return;
    if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else {
      await launchUrl(Uri.file(dir));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    final hasUpdate = _found != null &&
        _currentVersion.isNotEmpty &&
        versionCmp(_found!.version, _currentVersion) > 0;
    return AlertDialog(
      title: const Text('Atualizações'),
      content: SizedBox(
        width: 470,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pacotes do NÓ em uma pasta da rede local.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _folderController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Pasta de atualizações',
                hintText: r'\\servidor\atualizacoes',
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: 'Escolher pasta',
                  onPressed: _pickFolder,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: muted),
                const SizedBox(width: 6),
                Text(
                  _currentVersion.isEmpty
                      ? 'Versão atual: ...'
                      : 'Versão atual: $_currentVersion',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasUpdate
                      ? MyTheme.accent.withOpacity(0.10)
                      : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            hasUpdate ? FontWeight.w600 : FontWeight.w400,
                        color: hasUpdate ? MyTheme.accent : null,
                      ),
                    ),
                    if (hasUpdate && (_found!.file ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pacote: ${_found!.file}',
                        style: TextStyle(fontSize: 11.5, color: muted),
                      ),
                    ],
                    if (hasUpdate && (_found!.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _found!.notes!,
                        style: TextStyle(fontSize: 11.5, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _openFolder,
          child: const Text('Abrir pasta'),
        ),
        TextButton(
          onPressed: _checking ? null : _check,
          child: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verificar agora'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
