import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../db/database.dart';
import '../models/models.dart';

class BlacklistPage extends StatefulWidget {
  const BlacklistPage({super.key});
  @override
  State<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends State<BlacklistPage> {
  List<Blacklist> _list = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('blacklist', orderBy: 'id DESC');
    if (!mounted) return;
    setState(() => _list = rows.map(Blacklist.fromMap).toList());
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController(), platCtrl = TextEditingController(), pidCtrl = TextEditingController(), gidCtrl = TextEditingController(), reasonCtrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('拉黑买家'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '买家名称 (必填)')),
        TextField(controller: platCtrl, decoration: const InputDecoration(labelText: '交易平台')),
        TextField(controller: pidCtrl, decoration: const InputDecoration(labelText: '买家平台ID')),
        TextField(controller: gidCtrl, decoration: const InputDecoration(labelText: '买家游戏ID')),
        TextField(controller: reasonCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '拉黑原因')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          final db = await AppDatabase.instance.db;
          await db.insert('blacklist', {'buyer_name': nameCtrl.text, 'platform': platCtrl.text, 'platform_id': pidCtrl.text, 'game_id': gidCtrl.text, 'reason': reasonCtrl.text});
          if (mounted) Navigator.pop(c);
          _load();
        }, child: const Text('保存')),
      ],
    ));
  }

  void _deleteItem(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('确认解除拉黑？'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定'))],
    ));
    if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('blacklist', where: 'id = ?', whereArgs: [id]); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _list.isEmpty ? const Center(child: Text('暂无拉黑记录')) : ListView.builder(
        itemCount: _list.length,
        itemBuilder: (context, i) {
          final b = _list[i];
          return GestureDetector(
            onSecondaryTap: () => _deleteItem(b.id!),
            child: Slidable(
              key: ValueKey(b.id),
              endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteItem(b.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
              child: ListTile(
                title: Text(b.buyerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('平台: ${b.platform} | 平台ID: ${b.platformId}\n游戏ID: ${b.gameId} | 原因: ${b.reason ?? "无"}'),
                isThreeLine: true,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)),
    );
  }
}
