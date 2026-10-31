import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lpinyin/lpinyin.dart';
import '../db/database.dart';
import '../models/models.dart';

class BlacklistPage extends StatefulWidget {
  const BlacklistPage({super.key});
  @override
  State<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends State<BlacklistPage> {
  List<Blacklist> _list = [];
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

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
    var visible = _list.where((b) {
      return _searchQuery.isEmpty || b.buyerName.contains(_searchQuery) || (b.platformId).contains(_searchQuery) || (b.gameId).contains(_searchQuery);
    }).toList();

    Map<String, List<Blacklist>> groupedList = {};
    for (var b in visible) {
      String buyer = b.buyerName;
      String firstLetter = 'Z';
      if (buyer.isNotEmpty) {
        try { firstLetter = PinyinHelper.getShortPinyin(buyer)[0].toUpperCase(); } catch (_) {}
      }
      if (firstLetter.codeUnitAt(0) < 65 || firstLetter.codeUnitAt(0) > 90) firstLetter = '#';
      if (!groupedList.containsKey(firstLetter)) groupedList[firstLetter] = [];
      groupedList[firstLetter]!.add(b);
    }
    List<String> alphabet = groupedList.keys.toList()..sort();

    final Map<String, GlobalKey> sectionKeys = { for (var letter in alphabet) letter: GlobalKey() };

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(hintText: '搜索买家名称 / 平台ID / 游戏ID', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
            ),
          ),
          
          Expanded(
            child: groupedList.isEmpty 
              ? const Center(child: Text('暂无数据')) 
              : Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(right: 30, bottom: 100),
                      itemCount: alphabet.length,
                      itemBuilder: (context, index) {
                        final letter = alphabet[index];
                        return Column(
                          key: sectionKeys[letter],
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: Colors.grey.shade200,
                              child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ...groupedList[letter]!.map((b) => GestureDetector(
                              onSecondaryTap: () => _deleteItem(b.id!),
                              child: Slidable(
                                key: ValueKey(b.id),
                                extentRatio: 0.25, 
                                endActionPane: ActionPane(motion: const ScrollMotion(), children: [
                                  SlidableAction(onPressed: (_) => _deleteItem(b.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')
                                ]),
                                child: ListTile(
                                  title: Text(b.buyerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('平台: ${b.platform} | 平台ID: ${b.platformId}\n游戏ID: ${b.gameId} | 原因: ${b.reason ?? "无"}'),
                                  isThreeLine: true,
                                ),
                              ),
                            ))
                          ],
                        );
                      },
                    ),
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: alphabet.map((l) => GestureDetector(
                              onTap: () {
                                final ctx = sectionKeys[l]?.currentContext;
                                if (ctx != null) { Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)),
      ),
    );
  }
}
