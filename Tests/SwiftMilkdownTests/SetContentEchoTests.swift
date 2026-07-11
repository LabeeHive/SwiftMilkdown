//
//  SetContentEchoTests.swift
//  SwiftMilkdown
//
//  Regression tests for `setContent`'s echo behaviour: programmatic content
//  injection (setContent, and the delayed scanAndInsertCards link-card scan
//  it schedules) must not bounce a `contentChanged` echo back to Swift, since
//  the host interprets that as "notes changed" and triggers an auto-save even
//  though the user never edited anything. Genuine user edits — and undoing
//  them — must still echo normally.
//
//  These tests load the *real built bundle* (Resources/Editor/index.js, produced
//  by `vite build` in the `pretest` step) into a headless WKWebView and observe
//  the exact `contentChanged` traffic the Swift side would receive.
//

import WebKit
import XCTest

@testable import SwiftMilkdown

// MARK: - Harness

/// Captures the `editorBridge` message traffic emitted by the editor bundle.
private final class BridgeRecorder: NSObject, WKScriptMessageHandler {
  struct Change {
    let content: String
    let at: Date
  }

  private(set) var isReady = false
  private(set) var changes: [Change] = []

  func userContentController(
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
      isReady = true
    case "contentChanged":
      if let content = body["content"] as? String {
        changes.append(Change(content: content, at: Date()))
      }
    default:
      break
    }
  }

  func resetChanges() {
    changes.removeAll()
  }

  var contents: [String] { changes.map(\.content) }
  var lastContent: String? { changes.last?.content }
}

@MainActor
private final class EditorHarness {
  let webView: WKWebView
  let recorder = BridgeRecorder()

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

  /// Polls the run loop until the editor reports `editorReady`.
  func waitUntilReady(timeout: TimeInterval = 20) async throws {
    let start = Date()
    while !recorder.isReady {
      if Date().timeIntervalSince(start) > timeout {
        throw XCTSkip("editorReady never arrived — WKWebView may not run JS headless here")
      }
      try await Task.sleep(nanoseconds: 50_000_000)  // 50ms — yields to the WK callbacks
    }
  }

  /// Injects markdown exactly like `MilkdownEditor.Coordinator.setContent`, then
  /// waits `settle` so any delayed (`scanAndInsertCards`, 100ms) echo is captured.
  /// Returns every `contentChanged` observed during the window.
  @discardableResult
  func setContent(_ markdown: String, settle: TimeInterval = 0.7) async throws
    -> [BridgeRecorder.Change]
  {
    recorder.resetChanges()
    let data = try JSONSerialization.data(withJSONObject: ["content": markdown])
    let json = String(data: data, encoding: .utf8)!
    _ = try await webView.evaluateJavaScript(
      "window.editorBridge.setContent((\(json)).content); true")
    try await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
    return recorder.changes
  }
}

// MARK: - Smoke / diagnostics

@MainActor
final class SetContentSmokeTests: XCTestCase {
  func testBundleLayoutAndEditorBoots() async throws {
    // Diagnostic: confirm the bundle actually contains the built JS/CSS, not just HTML.
    let htmlURL = Bundle.module.url(
      forResource: "index", withExtension: "html", subdirectory: "Editor")
    XCTAssertNotNil(htmlURL, "index.html must be bundled")
    if let dir = htmlURL?.deletingLastPathComponent() {
      let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
      print("📦 Editor bundle dir: \(dir.path)")
      print("📦 Editor bundle files: \(files.sorted())")
      XCTAssertTrue(files.contains("index.js"), "Built index.js must be present (run vite build)")
    }

    let harness = try EditorHarness()
    try await harness.waitUntilReady()
    XCTAssertTrue(harness.recorder.isReady, "Editor should report editorReady")

    // Sanity: the bridge is reachable and content can be set.
    let changes = try await harness.setContent("# Hello\n\nWorld")
    print("🔁 first setContent produced \(changes.count) contentChanged event(s)")
    for (i, c) in changes.enumerated() {
      print(
        "   [\(i)] +\(String(format: "%.0f", c.at.timeIntervalSince(changes[0].at) * 1000))ms: \(c.content.debugDescription)"
      )
    }
  }
}

// MARK: - Echo reproduction

@MainActor
final class SetContentEchoTests: XCTestCase {

  /// Core fix requirement: `setContent` is a programmatic content injection,
  /// not a user edit. It must not bounce `contentChanged` back to Swift — that
  /// echo is what the host interprets as "notes changed → auto-save" on
  /// every open, even though the user never typed anything.
  func testSetContentDoesNotEcho() async throws {
    let harness = try EditorHarness()
    try await harness.waitUntilReady()

    let changes = try await harness.setContent("# Title\n\nSome body text.")

    XCTAssertTrue(
      changes.isEmpty,
      "setContent must not echo contentChanged — it is a remote content "
        + "injection, not a user edit: \(changes.map(\.content))")
  }

  /// Guard against over-suppression: a real user edit made *after* a
  /// `setContent` call must still echo normally. Only the programmatic
  /// injection itself should be silenced, not subsequent genuine edits.
  func testUserEditAfterSetContentIsEchoed() async throws {
    let harness = try EditorHarness()
    try await harness.waitUntilReady()

    _ = try await harness.setContent("Hello")
    harness.recorder.resetChanges()

    // Simulate real user typing via the DOM mutation path (execCommand),
    // not any Milkdown-internal API — same technique used elsewhere in this
    // test suite to drive genuine user-edit scenarios.
    _ = try await harness.webView.evaluateJavaScript(
      """
      (function() {
        const pm = document.querySelector('#editor .ProseMirror');
        pm.focus();
        const range = document.createRange();
        range.selectNodeContents(pm);
        range.collapse(false);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
        return document.execCommand('insertText', false, ' World');
      })()
      """
    )
    try await Task.sleep(nanoseconds: 400_000_000)

    XCTAssertFalse(
      harness.recorder.changes.isEmpty,
      "a real user edit after setContent must still echo contentChanged")
  }

  /// `scanAndInsertCards` (the delayed, ~100ms-later link-card scan triggered
  /// by `setContent`) is also a programmatic transaction, not a user edit —
  /// it must not echo either, even on its own delayed timer.
  func testScanAndInsertCardsDoesNotEcho() async throws {
    let harness = try EditorHarness()
    try await harness.waitUntilReady()

    let changes = try await harness.setContent("https://example.com", settle: 0.8)

    XCTAssertTrue(
      changes.isEmpty,
      "scanAndInsertCards must not echo contentChanged either: \(changes.map(\.content))")
  }

  /// Guard against over-suppression via the transaction-history changes: an
  /// undo of a genuine user edit must still echo normally. This exercises the
  /// interaction between the remote-content guard and ProseMirror's own undo
  /// history, which must not be swallowed by the fix.
  func testUndoAfterUserEditIsEchoed() async throws {
    let harness = try EditorHarness()
    try await harness.waitUntilReady()

    _ = try await harness.setContent("Hello")
    harness.recorder.resetChanges()

    _ = try await harness.webView.evaluateJavaScript(
      """
      (function() {
        const pm = document.querySelector('#editor .ProseMirror');
        pm.focus();
        const range = document.createRange();
        range.selectNodeContents(pm);
        range.collapse(false);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
        return document.execCommand('insertText', false, ' World');
      })()
      """
    )
    try await Task.sleep(nanoseconds: 400_000_000)
    harness.recorder.resetChanges()

    // Trigger ProseMirror's bound undo command (Mod-z) via a synthetic
    // keydown — this drives the keymap plugin's real handler, not any
    // Milkdown-internal undo API.
    _ = try await harness.webView.evaluateJavaScript(
      """
      (function() {
        const pm = document.querySelector('#editor .ProseMirror');
        const evt = new KeyboardEvent('keydown', {
          key: 'z', code: 'KeyZ', metaKey: true, bubbles: true, cancelable: true
        });
        return pm.dispatchEvent(evt);
      })()
      """
    )
    try await Task.sleep(nanoseconds: 400_000_000)

    XCTAssertFalse(
      harness.recorder.changes.isEmpty,
      "undoing a real user edit must still echo contentChanged")
  }
}
