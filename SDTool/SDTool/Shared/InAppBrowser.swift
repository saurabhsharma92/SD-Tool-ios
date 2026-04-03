//
//  InAppBrowser.swift
//  SDTool
//
//  Provides SFSafariViewController as a SwiftUI sheet.
//  Usage: attach .inAppBrowser() once at a high level, then call
//  @Environment(\.openInAppBrowser) var openInAppBrowser
//  openInAppBrowser(url) from any child view.
//

import SwiftUI
import SafariServices

// MARK: - IdentifiableURL

struct IdentifiableURL: Identifiable {
    let id  = UUID()
    let url: URL
}

// MARK: - SafariView

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - Environment key

private struct OpenInAppBrowserKey: EnvironmentKey {
    // Default falls back to system browser so the app works without the modifier attached
    static let defaultValue: (URL) -> Void = { UIApplication.shared.open($0) }
}

extension EnvironmentValues {
    var openInAppBrowser: (URL) -> Void {
        get { self[OpenInAppBrowserKey.self] }
        set { self[OpenInAppBrowserKey.self] = newValue }
    }
}

// MARK: - View modifier

private struct InAppBrowserModifier: ViewModifier {
    @State private var browserURL: IdentifiableURL?

    func body(content: Content) -> some View {
        content
            .environment(\.openInAppBrowser) { url in
                browserURL = IdentifiableURL(url: url)
            }
            .sheet(item: $browserURL) { item in
                SafariView(url: item.url)
                    .ignoresSafeArea()
            }
    }
}

extension View {
    /// Attach once at a high level. All child views can then call
    /// `@Environment(\.openInAppBrowser) var openInAppBrowser` to open links in-app.
    func inAppBrowser() -> some View {
        modifier(InAppBrowserModifier())
    }
}
