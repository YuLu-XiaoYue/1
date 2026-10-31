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
  List<ProductionLine> _lines = [];
  
  String _searchQuery = '';
  String _sortType = '时间由近到远';
  final List<String> _sortTypes = ['时间由近到远', '时间由远到近', '蛋重高到低', '蛋重低到高'];
  
  // 筛选条件
  Set<String> _filterTags = {}; // 奖牌与绿窝
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
                    // 账号筛选
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: tempAcc,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '按账号筛选'),
                        items: [
                          const DropdownMenuItem(value: '全部', child: Text('全部账号')),
                          ..._accounts.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name)))
                        ],
                        onChanged: (v) => setDialogState(() { tempAcc = v!; tempLine = '全部'; }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 产线筛选
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: tempLine,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '按产线筛选'),
                        items: [
                          const DropdownMenuItem(value: '全部', child: Text('全部产线')),
                          ..._lines.where((l) => tempAcc == '全部' || l.accountName == tempAcc).map((l) => DropdownMenuItem(value: l.name, child: Text(l.name)))
                        ],
                        onChanged: (v) => setDialogState(() => tempLine = v!),
                      ),
                    ),
                    const Divider(height: 32),
                    // 组合条件
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('特征条件组合：', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          const Text('已选特征：'),
                          TextButton(onPressed: () => setDialogState(() => tempTags.clear()), child: const Text('清空选择')),
                        ],
                      ),
                    ),
                    // 绿窝
                    CheckboxListTile(
                      value: tempTags.contains('绿窝'),
                      title: Row(children: [
                        Image.asset('assets/nest_types/green_nest.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.eco, size: 20, color: Colors.green)),
                        const SizedBox(width: 8), const Text('绿窝'),
                      ]),
                      onChanged: (v) => setDialogState(() { if (v!) { tempTags.add('绿窝'); } else { tempTags.remove('绿窝'); } }),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                    const Divider(),
                    // 奖牌
                    ...sizeMedals.map((m) => CheckboxListTile(
                      value: tempTags.contains(m),
                      title: Row(children: [
                        Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.military_tech, size: 20, color: Colors.grey)),
                        const SizedBox(width: 8), Text(m),
                      ]),
                      onChanged: (v) => setDialogState(() { if (v!) { tempTags.add(m); } else { tempTags.remove(m); } }),
                      controlAffinity: ListTileControlAffinity.trailing,
                    )),
                    ...voiceMedals.map((m) => CheckboxListTile(
                      value: tempTags.contains(m),
                      title: Row(children: [
                        Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.military_tech, size: 20, color: Colors.grey)),
                        const SizedBox(width: 8), Text(m),
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
                    _filterAccount = tempAcc;
                    _filterLine = tempLine;
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
                  children: e.medals.map((m) => Image.asset('assets/medals/${medalIconMap[m] ?? m}.png', width: 16, height: 16)).toList(),
                ),
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
          // 搜索和筛选栏
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

  // ... (省略 _buildNormalList 和 _buildAlphabetList 的代码，与之前保持一致即可) ...
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
              onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); _loadData(); },
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
                        onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => EggEditPage(egg: e))); _loadData(); },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
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

// EggEditPage 保持原样，不用改。由于篇幅限制，请直接保留你上次替换的 EggEditPage 即可。
