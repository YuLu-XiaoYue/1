import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:convert';
import '../db/database.dart';
import '../models/models.dart';

class CreatureLibraryPage extends StatefulWidget {
  const CreatureLibraryPage({super.key});
  @override
  State<CreatureLibraryPage> createState() => CreatureLibraryPageState();
}

class CreatureLibraryPageState extends State<CreatureLibraryPage> {
  List<Creature> _creatures = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> loadData() async { await _load(); }

  Future<void> _load() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('creatures', orderBy: 'id DESC');
    if (!mounted) return;
    setState(() => _creatures = rows.map(Creature.fromMap).toList());
  }

  void _deleteCreature(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('删除精灵？'), content: const Text('删除后将无法自动识别该精灵的蛋组。'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定删除', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) { final db = await AppDatabase.instance.db; await db.delete('creatures', where: 'id = ?', whereArgs: [id]); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _creatures.isEmpty ? const Center(child: Text('暂无精灵，点击右下角添加')) : LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 800 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5, // 控制卡片比例
            ),
            itemCount: _creatures.length,
            itemBuilder: (context, i) {
              final c = _creatures[i];
              return GestureDetector(
                onSecondaryTap: () => _deleteCreature(c.id!),
                child: Slidable(
                  key: ValueKey(c.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(), extentRatio: 0.25,
                    children: [SlidableAction(onPressed: (_) => _deleteCreature(c.id!), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: '删除')],
                  ),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => CreatureEditPage(creature: c)));
                        _load();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                getLocalImage(c.iconPath, 'egg_icons', size: 40, fallbackIcon: Icons.pets),
                                const SizedBox(width: 12),
                                Expanded(child: Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const Spacer(),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: c.eggGroups.map((g) => Chip(label: Text(g, style: const TextStyle(fontSize: 10)), backgroundColor: Colors.grey.shade100)).toList(),
                            )
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatureEditPage())); _load(); }, child: const Icon(Icons.add)),
      ),
    );
  }
}

class CreatureEditPage extends StatefulWidget {
  final Creature? creature;
  const CreatureEditPage({super.key, this.creature});
  @override
  State<CreatureEditPage> createState() => _CreatureEditPageState();
}

class _CreatureEditPageState extends State<CreatureEditPage> {
  final _nameCtrl = TextEditingController();
  List<String> _eggGroups = [];
  String? _iconPath;
  String? _tempSelectedImagePath;

  @override
  void initState() {
    super.initState();
    if (widget.creature != null) {
      _nameCtrl.text = widget.creature!.name;
      _eggGroups = List.from(widget.creature!.eggGroups);
      _iconPath = widget.creature!.iconPath;
    }
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty) return;
    final db = await AppDatabase.instance.db;
    String? finalPath = await syncEggImage(_nameCtrl.text, _tempSelectedImagePath, widget.creature?.iconPath);

    final c = Creature(id: widget.creature?.id, name: _nameCtrl.text, iconPath: finalPath, eggGroups: _eggGroups);
    if (c.id == null) { await db.insert('creatures', c.toMap()); } else { await db.update('creatures', c.toMap(), where: 'id=?', whereArgs: [c.id]); }
    if (mounted) Navigator.pop(context);
  }

  void _showGroupSelector() {
    showDialog(context: context, builder: (c) => StatefulBuilder(
      builder: (context, setDialogState) {
        List<String> selected = List.from(_eggGroups);
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
            ElevatedButton(onPressed: () { setState(() => _eggGroups = selected); Navigator.pop(c); }, child: const Text('确定')),
          ],
        );
      }
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.creature == null ? '新增精灵' : '编辑精灵')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          _tempSelectedImagePath != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_tempSelectedImagePath!), width: 60, height: 60, fit: BoxFit.cover)) : getLocalImage(_iconPath, 'egg_icons', size: 60),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: () async { final res = await FilePicker.platform.pickFiles(type: FileType.image); if (res != null && res.files.single.path != null) setState(() => _tempSelectedImagePath = res.files.single.path!); }, icon: const Icon(Icons.image), label: const Text('选图')),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '精灵名字 (如: 小黑猫)')),
        const SizedBox(height: 16),
        InkWell(
          onTap: _showGroupSelector,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: '所属蛋组 (最多2个)', suffixIcon: Icon(Icons.arrow_drop_down)),
            child: Text(_eggGroups.isEmpty ? '请选择蛋组' : _eggGroups.join('、')),
          ),
        ),
      ]),
      floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(onPressed: _save, backgroundColor: Colors.green, foregroundColor: Colors.white, heroTag: 'save', child: const Icon(Icons.check)),
        const SizedBox(width: 16),
        FloatingActionButton(onPressed: () => Navigator.pop(context), backgroundColor: Colors.red, foregroundColor: Colors.white, heroTag: 'cancel', child: const Icon(Icons.close)),
      ]),
    );
  }
}
