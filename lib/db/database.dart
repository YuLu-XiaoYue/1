import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; // 新增
import 'package:excel/excel.dart'; // 新增
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:file_picker/file_picker.dart';

String appDocsPath = '';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    appDocsPath = dir.path;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = p.join(dir.path, 'elf_egg_v16.db'); 
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, account_id TEXT)');
          await db.execute('CREATE TABLE parents(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, gender TEXT, account TEXT, nature TEXT, height REAL, weight REAL, voice REAL, bloodline TEXT, icon_path TEXT, created_at INTEGER, appearance TEXT)');
          await db.execute('CREATE TABLE pairings(id INTEGER PRIMARY KEY AUTOINCREMENT, account TEXT, mother_id INTEGER)');
          await db.execute('CREATE TABLE pairing_fathers(pairing_id INTEGER, father_id INTEGER, PRIMARY KEY(pairing_id, father_id))');
          await db.execute('CREATE TABLE eggs(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, weight REAL, medals TEXT, nature TEXT, account TEXT, pairing_id INTEGER, father_id INTEGER, mother_id INTEGER, father_name_snapshot TEXT, mother_name_snapshot TEXT, icon_path TEXT, price REAL, status TEXT, sale_platform TEXT, buyer_platform_name TEXT, buyer_platform_id TEXT, buyer_game_name TEXT, buyer_game_id TEXT, note TEXT, created_at INTEGER, updated_at INTEGER, nest_type TEXT, obtained_date TEXT, after_sales_plan TEXT, is_after_sales INTEGER)');
          await db.execute('CREATE TABLE price_rules(id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT, min_weight REAL, max_weight REAL, price REAL)');
          await db.execute('CREATE TABLE blacklist(id INTEGER PRIMARY KEY AUTOINCREMENT, platform TEXT, buyer_name TEXT, platform_id TEXT, game_id TEXT, reason TEXT)');
          await db.execute('CREATE TABLE egg_categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');
          await db.execute('CREATE TABLE articles(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, content TEXT)');
          
          await db.insert('accounts', {'name': '默认账号', 'account_id': ''});
          
          String tutorialContent = '欢迎使用精灵蛋仓库！';
          String logContent = 'v1.0.0\n- 初始版本发布。';
          try {
            tutorialContent = await rootBundle.loadString('assets/tutorial.txt');
            logContent = await rootBundle.loadString('assets/update_log.txt');
          } catch (e) { debugPrint('未找到默认文本文件'); }
          
          await db.insert('articles', {'type': 'tutorial', 'content': tutorialContent});
          await db.insert('articles', {'type': 'log', 'content': logContent});
        },
      ),
    );
  }

  // ... (备份相关方法保持不变)
  Future<String?> exportBackup() async {
    final db = await instance.db;
    final tables = ['accounts', 'parents', 'pairings', 'pairing_fathers', 'eggs', 'price_rules', 'blacklist', 'egg_categories', 'articles'];
    Map<String, dynamic> backup = {};
    for (var t in tables) { backup[t] = await db.query(t); }
    String jsonStr = jsonEncode(backup);
    try {
      return await FilePicker.platform.saveFile(dialogTitle: '保存备份文件', fileName: 'elf_egg_backup.json', bytes: utf8.encode(jsonStr));
    } catch (e) { return null; }
  }

  Future<bool> importBackup() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (res == null || res.files.single.path == null) return false;
      final jsonStr = await File(res.files.single.path!).readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (!data.containsKey('eggs') || !data.containsKey('parents')) return false;

      final db = await instance.db;
      await db.transaction((txn) async {
        for (var t in ['accounts', 'parents', 'pairings', 'pairing_fathers', 'eggs', 'price_rules', 'blacklist', 'egg_categories', 'articles']) {
          await txn.delete(t);
          for (var row in data[t] ?? []) { await txn.insert(t, Map<String, dynamic>.from(row)); }
        }
      });
      return true;
    } catch (e) { return false; }
  }

  Future<String?> exportArticlesOnly() async {
    final db = await instance.db;
    final rows = await db.query('articles');
    String jsonStr = jsonEncode({'articles': rows});
    try {
      return await FilePicker.platform.saveFile(dialogTitle: '保存文本备份', fileName: 'elf_egg_text_backup.json', bytes: utf8.encode(jsonStr));
    } catch (e) { return null; }
  }

  Future<bool> importArticlesOnly() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (res == null || res.files.single.path == null) return false;
      final jsonStr = await File(res.files.single.path!).readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (!data.containsKey('articles')) return false;

      final db = await instance.db;
      await db.transaction((txn) async {
        await txn.delete('articles');
        for (var row in data['articles']) { await txn.insert('articles', Map<String, dynamic>.from(row)); }
      });
      return true;
    } catch (e) { return false; }
  }

  // ================= 新增：导出为 Excel =================
  Future<String?> exportToExcel() async {
    final db = await instance.db;
    final eggs = await db.query('eggs', orderBy: 'created_at DESC');

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['精灵蛋数据'];
    
    // 删除默认的 Sheet1
    excel.delete('Sheet1');

    // 设置表头
    List<String> headers = [
      '蛋名', '重量(kg)', '窝类型', '收取日期', '性格', '标价', 
      '状态', '售卖平台', '买家平台名称', '买家平台ID', '买家游戏名称', '买家游戏ID', 
      '父本(快照)', '母本(快照)', '备注', '售后方案'
    ];
    
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // 写入数据
    for (var row in eggs) {
      sheetObject.appendRow([
        TextCellValue(row['name']?.toString() ?? ''),
        DoubleCellValue((row['weight'] as num?)?.toDouble() ?? 0),
        TextCellValue(row['nest_type']?.toString() ?? '普窝'),
        TextCellValue(row['obtained_date']?.toString() ?? ''),
        TextCellValue(row['nature']?.toString() ?? ''),
        DoubleCellValue((row['price'] as num?)?.toDouble() ?? 0),
        TextCellValue(row['status']?.toString() ?? '在库'),
        TextCellValue(row['sale_platform']?.toString() ?? ''),
        TextCellValue(row['buyer_platform_name']?.toString() ?? ''),
        TextCellValue(row['buyer_platform_id']?.toString() ?? ''),
        TextCellValue(row['buyer_game_name']?.toString() ?? ''),
        TextCellValue(row['buyer_game_id']?.toString() ?? ''),
        TextCellValue(row['father_name_snapshot']?.toString() ?? ''),
        TextCellValue(row['mother_name_snapshot']?.toString() ?? ''),
        TextCellValue(row['note']?.toString() ?? ''),
        TextCellValue(row['after_sales_plan']?.toString() ?? ''),
      ]);
    }

    // 调整列宽（可选优化）
    for (var i = 0; i < headers.length; i++) {
      sheetObject.setColumnWidth(i, 15.0);
    }

    // 生成文件并保存
    List<int>? fileBytes = excel.save();
    if (fileBytes != null) {
      try {
        return await FilePicker.platform.saveFile(
          dialogTitle: '保存 Excel 表格',
          fileName: '精灵蛋数据导出.xlsx',
          bytes: Uint8List.fromList(fileBytes),
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

Future<String> copyImageToLocal(String sourcePath, String folderName) async {
  final dir = Directory(p.join(appDocsPath, folderName));
  if (!await dir.exists()) await dir.create(recursive: true);
  final ext = p.extension(sourcePath).isEmpty ? '.png' : p.extension(sourcePath);
  final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
  await File(sourcePath).copy(p.join(dir.path, name));
  return name;
}

Widget getLocalImage(String? imageName, String folderName, {double size = 40, IconData fallbackIcon = Icons.egg}) {
  if (imageName == null || imageName.isEmpty) return Icon(fallbackIcon, size: size, color: Colors.grey);
  final file = File(p.join(appDocsPath, folderName, imageName));
  if (!file.existsSync()) return Icon(fallbackIcon, size: size, color: Colors.grey);
  return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, width: size, height: size, fit: BoxFit.cover));
}
