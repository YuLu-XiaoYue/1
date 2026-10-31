import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import '../db/database.dart';
import '../models/models.dart';

// ... buildParentCard 保持原样 ...

class ParentPage extends StatefulWidget {
  const ParentPage({super.key});
  @override
  State<ParentPage> createState() => ParentPageState();
}

class ParentPageState extends State<ParentPage> {
  List<Account> _accounts = [];
  String _currentAccount = '';
  List<Parent> _parents = [];

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
      _loadParents();
    });
  }

  Future<void> _loadParents() async {
    if (_currentAccount.isEmpty) { setState(() => _parents = []); return; }
    final db = await AppDatabase.instance.db;
    final rows = await db.query('parents', where: 'account = ?', whereArgs: [_currentAccount], orderBy: 'id DESC');
    if (!mounted) return;
    setState(() => _parents = rows.map(Parent.fromMap).toList());
  }

  void _addAccount() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('添加新账号'), 
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '账号名称 (必填)')),
        const SizedBox(height: 12),
        TextField(controller: idCtrl, decoration: const InputDecoration(labelText: '账号ID / 备注')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isNotEmpty) { 
            final db = await AppDatabase.instance.db; 
            await db.insert('accounts', {'name': nameCtrl.text, 'account_id': idCtrl.text}); 
            if (mounted) Navigator.pop(c); 
            _loadAccounts(); 
          }
        }, child: const Text('添加')),
      ],
    ));
  }

  // 修改或删除账号
  void _manageAccount(Account acc) {
    final nameCtrl = TextEditingController(text: acc.name);
    final idCtrl = TextEditingController(text: acc.accountId ?? '');

    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text('管理账号'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '账号名称')),
          const SizedBox(height: 12),
          TextField(controller: idCtrl, decoration: const InputDecoration(labelText: '账号ID / 备注')),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              // 删除逻辑
              final confirm = await showDialog<bool>(context: context, builder: (c2) => AlertDialog(
                title: Text('危险操作'), 
                content: Text('确定删除账号 "${acc.name}" 吗？\n该账号下的所有父母本、配对组、产线都将被彻底清除！在库的蛋会解除关联，已售出的保留历史。'), 
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('取消')), 
                  TextButton(onPressed: () => Navigator.pop(c2, true), child: const Text('确定删除', style: TextStyle(color: Colors.red)))
                ]
              ));
              
              if (confirm == true) {
                final db = await AppDatabase.instance.db;
                await db.transaction((txn) async {
                  // 1. 解除在库/预定蛋的关联
                  final eggs = await txn.query('eggs', where: 'account = ? AND status != ?', whereArgs: [acc.name, '已售出']);
                  for (var e in eggs) { await txn.update('eggs', {'father_id': null, 'mother_id': null}, where: 'id = ?', whereArgs: [e['id']]); }
                  // 2. 清理父母本、配对组、产线
                  await txn.delete('parents', where: 'account = ?', whereArgs: [acc.name]);
                  await txn.delete('pairings', where: 'account = ?', whereArgs: [acc.name]);
                  await txn.delete('production_lines', where: 'account_name = ?', whereArgs: [acc.name]);
                  await txn.delete('accounts', where: 'id = ?', whereArgs: [acc.id]);
                });
                if (mounted) Navigator.pop(c);
                _loadAccounts();
              }
            }, 
            child: const Text('删除账号', style: TextStyle(color: Colors.red))
          ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              // 保存修改
              if (nameCtrl.text.isEmpty) return;
              final db = await AppDatabase.instance.db;
              final oldName = acc.name;
              final newName = nameCtrl.text;
              
              await db.transaction((txn) async {
                await txn.update('accounts', {'name': newName, 'account_id': idCtrl.text}, where: 'id = ?', whereArgs: [acc.id]);
                if (oldName != newName) {
                   // 级联更新名字
                   await txn.update('parents', {'account': newName}, where: 'account = ?', whereArgs: [oldName]);
                   await txn.update('pairings', {'account': newName}, where: 'account = ?', whereArgs: [oldName]);
                   await txn.update('production_lines', {'account_name': newName}, where: 'account_name = ?', whereArgs: [oldName]);
                   await txn.update('eggs', {'account': newName}, where: 'account = ?', whereArgs: [oldName]);
                }
              });
              if (mounted) Navigator.pop(c);
              _loadAccounts();
            }, 
            child: const Text('保存修改')
          ),
        ],
      )
    );
  }

  void _deleteParent(Parent p) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('确认删除父母本？'), content: const Text('删除后，已经生成的蛋将永久显示[已删除]状态！'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定删除', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('parents', where: 'id = ?', whereArgs: [p.id]); _loadParents(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _accounts.map((acc) => GestureDetector(
                      onTap: () { setState(() => _currentAccount = acc.name); _loadParents(); },
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
                    )).toList(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addAccount),
              ],
            ),
          ),
          Expanded(
            child: _currentAccount.isEmpty ? const Center(child: Text('请先添加账号')) : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _parents.length,
              itemBuilder: (context, i) {
                final p = _parents[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onSecondaryTap: () => _deleteParent(p),
                    child: Slidable(
                      key: ValueKey(p.id),
                      extentRatio: 0.25, 
                      endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteParent(p), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
                      child: buildParentCard(
                        context,
                        p, p.gender == '母本',
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ParentEditPage(parent: p, account: _currentAccount)));
                          _loadParents();
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _currentAccount.isEmpty ? null : Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: FloatingActionButton(
          onPressed: () async { 
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ParentEditPage(account: _currentAccount))); 
            _loadParents(); 
          }, 
          child: const Icon(Icons.add)
        ),
      ),
    );
  }
}
