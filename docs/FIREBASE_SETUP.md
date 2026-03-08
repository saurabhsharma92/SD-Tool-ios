# Firebase Setup Guide

SDTool uses Firebase for three things: **Authentication**, **AI (Gemini)**, and **App Check**. This guide walks through setting up a fresh Firebase project from scratch.

---

## 1. Create a Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it `SDTool-iOS`
3. Disable Google Analytics (not needed) → **Create project**

---

## 2. Add Your iOS App

1. In the project overview, click the **iOS icon** (Add app)
2. Enter bundle ID: `com.ss9.SDTool`
3. Enter app nickname: `SDTool`
4. Click **Register app**
5. **Download `GoogleService-Info.plist`**
6. Place it in `SDTool/SDTool/GoogleService-Info.plist` in Xcode
7. **Do NOT commit this file** — it's in `.gitignore`

---

## 3. Add Firebase SDK via Swift Package Manager

In Xcode → File → Add Package Dependencies:

```
https://github.com/firebase/firebase-ios-sdk
```

Add these products to your target:
- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseAI`
- `FirebaseAppCheck`

Also add Google Sign-In:
```
https://github.com/google/GoogleSignIn-iOS
```
Add: `GoogleSignIn`, `GoogleSignInSwift`

---

## 4. Enable Authentication

1. Firebase Console → **Authentication** → Get Started
2. **Sign-in method** tab → enable:
   - **Google** — set project name `SDTool`, support email → Save
   - **Anonymous** — enable → Save (used for debug bypass in development)

---

## 5. Add Reversed Client ID URL Scheme

1. Open your downloaded `GoogleService-Info.plist`
2. Find the `REVERSED_CLIENT_ID` value (starts with `com.googleusercontent.apps.`)
3. In Xcode → `SDTool` target → **Info** tab → **URL Types** → `+`
4. Set **URL Schemes** to your `REVERSED_CLIENT_ID` value

---

## 6. Enable Firebase AI (Gemini)

1. Firebase Console → **Build** → **AI Logic** → Get Started
2. Choose **Gemini Developer API** (free tier, no billing required)
3. Click **Enable**

The app uses model `gemini-2.5-flash-lite` via the `.googleAI()` backend.

### How the app calls Gemini

```swift
// GeminiService.swift
actor GeminiService {
    static let shared = GeminiService()

    private func generate(_ prompt: String) async throws -> String {
        let ai    = FirebaseAI.firebaseAI(backend: .googleAI())
        let model = ai.generativeModel(modelName: "gemini-2.5-flash-lite")
        let response = try await model.generateContent(prompt)
        return response.text ?? ""
    }
}
```

All AI calls go through `GeminiService` which is a Swift actor — concurrent calls are automatically serialized. The service is called from views via `.task { await generate() }`.

---

## 7. Configure App Check

App Check protects your Firebase AI endpoint from unauthorized use.

### For Simulator / Development

1. In `SDToolApp.swift`, the app registers `AppCheckDebugProviderFactory` in `#if DEBUG`:

```swift
#if DEBUG
let providerFactory = AppCheckDebugProviderFactory()
AppCheck.setAppCheckProviderFactory(providerFactory)
#endif
FirebaseApp.configure()
```

2. Run the app on simulator — look in Xcode console for:
```
[Firebase/AppCheck] Firebase App Check debug token: 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
```

3. Firebase Console → **App Check** → **Apps** → your iOS app → `...` → **Manage debug tokens** → **Add debug token** → paste the UUID

### For Physical Devices (Release)

Physical devices use **DeviceCheck** automatically in release builds — no extra setup needed.

### Enforce App Check

Firebase Console → **App Check** → **APIs** → **Firebase AI Logic** → **Enforce**

---

## 8. Firebase Architecture in the App

```
SDToolApp.init()
    └── FirebaseApp.configure()           ← must be first
         └── AppCheck.setFactory()        ← before configure in DEBUG

AuthStore.init()
    └── Auth.auth().addStateDidChangeListener()
         └── fires immediately with persisted user (or nil)
              └── sets isLoading = false
                   └── SDToolApp shows LoginView or ContentView

GeminiService (actor)
    └── called by ArticleAISheet, BlogAISheet, ArticleChatView
         └── FirebaseAI.firebaseAI(backend: .googleAI())
              └── model.generateContent(prompt)
                   └── App Check token attached automatically
```

---

## 9. Environment Variables / Secrets

| Secret | Location | Committed? |
|---|---|---|
| `GoogleService-Info.plist` | `SDTool/SDTool/` | ❌ Never |
| Firebase API Key | Inside the plist | ❌ Never |
| `REVERSED_CLIENT_ID` | Info.plist URL scheme | ✅ Safe (public) |
| App Check debug token | Firebase Console only | ❌ Never in code |

### Rotating a Compromised Key

If `GoogleService-Info.plist` is accidentally committed:

1. Google Cloud Console → **Credentials** → find **iOS key** → **Rotate key**
2. Firebase Console → Project Settings → download new `GoogleService-Info.plist`
3. Replace the file in Xcode
4. Remove from git history:
```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch SDTool/SDTool/GoogleService-Info.plist" \
  --prune-empty --tag-name-filter cat -- --all
git push origin --force --all
```

---

## 10. Firebase Console Quick Reference

| Task | Path |
|---|---|
| View signed-in users | Authentication → Users |
| Check AI usage | AI Logic → Usage |
| Manage App Check tokens | App Check → Apps → your app → ... |
| View API key restrictions | Google Cloud Console → Credentials |
| Enable/disable providers | Authentication → Sign-in method |
