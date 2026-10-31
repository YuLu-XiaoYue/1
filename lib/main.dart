import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'db/database.dart';
import 'pages/egg_list_page.dart';
import 'pages/pairing_page.dart';
import 'pages/parent_page.dart';
import 'pages/settings_page.dart';
import 'pages/blacklist_page.dart';
import 'pages/article_page.dart';
import 'pages/production_line_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.db;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Color _themeColor = Colors.teal;
  Color _bgColor = const Color(0xFFF5F5F5);
  Color? _drawerColor;
  Color _cardColor = Colors.white; // 新增：卡片独立背景色

  @override
  void initState() { super.initState(); _loadTheme(); }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeColor = Color(prefs.getInt('theme_color') ?? Colors.teal.value);
      _bgColor = Color(prefs.getInt('bg_color') ?? 0xFFF5F5F5);
      int? dc = prefs.getInt('drawer_color');
      _drawerColor = dc != null ? Color(dc) : null;
      _cardColor = Color(prefs.getInt('card_color') ?? Colors.white.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '精灵蛋仓库',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      locale: const Locale('zh', 'CN'),
      theme: ThemeData(
        colorSchemeSeed: _themeColor, 
        scaffoldBackgroundColor: _bgColor,
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei',
        fontFamilyFallback: const ['PingFang SC', 'Roboto', 'sans-serif'],
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
      ),
      home: MainLayout(
        currentThemeColor: _themeColor, 
        currentBgColor: _bgColor, 
        currentDrawerColor: _drawerColor,
        currentCardColor: _cardColor,
        onThemeColorChanged: (c) => setState(() => _themeColor = c),
        onBgColorChanged: (c) => setState(() => _bgColor = c),
        onDrawerColorChanged: (c) => setState(() => _drawerColor = c),
        onCardColorChanged: (c) => setState(() => _cardColor = c),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  final Color currentThemeColor; 
  final Color currentBgColor; 
  final Color? currentDrawerColor;
  final Color currentCardColor;
  final Function(Color) onThemeColorChanged; 
  final Function(Color) onBgColorChanged; 
  final Function(Color?) onDrawerColorChanged;
  final Function(Color) onCardColorChanged;
  
  const MainLayout({
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
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _index = 0;
  final List<String> _titles = ['精灵蛋仓库', '产线', '已售出', '售后订单', '黑名单', '配对库', '父母本库', '新手教学', '更新日志', '设置'];
  String _versionText = '加载中...'; 

  final GlobalKey<EggListPageState> _eggKey0 = GlobalKey();
  final GlobalKey<EggListPageState> _eggKey1 = GlobalKey();
  final GlobalKey<EggListPageState> _eggKey2 = GlobalKey();
  final GlobalKey<PairingPageState> _pairingKey = GlobalKey();
  final GlobalKey<ParentPageState> _parentKey = GlobalKey();
  final GlobalKey<ProductionLinePageState> _lineKey = GlobalKey();

  @override
  void initState() { super.initState(); _loadVersion(); }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _versionText = 'v${info.version}');
  }

  @override
  Widget build(BuildContext context) {
    final drawerColor = widget.currentDrawerColor ?? widget.currentThemeColor;

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: GestureDetector(
        onHorizontalDragEnd: (details) { if (details.primaryVelocity != null && details.primaryVelocity! < 0) Navigator.pop(context); },
        child: Drawer(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: drawerColor),
                child: const Align(alignment: Alignment.bottomLeft, child: Text('精灵蛋仓库', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
              ),
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
                  _navItem(0, Icons.inventory, '精灵蛋仓库'),
                  _navItem(1, Icons.precision_manufacturing, '产线'),
                  _navItem(2, Icons.sell, '已售出'),
                  _navItem(3, Icons.handyman, '售后订单'),
                  _navItem(4, Icons.block, '黑名单'),
                  _navItem(5, Icons.family_restroom, '配对库'),
                  _navItem(6, Icons.people, '父母本库'),
                  const Divider(),
                  _navItem(7, Icons.menu_book, '新手教学'),
                  _navItem(8, Icons.history, '更新日志'),
                  _navItem(9, Icons.settings, '设置'),
                ]),
              ),
              Padding(padding: const EdgeInsets.all(16), child: Text('当前版本: $_versionText', style: const TextStyle(color: Colors.grey, fontSize: 12))),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          EggListPage(key: _eggKey0, viewType: '在库/预定'),
          ProductionLinePage(key: _lineKey, cardColor: widget.currentCardColor), // 传入卡片底色
          EggListPage(key: _eggKey1, viewType: '已售出'),
          EggListPage(key: _eggKey2, viewType: '售后订单'),
          const BlacklistPage(),
          PairingPage(key: _pairingKey),
          ParentPage(key: _parentKey),
          const ArticlePage(type: 'tutorial', title: '新手教学'),
          const ArticlePage(type: 'log', title: '更新日志'),
          SettingsPage(
            currentThemeColor: widget.currentThemeColor,
            currentBgColor: widget.currentBgColor,
            currentDrawerColor: widget.currentDrawerColor,
            currentCardColor: widget.currentCardColor,
            onThemeColorChanged: widget.onThemeColorChanged,
            onBgColorChanged: widget.onBgColorChanged,
            onDrawerColorChanged: widget.onDrawerColorChanged,
            onCardColorChanged: widget.onCardColorChanged,
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon), title: Text(title), selected: _index == index, 
      onTap: () { 
        setState(() => _index = index); Navigator.pop(context); 
        if (index == 0) _eggKey0.currentState?.loadData();
        if (index == 1) _lineKey.currentState?.loadData();
        if (index == 2) _eggKey1.currentState?.loadData();
        if (index == 3) _eggKey2.currentState?.loadData();
        if (index == 5) _pairingKey.currentState?.loadData();
        if (index == 6) _parentKey.currentState?.loadData();
      }
    );
  }
}
