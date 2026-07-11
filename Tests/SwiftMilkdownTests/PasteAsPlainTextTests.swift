//
//  PasteAsPlainTextTests.swift
//  SwiftMilkdown
//
//  Regression tests for the editor bridge's plain-text paste entry point.
//
//  The actual pasteboard read and shortcut key capture (⌘⇧V) happen natively
//  on the Swift side (see `PasteAsPlainTextWebView`), outside the web
//  content's event pipeline — that flow is covered by
//  `PasteAsPlainTextWebViewTests`. These tests cover the JS-side half: once
//  Swift hands plain text to `window.editorBridge.pasteAsPlainText(text)`, it
//  must be inserted via ProseMirror's standard `pasteText` path, discarding
//  any formatting, without disturbing the default rich-HTML paste behaviour.
//

import WebKit
import XCTest

@testable import SwiftMilkdown

@MainActor
final class PasteAsPlainTextTests: XCTestCase {

  /// Baseline regression check: a normal paste with `text/html` content
  /// present is still inserted as rich HTML — the plain-text entry point must
  /// not affect default paste behaviour.
  func testNormalPasteStaysRich() async throws {
    let harness = try PasteAsPlainTextHarness()
    try await harness.waitUntilReady()

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
    XCTAssertEqual(richHTML, "<p><strong>hello world</strong></p>")
  }

  /// Text handed to `pasteAsPlainText` must be inserted verbatim, with no
  /// formatting — there is no HTML source at all in this path, since the
  /// text comes directly from the native pasteboard read.
  func testPasteAsPlainTextInsertsPlainText() async throws {
    let harness = try PasteAsPlainTextHarness()
    try await harness.waitUntilReady()

    _ = try await harness.webView.evaluateJavaScript(
      "window.editorBridge.setContent(''); true"
    )
    try await Task.sleep(nanoseconds: 200_000_000)

    _ = try await harness.webView.evaluateJavaScript(
      "window.editorBridge.pasteAsPlainText('hello world'); true"
    )
    try await Task.sleep(nanoseconds: 300_000_000)

    let plainHTML =
      try await harness.webView.evaluateJavaScript(
        "document.querySelector('#editor .ProseMirror')?.innerHTML || ''"
      ) as? String
    XCTAssertEqual(plainHTML, "<p>hello world</p>")
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
