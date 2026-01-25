# SwiftMilkdown

A WYSIWYG Markdown editor for Swift/SwiftUI, powered by [Milkdown](https://milkdown.dev/).

## Features

- WYSIWYG Markdown editing (Typora-style)
- CommonMark + GFM support
- Emoji support (`:smile:`, `:rocket:`, etc.)
- Syntax highlighting for code blocks
- Dark/Light theme auto-detection
- macOS and iOS support

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/user/SwiftMilkdown", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Usage

```swift
import SwiftUI
import SwiftMilkdown

struct ContentView: View {
    @State private var notes: String = ""

    var body: some View {
        MilkdownEditor(text: $notes)
    }
}
```

With change callback:

```swift
MilkdownEditor(text: $notes) { newText in
    print("Content changed: \(newText)")
}
```

## Development

### Prerequisites

- Node.js 20+
- pnpm 10+

### Setup

```bash
pnpm install
```

### Build Editor

```bash
pnpm run build
```

This outputs the built editor to `Sources/SwiftMilkdown/Resources/Editor/`.

### Development Server

```bash
pnpm run dev
```

Open http://localhost:3000 to preview the editor.

### Verify Swift Package

```bash
swift build
swift test
```

## Release

Releases are created manually via GitHub Actions workflow.

### Creating a Release

1. Go to the repository's **Actions** tab
2. Select the **Release** workflow
3. Click **Run workflow**
4. Enter the version number (e.g., `1.0.0`)
5. Click **Run workflow**

The CI will:
1. Build the editor assets (`pnpm install && pnpm build`)
2. Create a `releases/{version}` branch with built assets
3. Tag the release commit
4. Create a GitHub Release

### Version Format

- Use semantic versioning: `MAJOR.MINOR.PATCH` (e.g., `1.0.0`)

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
└── .github/workflows/
    └── release.yml           # CI/CD pipeline
```

## License

MIT
