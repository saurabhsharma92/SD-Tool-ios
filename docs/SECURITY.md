# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not open a public issue**.

Instead, email the maintainer directly or open a [GitHub Security Advisory](https://github.com/saurabhsharma92/SD-Tool-ios/security/advisories/new).

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You will receive a response within 48 hours.

---

## Supported Versions

| Version | Supported |
|---|---|
| Latest `main` | ✅ |
| Older releases | ❌ |

---

## Key Security Controls

### Authentication
- Google Sign-In via Firebase Authentication
- Firebase ID tokens are managed by the SDK — never stored manually
- Auth state persisted securely by Firebase SDK

### Biometric Lock
- Uses `LAContext` with `.deviceOwnerAuthentication` policy
- Falls back to device passcode if Face ID/Touch ID unavailable
- Re-locks on every app background event

### App Check
- Enforced on Firebase AI API endpoint
- Simulator uses debug token (registered in Firebase Console)
- Physical devices use DeviceCheck provider automatically
- Prevents unauthorized use of Gemini API

### Network
- All requests use HTTPS — `NSAllowsArbitraryLoads` is NOT set
- GitHub content fetched from `raw.githubusercontent.com`
- Blog RSS feeds fetched with browser User-Agent header to avoid 403s

### Debug Code
- All debug bypass code (`debugBypass`, `forceUnlock`, `signInAnonymously`) is strictly inside `#if DEBUG`
- Release builds contain zero debug bypass logic

### Data Storage
- No financial, health, or highly sensitive data is stored
- Reading progress, liked posts, flash card progress stored in UserDefaults (non-encrypted, acceptable for this data type)
- No keychain usage (no credentials stored locally)

### Logging
- All `print()` debug statements wrapped in `#if DEBUG`
- No user PII (email, name) is logged
- No API keys or tokens are logged

---

## Credentials & Secrets

| Secret | How It's Protected |
|---|---|
| `GoogleService-Info.plist` | In `.gitignore`, never committed |
| Firebase API Key | Inside plist only, not in code |
| App Check debug token | Registered in Firebase Console only, not in source |
| GitHub PAT (if used) | Should be in environment variables, not in source |

### If a Key Is Compromised

1. Rotate immediately in Google Cloud Console → Credentials
2. Download new `GoogleService-Info.plist` from Firebase Console
3. Remove old file from git history:

```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch SDTool/SDTool/GoogleService-Info.plist" \
  --prune-empty --tag-name-filter cat -- --all
git push origin --force --all
```

4. Add API key restrictions in Google Cloud Console (bundle ID: `com.ss9.SDTool`)

---

## .gitignore Coverage

The following are in `.gitignore` and must never be committed:

```
GoogleService-Info.plist
google-services.json
*.env
Secrets.swift
APIKeys.swift
xcuserdata/
*.xcuserstate
DerivedData/
```

Verify nothing sensitive is tracked:
```bash
git ls-files | grep -E "plist|env|secret|key|token" | grep -v "Info.plist|Entitlements"
```
