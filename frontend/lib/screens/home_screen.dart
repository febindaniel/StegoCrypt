import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'encode_screen.dart';
import 'decode_screen.dart';
import 'settings_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 0 = Encrypt, 1 = Decrypt
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                          "Steganography Tool",
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                         Text(
                          "Hide secret messages within images using advanced encryption",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Theme Toggle (Icon Button)
                  IconButton(
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    onPressed: () {
                      themeProvider.toggleTheme(!isDark);
                    },
                    tooltip: "Toggle Theme",
                  ),
                ],
              ),
            ),

            // Toggle Switch
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 300,
                  child: SegmentedButton<int>(
                    segments: const [
                       ButtonSegment(
                        value: 0, 
                        label: Text("Encrypt"), 
                        icon: Icon(Icons.lock_outline, size: 18),
                      ),
                       ButtonSegment(
                        value: 1, 
                        label: Text("Decrypt"), 
                        icon: Icon(Icons.lock_open, size: 18),
                      ),
                    ],
                    selected: {_selectedIndex},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _selectedIndex = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.standard,
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 20)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content Area
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  EncodeScreen(),
                  DecodeScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
