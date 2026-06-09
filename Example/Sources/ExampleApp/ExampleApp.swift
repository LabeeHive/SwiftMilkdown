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

  var body: some View {
    VStack(spacing: 0) {
      DebugMenuBar(
        themeMode: themeBinding,
        onCopyMarkdown: copyMarkdown,
        onResetContent: resetContent
      )
      MilkdownEditor(text: $markdown)
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

/// Debug menu header bar for the Example app.
struct DebugMenuBar: View {
  @Binding var themeMode: ThemeMode
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
