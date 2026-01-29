
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isLoading = true;
  bool _isLocked = false;
  String? _storedPassword;
  final TextEditingController _passwordController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    // BYPASS LOCK SCREEN
    // Wait for the end of the frame to avoid "!navigator._debugLocked" error
    await Future.delayed(Duration.zero);
    if (mounted) {
      _unlock();
    }
  }

  void _unlock() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _validate() {
    if (_passwordController.text == _storedPassword) {
      _unlock();
    } else {
      setState(() {
        _error = "Incorrect Password";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Only show simple UI if locked
    if (_isLocked) {
      return Scaffold(
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 64, color: Colors.deepPurple),
                const SizedBox(height: 24),
                const Text("Enter Master Password", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _validate(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _validate,
                    child: const Text("UNLOCK"),
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink(); 
  }
}
