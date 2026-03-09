//
//  AIError.swift
//  SDTool
//
//  Covers every error scenario Firebase AI (Gemini) can return.
//  Each case has: user-friendly title, plain-English explanation,
//  SF Symbol icon, colour hint, and retryability flag.
//

import SwiftUI

// MARK: - Error cases

enum AIError: LocalizedError {

    // ── Network ───────────────────────────────────────────────
    case networkUnavailable

    // ── Auth / Config ─────────────────────────────────────────
    case unauthorized               // 401 — bad API key or App Check token
    case permissionDenied           // 403 — API not enabled, key restriction, billing
    case appCheckFailed             // 403 specific to App Check rejection

    // ── Quota / Rate ──────────────────────────────────────────
    case quotaExceeded(retryAfter: Int?)   // 429 daily cap
    case rateLimited(retryAfter: Int?)     // 429 per-minute RPM limit

    // ── Model / Request ───────────────────────────────────────
    case modelNotFound              // 404 — invalid model name
    case invalidRequest(String?)    // 400 — bad prompt or params
    case contextTooLong             // 400 specific — prompt exceeds token limit

    // ── Response ──────────────────────────────────────────────
    case emptyResponse              // 200 but no text
    case truncated                  // finish reason MAX_TOKENS
    case blockedBySafety            // finish reason SAFETY
    case blockedByCopyright         // finish reason RECITATION

    // ── Server ────────────────────────────────────────────────
    case serverError                // 500
    case serviceUnavailable         // 503

    // ── Content ───────────────────────────────────────────────
    case noContent                  // article/blog had no text to send

    // ── Fallback ──────────────────────────────────────────────
    case unknown(Error)

    // MARK: - User-facing title (short, shown prominently)

    var title: String {
        switch self {
        case .networkUnavailable:   return "No Internet"
        case .unauthorized:         return "Unauthorized"
        case .permissionDenied:     return "Access Denied"
        case .appCheckFailed:       return "Security Check Failed"
        case .quotaExceeded:        return "Daily Quota Reached"
        case .rateLimited:          return "Too Many Requests"
        case .modelNotFound:        return "Model Unavailable"
        case .invalidRequest:       return "Invalid Request"
        case .contextTooLong:       return "Article Too Long"
        case .emptyResponse:        return "Empty Response"
        case .truncated:            return "Response Truncated"
        case .blockedBySafety:      return "Content Blocked"
        case .blockedByCopyright:   return "Content Restricted"
        case .serverError:          return "Server Error"
        case .serviceUnavailable:   return "Service Unavailable"
        case .noContent:            return "No Content"
        case .unknown:              return "Something Went Wrong"
        }
    }

    // MARK: - User-facing explanation (plain English, one line)

    var explanation: String {
        switch self {
        case .networkUnavailable:
            return "You appear to be offline. Check your connection and try again."
        case .unauthorized:
            return "The AI service rejected the request. This is a configuration issue — please try reinstalling the app."
        case .permissionDenied:
            return "The AI API is not enabled for this project or the key has restrictions. Contact the app developer."
        case .appCheckFailed:
            return "App security verification failed. Try force-quitting and reopening the app."
        case .quotaExceeded(let s):
            let reset = s.map { _ in " The quota resets at midnight PT." } ?? " The quota resets at midnight PT."
            return "The project's daily AI request limit has been reached.\(reset)"
        case .rateLimited(let s):
            let wait = s.map { "Wait \($0) seconds before trying again." } ?? "Wait a moment before trying again."
            return "Too many requests were sent in a short period.\(wait)"
        case .modelNotFound:
            return "The selected AI model is not available. Try switching to a different model in Settings."
        case .invalidRequest(let detail):
            return detail ?? "The request was malformed. Try a different article or shorter content."
        case .contextTooLong:
            return "This article is too long for the AI to process in one go. Try the Summary mode instead."
        case .emptyResponse:
            return "The AI returned a blank response. This is usually temporary — try again."
        case .truncated:
            return "The response was cut off because it exceeded the length limit. The partial result is shown above."
        case .blockedBySafety:
            return "The AI declined to process this content due to its safety guidelines."
        case .blockedByCopyright:
            return "The AI declined to reproduce this content due to copyright restrictions."
        case .serverError:
            return "Google's AI server encountered an error. This is temporary — try again in a moment."
        case .serviceUnavailable:
            return "The AI service is temporarily unavailable. Try again in a few minutes."
        case .noContent:
            return "There's no text to summarise. The article may still be loading."
        case .unknown(let e):
            return e.localizedDescription
        }
    }

    // LocalizedError conformance — used as fallback
    var errorDescription: String? { explanation }

    // MARK: - SF Symbol icon

    var systemImage: String {
        switch self {
        case .networkUnavailable:           return "wifi.slash"
        case .unauthorized:                 return "key.slash"
        case .permissionDenied:             return "lock.slash"
        case .appCheckFailed:               return "shield.slash"
        case .quotaExceeded:                return "gauge.with.dots.needle.100percent"
        case .rateLimited:                  return "clock.badge.exclamationmark"
        case .modelNotFound:                return "cpu.fill"
        case .invalidRequest:               return "exclamationmark.bubble"
        case .contextTooLong:               return "text.badge.xmark"
        case .emptyResponse:                return "bubble.left.and.exclamationmark.bubble.right"
        case .truncated:                    return "scissors"
        case .blockedBySafety:              return "hand.raised.slash"
        case .blockedByCopyright:           return "c.circle"
        case .serverError:                  return "server.rack"
        case .serviceUnavailable:           return "antenna.radiowaves.left.and.right.slash"
        case .noContent:                    return "doc.badge.ellipsis"
        case .unknown:                      return "exclamationmark.triangle"
        }
    }

    // MARK: - Tint colour

    var color: Color {
        switch self {
        case .networkUnavailable:           return .gray
        case .unauthorized, .permissionDenied, .appCheckFailed:
                                            return .red
        case .quotaExceeded, .rateLimited:  return .orange
        case .modelNotFound, .invalidRequest, .contextTooLong:
                                            return .yellow
        case .emptyResponse, .truncated:    return .secondary
        case .blockedBySafety, .blockedByCopyright:
                                            return .purple
        case .serverError, .serviceUnavailable:
                                            return .orange
        case .noContent:                    return .secondary
        case .unknown:                      return .secondary
        }
    }

    // MARK: - Retryability

    var isRetryable: Bool {
        switch self {
        case .quotaExceeded:        return false   // daily cap — pointless to retry
        case .unauthorized:         return false   // config issue — retry won't help
        case .permissionDenied:     return false
        case .blockedBySafety:      return false
        case .blockedByCopyright:   return false
        case .noContent:            return false
        default:                    return true
        }
    }

    /// True for errors the user can resolve themselves (vs needing dev fix)
    var isUserResolvable: Bool {
        switch self {
        case .networkUnavailable, .rateLimited, .serviceUnavailable,
             .emptyResponse, .serverError:
            return true
        default:
            return false
        }
    }

    // MARK: - Parse from raw Error
    //
    // Firebase AI SDK wraps HTTP errors in GenerateContentError (their own type).
    // The localizedDescription becomes "The operation couldn't be completed.
    // (FirebaseAILogic.GenerateContentError error 0.)" — useless for matching.
    //
    // Strategy:
    //   1. Walk the NSError userInfo chain for the underlying HTTP response body
    //   2. Fall back to string matching on the full mirror dump of the error
    //   3. Check NSError code directly for known HTTP status codes

    static func from(_ error: Error) -> AIError {
        // Collect all text we can find about this error
        let nsErr    = error as NSError
        let raw      = "\(error)"
        let desc     = error.localizedDescription
        let combined = collectAllErrorText(nsErr).lowercased()

        // 1. Network offline
        if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorNotConnectedToInternet {
            return .networkUnavailable
        }
        if combined.contains("offline") || combined.contains("not connected to the internet") {
            return .networkUnavailable
        }

        // 2. Parse HTTP status code from NSError or underlying response text
        let httpCode = extractHTTPCode(from: nsErr, combined: combined)

        switch httpCode {
        case 401:
            return .unauthorized
        case 403:
            if combined.contains("app check") || combined.contains("appcheck") {
                return .appCheckFailed
            }
            return .permissionDenied
        case 404:
            return .modelNotFound
        case 429:
            // Distinguish daily quota cap from per-minute rate limit
            if combined.contains("per_day") || combined.contains("perday")
                || combined.contains("generaterequestsperday")
                || combined.contains("free_tier")
                || combined.contains("free tier") {
                return .quotaExceeded(retryAfter: parseRetryDelay(from: combined))
            }
            return .rateLimited(retryAfter: parseRetryDelay(from: combined))
        case 400:
            if combined.contains("token") && (combined.contains("limit") || combined.contains("exceed")) {
                return .contextTooLong
            }
            return .invalidRequest(nil)
        case 500:
            return .serverError
        case 503:
            return .serviceUnavailable
        default:
            break
        }

        // 3. String fallback for cases where HTTP code wasn't extracted
        if combined.contains("resource_exhausted") || combined.contains("quota exceeded")
            || combined.contains("quota_exceeded") {
            if combined.contains("per_day") || combined.contains("free_tier")
                || combined.contains("free tier") || combined.contains("generaterequestsperday") {
                return .quotaExceeded(retryAfter: parseRetryDelay(from: combined))
            }
            return .rateLimited(retryAfter: parseRetryDelay(from: combined))
        }
        if combined.contains("unauthenticated") { return .unauthorized }
        if combined.contains("permission_denied") { return .permissionDenied }
        if combined.contains("not_found") { return .modelNotFound }
        if combined.contains("safety") { return .blockedBySafety }
        if combined.contains("recitation") { return .blockedByCopyright }
        if combined.contains("max_tokens") || combined.contains("maxtokens") { return .truncated }

        // 4. Firebase AI GenerateContentError code 0 = unknown server-side error
        //    Check for this specific pattern from the screenshots
        if raw.contains("GenerateContentError") {
            // Try to get more info from underlying error
            if let underlying = nsErr.userInfo[NSUnderlyingErrorKey] as? NSError {
                return from(underlying)   // recurse with the real error
            }
            // Could be quota — if we saw any 429 hint in the response body
            if combined.contains("429") { return .quotaExceeded(retryAfter: nil) }
            return .serverError
        }

        return .unknown(error)
    }

    // MARK: - Helpers

    /// Recursively collects all text from an NSError including userInfo, underlying errors,
    /// and the response body that Firebase AI stores in userInfo["response"] or similar keys.
    private static func collectAllErrorText(_ nsErr: NSError) -> String {
        var parts: [String] = [
            "\(nsErr)",
            nsErr.localizedDescription,
            nsErr.domain,
            "\(nsErr.code)"
        ]

        // Walk all userInfo values recursively
        for (_, value) in nsErr.userInfo {
            if let nested = value as? NSError {
                parts.append(collectAllErrorText(nested))
            } else {
                parts.append("\(value)")
            }
        }

        return parts.joined(separator: " ")
    }

    /// Extracts HTTP status code from NSError userInfo or known Firebase error patterns
    private static func extractHTTPCode(from nsErr: NSError, combined: String) -> Int? {
        // Firebase AI stores the HTTP response in userInfo — look for status code number patterns
        // Pattern: "Status Code: 429" or "statusCode = 429" or just bare "429" near "http"
        let patterns = [
            #"status[\s_-]*code[\s:=]*([0-9]{3})"#,
            #"httpstatus[\s:=]*([0-9]{3})"#,
            #""code"\s*:\s*([0-9]{3})"#,   // JSON: "code": 429
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: combined, range: NSRange(combined.startIndex..., in: combined)),
               let range = Range(match.range(at: 1), in: combined),
               let code = Int(combined[range]) {
                return code
            }
        }

        // NSError code itself might be an HTTP code for URLSession errors
        if nsErr.domain == "com.google.HTTPStatus" || nsErr.domain.contains("HTTP") {
            return nsErr.code
        }

        return nil
    }

    private static func parseRetryDelay(from message: String) -> Int? {
        let pattern = #"retry[^0-9]*([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              let range = Range(match.range(at: 1), in: message) else { return nil }
        return Int(message[range])
    }
}
