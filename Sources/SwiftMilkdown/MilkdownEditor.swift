//
//  MilkdownEditor.swift
//  SwiftMilkdown
//
//  A WYSIWYG Markdown editor powered by Milkdown, wrapped for SwiftUI.
//

import SwiftUI
import WebKit

#if os(macOS)
    public struct MilkdownEditor: NSViewRepresentable {
        @Binding var text: String
        @Environment(\.colorScheme) var colorScheme
        public var onTextChange: ((String) -> Void)?

        public init(text: Binding<String>, onTextChange: ((String) -> Void)? = nil) {
            self._text = text
            self.onTextChange = onTextChange
        }

        public func makeNSView(context: Context) -> WKWebView {
            createWebView(context: context)
        }

        public func updateNSView(_ nsView: WKWebView, context: Context) {
            updateWebView(nsView, context: context)
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
    }
#elseif os(iOS)
    public struct MilkdownEditor: UIViewRepresentable {
        @Binding var text: String
        @Environment(\.colorScheme) var colorScheme
        public var onTextChange: ((String) -> Void)?

        public init(text: Binding<String>, onTextChange: ((String) -> Void)? = nil) {
            self._text = text
            self.onTextChange = onTextChange
        }

        public func makeUIView(context: Context) -> WKWebView {
            createWebView(context: context)
        }

        public func updateUIView(_ uiView: WKWebView, context: Context) {
            updateWebView(uiView, context: context)
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
    }
#endif

// MARK: - Shared Implementation

extension MilkdownEditor {
    func createWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.userContentController.add(context.coordinator, name: "editorBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        #if os(macOS)
            webView.setValue(false, forKey: "drawsBackground")
        #elseif os(iOS)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
        #endif

        if let htmlURL = Bundle.module.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "Editor"
        ) {
            let resourceDir = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: resourceDir)
        } else {
            print("[SwiftMilkdown] Editor HTML not found in bundle")
        }

        return webView
    }

    func updateWebView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastSentText != text {
            context.coordinator.setContent(text)
        }

        if context.coordinator.lastColorScheme != colorScheme {
            context.coordinator.lastColorScheme = colorScheme
            context.coordinator.updateTheme(colorScheme)
        }
    }
}

// MARK: - Coordinator

extension MilkdownEditor {
    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: MilkdownEditor
        weak var webView: WKWebView?
        var isEditorReady = false
        var lastSentText = ""
        var lastColorScheme: ColorScheme?

        init(_ parent: MilkdownEditor) {
            self.parent = parent
        }

        // MARK: - WKNavigationDelegate

        public func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            print("[SwiftMilkdown] Failed to load: \(error.localizedDescription)")
        }

        public func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            print("[SwiftMilkdown] Failed provisional navigation: \(error.localizedDescription)")
        }

        // MARK: - WKScriptMessageHandler

        public func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "editorBridge",
                let body = message.body as? [String: Any],
                let type = body["type"] as? String
            else {
                return
            }

            switch type {
            case "editorReady":
                isEditorReady = true
                setContent(parent.text)
                updateTheme(parent.colorScheme)

            case "contentChanged":
                if let content = body["content"] as? String {
                    lastSentText = content
                    DispatchQueue.main.async {
                        self.parent.text = content
                        self.parent.onTextChange?(content)
                    }
                }

            case "openURL":
                if let urlString = body["url"] as? String,
                    let url = URL(string: urlString)
                {
                    #if os(macOS)
                        NSWorkspace.shared.open(url)
                    #elseif os(iOS)
                        UIApplication.shared.open(url)
                    #endif
                }

            default:
                break
            }
        }

        // MARK: - Content Management

        func setContent(_ markdown: String) {
            guard isEditorReady, let webView = webView else {
                return
            }

            lastSentText = markdown

            guard let jsonData = try? JSONSerialization.data(withJSONObject: ["content": markdown]),
                let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                return
            }

            let script = """
                try {
                  const data = \(jsonString);
                  window.editorBridge?.setContent(data.content);
                } catch (e) {
                  console.error('Error setting content:', e);
                }
                """

            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("[SwiftMilkdown] Failed to set content: \(error.localizedDescription)")
                }
            }
        }

        func updateTheme(_ colorScheme: ColorScheme) {
            guard isEditorReady, let webView = webView else {
                return
            }

            let theme = colorScheme == .dark ? "dark" : "light"

            let script = """
                try {
                  if (window.editorBridge?.setTheme) {
                    window.editorBridge.setTheme('\(theme)');
                  }
                } catch (e) {
                  console.error('Error setting theme:', e);
                }
                """

            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("[SwiftMilkdown] Failed to set theme: \(error.localizedDescription)")
                }
            }
        }
    }
}
