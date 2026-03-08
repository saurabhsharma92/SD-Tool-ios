# Architecture

SDTool follows a **unidirectional data flow** pattern using SwiftUI's `ObservableObject` + `@AppStorage` + actor-based services.

---

## Layer Overview

```
┌─────────────────────────────────────────────────┐
│                   SwiftUI Views                  │
│  HomeView  DocListView  BlogsView  FlashCards    │
│  SettingsView  DocReaderView  CompanyBlogView    │
└──────────────────┬──────────────────────────────┘
                   │ reads / binds
┌──────────────────▼──────────────────────────────┐
│              ObservableObject Stores             │
│  DocStore  BlogStore  FlashCardStore             │
│  ActivityStore  ReadingProgressStore             │
│  AuthStore  DailyPickStore  LikedPostsStore      │
└──────────────────┬──────────────────────────────┘
                   │ async calls
┌──────────────────▼──────────────────────────────┐
│               Swift Actors (Services)            │
│  DocSyncService  BlogSyncService                 │
│  FlashCardSyncService  GeminiService             │
│  BlogFeedService  BlogTextExtractor              │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│                External Services                 │
│  GitHub (raw content)   Firebase AI (Gemini)     │
│  Firebase Auth          RSS Feeds                │
└─────────────────────────────────────────────────┘
```

---

## App Launch Flow

```mermaid
flowchart TD
    A[App Launch] --> B[FirebaseApp.configure]
    B --> C[AuthStore listener starts]
    C --> D{Firebase session\nexists?}
    D -->|Yes| E{Biometric\nenabled?}
    D -->|No| F[LoginView]
    F -->|Google Sign-In| G[Firebase Auth]
    G --> E
    E -->|Yes| H[LockScreenView]
    E -->|No| I[ContentView - TabView]
    H -->|Face ID / Passcode| I
    I --> J[Home Tab]
```

---

## Authentication Flow

```mermaid
sequenceDiagram
    participant U as User
    participant App as SDToolApp
    participant AS as AuthStore
    participant GS as Google Sign-In SDK
    participant FB as Firebase Auth

    U->>App: Tap "Continue with Google"
    App->>GS: signIn(presenting:)
    GS->>U: Google OAuth sheet
    U->>GS: Approves
    GS-->>App: GIDSignInResult (idToken, accessToken)
    App->>FB: signIn(with: GoogleAuthProvider.credential)
    FB-->>AS: authStateDidChange(user)
    AS-->>App: isSignedIn = true
    App->>App: Show ContentView
```

---

## Content Sync Flow

```mermaid
sequenceDiagram
    participant V as DocListView
    participant S as DocStore
    participant Sync as DocSyncService (actor)
    participant GH as GitHub

    V->>S: sync()
    S->>Sync: fetchIndex()
    Sync->>GH: GET articles/index.md
    GH-->>Sync: Markdown table
    Sync-->>S: [(filename, name, category)]
    S->>S: mergeFetchedEntries()
    S->>S: save() to UserDefaults
    S-->>V: @Published docs updated
    V->>V: Re-renders list
```

---

## AI Flow (Gemini)

```mermaid
sequenceDiagram
    participant U as User
    participant R as DocReaderView
    participant AS as ArticleAISheet
    participant GS as GeminiService (actor)
    participant FB as Firebase AI

    U->>R: Tap "Summary" toolbar button
    R->>AS: .sheet(isPresented)
    AS->>AS: .task { await generate() }
    AS->>GS: summarizeArticle(doc, markdown)
    GS->>GS: Build prompt (truncated to 15k chars)
    GS->>FB: generateContent(prompt)
    FB-->>GS: GenerateContentResponse
    GS-->>AS: String result
    AS-->>U: Rendered markdown summary
```

---

## Cross-Tab Navigation

```mermaid
flowchart LR
    H[HomeView] -->|router.openArticle| NR[NavigationRouter]
    NR -->|selectedTab = 1| DL[DocListView]
    NR -->|articleDestination = doc| DR[DocReaderView]

    H -->|router.openBlog| NR
    NR -->|selectedTab = 2| BV[BlogsView]
    NR -->|blogDestination = company| CB[CompanyBlogView]
```

`NavigationRouter` is a singleton `ObservableObject`. `ContentView` observes it to drive tab switching. Each tab's `NavigationStack` observes `router.articleDestination` / `router.blogDestination` via `.onChange` to push the destination view.

---

## Data Persistence

| Store | Storage | Data |
|---|---|---|
| `DocStore` | UserDefaults | Article metadata (filename, name, category, state) |
| `ReadingProgressStore` | UserDefaults | Scroll progress per article (0.0–1.0) |
| `ActivityStore` | UserDefaults | Daily read counts (articles, blogs) |
| `LikedPostsStore` | UserDefaults | Liked blog post URLs + metadata |
| `BlogStore` | UserDefaults | Blog company list |
| `FlashCardStore` | UserDefaults | Deck metadata + cards |
| `FlashCardProgress` | UserDefaults | Known/unknown card keys |
| `DailyPickStore` | UserDefaults | Today's picked article + blog |
| `AppSettings` | UserDefaults (`@AppStorage`) | Theme, font, font size, Face ID toggle |

> All data is non-sensitive (reading progress, preferences). No financial or health data is stored. UserDefaults is acceptable for this data profile.

---

## Thread Safety

- All sync services are Swift **actors** — safe to call from any context
- All store updates happen on `@MainActor` via `DispatchQueue.main.async` or `await MainActor.run`
- `GeminiService` is an actor — concurrent AI calls are serialized automatically
- `BiometricService` and `AuthStore` are `ObservableObject` on main thread

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| GitHub as CMS | Zero backend cost, content versioned, community PRs for new articles |
| Firebase Auth (Google only) | Simplest OAuth without paid Apple Developer account requirement |
| Firebase AI with `.googleAI()` backend | Free tier, no Vertex AI billing setup needed |
| UserDefaults for all persistence | Content is non-sensitive; avoids CoreData complexity for MVP |
| `@AppStorage` for settings | Automatic SwiftUI binding, persists across launches |
| Actor for sync services | Swift concurrency, no manual locking needed |
| `NavigationRouter` singleton | Cross-tab deep linking without prop drilling |
