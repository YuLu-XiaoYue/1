// ... 前面 import 和 buildParentCard 保持不变 ...

class ParentEditPage extends StatefulWidget {
  final Parent? parent; final String account;
  const ParentEditPage({super.key, this.parent, required this.account});
  @override
  State<ParentEditPage> createState() => _ParentEditPageState();
}

class _ParentEditPageState extends State<ParentEditPage> {
  final _nameCtrl = TextEditingController(), _natureCtrl = TextEditingController(), _heightCtrl = TextEditingController(), _weightCtrl = TextEditingController(), _voiceCtrl = TextEditingController();
  String _gender = '母本'; String? _bloodline, _iconPath; String _appearance = '普通';
  String? _tempSelectedImagePath; // 暂存

  @override
  void initState() {
    super.initState();
    if (widget.parent != null) {
      final p = widget.parent!; _nameCtrl.text = p.name; _natureCtrl.text = p.nature ?? ''; _heightCtrl.text = p.height?.toString() ?? ''; _weightCtrl.text = p.weight?.toString() ?? ''; _voiceCtrl.text = p.voice?.toString() ?? ''; _gender = p.gender; _bloodline = p.bloodline; _iconPath = p.iconPath; _appearance = p.appearance;
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    final db = await AppDatabase.instance.db;
    
    // 核心修改：同步父母本图片
    String? finalPath = await syncParentImage(_nameCtrl.text, _tempSelectedImagePath, widget.parent?.iconPath);

    final p = Parent(id: widget.parent?.id, name: _nameCtrl.text, gender: _gender, account: widget.account, nature: _natureCtrl.text, height: double.tryParse(_heightCtrl.text), weight: double.tryParse(_weightCtrl.text), voice: double.tryParse(_voiceCtrl.text), bloodline: _bloodline, iconPath: finalPath, appearance: _appearance);
    if (p.id == null) { await db.insert('parents', p.toMap()); } else { await db.update('parents', p.toMap(), where: 'id=?', whereArgs: [p.id]); }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.parent == null ? '新增父母本' : '编辑父母本')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          // 核心修改：预览新图
          _tempSelectedImagePath != null 
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_tempSelectedImagePath!), width: 60, height: 60, fit: BoxFit.cover))
            : getLocalImage(_iconPath, 'parent_icons', size: 60, fallbackIcon: Icons.face),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () async { 
              final res = await FilePicker.platform.pickFiles(type: FileType.image); 
              if (res != null && res.files.single.path != null) { 
                setState(() => _tempSelectedImagePath = res.files.single.path!); 
              } 
            }, 
            icon: const Icon(Icons.image), label: const Text('选图')
          ),
        ]),
        // ... 后面表单保持不变 ...
      ]),
    );
  }
}
