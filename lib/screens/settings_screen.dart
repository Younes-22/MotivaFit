import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';

// The central hub for user preferences. This screen allows the user to tweak their app theme, update their dietary goals, export their data, and log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// Holds the active state for the Settings screen, including the text controllers and the preset lists used in the dropdowns and dialogs.
class _SettingsScreenState extends State<SettingsScreen> {
  final PdfService _pdfService = PdfService();
  final TextEditingController _customController = TextEditingController();

  // A handy list of common diets and allergies so the user can just tap what they need instead of typing it out manually every time.
  final List<String> _presetRestrictions = [
    'Halal', 'Vegan', 'Vegetarian', 'Pescetarian', 
    'Gluten-Free', 'Dairy-Free', 'Keto', 'No Nuts',
  ];

  final List<String> _goals = ['Lose Weight', 'Maintain', 'Build Muscle'];

  // Completely clears the current user's active session and safely kicks them all the way back to the main Login/Sign Up screen.
  void _handleLogout() {
    AuthService().signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Tells the PDF service to start building the weekly progress report. It throws up a snackbar so the user knows it's working in the background.
  Future<void> _handleExportReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF Report... please wait.')),
    );
    try {
      await _pdfService.generateAndDownloadReport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // The main layout. We wrap the whole body in a StreamBuilder so if the user changes a setting, the UI instantly reacts without needing a page refresh.
  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StreamBuilder<UserModel>(
        stream: firestore.getUserStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final user = snapshot.data!;
          List<String> userRestrictions = List.from(user.dietaryRestrictions);
          
          // Checks what theme the user currently has active in the database. If they bought a special theme from the shop, we  default the dropdown to 'custom'.
          String themeValue;
          if (['system', 'default'].contains(user.selectedThemeId)) {
            themeValue = 'system';
          } else if (user.selectedThemeId == 'theme_light') {
            themeValue = 'theme_light';
          } else if (user.selectedThemeId == 'theme_dark') {
            themeValue = 'theme_dark';
          } else {
            themeValue = 'custom';
          }

          return ListView(
            children: [
              const SizedBox(height: 20),
              
              // Apperance section
              _buildSectionHeader('Appearance'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("App Theme", style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: themeValue,
                      items: [
                        const DropdownMenuItem(value: 'system', child: Text('📱 System Default')),
                        const DropdownMenuItem(value: 'theme_light', child: Text('☀️ Light Mode')),
                        const DropdownMenuItem(value: 'theme_dark', child: Text('🌙 Dark Mode')),
                        if (themeValue == 'custom')
                          const DropdownMenuItem(value: 'custom', child: Text('✨ Custom Theme Equipped')),
                      ],
                      onChanged: (newTheme) {
                        if (newTheme != null && newTheme != 'custom') {
                          firestore.equipTheme(newTheme);
                        }
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (themeValue == 'custom')
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          'Select a standard theme to unequip your shop theme.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),

              // Fitness & diet section
              _buildSectionHeader('Fitness & Diet'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current Goal", style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: user.fitnessGoal,
                      items: _goals.map((goal) => DropdownMenuItem(value: goal, child: Text(goal))).toList(),
                      onChanged: (newGoal) {
                        if (newGoal != null) {
                          firestore.updateDietaryPreferences(restrictions: userRestrictions, goal: newGoal);
                        }
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Dietary Restrictions & Allergies", style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    
                    // Creates a wrap of chips. Users can easily tap the 'x' on an existing restriction to remove it, or tap 'Add New' to pop open the dialog.
                    Wrap(
                      spacing: 8,
                      children: [
                        ...userRestrictions.map((restriction) => InputChip(
                          label: Text(restriction),
                          onDeleted: () {
                            userRestrictions.remove(restriction);
                            firestore.updateDietaryPreferences(restrictions: userRestrictions, goal: user.fitnessGoal);
                          },
                        )),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text("Add New"),
                          onPressed: () => _showAddCustomRestriction(context, userRestrictions, user.fitnessGoal, firestore),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Report and data section
              _buildSectionHeader('Data & Reports'),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Export Weekly Report'),
                subtitle: const Text('Download PDF summary'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _handleExportReport,
              ),
              const Divider(),

              // Account section
              _buildSectionHeader('Account'),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log Out', style: TextStyle(color: Colors.red)),
                onTap: _handleLogout,
              ),
              const SizedBox(height: 24), 
            ],
          );
        },
      ),
    );
  }

  // Pops open a dialog that dynamically shows the preset restrictions the user hasn't picked yet, while also giving them a text field to type something completely custom.
  void _showAddCustomRestriction(BuildContext context, List<String> current, String goal, FirestoreService firestore) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Restriction"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select a common one or type your own:"),
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              children: _presetRestrictions.where((p) => !current.contains(p)).map((p) => ActionChip(
                label: Text(p, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  current.add(p);
                  firestore.updateDietaryPreferences(restrictions: current, goal: goal);
                  Navigator.pop(ctx);
                },
              )).toList(),
            ),
            const Divider(height: 32),
            TextField(
              controller: _customController,
              decoration: const InputDecoration(hintText: "e.g. No Shellfish, Low Carb"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              if (_customController.text.isNotEmpty) {
                current.add(_customController.text.trim());
                firestore.updateDietaryPreferences(restrictions: current, goal: goal);
                _customController.clear();
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add Custom"),
          ),
        ],
      ),
    );
  }

  // A tiny helper widget that ensures all the section titles (Appearance, Account, etc.) look uniform and have the exact same spacing without repeating code.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}