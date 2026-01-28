# SwiftMilkdown

A WYSIWYG Markdown editor for Swift/SwiftUI, powered by [Milkdown](https://milkdown.dev/).

## Features

- WYSIWYG Markdown editing (Typora-style)
- CommonMark + GFM support
- Emoji support (`:smile:`, `:rocket:`, etc.)
- Syntax highlighting for code blocks
- Dark/Light theme auto-detection
- Error handling with callbacks
- macOS and iOS support

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/LabeeHive/SwiftMilkdown", from: "1.1.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Usage

### Basic

```swift
import SwiftUI
import SwiftMilkdown

struct ContentView: View {
    @State private var markdown = ""

    var body: some View {
        MilkdownEditor(text: $markdown)
    }
}
```

### With Callbacks

```swift
MilkdownEditor(
    text: $markdown,
    onTextChange: { newText in
        print("Content changed: \(newText)")
    },
    onError: { error in
        switch error {
        case .resourceNotFound:
            print("Editor resources not found")
        case .loadFailed(let underlying):
            print("Failed to load: \(underlying)")
        case .contentUpdateFailed(let underlying):
            print("Failed to update content: \(underlying)")
        case .themeUpdateFailed(let underlying):
            print("Failed to update theme: \(underlying)")
        }
    }
)
```

### Error Types

| Error | Description |
|-------|-------------|
| `resourceNotFound` | Editor HTML resources not found in bundle |
| `loadFailed(underlying:)` | Failed to load the editor in WebView |
| `contentUpdateFailed(underlying:)` | Failed to update editor content |
| `themeUpdateFailed(underlying:)` | Failed to update editor theme |

## Development

### Prerequisites

- Node.js 20+
- pnpm 10+
- Xcode (for Swift)

### Setup

```bash
pnpm install
```

### Scripts

| Script | Description |
|--------|-------------|
| `pnpm run dev` | Start development server (http://localhost:3000) |
| `pnpm run build` | Build editor assets |
| `pnpm run test` | Run Swift tests |
| `pnpm run example` | Build and run Example app |
| `pnpm run example:build` | Build Example app only |
| `pnpm run typecheck` | Run TypeScript type check |
| `pnpm run clean` | Clean build artifacts |

### Example App

Run the example app to test the editor:

```bash
pnpm run example
```

This will build the editor and launch a macOS app with the MilkdownEditor component.

## Release

Releases are created manually via GitHub Actions workflow.

### Creating a Release

1. Go to the repository's **Actions** tab
2. Select the **Release** workflow
3. Click **Run workflow**
4. Enter the version number (e.g., `1.1.0`)
5. Click **Run workflow**

The CI will:
1. Build the editor assets (`pnpm install && pnpm build`)
2. Create a `releases/{version}` branch with built assets
3. Tag the release commit
4. Create a GitHub Release

### Version Format

- Use semantic versioning: `MAJOR.MINOR.PATCH` (e.g., `1.1.0`)

### Branch Structure

- `main`: Source code only (no built assets)
- `releases/{version}`: Contains built assets for each release

## Architecture

```
SwiftMilkdown/
├── Package.swift              # SPM manifest
├── package.json               # npm dependencies
├── src/                       # TypeScript source
│   ├── main.ts               # Milkdown editor setup
│   └── bridge.ts             # Swift ↔ JS communication
├── Sources/SwiftMilkdown/
│   ├── MilkdownEditor.swift  # SwiftUI component
│   └── Resources/Editor/     # Built web assets (generated)
├── Tests/SwiftMilkdownTests/ # Swift tests
├── Example/                   # Example macOS app
│   ├── Package.swift
│   └── Sources/ExampleApp/
└── .github/workflows/
    └── release.yml           # CI/CD pipeline
```

## License

MIT
