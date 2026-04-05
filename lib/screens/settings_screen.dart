import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PdfService _pdfService = PdfService();
  final TextEditingController _customController = TextEditingController();

  final List<String> _presetRestrictions = [
    'Halal', 'Vegan', 'Vegetarian', 'Pescetarian', 
    'Gluten-Free', 'Dairy-Free', 'Keto', 'No Nuts',
  ];

  final List<String> _goals = ['Lose Weight', 'Maintain', 'Build Muscle'];

  // --- ACTIONS ---

  void _handleLogout() {
    AuthService().signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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

  // --- UI BUILDER ---

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
          
          // Determine if dark mode is active based on the exact Firestore ID
          bool isDarkModeEnabled = user.selectedThemeId == 'theme_dark';

          return ListView(
            children: [
              const SizedBox(height: 20),
              
              // --- SECTION: APPEARANCE ---
              _buildSectionHeader('Appearance'),
              SwitchListTile(
                title: const Text('Dark Mode'),
                secondary: const Icon(Icons.dark_mode),
                value: isDarkModeEnabled,
                onChanged: (val) {
                  // Save the exact ID to Firestore so AppThemes recognizes it
                  firestore.equipTheme(val ? 'theme_dark' : 'default');
                },
              ),
              const Divider(),

              // --- SECTION: FITNESS & DIET ---
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

              // --- SECTION: DATA & REPORTS ---
              _buildSectionHeader('Data & Reports'),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Export Weekly Report'),
                subtitle: const Text('Download PDF summary'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _handleExportReport,
              ),
              const Divider(),

              // --- SECTION: ACCOUNT ---
              _buildSectionHeader('Account'),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log Out', style: TextStyle(color: Colors.red)),
                onTap: _handleLogout,
              ),
              const SizedBox(height: 24), // Extra padding at the bottom
            ],
          );
        },
      ),
    );
  }

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