import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import '../db/database.dart';
import '../models/models.dart';
import 'parent_page.dart';

// 图1风格的胶囊卡片（这里用圆角+阴影模拟）
Widget _buildPillCard({required Widget child, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.purple.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
        ]
      ),
      child: child,
    ),
  );
}

class ProductionLinePage extends StatefulWidget {
  const ProductionLinePage({super.key});
  @override
  State<ProductionLinePage> createState() => ProductionLinePageState();
}

class ProductionLinePageState extends State<ProductionLinePage> {
  List<ProductionLine> _lines = [];
  List<Account> _accounts = [];
  String _filterAccount = '全部';
  String _filterLine = '全部';
  
  @override
  void initState() { super.initState(); _load(); }

  Future<void> loadData() async { await _load(); }

  Future<void> _load() async {
    final db = await AppDatabase.instance.db;
    final accRows = await db.query('accounts');
    final lineRows = await db.query('production_lines', orderBy: 'created_at DESC');
    if (!mounted) return;
    setState(() {
      _accounts = accRows.map(Account.fromMap).toList();
      _lines = lineRows.map(ProductionLine.fromMap).toList();
    });
  }

  void _deleteLine(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('删除产线？'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定'))],
    ));
    if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('production_lines', where: 'id = ?', whereArgs: [id]); _load(); }
  }

  // 长按/右键删除标签
  void _showDeleteTabMenu(String title, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('删除标签 "$title"？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          TextButton(onPressed: () { onDelete(); Navigator.pop(c); }, child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var visible = _lines.where((l) {
      bool matchAcc = _filterAccount == '全部' || l.accountName == _filterAccount;
      bool matchLine = _filterLine == '全部' || l.name == _filterLine;
      return matchAcc && matchLine;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // 顶部筛选标签
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterTab('全部', _filterAccount == '全部', () => setState(() => _filterAccount = '全部'), null),
                ..._accounts.map((acc) {
                  return _buildFilterTab(
                    acc.name, 
                    _filterAccount == acc.name, 
                    () => setState(() => _filterAccount = acc.name), 
                    () => _showDeleteTabMenu(acc.name, () {})
                  );
                })
              ],
            ),
          ),
          
          // 筛选按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_alt),
                  onSelected: (v) => setState(() => _filterLine = v),
                  itemBuilder: (c) => [
                    const PopupMenuItem(value: '全部', child: Text('全部产线')),
                    ..._lines.map((l) => PopupMenuItem(value: l.name, child: Text(l.name)))
                  ],
                )
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final line = visible[i];
                return GestureDetector(
                  onSecondaryTap: () => _deleteLine(line.id!),
                  child: Slidable(
                    key: ValueKey(line.id),
                    extentRatio: 0.25,
                    endActionPane: ActionPane(motion: const ScrollMotion(), children: [
                      SlidableAction(onPressed: (_) => _deleteLine(line.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')
                    ]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildPillCard(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductionLineEditPage(line: line)));
                          _load();
                        },
                        child: Row(
                          children: [
                            // 序号
                            Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(width: 12),
                            // 图标
                            getLocalImage(line.iconPath, 'egg_icons', size: 44),
                            const SizedBox(width: 12),
                            // 产线名称
                            Expanded(
                              child: Text(line.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            // 3个固定角标位置 (无则不显示，但占位)
                            SizedBox(width: 24, child: line.medals.contains('满重') || line.medals.contains('大块头') ? Image.asset('assets/medals/full_weight.png', width: 24, height: 24, errorBuilder: (c,e,s) => const SizedBox()) : null),
                            const SizedBox(width: 4),
                            SizedBox(width: 24, child: line.medals.contains('婉转声') || line.medals.contains('满音婉转声') ? Image.asset('assets/medals/gentle_voice.png', width: 24, height: 24, errorBuilder: (c,e,s) => const SizedBox()) : null),
                            const SizedBox(width: 4),
                            SizedBox(width: 24, child: line.nestType == '绿窝' ? Image.asset('assets/nest_types/green_nest.png', width: 24, height: 24, errorBuilder: (c,e,s) => const SizedBox()) : null),
                            const SizedBox(width: 16),
                            // 性格与概率
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                                  child: Text(line.nature, style: const TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(height: 4),
                                Text(line.natureProb, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: FloatingActionButton(
          onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionLineEditPage())); _load(); }, 
          child: const Icon(Icons.add)
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title, bool isSelected, VoidCallback onTap, VoidCallback? onDelete) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      onSecondaryTap: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey)),
      ),
    );
  }
}

class ProductionLineEditPage extends StatefulWidget {
  final ProductionLine? line;
  const ProductionLineEditPage({super.key, this.line});
  @override
  State<ProductionLineEditPage> createState() => _ProductionLineEditPageState();
}

class _ProductionLineEditPageState extends State<ProductionLineEditPage> {
  final _nameCtrl = TextEditingController();
  String _account = '';
  String _nestType = '普窝';
  int? _pairingId;
  String _nature = '请选择配对组';
  String _natureProb = '概率将在选择配对组后自动生成';
  
  List<Account> _accounts = [];
  List<Map<String, dynamic>> _pairings = [];
  List<Parent> _selectedFathers = [];
  Parent? _selectedMother;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.line != null) {
      final l = widget.line!;
      _nameCtrl.text = l.name; _account = l.accountName; _nestType = l.nestType; _pairingId = l.pairingId; _nature = l.nature; _natureProb = l.natureProb;
      _loadPairingDetails(l.pairingId);
    }
  }

  Future<void> _loadData() async {
    final db = await AppDatabase.instance.db;
    final accRows = await db.query('accounts');
    final pairingRows = await db.query('pairings', where: 'account = ?', whereArgs: [_account.isNotEmpty ? _account : (accRows.isNotEmpty ? accRows.first['name'] : '')]);
    setState(() {
      _accounts = accRows.map(Account.fromMap).toList();
      if (_account.isEmpty && _accounts.isNotEmpty) _account = _accounts.first.name;
      _pairings = pairingRows;
    });
  }

  Future<void> _loadPairingDetails(int pairingId) async {
    final db = await AppDatabase.instance.db;
    final mRows = await db.rawQuery('SELECT p.* FROM parents p JOIN pairings pa ON p.id = pa.mother_id WHERE pa.id = ?', [pairingId]);
    final fRows = await db.rawQuery('SELECT p.* FROM parents p JOIN pairing_fathers pf ON p.id = pf.father_id WHERE pf.pairing_id = ?', [pairingId]);
    
    if (mRows.isNotEmpty && fRows.isNotEmpty) {
      _selectedMother = Parent.fromMap(mRows.first);
      _selectedFathers = fRows.map(Parent.fromMap).toList();
      String result = calculateNature(_selectedFathers, _selectedMother!);
      List<String> parts = result.split('|');
      setState(() { _nature = parts[0]; _natureProb = parts[1]; });
    }
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty || _pairingId == null) return;
    final db = await AppDatabase.instance.db;
    final acc = _accounts.firstWhere((a) => a.name == _account);
    
    final line = ProductionLine(
      id: widget.line?.id, name: _nameCtrl.text, accountName: _account, accountId: acc.accountId,
      nestType: _nestType, pairingId: _pairingId!, nature: _nature, natureProb: _natureProb, 
      iconPath: widget.line?.iconPath, medals: widget.line?.medals ?? [],
    );
    if (line.id == null) { await db.insert('production_lines', line.toMap()); } else { await db.update('production_lines', line.toMap(), where: 'id=?', whereArgs: [line.id]); }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.line == null ? '新增产线' : '编辑产线')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '产线名称 (蛋名)')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _account.isEmpty ? null : _account, decoration: const InputDecoration(labelText: '所属账号'),
          items: _accounts.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(),
          onChanged: (v) { setState(() => _account = v!); _loadData(); }
        ),
        const SizedBox(height: 16),
        // 图2样式的窝类型按钮
        Row(children: [
          Expanded(child: _buildNestButton('普窝')),
          const SizedBox(width: 16),
          Expanded(child: _buildNestButton('绿窝')),
        ]),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _pairingId, decoration: const InputDecoration(labelText: '父母本配对组'),
          items: _pairings.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('组 ${p['id']} (母本ID: ${p['mother_id']})'))).toList(),
          onChanged: (v) { setState(() => _pairingId = v); _loadPairingDetails(v!); }
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text('自动识别性格: $_nature', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('性格概率: $_natureProb', style: const TextStyle(color: Colors.grey)),
          ]),
        )
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(type, style: TextStyle(color: isSelected ? Colors.green.shade800 : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
