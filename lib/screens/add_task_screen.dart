import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';

// Screen to create a new task
class AddTaskScreen extends StatefulWidget {
  final String? initialCategory;
  final DateTime? initialDate;

  const AddTaskScreen({
    super.key, 
    this.initialCategory,
    this.initialDate,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  // Form state variables
  final _titleController = TextEditingController();
  TaskDifficulty _difficulty = TaskDifficulty.easy;
  TaskPriority _priority = TaskPriority.normal;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // This defaults to the passed date or today
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  // Shows the native date picker
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Saves the task to the database and handles the loading spinner
  void _submit() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await FirestoreService().addTask(
        title: _titleController.text,
        // Auto assign the category behind the scenes so the user doesn't need to
        category: widget.initialCategory ?? 'Custom', 
        difficulty: _difficulty,
        priority: _priority,
        date: _selectedDate, 
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView( 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task name input
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              
              // Date picking row
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Scheduled Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Side by side dropdowns for difficulty and priority
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TaskDifficulty>(
                      value: _difficulty,
                      decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()),
                      items: TaskDifficulty.values.map((d) => DropdownMenuItem(value: d, child: Text(d.name.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<TaskPriority>(
                      value: _priority,
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                      items: TaskPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Task'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}