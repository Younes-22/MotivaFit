import 'package:flutter/material.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final FirestoreService _firestore = FirestoreService();

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

  void _equipItem(String rewardId) {
    _firestore.equipAvatar(rewardId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar Equipped!'), duration: Duration(milliseconds: 500)),
    );
  }

  void _equipTheme(String rewardId) {
    _firestore.equipTheme(rewardId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme Applied!'), duration: Duration(milliseconds: 500)),
    );
  }

  void _deleteCustomReward(String id) {
    _firestore.deleteCustomReward(id);
  }

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
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
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