# MotivaFit 🏋️‍♂️🥗

MotivaFit is a gamified Flutter application designed to make health and fitness tracking engaging. By combining daily nutrition logging and workout tracking with RPG-style elements (XP, Coins, and weekly Boss Battles), MotivaFit keeps users consistent and motivated. It also features a built-in AI Nutritionist powered by a dual-model fallback architecture for maximum uptime.

---

## 📂 Folder Structure

The project follows a feature-first, modular architecture to separate the UI from business logic and database management.

```text
lib/
│
├── models/               # Data structures (User, Task, Boss, Nutrition, Workout)
├── screens/              # UI Views (Home, Nutrition, Workout, Settings, AI Chat)
├── services/             # Core Logic & APIs
│   ├── auth_service.dart      # Firebase Authentication
│   ├── firestore_service.dart # Database operations & Gamification logic
│   ├── food_service.dart      # Public food database API integration
│   ├── ai_chat_service.dart   # Dual-layer AI integration (Gemini / gpt-oss-20b)
│   └── pdf_service.dart       # Weekly report generation
│
└── main.dart             # App entry point and theme initialization
🛠 Prerequisites & Requirements
To run this project locally, you will need the following installed on your machine:

Flutter SDK: Version 3.19.0 or higher (Installation Guide)

Dart SDK: Included with Flutter.

IDE: VS Code, Android Studio, or Xcode (for iOS simulation).

Firebase Account: A free Firebase project with Authentication and Firestore enabled.

⚙️ Environment Setup & Reproducibility
To protect sensitive API keys, this project uses the flutter_dotenv package. You must create your own environment file for the app to compile and run correctly.

Clone the repository:

Bash
git clone [https://github.com/yourusername/MotivaFit.git](https://github.com/yourusername/MotivaFit.git)
cd MotivaFit
Install dependencies:

Bash
flutter pub get
Create your Environment File:
You must create a file named exactly .env in the root directory of the project (at the same level as pubspec.yaml). Open this file and paste in your own API keys. You must use these exact variable names:

Code snippet
GEMINI_API_KEY=your_google_gemini_key_here
HUGGING_FACE_API_KEY=your_hugging_face_token_here
SPOONACULAR_API_KEY=your_spoonacular_key_here
Configure Firebase:
This project requires a Firebase backend. Use the FlutterFire CLI to connect the app to your own Firebase project:

Bash
dart pub global activate flutterfire_cli
flutterfire configure
🚀 How to Run the Code
Once your .env file and Firebase configurations are locked in, you can run the app on an emulator or physical device.

To run on an iOS Simulator (Mac only):

Bash
open -a Simulator
flutter run
To run on an Android Emulator or physical device:

Bash
flutter run
🧪 Testing the Application
Because MotivaFit relies heavily on real-time external APIs and Firebase backend services, the most effective way to test the codebase is through manual user-journey exploration.

Once your dependencies are installed and the app is running, try the following flow to verify all systems are operational:

Authentication: Create a new account to verify Firebase Auth is connected.

Database & API: Go to the Nutrition tab and log a meal (using either the text search or the barcode scanner). This verifies the Spoonacular API is fetching data and Firestore is saving it.

Gamification: Complete a daily task or finish a workout to ensure the XP bar increases and coins are awarded.

AI Architecture: Open the AI Assistant (Mo) and ask for a meal recommendation to verify the Hugging Face / Gemini fallback router is successfully generating responses.

📊 APIs & Models Used
Instead of static CSV datasets, this application relies on live APIs and open-weight models to provide real-time data to the user:

Food & Nutrition Database: Spoonacular Food API

Primary AI Assistant: Hugging Face Serverless Inference API (routing to openai/gpt-oss-20b)

Fallback AI Assistant: Google Gemini API (gemini-1.5-flash)