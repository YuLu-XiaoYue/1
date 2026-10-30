// 这里的 import 和之前一样
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lpinyin/lpinyin.dart';
import 'dart:io'; // 新增：用于预览临时图片
import '../db/database.dart';
import '../models/models.dart';
import 'parent_page.dart'; 

// ... (medalIconMap, _buildMedalChip, EggListPage 列表部分代码保持不变) ...

// 只替换 EggEditPage 和它的 State
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
  String? _tempSelectedImagePath; // 暂存新选的图片路径
  
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

  // ... (_loadLegacyParentData, _loadGroupData, _loadAccounts, _showPairingSelectionDialog, _autoFillPrice, _pickDate) 保持原样 ...

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
    
    // 核心修改：调用 database.dart 里的同步图片方法
    String? finalPath = await syncEggImage(_nameCtrl.text, _tempSelectedImagePath, widget.egg?.iconPath);
    
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
          // 核心修改：如果有临时新图，显示新图，否则显示老图
          _tempSelectedImagePath != null 
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_tempSelectedImagePath!), width: 60, height: 60, fit: BoxFit.cover))
            : getLocalImage(_iconPath, 'egg_icons', size: 60),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () async { 
              final res = await FilePicker.platform.pickFiles(type: FileType.image); 
              if (res != null && res.files.single.path != null) { 
                setState(() => _tempSelectedImagePath = res.files.single.path!); // 这里只暂存，不保存
              } 
            }, 
            icon: const Icon(Icons.image), label: const Text('选图')
          ),
        ]),
        // ... 后面的表单保持不变 ...
        // 注意：结尾的 FloatingActionButton 保持你的“保存/取消”样式
      ]),
    );
  }
}
