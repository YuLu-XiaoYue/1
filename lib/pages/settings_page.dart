import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';
import 'price_rules_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Color _themeColor = Colors.teal;
  Color _bgColor = const Color(0xFFF5F5F5);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeColor = Color(prefs.getInt('theme_color') ?? Colors.teal.value);
      _bgColor = Color(prefs.getInt('bg_color') ?? 0xFFF5F5F5);
    });
  }

  // 实时更新颜色并保存
  void _updateColor(Color color, bool isTheme) {
    setState(() {
      if (isTheme) {
        _themeColor = color;
      } else {
        _bgColor = color;
      }
    });
    // 这里我们通过全局状态通知机制（这里用简单的内置回调模拟）
    // 实际上它会触发整个 MaterialApp 重建
    SharedPreferences.getInstance().then((p) => p.setInt(isTheme ? 'theme_color' : 'bg_color', color.value));
  }

  void _pickColor(bool isTheme) async {
    Color picked = isTheme ? _themeColor : _bgColor;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isTheme ? '选择主题色' : '选择背景色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked, 
            onColorChanged: (color) {
              picked = color;
              _updateColor(color, isTheme); // 实时预览
            }, 
            enableAlpha: false, 
            displayThumbColor: true, 
            paletteType: PaletteType.hsvWithHue
          )
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              // 提示重启或通过顶层状态刷新（由于咱们结构里State是局部的，这里其实已经实时改了）
            }, 
            child: const Text('确定')
          ),
        ],
      ),
    );
  }

  // 图1风格的按钮组件
  Widget _buildColorButton(Color color, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('颜色设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('主题色 (按钮/顶栏)', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            // 使用图1风格的按钮
            _buildColorButton(_themeColor, '点击选择', () => _pickColor(true)),
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('背景色', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            _buildColorButton(_bgColor, '点击选择', () => _pickColor(false)),
          ])),
        ]),
        const SizedBox(height: 24),
        ListTile(leading: const Icon(Icons.price_change), title: const Text('蛋重价格规则'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PriceRulesPage()))),
        const Divider(),
        const SizedBox(height: 20),
        const Text('数据管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // 图5的按钮风格保持不变
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant
          ),
          onPressed: () async { final path = await AppDatabase.instance.exportBackup(); if (path != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('备份成功！'))); }, 
          icon: const Icon(Icons.download), 
          label: const Text('导出备份 (保存为JSON)')
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: Colors.red.shade50, 
            foregroundColor: Colors.red
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('危险操作'), content: const Text('导入备份会覆盖当前所有的数据，确定继续吗？'),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定覆盖'))],
            ));
            if (confirm == true) {
              final success = await AppDatabase.instance.importBackup();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '恢复成功！请重启APP查看' : '恢复失败或取消')));
            }
          },
          icon: const Icon(Icons.upload), label: const Text('导入恢复 (覆盖当前数据)'),
        ),
      ],
    );
  }
}
