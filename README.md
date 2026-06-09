# SwiftMilkdown

A WYSIWYG Markdown editor for Swift/SwiftUI, powered by [Milkdown](https://milkdown.dev/).

## Features

- WYSIWYG Markdown editing (Typora-style)
- CommonMark + GFM support
- Link preview cards for pasted URLs (using LPMetadataProvider)
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
    .package(url: "https://github.com/LabeeHive/SwiftMilkdown", from: "1.2.0")
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

## Development

Requires Node.js 20+, pnpm 11+, and Xcode. Run `pnpm install` after cloning.

| Script | Description |
|--------|-------------|
| `pnpm dev` | Start Vite dev server and Example app in parallel (HMR enabled) |
| `pnpm preview` | Build editor assets and run Example app against the production bundle |
| `pnpm build` | Build editor assets into `Sources/SwiftMilkdown/Resources/Editor` |
| `pnpm test` | Run Swift tests |
| `pnpm typecheck` | Run TypeScript type check |
| `pnpm clean` | Clean build artifacts |

## Release

Releases are triggered manually via the [Release workflow](.github/workflows/release.yml): **Actions → Release → Run workflow**, then enter the version (`MAJOR.MINOR.PATCH`).

The workflow builds the editor assets, commits them to a `releases/{version}` branch, tags the commit, and creates a GitHub Release. The `main` branch contains source code only; consumers resolve the package against the release tags.

## License

MIT
