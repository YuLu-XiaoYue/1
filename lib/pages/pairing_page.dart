import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:convert';
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
  
  String _filterNature = '全部';
  String _filterMotherName = '全部';
  String _filterEggGroup = '全部';

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
      
      List<String> relatedEggGroups = [];
      final lines = await db.query('production_lines', where: 'pairing_id = ?', whereArgs: [p['id']]);
      for (var l in lines) {
        final groups = (jsonDecode(l['egg_groups'] as String? ?? '[]') as List).cast<String>();
        relatedEggGroups.addAll(groups);
      }

      loaded.add({
        'id': p['id'], 'groupName': p['group_name'] ?? '', 'mother': mother, 'fathers': fathers, 
        'inStock': inStock, 'sold': sold, 'isMixed': isMixed, 'nestType': p['nest_type'] ?? '普窝',
        'eggGroups': relatedEggGroups.toSet().toList(), 
      });
    }
    if (!mounted) return;
    setState(() => _groups = loaded);
  }

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
        // 修复：用 Row 包裹
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
            )
          ],
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

  void _showFilterDialog() {
    Set<String> mothers = _groups.map((g) => (g['mother'] as Parent).name).toSet();
    Set<String> allGroups = _groups.expand((g) => g['eggGroups'] as List<String>).toSet();

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('筛选配对组'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: _filterNature, isExpanded: true, decoration: const InputDecoration(labelText: '按性格'),
                items: [const DropdownMenuItem(value: '全部', child: Text('全部')), ...naturesList.map((e) => DropdownMenuItem(value: e, child: Text(e)))],
                onChanged: (v) => setDialogState(() => _filterNature = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _filterMotherName, isExpanded: true, decoration: const InputDecoration(labelText: '按母本精灵名字'),
                items: [const DropdownMenuItem(value: '全部', child: Text('全部')), ...mothers.map((e) => DropdownMenuItem(value: e, child: Text(e)))],
                onChanged: (v) => setDialogState(() => _filterMotherName = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _filterEggGroup, isExpanded: true, decoration: const InputDecoration(labelText: '按蛋组'),
                items: [const DropdownMenuItem(value: '全部', child: Text('全部')), ...allGroups.map((e) => DropdownMenuItem(value: e, child: Text(e)))],
                onChanged: (v) => setDialogState(() => _filterEggGroup = v!),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => setState(() { _filterNature = '全部'; _filterMotherName = '全部'; _filterEggGroup = '全部'; }), child: const Text('重置')),
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
              ElevatedButton(onPressed: () { setState(() {}); Navigator.pop(c); }, child: const Text('确定')),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var visible = _groups.where((g) {
      bool matchMother = _filterMotherName == '全部' || (g['mother'] as Parent).name == _filterMotherName;
      bool matchNature = _filterNature == '全部' || (g['mother'] as Parent).nature == _filterNature || (g['fathers'] as List<Parent>).any((f) => f.nature == _filterNature);
      bool matchGroup = _filterEggGroup == '全部' || (g['eggGroups'] as List<String>).contains(_filterEggGroup);
      return matchMother && matchNature && matchGroup;
    }).toList();

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
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(acc.name, style: TextStyle(fontWeight: FontWeight.bold, color: _currentAccount == acc.name ? Theme.of(context).colorScheme.primary : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (acc.accountId != null && acc.accountId!.isNotEmpty) Text(acc.accountId!, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          )).toList())),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: Icon(Icons.filter_alt, color: (_filterNature != '全部' || _filterMotherName != '全部' || _filterEggGroup != '全部') ? Theme.of(context).colorScheme.primary : null), onPressed: _showFilterDialog),
              ],
            ),
          ),

          Expanded(child: _currentAccount.isEmpty ? const Center(child: Text('请先添加账号')) : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final g = visible[i];
              String displayName = '第 ${i + 1} 组';
              if (g['groupName'].isNotEmpty) { displayName += ' - ${g['groupName']}'; }

              return GestureDetector(
                onSecondaryTap: () => _deleteGroup(g['id']),
                child: Slidable(
                  key: ValueKey(g['id']),
                  endActionPane: ActionPane(motion: const ScrollMotion(), extentRatio: 0.25, children: [SlidableAction(onPressed: (_) => _deleteGroup(g['id']), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                            const SizedBox(width: 8),
                            if (g['isMixed']) const Text('混窝', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
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

class PairingEditPage extends StatefulWidget {
  final String account;
  const PairingEditPage({super.key, required this.account});
  @override
  State<PairingEditPage> createState() => _PairingEditPageState();
}

class _PairingEditPageState extends State<PairingEditPage> {
  List<Parent> _mothers = [], _fathers = [];
  int? _motherId; Set<int> _fatherIds = {};
  String _nestType = '普窝';
  final _groupNameCtrl = TextEditingController(); 

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
    final id = await db.insert('pairings', {
      'account': widget.account, 'mother_id': _motherId, 'nest_type': _nestType, 'group_name': _groupNameCtrl.text.trim() 
    });
    for (var fid in _fatherIds) { await db.insert('pairing_fathers', {'pairing_id': id, 'father_id': fid}); }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建配对组')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _groupNameCtrl, decoration: const InputDecoration(labelText: '自定义组名 (选填)')), 
        const SizedBox(height: 16),
        const Text('选择窝类型', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [ Expanded(child: _buildNestButton('普窝')), const SizedBox(width: 16), Expanded(child: _buildNestButton('绿窝')) ]),
        const SizedBox(height: 24),
        const Text('选择母本', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(height: 160, child: _mothers.isEmpty ? const Center(child: Text('暂无母本')) : ListView.builder(
          scrollDirection: Axis.horizontal, itemCount: _mothers.length,
          itemBuilder: (context, i) {
            final m = _mothers[i];
            return Padding(padding: const EdgeInsets.only(right: 12), child: SizedBox(width: 200, child: buildParentCard(context, m, true, isSelected: _motherId == m.id, onTap: () => setState(() => _motherId = m.id))));
          },
        )),
        const SizedBox(height: 24),
        const Text('选择父本(可多选)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(height: 160, child: _fathers.isEmpty ? const Center(child: Text('暂无父本')) : ListView.builder(
          scrollDirection: Axis.horizontal, itemCount: _fathers.length,
          itemBuilder: (context, i) {
            final f = _fathers[i];
            return Padding(padding: const EdgeInsets.only(right: 12), child: SizedBox(width: 200, child: buildParentCard(context, f, false, isSelected: _fatherIds.contains(f.id), onTap: () { setState(() { if (_fatherIds.contains(f.id)) { _fatherIds.remove(f.id); } else { _fatherIds.add(f.id!); } }); })));
          },
        )),
      ]),
      floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(onPressed: _save, backgroundColor: Colors.green, foregroundColor: Colors.white, heroTag: 'save', child: const Icon(Icons.check)),
        const SizedBox(width: 16),
        FloatingActionButton(onPressed: () => Navigator.pop(context), backgroundColor: Colors.red, foregroundColor: Colors.white, heroTag: 'cancel', child: const Icon(Icons.close)),
      ]),
    );
  }

  Widget _buildNestButton(String type) {
    bool isSelected = _nestType == type;
    return InkWell(
      onTap: () => setState(() => _nestType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.center,
        decoration: BoxDecoration(color: isSelected ? Colors.green.shade50 : Colors.white, border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(16)),
        child: Text(type, style: TextStyle(color: isSelected ? Colors.green.shade800 : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
