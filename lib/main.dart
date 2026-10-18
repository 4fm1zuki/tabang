import 'package:flutter/material.dart';

// Import your dashboards
import 'dashboard.dart'; // Donor / Recipient Dashboard
import 'admin_dashboard.dart'; // System Admin Dashboard

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TabangApp());
}

class TabangApp extends StatefulWidget {
  const TabangApp({super.key});

  @override
  State<TabangApp> createState() => _TabangAppState();
}

class _TabangAppState extends State<TabangApp> {
  ThemeMode themeMode = ThemeMode.system;

  void _handleThemeChange(ThemeMode mode) {
    setState(() {
      themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TABANG',
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFD3D3D3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFF181818),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: themeMode,
      home: LoginScreen(
        themeMode: themeMode,
        onThemeChanged: _handleThemeChange,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const LoginScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedRole = 'admin'; // Defaults to Admin for quick preview

  void _login() {
    Widget destination;

    if (_selectedRole == 'admin') {
      destination = AdminDashboard(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      );
    } else {
      destination = Dashboard(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.water_drop, color: Color(0xFF7A1C1E), size: 48),
              const SizedBox(height: 12),
              const Text(
                'TABANG Access Portal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Role Selector Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Select Portal Access Role',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('System Admin Dashboard'),
                  ),
                  DropdownMenuItem(
                    value: 'donor',
                    child: Text('Donor / Recipient Dashboard'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A1C1E),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Open Selected Dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}