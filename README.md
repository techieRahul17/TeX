# PingMe 🚀

![PingMe Banner](https://via.placeholder.com/1200x400/000000/FF007F?text=PingMe+Chat+App)

> **"Connect perfectly. Chat instantly. Experience Stellar."**

**PingMe** is a next-generation real-time messaging application built with **Flutter** and **Firebase**. Designed with a stunning **Black & Neon Pink** aesthetic, it offers a premium, glassmorphic user experience that feels alive.

## ✨ Features

- **🎨 Stellar UI**: A deep black simplified interface with vibrant pink neon accents and glassmorphic elements.
- **🔐 Secure Authentication**: Seamless login with **Google Sign-In** and Email/Password.
- **💬 Real-Time Messaging**: Instant 1-on-1 chats powered by Firestore streams.
- **👥 Group Chats**: Create groups, add friends, and chat simultaneously with live updates.
- **🛡️ Privacy First**: Toggle your "Online Status" and control what others see.
- **👤 Custom Profiles**: Set your "About" status and view stylized generative avatars.
- **⚡ Super Fast**: Optimized for performance on Web, Android, and iOS.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (3.x)
- **Language**: Dart
- **Backend Service**: [Firebase](https://firebase.google.com/)
  - **Firestore**: Real-time NoSQL Database
  - **Authentication**: Google & Email Providers
- **State Management**: Provider
- **UI Libraries**: `glassmorphism`, `flutter_animate`, `phosphor_flutter`, `google_fonts`

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- A Firebase Project with **Auth** and **Firestore** enabled.

### Installation

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/techieRahul17/PingMe.git
    cd PingMe
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**
    - Replace `lib/firebase_options.dart` with your project's generated file.
    - **Web**: Update `web/index.html` with your Google Sign-In Client ID.
      ```html
      <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
      ```
    - **Android**: Ensure `google-services.json` is in `android/app/`.

4.  **Run the App**
    ```bash
    flutter run
    # For Chrome
    flutter run -d chrome
    ```

## 📸 Screenshots

| Login Screen | chat Screen | Group Chat | Settings |
|:---:|:---:|:---:|:---:|
| ![Login](https://via.placeholder.com/200x400/000000/FF007F?text=Login) | ![Home](https://via.placeholder.com/200x400/000000/FF007F?text=Home) | ![Chat](https://via.placeholder.com/200x400/000000/FF007F?text=Chat) | ![Settings](https://via.placeholder.com/200x400/000000/FF007F?text=Settings) |

## 🤝 Contributing

Contributions are welcome! Please fork the repository and submit a pull request for any enhancements.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
  Built with ❤️ by <a href="https://github.com/techieRahul17">Rahul V S</a>
</p>
