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
  @State private var markdown: String = demoMarkdown

  var body: some View {
    MilkdownEditor(text: $markdown)
      .frame(minWidth: 600, minHeight: 400)
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
