import 'dart:convert';

// ... (Account, Parent, Pairing, ProductionLine 保持原样，直接复制你现在的即可) ...

class LinePriceRule {
  final int? id;
  final int lineId;
  final String nestType; // 新增：区间绑定的窝类型
  final double minWeight;
  final double maxWeight;
  final double price;
  
  LinePriceRule({this.id, required this.lineId, required this.nestType, required this.minWeight, required this.maxWeight, required this.price});
  
  Map<String, Object?> toMap() => {
    'id': id, 'line_id': lineId, 'nest_type': nestType, 
    'min_weight': minWeight, 'max_weight': maxWeight, 'price': price
  };
  
  factory LinePriceRule.fromMap(Map<String, Object?> m) => LinePriceRule(
    id: m['id'] as int?, 
    lineId: m['line_id'] as int, 
    nestType: m['nest_type'] as String? ?? '普窝',
    minWeight: (m['min_weight'] as num).toDouble(), 
    maxWeight: (m['max_weight'] as num).toDouble(), 
    price: (m['price'] as num).toDouble()
  );
}

// ... (Egg, Blacklist, 常量, calculateNature 保持原样) ...
