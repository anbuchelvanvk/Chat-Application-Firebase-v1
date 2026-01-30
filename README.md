# 💬 PingMe - Real-Time Chat App

PingMe is a modern, real-time messaging application built with **Flutter** and **Firebase**. It features a robust privacy-focused architecture, instant messaging, and live user status updates. It's UI/UX and frontend is being designed by [Lavanya Karthikeyan]([url]("https://github.com/lavanya-3006")), while the backend process, and conversion of idea into fully working application is made by [Anbuchelvan VK]([url](https://github.com/anbuchelvanvk)) (Myself).

## ✨ Features

- **Authentication**: Secure Email/Password login with a unique Username system.
- **Real-Time Chat**: Instant messaging with Firestore streams.
- **Live Status**:
  - "Online" / "Offline" indicators.
  - "Last Seen" timestamps (e.g., "Last seen today at 10:30").
  - "Typing..." indicators.
- **Message Status**: Visual ticks for Sent, Delivered, and Seen.
- **Privacy Architecture**:
  - **Public Profile**: Searchable data (Username, Display Name).
  - **Private Profile**: Protected data (Email, Security Questions).
- **Search**: Optimized user search with debounce to reduce database reads.

## 🛡️ Security & Privacy

PingMe implements a robust security model to protect user data:

- **Public/Private Data Split**: Sensitive data (Email, DOB) is isolated in a private collection, while only essential discovery data (Username, Status) is public.
- **End-to-End Database Rules**: Firestore security rules enforce strict ownership, ensuring users can only access chats they are participants in.
- **Secure Hashing**: Security question answers are hashed using **SHA-256** before storage, ensuring raw answers are never exposed.
- **Impersonation Protection**: Atomic transactions and unique index constraints prevent username duplication or hijacking.

## 🛠️ Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **Backend**: Firebase (Firestore Database)
- **Auth**: Firebase Authentication
- **State Management**: `StreamBuilder` & `FutureBuilder`

## 🌟 Credits

- **Frontend Design & UI/UX**: [Lavanya Karthikeyan]([url](https://github.com/lavanya-3006)) (A Big Thankyou!)
- **Development**: [Anbuchelvan VK]([url](https://github.com/anbuchelvanvk))

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed
- A Firebase Project

### 📸 Screenshots
1. Login Page :
   ![WhatsApp Image 2026-01-30 at 22 25 41](https://github.com/user-attachments/assets/542c7c2f-84bf-447d-bed0-5e2d902500d7)


2. Complete Profile while SignUp!
   ![WhatsApp Image 2026-01-30 at 22 25 41 (1)](https://github.com/user-attachments/assets/9dd61027-ca2e-4546-9049-ea113c92817e)


3. ChatList Screen :
   ![WhatsApp Image 2026-01-30 at 22 25 42](https://github.com/user-attachments/assets/c71cc460-b8d4-4eac-b343-04a0e417bb6e)

   
4. Realtime Online, LastSeen and Typing Indication:
   ![WhatsApp Image 2026-01-30 at 22 25 43 (1)](https://github.com/user-attachments/assets/a48b6ddf-2aca-4796-9f3e-b9a0ffbd6e70)



### Installation

1. **Clone the repository**

   ```git clone [https://github.com/your-username/pingme.git](https://github.com/your-username/pingme.git)```
   
   ```cd pingme```
   
2. **Install Dependencies**

```flutter pub get```

3 **Firebase Setup**
- Create a project in the Firebase Console.
- Enable Authentication (Email/Password).
- Enable Firestore Database.
- Copy your google-services.json (Android) and GoogleService-Info.plist (iOS) into the respective folders.

4. **Run the App**

```flutter run```

🤝 Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

📄 License
[MIT](LICENSE)
