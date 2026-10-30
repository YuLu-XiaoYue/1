import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../db/database.dart';
import '../models/models.dart';
import 'parent_page.dart'; // 引入卡片组件

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

  // 暴露刷新方法，供主框架调用
  Future<void> loadData() async {
    await _loadAccounts();
  }

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
      final eggStats = await db.rawQuery('SELECT status, count(*) as c FROM eggs WHERE father_id IN (SELECT father_id FROM pairing_fathers WHERE pairing_id = ?) AND mother_id = ? GROUP BY status', [p['id'], p['mother_id']]);
      int inStock = 0, sold = 0;
      for (var stat in eggStats) { if (stat['status'] == '在库') inStock = stat['c'] as int; if (stat['status'] == '已售出') sold = stat['c'] as int; }
      loaded.add({'id': p['id'], 'mother': Parent.fromMap(motherRows.first), 'fathers': fatherRows.map(Parent.fromMap).toList(), 'inStock': inStock, 'sold': sold});
    }
    if (!mounted) return;
    setState(() => _groups = loaded);
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
          SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, children: _accounts.map((acc) => InkWell(
            onTap: () { setState(() => _currentAccount = acc.name); _load(); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 24), alignment: Alignment.center, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _currentAccount == acc.name ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))), child: Text(acc.name, style: TextStyle(fontWeight: FontWeight.bold, color: _currentAccount == acc.name ? Theme.of(context).colorScheme.primary : Colors.grey))),
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
                  endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteGroup(g['id']), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('第 ${i + 1} 组', style: const TextStyle(fontWeight: FontWeight.bold)), Text('在库: ${g['inStock']} / 已售出: ${g['sold']}', style: const TextStyle(fontSize: 12, color: Colors.grey))]),
                        const Divider(),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: buildParentCard(g['mother'], true)),
                          const SizedBox(width: 8),
                          Expanded(child: Column(children: (g['fathers'] as List<Parent>).map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: buildParentCard(f, false))).toList())),
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
      floatingActionButton: _currentAccount.isEmpty ? null : FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => PairingEditPage(account: _currentAccount))); _load(); }, child: const Icon(Icons.add)),
    );
  }
}

class PairingEditPage extends StatefulWidget {
  final String account;
  const PairingEditPage({super.key, required this.account});
  @override
  State<PairingEditPage> createState() => _PairingEditPageState();
}

class _PairingEditPageState extends State<PairingEditPage> {
  List<Parent> _mothers = [], _fathers = [];
  int? _motherId; Set<int> _fatherIds = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('parents', where: 'account = ?', whereArgs: [widget.account]);
    final all = rows.map(Parent.fromMap).toList();
    setState(() { _mothers = all.where((p) => p.gender == '母本').toList(); _fathers = all.where((p) => p.gender == '父本').toList(); });
  }

  Future<void> _save() async {
    if (_motherId == null) return;
    final db = await AppDatabase.instance.db;
    final id = await db.insert('pairings', {'account': widget.account, 'mother_id': _motherId});
    for (var fid in _fatherIds) { await db.insert('pairing_fathers', {'pairing_id': id, 'father_id': fid}); }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建配对组')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('选择母本', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // 横向滑动的卡片列表
        SizedBox(
          height: 160,
          child: _mothers.isEmpty 
            ? const Center(child: Text('暂无母本'))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mothers.length,
                itemBuilder: (context, i) {
                  final m = _mothers[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 200,
                      child: buildParentCard(m, true, isSelected: _motherId == m.id, onTap: () => setState(() => _motherId = m.id)),
                    ),
                  );
                },
              ),
        ),
        const SizedBox(height: 24),
        const Text('选择父本(可多选)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: _fathers.isEmpty 
            ? const Center(child: Text('暂无父本'))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _fathers.length,
                itemBuilder: (context, i) {
                  final f = _fathers[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 200,
                      child: buildParentCard(
                        f, false, 
                        isSelected: _fatherIds.contains(f.id), 
                        onTap: () {
                          setState(() {
                            if (_fatherIds.contains(f.id)) { _fatherIds.remove(f.id); } else { _fatherIds.add(f.id!); }
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
        ),
      ]),
      floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(onPressed: _save, backgroundColor: Colors.green, foregroundColor: Colors.white, heroTag: 'save', child: const Icon(Icons.check)),
        const SizedBox(width: 16),
        FloatingActionButton(onPressed: () => Navigator.pop(context), backgroundColor: Colors.red, foregroundColor: Colors.white, heroTag: 'cancel', child: const Icon(Icons.close)),
      ]),
    );
  }
}
