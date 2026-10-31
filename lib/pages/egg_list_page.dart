import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lpinyin/lpinyin.dart';
import 'dart:io';
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
  List<Account> _accounts = [];
  String _currentAccount = '全部';
  
  String _searchQuery = '';
  String _sortType = '时间由近到远';
  final List<String> _sortTypes = ['时间由近到远', '时间由远到近', '蛋重高到低', '蛋重低到高'];
  Set<String> _filterTags = {};
  bool _filterMatchAll = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() { super.initState(); _loadAccounts(); _load(); }

  Future<void> loadData() async { await _loadAccounts(); _load(); }

  Future<void> _loadAccounts() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('accounts');
    if (!mounted) return;
    setState(() {
      _accounts = rows.map(Account.fromMap).toList();
      if (_currentAccount != '全部' && !_accounts.any((a) => a.name == _currentAccount)) _currentAccount = '全部';
    });
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

  void _deleteAccountTab(String name) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('删除标签 "$name"？'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定'))],
    ));
    if (confirm == true) {
      final db = await AppDatabase.instance.db;
      await db.delete('accounts', where: 'name = ?', whereArgs: [name]);
      _loadAccounts();
    }
  }

  // ... 省略删除逻辑和筛选逻辑 (与前面保持一致) ...

  @override
  Widget build(BuildContext context) {
    var visible = _eggs.where((e) {
      bool matchTab = _currentAccount == '全部' || e.account == _currentAccount;
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
      return matchTab && matchSearch && matchTags;
    }).toList();

    // 排序、字母分组等保持原样...
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
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterTab('全部', _currentAccount == '全部', () => setState(() => _currentAccount = '全部'), null),
                ..._accounts.map((acc) => _buildFilterTab(
                  acc.name, _currentAccount == acc.name, 
                  () => setState(() => _currentAccount = acc.name), 
                  () => _deleteAccountTab(acc.name)
                ))
              ],
            ),
          ),
          // 搜索和筛选栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(child: TextField(onChanged: (v) => setState(() => _searchQuery = v), decoration: const InputDecoration(hintText: '搜索名字/买家', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                IconButton(tooltip: '筛选', icon: Icon(Icons.filter_alt, color: _filterTags.isNotEmpty ? Theme.of(context).colorScheme.primary : null), onPressed: _showFilterDialog),
                PopupMenuButton<String>(icon: const Icon(Icons.sort), onSelected: (v) => setState(() => _sortType = v), itemBuilder: (c) => _sortTypes.map((s) => PopupMenuItem(value: s, child: Text(s))).toList()),
              ],
            ),
          ),
          Expanded(child: useAlphabetGroup ? _buildAlphabetList(groupedEggs, alphabet) : _buildNormalList(visible)),
        ],
      ),
      floatingActionButton: widget.viewType == '在库/预定' ? Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const EggEditPage())); _load(); }, child: const Icon(Icons.add)),
      ) : null,
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

  // 列表渲染保持一致，省略以节省空间，直接复制你之前列表的代码即可...
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
              onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); _load(); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
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

  // ... 省略 _buildAlphabetList, _showFilterDialog, _deleteEgg, 和 _buildEggIconWithBadges 的代码，保持一致即可 ...
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
  String? _tempSelectedImagePath; 
  
  int? _pairingId;
  int? _lineId; // 当前选中的产线
  
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
      _isParentLocked = true; // 已有的锁死
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
    });
  }

  Future<void> _autoFillPrice(String weightStr) async {
    final weight = double.tryParse(weightStr);
    if (weight == null) { setState(() => _isOutOfRange = false); return; }
    final db = await AppDatabase.instance.db;
    // 价格规则依然读 category (你可以直接用产线名来匹配)
    final rules = await db.query('price_rules', where: 'category = ?', whereArgs: [_nameCtrl.text]);
    for (var r in rules) {
      if (weight >= (r['min_weight'] as double) && weight <= (r['max_weight'] as double)) {
        setState(() { _priceCtrl.text = (r['price'] as double).toStringAsFixed(0); _isOutOfRange = false; }); return;
      }
    }
    setState(() => _isOutOfRange = true);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写蛋名！'))); return; }
    if (_weightCtrl.text.trim().isEmpty || double.tryParse(_weightCtrl.text) == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写正确的重量！'))); return; }

    final db = await AppDatabase.instance.db;
    
    // 图片同步
    String? finalPath = await syncEggImage(_nameCtrl.text, _tempSelectedImagePath, widget.egg?.iconPath);
    
    // 父母本快照 (如果选了产线，就存产线关联的配对组快照)
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
        
        // 核心改动：先选产线，自动填蛋名和性格
        DropdownButtonFormField<int>(
          value: _lineId,
          decoration: const InputDecoration(labelText: '选择产线 (自动填充蛋名/性格)'),
          items: _lines.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
          onChanged: isReadOnly ? null : (v) {
            final line = _lines.firstWhere((element) => element.id == v);
            setState(() {
              _lineId = v;
              _nameCtrl.text = line.name;
              _natureCtrl.text = line.nature;
              _nestType = line.nestType;
              _pairingId = line.pairingId;
              _selectedAccount = line.accountName;
              _iconPath = line.iconPath;
              _isParentLocked = true;
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, enabled: false, decoration: const InputDecoration(labelText: '蛋名 (由产线自动决定)')),
        
        const SizedBox(height: 16),
        // 窝类型按钮化
        Row(children: [
          Expanded(child: _buildNestButton('普窝', isReadOnly)),
          const SizedBox(width: 16),
          Expanded(child: _buildNestButton('绿窝', isReadOnly)),
        ]),

        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(controller: _weightCtrl, enabled: !isReadOnly, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '重量(kg)', errorText: _isOutOfRange ? '不在范围内' : null), onChanged: _autoFillPrice)),
          const SizedBox(width: 16),
          Expanded(child: TextField(controller: _natureCtrl, enabled: false, decoration: const InputDecoration(labelText: '性格 (自动推导)'))),
        ]),
        
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(controller: _priceCtrl, enabled: !isReadOnly, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '标价'))),
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
        DropdownButtonFormField<String>(
          value: _status, isExpanded: true, menuMaxHeight: 250, decoration: const InputDecoration(labelText: '状态'),
          items: ['在库', '已预定', '已售出', '需售后'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _status = v!),
        ),
        
        // ... 买家信息和备注字段保持不变 ...
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
      onTap: isReadOnly ? null : () => setState(() => _nestType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
