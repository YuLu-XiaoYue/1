import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:io';
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

// 公用卡片组件，供配对页复用
Widget buildParentCard(BuildContext context, Parent p, bool isMother, {bool isSelected = false, VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
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
                        Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
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
          const Spacer(),
          const Divider(height: 16),
          Text('身高: ${p.height ?? "-"}m', style: const TextStyle(fontSize: 11, color: Colors.black87)),
          Text('体重: ${p.weight ?? "-"}kg', style: const TextStyle(fontSize: 11, color: Colors.black87)),
          Text('声音: ${p.voice ?? "-"}dB', style: const TextStyle(fontSize: 11, color: Colors.black87)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () async {
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
                }, 
                child: const Text('删除账号', style: TextStyle(color: Colors.red))
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
                    }, 
                    child: const Text('保存修改')
                  ),
                ],
              )
            ],
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
            child: _currentAccount.isEmpty 
              ? const Center(child: Text('请先添加账号')) 
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // 响应式网格：宽屏3列，窄屏2列
                    int crossAxisCount = constraints.maxWidth > 800 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8, // 控制卡片高度
                      ),
                      itemCount: _parents.length,
                      itemBuilder: (context, i) {
                        final p = _parents[i];
                        return GestureDetector(
                          onSecondaryTap: () => _deleteParent(p),
                          child: Slidable(
                            key: ValueKey(p.id),
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(), 
                              extentRatio: 0.25, 
                              children: [
                                SlidableAction(onPressed: (_) => _deleteParent(p), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')
                              ]
                            ),
                            child: buildParentCard(
                              context,
                              p, p.gender == '母本',
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => ParentEditPage(parent: p, account: _currentAccount)));
                                _loadParents();
                              },
                            ),
                          ),
                        );
                      },
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

  Future<void> _onNameChanged(String name) async {
    if (name.isEmpty) return;
    final db = await AppDatabase.instance.db;
    final rows = await db.query('creatures');
    final creatures = rows.map(Creature.fromMap).toList();
    
    for (var c in creatures) {
      if (name.contains(c.name)) {
        setState(() => _iconPath = c.iconPath);
        return;
      }
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    final db = await AppDatabase.instance.db;
    
    if (_iconPath == null) {
      _iconPath = await syncParentImage(_nameCtrl.text, null, widget.parent?.iconPath);
    }

    final p = Parent(id: widget.parent?.id, name: _nameCtrl.text, gender: _gender, account: widget.account, nature: _natureCtrl.text, height: double.tryParse(_heightCtrl.text), weight: double.tryParse(_weightCtrl.text), voice: double.tryParse(_voiceCtrl.text), bloodline: _bloodline, iconPath: _iconPath, appearance: _appearance);
    if (p.id == null) { await db.insert('parents', p.toMap()); } else { await db.update('parents', p.toMap(), where: 'id=?', whereArgs: [p.id]); }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.parent == null ? '新增父母本' : '编辑父母本')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: getLocalImage(_iconPath, 'parent_icons', size: 80, fallbackIcon: Icons.face),
          ),
        ),

        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '精灵名字 (自动识别图标)'), onChanged: _onNameChanged),
        
        const SizedBox(height: 16),
        const Text('性别', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildChoiceButton('母本', _gender == '母本', () => setState(() => _gender = '母本'))),
          const SizedBox(width: 16),
          Expanded(child: _buildChoiceButton('父本', _gender == '父本', () => setState(() => _gender = '父本'))),
        ]),

        const SizedBox(height: 16),
        const Text('外观', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: appearanceTypes.map((a) => ChoiceChip(
            label: Text(a), 
            selected: _appearance == a, 
            onSelected: (v) => setState(() => _appearance = v ? a : '普通')
          )).toList(),
        ),
        
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

  Widget _buildChoiceButton(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.green.shade800 : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
