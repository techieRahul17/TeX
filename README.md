# 🎨 PingMe - Premium Real-Time Chat

<div align="center">

![PingMe Banner](https://via.placeholder.com/1200x300/0a0e27/FF007F?text=PingMe+%7C+Premium+Real-Time+Messaging)

**🌟 Connect perfectly. Chat instantly. Experience Stellar. 🌟**

</div>

> **PingMe** is a next-generation real-time messaging application built with **Flutter** and **Firebase**. Designed with a stunning **Black & Neon Pink** aesthetic, it offers a premium, glassmorphic interface with enterprise-grade security and lightning-fast performance.

---

## ✨ Features

- **🎨 Stellar UI**: A sleek black interface with vibrant pink neon accents and glassmorphic design elements.
- **🔐 Enterprise Security**: Secure authentication with **Google Sign-In** and Email/Password via Firebase.
- **💬 Real-Time Messaging**: Instant 1-on-1 chats powered by Firestore real-time streams.
- **👥 Group Chats**: Create groups, manage members, and enjoy synchronized conversations with live updates.
- **🛡️ Privacy Controls**: Customize your "Online Status" visibility and control your digital presence.
- **👤 Custom Profiles**: Personalized "About" status and generative avatar profiles.
- **⚡ High Performance**: Optimized for Web, Android, and iOS platforms with minimal latency.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (3.x)
- **Language**: Dart
- **Backend**: [Firebase](https://firebase.google.com/)
  - **Firestore**: Real-time NoSQL Database with encryption
  - **Authentication**: Secure Google OAuth & Email authentication
- **State Management**: Provider pattern
- **UI Libraries**: `glassmorphism`, `flutter_animate`, `phosphor_flutter`, `google_fonts`

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.x or higher)
- A Firebase Project with **Authentication** and **Firestore** enabled
- Dart 3.0+

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/techieRahul17/PingMe.git
   cd PingMe
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - Replace `lib/firebase_options.dart` with your Firebase project's configuration file
   - **Web**: Update `web/index.html` with your Google OAuth Client ID
     ```html
     <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
     ```
   - **Android**: Ensure `google-services.json` is placed in `android/app/`

4. **Run the Application**
   ```bash
   flutter run
   # For Chrome/Web
   flutter run -d chrome
   ```

---

## 🔒 Security

### Authentication & Authorization

- **OAuth 2.0 Compliance**: Implements industry-standard OAuth 2.0 for Google Sign-In
- **Firebase Authentication**: Leverages Firebase's managed authentication with automatic token refresh
- **End-to-End Design**: Communication flows through encrypted Firebase channels (TLS 1.3+)
- **Password Security**: Email/password authentication with secure hashing via Firebase

### Data Protection

- **Firestore Security Rules**: Implemented field-level access controls and user isolation
- **Privacy by Design**: User data is compartmentalized; users can only access their own conversations
- **No Data Logging**: Sensitive data (passwords, auth tokens) are never logged or stored locally
- **Compliance**: Follows OWASP security guidelines and Firebase best practices

### User Privacy

- **Online Status Control**: Users have complete control over visibility settings
- **Profile Customization**: Optional profile information with user consent
- **Data Deletion**: Users can request data removal in compliance with privacy regulations

### Deployment Security

- Utilize environment variables for sensitive configuration
- Ensure HTTPS/TLS for all API communications
- Regular dependency audits using `flutter pub outdated` and security scanners

---

## 📸 Screenshots

| Login Screen | Chat Screen | Group Chat | Settings |
|:---:|:---:|:---:|:---:|
| ![Login](https://via.placeholder.com/200x400/0a0e27/FF007F?text=Login) | ![Home](https://via.placeholder.com/200x400/0a0e27/FF007F?text=Home) | ![Chat](https://via.placeholder.com/200x400/0a0e27/FF007F?text=Group) | ![Settings](https://via.placeholder.com/200x400/0a0e27/FF007F?text=Settings) |

---

## ⚠️ Contribution Policy

**This is a closed-source project.** We do not accept external contributions, pull requests, or feature suggestions at this time.

This repository is maintained exclusively by the project owner. If you have feedback or concerns, please respect the project's intellectual property.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
  <strong>Built with ❤️ by <a href="https://github.com/techieRahul17">Rahul V S</a></strong>
  <br/>
  <sub>© 2026 All Rights Reserved</sub>
</p>