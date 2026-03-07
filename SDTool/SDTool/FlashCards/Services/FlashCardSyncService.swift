//
//  FlashCardSyncService.swift
//  SDTool
//

import Foundation

// MARK: - GitHub API response models

private struct GitHubFile: Decodable {
    let name: String    // "system-design.md"
    let sha:  String    // file content hash for change detection
    let type: String    // "file" or "dir"
}

// MARK: - Sync result

enum SyncResult {
    case upToDate                           // nothing changed
    case updated(newDecks: Int, updatedDecks: Int)
    case failed(Error)
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case noMarkdownFiles
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid GitHub URL."
        case .networkError(let e):  return e.localizedDescription
        case .noMarkdownFiles:      return "No flash card files found in repository."
        case .decodingError:        return "Failed to read repository data."
        }
    }
}

// MARK: - Service

actor FlashCardSyncService {
    static let shared = FlashCardSyncService()

    private let store    = FlashCardStore.shared
    private let progress = FlashCardProgress.shared

    // MARK: - Public

    /// Checks GitHub for new or updated .md files and downloads them.
    /// - Returns a SyncResult describing what changed.
    func sync() async -> SyncResult {
        // 1. Fetch file list from GitHub API
        let files: [GitHubFile]
        do {
            files = try await fetchFileList()
        } catch {
            return .failed(error)
        }

        // Filter to .md files only
        let mdFiles = files.filter {
            $0.type == "file" && $0.name.hasSuffix(".md")
        }

        guard !mdFiles.isEmpty else {
            return .failed(SyncError.noMarkdownFiles)
        }

        var newCount     = 0
        var updatedCount = 0

        // 2. For each file, check SHA and download if changed
        for file in mdFiles {
            let isNew     = store.deck(for: file.name) == nil
            let hasChanged = store.needsUpdate(filename: file.name, remoteSHA: file.sha)

            guard isNew || hasChanged else { continue }

            // 3. Download raw content
            do {
                let content = try await fetchRawContent(filename: file.name)
                let cards   = FlashCardParser.parse(content: content, filename: file.name)

                guard !cards.isEmpty else { continue }

                // 4. Build deck — preserve existing known progress automatically
                // (progress is keyed by stableKey which survives content updates)
                var deck = FlashDeck(
                    filename:     file.name,
                    cards:        cards,
                    lastSyncedAt: Date(),
                    remoteSHA:    file.sha,
                    isBundled:    false
                )

                // If we already have this deck (update, not new), copy its UUID
                // so progress keys stay valid
                if let existing = store.deck(for: file.name) {
                    deck.id = existing.id
                    updatedCount += 1
                } else {
                    newCount += 1
                }

                await MainActor.run {
                    store.upsert(deck: deck)
                    store.updateSHA(file.sha, for: file.name)
                }

            } catch {
                // Skip this file but continue with others
                continue
            }
        }

        if newCount == 0 && updatedCount == 0 {
            return .upToDate
        }
        return .updated(newDecks: newCount, updatedDecks: updatedCount)
    }

    // MARK: - Network

    private func fetchFileList() async throws -> [GitHubFile] {
        guard let url = URL(string: FlashCardConfig.apiURL) else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        // GitHub API requires a User-Agent header
        request.setValue("SDTool/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw SyncError.networkError(
                    NSError(domain: "HTTP", code: http.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
                )
            }
            guard let files = try? JSONDecoder().decode([GitHubFile].self, from: data) else {
                throw SyncError.decodingError
            }
            return files
        } catch let e as SyncError {
            throw e
        } catch {
            throw SyncError.networkError(error)
        }
    }

    private func fetchRawContent(filename: String) async throws -> String {
        let urlString = FlashCardConfig.rawURL(for: filename)
        guard let url = URL(string: urlString) else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("SDTool/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw SyncError.networkError(
                    NSError(domain: "HTTP", code: http.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
                )
            }
            guard let content = String(data: data, encoding: .utf8) else {
                throw SyncError.decodingError
            }
            return content
        } catch let e as SyncError {
            throw e
        } catch {
            throw SyncError.networkError(error)
        }
    }
}
