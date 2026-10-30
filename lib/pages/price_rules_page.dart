import 'package:flutter/material.dart';
import '../db/database.dart';

class PriceRulesPage extends StatefulWidget {
  const PriceRulesPage({super.key});
  @override
  State<PriceRulesPage> createState() => _PriceRulesPageState();
}

class _PriceRulesPageState extends State<PriceRulesPage> {
  List<Map<String, dynamic>> _rules = [];
  List<String> _categories = [];
  String _currentCategory = '';

  @override
  void initState() { super.initState(); _loadCategories(); }

  Future<void> _loadCategories() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('egg_categories');
    if (!mounted) return;
    setState(() {
      _categories = rows.map((r) => r['name'] as String).toList();
      if (_categories.isNotEmpty && !_categories.contains(_currentCategory)) {
        _currentCategory = _categories.first;
      }
      _loadRules();
    });
  }

  Future<void> _loadRules() async {
    if (_currentCategory.isEmpty) { setState(() => _rules = []); return; }
    final db = await AppDatabase.instance.db;
    final rows = await db.query('price_rules', where: 'category = ?', whereArgs: [_currentCategory], orderBy: 'min_weight ASC');
    setState(() => _rules = rows);
  }

  void _showAddDialog() {
    if (_currentCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先去精灵蛋页面添加分类Tab！')));
      return;
    }

    final minCtrl = TextEditingController(), maxCtrl = TextEditingController(), priceCtrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text('新增 [$_currentCategory] 价格规则'),
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
            await db.insert('price_rules', {'category': _currentCategory, 'min_weight': min, 'max_weight': max, 'price': price});
            if (mounted) Navigator.pop(c);
            _loadRules();
          }
        }, child: const Text('保存')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('蛋重价格规则')),
      body: Column(
        children: [
          // 分类 Tab
          if (_categories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories.map((cat) => InkWell(
                  onTap: () { setState(() => _currentCategory = cat); _loadRules(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24), alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _currentCategory == cat ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))),
                    child: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: _currentCategory == cat ? Theme.of(context).colorScheme.primary : Colors.grey)),
                  ),
                )).toList(),
              ),
            ),
          
          Expanded(
            child: _categories.isEmpty 
              ? const Center(child: Text('暂无分类，请先去精灵蛋页添加分类'))
              : _rules.isEmpty ? const Center(child: Text('该分类暂无规则，点击右下角添加')) : ListView.builder(
                itemCount: _rules.length,
                itemBuilder: (context, i) {
                  final r = _rules[i];
                  return ListTile(
                    title: Text('${r['min_weight']} kg ～ ${r['max_weight']} kg'),
                    trailing: Text('${r['price']} 元', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    onLongPress: () async {
                      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                        title: const Text('删除规则？'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定'))],
                      ));
                      if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('price_rules', where: 'id=?', whereArgs: [r['id']]); _loadRules(); }
                    },
                  );
                },
              ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)),
    );
  }
}
