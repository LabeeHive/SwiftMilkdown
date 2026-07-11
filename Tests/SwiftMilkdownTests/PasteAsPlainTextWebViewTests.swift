//
//  PasteAsPlainTextWebViewTests.swift
//  SwiftMilkdown
//
//  End-to-end coverage for the "paste as plain text" flow on macOS: pressing
//  ⌘⇧V while the editor is focused reads plain text from the pasteboard
//  (never the HTML representation, even when one is present) and inserts it
//  into the document with no formatting.
//
//  Drives the real key-capture code path (`PasteAsPlainTextWebView.
//  performKeyEquivalent`) against a private, named `NSPasteboard` — never the
//  real system clipboard — and the real built editor bundle in a headless
//  `WKWebView`, observing the resulting `contentChanged` traffic exactly as
//  Swift would receive it.
//

#if os(macOS)

  import AppKit
  import WebKit
  import XCTest

  @testable import SwiftMilkdown

  @MainActor
  final class PasteAsPlainTextWebViewTests: XCTestCase {

    func testCommandShiftVReadsPlainTextFromPasteboardAndInsertsIt() async throws {
      let harness = try PasteAsPlainTextWebViewHarness()
      try await harness.waitUntilReady()

      harness.pasteboard.declareTypes([.string, .html], owner: nil)
      harness.pasteboard.setString("hello world", forType: .string)
      harness.pasteboard.setString("<b>hello world</b>", forType: .html)
      harness.webView.pasteboard = NamedPasteboard(name: harness.pasteboardName)

      let handled = harness.webView.performKeyEquivalent(with: .commandShiftV())
      XCTAssertTrue(handled, "⌘⇧V should be consumed by the plain-text paste shortcut")

      try await Task.sleep(nanoseconds: 400_000_000)

      XCTAssertEqual(
        harness.recorder.lastContent, "hello world\n",
        "text typed via ⌘⇧V must come from the pasteboard's plain-text representation, "
          + "not its HTML representation")
    }

    /// A key event that doesn't match the shortcut must fall through to the
    /// web content's own handling rather than being swallowed here.
    func testUnrelatedKeyEquivalentIsNotIntercepted() async throws {
      let harness = try PasteAsPlainTextWebViewHarness()
      try await harness.waitUntilReady()

      harness.webView.pasteboard = NamedPasteboard(name: harness.pasteboardName)

      let handled = harness.webView.performKeyEquivalent(with: .commandA())
      XCTAssertFalse(handled, "only ⌘⇧V should be intercepted by the plain-text paste shortcut")
    }

    /// Pasteboard text containing characters that are meaningful in a JS
    /// string literal (quotes, backslashes) must survive the Swift → JS
    /// bridge call intact, not corrupt the injected script.
    func testPasteboardTextWithQuotesAndBackslashesIsPreservedExactly() async throws {
      let harness = try PasteAsPlainTextWebViewHarness()
      try await harness.waitUntilReady()

      let tricky = #"She said "hi" \ then left"#
      harness.pasteboard.declareTypes([.string], owner: nil)
      harness.pasteboard.setString(tricky, forType: .string)
      harness.webView.pasteboard = NamedPasteboard(name: harness.pasteboardName)

      let handled = harness.webView.performKeyEquivalent(with: .commandShiftV())
      XCTAssertTrue(handled)

      try await Task.sleep(nanoseconds: 400_000_000)

      XCTAssertEqual(harness.recorder.lastContent, tricky + "\n")
    }
  }

  // MARK: - Shared harness

  @MainActor
  private final class PasteAsPlainTextWebViewHarness {
    let webView: PasteAsPlainTextWebView
    let recorder = PasteAsPlainTextWebViewRecorder()
    let pasteboardName = NSPasteboard.Name("dev.swiftmilkdown.tests.paste-as-plain-text")
    lazy var pasteboard = NSPasteboard(name: pasteboardName)

    init() throws {
      let config = WKWebViewConfiguration()
      config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
      config.userContentController.add(recorder, name: "editorBridge")
      webView = PasteAsPlainTextWebView(
        frame: .init(x: 0, y: 0, width: 800, height: 600), configuration: config)
      // Mirrors MilkdownEditor.Coordinator.pasteAsPlainText's JSON-encoding
      // approach exactly, so this harness exercises the same escaping the
      // production bridge call relies on.
      webView.onPasteAsPlainText = { [weak webView] text in
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["text": text]),
          let jsonString = String(data: jsonData, encoding: .utf8)
        else {
          return
        }
        webView?.evaluateJavaScript(
          "window.editorBridge?.pasteAsPlainText((\(jsonString)).text);")
      }

      guard
        let htmlURL = Bundle.module.url(
          forResource: "index", withExtension: "html", subdirectory: "Editor")
      else {
        throw XCTSkip("Editor HTML not found in bundle — run `vite build` first")
      }
      webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    func waitUntilReady(timeout: TimeInterval = 20) async throws {
      let start = Date()
      while !recorder.isReady {
        if Date().timeIntervalSince(start) > timeout {
          throw XCTSkip("editorReady never arrived — WKWebView may not run JS headless here")
        }
        try await Task.sleep(nanoseconds: 50_000_000)
      }
    }
  }

  private final class PasteAsPlainTextWebViewRecorder: NSObject, WKScriptMessageHandler {
    private(set) var isReady = false
    private(set) var lastContent: String?

    func userContentController(
      _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
      guard let body = message.body as? [String: Any], let type = body["type"] as? String else {
        return
      }
      if type == "editorReady" { isReady = true }
      if type == "contentChanged" { lastContent = body["content"] as? String }
    }
  }

  // MARK: - Synthetic key events

  extension NSEvent {
    fileprivate static func commandShiftV() -> NSEvent {
      keyEquivalent(characters: "v", modifierFlags: [.command, .shift], keyCode: 9)
    }

    fileprivate static func commandA() -> NSEvent {
      keyEquivalent(characters: "a", modifierFlags: [.command], keyCode: 0)
    }

    private static func keyEquivalent(
      characters: String, modifierFlags: NSEvent.ModifierFlags, keyCode: UInt16
    ) -> NSEvent {
      NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifierFlags,
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode
      )!
    }
  }

#endif
