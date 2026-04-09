import 'package:flutter/material.dart';

// A lightweight widget that displays a motivational quote. 
// It automatically rotates to a new quote every 24 hours.
class QuoteWidget extends StatelessWidget {
  const QuoteWidget({super.key});

  // A hardcoded list of fitness and productivity quotes.
  static const List<String> _quotes = [
    "The only bad workout is the one that didn't happen.",
    "Action is the foundational key to all success.",
    "Don't wish for it. Work for it.",
    "Motivation is what gets you started. Habit is what keeps you going.",
    "Sweat is just fat crying.",
    "Your body can stand almost anything. It’s your mind that you have to convince.",
    "Fitness is not about being better than someone else. It’s about being better than you were yesterday.",
    "Discipline is doing what needs to be done, even if you don't want to do it.",
    "Success starts with self-discipline.",
    "The pain you feel today will be the strength you feel tomorrow.",
    "Don't count the days, make the days count.",
    "Believe you can and you're halfway there.",
    "Strength does not come from physical capacity. It comes from an indomitable will.",
    "You don't have to be great to start, but you have to start to be great.",
    "A one-hour workout is 4% of your day. No excuses.",
  ];

  @override
  Widget build(BuildContext context) {
    // Logic to pick a quote based on the current date.
    // By combining the year, month, and day into a single number, we guarantee the math returns the exact same quote all day long.
    final now = DateTime.now();
    final dateString = "${now.year}${now.month}${now.day}"; 
    final dayNumber = int.parse(dateString); 
    final quoteIndex = dayNumber % _quotes.length;
    final quote = _quotes[quoteIndex];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.deepPurple.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.format_quote, color: theme.primaryColor, size: 32),
          const SizedBox(height: 8),
          Text(
            quote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.deepPurple[900],
            ),
          ),
        ],
      ),
    );
  }
}