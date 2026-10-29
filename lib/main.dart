import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/database.dart';
import 'pages/egg_list_page.dart';
import 'pages/pairing_page.dart';
import 'pages/parent_page.dart';
import 'pages/settings_page.dart';
import 'pages/blacklist_page.dart';
import 'pages/article_page.dart';

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

  @override
  void initState() { super.initState(); _loadTheme(); }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeColor = Color(prefs.getInt('theme_color') ?? Colors.teal.value);
      _bgColor = Color(prefs.getInt('bg_color') ?? 0xFFF5F5F5);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '精灵蛋仓库',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: _themeColor, 
        scaffoldBackgroundColor: _bgColor,
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei',
        fontFamilyFallback: const ['PingFang SC', 'Roboto', 'sans-serif'],
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
      ),
      home: MainLayout(
        currentThemeColor: _themeColor, currentBgColor: _bgColor,
        onThemeColorChanged: (c) => setState(() => _themeColor = c),
        onBgColorChanged: (c) => setState(() => _bgColor = c),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  final Color currentThemeColor;
  final Color currentBgColor;
  final Function(Color) onThemeColorChanged;
  final Function(Color) onBgColorChanged;
  const MainLayout({super.key, required this.currentThemeColor, required this.currentBgColor, required this.onThemeColorChanged, required this.onBgColorChanged});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _index = 0;
  final List<String> _titles = ['精灵蛋', '已售出', '售后订单', '黑名单', '配对库', '父母本库', '新手教学', '更新日志', '设置'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: GestureDetector(
        onHorizontalDragEnd: (details) { if (details.primaryVelocity != null && details.primaryVelocity! < 0) Navigator.pop(context); },
        child: Drawer(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
                child: const Align(alignment: Alignment.bottomLeft, child: Text('精灵蛋仓库', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
              ),
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
                  _navItem(0, Icons.egg, '精灵蛋'),
                  _navItem(1, Icons.sell, '已售出'),
                  _navItem(2, Icons.handyman, '售后订单'),
                  _navItem(3, Icons.block, '黑名单'),
                  _navItem(4, Icons.family_restroom, '配对库'),
                  _navItem(5, Icons.people, '父母本库'),
                  const Divider(),
                  _navItem(6, Icons.menu_book, '新手教学'),
                  _navItem(7, Icons.history, '更新日志'),
                  _navItem(8, Icons.settings, '设置'),
                ]),
              ),
              const Padding(padding: EdgeInsets.all(16), child: Text('当前版本: v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12))),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          EggListPage(viewType: '在库/预定'),
          EggListPage(viewType: '已售出'),
          EggListPage(viewType: '售后订单'),
          BlacklistPage(),
          PairingPage(),
          ParentPage(),
          ArticlePage(type: 'tutorial', title: '新手教学'),
          ArticlePage(type: 'log', title: '更新日志'),
          SettingsPage(),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String title) {
    return ListTile(leading: Icon(icon), title: Text(title), selected: _index == index, onTap: () { setState(() => _index = index); Navigator.pop(context); });
  }
}
