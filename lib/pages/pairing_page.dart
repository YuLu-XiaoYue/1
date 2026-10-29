import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../db/database.dart';
import '../models/models.dart';

Widget _buildAppearanceIcon(String appearance, {double size = 16}) {
  if (appearance == '异色') return Image.asset('assets/special_icons/shiny.png', width: size, height: size, errorBuilder: (c,e,s) => Icon(Icons.auto_awesome, size: size, color: Colors.amber));
  if (appearance == '炫彩') return Image.asset('assets/special_icons/colorful.png', width: size, height: size, errorBuilder: (c,e,s) => Icon(Icons.star, size: size, color: Colors.blueAccent));
  if (appearance == '异色炫彩') return Image.asset('assets/special_icons/shiny_colorful.png', width: size, height: size, errorBuilder: (c,e,s) => Icon(Icons.color_lens, size: size, color: Colors.purpleAccent));
  if (appearance == '黑白') return Image.asset('assets/special_icons/monochrome.png', width: size, height: size, errorBuilder: (c,e,s) => Icon(Icons.contrast, size: size, color: Colors.grey));
  if (appearance == '异色黑白') return Image.asset('assets/special_icons/shiny_monochrome.png', width: size, height: size, errorBuilder: (c,e,s) => Icon(Icons.brightness_4, size: size, color: Colors.black87));
  return const SizedBox.shrink();
}

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});
  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  List<Account> _accounts = [];
  String _currentAccount = '';
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() { super.initState(); _loadAccounts(); }

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
                          Expanded(child: _buildParentCard(g['mother'], true)),
                          const SizedBox(width: 8),
                          Expanded(child: Column(children: (g['fathers'] as List<Parent>).map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildParentCard(f, false))).toList())),
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

  Widget _buildParentCard(Parent p, bool isMother) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0,2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            getLocalImage(p.iconPath, 'parent_icons', size: 40, fallbackIcon: Icons.face),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: isMother ? Colors.pink.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text(isMother ? '♀' : '♂', style: TextStyle(color: isMother ? Colors.pink : Colors.blue, fontWeight: FontWeight.bold))),
                const SizedBox(width: 4),
                Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                if (p.appearance != '普通') Padding(padding: const EdgeInsets.only(right: 4), child: _buildAppearanceIcon(p.appearance)),
                if (p.bloodline != null) Image.asset('assets/bloodlines/${p.bloodline}.png', width: 16, height: 16, errorBuilder: (c,e,s) => Text(p.bloodline![0], style: const TextStyle(fontSize: 10, color: Colors.purple))),
              ]),
              Text(p.nature ?? "-", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
          ]),
          const Divider(height: 16),
          Text('身高: ${p.height ?? "-"}m', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Text('体重: ${p.weight ?? "-"}kg', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Text('声音: ${p.voice ?? "-"}dB', style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
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
        Wrap(spacing: 8, children: _mothers.map((m) => ChoiceChip(label: Text(m.name), selected: _motherId == m.id, onSelected: (v) => setState(() => _motherId = v ? m.id : null))).toList()),
        const SizedBox(height: 24),
        const Text('选择父本(可多选)', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: _fathers.map((f) => FilterChip(label: Text(f.name), selected: _fatherIds.contains(f.id), onSelected: (v) { setState(() { if (v) { _fatherIds.add(f.id!); } else { _fatherIds.remove(f.id); } }); })).toList()),
      ]),
      floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(onPressed: _save, backgroundColor: Colors.green, foregroundColor: Colors.white, heroTag: 'save', child: const Icon(Icons.check)),
        const SizedBox(width: 16),
        FloatingActionButton(onPressed: () => Navigator.pop(context), backgroundColor: Colors.red, foregroundColor: Colors.white, heroTag: 'cancel', child: const Icon(Icons.close)),
      ]),
    );
  }
}
