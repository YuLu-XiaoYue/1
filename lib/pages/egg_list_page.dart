import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lpinyin/lpinyin.dart';
import '../db/database.dart';
import '../models/models.dart';

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
  State<EggListPage> createState() => EggListPageState(); // 改为了公开的 State
}

class EggListPageState extends State<EggListPage> {
  List<Egg> _eggs = [];
  List<String> _categories = ['全部'];
  String _currentCategory = '全部';
  
  String _searchQuery = '';
  String _sortType = '时间由近到远';
  final List<String> _sortTypes = ['时间由近到远', '时间由远到近', '蛋重高到低', '蛋重低到高'];
  
  Set<String> _filterMedals = {};
  bool _filterMatchAll = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() { super.initState(); _loadCategories(); _load(); }

  // 暴露给外部的刷新方法
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

  @override
  Widget build(BuildContext context) {
    var visible = _eggs.where((e) {
      bool matchTab = _currentCategory == '全部' || e.name.contains(_currentCategory);
      bool matchSearch = _searchQuery.isEmpty || e.name.contains(_searchQuery) || (e.buyerPlatformName ?? '').contains(_searchQuery) || (e.buyerGameName ?? '').contains(_searchQuery) || (e.nature ?? '').contains(_searchQuery);
      bool matchMedal = true;
      if (_filterMedals.isNotEmpty) {
        if (_filterMatchAll) matchMedal = _filterMedals.every((m) => e.medals.contains(m));
        else matchMedal = _filterMedals.any((m) => e.medals.contains(m));
      }
      return matchTab && matchSearch && matchMedal;
    }).toList();

    if (_sortType == '时间由近到远') visible.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    if (_sortType == '时间由远到近') visible.sort((a, b) => (a.createdAt ?? 0).compareTo(b.createdAt ?? 0));
    if (_sortType == '蛋重高到低') visible.sort((a, b) => b.weight.compareTo(a.weight));
    if (_sortType == '蛋重低到高') visible.sort((a, b) => a.weight.compareTo(b.weight));

    Map<String, List<Egg>> groupedEggs = {};
    List<String> alphabet = [];
    if (widget.viewType != '在库/预定') {
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
                PopupMenuButton<String>(
                  tooltip: '筛选与过滤',
                  icon: const Icon(Icons.filter_alt),
                  onSelected: (v) { if (v == 'clear') setState(() => _filterMedals.clear()); else if (v == 'toggle') setState(() => _filterMatchAll = !_filterMatchAll); else setState(() { if (_filterMedals.contains(v)) _filterMedals.remove(v); else _filterMedals.add(v); }); },
                  itemBuilder: (c) => [
                    PopupMenuItem(value: 'toggle', child: Text('当前条件: ${_filterMatchAll ? "全部满足" : "满足其一"}')),
                    const PopupMenuItem(value: 'clear', child: Text('清空筛选')),
                    const PopupMenuDivider(),
                    ...sizeMedals.map((m) => CheckedPopupMenuItem(value: m, checked: _filterMedals.contains(m), child: Text(m))),
                    ...voiceMedals.map((m) => CheckedPopupMenuItem(value: m, checked: _filterMedals.contains(m), child: Text(m))),
                  ],
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
            child: widget.viewType == '在库/预定' ? _buildNormalList(visible) : _buildAlphabetList(groupedEggs, alphabet),
          ),
        ],
      ),
      floatingActionButton: widget.viewType == '在库/预定' ? FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const EggEditPage())); _load(); }, child: const Icon(Icons.add)) : null,
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
        return GestureDetector(
          onSecondaryTap: () => _deleteEgg(e.id!),
          child: Slidable(
            key: ValueKey(e.id),
            endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteEgg(e.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
            child: ListTile(
              leading: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 12),
                Stack(clipBehavior: Clip.none, children: [
                  getLocalImage(e.iconPath, 'egg_icons', size: 40),
                  if (e.nestType == '绿窝') Positioned(right: -6, bottom: -6, child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), padding: const EdgeInsets.all(2), child: Image.asset('assets/nest_types/green_nest.png', width: 16, height: 16, errorBuilder: (c,e,s) => const Icon(Icons.eco, color: Colors.green, size: 16)))),
                ])
              ]),
              title: Text('${e.name}  ${e.weight}kg'),
              subtitle: Text('收取: ${e.obtainedDate} | 标价:${e.price ?? "-"}'),
              trailing: Text(e.status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); _load(); },
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
                ...groups[letter]!.map((e) => GestureDetector(
                  onSecondaryTap: () => _deleteEgg(e.id!),
                  child: Slidable(
                    key: ValueKey(e.id),
                    endActionPane: ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (_) => _deleteEgg(e.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')]),
                    child: ListTile(
                      leading: getLocalImage(e.iconPath, 'egg_icons', size: 40),
                      title: Text('${e.name}  ${e.weight}kg'),
                      subtitle: Text('买家: ${e.buyerPlatformName ?? e.buyerGameName ?? "无"} | ${e.isAfterSales ? "已售后" : ""}'),
                      trailing: Text(e.status, style: TextStyle(color: e.status == '需售后' ? Colors.orange : Colors.grey, fontWeight: FontWeight.bold)),
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); _load(); },
                    ),
                  ),
                ))
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
  List<Account> _accounts = [];
  List<Parent> _fathers = [], _mothers = [];
  int? _fatherId, _motherId;
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
      
      _status = e.status; _nestType = e.nestType; _obtainedDate = e.obtainedDate; _iconPath = e.iconPath; _selectedAccount = e.account; _fatherId = e.fatherId; _motherId = e.motherId; _isAfterSales = e.isAfterSales;
      if (_fatherId != null || _motherId != null) _isParentLocked = true;
      for (var m in e.medals) { if (sizeMedals.contains(m)) _sizeMedal = m; if (voiceMedals.contains(m)) _voiceMedal = m; }
    }
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('accounts');
    setState(() {
      _accounts = rows.map(Account.fromMap).toList();
      if (_accounts.isNotEmpty && _selectedAccount == null) { _selectedAccount = _accounts.first.name; _loadParents(); }
      else if (_selectedAccount != null) _loadParents();
    });
  }

  Future<void> _loadParents() async {
    if (_selectedAccount == null) return;
    final db = await AppDatabase.instance.db;
    final rows = await db.query('parents', where: 'account = ?', whereArgs: [_selectedAccount]);
    final all = rows.map(Parent.fromMap).toList();
    setState(() {
      _fathers = all.where((p) => p.gender == '父本').toList(); _mothers = all.where((p) => p.gender == '母本').toList();
      if (_fatherId != null && !_fathers.any((p) => p.id == _fatherId)) _fatherId = null;
      if (_motherId != null && !_mothers.any((p) => p.id == _motherId)) _motherId = null;
    });
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
    if (_nameCtrl.text.isEmpty) return;
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
      fatherName = _fathers.firstWhere((p) => p.id == _fatherId, orElse: () => Parent(name: '', gender: '', account: '')).name;
      motherName = _mothers.firstWhere((p) => p.id == _motherId, orElse: () => Parent(name: '', gender: '', account: '')).name;
    }

    final medals = <String>[]; if (_sizeMedal != null) medals.add(_sizeMedal!); if (_voiceMedal != null) medals.add(_voiceMedal!);
    if (_status == '需售后') _isAfterSales = true;

    final e = Egg(
      id: widget.egg?.id, name: _nameCtrl.text, weight: double.tryParse(_weightCtrl.text) ?? 0, medals: medals, nature: _natureCtrl.text, price: double.tryParse(_priceCtrl.text), status: _status, iconPath: finalPath, createdAt: widget.egg?.createdAt, 
      salePlatform: _salePlatformCtrl.text, buyerPlatformName: _buyerPlatNameCtrl.text, buyerPlatformId: _buyerPlatIdCtrl.text, buyerGameName: _buyerGameNameCtrl.text, buyerGameId: _buyerGameIdCtrl.text, note: _noteCtrl.text,
      nestType: _nestType, obtainedDate: _obtainedDate, account: _selectedAccount, fatherId: _fatherId, motherId: _motherId, fatherNameSnapshot: fatherName, motherNameSnapshot: motherName, afterSalesPlan: _afterSalesCtrl.text, isAfterSales: _isAfterSales,
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
              onChanged: isReadOnly ? null : (v) { setState(() { _selectedAccount = v; _fatherId = null; _motherId = null; _isParentLocked = false; _loadParents(); }); },
            )
          ),
          const SizedBox(width: 16),
          Expanded(child: TextField(controller: _weightCtrl, enabled: !isReadOnly, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '重量(kg)', errorText: _isOutOfRange ? '不在范围内' : null), onChanged: _autoFillPrice)),
        ]),

        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _motherId, isExpanded: true, menuMaxHeight: 250, decoration: const InputDecoration(labelText: '母本'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('无')),
                  ..._mothers.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name))),
                  if (widget.egg != null && widget.egg!.motherId != null && !_mothers.any((p) => p.id == widget.egg!.motherId))
                    DropdownMenuItem<int?>(value: widget.egg!.motherId, child: const Text('[已删除]')),
                ],
                onChanged: (isReadOnly || _isParentLocked) ? null : (v) => setState(() => _motherId = v),
              )
            ),
            if (!isReadOnly && _isParentLocked) IconButton(icon: const Icon(Icons.lock, size: 16, color: Colors.red), onPressed: () { setState(() => _isParentLocked = false); }),
          ])),
          const SizedBox(width: 16),
          Expanded(child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _fatherId, isExpanded: true, menuMaxHeight: 250, decoration: const InputDecoration(labelText: '父本'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('无')),
                  ..._fathers.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name))),
                  if (widget.egg != null && widget.egg!.fatherId != null && !_fathers.any((p) => p.id == widget.egg!.fatherId))
                    DropdownMenuItem<int?>(value: widget.egg!.fatherId, child: const Text('[已删除]')),
                ],
                onChanged: (isReadOnly || _isParentLocked) ? null : (v) => setState(() => _fatherId = v),
              )
            ),
            if (!isReadOnly && _isParentLocked) IconButton(icon: const Icon(Icons.lock, size: 16, color: Colors.red), onPressed: () { setState(() => _isParentLocked = false); }),
          ])),
        ]),

        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(controller: _natureCtrl, enabled: !isReadOnly, decoration: const InputDecoration(labelText: '性格'))),
          const SizedBox(width: 16),
          Expanded(child: TextField(controller: _priceCtrl, enabled: !isReadOnly, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '标价'))),
        ]),
        
        const SizedBox(height: 16),
        const Text('体型/重量奖牌 (单选)', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: sizeMedals.map((m) => ChoiceChip(label: _buildMedalChip(m), selected: _sizeMedal == m, onSelected: isReadOnly ? null : (v) => setState(() => _sizeMedal = v ? m : null))).toList()),
        const SizedBox(height: 16),
        const Text('声音奖牌 (单选)', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: voiceMedals.map((m) => ChoiceChip(label: _buildMedalChip(m), selected: _voiceMedal == m, onSelected: isReadOnly ? null : (v) => setState(() => _voiceMedal = v ? m : null))).toList()),
        
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _status, isExpanded: true, menuMaxHeight: 250, decoration: const InputDecoration(labelText: '状态'),
          items: ['在库', '已预定', '已售出', '需售后'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _status = v!),
        ),
        
        const SizedBox(height: 24),
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
        
        const SizedBox(height: 24),
        const Text('其他', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
        const Divider(),
        const SizedBox(height: 8),
        TextField(controller: _noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '备注')),
        const SizedBox(height: 12),
        TextField(controller: _afterSalesCtrl, enabled: _status == '需售后', maxLines: 3, decoration: const InputDecoration(labelText: '售后方案（仅需售后状态可填写）')),

        const SizedBox(height: 80),
      ]),
      floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(onPressed: _save, backgroundColor: Colors.green, foregroundColor: Colors.white, heroTag: 'save', child: const Icon(Icons.check)),
        const SizedBox(width: 16),
        FloatingActionButton(onPressed: () async {
          final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
            title: const Text('放弃修改？'), content: const Text('当前填写的数据将丢失。'),
            actions: [TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定')), TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消'))],
          ));
          if (confirm == true && context.mounted) Navigator.pop(context);
        }, backgroundColor: Colors.red, foregroundColor: Colors.white, heroTag: 'cancel', child: const Icon(Icons.close)),
      ]),
    );
  }
}
