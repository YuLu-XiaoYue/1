import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:convert';
import '../db/database.dart';
import '../models/models.dart';

class ProductionLinePage extends StatefulWidget {
  final Color cardColor;
  const ProductionLinePage({super.key, this.cardColor = Colors.white});
  
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
      title: const Text('确认删除产线？'), content: const Text('删除后，该产线及定价规则将消失。'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定删除', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) { 
      final db = await AppDatabase.instance.db; 
      await db.delete('production_lines', where: 'id = ?', whereArgs: [id]); 
      await db.delete('line_price_rules', where: 'line_id = ?', whereArgs: [id]);
      _load(); 
    }
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 800 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82, 
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final line = visible[i];
                    return GestureDetector(
                      onSecondaryTap: () => _deleteLine(line.id!),
                      child: Slidable(
                        key: ValueKey(line.id),
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(), extentRatio: 0.25,
                          children: [SlidableAction(onPressed: (_) => _deleteLine(line.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')],
                        ),
                        child: Card(
                          color: widget.cardColor,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductionLineEditPage(line: line)));
                              _load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      getLocalImage(line.iconPath, 'egg_icons', size: 36),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(line.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                      const Icon(Icons.edit, size: 16, color: Colors.grey), 
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: line.nature == '混窝' ? Colors.red.shade50 : (line.nature.contains('丨') ? Colors.yellow.shade50 : Colors.green.shade50),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300)
                                    ),
                                    child: Text(line.nature, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(line.natureProb, style: const TextStyle(fontSize: 9, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                  
                                  const Spacer(),
                                  
                                  if (line.eggGroups.isNotEmpty || line.medals.isNotEmpty || line.nestType == '绿窝')
                                    Wrap(
                                      spacing: 4, runSpacing: 4,
                                      children: [
                                        if (line.nestType == '绿窝') Image.asset('assets/nest_types/green_nest.png', width: 16, height: 16),
                                        ...line.eggGroups.map((g) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                          child: Text(g, style: const TextStyle(fontSize: 9)),
                                        )),
                                        ...line.medals.map((m) => Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 16, height: 16)),
                                      ],
                                    ),
                                  const Divider(height: 16),
                                  Expanded(child: _buildMiniRules(line.id!)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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

  Widget _buildMiniRules(int lineId) {
    return FutureBuilder<List<LinePriceRule>>(
      future: AppDatabase.instance.db.then((db) => db.query('line_price_rules', where: 'line_id = ?', whereArgs: [lineId], orderBy: 'min_weight ASC')).then((rows) => rows.map(LinePriceRule.fromMap).toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('无区间', style: TextStyle(fontSize: 12, color: Colors.grey)));
        final rules = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.zero, physics: const NeverScrollableScrollPhysics(),
          itemCount: rules.length > 2 ? 2 : rules.length,
          itemBuilder: (context, i) {
            final r = rules[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${r.minWeight}~${r.maxWeight}kg', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  Text('${r.price}元', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          },
        );
      }
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
  List<String> _eggGroups = [];
  List<String> _medals = []; 
  String? _iconPath;
  
  List<Account> _accounts = [];
  List<Map<String, dynamic>> _pairings = [];
  List<LinePriceRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.line != null) {
      final l = widget.line!;
      _nameCtrl.text = l.name; _account = l.accountName; _nestType = l.nestType; _pairingId = l.pairingId; 
      _nature = l.nature; _natureProb = l.natureProb; _eggGroups = List.from(l.eggGroups); _iconPath = l.iconPath;
      _medals = List.from(l.medals);
      _loadRules(l.id!);
    }
  }

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

  Future<void> _loadRules(int lineId) async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('line_price_rules', where: 'line_id = ?', whereArgs: [lineId], orderBy: 'min_weight ASC');
    setState(() => _rules = rows.map(LinePriceRule.fromMap).toList());
  }

  Future<void> _onNameChanged(String name) async {
    if (name.isEmpty) return;
    final db = await AppDatabase.instance.db;
    final rows = await db.query('creatures');
    final creatures = rows.map(Creature.fromMap).toList();
    
    for (var c in creatures) {
      if (name.contains(c.name)) {
        setState(() { _eggGroups = List.from(c.eggGroups); _iconPath = c.iconPath; });
        return;
      }
    }
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

  void _toggleMedal(String medal) {
    setState(() {
      if (_medals.contains(medal)) {
        _medals.remove(medal);
      } else {
        if (sizeMedals.contains(medal)) {
          _medals.removeWhere((m) => sizeMedals.contains(m));
        } else if (voiceMedals.contains(medal)) {
          _medals.removeWhere((m) => voiceMedals.contains(m));
        }
        _medals.add(medal);
      }
    });
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写产线名称！'))); return; }
    if (_pairingId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择配对组！'))); return; }
    
    final db = await AppDatabase.instance.db;
    final acc = _accounts.firstWhere((a) => a.name == _account);
    
    final line = ProductionLine(
      id: widget.line?.id, name: _nameCtrl.text, accountName: _account, accountId: acc.accountId,
      nestType: _nestType, pairingId: _pairingId!, nature: _nature, natureProb: _natureProb, 
      medals: _medals, eggGroups: _eggGroups, iconPath: _iconPath,
    );
    if (line.id == null) { 
      final id = await db.insert('production_lines', line.toMap()); 
      for (var r in _rules) { await db.insert('line_price_rules', {'line_id': id, 'min_weight': r.minWeight, 'max_weight': r.maxWeight, 'price': r.price}); }
    } else { 
      await db.update('production_lines', line.toMap(), where: 'id=?', whereArgs: [line.id]); 
    }
    if (mounted) Navigator.pop(context);
  }

  void _showAddRuleDialog() {
    final minCtrl = TextEditingController(), maxCtrl = TextEditingController(), priceCtrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('添加区间'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: minCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '最小蛋重 (kg)')),
        TextField(controller: maxCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '最大蛋重 (kg)')),
        TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '标价 (元)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          final min = double.tryParse(minCtrl.text), max = double.tryParse(maxCtrl.text), price = double.tryParse(priceCtrl.text);
          if (min != null && max != null && price != null) {
            setState(() { _rules.add(LinePriceRule(lineId: widget.line?.id ?? -1, minWeight: min, maxWeight: max, price: price)); });
            if (widget.line != null) {
              final db = await AppDatabase.instance.db;
              await db.insert('line_price_rules', {'line_id': widget.line!.id, 'min_weight': min, 'max_weight': max, 'price': price});
              _loadRules(widget.line!.id!);
            }
            if (mounted) Navigator.pop(c);
          }
        }, child: const Text('确定')),
      ],
    ));
  }

  void _deleteRule(int index) async {
    if (widget.line != null && _rules[index].id != null) {
      final db = await AppDatabase.instance.db;
      await db.delete('line_price_rules', where: 'id = ?', whereArgs: [_rules[index].id]);
      _loadRules(widget.line!.id!);
    } else {
      setState(() => _rules.removeAt(index));
    }
  }

  void _showPairingPicker() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('选择配对组', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
        contentPadding: const EdgeInsets.only(top: 16, bottom: 0),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _pairings.length,
            itemBuilder: (context, i) {
              final p = _pairings[i];
              String name = p['group_name'] ?? '';
              String display = '组 ${i+1}';
              if (name.isNotEmpty) display += ' - $name';
              return InkWell(
                onTap: () { 
                  _onPairingSelected(p['id'] as int);
                  Navigator.pop(c); 
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      child: Text(display, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                    ),
                    if (_pairingId == p['id'])
                      Positioned(
                        right: 16,
                        child: Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [ Center(child: TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消'))) ],
      ),
    );
  }

  void _showAlertPicker(String title, List<String> items, String? current, Function(String) onSelect) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
        contentPadding: const EdgeInsets.only(top: 16, bottom: 0),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true, itemCount: items.length,
            itemBuilder: (context, i) => InkWell(
              onTap: () { onSelect(items[i]); Navigator.pop(c); },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(items[i], style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                  ),
                  if (current == items[i])
                    Positioned(
                      right: 16,
                      child: Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [ Center(child: TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消'))) ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String pairingDisplay = '请选择配对组';
    if (_pairingId != null) {
      int idx = _pairings.indexWhere((p) => p['id'] == _pairingId);
      if (idx != -1) {
        String name = _pairings[idx]['group_name'] ?? '';
        pairingDisplay = '组 ${idx+1}';
        if (name.isNotEmpty) pairingDisplay += ' - $name';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.line == null ? '新增产线' : '编辑产线'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _save, 
              icon: const Icon(Icons.save), 
              label: const Text('保存')
            ),
          )
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '产线名称 (蛋名)', suffixIcon: Icon(Icons.edit)), onChanged: _onNameChanged),
        
        if (_iconPath != null || _eggGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                if (_iconPath != null) getLocalImage(_iconPath, 'egg_icons', size: 40),
                const SizedBox(width: 12),
                ..._eggGroups.map((g) => Padding(padding: const EdgeInsets.only(right: 8), child: Chip(label: Text(g), backgroundColor: Colors.grey.shade100))),
              ],
            ),
          ),

        const SizedBox(height: 16),
        InkWell(
          onTap: () => _showAlertPicker('选择账号', _accounts.map((e) => e.name).toList(), _account, (v) { setState(() { _account = v; _pairingId = null; }); _loadPairings(); }),
          child: InputDecorator(decoration: const InputDecoration(labelText: '所属账号', suffixIcon: Icon(Icons.arrow_drop_down)), child: Text(_account)),
        ),

        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildNestButton('普窝')),
          const SizedBox(width: 16),
          Expanded(child: _buildNestButton('绿窝')),
        ]),

        const SizedBox(height: 16),
        InkWell(
          onTap: _showPairingPicker,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: '父母本配对组', suffixIcon: Icon(Icons.arrow_drop_down)), 
            child: Text(pairingDisplay),
          ),
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
        ),

        const SizedBox(height: 24),
        const Text('产线奖牌 (单选互斥)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ...sizeMedals.map((m) => FilterChip(
              avatar: Image.asset('assets/medals/${medalIconMap[m]}.png', width: 18, height: 18, errorBuilder: (c,e,s) => const Icon(Icons.star, size: 18)),
              label: Text(m),
              selected: _medals.contains(m),
              onSelected: (v) => _toggleMedal(m),
            )),
            ...voiceMedals.map((m) => FilterChip(
              avatar: Image.asset('assets/medals/${medalIconMap[m]}.png', width: 18, height: 18, errorBuilder: (c,e,s) => const Icon(Icons.star, size: 18)),
              label: Text(m),
              selected: _medals.contains(m),
              onSelected: (v) => _toggleMedal(m),
            )),
          ],
        ),

        const Divider(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('价格区间', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(onPressed: _showAddRuleDialog, icon: const Icon(Icons.add), label: const Text('添加新区间')),
          ],
        ),
        if (_rules.isEmpty) const Center(child: Text('暂无区间', style: TextStyle(color: Colors.grey))),
        ..._rules.asMap().entries.map((entry) {
          final i = entry.key; final r = entry.value;
          return ListTile(
            leading: const Icon(Icons.balance),
            title: Text('${r.minWeight} ~ ${r.maxWeight} kg'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${r.price} 元', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _deleteRule(i)),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 80),
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
