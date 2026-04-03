# AGENTS.md — SDTool iOS

This file provides full project context for AI agents and future reference. It covers architecture, features, patterns, data flow, and conventions to enable effective work without re-exploring the codebase from scratch.

---

## Project Summary

**SDTool** is a native iOS app (iOS 17+, SwiftUI, Swift 5.9) for software engineers to study system design. It provides:

- Markdown articles synced from GitHub
- RSS feeds from top engineering blogs (Netflix, Uber, Airbnb, etc.)
- Flash card decks with spaced repetition
- Gemini AI summaries / ELI5 / multi-turn chat on articles and blog posts
- Google + Apple Sign-In via Firebase Authentication
- Face ID / Touch ID app lock
- V2 redesign with horizontal tab strip, favorites, and custom RSS feeds

**Bundle ID:** `com.ss9.SDTool`  
**GitHub Repo:** `saurabhsharma92/SD-Tool-ios`  
**Xcode Project:** `SDTool/SDTool.xcodeproj`

---

## Related Projects

- **SD-ios (web)** — Companion web project started alongside this iOS app. Shares the same content repository structure (articles, blogs index, flashcards on GitHub). Design decisions in the web project can inform the iOS app and vice versa.

---

## Repository Layout

```
SD-Tool-ios/
├── SDTool/SDTool/               # All Swift source code
│   ├── SDToolApp.swift          # Entry point
│   ├── NavigationRouter.swift   # Cross-tab deep linking singleton
│   ├── Auth/                    # Auth + biometrics
│   ├── Models/                  # Shared data models & settings
│   ├── Storage/                 # Persistence stores
│   ├── DocList/                 # Articles feature
│   ├── Blogs/                   # Engineering blogs / RSS feature
│   ├── FlashCards/              # Flash cards feature
│   ├── AI/                      # Gemini AI integration
│   ├── V2/                      # New UI redesign (feature-flagged)
│   └── Resources/               # Bundled articles + flash card decks
├── articles/                    # CMS: article markdown files
│   └── index.md                 # Article registry (pipe-delimited)
├── blogs/
│   └── index.md                 # Blog company registry (pipe-delimited)
├── flashcards/                  # Flash card deck markdown files
├── docs/                        # Architecture, Firebase setup, contribution guides
└── AGENTS.md                    # This file
```

---

## Architecture

### Pattern: Unidirectional Data Flow

```
SwiftUI Views
    │ reads / binds
ObservableObject Stores        (@Published, @MainActor)
    │ async calls
Swift Actors (Services)        (thread-safe, no manual locking)
    │
External Services              (GitHub raw, Firebase Auth, Firebase AI, RSS)
```

### Layer Responsibilities

| Layer | Type | Responsibility |
|-------|------|---------------|
| Views | `View` structs | UI rendering, user input |
| Stores | `ObservableObject` | Reactive state, UserDefaults persistence |
| Services | `actor` | Network calls, sync, parsing, caching |
| Models | `struct` / `enum` | Pure data types |

---

## Entry Point & App Launch States

**`SDToolApp.swift`** sequences through these states:

1. **Privacy consent gate** — shown once on first launch (`PrivacyConsentView`)
2. **Firebase loading** — checking persisted session (4s timeout)
3. **Login view** — Google Sign-In or Apple Sign-In (`LoginView`)
4. **Splash animation** — shown after first sign-in (`SplashView`)
5. **Biometric lock** — if Face ID enabled and app returned from background (`LockScreenView`)
6. **Main app** — `ContentView` (TabView)

App Check is configured before `FirebaseApp.configure()`:
- Debug builds: `AppCheckDebugProviderFactory`
- Release builds: `SDToolAppCheckFactory` (App Attest)

---

## Navigation Architecture

### V1 (legacy, `FeatureFlags.useNewUI = false`)

```
TabView (5 tabs)
├── 0: HomeView         — daily picks, recent reads
├── 1: DocListView      — article list/grid
├── 2: BlogsView        — blog companies
├── 3: FlashCardsHomeView
└── 4: SettingsView
```

### V2 (default, `FeatureFlags.useNewUI = true`)

```
TabView (3 tabs)
├── 0: HomeV2
│   └── Horizontal tab strip
│       ├── Favorites
│       ├── Articles
│       ├── [Company tabs — pinnable, hideable]
│       ├── [Custom RSS feed tabs]
│       └── + Add feed
├── 1: FlashCardsHomeView  (unchanged from v1)
└── 2: SettingsV2
```

### Cross-Tab Deep Linking

`NavigationRouter` is a shared singleton `ObservableObject`. Use it to navigate across tabs:

```swift
NavigationRouter.shared.openArticle(_ doc: Doc)
NavigationRouter.shared.openBlogPost(_ url: URL)
```

`ContentView` observes `router.selectedTab` to switch tabs. Each tab's `NavigationStack` observes `router.articleDestination` / `router.blogDestination` via `.onChange` to push the destination view.

---

## Authentication

**Providers:** Google Sign-In + Apple Sign-In (both via Firebase Auth) + Guest (anonymous)

**Key files:**
- `Auth/AuthService.swift` — OAuth logic (stateless)
- `Auth/AuthStore.swift` — `ObservableObject`, exposes `isSignedIn`, `email`, `displayName`
- `Auth/BiometricService.swift` — Face ID / Touch ID with passcode fallback
- `Auth/LoginView.swift` — Sign-in UI
- `Auth/LockScreenView.swift` — Biometric lock screen

**Apple Sign-In** uses nonce/SHA256 for security. **Google Sign-In** uses the `GoogleSignIn` SDK.

**Biometric lock** triggers when `scenePhase == .background`. Re-authenticates on `.active` if lock is set.

**Guest mode** allows limited use (no AI features — gated by `GuestRestrictionView`).

---

## Feature Flags

```swift
// SDTool/SDTool/V2/FeatureFlags.swift
enum FeatureFlags {
    static let useNewUI: Bool = true
}
```

This single flag switches between v1 (5-tab) and v2 (3-tab with horizontal strip) UIs throughout the app. `ContentView` and `DocList/ContentView.swift` both check this flag.

---

## Data Models

| Model | File | Purpose |
|-------|------|---------|
| `Doc` | `Models/Doc.swift` | Article metadata; state machine: `remote → downloading → downloaded` |
| `DocSection` | `Models/DocSection.swift` | User-created article groupings |
| `BlogCompany` | `Blogs/Model/BlogCompany.swift` | Blog company with RSS URL, website, emoji, category |
| `BlogPost` | `Blogs/Model/BlogPost.swift` | Individual blog post (title, URL, date, summary) |
| `FlashDeck` | `FlashCards/Model/FlashDeck.swift` | Collection of flash cards |
| `FlashCard` | `FlashCards/Model/FlashCard.swift` | Front/back card (key/value) |
| `FlashCardProgress` | `FlashCards/Model/FlashCardProgress.swift` | Spaced repetition state per card |
| `FavoriteItem` | `V2/FavoriteStore.swift` | Favorited article or blog post (v2) |
| `ChatMessage` | `AI/ChatMessage.swift` | Message in multi-turn AI chat |
| `AppSettings` | `Models/AppSettings.swift` | Settings keys, defaults, enums (colors, fonts, Gemini models) |

---

## Stores (ObservableObject)

| Store | Singleton | Key Responsibility |
|-------|-----------|-------------------|
| `AuthStore` | `AuthStore.shared` | Auth state, sign-in/out methods |
| `DocStore` | instance (injected) | Articles list, download state, GitHub sync trigger |
| `BlogStore` | instance | Blog companies, subscription state |
| `FlashCardStore` | instance | Decks, bundled seeding, sync |
| `FavoriteStore` | instance | Saved articles/blogs (v2) |
| `CompanyVisibilityStore` | instance | Blog tab visibility + pinning + custom RSS feeds (v2) |
| `AIQuotaStore` | `AIQuotaStore.shared` | Daily AI usage tracking per model |
| `BiometricService` | `BiometricService.shared` | Biometric unlock state |
| `DocSectionStore` | instance | User-created article sections |
| `ActivityStore` | instance | Read counts, recent reads |
| `DailyPickStore` | instance | Today's article/blog picks |
| `LikedPostsStore` | instance | Liked blog post URLs |
| `ReadingProgressStore` | instance | Scroll progress per article |

---

## Services (Swift Actors)

| Service | Responsibility |
|---------|---------------|
| `AuthService` | OAuth flow (Google + Apple), stateless |
| `DocSyncService` | Fetch article index + download files from GitHub |
| `BlogSyncService` | Fetch company index from GitHub |
| `BlogFeedService` | Fetch RSS feeds; memory + disk cache (TTL-based) |
| `FlashCardSyncService` | Fetch flash card decks from GitHub |
| `FlashCardParser` | Parse markdown Q&A into `FlashCard` objects |
| `GeminiService` | Firebase AI calls; deduplication + quota tracking |
| `RSSParser` | XML RSS → `[BlogPost]` |
| `BlogTextExtractor` | Extract plain text from blog HTML for AI context |

All services are actors — thread-safe, no manual locking required.

---

## AI Integration

**Backend:** Firebase AI Logic (Gemini), free Spark plan tier

### Models

```swift
enum GeminiModel: String {
    case flashLite = "gemini-2.5-flash-lite"   // lightest, ~20 req/day
    case flash     = "gemini-2.5-flash"        // default, ~50 req/day
    case pro       = "gemini-2.5-pro"          // most capable, ~25 req/day
}
```

### Quota

- Tracked per model per day in `AIQuotaStore`
- Resets daily at midnight PT
- `UserDefaults` keys: `aiQuota_usedToday`, `aiQuota_date`, `aiQuota_breakdown`, `aiQuota_exhausted`

### AI Features

| Feature | Entry Point | Service |
|---------|-------------|---------|
| Article summary | `ArticleAISheet` | `GeminiService.summarizeArticle` |
| Article ELI5 | `ArticleAISheet` | `GeminiService.explainArticle` |
| Article chat | `ArticleChatView` | `GeminiService` multi-turn with 20-message history |
| Blog summary | `BlogAISheet` | `GeminiService` + `BlogTextExtractor` |

Prompts truncate article markdown to ~15k chars to stay within token limits.
`ArticleSummaryCache` prevents duplicate calls if user toggles summary on/off.

---

## Content Sync (GitHub as CMS)

All content is self-hosted in this GitHub repo. No paid CMS.

### Articles

```
articles/index.md   — format: "filename|name|category" per line
articles/*.md       — full article markdown
```

`DocSyncService` fetches the index, computes SHA diff, downloads only changed files. State per article: `remote → downloading → downloaded`.

### Blogs

```
blogs/index.md   — format: name|rssURL|websiteURL|emoji|domain|category|type
```

`BlogSyncService` fetches and parses this. `BlogFeedService` fetches individual RSS feeds with 3-tier caching: memory → disk (UserDefaults) → network.

### Flash Cards

```
flashcards/*.md  — format: "## Question\n\nAnswer" blocks
```

`FlashCardParser` splits markdown into `FlashCard` objects. Bundled decks live at `SDTool/SDTool/FlashCards/Bundled/`.

---

## Persistence

All data uses `UserDefaults` (non-sensitive content — reading progress, preferences, article metadata).

| Data | UserDefaults Key | Type |
|------|-----------------|------|
| Articles | `githubDocs` | `[Doc]` JSON |
| Article sections | `docSections` | `[DocSection]` JSON |
| Blog companies | `blogCompanies` | `[BlogCompany]` JSON |
| RSS cache (per company) | `rss_cache_{uuid}` | `DiskCacheEntry` JSON |
| Flash decks | `flashDecks` | `[FlashDeck]` JSON |
| Card progress | `fc_progress` | `FlashCardProgress` JSON |
| Favorites (v2) | `v2_favorites` | `[FavoriteItem]` JSON |
| Theme | `colorScheme` | String |
| Font family | `appFont` | String |
| Font size | `fontSize` | Double |
| Face ID | `faceIDEnabled` | Bool |
| Gemini model | `geminiModel` | String |

---

## V2 Redesign Directory

`SDTool/SDTool/V2/` contains the new UI enabled by `FeatureFlags.useNewUI = true`.

| File | Purpose |
|------|---------|
| `FeatureFlags.swift` | Master `useNewUI` switch |
| `AppSettingsV2.swift` | V2-specific settings |
| `Home/HomeV2.swift` | Root home with horizontal tab strip |
| `Home/ArticlesTabV2.swift` | Searchable article list |
| `Home/FavoritesTabV2.swift` | Favorites display |
| `Home/CompanyTabV2.swift` | Single company RSS feed |
| `Settings/SettingsV2.swift` | Enhanced settings (blog/RSS management) |
| `FavoriteStore.swift` | Favorites persistence |
| `CompanyVisibilityStore.swift` | Blog visibility toggles + custom RSS feeds |
| `GuestRestrictionView.swift` | Block guest users from AI features |
| `PrivacyConsentView.swift` | First-launch privacy gate |
| `RSSFeedSheet.swift` | Add custom RSS feeds dialog |

---

## External Dependencies

### Swift Package Manager

| Package | Use |
|---------|-----|
| `FirebaseCore` | Foundation |
| `FirebaseAuth` | Authentication |
| `FirebaseAppCheck` | Device attestation (security) |
| `FirebaseAI` | Gemini AI integration |
| `GoogleSignIn` | Google OAuth |
| `GoogleSignInSwift` | SwiftUI wrapper for Google Sign-In |

### System Frameworks

`Combine`, `SwiftUI`, `LocalAuthentication` (Face ID), `AuthenticationServices` (Apple Sign-In)

---

## Key Conventions

- **Actors for all services** — never add sync/locking manually
- **@MainActor for store updates** — use `await MainActor.run { }` or `DispatchQueue.main.async`
- **SHA-based change detection** — check `remoteSHA` before re-downloading content
- **`#if DEBUG` for bypasses** — never ship debug code without this guard
- **`GoogleService-Info.plist` is gitignored** — never commit it
- **Feature flags gate v2** — check `FeatureFlags.useNewUI` when adding UI that differs between versions
- **Singletons**: `AuthStore.shared`, `GeminiService.shared`, `NavigationRouter.shared`, `BiometricService.shared`, `AIQuotaStore.shared`
- **Guest restrictions** — AI features must check `GuestRestrictionView` / guest state

---

## Security Notes

- Firebase App Check enforced in production (App Attest)
- Apple Sign-In uses nonce/SHA256
- `NSAllowsArbitraryLoads` is `true` in Info.plist — review before App Store submission
- All auth tokens handled by Firebase SDK; never stored manually
- Face ID re-authenticates on every foreground return (if enabled)

---

## Common Tasks Quick Reference

| Task | Where to look |
|------|--------------|
| Add a new article | `articles/index.md` + `articles/<name>.md` |
| Add a blog company | `blogs/index.md` (pipe-delimited row) |
| Add a flash card deck | `flashcards/<name>.md` + register in `FlashCardConfig` |
| Add a new AI feature | `AI/GeminiService.swift` + new view in `AI/` |
| Add a v2 tab | `V2/Home/HomeV2.swift` horizontal strip logic |
| Change default settings | `Models/AppSettings.swift` |
| Add a settings key | `Models/AppSettings.swift` enum + `@AppStorage` in relevant view |
| Change Gemini model defaults | `Models/AppSettings.swift` `GeminiModel` enum |
| Update deep linking | `NavigationRouter.swift` |
| Toggle v1/v2 | `V2/FeatureFlags.swift` `useNewUI` |
