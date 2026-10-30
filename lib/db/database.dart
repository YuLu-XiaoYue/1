import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:file_picker/file_picker.dart';

String appDocsPath = '';

class AppDatabase {
  // ... [前面的代码保持不变，一直到 exportToExcel] ...
  
  // 为了篇幅，这里省略上面没有改动的代码，你只需把这部分追加在文件最底部，或者直接复制完整的
}

// ... copyImageToLocal 保持不变 ...

// 以下是新增的核心同步逻辑：
Future<String?> syncEggImage(String name, String? tempNewPath, String? currentPath) async {
  final db = await AppDatabase.instance.db;
  String? finalPath = currentPath;

  if (tempNewPath != null) {
    // 1. 保存新图片到本地
    finalPath = await copyImageToLocal(tempNewPath, 'egg_icons');
    
    // 2. 找出所有同名记录（不管是在蛋库还是父母本库）
    final sameNameEggs = await db.query('eggs', where: 'name = ?', whereArgs: [name]);
    final sameNameParents = await db.query('parents', where: 'name = ?', whereArgs: [name]);
    
    // 3. 收集旧图准备物理删除
    Set<String> oldFilesToDelete = {};
    for (var row in sameNameEggs) {
      if (row['icon_path'] != null && row['icon_path'] != finalPath) oldFilesToDelete.add(row['icon_path'] as String);
    }
    for (var row in sameNameParents) {
      if (row['icon_path'] != null && row['icon_path'] != finalPath) oldFilesToDelete.add(row['icon_path'] as String);
    }
    
    // 4. 批量更新数据库中的图片路径
    await db.update('eggs', {'icon_path': finalPath}, where: 'name = ?', whereArgs: [name]);
    await db.update('parents', {'icon_path': finalPath}, where: 'name = ?', whereArgs: [name]);
    
    // 5. 物理删除旧图片文件
    for (var oldFile in oldFilesToDelete) {
      final f1 = File(p.join(appDocsPath, 'egg_icons', oldFile));
      final f2 = File(p.join(appDocsPath, 'parent_icons', oldFile));
      if (await f1.exists()) await f1.delete();
      if (await f2.exists()) await f2.delete();
    }
  } else if (finalPath == null) {
    // 没传新图，且当前没图，找同名继承
    final exist = await db.query('eggs', where: 'name = ? AND icon_path IS NOT NULL', whereArgs: [name], limit: 1);
    if (exist.isNotEmpty) {
       finalPath = exist.first['icon_path'] as String?;
    } else {
       final existParent = await db.query('parents', where: 'name = ? AND icon_path IS NOT NULL', whereArgs: [name], limit: 1);
       if (existParent.isNotEmpty) finalPath = existParent.first['icon_path'] as String?;
    }
  }
  return finalPath;
}

Future<String?> syncParentImage(String name, String? tempNewPath, String? currentPath) async {
  final db = await AppDatabase.instance.db;
  String? finalPath = currentPath;

  if (tempNewPath != null) {
    finalPath = await copyImageToLocal(tempNewPath, 'parent_icons');
    
    final sameNameEggs = await db.query('eggs', where: 'name = ?', whereArgs: [name]);
    final sameNameParents = await db.query('parents', where: 'name = ?', whereArgs: [name]);
    
    Set<String> oldFilesToDelete = {};
    for (var row in sameNameEggs) {
      if (row['icon_path'] != null && row['icon_path'] != finalPath) oldFilesToDelete.add(row['icon_path'] as String);
    }
    for (var row in sameNameParents) {
      if (row['icon_path'] != null && row['icon_path'] != finalPath) oldFilesToDelete.add(row['icon_path'] as String);
    }
    
    await db.update('eggs', {'icon_path': finalPath}, where: 'name = ?', whereArgs: [name]);
    await db.update('parents', {'icon_path': finalPath}, where: 'name = ?', whereArgs: [name]);
    
    for (var oldFile in oldFilesToDelete) {
      final f1 = File(p.join(appDocsPath, 'egg_icons', oldFile));
      final f2 = File(p.join(appDocsPath, 'parent_icons', oldFile));
      if (await f1.exists()) await f1.delete();
      if (await f2.exists()) await f2.delete();
    }
  } else if (finalPath == null) {
    final exist = await db.query('parents', where: 'name = ? AND icon_path IS NOT NULL', whereArgs: [name], limit: 1);
    if (exist.isNotEmpty) {
       finalPath = exist.first['icon_path'] as String?;
    } else {
       final existEgg = await db.query('eggs', where: 'name = ? AND icon_path IS NOT NULL', whereArgs: [name], limit: 1);
       if (existEgg.isNotEmpty) finalPath = existEgg.first['icon_path'] as String?;
    }
  }
  return finalPath;
}

Widget getLocalImage(String? imageName, String folderName, {double size = 40, IconData fallbackIcon = Icons.egg}) {
  if (imageName == null || imageName.isEmpty) return Icon(fallbackIcon, size: size, color: Colors.grey);
  final file = File(p.join(appDocsPath, folderName, imageName));
  if (!file.existsSync()) return Icon(fallbackIcon, size: size, color: Colors.grey);
  return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, width: size, height: size, fit: BoxFit.cover));
}
