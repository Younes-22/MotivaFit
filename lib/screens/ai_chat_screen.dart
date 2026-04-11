import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/nutrition_model.dart';
import '../services/firestore_service.dart';
import '../services/ai_chat_service.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final AIChatService _aiService = AIChatService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimer();
    });
  }

  void _sendWelcomeMessage() {
    setState(() {
      _messages.add({
        "role": "bot",
        "text": "Hi! I'm Mo, your MotivaFit AI Assistant. 🤖\n\nI can help you crush your goals! Ask me to:\n🥗 Suggest meals based on your calories and diet\n\nWhat can I help you with today?"
      });
    });
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: const Text("AI Safety Warning", overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: const Text(
          "This AI Assistant provides suggestions based on your profile data. However, AI can make mistakes.\n\n"
          "• Do not treat this as medical advice.\n"
          "• Double-check ingredients for allergies.\n"
          "• Consult a doctor before major diet or fitness changes.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_messages.isEmpty) {
                _sendWelcomeMessage();
              }
            },
            child: const Text("I Understand"),
          ),
        ],
      ),
    );
  }

  void _sendMessage(UserModel user, NutritionDay nutrition) async {
    if (_controller.text.trim().isEmpty) return;

    final userQuery = _controller.text;
    setState(() {
      // 1. Add the user's new message to the history list immediately
      _messages.add({"role": "user", "text": userQuery});
      _isLoading = true;
    });
    _controller.clear();

    // 2. Pass the ENTIRE chat history to the service, not just the single query
    final response = await _aiService.getMealSuggestion(
      user: user,
      todayNutrition: nutrition,
      chatHistory: _messages, 
    );

    // 3. The Blank Bubble Fix: If the API returns nothing, swap it with a default error message.
    String safeResponse = response.trim();
    if (safeResponse.isEmpty) {
      safeResponse = "Oops! My brain froze for a second. Could you repeat that?";
    }

    setState(() {
      _messages.add({"role": "bot", "text": safeResponse});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mo - AI Assistant'), centerTitle: true),
      body: StreamBuilder<UserModel>(
        stream: FirestoreService().getUserStream(),
        builder: (context, userSnap) {
          return StreamBuilder<NutritionDay>(
            stream: FirestoreService().getNutritionForDate(DateTime.now()),
            builder: (context, nutritionSnap) {
              if (!userSnap.hasData || !nutritionSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final isUser = _messages[i]["role"] == "user";
                        return _buildChatBubble(isUser, _messages[i]["text"]!);
                      },
                    ),
                  ),
                  if (_isLoading) const LinearProgressIndicator(),
                  _buildInputArea(userSnap.data!, nutritionSnap.data!),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatBubble(bool isUser, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser 
              ? Colors.deepPurple 
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(UserModel user, NutritionDay nutrition) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Message Mo...', border: InputBorder.none),
              onSubmitted: (_) => _sendMessage(user, nutrition),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.deepPurple),
            onPressed: () => _sendMessage(user, nutrition),
          ),
        ],
      ),
    );
  }
}