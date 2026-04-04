# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `SDTool/SDTool.xcodeproj` in Xcode (15+), then:

```bash
# Build from command line (simulator)
xcodebuild -project SDTool/SDTool.xcodeproj \
  -scheme SDTool \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run tests
xcodebuild -project SDTool/SDTool.xcodeproj \
  -scheme SDTool \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test

# Run a single test class
xcodebuild -project SDTool/SDTool.xcodeproj \
  -scheme SDTool \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:SDToolTests/YourTestClass \
  test
```

**Required before first build:** Place `GoogleService-Info.plist` (downloaded from Firebase Console) at `SDTool/SDTool/GoogleService-Info.plist`. This file is gitignored and must never be committed. See `docs/FIREBASE_SETUP.md` for full setup.

## Architecture

Unidirectional data flow: **Views → Stores → Services → External APIs**

- **Views** (`SwiftUI`) bind to `@Published` properties on stores
- **Stores** (`ObservableObject`, `@MainActor`) own state and persist to `UserDefaults`
- **Services** (`actor`) handle all network/IO — thread-safe, no manual locking needed
- **External:** GitHub raw content (articles/blogs/flashcards), Firebase Auth, Firebase AI (Gemini), RSS feeds

### Feature Flag (V1 vs V2 UI)

`V2/FeatureFlags.swift` has a single `useNewUI: Bool = true` flag. This switches between:
- **V1:** 5-tab bottom bar (Home, Articles, Blogs, Flashcards, Settings)
- **V2:** 3-tab layout where the Home tab has a horizontal strip of dynamically added company/RSS tabs

When modifying UI, check this flag — both branches may need updating.

### Cross-Tab Navigation

`NavigationRouter.shared` (singleton `ObservableObject`) drives all cross-tab deep linking. Never push views directly across tab boundaries — always go through the router.

### App Launch Gate Order

`SDToolApp.swift` sequences: privacy consent → Firebase loading → login → splash → biometric lock → `ContentView`. All state transitions are driven by `AuthStore.shared` and `BiometricService.shared`.

## Key Files

| What you want to change | File |
|------------------------|------|
| App launch / gate logic | `SDTool/SDTool/SDToolApp.swift` |
| Auth (Google/Apple/Guest) | `SDTool/SDTool/Auth/AuthService.swift`, `AuthStore.swift` |
| AI calls (Gemini) | `SDTool/SDTool/AI/GeminiService.swift` |
| AI quota limits | `SDTool/SDTool/AI/AIQuotaStore.swift` |
| Article reader | `SDTool/SDTool/DocList/DocReaderView.swift` |
| V2 home / horizontal tabs | `SDTool/SDTool/V2/Home/HomeV2.swift` |
| Blog RSS fetching/caching | `SDTool/SDTool/Blogs/Services/BlogFeedService.swift` |
| Settings keys & defaults | `SDTool/SDTool/Models/AppSettings.swift` |
| GitHub content URLs | `SDTool/SDTool/Models/GitHubConfig.swift` |

## Content as Code

All app content lives in this same repo and is fetched at runtime via GitHub's raw content API:

- `articles/index.md` — pipe-delimited: `filename|name|category`
- `blogs/index.md` — pipe-delimited: `name|rssURL|websiteURL|emoji|domain|category|type`
- `flashcards/*.md` — `## Question\n\nAnswer` blocks

SHA-based change detection prevents unnecessary re-downloads. Bundled fallback content is in `SDTool/SDTool/Resources/SourceDocs.bundle/` and `SDTool/SDTool/FlashCards/Bundled/`.

## Git Workflow

- **Never commit or push changes unless the user explicitly asks.** Make code edits freely, but do not run `git commit` or `git push` until instructed.

## Patterns to Follow

- **New services** must be Swift `actor` types
- **Store updates** must happen on `@MainActor` — use `await MainActor.run { }` or `DispatchQueue.main.async`
- **Debug-only code** must be inside `#if DEBUG` blocks
- **Guest users** are blocked from AI features — check `GuestRestrictionView` / auth state before adding any new AI-gated UI
- **AI prompts** truncate content to ~15k chars to stay within token limits
