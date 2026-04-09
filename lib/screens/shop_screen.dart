import 'package:flutter/material.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

// The digital storefront where users can spend their hard-earned coins. It is split into two tabs: one for custom real-life treats, and another for in-app cosmetics.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

// Manages the logic for buying items, equipping cosmetics, and creating custom rewards.
class _ShopScreenState extends State<ShopScreen> {
  final FirestoreService _firestore = FirestoreService();

  // Attempts to purchase a reward using the user's coins. If successful, it throws a celebratory pop-up. If they can't afford it or an error occurs, it lets them know.
  void _buyReward(Reward reward) async {
    String? error = await _firestore.purchaseReward(reward);

    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reward.isPreset 
            ? 'Unlocked ${reward.title}!' 
            : 'Redeemed ${reward.title}! Enjoy!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  // Instantly updates the user's profile to display their newly equipped avatar.
  void _equipItem(String rewardId) {
    _firestore.equipAvatar(rewardId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar Equipped!'), duration: Duration(milliseconds: 500)),
    );
  }

  // Instantly applies a newly purchased theme to the user's database profile.
  void _equipTheme(String rewardId) {
    _firestore.equipTheme(rewardId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme Applied!'), duration: Duration(milliseconds: 500)),
    );
  }

  // Removes a custom reward from the database if the user no longer wants it.
  void _deleteCustomReward(String id) {
    _firestore.deleteCustomReward(id);
  }

  // Pops open a small form for users to invent their own motivation. 
  // For example, they can create a "1 Hour of Gaming" reward and price it at 50 coins.
  void _showAddRewardDialog(BuildContext context) {
    final titleController = TextEditingController();
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Custom Reward'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Reward Title (e.g. Netflix)'),
            ),
            TextField(
              controller: costController,
              decoration: const InputDecoration(labelText: 'Cost (Coins)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final cost = int.tryParse(costController.text) ?? 0;
              
              if (title.isNotEmpty && cost > 0) {
                _firestore.addCustomReward(title, cost);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // The main layout. It sets up a persistent header showing the user's current coin bank, followed by a swipeable tab view for the two different shops.
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rewards Shop'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Rewards'),
              Tab(text: 'Item Shop'),
            ],
          ),
        ),
        body: StreamBuilder<UserModel>(
          stream: _firestore.getUserStream(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final user = userSnapshot.data!;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Balance: ${user.currentCoins} Coins',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      _buildMyRewardsTab(user),
                      _buildItemShopTab(user),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // The custom rewards tab. It fetches the user's personal treats and disables the "Redeem" button if their bank balance is too low.
  Widget _buildMyRewardsTab(UserModel user) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRewardDialog(context),
        label: const Text('Create Reward'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Reward>>(
        stream: _firestore.getCustomRewards(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final rewards = snapshot.data!;
          if (rewards.isEmpty) {
            return const Center(
              child: Text('Create your own rewards to stay motivated!\n(e.g. "Takeout Night", "1 Hour Gaming")'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              final canAfford = user.currentCoins >= reward.cost;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.star)),
                  title: Text(
                    reward.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${reward.cost} Coins',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        onPressed: canAfford ? () => _buyReward(reward) : null,
                        child: const Text('Redeem'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: () => _deleteCustomReward(reward.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // The cosmetic shop. This contains logic to check if an item is locked behind a specific user level, too expensive, already owned, or actively equipped.
  Widget _buildItemShopTab(UserModel user) {
    final rewards = Reward.presetRewards;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rewards.length,
      itemBuilder: (context, index) {
        final reward = rewards[index];
        
        final isUnlocked = user.unlockedRewardIds.contains(reward.id);
        final isLevelLocked = user.currentLevel < reward.requiredLevel;
        final canAfford = user.currentCoins >= reward.cost;
        
        final isAvatarEquipped = user.selectedAvatarId == reward.id;
        final isThemeEquipped = user.selectedThemeId == reward.id;
        bool isAvatar = reward.id.startsWith('avatar_');
        bool isTheme = reward.id.startsWith('theme_');

        String buttonText;
        VoidCallback? onPressed;
        
        if (isUnlocked) {
          if (isAvatar) {
            if (isAvatarEquipped) {
              buttonText = 'Equipped';
              onPressed = null;
            } else {
              buttonText = 'Equip';
              onPressed = () => _equipItem(reward.id);
            }
          } else if (isTheme) {
            if (isThemeEquipped) {
              buttonText = 'Equipped';
              onPressed = null;
            } else {
              buttonText = 'Equip';
              onPressed = () => _equipTheme(reward.id);
            }
          } else {
            buttonText = 'Owned';
            onPressed = null; 
          }
        } else if (isLevelLocked) {
          buttonText = 'Lvl ${reward.requiredLevel}';
          onPressed = null;
        } else if (!canAfford) {
          buttonText = 'Need Coins';
          onPressed = null;
        } else {
          buttonText = '${reward.cost} Coins';
          onPressed = () => _buyReward(reward);
        }

        return Card(
          child: ListTile(
            leading: Icon(
              isUnlocked ? Icons.check_circle : (isLevelLocked ? Icons.lock : Icons.store),
              color: isUnlocked ? Colors.green : (isLevelLocked ? Colors.grey : Colors.blue),
            ),
            title: Text(
              reward.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: isLevelLocked 
              ? Text(
                  'Unlocks at Level ${reward.requiredLevel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ) 
              : Text(
                  '${reward.cost} Coins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            trailing: FilledButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ),
        );
      },
    );
  }
}