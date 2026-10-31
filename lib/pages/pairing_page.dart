import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../db/database.dart';
import '../models/models.dart';
import 'parent_page.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});
  @override
  State<PairingPage> createState() => PairingPageState();
}

class PairingPageState extends State<PairingPage> {
  List<Account> _accounts = [];
  String _currentAccount = '';
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() { super.initState(); _loadAccounts(); }
  Future<void> loadData() async { await _loadAccounts(); }

  Future<void> _loadAccounts() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('accounts');
    if (!mounted) return;
    setState(() {
      _accounts = rows.map(Account.fromMap).toList();
      if (_accounts.isNotEmpty) { if (!_accounts.any((a) => a.name == _currentAccount)) _currentAccount = _accounts.first.name; } else _currentAccount = '';
      _load();
    });
  }

  Future<void> _load() async {
    if (_currentAccount.isEmpty) { setState(() => _groups = []); return; }
    final db = await AppDatabase.instance.db;
    final pairings = await db.query('pairings', where: 'account = ?', whereArgs: [_currentAccount]);
    final List<Map<String, dynamic>> loaded = [];
    for (final p in pairings) {
      final motherRows = await db.query('parents', where: 'id=?', whereArgs: [p['mother_id']]);
      if (motherRows.isEmpty) continue;
      final fatherRows = await db.rawQuery('SELECT p.* FROM parents p JOIN pairing_fathers pf ON p.id = pf.father_id WHERE pf.pairing_id = ?', [p['id']]);
      final fathers = fatherRows.map(Parent.fromMap).toList();
      final mother = Parent.fromMap(motherRows.first);
      
      Set<String> natures = {mother.nature ?? '未知', ...fathers.map((f) => f.nature ?? '未知')};
      bool isMixed = natures.length >= 3;

      final eggStats = await db.rawQuery('SELECT status, count(*) as c FROM eggs WHERE pairing_id = ? GROUP BY status', [p['id']]);
      int inStock = 0, sold = 0;
      for (var stat in eggStats) { if (stat['status'] == '在库') inStock = stat['c'] as int; if (stat['status'] == '已售出') sold = stat['c'] as int; }
      
      loaded.add({'id': p['id'], 'mother': mother, 'fathers': fathers, 'inStock': inStock, 'sold': sold, 'isMixed': isMixed, 'nestType': p['nest_type'] ?? '普窝'});
    }
    if (!mounted) return;
    setState(() => _groups = loaded);
  }

  // 管理账号
  void _manageAccount(Account acc) {
    final nameCtrl = TextEditingController(text: acc.name);
    final idCtrl = TextEditingController(text: acc.accountId ?? '');

    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('管理账号'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '账号名称')),
        const SizedBox(height: 12),
        TextField(controller: idCtrl, decoration: const InputDecoration(labelText: '账号ID / 备注')),
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(context: context, builder: (c2) => AlertDialog(
              title: Text('危险操作'), content: Text('确定删除账号 "${acc.name}" 吗？\n该账号下的所有数据都将被清除！'), 
              actions: [TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c2, true), child: const Text('确定删除', style: TextStyle(color: Colors.red)))]
            ));
            if (confirm == true) {
              final db = await AppDatabase.instance.db;
              await db.transaction((txn) async {
                final eggs = await txn.query('eggs', where: 'account = ? AND status != ?', whereArgs: [acc.name, '已售出']);
                for (var e in eggs) { await txn.update('eggs', {'father_id': null, 'mother_id': null}, where: 'id = ?', whereArgs: [e['id']]); }
                await txn.delete('parents', where: 'account = ?', whereArgs: [acc.name]);
                await txn.delete('pairings', where: 'account = ?', whereArgs: [acc.name]);
                await txn.delete('production_lines', where: 'account_name = ?', whereArgs: [acc.name]);
                await txn.delete('accounts', where: 'id = ?', whereArgs: [acc.id]);
              });
              if (mounted) Navigator.pop(c);
              _loadAccounts();
            }
          }, child: const Text('删除账号', style: TextStyle(color: Colors.red))
        ),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.isEmpty) return;
            final db = await AppDatabase.instance.db;
            final oldName = acc.name;
            final newName = nameCtrl.text;
            await db.transaction((txn) async {
              await txn.update('accounts', {'name': newName, 'account_id': idCtrl.text}, where: 'id = ?', whereArgs: [acc.id]);
              if (oldName != newName) {
                 await txn.update('parents', {'account': newName}, where: 'account = ?', whereArgs: [oldName]);
                 await txn.update('pairings', {'account': newName}, where: 'account = ?', whereArgs: [oldName]);
                 await txn.update('production_lines', {'account_name': newName}, where: 'account_name = ?', whereArgs: [oldName]);
                 await txn.update('eggs', {'account': newName}, where: 'account = ?', whereArgs: [oldName]);
              }
            });
            if (mounted) Navigator.pop(c);
            _loadAccounts();
          }, child: const Text('保存修改')
        ),
      ],
    ));
  }

  void _deleteGroup(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('确认删除配对组？'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定'))],
    ));
    if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('pairings', where: 'id = ?', whereArgs: [id]); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 60, child: ListView(scrollDirection: Axis.horizontal, children: _accounts.map((acc) => GestureDetector(
            onTap: () { setState(() => _currentAccount = acc.name); _load(); },
            onLongPress: () => _manageAccount(acc),
            onSecondaryTap: () => _manageAccount(acc),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 150, minWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center, 
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _currentAccount == acc.name ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))), 
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(acc.name, style: TextStyle(fontWeight: FontWeight.bold, color: _currentAccount == acc.name ? Theme.of(context).colorScheme.primary : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (acc.accountId != null && acc.accountId!.isNotEmpty)
                    Text(acc.accountId!, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          )).toList())),
          Expanded(child: _currentAccount.isEmpty ? const Center(child: Text('请先添加账号')) : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _groups.length,
            itemBuilder: (context, i) {
              final g = _groups[i];
              return GestureDetector(
                onSecondaryTap: () => _deleteGroup(g['id']),
                child: Slidable(
                  key: ValueKey(g['id']),
                  extentRatio: 0.25, 
                  endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteGroup(g['id']), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            Text('第 ${i + 1} 组  ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (g['isMixed']) const Text('混窝 ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            if (g['nestType'] == '绿窝') Image.asset('assets/nest_types/green_nest.png', width: 18, height: 18),
                          ]),
                          Text('在库: ${g['inStock']} / 已售出: ${g['sold']}', style: const TextStyle(fontSize: 12, color: Colors.grey))
                        ]),
                        const Divider(),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: buildParentCard(context, g['mother'], true)),
                          const SizedBox(width: 8),
                          Expanded(child: Column(children: (g['fathers'] as List<Parent>).map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: buildParentCard(context, f, false))).toList())),
                        ]),
                      ]),
                    ),
                  ),
                ),
              );
            },
          )),
        ],
      ),
      floatingActionButton: _currentAccount.isEmpty ? null : Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => PairingEditPage(account: _currentAccount))); _load(); }, child: const Icon(Icons.add)),
      ),
    );
  }
}

// PairingEditPage 保持你上次替换的代码即可
