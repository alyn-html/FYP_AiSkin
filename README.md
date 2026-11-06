# 🍓 AiSkin – AI-Powered Personal Skin Health Assistant

**An AI-assisted skin health companion for Android.**

AiSkin helps users understand and monitor their skin condition through AI-powered skin analysis using the Google Gemini API. It transforms analysis results into personalised skincare routines, recommendations, reminders, and a skin diary that users can track over time.

> ⚕️ **Medical Disclaimer:** AiSkin is an educational and informational tool, not a medical device. It does not diagnose, treat, or cure any medical condition. AI-generated results may be inaccurate or inconsistent. Users should consult a qualified dermatologist or healthcare professional for medical concerns.

Developed as a Final Year Project (FYP) at **Universiti Teknologi PETRONAS (UTP)**.

---

## 📲 Download AiSkin

**Want to try AiSkin on your Android device?**

[![Download AiSkin APK](https://img.shields.io/badge/Download-AiSkin%20APK-ec8ca1?style=for-the-badge&logo=android&logoColor=white)](https://github.com/alyn-html/FYP_AiSkin/releases)

<sub>Visit the GitHub Releases page to download the latest available Android APK.</sub>

### Installation Instructions

1. Open the [AiSkin Releases page](https://github.com/alyn-html/FYP_AiSkin/releases).
2. Select the latest release.
3. Under **Assets**, download `app-release.apk`.
4. Open the downloaded APK on your Android phone.
5. If prompted, allow your browser or file manager to install unknown apps.
6. Tap **Install** and wait for the installation to finish.
7. Open AiSkin, create an account, and complete your skin profile.

**Requirements:**
- Android device compatible with the APK.
- Internet connection for sign-in, AI analysis, chatbot, and online services.
- Permission to install applications from the selected source.

---

## ✨ Features

### 1. Face Scan Analysis
- Upload facial images for AI-assisted skin analysis.
- Perform an on-device photo check for suitable lighting and face visibility.
- Use Google Gemini API to analyse submitted images.
- Generate an overall skin health score.
- Provide severity ratings and explanations for five skin concerns:
  - Acne
  - Oiliness
  - Dryness
  - Dark circles and eye bags
  - Redness
- Provide observations for different facial zones.

### 2. Past Scan History
- Browse previously completed skin analyses.
- Open individual scans to view detailed results.
- Keep a record of changes in skin condition over time.

### 3. Personalised Skincare Routine
- Generate morning and night skincare routines based on the user's latest skin concerns.
- Follow daily skincare checklists.
- Receive nutrition and lifestyle suggestions.
- Support consistent skincare habits through personalised guidance.

### 4. Daily Tips and Personalised Insights
- Receive AI-generated daily skincare tips.
- View personalised insights based on scan trends and diary entries.
- Incorporate local weather and air quality information into relevant insights.

### 5. Skin Diary and Progress Tracking
- Record daily skin conditions and personal observations.
- Track mood, sleep, water intake, stress, diet, and skincare products.
- View diary entries through a calendar.
- Compare the first and latest skin scans.
- Monitor skin progress through visual records and charts.

### 6. Customisable Reminders
- Create skincare and personal care reminders.
- Edit or delete existing reminders.
- Set reminders to repeat daily, weekly, or on a specific date.

### 7. AI Skin Assistant
- Chat with an AI assistant about skin-related concerns.
- Submit text descriptions and optional images.
- Receive general skincare information and suggestions.
- Includes a limit of five chat exchanges per day.

### 8. Find a Dermatologist
- Open a location-based search for nearby dermatologists or clinics.
- Use the device's available Maps application to explore consultation options.

### 9. Personalisation and Privacy
- Support light and dark themes.
- Provide Privacy Mode to block screenshots and screen recording on the Diary screen.
- Allow users to manage their skincare preferences and reminders.

---

## 🛠️ Technology Stack

| Component | Technology |
|---|---|
| Mobile Development | Flutter |
| Programming Language | Dart |
| AI Integration | Google Gemini API |
| Authentication | Firebase Authentication |
| Face Detection | Google ML Kit |
| Local Data Storage | SharedPreferences |
| Image Selection | Image Picker |
| File Management | Path Provider |
| Notifications | Flutter Local Notifications |
| Timezone Management | Timezone |
| Location Services | Geolocator |
| Weather and Air Quality | Open-Meteo API |
| External Maps | URL Launcher |
| Native Android Integration | Kotlin Platform Channel |
| Development Environment | Android Studio |
| Version Control | Git and GitHub |

---

## 🔄 Application Workflow

AiSkin follows a continuous personal skin health management workflow:

1. **DETECT** – Upload a facial image or describe a skin concern.
2. **ANALYSE** – Obtain AI-generated observations and skin-related insights.
3. **RECOMMEND** – Receive personalised skincare and lifestyle suggestions.
4. **CREATE ROUTINE** – Establish morning and night skincare routines.
5. **MONITOR PROGRESS** – Record and review changes through the skin diary and scan history.
6. **ADAPT** – Adjust skincare guidance based on updated information.
7. **REMIND AND RE-ENGAGE** – Maintain consistent skincare habits through reminders and daily insights.

---

## 🔒 Privacy and Data Handling

AiSkin uses external services and on-device storage to support its features.

| Data / Component | Data Handling |
|---|---|
| User Account | Firebase Authentication handles email and password authentication. |
| Facial Images | Images submitted for analysis are sent to Google's Gemini API. A copy is retained on the device for scan history. |
| Scan Results | Stored locally on the device. |
| Skin Diary | Stored locally on the device. |
| Skincare Routines | Stored locally on the device. |
| Reminders | Managed through local notification and storage functionality. |
| Location | Optional location access supports local weather and air quality information through Open-Meteo. |

**Important Privacy Notes:**
- Scan records, diary entries, routines, and reminders are not synchronised to a cloud database.
- Uninstalling the application or clearing its data may permanently erase locally stored information.
- Local records do not automatically transfer to another device.
- Facial images submitted for AI analysis are processed through Google's Gemini API.
- Users should avoid submitting unnecessary personal or sensitive information.

---

## ⚠️ Known Limitations

- AI-generated analysis may be inaccurate, inconsistent, or incomplete.
- The application has not been clinically validated and is not a substitute for professional dermatological assessment.
- Skin analysis is limited to five predefined concern categories.
- Image analysis works best with clear facial images and suitable lighting conditions.
- The Gemini API key is supplied at build time and embedded in the compiled application. Consequently, all distributed installations may share the same API key and usage quota.
- High API usage or service restrictions may temporarily affect AI features.
- Scan history, diary entries, routines, and reminders do not support automatic cross-device synchronisation or cloud backup.
- Some features require an active internet connection.

---

## 💻 Build from Source

Developers who wish to explore, modify, or build AiSkin can follow the instructions below.

### Prerequisites

Install the following before starting:

- Flutter SDK
- Dart SDK
- Android Studio
- Android SDK
- Git
- A Google Gemini API key from [Google AI Studio](https://aistudio.google.com/)
- A Firebase project with Email/Password Authentication enabled

### 1. Clone the Repository

```bash
git clone https://github.com/alyn-html/FYP_AiSkin.git
cd FYP_AiSkin
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

If the Firebase configuration files are not included in the repository, configure your own Firebase project.

Install FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

Configure Firebase:

```bash
flutterfire configure
```

Ensure that Email/Password Authentication is enabled in your Firebase project.

### 4. Configure Gemini API Key

Create a file named `secrets.json` in the root project directory:

```json
{
  "GEMINI_API_KEY": "YOUR_GEMINI_API_KEY"
}
```

Replace `YOUR_GEMINI_API_KEY` with your own API key.

**Important:** The `secrets.json` file is excluded from version control and must not be uploaded to GitHub.

### 5. Run the Application

```bash
flutter run --dart-define-from-file=secrets.json
```

### 6. Build the Android APK

To generate a release APK:

```bash
flutter build apk --release --dart-define-from-file=secrets.json
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

**API Key Security Notice:** Supplying an API key through Flutter build arguments prevents it from being stored directly in the source repository, but it does not secure the key inside the compiled APK. A backend proxy with appropriate authentication and usage restrictions is recommended for production deployment.

---

## 📁 Project Structure

```text
FYP_AiSkin/
│
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── kotlin/
│                   └── .../
│                       └── MainActivity.kt
│
├── assets/
│
├── lib/
│   ├── main.dart
│   ├── theme/
│   ├── screens/
│   └── services/
│
├── test/
│
├── .gitignore
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

*Note: The structure above provides a high-level overview. Individual folders may contain additional files and subdirectories.*

---

## 🎓 Project Information

| Item | Details |
|---|---|
| Project Name | AiSkin |
| Project Type | Final Year Project |
| Institution | Universiti Teknologi PETRONAS |
| Programme | Bachelor of Information Technology (Honours) |
| Platform | Android |
| Primary Language | Dart |
| AI Service | Google Gemini API |
| Repository | [FYP_AiSkin](https://github.com/alyn-html/FYP_AiSkin) |

---

## 📌 Future Improvements

Potential future enhancements include:

- Backend integration for more secure AI API key management.
- Cloud backup and cross-device synchronisation.
- Improved AI analysis consistency and evaluation.
- Expanded skin concern categories.
- More comprehensive skincare progress analytics.
- Additional personalisation based on user feedback and historical trends.

---

## ❤️ Acknowledgements

AiSkin is developed as an academic Final Year Project to explore the application of artificial intelligence in personal skin health management.

Special thanks to the project supervisor, Universiti Teknologi PETRONAS, and the developers of the technologies and services used in this project.

---

**Made with 🍓 for smarter and more consistent skincare.**
