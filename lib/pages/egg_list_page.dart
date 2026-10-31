import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lpinyin/lpinyin.dart';
import 'dart:io';
import '../db/database.dart';
import '../models/models.dart';

Widget _buildMedalChip(String medal) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Image.asset('assets/medals/${medalIconMap[medal] ?? medal}.png', width: 16, height: 16, errorBuilder: (c,e,s) => const Icon(Icons.military_tech, size: 16, color: Colors.grey)),
    const SizedBox(width: 4), Text(medal),
  ]);
}

class EggListPage extends StatefulWidget {
  final String viewType;
  const EggListPage({super.key, required this.viewType});
  @override
  State<EggListPage> createState() => EggListPageState();
}

class EggListPageState extends State<EggListPage> {
  List<Egg> _eggs = [];
  List<Account> _accounts = [];
  List<ProductionLine> _lines = [];
  
  String _searchQuery = '';
  String _sortType = '时间由近到远';
  final List<String> _sortTypes = ['时间由近到远', '时间由远到近', '蛋重高到低', '蛋重低到高'];
  
  Set<String> _filterTags = {}; 
  bool _filterMatchAll = false;
  String _filterAccount = '全部';
  String _filterLine = '全部';

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> loadData() async { await _loadData(); }

  Future<void> _loadData() async {
    final db = await AppDatabase.instance.db;
    final accRows = await db.query('accounts');
    final lineRows = await db.query('production_lines');
    List<Map<String, Object?>> rows;
    if (widget.viewType == '在库/预定') {
      rows = await db.query('eggs', where: 'status != ? AND status != ?', whereArgs: ['已售出', '需售后']);
    } else if (widget.viewType == '已售出') {
      rows = await db.query('eggs', where: 'status = ?', whereArgs: ['已售出']);
    } else {
      rows = await db.query('eggs', where: 'status = ?', whereArgs: ['需售后']);
    }
    if (!mounted) return;
    setState(() {
      _accounts = accRows.map(Account.fromMap).toList();
      _lines = lineRows.map(ProductionLine.fromMap).toList();
      _eggs = rows.map(Egg.fromMap).toList();
    });
  }

  void _deleteEgg(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('确认删除？'), content: const Text('删除后不可恢复！'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定删除', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('eggs', where: 'id = ?', whereArgs: [id]); _loadData(); }
  }

  // 居中弹窗选择器，解决图7遮挡问题
  void _showAlertPicker(String title, List<String> items, String current, Function(String) onSelect) {
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

  void _showFilterDialog() {
    Set<String> tempTags = Set.from(_filterTags);
    bool tempMatchAll = _filterMatchAll;
    String tempAcc = _filterAccount;
    String tempLine = _filterLine;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('筛选条件'),
            contentPadding: const EdgeInsets.only(top: 16),
            content: SizedBox(
              width: 350,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: () => _showAlertPicker('按账号筛选', ['全部', ..._accounts.map((a) => a.name)], tempAcc, (v) { setDialogState(() { tempAcc = v; tempLine = '全部'; }); }),
                        child: InputDecorator(decoration: const InputDecoration(labelText: '按账号筛选', suffixIcon: Icon(Icons.arrow_drop_down)), child: Text(tempAcc)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: () => _showAlertPicker('按产线筛选', ['全部', ..._lines.where((l) => tempAcc == '全部' || l.accountName == tempAcc).map((l) => l.name)], tempLine, (v) { setDialogState(() => tempLine = v); }),
                        child: InputDecorator(decoration: const InputDecoration(labelText: '按产线筛选', suffixIcon: Icon(Icons.arrow_drop_down)), child: Text(tempLine)),
                      ),
                    ),
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('特征条件组合：', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<bool>(
                            value: tempMatchAll,
                            items: const [DropdownMenuItem(value: false, child: Text('满足其一 (或)')), DropdownMenuItem(value: true, child: Text('全部满足 (且)'))],
                            onChanged: (v) => setDialogState(() => tempMatchAll = v!),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('已选特征：'),
                          TextButton(onPressed: () => setDialogState(() => tempTags.clear()), child: const Text('清空选择')),
                        ],
                      ),
                    ),
                    CheckboxListTile(
                      value: tempTags.contains('绿窝'),
                      title: Row(children: [Image.asset('assets/nest_types/green_nest.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.eco, size: 20, color: Colors.green)), const SizedBox(width: 8), const Text('绿窝')]),
                      onChanged: (v) => setDialogState(() { if (v!) { tempTags.add('绿窝'); } else { tempTags.remove('绿窝'); } }),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                    const Divider(),
                    ...sizeMedals.map((m) => CheckboxListTile(
                      value: tempTags.contains(m),
                      title: Row(children: [Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.military_tech, size: 20, color: Colors.grey)), const SizedBox(width: 8), Text(m)]),
                      onChanged: (v) => setDialogState(() { if (v!) { tempTags.add(m); } else { tempTags.remove(m); } }),
                      controlAffinity: ListTileControlAffinity.trailing,
                    )),
                    ...voiceMedals.map((m) => CheckboxListTile(
                      value: tempTags.contains(m),
                      title: Row(children: [Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.military_tech, size: 20, color: Colors.grey)), const SizedBox(width: 8), Text(m)]),
                      onChanged: (v) => setDialogState(() { if (v!) { tempTags.add(m); } else { tempTags.remove(m); } }),
                      controlAffinity: ListTileControlAffinity.trailing,
                    )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
              ElevatedButton(onPressed: () { setState(() { _filterTags = tempTags; _filterMatchAll = tempMatchAll; _filterAccount = tempAcc; _filterLine = tempLine; }); Navigator.pop(c); }, child: const Text('确定筛选')),
            ],
          );
        }
      ),
    );
  }

  Widget _buildEggIconWithBadges(Egg e) {
    bool hasMedals = e.medals.isNotEmpty;
    bool hasGreenNest = e.nestType == '绿窝';
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        getLocalImage(e.iconPath, 'egg_icons', size: 44),
        if (hasMedals || hasGreenNest) const SizedBox(width: 8),
        if (hasMedals || hasGreenNest)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMedals)
                Wrap(
                  spacing: 2,
                  children: e.medals.map((m) => Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 16, height: 16, errorBuilder: (c,e,s) => const Icon(Icons.star, size: 16, color: Colors.amber))).toList(),
                ),
              if (hasGreenNest)
                Padding(
                  padding: EdgeInsets.only(top: hasMedals ? 4 : 0),
                  child: Image.asset('assets/nest_types/green_nest.png', width: 16, height: 16, errorBuilder: (c,e,s) => const Icon(Icons.eco, color: Colors.green, size: 16)),
                ),
            ],
          ),
      ],
    );
  }

  // 核心修复图11：重置列表内的文字排列
  String _buildSubtitle(Egg e) {
    String priceStr = e.price != null ? '标价:${e.price}' : '标价:-';
    String dateStr = '收取:${e.obtainedDate}';
    String nestStr = e.nestType;
    
    // 构造奖牌字符串
    List<String> mList = [];
    if (e.medals.isNotEmpty) {
      mList.addAll(e.medals);
    }
    String medalStr = mList.isNotEmpty ? mList.join('、') : '无奖牌';
    
    if (widget.viewType != '在库/预定') {
      String buyer = e.buyerPlatformName ?? e.buyerGameName ?? '无';
      if (buyer.isEmpty) buyer = '无';
      String afterSales = e.isAfterSales ? ' [已售后]' : '';
      return '$priceStr | $dateStr | $nestStr\n奖牌: $medalStr\n买家: $buyer$afterSales';
    }
    
    return '$priceStr | $dateStr | $nestStr\n奖牌: $medalStr';
  }

  @override
  Widget build(BuildContext context) {
    var visible = _eggs.where((e) {
      bool matchAcc = _filterAccount == '全部' || e.account == _filterAccount;
      bool matchLine = _filterLine == '全部' || e.name == _filterLine;
      bool matchSearch = _searchQuery.isEmpty || e.name.contains(_searchQuery) || (e.buyerPlatformName ?? '').contains(_searchQuery) || (e.buyerGameName ?? '').contains(_searchQuery) || (e.nature ?? '').contains(_searchQuery);
      
      bool matchTags = true;
      if (_filterTags.isNotEmpty) {
        List<bool> conditions = [];
        for (var tag in _filterTags) {
          if (tag == '绿窝') { conditions.add(e.nestType == '绿窝'); } 
          else { conditions.add(e.medals.contains(tag)); }
        }
        matchTags = _filterMatchAll ? conditions.every((c) => c) : conditions.any((c) => c);
      }
      return matchAcc && matchLine && matchSearch && matchTags;
    }).toList();

    if (_sortType == '时间由近到远') visible.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    if (_sortType == '时间由远到近') visible.sort((a, b) => (a.createdAt ?? 0).compareTo(b.createdAt ?? 0));
    if (_sortType == '蛋重高到低') visible.sort((a, b) => b.weight.compareTo(a.weight));
    if (_sortType == '蛋重低到高') visible.sort((a, b) => a.weight.compareTo(b.weight));

    bool useAlphabetGroup = (widget.viewType != '在库/预定') && (_sortType == '时间由近到远' || _sortType == '时间由远到近');
    Map<String, List<Egg>> groupedEggs = {};
    List<String> alphabet = [];
    if (useAlphabetGroup) {
      for (var e in visible) {
        String buyer = e.buyerPlatformName ?? e.buyerGameName ?? '无';
        String firstLetter = 'Z';
        if (buyer != '无' && buyer.isNotEmpty) { try { firstLetter = PinyinHelper.getShortPinyin(buyer)[0].toUpperCase(); } catch (_) {} }
        if (firstLetter.codeUnitAt(0) < 65 || firstLetter.codeUnitAt(0) > 90) firstLetter = '#';
        if (!groupedEggs.containsKey(firstLetter)) groupedEggs[firstLetter] = [];
        groupedEggs[firstLetter]!.add(e);
      }
      alphabet = groupedEggs.keys.toList()..sort();
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(child: TextField(onChanged: (v) => setState(() => _searchQuery = v), decoration: const InputDecoration(hintText: '搜索名字/买家', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '筛选与过滤', 
                  icon: Icon(Icons.filter_alt, color: (_filterTags.isNotEmpty || _filterAccount != '全部' || _filterLine != '全部') ? Theme.of(context).colorScheme.primary : null), 
                  onPressed: _showFilterDialog
                ),
                PopupMenuButton<String>(icon: const Icon(Icons.sort), onSelected: (v) => setState(() => _sortType = v), itemBuilder: (c) => _sortTypes.map((s) => PopupMenuItem(value: s, child: Text(s))).toList()),
              ],
            ),
          ),
          Expanded(child: useAlphabetGroup ? _buildAlphabetList(groupedEggs, alphabet) : _buildNormalList(visible)),
        ],
      ),
      floatingActionButton: widget.viewType == '在库/预定' ? Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const EggEditPage())); _loadData(); }, child: const Icon(Icons.add)),
      ) : null,
    );
  }

  Widget _buildNormalList(List<Egg> list) {
    if (list.isEmpty) return const Center(child: Text('暂无数据'));
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100), 
      itemCount: list.length,
      itemBuilder: (context, i) {
        final e = list[i];
        final statusColor = e.status == '在库' ? Colors.green : (e.status == '需售后' ? Colors.orange : Colors.grey);
        String subtitleText = _buildSubtitle(e);

        return GestureDetector(
          onSecondaryTap: () => _deleteEgg(e.id!),
          child: Slidable(
            key: ValueKey(e.id),
            endActionPane: ActionPane(
              motion: const ScrollMotion(), 
              extentRatio: 0.25, 
              children: [SlidableAction(onPressed: (_) => _deleteEgg(e.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]
            ),
            child: InkWell(
              onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); _loadData(); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    const SizedBox(width: 8),
                    _buildEggIconWithBadges(e),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.name}  ${e.weight}kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(subtitleText, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
                        ],
                      ),
                    ),
                    Text(e.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlphabetList(Map<String, List<Egg>> groups, List<String> alphabet) {
    if (groups.isEmpty) return const Center(child: Text('暂无数据'));
    final Map<String, GlobalKey> sectionKeys = { for (var letter in alphabet) letter: GlobalKey() };
    
    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(right: 30, bottom: 100),
          children: alphabet.map((letter) {
            return Column(
              key: sectionKeys[letter],
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.grey.shade200, child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold))),
                ...groups[letter]!.map((e) {
                  String subtitleText = _buildSubtitle(e);
                  return GestureDetector(
                    onSecondaryTap: () => _deleteEgg(e.id!),
                    child: Slidable(
                      key: ValueKey(e.id),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(), 
                        extentRatio: 0.25, 
                        children: [SlidableAction(onPressed: (_) => _deleteEgg(e.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]
                      ),
                      child: InkWell(
                        onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); _loadData(); },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEggIconWithBadges(e),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${e.name}  ${e.weight}kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text(subtitleText, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
                                  ],
                                ),
                              ),
                              Text(e.status, style: TextStyle(color: e.status == '需售后' ? Colors.orange : Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                })
              ],
            );
          }).toList(),
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
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))),
                )).toList(),
              ),
            ),
          ),
        )
      ],
    );
  }
}

// ================= 录入/编辑精灵蛋 =================
class EggEditPage extends StatefulWidget {
  final Egg? egg;
  const EggEditPage({super.key, this.egg});
  @override
  State<EggEditPage> createState() => _EggEditPageState();
}

class _EggEditPageState extends State<EggEditPage> {
  final _nameCtrl = TextEditingController(), _weightCtrl = TextEditingController(), _natureCtrl = TextEditingController(), _priceCtrl = TextEditingController();
  final _salePlatformCtrl = TextEditingController(), _buyerPlatNameCtrl = TextEditingController(), _buyerPlatIdCtrl = TextEditingController(), _buyerGameNameCtrl = TextEditingController(), _buyerGameIdCtrl = TextEditingController();
  final _noteCtrl = TextEditingController(), _afterSalesCtrl = TextEditingController();
  
  String _status = '在库', _nestType = '普窝', _obtainedDate = DateTime.now().toString().substring(0, 10);
  String? _sizeMedal, _voiceMedal, _iconPath, _selectedAccount;
  String? _tempSelectedImagePath; 
  
  int? _pairingId;
  int? _lineId; 
  List<String> _eggGroups = []; 
  
  List<Account> _accounts = [];
  List<ProductionLine> _lines = [];
  bool _isOutOfRange = false;
  bool _isParentLocked = false; 
  bool _isAfterSales = false;

  @override
  void initState() {
    super.initState();
    if (widget.egg != null) {
      final e = widget.egg!;
      _nameCtrl.text = e.name; _weightCtrl.text = e.weight.toString(); _natureCtrl.text = e.nature ?? ''; _priceCtrl.text = e.price?.toString() ?? '';
      _salePlatformCtrl.text = e.salePlatform ?? ''; _buyerPlatNameCtrl.text = e.buyerPlatformName ?? '';
      _buyerPlatIdCtrl.text = e.buyerPlatformId ?? ''; _buyerGameNameCtrl.text = e.buyerGameName ?? '';
      _buyerGameIdCtrl.text = e.buyerGameId ?? ''; _noteCtrl.text = e.note ?? ''; _afterSalesCtrl.text = e.afterSalesPlan ?? '';
      _status = e.status; _nestType = e.nestType; _obtainedDate = e.obtainedDate; _iconPath = e.iconPath; _selectedAccount = e.account; _pairingId = e.pairingId; _isAfterSales = e.isAfterSales;
      _isParentLocked = true;
      for (var m in e.medals) { if (sizeMedals.contains(m)) _sizeMedal = m; if (voiceMedals.contains(m)) _voiceMedal = m; }
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await AppDatabase.instance.db;
    final accRows = await db.query('accounts');
    final lineRows = await db.query('production_lines');
    setState(() {
      _accounts = accRows.map(Account.fromMap).toList();
      _lines = lineRows.map(ProductionLine.fromMap).toList();
      if (_selectedAccount == null && _accounts.isNotEmpty) _selectedAccount = _accounts.first.name;
      
      if (widget.egg != null) {
         for (var l in _lines) {
           if (l.name == widget.egg!.name) {
             _eggGroups = List.from(l.eggGroups);
             break;
           }
         }
      }
    });
  }

  Future<void> _autoFillPrice(String weightStr) async {
    final weight = double.tryParse(weightStr);
    if (weight == null || _lineId == null) { setState(() => _isOutOfRange = false); return; }
    final db = await AppDatabase.instance.db;
    final rules = await db.query('line_price_rules', where: 'line_id = ?', whereArgs: [_lineId]);
    for (var r in rules) {
      if (weight >= (r['min_weight'] as double) && weight <= (r['max_weight'] as double)) {
        setState(() { _priceCtrl.text = (r['price'] as double).toString(); _isOutOfRange = false; }); return;
      }
    }
    setState(() => _isOutOfRange = true);
  }

  Future<void> _pickDate() async {
    final parts = _obtainedDate.split('-');
    final initialDate = parts.length == 3 ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])) : DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initialDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _obtainedDate = picked.toString().substring(0, 10));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写蛋名！'))); return; }
    if (_weightCtrl.text.trim().isEmpty || double.tryParse(_weightCtrl.text) == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写正确的重量！'))); return; }

    final db = await AppDatabase.instance.db;
    String? finalPath = await syncEggImage(_nameCtrl.text, _tempSelectedImagePath, widget.egg?.iconPath);
    
    String? fatherName, motherName;
    if (widget.egg != null && _isParentLocked) {
      fatherName = widget.egg!.fatherNameSnapshot; motherName = widget.egg!.motherNameSnapshot;
    } else if (_pairingId != null) {
      final mRows = await db.rawQuery('SELECT p.name FROM parents p JOIN pairings pa ON p.id = pa.mother_id WHERE pa.id = ?', [_pairingId]);
      final fRows = await db.rawQuery('SELECT p.name FROM parents p JOIN pairing_fathers pf ON p.id = pf.father_id WHERE pf.pairing_id = ?', [_pairingId]);
      if (mRows.isNotEmpty) motherName = mRows.first['name'] as String?;
      if (fRows.isNotEmpty) fatherName = fRows.map((e) => e['name'] as String).join('、');
    }

    final medals = <String>[]; if (_sizeMedal != null) medals.add(_sizeMedal!); if (_voiceMedal != null) medals.add(_voiceMedal!);
    if (_status == '需售后') _isAfterSales = true;

    final e = Egg(
      id: widget.egg?.id, name: _nameCtrl.text, weight: double.tryParse(_weightCtrl.text) ?? 0, medals: medals, nature: _natureCtrl.text, price: double.tryParse(_priceCtrl.text), status: _status, iconPath: finalPath, createdAt: widget.egg?.createdAt, 
      salePlatform: _salePlatformCtrl.text, buyerPlatformName: _buyerPlatNameCtrl.text, buyerPlatformId: _buyerPlatIdCtrl.text, buyerGameName: _buyerGameNameCtrl.text, buyerGameId: _buyerGameIdCtrl.text, note: _noteCtrl.text,
      nestType: _nestType, obtainedDate: _obtainedDate, account: _selectedAccount, 
      pairingId: _pairingId, 
      fatherNameSnapshot: fatherName, motherNameSnapshot: motherName, afterSalesPlan: _afterSalesCtrl.text, isAfterSales: _isAfterSales,
    );
    if (e.id == null) { await db.insert('eggs', e.toMap()); } else { await db.update('eggs', e.toMap(), where: 'id=?', whereArgs: [e.id]); }
    if (mounted) Navigator.pop(context);
  }

  void _showAlertPicker(String title, List<String> items, String current, Function(String) onSelect) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
        contentPadding: const EdgeInsets.only(top: 16, bottom: 0),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
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
    bool isReadOnly = _status == '已售出' || _status == '需售后'; 
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.egg == null ? '新增精灵蛋' : '编辑精灵蛋')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          _tempSelectedImagePath != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_tempSelectedImagePath!), width: 60, height: 60, fit: BoxFit.cover)) : getLocalImage(_iconPath, 'egg_icons', size: 60),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: () async { final res = await FilePicker.platform.pickFiles(type: FileType.image); if (res != null && res.files.single.path != null) setState(() => _tempSelectedImagePath = res.files.single.path!); }, icon: const Icon(Icons.image), label: const Text('选图')),
        ]),
        const SizedBox(height: 16),
        
        InkWell(
          onTap: isReadOnly ? null : () => _showAlertPicker('选择产线', _lines.map((e) => e.name).toList(), _nameCtrl.text, (v) {
            final line = _lines.firstWhere((element) => element.name == v);
            setState(() {
              _lineId = line.id;
              _nameCtrl.text = line.name;
              _natureCtrl.text = line.nature;
              _nestType = line.nestType;
              _pairingId = line.pairingId;
              _selectedAccount = line.accountName;
              _iconPath = line.iconPath;
              _eggGroups = List.from(line.eggGroups);
              _isParentLocked = true;
            });
            _autoFillPrice(_weightCtrl.text);
          }),
          child: InputDecorator(decoration: const InputDecoration(labelText: '选择产线 (自动填充信息)', suffixIcon: Icon(Icons.arrow_drop_down)), child: Text(_nameCtrl.text.isEmpty ? '请选择产线' : _nameCtrl.text)),
        ),
        
        if (_eggGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: _eggGroups.map((g) => Padding(padding: const EdgeInsets.only(right: 8), child: Chip(label: Text(g), backgroundColor: Colors.grey.shade100))).toList(),
            ),
          ),

        const SizedBox(height: 16),
        // 核心修复图1：选过产线后，窝类型不可修改
        Row(children: [
          Expanded(child: _buildNestButton('普窝', isReadOnly || _nameCtrl.text.isNotEmpty)),
          const SizedBox(width: 16),
          Expanded(child: _buildNestButton('绿窝', isReadOnly || _nameCtrl.text.isNotEmpty)),
        ]),

        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(controller: _weightCtrl, enabled: !isReadOnly, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '重量(kg)', errorText: _isOutOfRange ? '不在范围内' : null), onChanged: _autoFillPrice)),
          const SizedBox(width: 16),
          Expanded(child: TextField(controller: _natureCtrl, enabled: false, decoration: const InputDecoration(labelText: '性格 (自动推导)'))),
        ]),
        
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(controller: _priceCtrl, enabled: !isReadOnly, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '标价'))),
          const SizedBox(width: 16),
          Expanded(child: InkWell(onTap: isReadOnly ? null : _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: '收取日期'), child: Text(_obtainedDate)))),
        ]),

        const SizedBox(height: 24),
        const Text('体型/重量奖牌 (单选)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: sizeMedals.map((m) => ChoiceChip(label: _buildMedalChip(m), selected: _sizeMedal == m, onSelected: isReadOnly ? null : (v) => setState(() => _sizeMedal = v ? m : null))).toList()),
        
        const SizedBox(height: 24),
        const Text('声音奖牌 (单选)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: voiceMedals.map((m) => ChoiceChip(label: _buildMedalChip(m), selected: _voiceMedal == m, onSelected: isReadOnly ? null : (v) => setState(() => _voiceMedal = v ? m : null))).toList()),
        
        const SizedBox(height: 24),
        InkWell(
          onTap: () => _showAlertPicker('选择状态', ['在库', '已预定', '已售出', '需售后'], _status, (v) => setState(() => _status = v)),
          child: InputDecorator(decoration: const InputDecoration(labelText: '状态', suffixIcon: Icon(Icons.arrow_drop_down)), child: Text(_status)),
        ),
        
        const SizedBox(height: 32),
        const Text('买家与交易信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
        const Divider(),
        const SizedBox(height: 8),
        TextField(controller: _salePlatformCtrl, decoration: const InputDecoration(labelText: '售卖平台')),
        const SizedBox(height: 12),
        TextField(controller: _buyerPlatNameCtrl, decoration: const InputDecoration(labelText: '买家平台名称')),
        const SizedBox(height: 12),
        TextField(controller: _buyerPlatIdCtrl, decoration: const InputDecoration(labelText: '买家平台ID')),
        const SizedBox(height: 12),
        TextField(controller: _buyerGameNameCtrl, decoration: const InputDecoration(labelText: '买家游戏名称')),
        const SizedBox(height: 12),
        TextField(controller: _buyerGameIdCtrl, decoration: const InputDecoration(labelText: '买家游戏ID')),
        
        const SizedBox(height: 32),
        const Text('其他', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
        const Divider(),
        const SizedBox(height: 8),
        TextField(controller: _noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '备注')),
        const SizedBox(height: 12),
        TextField(controller: _afterSalesCtrl, enabled: _status == '需售后', maxLines: 3, decoration: const InputDecoration(labelText: '售后方案（仅需售后状态可填写）')),

        const SizedBox(height: 80),
      ]),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.extended(onPressed: _save, backgroundColor: Colors.green, foregroundColor: Colors.white, heroTag: 'save', icon: const Icon(Icons.check), label: const Text('保存')),
            const SizedBox(width: 16),
            FloatingActionButton.extended(
              onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('放弃修改？'), actions: [TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定')), TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消'))]));
                if (confirm == true && context.mounted) Navigator.pop(context);
              }, 
              backgroundColor: Colors.red, foregroundColor: Colors.white, heroTag: 'cancel', icon: const Icon(Icons.close), label: const Text('取消'),
            ),
          ]
        ),
      ),
    );
  }

  Widget _buildNestButton(String type, bool isReadOnly) {
    bool isSelected = _nestType == type;
    return InkWell(
      onTap: isReadOnly ? null : () {
        setState(() => _nestType = type);
        _autoFillPrice(_weightCtrl.text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? (isReadOnly ? Colors.grey.shade300 : Colors.green.shade50) : Colors.white,
          border: Border.all(color: isSelected ? (isReadOnly ? Colors.grey : Colors.green) : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(type, style: TextStyle(color: isSelected ? (isReadOnly ? Colors.grey.shade700 : Colors.green.shade800) : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
