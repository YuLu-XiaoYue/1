import 'package:flutter/material.dart';
import '../db/database.dart';

class ArticlePage extends StatefulWidget {
  final String type;
  final String title;
  const ArticlePage({super.key, required this.type, required this.title});
  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  String _content = '加载中...';
  bool _isEditing = false;
  final _ctrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('articles', where: 'type = ?', whereArgs: [widget.type]);
    if (rows.isNotEmpty) {
      setState(() { _content = rows.first['content'] as String; _ctrl.text = _content; });
    } else {
      setState(() { _content = '暂无内容，点击右上角编辑。'; _ctrl.text = ''; });
    }
  }

  Future<void> _save() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('articles', where: 'type = ?', whereArgs: [widget.type]);
    if (rows.isEmpty) {
      await db.insert('articles', {'type': widget.type, 'content': _ctrl.text});
    } else {
      await db.update('articles', {'content': _ctrl.text}, where: 'type = ?', whereArgs: [widget.type]);
    }
    setState(() { _content = _ctrl.text; _isEditing = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing ? Colors.green.shade50 : Colors.blue.shade50,
                foregroundColor: _isEditing ? Colors.green : Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 20), 
              label: Text(_isEditing ? '保存' : '编辑'),
              onPressed: () { if (_isEditing) { _save(); } else { setState(() => _isEditing = true); } }
            ),
          )
        ],
      ),
      body: _isEditing 
        ? Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _ctrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: '在这里输入内容...')))
        : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Text(_content, style: const TextStyle(fontSize: 16, height: 1.5))),
    );
  }
}
