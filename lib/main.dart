// 只改 _MainLayoutState 里的 titles 和 body
final List<String> _titles = ['精灵蛋仓库', '产线', '已售出', '售后订单', '黑名单', '配对库', '父母本库', '新手教学', '更新日志', '设置'];

// 左侧 ListView 里：
_navItem(0, Icons.inventory, '精灵蛋仓库'),
_navItem(1, Icons.precision_manufacturing, '产线'),
_navItem(2, Icons.sell, '已售出'),
// ... 依次往后推 ...

// IndexedStack 里：
EggListPage(key: _eggKey0, viewType: '在库/预定'),
const ProductionLinePage(), // 引入产线页
EggListPage(key: _eggKey1, viewType: '已售出'),
EggListPage(key: _eggKey2, viewType: '售后订单'),
const BlacklistPage(),
// ... 依次往后推 ...
