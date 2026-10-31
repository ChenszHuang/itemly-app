import 'package:flutter/material.dart';

import 'category_screen.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const AppShell({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedPage = 0;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedPage == 0 ? 'Product Catalog' : 'Categories'),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const DrawerHeader(
                child: Center(
                  child: Text(
                    'Itemly',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home'),
                selected: _selectedPage == 0,
                onTap: () => _selectPage(0),
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Categories'),
                selected: _selectedPage == 1,
                onTap: () => _selectPage(1),
              ),
              const Divider(),
              SwitchListTile(
                secondary: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode_outlined,
                ),
                title: const Text('Dark mode'),
                value: isDarkMode,
                onChanged: (enabled) => widget.onThemeModeChanged(
                  enabled ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedPage,
        children: const [HomeScreen(), CategoryScreen()],
      ),
    );
  }

  void _selectPage(int page) {
    Navigator.pop(context);
    setState(() => _selectedPage = page);
  }
}
