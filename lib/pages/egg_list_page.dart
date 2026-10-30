import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lpinyin/lpinyin.dart';
import '../db/database.dart';
import '../models/models.dart';
import 'parent_page.dart'; 

const Map<String, String> medalIconMap = {
  '大块头': 'big_body', '满重': 'full_weight', '小不点': 'tiny', '满轻': 'full_light',
  '婉转声': 'gentle_voice', '满音婉转声': 'full_gentle_voice', '粗嗓门': 'rough_voice', '满音粗嗓门': 'full_rough_voice',
};

Widget _buildMedalChip(String medal) {
  final fileName = medalIconMap[medal] ?? medal;
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Image.asset('assets/medals/$fileName.png', width: 16, height: 16, errorBuilder: (c,e,s) => const Icon(Icons.military_tech, size: 16, color: Colors.grey)),
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
  List<String> _categories = ['全部'];
  String _currentCategory = '全部';
  
  String _searchQuery = '';
  String _sortType = '时间由近到远';
  final List<String> _sortTypes = ['时间由近到远', '时间由远到近', '蛋重高到低', '蛋重低到高'];
  
  Set<String> _filterTags = {};
  bool _filterMatchAll = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() { super.initState(); _loadCategories(); _load(); }

  Future<void> loadData() async {
    await _load();
  }

  Future<void> _loadCategories() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('egg_categories');
    if (!mounted) return;
    setState(() { _categories = ['全部', ...rows.map((r) => r['name'] as String)]; });
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.db;
    List<Map<String, Object?>> rows;
    if (widget.viewType == '在库/预定') {
      rows = await db.query('eggs', where: 'status != ? AND status != ?', whereArgs: ['已售出', '需售后']);
    } else if (widget.viewType == '已售出') {
      rows = await db.query('eggs', where: 'status = ?', whereArgs: ['已售出']);
    } else {
      rows = await db.query('eggs', where: 'status = ?', whereArgs: ['需售后']);
    }
    if (!mounted) return;
    setState(() => _eggs = rows.map(Egg.fromMap).toList());
  }

  void _addCategory() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('新增分类Tab'), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: '分类名称 (如: 小黑猫)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.isNotEmpty) { final db = await AppDatabase.instance.db; await db.insert('egg_categories', {'name': ctrl.text}); if (mounted) Navigator.pop(c); _loadCategories(); }
        }, child: const Text('添加')),
      ],
    ));
  }

  void _deleteEgg(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('确认删除？'), content: const Text('删除后不可恢复！'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定删除', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('eggs', where: 'id = ?', whereArgs: [id]); _load(); }
  }

  void _showFilterDialog() {
    Set<String> tempTags = Set.from(_filterTags);
    bool tempMatchAll = _filterMatchAll;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('筛选条件'),
            contentPadding: const EdgeInsets.only(top: 16),
            content: SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('条件组合：', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<bool>(
                            value: tempMatchAll,
                            items: const [
                              DropdownMenuItem(value: false, child: Text('满足其一 (或)')),
                              DropdownMenuItem(value: true, child: Text('全部满足 (且)')),
                            ],
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
                          const Text('已选条件：'),
                          TextButton(
                            onPressed: () => setDialogState(() => tempTags.clear()),
                            child: const Text('清空选择'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    
                    CheckboxListTile(
                      value: tempTags.contains('绿窝'),
                      title: Row(children: [
                        Image.asset('assets/nest_types/green_nest.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.eco, size: 20, color: Colors.green)),
                        const SizedBox(width: 8),
                        const Text('绿窝'),
                      ]),
                      onChanged: (v) => setDialogState(() { if (v!) { tempTags.add('绿窝'); } else { tempTags.remove('绿窝'); } }),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                    const Divider(),
                    
                    ...sizeMedals.map((m) => CheckboxListTile(
                      value: tempTags.contains(m),
                      title: Row(children: [
                        Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.military_tech, size: 20, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Text(m),
                      ]),
                      onChanged: (v) => setDialogState(() { if (v!) { tempTags.add(m); } else { tempTags.remove(m); } }),
                      controlAffinity: ListTileControlAffinity.trailing,
                    )),
                    ...voiceMedals.map((m) => CheckboxListTile(
                      value: tempTags.contains(m),
                      title: Row(children: [
                        Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.military_tech, size: 20, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Text(m),
                      ]),
                      onChanged: (v) => setDialogState(() { if (v!) { tempTags.add(m); } else { tempTags.remove(m); } }),
                      controlAffinity: ListTileControlAffinity.trailing,
                    )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filterTags = tempTags;
                    _filterMatchAll = tempMatchAll;
                  });
                  Navigator.pop(c);
                }, 
                child: const Text('确定筛选')
              ),
            ],
          );
        }
      ),
    );
  }

  // --- 核心修改：把角标从图片上方移到右侧 ---
  Widget _buildEggIconWithBadges(Egg e) {
    bool hasMedals = e.medals.isNotEmpty;
    bool hasGreenNest = e.nestType == '绿窝';
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, // 图片与角标垂直居中对齐
      children: [
        getLocalImage(e.iconPath, 'egg_icons', size: 44),
        if (hasMedals || hasGreenNest)
          const SizedBox(width: 8), // 图片和角标的间距
        if (hasMedals || hasGreenNest)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 奖牌（上方）
              if (hasMedals)
                Wrap(
                  spacing: 2,
                  children: e.medals.map((m) => Image.asset(
                    'assets/medals/${medalIconMap[m] ?? m}.png', 
                    width: 16, height: 16
                  )).toList(),
                ),
              // 绿窝（下方）
              if (hasGreenNest)
                Padding(
                  padding: EdgeInsets.only(top: hasMedals ? 4 : 0),
                  child: Image.asset('assets/nest_types/green_nest.png', width: 16, height: 16),
                ),
            ],
          ),
      ],
    );
  }
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    var visible = _eggs.where((e) {
      bool matchTab = _currentCategory == '全部' || e.name.contains(_currentCategory);
      bool matchSearch = _searchQuery.isEmpty || e.name.contains(_searchQuery) || (e.buyerPlatformName ?? '').contains(_searchQuery) || (e.buyerGameName ?? '').contains(_searchQuery) || (e.nature ?? '').contains(_searchQuery);
      
      bool matchTags = true;
      if (_filterTags.isNotEmpty) {
        List<bool> conditions = [];
        for (var tag in _filterTags) {
          if (tag == '绿窝') {
            conditions.add(e.nestType == '绿窝');
          } else {
            conditions.add(e.medals.contains(tag));
          }
        }
        
        if (_filterMatchAll) {
          matchTags = conditions.every((c) => c == true);
        } else {
          matchTags = conditions.any((c) => c == true);
        }
      }
      
      return matchTab && matchSearch && matchTags;
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
        if (buyer != '无' && buyer.isNotEmpty) {
          try { firstLetter = PinyinHelper.getShortPinyin(buyer)[0].toUpperCase(); } catch (_) {}
        }
        if (firstLetter.codeUnitAt(0) < 65 || firstLetter.codeUnitAt(0) > 90) firstLetter = '#';
        if (!groupedEggs.containsKey(firstLetter)) groupedEggs[firstLetter] = [];
        groupedEggs[firstLetter]!.add(e);
      }
      alphabet = groupedEggs.keys.toList()..sort();
    }

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
                    children: _categories.map((cat) => InkWell(
                      onTap: () => setState(() => _currentCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20), alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _currentCategory == cat ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))),
                        child: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: _currentCategory == cat ? Theme.of(context).colorScheme.primary : Colors.grey)),
                      ),
                    )).toList(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addCategory),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(child: TextField(onChanged: (v) => setState(() => _searchQuery = v), decoration: const InputDecoration(hintText: '搜索名字/买家', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                
                IconButton(
                  tooltip: '筛选与过滤',
                  icon: Icon(Icons.filter_alt, color: _filterTags.isNotEmpty ? Theme.of(context).colorScheme.primary : null),
                  onPressed: _showFilterDialog,
                ),
                
                PopupMenuButton<String>(
                  tooltip: '排序方式',
                  icon: const Icon(Icons.sort),
                  onSelected: (v) => setState(() => _sortType = v),
                  itemBuilder: (c) => _sortTypes.map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: useAlphabetGroup ? _buildAlphabetList(groupedEggs, alphabet) : _buildNormalList(visible),
          ),
        ],
      ),
      floatingActionButton: widget.viewType == '在库/预定' ? Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: FloatingActionButton(
          onPressed: () async { 
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const EggEditPage())); 
            _load(); 
          }, 
          child: const Icon(Icons.add)
        ),
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
        
        String buyerText = e.buyerPlatformName ?? e.buyerGameName ?? '无';
        if (buyerText.isEmpty) buyerText = '无';
        String afterSalesTag = (e.isAfterSales && widget.viewType != '售后订单') ? ' | 已售后' : '';
        String subtitleText = widget.viewType != '在库/预定' ? '买家: $buyerText$afterSalesTag' : '收取: ${e.obtainedDate} | 标价:${e.price ?? "-"}';

        return GestureDetector(
          onSecondaryTap: () => _deleteEgg(e.id!),
          child: Slidable(
            key: ValueKey(e.id),
            extentRatio: 0.25, 
            endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteEgg(e.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
            child: InkWell(
              onTap: () async { 
                await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); 
                _load(); 
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    const SizedBox(width: 8),
                    _buildEggIconWithBadges(e),
                    const SizedBox(width: 16), // 角标和文字的间距
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.name}  ${e.weight}kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(subtitleText, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                  String buyerText = e.buyerPlatformName ?? e.buyerGameName ?? '无';
                  if (buyerText.isEmpty) buyerText = '无';
                  String afterSalesTag = (e.isAfterSales && widget.viewType != '售后订单') ? ' | 已售后' : '';
                  String subtitleText = '买家: $buyerText$afterSalesTag';

                  return GestureDetector(
                    onSecondaryTap: () => _deleteEgg(e.id!),
                    child: Slidable(
                      key: ValueKey(e.id),
                      extentRatio: 0.25, 
                      endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteEgg(e.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
                      child: InkWell(
                        onTap: () async { 
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); 
                          _load(); 
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              _buildEggIconWithBadges(e),
                              const SizedBox(width: 16), // 角标和文字的间距
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${e.name}  ${e.weight}kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text(subtitleText, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
  
  int? _pairingId;
  Parent? _selectedMother;
  List<Parent> _groupFathers = []; 
  
  List<Account> _accounts = [];
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
      
      if (_pairingId != null) {
        _isParentLocked = true;
        _loadGroupData(_pairingId!);
      } else if (e.motherId != null || e.fatherId != null) {
         _isParentLocked = true;
         _loadLegacyParentData(e.motherId, e.fatherId);
      }
      for (var m in e.medals) { if (sizeMedals.contains(m)) _sizeMedal = m; if (voiceMedals.contains(m)) _voiceMedal = m; }
    }
    _loadAccounts();
  }

  Future<void> _loadLegacyParentData(int? mId, int? fId) async {
    final db = await AppDatabase.instance.db;
    if (mId != null) {
      final rows = await db.query('parents', where: 'id = ?', whereArgs: [mId]);
      if (rows.isNotEmpty) setState(() => _selectedMother = Parent.fromMap(rows.first));
    }
    if (fId != null) {
      final rows = await db.query('parents', where: 'id = ?', whereArgs: [fId]);
      if (rows.isNotEmpty) setState(() => _groupFathers = [Parent.fromMap(rows.first)]);
    }
  }

  Future<void> _loadGroupData(int pairingId) async {
    final db = await AppDatabase.instance.db;
    final pRows = await db.query('pairings', where: 'id = ?', whereArgs: [pairingId]);
    if (pRows.isEmpty) return;
    final p = pRows.first;
    
    final mRows = await db.query('parents', where: 'id = ?', whereArgs: [p['mother_id']]);
    if (mRows.isNotEmpty) setState(() => _selectedMother = Parent.fromMap(mRows.first));
    
    final fRows = await db.rawQuery('SELECT p.* FROM parents p JOIN pairing_fathers pf ON p.id = pf.father_id WHERE pf.pairing_id = ?', [pairingId]);
    setState(() => _groupFathers = fRows.map(Parent.fromMap).toList());
  }

  Future<void> _loadAccounts() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('accounts');
    setState(() {
      _accounts = rows.map(Account.fromMap).toList();
      if (_accounts.isNotEmpty && _selectedAccount == null) { _selectedAccount = _accounts.first.name; }
    });
  }

  Future<void> _showPairingSelectionDialog() async {
    if (_selectedAccount == null) return;
    final db = await AppDatabase.instance.db;
    final pairings = await db.query('pairings', where: 'account = ?', whereArgs: [_selectedAccount]);
    if (pairings.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该账号暂无配对组'))); return; }
    
    List<Map<String, dynamic>> groups = [];
    for (final p in pairings) {
      final mRows = await db.query('parents', where: 'id=?', whereArgs: [p['mother_id']]);
      if (mRows.isEmpty) continue;
      final fRows = await db.rawQuery('SELECT p.* FROM parents p JOIN pairing_fathers pf ON p.id = pf.father_id WHERE pf.pairing_id = ?', [p['id']]);
      if (fRows.isEmpty) continue;
      groups.add({'id': p['id'], 'mother': Parent.fromMap(mRows.first), 'fathers': fRows.map(Parent.fromMap).toList()});
    }
    
    if (!mounted) return;
    
    final resultId = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('选择配对组'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: groups.isEmpty ? const Center(child: Text('暂无有效配对组')) : ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final g = groups[i];
              return Card(
                child: InkWell(
                  onTap: () => Navigator.pop(context, g['id']),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('第 ${i+1} 组', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 140, child: buildParentCard(context, g['mother'], true)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 160, 
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: (g['fathers'] as List).length,
                                  itemBuilder: (context, j) {
                                    final f = g['fathers'][j];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: SizedBox(width: 140, child: buildParentCard(context, f, false)),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    if (resultId != null) {
      setState(() {
        _pairingId = resultId;
        _isParentLocked = true; 
      });
      _loadGroupData(resultId);
    }
  }

  Future<void> _autoFillPrice(String weightStr) async {
    final weight = double.tryParse(weightStr);
    if (weight == null) { setState(() => _isOutOfRange = false); return; }
    final db = await AppDatabase.instance.db;
    final catRows = await db.query('egg_categories');
    String matchedCategory = '';
    for (var row in catRows) {
      String catName = row['name'] as String;
      if (_nameCtrl.text.contains(catName)) { matchedCategory = catName; break; }
    }
    if (matchedCategory.isEmpty) { setState(() => _isOutOfRange = true); return; }

    final rules = await db.query('price_rules', where: 'category = ?', whereArgs: [matchedCategory]);
    for (var r in rules) {
      if (weight >= (r['min_weight'] as double) && weight <= (r['max_weight'] as double)) {
        setState(() { _priceCtrl.text = (r['price'] as double).toStringAsFixed(0); _isOutOfRange = false; }); return;
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
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写蛋名！')));
      return;
    }
    if (_weightCtrl.text.trim().isEmpty || double.tryParse(_weightCtrl.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写正确的重量！')));
      return;
    }

    final db = await AppDatabase.instance.db;
    String? finalPath = _iconPath;
    if (finalPath == null) {
      final exist = await db.query('eggs', where: 'name = ? AND icon_path IS NOT NULL', whereArgs: [_nameCtrl.text], limit: 1);
      if (exist.isNotEmpty) finalPath = exist.first['icon_path'] as String?;
    }
    
    String? fatherName, motherName;
    if (widget.egg != null && _isParentLocked) {
      fatherName = widget.egg!.fatherNameSnapshot; motherName = widget.egg!.motherNameSnapshot;
    } else {
      motherName = _selectedMother?.name;
      fatherName = _groupFathers.isNotEmpty ? _groupFathers.map((e) => e.name).join('、') : null;
    }

    final medals = <String>[]; if (_sizeMedal != null) medals.add(_sizeMedal!); if (_voiceMedal != null) medals.add(_voiceMedal!);
    if (_status == '需售后') _isAfterSales = true;

    final e = Egg(
      id: widget.egg?.id, name: _nameCtrl.text, weight: double.tryParse(_weightCtrl.text) ?? 0, medals: medals, nature: _natureCtrl.text, price: double.tryParse(_priceCtrl.text), status: _status, iconPath: finalPath, createdAt: widget.egg?.createdAt, 
      salePlatform: _salePlatformCtrl.text, buyerPlatformName: _buyerPlatNameCtrl.text, buyerPlatformId: _buyerPlatIdCtrl.text, buyerGameName: _buyerGameNameCtrl.text, buyerGameId: _buyerGameIdCtrl.text, note: _noteCtrl.text,
      nestType: _nestType, obtainedDate: _obtainedDate, account: _selectedAccount, 
      pairingId: _pairingId, 
      motherId: _selectedMother?.id, 
      fatherId: _groupFathers.isNotEmpty ? _groupFathers.first.id : null,
      fatherNameSnapshot: fatherName, motherNameSnapshot: motherName, afterSalesPlan: _afterSalesCtrl.text, isAfterSales: _isAfterSales,
    );
    if (e.id == null) { await db.insert('eggs', e.toMap()); } else { await db.update('eggs', e.toMap(), where: 'id=?', whereArgs: [e.id]); }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    bool isReadOnly = _status == '已售出' || _status == '需售后'; 
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.egg == null ? '新增精灵蛋' : '编辑精灵蛋')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          getLocalImage(_iconPath, 'egg_icons', size: 60),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: () async { final res = await FilePicker.platform.pickFiles(type: FileType.image); if (res != null && res.files.single.path != null) { final saved = await copyImageToLocal(res.files.single.path!, 'egg_icons'); setState(() => _iconPath = saved); } }, icon: const Icon(Icons.image), label: const Text('选图')),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, enabled: !isReadOnly, decoration: const InputDecoration(labelText: '蛋名'), onChanged: (v) => _autoFillPrice(_weightCtrl.text)),
        
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _nestType, isExpanded: true, menuMaxHeight: 250, decoration: const InputDecoration(labelText: '窝类型'),
              items: ['普窝', '绿窝'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: isReadOnly ? null : (v) => setState(() => _nestType = v!),
            )
          ),
          const SizedBox(width: 16),
          Expanded(child: InkWell(onTap: isReadOnly ? null : _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: '收取日期'), child: Text(_obtainedDate)))),
        ]),

        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedAccount, isExpanded: true, menuMaxHeight: 250, decoration: const InputDecoration(labelText: '所属账号'),
              items: _accounts.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(),
              onChanged: isReadOnly ? null : (v) { setState(() { _selectedAccount = v; _pairingId = null; _selectedMother = null; _groupFathers = []; _isParentLocked = false; }); },
            )
          ),
          const SizedBox(width: 16),
          Expanded(child: TextField(controller: _weightCtrl, enabled: !isReadOnly, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '重量(kg)', errorText: _isOutOfRange ? '不在范围内' : null), onChanged: _autoFillPrice)),
        ]),

        const SizedBox(height: 16),
        
        InkWell(
          onTap: (isReadOnly || _isParentLocked) ? null : _showPairingSelectionDialog,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400), 
              borderRadius: BorderRadius.circular(8),
              color: isReadOnly ? Colors.grey.shade100 : Colors.white
            ),
            child: Column(
              children: [
                if (!_isParentLocked && !isReadOnly)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('点击选择配对组', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                
                if (_selectedMother != null && _groupFathers.isNotEmpty)
                  Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('母本', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        buildParentCard(context, _selectedMother!, true)
                      ],
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('父本 (左右滑动)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 160,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _groupFathers.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SizedBox(width: 140, child: buildParentCard(context, _groupFathers[i], false)),
                            ),
                          ),
                        )
                      ],
                    )),
                  ])
                else
                  const Text('未选择配对组', style: TextStyle(color: Colors.grey)),
                
                if (!isReadOnly && _isParentLocked) 
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () { setState(() => _isParentLocked = false); },
                      icon: const Icon(Icons.lock, size: 16, color: Colors.red),
                      label: const Text('解锁并重新选择配对组', style: TextStyle(color: Colors.red)),
                    ),
                  )
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: TextField(controller: _natureCtrl, enabled: !isReadOnly, decoration: const InputDecoration(labelText: '性格'))),
          const SizedBox(width: 16),
          Expanded(child: TextField(controller: _priceCtrl, enabled: !isReadOnly, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '标价'))),
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
        DropdownButtonFormField<String>(
          value: _status, isExpanded: true, menuMaxHeight: 250, decoration: const InputDecoration(labelText: '状态'),
          items: ['在库', '已预定', '已售出', '需售后'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _status = v!),
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
            FloatingActionButton.extended(
              onPressed: _save, 
              backgroundColor: Colors.green, 
              foregroundColor: Colors.white, 
              heroTag: 'save', 
              icon: const Icon(Icons.check),
              label: const Text('保存'),
            ),
            const SizedBox(width: 16),
            FloatingActionButton.extended(
              onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                  title: const Text('放弃修改？'), content: const Text('当前填写的数据将丢失。'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定')), TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消'))],
                ));
                if (confirm == true && context.mounted) Navigator.pop(context);
              }, 
              backgroundColor: Colors.red, 
              foregroundColor: Colors.white, 
              heroTag: 'cancel', 
              icon: const Icon(Icons.close),
              label: const Text('取消'),
            ),
          ]
        ),
      ),
    );
  }
}
