import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:convert';
import '../db/database.dart';
import '../models/models.dart';

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
          // 筛选栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_alt),
                  onSelected: (v) => setState(() => _filterAccount = v),
                  itemBuilder: (c) => [
                    const PopupMenuItem(value: '全部', child: Text('全部账号')),
                    ..._accounts.map((a) => PopupMenuItem(value: a.name, child: Text(a.name)))
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
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
              padding: const EdgeInsets.all(12),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final line = visible[i];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductionLineDetailPage(line: line)));
                    _load();
                  },
                  child: Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左侧大图标
                          getLocalImage(line.iconPath, 'egg_icons', size: 72),
                          const SizedBox(width: 16),
                          // 右侧信息列
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (line.eggGroups.isNotEmpty) Text('蛋组: ${line.eggGroups[0]}', style: const TextStyle(fontSize: 12)),
                                          Text('性格: ${line.nature}', style: const TextStyle(fontSize: 12)),
                                          if (line.nestType == '绿窝') const Text('绿窝', style: TextStyle(fontSize: 12, color: Colors.green)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (line.eggGroups.length > 1) Text('蛋组: ${line.eggGroups[1]}', style: const TextStyle(fontSize: 12)),
                                          if (line.medals.isNotEmpty) Text('奖牌: ${line.medals[0]}', style: const TextStyle(fontSize: 12)),
                                          if (line.medals.length > 1) Text('奖牌: ${line.medals[1]}', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
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
        child: FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionLineEditPage())); _load(); }, child: const Icon(Icons.add)),
      ),
    );
  }
}

// ================= 详情页 & 编辑模式 =================

class ProductionLineDetailPage extends StatefulWidget {
  final ProductionLine line;
  const ProductionLineDetailPage({super.key, required this.line});
  @override
  State<ProductionLineDetailPage> createState() => _ProductionLineDetailPageState();
}

class _ProductionLineDetailPageState extends State<ProductionLineDetailPage> {
  late ProductionLine _line;
  bool _isEditing = false;
  List<LinePriceRule> _rules = [];

  // 编辑暂存状态
  String? _tempName;
  String? _tempNestType;
  List<String> _tempGroups = [];
  List<String> _tempMedals = [];
  String _tempNature = '';
  String _tempNatureProb = '';

  @override
  void initState() {
    super.initState();
    _line = widget.line;
    _resetTemp();
    _loadRules();
  }

  void _resetTemp() {
    _tempName = _line.name;
    _tempNestType = _line.nestType;
    _tempGroups = List.from(_line.eggGroups);
    _tempMedals = List.from(_line.medals);
    _tempNature = _line.nature;
    _tempNatureProb = _line.natureProb;
  }

  Future<void> _loadRules() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('line_price_rules', where: 'line_id = ?', whereArgs: [_line.id], orderBy: 'min_weight ASC');
    setState(() => _rules = rows.map(LinePriceRule.fromMap).toList());
  }

  void _saveChanges() async {
    final db = await AppDatabase.instance.db;
    await db.update('production_lines', {
      'name': _tempName, 'nest_type': _tempNestType, 'medals': jsonEncode(_tempMedals), 
      'egg_groups': jsonEncode(_tempGroups), 'nature': _tempNature, 'nature_prob': _tempNatureProb
    }, where: 'id = ?', whereArgs: [_line.id]);
    
    setState(() {
      _line = ProductionLine(id: _line.id, name: _tempName!, accountName: _line.accountName, nestType: _tempNestType!, pairingId: _line.pairingId, nature: _tempNature, natureProb: _tempNatureProb, medals: _tempMedals, eggGroups: _tempGroups, iconPath: _line.iconPath);
      _isEditing = false;
    });
  }

  void _deleteRule(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('确认删除该区间？'), content: const Text('删除后不可恢复！'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定删除', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('line_price_rules', where: 'id = ?', whereArgs: [id]); _loadRules(); }
  }

  void _showAddRuleDialog() {
    final minCtrl = TextEditingController(), maxCtrl = TextEditingController(), priceCtrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text('添加 [${_line.nestType}] 区间'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '最小蛋重 (kg)')),
        TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '最大蛋重 (kg)')),
        TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '标价 (元)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          final min = double.tryParse(minCtrl.text), max = double.tryParse(maxCtrl.text), price = double.tryParse(priceCtrl.text);
          if (min != null && max != null && price != null) {
            final db = await AppDatabase.instance.db;
            await db.insert('line_price_rules', {
              'line_id': _line.id, 
              'min_weight': min, 'max_weight': max, 'price': price
            });
            if (mounted) Navigator.pop(c);
            _loadRules();
          }
        }, child: const Text('确定')),
      ],
    ));
  }

  // ======= 性格选择器 =======
  void _showNatureSelector() {
    showDialog(context: context, builder: (c) => StatefulBuilder(
      builder: (context, setDialogState) {
        List<String> selected = [];
        if (_tempNature != '混窝' && _tempNature.isNotEmpty) {
          selected = _tempNature.split('丨');
        } else if (_tempNature == '混窝') {
          selected = ['混窝'];
        }
        
        void toggle(String n) {
          setDialogState(() {
            if (n == '混窝') {
              selected = selected.contains('混窝') ? [] : ['混窝'];
            } else {
              selected.remove('混窝');
              if (selected.contains(n)) { selected.remove(n); } 
              else { if (selected.length >= 2) selected.removeAt(0); selected.add(n); }
            }
          });
        }

        return AlertDialog(
          title: const Text('选择性格 (最多2个)'),
          content: SizedBox(width: 400, child: SingleChildScrollView(child: Wrap(spacing: 8, runSpacing: 8, children: naturesList.map((n) {
            final isSel = selected.contains(n);
            return InkWell(
              onTap: () => toggle(n),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: isSel ? Colors.green.shade100 : Colors.white, border: Border.all(color: isSel ? Colors.green : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Text(n, style: TextStyle(color: isSel ? Colors.green.shade800 : Colors.black)),
              ),
            );
          }).toList()))),
          actions: [
            TextButton(onPressed: () { toggle('混窝'); }, child: const Text('混窝', style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            ElevatedButton(onPressed: () {
              String natureStr = selected.isEmpty ? '未知' : selected.join('丨');
              String probStr = '随机';
              if (selected.length == 1 && selected.first != '混窝') probStr = '60%${selected.first}+40%随机';
              if (selected.length == 2) probStr = '30%${selected[0]}+30%${selected[1]}+40%随机';
              
              setState(() { _tempNature = natureStr; _tempNatureProb = probStr; });
              Navigator.pop(c);
            }, child: const Text('确定')),
          ],
        );
      }
    ));
  }

  // ======= 蛋组选择器 =======
  void _showGroupSelector() {
    showDialog(context: context, builder: (c) => StatefulBuilder(
      builder: (context, setDialogState) {
        List<String> selected = List.from(_tempGroups);
        void toggle(String g) {
          setDialogState(() {
            if (selected.contains(g)) selected.remove(g); 
            else { if (selected.length >= 2) selected.removeAt(0); selected.add(g); }
          });
        }

        return AlertDialog(
          title: const Text('选择蛋组 (最多2个)'),
          content: SizedBox(width: 400, child: SingleChildScrollView(child: Wrap(spacing: 8, runSpacing: 8, children: eggGroupsList.map((g) {
            final isSel = selected.contains(g);
            return InkWell(
              onTap: () => toggle(g),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: isSel ? Colors.green.shade100 : Colors.white, border: Border.all(color: isSel ? Colors.green : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Text(g, style: TextStyle(color: isSel ? Colors.green.shade800 : Colors.black)),
              ),
            );
          }).toList()))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            ElevatedButton(onPressed: () { setState(() => _tempGroups = selected); Navigator.pop(c); }, child: const Text('确定')),
          ],
        );
      }
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑产线' : '产线详情'),
        actions: [
          if (!_isEditing) IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true)),
        ],
      ),
      body: Column(
        children: [
          // ==== 顶部固定区 (蛋组及以上) ====
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    getLocalImage(_line.iconPath, 'egg_icons', size: 80),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEditing) 
                             OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.arrow_drop_down), label: Text(_tempName ?? '选择蛋名'))
                          else 
                             Text(_line.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _isEditing ? _showNatureSelector : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _tempNature == '混窝' ? Colors.red.shade50 : (_tempNature.contains('丨') ? Colors.yellow.shade50 : Colors.green.shade50),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: _isEditing ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : [],
                              ),
                              child: Text(_tempNature, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_tempNatureProb, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                // 蛋组与奖牌展示区
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    if (_isEditing) ...[
                      _buildEditTag('绿窝', _tempNestType == '绿窝', () => setState(() => _tempNestType = _tempNestType == '绿窝' ? '普窝' : '绿窝'), true),
                      ..._tempGroups.map((g) => _buildEditTag(g, true, () => setState(() => _tempGroups.remove(g)), false)),
                      _buildEditTag('+蛋组', false, _showGroupSelector, false),
                      ...sizeMedals.map((m) => _buildEditTag(m, _tempMedals.contains(m), () => setState(() { _tempMedals.contains(m) ? _tempMedals.remove(m) : _tempMedals.add(m); }), false)),
                      ...voiceMedals.map((m) => _buildEditTag(m, _tempMedals.contains(m), () => setState(() { _tempMedals.contains(m) ? _tempMedals.remove(m) : _tempMedals.add(m); }), false)),
                    ] else ...[
                      if (_line.nestType == '绿窝') Image.asset('assets/nest_types/green_nest.png', width: 24, height: 24),
                      ..._line.eggGroups.map((g) => Chip(label: Text(g), backgroundColor: Colors.grey.shade100)),
                      ..._line.medals.map((m) => Chip(label: Text(m), backgroundColor: Colors.blue.shade50)),
                    ]
                  ],
                )
              ],
            ),
          ),
          const Divider(thickness: 2),
          
          // ==== 下方滑动区（区间列表） ====
          Expanded(
            child: _rules.isEmpty ? const Center(child: Text('暂无区间，请点击下方添加')) : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _rules.length,
              itemBuilder: (context, i) {
                final r = _rules[i];
                return GestureDetector(
                  onSecondaryTap: () => _deleteRule(r.id!),
                  child: Slidable(
                    key: ValueKey(r.id),
                    enabled: _isEditing, // 只有编辑模式才允许滑出删除
                    endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteRule(r.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
                    child: ListTile(
                      leading: const Icon(Icons.balance, color: Colors.grey),
                      title: Text('${r.minWeight} kg ~ ${r.maxWeight} kg'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.monetization_on, color: Colors.amber), const SizedBox(width: 4), Text('${r.price} 元', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
                      onLongPress: _isEditing ? () => _deleteRule(r.id!) : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isEditing ? Padding(
        padding: const EdgeInsets.only(bottom: 80, right: 8), // 避开底部的保存按钮
        child: FloatingActionButton.extended(onPressed: _showAddRuleDialog, icon: const Icon(Icons.add), label: const Text('添加新区间')),
      ) : null,
      bottomNavigationBar: _isEditing ? Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: () { setState(() { _resetTemp(); _isEditing = false; }); }, child: const Text('取消'))),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: _saveChanges, child: const Text('保存并退出'))),
        ]),
      ) : null,
    );
  }

  Widget _buildEditTag(String label, bool isSelected, VoidCallback onTap, bool isNest) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade100 : Colors.white,
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade400, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.green.shade900 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ================= 新建产线页面 =================
class ProductionLineEditPage extends StatefulWidget {
  const ProductionLineEditPage({super.key});
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

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final db = await AppDatabase.instance.db;
    final accRows = await db.query('accounts');
    setState(() {
      _accounts = accRows.map(Account.fromMap).toList();
      if (_account.isEmpty && _accounts.isNotEmpty) _account = _accounts.first.name;
    });
    _loadPairings();
  }

  Future<void> _loadPairings() async {
    if (_account.isEmpty) return;
    final db = await AppDatabase.instance.db;
    final rows = await db.query('pairings', where: 'account = ?', whereArgs: [_account]);
    setState(() => _pairings = rows);
  }

  Future<void> _onPairingSelected(int pairingId) async {
    setState(() => _pairingId = pairingId);
    final db = await AppDatabase.instance.db;
    final mRows = await db.rawQuery('SELECT p.* FROM parents p JOIN pairings pa ON p.id = pa.mother_id WHERE pa.id = ?', [pairingId]);
    final fRows = await db.rawQuery('SELECT p.* FROM parents p JOIN pairing_fathers pf ON p.id = pf.father_id WHERE pf.pairing_id = ?', [pairingId]);
    
    if (mRows.isNotEmpty && fRows.isNotEmpty) {
      final mother = Parent.fromMap(mRows.first);
      final fathers = fRows.map(Parent.fromMap).toList();
      String result = calculateNature(fathers, mother);
      List<String> parts = result.split('|');
      setState(() { _nature = parts[0]; _natureProb = parts[1]; });
    }
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty || _pairingId == null) return;
    final db = await AppDatabase.instance.db;
    final acc = _accounts.firstWhere((a) => a.name == _account);
    
    final line = ProductionLine(
      name: _nameCtrl.text, accountName: _account, accountId: acc.accountId,
      nestType: _nestType, pairingId: _pairingId!, nature: _nature, natureProb: _natureProb, 
      medals: [], eggGroups: [],
    );
    await db.insert('production_lines', line.toMap());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增产线')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '产线名称 (蛋名)')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _account.isEmpty ? null : _account, decoration: const InputDecoration(labelText: '所属账号'),
          items: _accounts.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(),
          onChanged: (v) { setState(() { _account = v!; _pairingId = null; }); _loadPairings(); }
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildNestButton('普窝')),
          const SizedBox(width: 16),
          Expanded(child: _buildNestButton('绿窝')),
        ]),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _pairingId, decoration: const InputDecoration(labelText: '父母本配对组'),
          items: _pairings.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('组 ${p['id']} (母本ID: ${p['mother_id']})'))).toList(),
          onChanged: (v) => _onPairingSelected(v!),
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
        padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.center,
        decoration: BoxDecoration(color: isSelected ? Colors.green.shade50 : Colors.white, border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(16)),
        child: Text(type, style: TextStyle(color: isSelected ? Colors.green.shade800 : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
