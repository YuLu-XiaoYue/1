import 'dart:convert';

class Account {
  final int? id;
  final String name;
  final String? accountId;
  Account({this.id, required this.name, this.accountId});
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'account_id': accountId};
  factory Account.fromMap(Map<String, Object?> m) => Account(id: m['id'] as int?, name: m['name'] as String, accountId: m['account_id'] as String?);
}

class Parent {
  final int? id;
  final String name;
  final String gender;
  final String account;
  final String? nature;
  final double? height;
  final double? weight;
  final double? voice;
  final String? bloodline;
  final String? iconPath;
  final String appearance; 

  Parent({this.id, required this.name, required this.gender, required this.account, this.nature, this.height, this.weight, this.voice, this.bloodline, this.iconPath, this.appearance = '普通'});

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id, 'name': name, 'gender': gender, 'account': account, 'nature': nature,
    'height': height, 'weight': weight, 'voice': voice, 'bloodline': bloodline, 'icon_path': iconPath, 
    'created_at': DateTime.now().millisecondsSinceEpoch, 'appearance': appearance,
  };

  factory Parent.fromMap(Map<String, Object?> m) => Parent(
    id: m['id'] as int?, name: m['name'] as String, gender: m['gender'] as String, account: m['account'] as String,
    nature: m['nature'] as String?, height: (m['height'] as num?)?.toDouble(), weight: (m['weight'] as num?)?.toDouble(),
    voice: (m['voice'] as num?)?.toDouble(), bloodline: m['bloodline'] as String?, iconPath: m['icon_path'] as String?,
    appearance: m['appearance'] as String? ?? '普通',
  );
}

// 新增：精灵库模型
class Creature {
  final int? id;
  final String name;
  final String? iconPath;
  final List<String> eggGroups;
  
  Creature({this.id, required this.name, this.iconPath, this.eggGroups = const []});

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id, 'name': name, 'icon_path': iconPath, 'egg_groups': jsonEncode(eggGroups),
  };

  factory Creature.fromMap(Map<String, Object?> m) => Creature(
    id: m['id'] as int?, name: m['name'] as String, iconPath: m['icon_path'] as String?,
    eggGroups: (jsonDecode(m['egg_groups'] as String? ?? '[]') as List).cast<String>(),
  );
}

class Pairing {
  final int? id;
  final String account;
  final int motherId;
  final String nestType;
  Pairing({this.id, required this.account, required this.motherId, this.nestType = '普窝'});
  Map<String, Object?> toMap() => {'id': id, 'account': account, 'mother_id': motherId, 'nest_type': nestType};
  factory Pairing.fromMap(Map<String, Object?> m) => Pairing(id: m['id'] as int?, account: m['account'] as String, motherId: m['mother_id'] as int, nestType: m['nest_type'] as String? ?? '普窝');
}

class ProductionLine {
  final int? id;
  final String name; 
  final String accountName;
  final String? accountId;
  final String nestType; 
  final int pairingId;
  final String nature; 
  final String natureProb; 
  final String? iconPath;
  final List<String> medals;
  final List<String> eggGroups; 
  final int? createdAt;

  ProductionLine({
    this.id, required this.name, required this.accountName, this.accountId, required this.nestType,
    required this.pairingId, required this.nature, required this.natureProb, this.iconPath, 
    this.medals = const [], this.eggGroups = const [], this.createdAt,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id, 'name': name, 'account_name': accountName, 'account_id': accountId, 'nest_type': nestType,
    'pairing_id': pairingId, 'nature': nature, 'nature_prob': natureProb, 'icon_path': iconPath, 
    'medals': jsonEncode(medals), 'egg_groups': jsonEncode(eggGroups),
    'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  factory ProductionLine.fromMap(Map<String, Object?> m) => ProductionLine(
    id: m['id'] as int?, name: m['name'] as String, accountName: m['account_name'] as String, accountId: m['account_id'] as String?,
    nestType: m['nest_type'] as String, pairingId: m['pairing_id'] as int, nature: m['nature'] as String, natureProb: m['nature_prob'] as String,
    iconPath: m['icon_path'] as String?, 
    medals: (jsonDecode(m['medals'] as String? ?? '[]') as List).cast<String>(), 
    eggGroups: (jsonDecode(m['egg_groups'] as String? ?? '[]') as List).cast<String>(), 
    createdAt: m['created_at'] as int?,
  );
}

class LinePriceRule {
  final int? id;
  final int lineId;
  final double minWeight;
  final double maxWeight;
  final double price;
  
  LinePriceRule({this.id, required this.lineId, required this.minWeight, required this.maxWeight, required this.price});
  
  Map<String, Object?> toMap() => {'id': id, 'line_id': lineId, 'min_weight': minWeight, 'max_weight': maxWeight, 'price': price};
  
  factory LinePriceRule.fromMap(Map<String, Object?> m) => LinePriceRule(
    id: m['id'] as int?, lineId: m['line_id'] as int, 
    minWeight: (m['min_weight'] as num).toDouble(), maxWeight: (m['max_weight'] as num).toDouble(), price: (m['price'] as num).toDouble()
  );
}

// ... (保留原本的 Egg, Blacklist, Article, 常量列表) ...

const List<String> eggGroupsList = ['巨灵组', '两栖组', '昆虫组', '天空组', '动物组', '妖精组', '植物组', '拟人组', '软体组', '大地组', '魔力组', '海洋组', '龙组', '机械组'];
const List<String> naturesList = ['大胆', '固执', '调皮', '勇敢', '逞强', '稳重', '天真', '懒散', '悠闲', '坦率', '聪明', '专注', '偏执', '冷静', '理性', '警惕', '温顺', '害羞', '慎重', '焦虑', '胆小', '急躁', '开朗', '莽撞', '热情', '沉默', '忧郁', '平和', '粗心', '踏实'];
const List<String> bloodlines = ['普通','草','火','水','光','地','冰','龙','电','毒','虫','武','翼','萌','幽','恶','机械','幻','首领','污染','奇异'];
const List<String> sizeMedals = ['大块头', '满重', '小不点', '满轻'];
const List<String> voiceMedals = ['婉转声', '满音婉转声', '粗嗓门', '满音粗嗓门'];
const List<String> appearanceTypes = ['普通', '异色', '炫彩', '异色炫彩', '黑白', '异色黑白'];

String calculateNature(List<Parent> fathers, Parent mother) {
  String mNature = mother.nature ?? '未知';
  Set<String> fNatures = fathers.map((f) => f.nature ?? '未知').toSet();
  Set<String> allNatures = {mNature, ...fNatures};
  if (allNatures.length >= 3) return '混窝|随机';
  if (fNatures.length == 1) {
    String fNature = fNatures.first;
    if (mNature == fNature) return '$mNature|60%$mNature+40%随机';
    else return '$mNature丨$fNature|30%$mNature+30%$fNature+40%随机';
  } else {
    return '混窝|随机';
  }
}
