//
//  PlainTextPasteboard.swift
//  SwiftMilkdown
//

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#endif

/// Reads plain text from a pasteboard. Abstracted so tests can inject an
/// isolated pasteboard instead of touching the real system clipboard.
protocol PlainTextPasteboardProviding {
  var plainText: String? { get }
}

/// Reads from the platform's default pasteboard (`NSPasteboard.general` on
/// macOS, `UIPasteboard.general` on iOS).
struct SystemPlainTextPasteboard: PlainTextPasteboardProviding {
  var plainText: String? {
    #if os(macOS)
      NSPasteboard.general.string(forType: .string)
    #elseif os(iOS)
      UIPasteboard.general.string
    #endif
  }
}

#if os(macOS)
  /// Reads from a private, named `NSPasteboard` instance rather than the
  /// system clipboard. Used in tests to exercise the paste-as-plain-text flow
  /// without touching (or depending on) the real system clipboard.
  struct NamedPasteboard: PlainTextPasteboardProviding {
    private let pasteboard: NSPasteboard

    init(name: NSPasteboard.Name) {
      self.pasteboard = NSPasteboard(name: name)
    }

    var plainText: String? {
      pasteboard.string(forType: .string)
    }
  }
#endif
