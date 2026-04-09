import 'package:flutter/material.dart';
import '../models/task_model.dart';

// A reusable UI component that displays a single task. It handles its own layout for the checkbox, priority badges, and the expected gamification rewards.
class TaskTile extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?> onChanged;
  
  // A flag to determine if we should show a loading spinner instead of the checkbox.
  // This locks-in the UI while the database processes the XP and coin math.
  final bool isUpdating; 

  const TaskTile({
    super.key,
    required this.task,
    required this.onChanged,
    this.isUpdating = false, 
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Dynamically sets the tag color based on the task priority.
    Color getPriorityColor() {
      switch (task.priority) {
        case TaskPriority.high: return colorScheme.error;
        case TaskPriority.normal: return colorScheme.primary;
        case TaskPriority.low: return Colors.grey;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            
            // Check Area
            SizedBox(
              width: 40,
              height: 40,
              child: isUpdating
                  ? const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: task.isCompleted,
                        onChanged: isUpdating ? null : onChanged, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        activeColor: colorScheme.primary,
                      ),
                    ),
            ),
            
            const SizedBox(width: 8),

            // Task Info
            // Displays the title and the difficulty/priority tags.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? Colors.grey : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildBadge(
                        task.difficulty.name.toUpperCase(),
                        Colors.blueGrey.withValues(alpha: 0.2),
                        Colors.blueGrey,
                      ),
                      if (task.priority != TaskPriority.normal)
                        _buildBadge(
                          task.priority.name.toUpperCase(),
                          getPriorityColor().withValues(alpha: 0.1),
                          getPriorityColor(),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Reward info
            // Shows the user exactly what they earn upon completion.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '⚔️ ${task.xpReward} DMG',
                  style: TextStyle(
                    color: task.isCompleted ? Colors.grey : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${task.coinReward} 🪙',
                  style: TextStyle(
                    color: task.isCompleted ? Colors.grey : Colors.amber[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '+${task.xpReward} XP',
                  style: TextStyle(
                    color: task.isCompleted ? Colors.grey : colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // A small helper widget to draw the uniform tags under the task title.
  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}