# SDTool — System Design Explorer

> A native iOS app for engineers to read system design articles, follow engineering blogs, study with flash cards, and get AI-powered explanations — all in one place.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![Firebase](https://img.shields.io/badge/firebase-10%2B-yellow)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Live Demo

**[🌐 View Project Page →](https://saurabhsharma92.github.io/SD-Tool-ios/)**

[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-live-brightgreen?logo=github)](https://saurabhsharma92.github.io/SD-Tool-ios/)

---

## Features

| Feature | Description |
|---|---|
| 📄 **Articles** | Markdown articles synced from GitHub, rendered natively with Mermaid diagram support |
| 📰 **Blogs** | RSS feeds from top engineering blogs (Netflix, Uber, Airbnb, etc.) |
| 🃏 **Flash Cards** | Study decks synced from GitHub, spaced-repetition style |
| 🤖 **AI Assistant** | Summarize or get ELI5 explanations via Gemini AI on any article or blog post |
| 💬 **Article Chat** | Multi-turn chat with context from the article you're reading |
| 🔐 **Auth** | Google Sign-In via Firebase Authentication |
| 🔒 **Biometric Lock** | Face ID / Touch ID app lock with passcode fallback |
| 🏠 **Smart Home** | Daily picks, in-progress articles, liked blogs — all in one home screen |
| 🎨 **Appearance** | Light/Dark/System theme, font family, font size controls |

---

## Architecture

```
SDTool/
├── App/
│   └── SDToolApp.swift          # Entry point, Firebase init, auth gate, biometric gate
├── Auth/
│   ├── AuthService.swift        # Google Sign-In wrapper
│   ├── AuthStore.swift          # ObservableObject, auth state
│   ├── LoginView.swift          # Sign-in screen
│   ├── BiometricService.swift   # Face ID / Touch ID
│   └── LockScreenView.swift     # Lock screen UI
├── Articles/
│   ├── DocStore.swift           # Article metadata store
│   ├── DocSyncService.swift     # GitHub sync (actor)
│   ├── DocSectionStore.swift    # Manual sections & pinning
│   ├── DocListView.swift        # Article list/grid tab
│   ├── DocReaderView.swift      # Markdown renderer + AI buttons
│   └── DocGridView.swift        # Grid layout
├── Blogs/
│   ├── BlogStore.swift          # Blog companies store
│   ├── BlogSyncService.swift    # GitHub sync (actor)
│   ├── BlogFeedService.swift    # RSS feed fetching
│   ├── BlogsView.swift          # Companies tab
│   ├── CompanyBlogView.swift    # RSS feed for one company
│   └── AI/
│       ├── BlogTextExtractor.swift
│       └── BlogAISheet.swift
├── FlashCards/
│   ├── FlashCardStore.swift     # Decks store
│   ├── FlashCardSyncService.swift
│   ├── FlashCardsHomeView.swift
│   └── StudyView.swift
├── AI/
│   ├── GeminiService.swift      # Firebase AI actor
│   ├── ArticleAISheet.swift     # Summarize / ELI5 sheet
│   ├── ArticleChatView.swift    # Multi-turn chat
│   └── ArticleSummaryCache.swift
├── Home/
│   ├── HomeView.swift           # Dashboard
│   ├── DailyPickStore.swift
│   └── ActivityStore.swift
├── Settings/
│   ├── SettingsView.swift
│   ├── AppSettings.swift        # Keys, defaults, enums
│   └── HowToView.swift          # Contribution guide
└── Shared/
    ├── NavigationRouter.swift   # Cross-tab deep linking
    ├── ActivityDialView.swift
    ├── ZoomableImageView.swift
    └── ContentView.swift        # TabView root
```

For full architecture details see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Getting Started

### Prerequisites

- Xcode 15+
- iOS 17+ deployment target
- macOS Sonoma or later
- A Firebase project (free Spark plan works)
- A Google Cloud project (auto-created with Firebase)

### 1. Clone the Repository

```bash
git clone https://github.com/saurabhsharma92/SD-Tool-ios.git
cd SD-Tool-ios
```

### 2. Firebase Setup

See [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for the full step-by-step guide. Quick summary:

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an iOS app with bundle ID `com.ss9.SDTool`
3. Download `GoogleService-Info.plist` → place in `SDTool/SDTool/`
4. Enable **Google Sign-In** and **Anonymous** providers in Authentication
5. Enable **Firebase AI Logic** (Gemini)
6. Configure **App Check** with debug token for simulator

> ⚠️ `GoogleService-Info.plist` is in `.gitignore` — never commit it.

### 3. Add URL Scheme

In Xcode → `SDTool` target → Info → URL Types → add:
```
URL Scheme: com.googleusercontent.apps.<YOUR_CLIENT_ID>
```
(Copy `REVERSED_CLIENT_ID` from your `GoogleService-Info.plist`)

### 4. Add Info.plist Keys

```xml
<key>NSFaceIDUsageDescription</key>
<string>SDTool uses Face ID to protect your study data</string>
```

### 5. Build & Run

Open `SDTool/SDTool.xcodeproj` in Xcode and press ⌘R.

---

## Content Repository Structure

All content (articles, blogs, flash cards) is sourced from this same GitHub repository:

```
SD-Tool-ios/
├── articles/
│   ├── index.md              # Article registry
│   └── *.md                  # Article files
├── blogs/
│   └── index.md              # Blog company registry
└── flashcards/
    └── *.md                  # Flash card decks
```

See [docs/CONTENT.md](docs/CONTENT.md) for format details.

---

## Contributing

We welcome contributions! See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the full guide.

Quick links:
- [Submit an article](docs/CONTRIBUTING.md#submitting-an-article)
- [Request a blog company](docs/CONTRIBUTING.md#requesting-a-blog-company)
- [Add flash card decks](docs/CONTRIBUTING.md#adding-flash-card-decks)
- [Report a bug](https://github.com/saurabhsharma92/SD-Tool-ios/issues)

---

## Security

See [docs/SECURITY.md](docs/SECURITY.md) for the full security policy.

Key points:
- `GoogleService-Info.plist` must never be committed — it is in `.gitignore`
- All network calls use HTTPS — no `NSAllowsArbitraryLoads`
- Debug bypass code is strictly inside `#if DEBUG` blocks
- App Check is enforced in production

---

## License

MIT — see [LICENSE](LICENSE)
