import 'dart:convert';

class Account {
  final int? id;
  final String name;
  Account({this.id, required this.name});
  Map<String, Object?> toMap() => {'id': id, 'name': name};
  factory Account.fromMap(Map<String, Object?> m) => Account(id: m['id'] as int?, name: m['name'] as String);
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

  Parent({
    this.id, required this.name, required this.gender, required this.account, 
    this.nature, this.height, this.weight, this.voice, this.bloodline, this.iconPath,
    this.appearance = '普通',
  });

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

class Egg {
  final int? id;
  final String name;
  final double weight;
  final List<String> medals;
  final String? nature;
  final String? account;
  final int? fatherId;
  final int? motherId;
  final String? fatherNameSnapshot; 
  final String? motherNameSnapshot;
  final String? iconPath;
  final double? price;
  final String status;
  final String? salePlatform;
  final String? buyerName;
  final String? buyerGameId;
  final int? createdAt;
  final String nestType; 
  final String obtainedDate;
  final String? afterSalesPlan; 
  final bool isAfterSales; 

  Egg({
    this.id, required this.name, required this.weight, this.medals = const [], this.nature, this.account, 
    this.fatherId, this.motherId, this.fatherNameSnapshot, this.motherNameSnapshot, this.iconPath, this.price, 
    this.status = '在库', this.salePlatform, this.buyerName, this.buyerGameId, this.createdAt,
    this.nestType = '普窝', this.obtainedDate = '', this.afterSalesPlan, this.isAfterSales = false,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id, 'name': name, 'weight': weight, 'medals': jsonEncode(medals),
    'nature': nature, 'account': account, 'father_id': fatherId, 'mother_id': motherId,
    'father_name_snapshot': fatherNameSnapshot, 'mother_name_snapshot': motherNameSnapshot,
    'icon_path': iconPath, 'price': price, 'status': status, 'sale_platform': salePlatform,
    'buyer_name': buyerName, 'buyer_game_id': buyerGameId,
    'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch, 'updated_at': DateTime.now().millisecondsSinceEpoch,
    'nest_type': nestType, 'obtained_date': obtainedDate, 'after_sales_plan': afterSalesPlan, 'is_after_sales': isAfterSales ? 1 : 0,
  };

  factory Egg.fromMap(Map<String, Object?> m) => Egg(
    id: m['id'] as int?, name: m['name'] as String, weight: (m['weight'] as num).toDouble(),
    medals: (jsonDecode(m['medals'] as String? ?? '[]') as List).cast<String>(),
    nature: m['nature'] as String?, account: m['account'] as String?, fatherId: m['father_id'] as int?, motherId: m['mother_id'] as int?,
    fatherNameSnapshot: m['father_name_snapshot'] as String?, motherNameSnapshot: m['mother_name_snapshot'] as String?,
    iconPath: m['icon_path'] as String?, price: (m['price'] as num?)?.toDouble(), status: m['status'] as String? ?? '在库',
    salePlatform: m['sale_platform'] as String?, buyerName: m['buyer_name'] as String?, buyerGameId: m['buyer_game_id'] as String?,
    createdAt: m['created_at'] as int?, nestType: m['nest_type'] as String? ?? '普窝', obtainedDate: m['obtained_date'] as String? ?? '',
    afterSalesPlan: m['after_sales_plan'] as String?, isAfterSales: (m['is_after_sales'] as int? ?? 0) == 1,
  );
}

class Blacklist {
  final int? id;
  final String platform;
  final String buyerName;
  final String platformId;
  final String gameId;
  final String? reason;

  Blacklist({this.id, required this.platform, required this.buyerName, required this.platformId, required this.gameId, this.reason});

  Map<String, Object?> toMap() => {'id': id, 'platform': platform, 'buyer_name': buyerName, 'platform_id': platformId, 'game_id': gameId, 'reason': reason};
  factory Blacklist.fromMap(Map<String, Object?> m) => Blacklist(id: m['id'] as int?, platform: m['platform'] as String, buyerName: m['buyer_name'] as String, platformId: m['platform_id'] as String, gameId: m['game_id'] as String, reason: m['reason'] as String?);
}

class Article {
  final int? id;
  final String type; // 'tutorial' 或 'log'
  final String content;
  Article({this.id, required this.type, required this.content});
  Map<String, Object?> toMap() => {'id': id, 'type': type, 'content': content};
  factory Article.fromMap(Map<String, Object?> m) => Article(id: m['id'] as int?, type: m['type'] as String, content: m['content'] as String);
}

const List<String> bloodlines = ['草','火','水','光','地','冰','龙','电','毒','虫','武','翼','萌','幽','恶','幻','机械','普通','奇异','首领','污染'];
const List<String> sizeMedals = ['大块头', '满重', '小不点', '满轻'];
const List<String> voiceMedals = ['婉转声', '满音婉转声', '粗嗓门', '满音粗嗓门'];
const List<String> appearanceTypes = ['普通', '异色', '炫彩', '异色炫彩', '黑白', '异色黑白'];
