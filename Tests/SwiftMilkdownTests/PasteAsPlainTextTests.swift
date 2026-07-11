import WebKit
import XCTest

@testable import SwiftMilkdown

// MARK: - RED test for a pending feature
//
// "Paste as plain text": there is currently no way to force a plain-text
// paste — HTML clipboard content is always inserted as rich text. Driven
// purely from JS against a headless WKWebView loading the real built bundle
// (same harness pattern as SetContentEchoTests.swift) — no XCUITest / manual
// verification needed. This is intentionally RED: it asserts the
// implemented behaviour and currently fails against today's code. Flip it
// GREEN once the feature lands.

@MainActor
final class PasteAsPlainTextTests: XCTestCase {

  // MARK: paste as plain text

  /// RED until a "paste as plain text" entry point exists.
  ///
  /// Baseline confirmed working today: a synthetic `ClipboardEvent` with a
  /// `DataTransfer` carrying both `text/plain` and `text/html` reaches
  /// Milkdown's real `handlePaste` (dispatchEvent returns `false`, i.e.
  /// `preventDefault()`'d by the handler) and is inserted as rich HTML
  /// (`<strong>`). That baseline is asserted below and should stay GREEN.
  ///
  /// The still-missing behaviour: there is no way to force a plain-text
  /// paste. This test calls a not-yet-implemented bridge hook
  /// (`window.editorBridge.pasteAsPlainText`) as the assumed entry point —
  /// adjust the call site to match whatever API/shortcut the implementation
  /// actually lands on.
  func testPasteAsPlainTextStripsFormatting() async throws {
    let harness = try PasteAsPlainTextHarness()
    try await harness.waitUntilReady()

    // Baseline (should stay GREEN): normal paste stays rich.
    let richResult =
      try await harness.webView.evaluateJavaScript(
        """
        (function() {
          const dt = new DataTransfer();
          dt.setData('text/plain', 'hello world');
          dt.setData('text/html', '<b>hello world</b>');
          const evt = new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true });
          const target = document.querySelector('#editor .ProseMirror');
          const dispatched = target.dispatchEvent(evt);
          return { dispatched: dispatched };
        })()
        """
      ) as? [String: Any]
    XCTAssertEqual(
      richResult?["dispatched"] as? Bool, false, "handlePaste should consume the event")

    try await Task.sleep(nanoseconds: 300_000_000)
    let richHTML =
      try await harness.webView.evaluateJavaScript(
        "document.querySelector('#editor .ProseMirror')?.innerHTML || ''"
      ) as? String
    XCTAssertEqual(richHTML, "<p><strong>hello world</strong></p>", "baseline rich paste regressed")

    // RED: no plain-text paste entry point implemented yet.
    _ = try await harness.webView.evaluateJavaScript(
      "window.editorBridge.setContent(''); true"
    )
    try await Task.sleep(nanoseconds: 200_000_000)

    let plainResult =
      try await harness.webView.evaluateJavaScript(
        """
        (function() {
          if (typeof window.editorBridge.pasteAsPlainText !== 'function') {
            return { ok: false, error: 'pasteAsPlainText not implemented' };
          }
          const dt = new DataTransfer();
          dt.setData('text/plain', 'hello world');
          dt.setData('text/html', '<b>hello world</b>');
          window.editorBridge.pasteAsPlainText(dt);
          return { ok: true };
        })()
        """
      ) as? [String: Any]

    XCTAssertEqual(
      plainResult?["ok"] as? Bool, true,
      "paste-as-plain-text entry point is not implemented yet: \(String(describing: plainResult))"
    )

    try await Task.sleep(nanoseconds: 300_000_000)
    let plainHTML =
      try await harness.webView.evaluateJavaScript(
        "document.querySelector('#editor .ProseMirror')?.innerHTML || ''"
      ) as? String
    XCTAssertEqual(
      plainHTML, "<p>hello world</p>",
      "plain-text paste must strip HTML formatting")
  }
}

// MARK: - Shared harness

@MainActor
private final class PasteAsPlainTextHarness {
  let webView: WKWebView
  let recorder = PasteAsPlainTextRecorder()

  init() throws {
    let config = WKWebViewConfiguration()
    config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
    config.userContentController.add(recorder, name: "editorBridge")
    webView = WKWebView(frame: .init(x: 0, y: 0, width: 800, height: 600), configuration: config)

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

private final class PasteAsPlainTextRecorder: NSObject, WKScriptMessageHandler {
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
