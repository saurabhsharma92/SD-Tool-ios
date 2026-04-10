# Chat Tab Feature Plan

## Context

The app currently has Gemini AI integrated for article-specific Q&A (via Firebase AI). Users want a standalone Chat tab where they can have general-purpose conversations with Claude (Anthropic), OpenAI (ChatGPT), or Gemini — without tying the chat to any specific article. 

Users bear their own API costs by providing their own API keys. Keys are stored securely in iOS Keychain. No backend proxy is needed. Gemini reuses the existing Firebase integration (free, no user key required) as a zero-setup option.

---

## Architecture Overview

```
ChatTabView
  └── ProviderSetupView       (if no provider configured)
  └── ChatConversationView    (main chat UI, reuses ArticleChatView patterns)
       └── ClaudeService      (actor, direct Anthropic API)
       └── OpenAIService      (actor, direct OpenAI API)
       └── GeminiService      (existing actor, reused as-is)

KeychainService               (new — wrapper for SecItem APIs)
ChatProviderStore             (ObservableObject — selected provider, key status)
ChatStore                     (ObservableObject — conversation history per provider)
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Chat/KeychainService.swift` | Generic Keychain read/write/delete wrapper using `SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`. Keys scoped to app bundle ID. |
| `Chat/ChatProviderStore.swift` | `@MainActor ObservableObject`. Tracks selected provider (`claude`, `openai`, `gemini`), whether each key is saved, and exposes save/delete key methods via `KeychainService`. |
| `Chat/Services/ClaudeService.swift` | `actor`. Sends requests to `https://api.anthropic.com/v1/messages`. Uses `anthropic-version: 2023-06-01` header. Supports multi-turn via `messages` array. Reads API key from Keychain at call time. |
| `Chat/Services/OpenAIService.swift` | `actor`. Sends requests to `https://api.openai.com/v1/chat/completions`. Supports multi-turn via `messages` array. Reads API key from Keychain at call time. |
| `Chat/ChatStore.swift` | `@MainActor ObservableObject`. Holds `[ChatMessage]` conversation history per provider (3 separate arrays). Handles sending messages by dispatching to the right service. Persists history to filesystem (like `FlashCardStore`). |
| `Chat/ChatTabView.swift` | Root view for the Chat tab. Shows `ProviderSetupView` if no provider is configured, otherwise `ChatConversationView`. Includes a provider picker toolbar button. |
| `Chat/ProviderSetupView.swift` | Onboarding/settings sheet for entering API keys. One section per provider. Each has a `SecureField` for the key, a "Save" button, and a link to the provider's API key console. Shows checkmark when key is saved. |
| `Chat/ChatConversationView.swift` | Chat UI — adapts patterns from `ArticleChatView.swift`. Message list (user = blue right, assistant = gray left, Markdown rendered). Input bar with `TextField` + send button. Provider name shown in nav title. |

---

## Files to Modify

| File | Change |
|------|--------|
| `DocList/ContentView.swift` | Add `.chat` tab (tag 2) to `newTabView`. Position: Home → FlashCards → **Chat** → Settings. Use `systemImage: "bubble.left.and.bubble.right.fill"`. |
| `Models/AppSettings.swift` | Add `ChatKey` namespace with `selectedProvider: String` UserDefaults key. |
| `NavigationRouter.swift` | Add `selectedTab = 2` constant for chat tab if deep linking is ever needed. |

---

## Key Implementation Details

### Keychain Storage
```swift
// Save key
KeychainService.save(key: "chat_api_key_claude", value: "sk-ant-...")

// Read key (at call time, never cached in memory)
let apiKey = KeychainService.read(key: "chat_api_key_claude")

// Delete key
KeychainService.delete(key: "chat_api_key_claude")
```
- Use `kSecClassGenericPassword`, `kSecAttrAccount` = key name, `kSecAttrService` = bundle ID
- `kSecAttrAccessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (most secure; not backed up to iCloud)

### Claude API Call (actor)
```swift
// POST https://api.anthropic.com/v1/messages
// Headers: x-api-key, anthropic-version: 2023-06-01, content-type: application/json
// Body: { model: "claude-opus-4-6", max_tokens: 1024, messages: [...] }
```

### OpenAI API Call (actor)
```swift
// POST https://api.openai.com/v1/chat/completions
// Headers: Authorization: Bearer sk-..., content-type: application/json
// Body: { model: "gpt-4o", messages: [...] }
```

### Gemini
- Reuse `GeminiService.shared` directly — no changes needed.
- No API key required from user (Firebase App Check handles auth).

### Guest User Restriction
- Chat tab visible to all, but sending a message checks auth state.
- If guest: show `GuestRestrictionView` (existing component, already used for AI features).

### Conversation Persistence
- Each provider has its own history file in the app's Documents directory.
- Format: JSON array of `ChatMessage` (same struct used in `ArticleChatView`).
- "Clear conversation" button in toolbar deletes the file and resets in-memory array.

---

## Tab Bar After Change

```
V2 Tab Bar (4 tabs):
[Home (0)] [Flash Cards (3)] [Chat (2)] [Settings (4)]
```
Tags are non-sequential by design (matches existing pattern where V1 tags are preserved).

---

## Reusable Components

- `ChatMessage` struct — `SDTool/SDTool/AI/ArticleChatView.swift` (reuse as-is)
- `GeminiService.shared` — `SDTool/SDTool/AI/GeminiService.swift` (no changes)
- `GuestRestrictionView` — `SDTool/SDTool/V2/GuestRestrictionView.swift` (reuse as-is)
- Markdown rendering pattern — copy from `ArticleChatView.swift` (uses `MarkdownUI`)
- Typing indicator dots — copy from `ArticleChatView.swift`

---

## Verification / Testing

1. **Build check**: `xcodebuild -project SDTool/SDTool.xcodeproj -scheme SDTool -destination 'platform=iOS Simulator,name=iPhone 16' build`
2. **Tab appears**: Run in simulator — Chat tab shows in bottom bar between FlashCards and Settings.
3. **No key configured**: Tapping Chat shows `ProviderSetupView` with sections for Claude, OpenAI, Gemini.
4. **Keychain save/read**: Enter a fake key, save, kill app, reopen — key still present (shown as saved).
5. **Gemini chat**: Select Gemini (no key needed), send a message, receive a response.
6. **Claude/OpenAI chat**: Enter valid API key, send a message, verify response from correct provider.
7. **Guest restriction**: Sign in as guest, open Chat, try sending — `GuestRestrictionView` appears.
8. **Conversation persistence**: Send messages, kill app, reopen — history restored.
9. **Key deletion**: Delete a key in `ProviderSetupView` — provider shows as "not configured".
10. **Error handling**: Enter invalid key — show error bubble with provider-specific error message.

---

## Out of Scope (for now)

- Streaming responses (both APIs support it but adds significant complexity)
- Model selection per provider (can be added later as a setting)
- Image/attachment support
- Conversation export/share
- Per-conversation titles (auto-generated from first message)
