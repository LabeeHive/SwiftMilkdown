//
//  PasteAsPlainTextWebView.swift
//  SwiftMilkdown
//

import WebKit

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#endif

/// A `WKWebView` subclass that intercepts the "paste as plain text" shortcut
/// (⌘⇧V) before it reaches the web content.
///
/// The shortcut is handled entirely natively: the pasteboard is read here,
/// outside the web content's event pipeline, so there's no need to race
/// ProseMirror's `handlePaste` plugin resolution order, and no dependency on
/// the web `Clipboard` API (`navigator.clipboard.readText()`), which requires
/// a full browser permission/focus context that a `WKWebView` embedded in a
/// native app does not reliably provide.
final class PasteAsPlainTextWebView: WKWebView {
  var pasteboard: PlainTextPasteboardProviding = SystemPlainTextPasteboard()
  var onPasteAsPlainText: ((String) -> Void)?

  #if os(macOS)
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
      if isPasteAsPlainTextShortcut(event) {
        if let text = pasteboard.plainText {
          onPasteAsPlainText?(text)
        }
        return true
      }
      return super.performKeyEquivalent(with: event)
    }

    private func isPasteAsPlainTextShortcut(_ event: NSEvent) -> Bool {
      let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      return modifiers == [.command, .shift]
        && event.charactersIgnoringModifiers?.lowercased() == "v"
    }
  #elseif os(iOS)
    override var keyCommands: [UIKeyCommand]? {
      let pasteAsPlainText = UIKeyCommand(
        input: "v",
        modifierFlags: [.command, .shift],
        action: #selector(handlePasteAsPlainTextKeyCommand)
      )
      return (super.keyCommands ?? []) + [pasteAsPlainText]
    }

    @objc private func handlePasteAsPlainTextKeyCommand() {
      if let text = pasteboard.plainText {
        onPasteAsPlainText?(text)
      }
    }
  #endif
}
