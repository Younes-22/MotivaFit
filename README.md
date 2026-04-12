# MotivaFit

The full version of this project is also available at: [MotivaFit Source Code](https://cityuni-my.sharepoint.com/:f:/g/personal/younes_bekhti_city_ac_uk/IgB7AF9csz9bSIQ_nTFTZhRKAd201hU_ShtOzem-_fw76q4?e=gHnmlK)

MotivaFit is a gamified Flutter application designed to make health and fitness tracking engaging. By combining daily nutrition logging and workout tracking with RPG-style elements (XP, Coins, and weekly Boss Battles), MotivaFit keeps users consistent and motivated. It also features a built-in AI Nutritionist powered by a dual-model fallback architecture to ensure maximum uptime and reliability.

---

## 📂 Folder Structure

The project follows a feature-first, modular architecture to separate the UI from business logic and database management.

```text
lib/
│
├── models/               # Data structures & logic
│   ├── badge_model.dart         # Structure for earnable achievements and trophies
│   ├── boss_model.dart          # Data for the weekly boss (HP, timer, difficulty)
│   ├── gamification_rules.dart  # Constants for XP scaling and level thresholds
│   ├── nutrition_model.dart     # Structure for logged meals and daily macros
│   ├── reward_model.dart        # Data for shop items (cosmetics and custom treats)
│   ├── task_model.dart          # Structure for daily and custom checklist items
│   ├── user_model.dart          # Core user profile, stats, and database blueprint
│   ├── user_progress.dart       # Tracking historical metrics and completion rates
│   └── workout_model.dart       # Structure for logged exercises and routines
│
├── screens/              # Full-page UI Views
│   ├── add_task_screen.dart       # Form to create new daily/custom tasks
│   ├── ai_chat_screen.dart        # Interface for talking to Mo (AI Nutritionist)
│   ├── create_account_screen.dart # Email/password registration UI
│   ├── home_screen.dart           # Main dashboard (Boss, Calendar, Quick Actions)
│   ├── login_screen.dart          # Authentication entry point
│   ├── nutrition_screen.dart      # Meal logging, food search, and macro tracking
│   ├── onboarding_screen.dart     # Initial clinical setup flow for new users
│   ├── settings_screen.dart       # User preferences and dietary restrictions
│   ├── shop_screen.dart           # Rewards store (Item Shop & Custom Rewards)
│   ├── trophy_room_screen.dart    # Display for earned badges and lifetime stats
│   └── workout_screen.dart        # Exercise logging interface
│
├── services/             # Core Backend Logic & APIs
│   ├── ai_chat_service.dart   # Dual-layer AI integration (Gemini / gpt-oss-20b)
│   ├── auth_service.dart      # Firebase Authentication logic
│   ├── firestore_service.dart # Database operations & Gamification state
│   ├── food_service.dart      # Public food database API integration
│   └── pdf_service.dart       # Weekly report generation
│
├── theme/                # Global app styling
│   └── app_themes.dart        # Light/Dark mode and colour palettes
│
├── widgets/              # Reusable, modular UI components
│   ├── boss_battle_card.dart  # Dynamic weekly boss UI
│   ├── completion_chart.dart  # Analytics graph
│   ├── progress_card.dart     # User level and XP bar
│   ├── quote_widget.dart      # Daily motivational quote
│   └── task_tile.dart         # Interactive checklist item
│
├── firebase_options.dart # Auto-generated Firebase configuration
└── main.dart             # App entry point and initialization
│
├── .gitignore            # Specifies files intentionally untracked by Git (like .env)
├── pubspec.yaml          # Flutter package manager, dependencies, and app configuration
└── README.md             # Project documentation and setup guide
🛠 Prerequisites & Requirements
To run this project locally, you will need the following installed on your machine:

Flutter SDK: Version 3.19.0 or higher

Dart SDK: Included with Flutter.

IDE: VS Code, Android Studio, or Xcode (for iOS compilation).
(Note: A personal Firebase account is not required. The app is pre-configured to connect to the official MotivaFit database for grading purposes).

⚙️ Environment Setup & Reproducibility
To protect sensitive API keys, this project uses the flutter_dotenv package. You must create your own environment file for the app to compile and run correctly.

1. Clone the repository:

Bash
git clone [https://github.com/Younes-22/MotivaFit.git](https://github.com/Younes-22/MotivaFit.git)
Note: The GitHub repository is currently set as private to protect academic integrity. Access can be granted upon request, or you may access the source code directly via the provided SharePoint folder link above.

Bash
cd MotivaFit
2. Install dependencies:

Bash
flutter pub get
3. Create your Environment File:
You must create a file named exactly .env in the root directory of the project (at the same level as pubspec.yaml). Open this file and paste in your own API keys using these exact variable names:

Plaintext
GEMINI_API_KEY=your_google_gemini_key_here
HUGGING_FACE_API_KEY=your_hugging_face_token_here
SPOONACULAR_API_KEY=your_spoonacular_key_here
🚀 How to Run the Code
You can test MotivaFit on either a virtual emulator or a physical device. Note: The Barcode Scanner feature requires a physical device camera to function.

Option A: Running on Virtual Devices (Emulators/Simulators)
This is the fastest method to verify the UI and core logic.

Android Emulator: Open Android Studio, navigate to the Virtual Device Manager, and launch a virtual phone.

iOS Simulator (Mac Only): Open your terminal and run open -a Simulator.

Once the virtual device is running, execute:

Bash
flutter run
Option B: Running on Physical Devices
Testing on a physical device allows you to utilise hardware features like the Barcode Scanner. Ensure your phone is connected to your computer via a reliable cable (a good sign is that the phone begins charging).

For Android:

Ensure "USB Debugging" is enabled in your phone's Developer Options.

Run flutter run in your terminal.

When prompted, select your physical device from the list. Keep the screen unlocked and wait a few minutes for the initial build and installation to complete.

For iOS (Mac Only):
⚠️ Apple enforces strict code-signing policies. You cannot simply run the code on an iPhone without prior setup.

Open the ios/Runner.xcworkspace file in Xcode.

Navigate to the "Signing & Capabilities" tab and assign your own Apple Developer ID to the Team setting.

Once signed, run flutter run and select your iPhone.

On your iPhone, navigate to Settings > General > VPN & Device Management and trust your developer certificate. You must also ensure Developer Mode is enabled in your Privacy & Security settings.

🧪 Testing the Application
Because MotivaFit relies heavily on real-time external APIs and Firebase backend services, the most effective way to test the codebase is through manual user-journey exploration.

Once the app is running, try the following flow to verify all systems are operational:

Authentication: Create a new account to verify Firebase Auth is connected.

Database & API: Go to the Nutrition tab and log a meal.

Hardware Limitation Note: If testing on an emulator, the camera cannot scan barcodes. Please use the "Search Food Name" or "Enter Manually" buttons to verify the Spoonacular API and Firestore integrations.

Gamification: Complete a daily task or finish a workout to ensure the XP bar increases and coins are awarded correctly.

AI Architecture: Open the AI Assistant (Mo) and ask for a meal recommendation to verify the Hugging Face / Gemini fallback router is successfully reading your current macros and generating an appropriate response.

📡 APIs & Models Used
This application relies on live APIs and open-weight models to provide real-time data to the user:

Food & Nutrition Database: Spoonacular Food API

Primary AI Assistant: Hugging Face Serverless Inference API (routing to openai/gpt-oss-20b)

Fallback AI Assistant: Google Gemini API

🔑 How to Obtain API Keys (Free Tier)
If you are evaluating this project and do not already have developer keys for these services, you can lock-in free-tier access by following these steps. All three services offer generous free tiers that do not require credit card details. (I am also happy to provide my personal testing keys via email upon request if required for grading).

1. Google Gemini API

Navigate to Google AI Studio.

Sign in with any standard Google account.

Click "Get API key" in the left-hand navigation menu.

Click "Create API key" and copy the generated string.

2. Hugging Face API

Navigate to Hugging Face and create a free account.

Go to your profile settings by clicking your avatar in the top right corner.

Select "Access Tokens" from the left-hand menu.

Click "Create new token", name it "MotivaFit", set the role to "Read", and copy the token.

3. Spoonacular Food API

Navigate to the Spoonacular API Console.

Create a free account.

Go to Profile & API Key.

Your API Key will be visible on the main screen. (Note: The free tier is limited to 150 points per day, which is more than enough for standard manual testing of the search and barcode features).

Once you have all three keys, paste them into your `.env` file exactly as formatted above to lock-in the app's full functionality.