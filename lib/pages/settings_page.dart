import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';
import 'price_rules_page.dart';

class SettingsPage extends StatefulWidget {
  final Color currentThemeColor;
  final Color currentBgColor;
  final Color? currentDrawerColor;
  final Function(Color) onThemeColorChanged;
  final Function(Color) onBgColorChanged;
  final Function(Color?) onDrawerColorChanged;

  const SettingsPage({
    super.key,
    required this.currentThemeColor,
    required this.currentBgColor,
    required this.currentDrawerColor,
    required this.onThemeColorChanged,
    required this.onBgColorChanged,
    required this.onDrawerColorChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

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
    }
  }

  void _pickColor(Color initialColor, String title, Function(Color) onColorChanged) async {
    Color picked = initialColor;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('选择$title'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor, 
            onColorChanged: (color) {
              picked = color;
              onColorChanged(color); 
            }, 
            enableAlpha: false, 
            displayThumbColor: true, 
            paletteType: PaletteType.hsvWithHue
          )
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('确定'))],
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
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(), 
              onPressed: () => Navigator.pop(c),
              tooltip: '关闭',
            ),
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
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300)
              ),
              child: SelectableText(
                path,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text('提示：你可以长按上方路径进行复制。', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('我知道了')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDrawerFollowing = widget.currentDrawerColor == null;
    final drawerDisplayColor = widget.currentDrawerColor ?? widget.currentThemeColor;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('颜色设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('主题色 (按钮/文字)', style: TextStyle(color: Colors.grey)), 
            const SizedBox(height: 8), 
            _buildColorButton(widget.currentThemeColor, '点击选择', () {
              _pickColor(widget.currentThemeColor, '主题色', (c) => _updateColor(c, 'theme'));
            })
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('背景色', style: TextStyle(color: Colors.grey)), 
            const SizedBox(height: 8), 
            _buildColorButton(widget.currentBgColor, '点击选择', () {
              _pickColor(widget.currentBgColor, '背景色', (c) => _updateColor(c, 'bg'));
            })
          ])),
        ]),
        
        const SizedBox(height: 24),
        const Text('侧边栏设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isDrawerFollowing ? '侧边栏颜色 (跟随主题)' : '侧边栏颜色 (独立)', style: const TextStyle(color: Colors.grey)), 
            const SizedBox(height: 8), 
            _buildColorButton(drawerDisplayColor, '点击选择', () {
              _pickColor(drawerDisplayColor, '侧边栏颜色', (c) => _updateColor(c, 'drawer'));
            })
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('重置', style: TextStyle(color: Colors.grey)), 
            const SizedBox(height: 8), 
            SizedBox(
              height: 60,
              child: OutlinedButton(
                onPressed: isDrawerFollowing ? null : () => _updateColor(Colors.transparent, 'drawer_reset'),
                child: const Text('恢复跟随主题'),
              ),
            )
          ])),
        ]),

        const SizedBox(height: 32),
        const Text('功能设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 1.5)
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PriceRulesPage())),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.price_change, color: Theme.of(context).colorScheme.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('蛋重价格规则', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('根据不同精灵分类，设置蛋重区间自动计算标价', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),

        const Divider(height: 48),
        const Text('数据管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // ============ 新增：导出 Excel ============
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
            padding: const EdgeInsets.symmetric(vertical: 12), 
            backgroundColor: Colors.green.shade50, 
            foregroundColor: Colors.green.shade800
          ),
          onPressed: () async { 
            final path = await AppDatabase.instance.exportToExcel(); 
            if (path != null && context.mounted) {
              _showExportSuccessDialog(path);
            }
          }, 
          icon: const Icon(Icons.table_chart), 
          label: const Text('导出精灵蛋数据 (Excel 表格)')
        ),
        const SizedBox(height: 16),
        // ==========================================

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
          onPressed: () async { 
            final path = await AppDatabase.instance.exportBackup(); 
            if (path != null && context.mounted) {
              _showExportSuccessDialog(path); 
            }
          }, 
          icon: const Icon(Icons.download), label: const Text('导出全量备份 (包含所有数据)')
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
            if (path != null && context.mounted) {
              _showExportSuccessDialog(path); 
            }
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
