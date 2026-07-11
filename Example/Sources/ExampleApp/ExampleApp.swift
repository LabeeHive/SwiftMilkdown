import AppKit
import SwiftMilkdown
import SwiftUI

@main
struct ExampleApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Make this a regular app (shows in Dock, can receive focus)
    NSApplication.shared.setActivationPolicy(.regular)
    // Activate and bring to front, taking focus from terminal
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}

struct ContentView: View {
  @Environment(\.colorScheme) private var systemColorScheme
  @State private var markdown: String = demoMarkdown
  // nil until the user picks one explicitly — that way the initial value
  // follows the system appearance instead of being hardcoded.
  @State private var themeOverride: ThemeMode? = nil

  // On-screen log of onTextChange firings. Useful when touching anything
  // that might affect the setContent/echo contract: a genuine user edit
  // should always log an entry, while a programmatic content load (initial
  // load, "Reset to demo content") should never log one.
  @State private var changeLog: [String] = []
  @State private var isChangeLogVisible = false

  var body: some View {
    VStack(spacing: 0) {
      DebugMenuBar(
        themeMode: themeBinding,
        isChangeLogVisible: $isChangeLogVisible,
        onCopyMarkdown: copyMarkdown,
        onResetContent: resetContent
      )
      HStack(spacing: 0) {
        MilkdownEditor(
          text: $markdown,
          onTextChange: { _ in
            let timestamp = DateFormatter.localizedString(
              from: Date(), dateStyle: .none, timeStyle: .medium)
            changeLog.append("[\(timestamp)] onTextChange fired")
          }
        )
        if isChangeLogVisible {
          ChangeLogPanel(entries: changeLog, onClear: { changeLog.removeAll() })
            .frame(width: 260)
        }
      }
    }
    .frame(minWidth: 600, minHeight: 400)
    .preferredColorScheme(themeOverride?.colorScheme)
  }

  private func copyMarkdown() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(markdown, forType: .string)
  }

  private func resetContent() {
    markdown = demoMarkdown
  }

  /// Reflects the system scheme until the user picks something,
  /// then reflects the explicit choice.
  private var themeBinding: Binding<ThemeMode> {
    Binding(
      get: {
        themeOverride ?? (systemColorScheme == .dark ? .dark : .light)
      },
      set: { themeOverride = $0 }
    )
  }
}

/// Visible log of `onTextChange` firings, for manually verifying that
/// programmatic content loads don't spuriously echo as if the user had
/// edited the document.
struct ChangeLogPanel: View {
  let entries: [String]
  let onClear: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("onTextChange log")
          .font(.headline)
        Spacer()
        Button("Clear", action: onClear)
      }
      .padding(8)
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 4) {
          if entries.isEmpty {
            Text("(no events yet)")
              .foregroundStyle(.secondary)
              .font(.caption)
          }
          ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
            Text(entry)
              .font(.caption.monospaced())
          }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .background(.ultraThinMaterial)
  }
}

/// Debug menu header bar for the Example app.
struct DebugMenuBar: View {
  @Binding var themeMode: ThemeMode
  @Binding var isChangeLogVisible: Bool
  let onCopyMarkdown: () -> Void
  let onResetContent: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Spacer()
      Button {
        onResetContent()
      } label: {
        Image(systemName: "arrow.counterclockwise")
      }
      .help("Reset to demo content")

      Button {
        onCopyMarkdown()
      } label: {
        Image(systemName: "doc.on.doc")
      }
      .help("Copy markdown to clipboard")

      Toggle(isOn: $isChangeLogVisible) {
        Image(systemName: "text.append")
      }
      .toggleStyle(.button)
      .help("Show onTextChange log")

      Picker("Theme", selection: $themeMode) {
        ForEach(ThemeMode.allCases) { mode in
          Text(mode.label).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}

enum ThemeMode: String, CaseIterable, Identifiable {
  case light
  case dark

  var id: String { rawValue }

  var label: String {
    switch self {
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }

  var colorScheme: ColorScheme {
    switch self {
    case .light: return .light
    case .dark: return .dark
    }
  }
}

// MARK: - Demo Content

private let demoMarkdown = """
  # SwiftMilkdown Demo :tada:

  A WYSIWYG Markdown editor for Swift/SwiftUI.

  ## Features

  - **Bold**, *italic*, and `inline code`
  - [Links](https://github.com/LabeeHive/SwiftMilkdown)
  - Emoji support :smile: :rocket: :sparkles:

  ## Lists

  ### Bullet List

  - First item
  - Second item
    - Nested item

  ### Task List

  - [x] Completed task
  - [ ] Pending task

  ## Code Block

  ```swift
  struct ContentView: View {
      @State private var text = ""

      var body: some View {
          MilkdownEditor(text: $text)
      }
  }
  ```

  ## Blockquote

  > SwiftMilkdown brings the power of Milkdown to native Swift apps.

  ---

  ## Link Preview

  Try pasting a URL to see the link card preview feature!

  Example URLs to test:
  - https://labee.jp
  - https://github.com/nicholasareed/prosemirror-link-preview

  ---

  Edit this content to test the editor!
  """
