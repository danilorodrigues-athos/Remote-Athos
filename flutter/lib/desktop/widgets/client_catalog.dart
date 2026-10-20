import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const kClientsCatalogOptionKey = 'athos-clients-catalog';

class CatalogMachine {
  CatalogMachine({required this.id, this.alias = '', this.password = ''});

  String id;
  String alias;
  String password;

  Map<String, dynamic> toJson() =>
      {'id': id, 'alias': alias, 'password': password};

  factory CatalogMachine.fromJson(Map<String, dynamic> json) => CatalogMachine(
        id: (json['id'] ?? '').toString(),
        alias: (json['alias'] ?? '').toString(),
        password: (json['password'] ?? '').toString(),
      );
}

class CatalogClient {
  CatalogClient({
    required this.id,
    required this.name,
    this.note = '',
    List<CatalogMachine>? machines,
  }) : machines = machines ?? <CatalogMachine>[];

  String id;
  String name;
  String note;
  final List<CatalogMachine> machines;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'note': note,
        'machines': machines.map((e) => e.toJson()).toList(),
      };

  factory CatalogClient.fromJson(Map<String, dynamic> json) => CatalogClient(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
        machines: (json['machines'] is List)
            ? (json['machines'] as List)
                .whereType<Map>()
                .map((e) => CatalogMachine.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : <CatalogMachine>[],
      );
}

class ClientCatalog {
  final List<CatalogClient> clients = <CatalogClient>[];

  void load() {
    clients.clear();
    final raw = bind.mainGetLocalOption(key: kClientsCatalogOptionKey);
    if (raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['clients'] is List) {
        for (final entry in data['clients'] as List) {
          if (entry is Map) {
            clients.add(
                CatalogClient.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
      }
    } catch (e) {
      debugPrint('load clients catalog failed: $e');
    }
  }

  Future<void> save() async {
    await bind.mainSetLocalOption(
      key: kClientsCatalogOptionKey,
      value: jsonEncode({
        'version': 1,
        'clients': clients.map((e) => e.toJson()).toList(),
      }),
    );
  }

  int get machineCount =>
      clients.fold(0, (sum, client) => sum + client.machines.length);
}

class ClientsCatalogView extends StatefulWidget {
  const ClientsCatalogView({Key? key}) : super(key: key);

  @override
  State<ClientsCatalogView> createState() => _ClientsCatalogViewState();
}

class _ClientsCatalogViewState extends State<ClientsCatalogView> {
  final ClientCatalog catalog = ClientCatalog();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardColor => _isDark ? const Color(0xFF1A1F2E) : Colors.white;
  Color get _borderColor =>
      _isDark ? const Color(0xFF24252B) : const Color(0xFFE1E1E1);
  Color get _fieldColor =>
      _isDark ? const Color(0xFF232A3A) : const Color(0xFFF3F5F9);
  Color? get _muted =>
      Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.55);

  @override
  void initState() {
    super.initState();
    catalog.load();
  }

  void _persist() {
    catalog.save().catchError((e) {
      debugPrint('save clients catalog failed: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          if (catalog.clients.isEmpty)
            _buildEmpty(context)
          else
            ...catalog.clients.map(_buildClientCard),
          if (catalog.clients.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: _muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'As senhas ficam salvas apenas neste computador.',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MyTheme.accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.groups_rounded, size: 22, color: MyTheme.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Clientes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                '${catalog.clients.length} ${catalog.clients.length == 1 ? 'cliente' : 'clientes'}'
                ' · ${catalog.machineCount} ${catalog.machineCount == 1 ? 'máquina' : 'máquinas'}',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () => _editClient(null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Novo cliente'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 46, color: _muted),
          const SizedBox(height: 12),
          const Text(
            'Nenhum cliente cadastrado',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Cadastre o cliente e adicione as máquinas pelo ID de cada uma.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _editClient(null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Cadastrar cliente'),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(CatalogClient client) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: MyTheme.accent.withOpacity(0.14),
                child: Text(
                  _initials(client.name),
                  style: TextStyle(
                    color: MyTheme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      client.note.isNotEmpty
                          ? client.note
                          : '${client.machines.length} ${client.machines.length == 1 ? 'máquina' : 'máquinas'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _editMachine(client, null),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Máquina'),
                style: TextButton.styleFrom(
                  foregroundColor: MyTheme.accent,
                  textStyle: const TextStyle(fontSize: 12.5),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '',
                icon: Icon(Icons.more_vert_rounded, size: 18, color: _muted),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editClient(client);
                  } else if (value == 'delete') {
                    _deleteClient(client);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(translate('Edit')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(translate('Remove')),
                  ),
                ],
              ),
            ],
          ),
          if (client.machines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2, bottom: 2),
              child: Text(
                'Nenhuma máquina. Use "+ Máquina" para cadastrar pelo ID.',
                style: TextStyle(fontSize: 11.5, color: _muted),
              ),
            )
          else
            ...client.machines.map((m) => _buildMachineRow(client, m)),
        ],
      ),
    );
  }

  Widget _buildMachineRow(CatalogClient client, CatalogMachine machine) {
    final alias = machine.alias.trim();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.desktop_windows_rounded,
              size: 18, color: MyTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alias.isEmpty ? formatID(machine.id) : alias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  formatID(machine.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
          if (machine.password.isNotEmpty)
            Tooltip(
              message: 'Senha salva',
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.key_rounded, size: 15, color: _muted),
              ),
            ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _connect(machine),
              child: Text(translate('Connect')),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '',
            icon: Icon(Icons.more_vert_rounded, size: 17, color: _muted),
            onSelected: (value) {
              if (value == 'edit') {
                _editMachine(client, machine);
              } else if (value == 'delete') {
                _deleteMachine(client, machine);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(translate('Edit')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(translate('Remove')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  void _connect(CatalogMachine machine) {
    final password = machine.password.trim();
    connect(
      context,
      machine.id.trim(),
      password: password.isEmpty ? null : password,
    );
  }

  void _editClient(CatalogClient? client) {
    final nameController = TextEditingController(text: client?.name ?? '');
    final noteController = TextEditingController(text: client?.note ?? '');
    gFFI.dialogManager.show((setState, close, context) {
      void submit() {
        final name = nameController.text.trim();
        if (name.isEmpty) {
          setState(() {});
          return;
        }
        if (client == null) {
          catalog.clients.add(CatalogClient(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            note: noteController.text.trim(),
          ));
        } else {
          client.name = name;
          client.note = noteController.text.trim();
        }
        _persist();
        this.setState(() {});
        close();
      }

      return CustomAlertDialog(
        title: Text(client == null ? 'Novo cliente' : 'Editar cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration:
                  const InputDecoration(labelText: 'Observações (opcional)'),
              onSubmitted: (_) => submit(),
            ),
          ],
        ),
        actions: [
          dialogButton('Cancel', onPressed: close, isOutline: true),
          dialogButton('Save', onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }

  void _editMachine(CatalogClient client, CatalogMachine? machine) {
    final idController = TextEditingController(text: machine?.id ?? '');
    final aliasController = TextEditingController(text: machine?.alias ?? '');
    final passwordController =
        TextEditingController(text: machine?.password ?? '');
    var passwordVisible = false;
    String? error;
    gFFI.dialogManager.show((setState, close, context) {
      void submit() {
        final id = idController.text.trim();
        if (id.isEmpty) {
          setState(() => error = 'Informe o ID ou IP da máquina');
          return;
        }
        final duplicated = client.machines
            .any((e) => e.id == id && !identical(e, machine));
        if (duplicated) {
          setState(() => error = 'Esta máquina já está neste cliente');
          return;
        }
        if (machine == null) {
          client.machines.add(CatalogMachine(
            id: id,
            alias: aliasController.text.trim(),
            password: passwordController.text,
          ));
        } else {
          machine.id = id;
          machine.alias = aliasController.text.trim();
          machine.password = passwordController.text;
        }
        _persist();
        this.setState(() {});
        close();
      }

      return CustomAlertDialog(
        title: Text(machine == null ? 'Adicionar máquina' : 'Editar máquina'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              client.name,
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: idController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'ID ou IP',
                errorText: error,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: aliasController,
              decoration:
                  const InputDecoration(labelText: 'Apelido (ex.: Recepção)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: !passwordVisible,
              decoration: InputDecoration(
                labelText: 'Senha (opcional)',
                suffixIcon: IconButton(
                  icon: Icon(
                    passwordVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => passwordVisible = !passwordVisible);
                  },
                ),
              ),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 8),
            Text(
              'Com a senha salva, a conexão entra direto.',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
        actions: [
          dialogButton('Cancel', onPressed: close, isOutline: true),
          dialogButton('Save', onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }

  void _deleteClient(CatalogClient client) {
    gFFI.dialogManager.show((setState, close, context) {
      void remove() {
        catalog.clients.remove(client);
        _persist();
        this.setState(() {});
        close();
      }

      return CustomAlertDialog(
        title: Text(translate('Remove')),
        content: Text(
          'Remover o cliente "${client.name}" e suas ${client.machines.length} máquinas?',
        ),
        actions: [
          dialogButton('Cancel', onPressed: close, isOutline: true),
          dialogButton('Remove', onPressed: remove),
        ],
        onSubmit: remove,
        onCancel: close,
      );
    });
  }

  void _deleteMachine(CatalogClient client, CatalogMachine machine) {
    client.machines.remove(machine);
    _persist();
    setState(() {});
  }
}
