import '../models/gamification_rules.dart';
import '../models/task.dart';
import '../models/user_progress.dart';
import '../models/reward.dart';

class GamificationService {
  
  // Calculate rewards and update user state
  UserProgress completeTask(UserProgress current, Task task) {
    // Calculate Gains
    int xpGain = GameRules.xpRewards[task.difficulty]!;
    
    int coinBase = GameRules.coinBaseRewards[task.difficulty]!;
    double multiplier = GameRules.coinMultipliers[task.priority]!;
    int coinGain = (coinBase * multiplier).round();

    // Update State
    int newXP = current.currentXP + xpGain;
    int newCoins = current.currentCoins + coinGain;
    int newLevel = current.currentLevel;

    // Check Level Up (Simple 500 XP threshold)
    int xpNeeded = current.currentLevel * 500;
    if (newXP >= xpNeeded) {
      newLevel++;
      newXP = newXP - xpNeeded; 
    }

    return current.copyWith(
      currentLevel: newLevel,
      currentXP: newXP,
      currentCoins: newCoins,
    );
  }

  // Handle unchecking a task (prevent infinite coin farming)
  UserProgress undoTaskCompletion(UserProgress current, Task task) {
    int xpLoss = GameRules.xpRewards[task.difficulty]!;
    
    int coinBase = GameRules.coinBaseRewards[task.difficulty]!;
    double multiplier = GameRules.coinMultipliers[task.priority]!;
    int coinLoss = (coinBase * multiplier).round();

    // Prevent negative values
    int newCoins = (current.currentCoins - coinLoss).clamp(0, 999999);
    int newXP = (current.currentXP - xpLoss).clamp(0, 999999);

    return current.copyWith(
      currentCoins: newCoins,
      currentXP: newXP,
    );
  }

  // Apply penalties for missed tasks
  UserProgress processMissedTasks(UserProgress current, List<Task> dailyTasks) {
    int totalPenalty = 0;

    for (var task in dailyTasks) {
      if (!task.isCompleted) {
        totalPenalty += GameRules.missedTaskPenalties[task.priority]!;
      }
    }

    int newCoins = (current.currentCoins - totalPenalty).clamp(0, 999999);
    return current.copyWith(currentCoins: newCoins);
  }

  // Validate purchase eligibility
  bool canPurchase(UserProgress user, Reward item) {
    if (user.currentLevel < item.minLevelRequired) return false;
    if (user.currentCoins < item.coinCost) return false;
    return true;
  }

  // Execute purchase
  UserProgress purchaseItem(UserProgress current, Reward item) {
    if (!canPurchase(current, item)) return current;

    return current.copyWith(
      currentCoins: current.currentCoins - item.coinCost,
    );
  }

}