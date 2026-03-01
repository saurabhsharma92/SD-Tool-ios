//
//  DocReaderView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import SwiftUI
import WebKit

struct DocReaderView: View {
    @StateObject private var viewModel: DocReaderViewModel
    @State private var webViewRef: WKWebView?
    private let scrollStore = ScrollPositionStore.self

    init(docId: String, displayName: String) {
        _viewModel = StateObject(wrappedValue: DocReaderViewModel(docId: docId, displayName: displayName))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let html = viewModel.htmlContent {
                WebViewRepresentable(
                    html: html,
                    docId: viewModel.docId,
                    webViewRef: $webViewRef,
                    scrollRestoreOffset: scrollStore.load(for: viewModel.docId),
                    onSaveScroll: { offset in scrollStore.save(offset: offset, for: viewModel.docId) }
                )
            } else {
                EmptyView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
        .onDisappear {
            if let wv = webViewRef {
                WebViewRepresentable.captureScrollPosition(from: wv, docId: viewModel.docId) { offset in
                    scrollStore.save(offset: offset, for: viewModel.docId)
                }
            }
        }
    }
}

// MARK: - WKWebView wrapper with scroll save/restore
private struct WebViewRepresentable: UIViewRepresentable {
    let html: String
    let docId: String
    @Binding var webViewRef: WKWebView?
    let scrollRestoreOffset: Double?
    let onSaveScroll: (Double) -> Void

    private static let scrollMessageHandlerName = "scrollPosition"

    func makeCoordinator() -> Coordinator {
        Coordinator(docId: docId, scrollRestoreOffset: scrollRestoreOffset, onSaveScroll: onSaveScroll)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: Self.scrollMessageHandlerName)
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor.systemBackground
        webViewRef = webView
        webView.loadHTMLString(html, baseURL: URL(string: "https://cdnjs.cloudflare.com/"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.saveCurrentScroll(from: uiView)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let docId: String
        let scrollRestoreOffset: Double?
        let onSaveScroll: (Double) -> Void
        private var lastScrollY: Double = 0

        init(docId: String, scrollRestoreOffset: Double?, onSaveScroll: @escaping (Double) -> Void) {
            self.docId = docId
            self.scrollRestoreOffset = scrollRestoreOffset
            self.onSaveScroll = onSaveScroll
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == WebViewRepresentable.scrollMessageHandlerName,
               let y = (message.body as? NSNumber)?.doubleValue, y >= 0 {
                lastScrollY = y
            }
        }

        func saveCurrentScroll(from webView: WKWebView) {
            let save = onSaveScroll
            let fallback = lastScrollY
            webView.evaluateJavaScript("window.scrollY") { result, _ in
                let y = (result as? NSNumber)?.doubleValue ?? fallback
                if y >= 0 {
                    DispatchQueue.main.async { save(y) }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Restore scroll after load (and after Mermaid if any)
            if let offset = scrollRestoreOffset, offset > 0 {
                let script = "window.scrollTo(0, \(offset));"
                webView.evaluateJavaScript(script) { _, _ in }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    webView.evaluateJavaScript(script) { _, _ in }
                }
            }
            // Inject scroll listener so we have lastScrollY when view is dismantled
            let handlerName = WebViewRepresentable.scrollMessageHandlerName
            let listener = """
            (function() {
                var ticking = false;
                window.addEventListener('scroll', function() {
                    if (!ticking) {
                        window.requestAnimationFrame(function() {
                            window.webkit.messageHandlers.\(handlerName).postMessage(window.scrollY);
                            ticking = false;
                        });
                        ticking = true;
                    }
                }, { passive: true });
            })();
            """
            webView.evaluateJavaScript(listener) { _, _ in }
        }
    }

    static func captureScrollPosition(from webView: WKWebView?, docId: String, save: @escaping (Double) -> Void) {
        guard let webView = webView else { return }
        webView.evaluateJavaScript("window.scrollY") { result, _ in
            if let y = (result as? NSNumber)?.doubleValue, y >= 0 {
                DispatchQueue.main.async { save(y) }
            }
        }
    }
}

