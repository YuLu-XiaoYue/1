import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
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

Widget _buildBloodlineChip(String bloodline, bool isSelected) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Image.asset('assets/bloodlines/$bloodline.png', width: 16, height: 16, errorBuilder: (c,e,s) => const Icon(Icons.circle, size: 16, color: Colors.grey)),
    const SizedBox(width: 4), Text(bloodline),
  ]);
}

Widget buildParentCard(BuildContext context, Parent p, bool isMother, {bool isSelected = false, VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white,
        border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200, width: isSelected ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              getLocalImage(p.iconPath, 'parent_icons', size: 40, fallbackIcon: Icons.face),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: isMother ? Colors.pink.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text(isMother ? '♀' : '♂', style: TextStyle(color: isMother ? Colors.pink : Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                        if (p.appearance != '普通') Padding(padding: const EdgeInsets.only(right: 4), child: _buildAppearanceIcon(p.appearance)),
                        if (p.bloodline != null) Image.asset('assets/bloodlines/${p.bloodline}.png', width: 16, height: 16, errorBuilder: (c,e,s) => Text(p.bloodline![0], style: const TextStyle(fontSize: 10, color: Colors.purple))),
                      ],
                    ),
                    Text(p.nature ?? "-", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Text('身高: ${p.height ?? "-"}m', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Text('体重: ${p.weight ?? "-"}kg', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Text('声音: ${p.voice ?? "-"}dB', style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    ),
  );
}

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
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('添加新账号'), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: '账号名称')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.isNotEmpty) { final db = await AppDatabase.instance.db; await db.insert('accounts', {'name': ctrl.text}); if (mounted) Navigator.pop(c); _loadAccounts(); }
        }, child: const Text('添加')),
      ],
    ));
  }

  void _deleteAccount(String accName) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('高危操作'), content: Text('确定删除账号 "$accName" 吗？\n该账号下的父母本和配对组将同步清除。'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) {
      final db = await AppDatabase.instance.db;
      await db.transaction((txn) async {
        final eggs = await txn.query('eggs', where: 'account = ? AND status != ?', whereArgs: [accName, '已售出']);
        for (var e in eggs) { await txn.update('eggs', {'father_id': null, 'mother_id': null}, where: 'id = ?', whereArgs: [e['id']]); }
        await txn.delete('parents', where: 'account = ?', whereArgs: [accName]);
        await txn.delete('pairings', where: 'account = ?', whereArgs: [accName]);
        await txn.delete('accounts', where: 'name = ?', whereArgs: [accName]);
      });
      _loadAccounts();
    }
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
            height: 50,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _accounts.map((acc) => InkWell(
                      onTap: () { setState(() => _currentAccount = acc.name); _loadParents(); },
                      onLongPress: () => _deleteAccount(acc.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24), alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _currentAccount == acc.name ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))),
                        child: Text(acc.name, style: TextStyle(fontWeight: FontWeight.bold, color: _currentAccount == acc.name ? Theme.of(context).colorScheme.primary : Colors.grey)),
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
      floatingActionButton: _currentAccount.isEmpty ? null : FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ParentEditPage(account: _currentAccount))); _loadParents(); }, child: const Icon(Icons.add)),
    );
  }
}

class ParentEditPage extends StatefulWidget {
  final Parent? parent; final String account;
  const ParentEditPage({super.key, this.parent, required this.account});
  @override
  State<ParentEditPage> createState() => _ParentEditPageState();
}

class _ParentEditPageState extends State<ParentEditPage> {
  final _nameCtrl = TextEditingController(), _natureCtrl = TextEditingController(), _heightCtrl = TextEditingController(), _weightCtrl = TextEditingController(), _voiceCtrl = TextEditingController();
  String _gender = '母本'; String? _bloodline, _iconPath; String _appearance = '普通';

  @override
  void initState() {
    super.initState();
    if (widget.parent != null) {
      final p = widget.parent!; _nameCtrl.text = p.name; _natureCtrl.text = p.nature ?? ''; _heightCtrl.text = p.height?.toString() ?? ''; _weightCtrl.text = p.weight?.toString() ?? ''; _voiceCtrl.text = p.voice?.toString() ?? ''; _gender = p.gender; _bloodline = p.bloodline; _iconPath = p.iconPath; _appearance = p.appearance;
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    final db = await AppDatabase.instance.db;
    String? finalPath = _iconPath;
    if (finalPath == null) {
      final exist = await db.query('parents', where: 'name = ? AND icon_path IS NOT NULL', whereArgs: [_nameCtrl.text], limit: 1);
      if (exist.isNotEmpty) finalPath = exist.first['icon_path'] as String?;
    }
    final p = Parent(id: widget.parent?.id, name: _nameCtrl.text, gender: _gender, account: widget.account, nature: _natureCtrl.text, height: double.tryParse(_heightCtrl.text), weight: double.tryParse(_weightCtrl.text), voice: double.tryParse(_voiceCtrl.text), bloodline: _bloodline, iconPath: finalPath, appearance: _appearance);
    if (p.id == null) { await db.insert('parents', p.toMap()); } else { await db.update('parents', p.toMap(), where: 'id=?', whereArgs: [p.id]); }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.parent == null ? '新增父母本' : '编辑父母本')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          getLocalImage(_iconPath, 'parent_icons', size: 60, fallbackIcon: Icons.face),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: () async { final res = await FilePicker.platform.pickFiles(type: FileType.image); if (res != null && res.files.single.path != null) { final saved = await copyImageToLocal(res.files.single.path!, 'parent_icons'); setState(() => _iconPath = saved); } }, icon: const Icon(Icons.image), label: const Text('选图')),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '精灵名字')),
        
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _gender,
              isExpanded: true,
              menuMaxHeight: 250,
              decoration: const InputDecoration(labelText: '性别'),
              items: ['母本', '父本'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _gender = v!),
            )
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _appearance,
              isExpanded: true,
              menuMaxHeight: 250,
              decoration: const InputDecoration(labelText: '外观'),
              items: appearanceTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _appearance = v!),
            )
          ),
        ]),
        
        const SizedBox(height: 16),
        TextField(controller: _natureCtrl, decoration: const InputDecoration(labelText: '性格')),
        
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '身高(m)'))), const SizedBox(width: 8),
          Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '体重(kg)'))), const SizedBox(width: 8),
          Expanded(child: TextField(controller: _voiceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '声音(dB)'))),
        ]),
        
        const SizedBox(height: 24),
        const Text('血脉（单选）', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: bloodlines.map((b) => ChoiceChip(label: _buildBloodlineChip(b, _bloodline == b), selected: _bloodline == b, onSelected: (v) => setState(() => _bloodline = v ? b : null))).toList()),
      ]),
      floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(onPressed: _save, backgroundColor: Colors.green, foregroundColor: Colors.white, heroTag: 'save', child: const Icon(Icons.check)),
        const SizedBox(width: 16),
        FloatingActionButton(onPressed: () async {
          final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('放弃修改？'), actions: [TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定')), TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消'))]));
          if (confirm == true && context.mounted) Navigator.pop(context);
        }, backgroundColor: Colors.red, foregroundColor: Colors.white, heroTag: 'cancel', child: const Icon(Icons.close)),
      ]),
    );
  }
}
