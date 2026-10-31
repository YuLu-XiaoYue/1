import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';

class SettingsPage extends StatefulWidget {
  final Color currentThemeColor;
  final Color currentBgColor;
  final Color? currentDrawerColor;
  final Color currentCardColor;
  final Function(Color) onThemeColorChanged;
  final Function(Color) onBgColorChanged;
  final Function(Color?) onDrawerColorChanged;
  final Function(Color) onCardColorChanged;

  const SettingsPage({
    super.key,
    required this.currentThemeColor,
    required this.currentBgColor,
    required this.currentDrawerColor,
    required this.currentCardColor,
    required this.onThemeColorChanged,
    required this.onBgColorChanged,
    required this.onDrawerColorChanged,
    required this.onCardColorChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

// 👇 注意看这里：之前你缺了这个类的外壳，现在所有的逻辑都被放进这里面了
class _SettingsPageState extends State<SettingsPage> {
  
  void _updateColor(Color color, String type) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == 'theme') {
      widget.onThemeColorChanged(color);
      await prefs.setInt('theme_color', color.value);
    } else if (type == 'bg') {
      widget.onBgColorChanged(color);
      await prefs.setInt('bg_color', color.value);
    } else if (type == 'drawer') {
      widget.onDrawerColorChanged(color);
      await prefs.setInt('drawer_color', color.value);
    } else if (type == 'drawer_reset') {
      widget.onDrawerColorChanged(null);
      await prefs.remove('drawer_color');
    } else if (type == 'card') {
      widget.onCardColorChanged(color);
      await prefs.setInt('card_color', color.value);
    }
  }

  void _pickColor(Color initialColor, String title, Function(Color) onColorChanged) async {
    Color picked = initialColor;
    await showDialog(
      context: context, // 现在这里可以正常使用 context 了
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('选择$title'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ColorPicker(
                    pickerColor: picked, 
                    onColorChanged: (color) {
                      picked = color;
                      onColorChanged(color); 
                      setDialogState(() {}); 
                    }, 
                    enableAlpha: false, 
                    displayThumbColor: true, 
                    paletteType: PaletteType.hsvWithHue,
                    hexInputBar: true, 
                  ),
                  const SizedBox(height: 24),
                  const Text('实际按钮预览效果：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: picked,
                        foregroundColor: picked.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                      ),
                      onPressed: () {}, 
                      icon: const Icon(Icons.add),
                      label: const Text('新增产线'),
                    ),
                  )
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('确定'))],
          );
        }
      ),
    );
  }

  Widget _buildColorButton(Color color, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 24, height: 24, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200))),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showExportSuccessDialog(String path) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (c) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('导出成功！'),
            IconButton(icon: const Icon(Icons.close, color: Colors.grey), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(c)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文件已成功保存至以下路径：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: SelectableText(path, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
            ),
            const SizedBox(height: 12),
            const Text('提示：你可以长按上方路径进行复制。', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('我知道了'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 现在这里在 State 类中，widget.currentThemeColor 可以完美运行
    final Color themeColor = widget.currentThemeColor;
    final Color bgColor = widget.currentBgColor;
    final Color cardColor = widget.currentCardColor;
    final Color drawerDisplayColor = widget.currentDrawerColor ?? themeColor;
    final bool isDrawerFollowing = widget.currentDrawerColor == null;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('颜色设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('主题色 (按钮)', style: TextStyle(color: Colors.grey)), 
            const SizedBox(height: 8), 
            _buildColorButton(themeColor, '点击选择', () => _pickColor(themeColor, '主题色', (c) => _updateColor(c, 'theme')))
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('背景色', style: TextStyle(color: Colors.grey)), 
            const SizedBox(height: 8), 
            _buildColorButton(bgColor, '点击选择', () => _pickColor(bgColor, '背景色', (c) => _updateColor(c, 'bg')))
          ])),
        ]),
        
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isDrawerFollowing ? '侧边栏 (跟随主题)' : '侧边栏 (独立)', style: const TextStyle(color: Colors.grey)), 
            const SizedBox(height: 8), 
            _buildColorButton(drawerDisplayColor, '点击选择', () => _pickColor(drawerDisplayColor, '侧边栏颜色', (c) => _updateColor(c, 'drawer')))
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('卡片底色', style: TextStyle(color: Colors.grey)), 
            const SizedBox(height: 8), 
            _buildColorButton(cardColor, '点击选择', () => _pickColor(cardColor, '卡片背景色', (c) => _updateColor(c, 'card')))
          ])),
        ]),

        const Divider(height: 48),
        const Text('数据管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.green.shade50, foregroundColor: Colors.green.shade800),
          onPressed: () async { 
            final path = await AppDatabase.instance.exportToExcel(); 
            if (path != null && context.mounted) _showExportSuccessDialog(path);
          }, 
          icon: const Icon(Icons.table_chart), label: const Text('导出精灵蛋数据 (Excel 表格)')
        ),
        const SizedBox(height: 16),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
          onPressed: () async { 
            final path = await AppDatabase.instance.exportBackup(); 
            if (path != null && context.mounted) _showExportSuccessDialog(path); 
          }, 
          icon: const Icon(Icons.download), label: const Text('导出全量备份 (.zip 包含图片)')
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
          onPressed: () async {
            final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('危险操作'), content: const Text('导入全量备份会覆盖当前所有的数据，确定继续吗？'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定覆盖'))]));
            if (confirm == true) {
              final success = await AppDatabase.instance.importBackup();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '全量恢复成功！请重启APP查看' : '恢复失败')));
            }
          },
          icon: const Icon(Icons.upload), label: const Text('导入全量恢复 (覆盖所有数据)'),
        ),
        
        const SizedBox(height: 32),
        const Text('内容分发 (仅文本)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('只包含新手教学和更新日志，导入不覆盖其他数据', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade700),
          onPressed: () async { 
            final path = await AppDatabase.instance.exportArticlesOnly(); 
            if (path != null && context.mounted) _showExportSuccessDialog(path); 
          }, 
          icon: const Icon(Icons.text_snippet), label: const Text('仅导出教学与日志')
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.green.shade50, foregroundColor: Colors.green.shade700),
          onPressed: () async {
            final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('导入文本'), content: const Text('导入后将覆盖你的新手教学和更新日志，但不会影响精灵蛋数据。确定继续吗？'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定'))]));
            if (confirm == true) {
              final success = await AppDatabase.instance.importArticlesOnly();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '文本导入成功！' : '导入失败')));
            }
          },
          icon: const Icon(Icons.text_snippet_outlined), label: const Text('仅导入教学与日志')
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
