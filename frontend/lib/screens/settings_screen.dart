
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _masterPasswordEnabled = false;
  final TextEditingController _masterPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _masterPasswordEnabled = prefs.getBool('masterPasswordEnabled') ?? false;
      _masterPassController.text = prefs.getString('masterPassword') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('masterPasswordEnabled', _masterPasswordEnabled);
    if (_masterPasswordEnabled) {
      await prefs.setString('masterPassword', _masterPassController.text);
    } else {
      await prefs.remove('masterPassword');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Settings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (val) {
              themeProvider.toggleTheme(val);
            },
          ),
          
          const Divider(),
          
          SwitchListTile(
            title: const Text("Enable Master Password (App Lock)"),
            subtitle: const Text("Require password to open the app (Mock Feature)"),
            value: _masterPasswordEnabled,
            onChanged: (val) {
              setState(() {
                _masterPasswordEnabled = val;
              });
            },
          ),
          
          if (_masterPasswordEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextFormField(
                controller: _masterPassController,
                decoration: const InputDecoration(
                  labelText: "Master Password",
                ),
                obscureText: true,
              ),
            ),
            
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: _saveSettings,
              child: const Text("Save Settings"),
            ),
          )
        ],
      ),
    );
  }
}
