//
//  LinkMarkInclusivityTests.swift
//  SwiftMilkdown
//
//  Regression tests for the link mark's `inclusive` schema setting.
//
//  ProseMirror mark schemas default `inclusive` to `true`, which means text
//  typed while the cursor sits at the right edge of a mark inherits that
//  mark. For a link, that means typing right after `[text](url)` silently
//  extends the link — the standard rich-text editor convention (see
//  prosemirror-example-setup's link schema) is to opt out of this via
//  `inclusive: false`. Milkdown core does not do this by default and does
//  not plan to (see https://github.com/Milkdown/milkdown/issues/1835), so
//  the app configures the schema itself in `src/main.ts`.
//
//  These tests load the real built bundle (Resources/Editor/index.js,
//  produced by `vite build` in the `pretest` step) into a headless WKWebView
//  and drive real DOM input paths (Selection API + `execCommand`) rather
//  than any Milkdown-internal API.
//

import WebKit
import XCTest

@testable import SwiftMilkdown

@MainActor
final class LinkMarkInclusivityTests: XCTestCase {

  /// Typing right after a link must not extend the link mark.
  ///
  /// Reproduction: load `[link](https://example.com)`, place the caret at
  /// the end of the link text via the DOM Selection API, then simulate real
  /// user typing with `execCommand('insertText')` (drives ProseMirror
  /// through its normal DOM-mutation observation path, not any
  /// Milkdown-internal API).
  func testTypingAfterLinkDoesNotInheritLinkMark() async throws {
    let harness = try LinkMarkHarness()
    try await harness.waitUntilReady()

    _ = try await harness.webView.evaluateJavaScript(
      "window.editorBridge.setContent('[link](https://example.com)'); true"
    )
    try await Task.sleep(nanoseconds: 500_000_000)

    let result =
      try await harness.webView.evaluateJavaScript(
        """
        (function() {
          const pm = document.querySelector('#editor .ProseMirror');
          if (!pm) return { ok: false, error: 'no ProseMirror dom root' };
          const link = pm.querySelector('a');
          if (!link) return { ok: false, error: 'no <a> found', html: pm.innerHTML };

          pm.focus();
          const range = document.createRange();
          range.selectNodeContents(link);
          range.collapse(false); // end of link text
          const sel = window.getSelection();
          sel.removeAllRanges();
          sel.addRange(range);

          const inserted = document.execCommand('insertText', false, ' X');
          return { ok: true, inserted: inserted, htmlAfter: pm.innerHTML };
        })()
        """
      ) as? [String: Any]

    XCTAssertEqual(
      result?["ok"] as? Bool, true, "probe setup failed: \(String(describing: result))")

    // Give the debounced markdownUpdated listener time to fire.
    try await Task.sleep(nanoseconds: 400_000_000)

    XCTAssertEqual(
      harness.recorder.lastContent,
      "[link](https://example.com) X\n",
      "the space/char typed right after a link must NOT be absorbed into the link mark "
        + "(link schema needs `inclusive: false`)"
    )
  }

  /// Editing *inside* a link must still be treated as part of the link.
  ///
  /// `inclusive: false` only affects the boundary right after the mark; it
  /// must not make the mark stop applying to text typed in the middle of the
  /// existing link range. This guards against an overly broad fix that
  /// disables link continuation entirely.
  func testTypingInsideLinkStillInheritsLinkMark() async throws {
    let harness = try LinkMarkHarness()
    try await harness.waitUntilReady()

    _ = try await harness.webView.evaluateJavaScript(
      "window.editorBridge.setContent('[link](https://example.com)'); true"
    )
    try await Task.sleep(nanoseconds: 500_000_000)

    let result =
      try await harness.webView.evaluateJavaScript(
        """
        (function() {
          const pm = document.querySelector('#editor .ProseMirror');
          if (!pm) return { ok: false, error: 'no ProseMirror dom root' };
          const link = pm.querySelector('a');
          if (!link) return { ok: false, error: 'no <a> found', html: pm.innerHTML };

          pm.focus();
          const textNode = link.firstChild;
          const range = document.createRange();
          // Place the caret between "li" and "nk" (inside the link text).
          range.setStart(textNode, 2);
          range.collapse(true);
          const sel = window.getSelection();
          sel.removeAllRanges();
          sel.addRange(range);

          const inserted = document.execCommand('insertText', false, 'X');
          return { ok: true, inserted: inserted, htmlAfter: pm.innerHTML };
        })()
        """
      ) as? [String: Any]

    XCTAssertEqual(
      result?["ok"] as? Bool, true, "probe setup failed: \(String(describing: result))")

    try await Task.sleep(nanoseconds: 400_000_000)

    XCTAssertEqual(
      harness.recorder.lastContent,
      "[liXnk](https://example.com)\n",
      "text typed inside an existing link must remain part of the link"
    )
  }
}

// MARK: - Shared harness

@MainActor
private final class LinkMarkHarness {
  let webView: WKWebView
  let recorder = LinkMarkRecorder()

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

private final class LinkMarkRecorder: NSObject, WKScriptMessageHandler {
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
