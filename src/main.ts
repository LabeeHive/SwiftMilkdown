import { defaultValueCtx, Editor, rootCtx } from '@milkdown/kit/core'
import { commonmark } from '@milkdown/kit/preset/commonmark'
import { gfm } from '@milkdown/kit/preset/gfm'
import { listener, listenerCtx } from '@milkdown/kit/plugin/listener'
import { history } from '@milkdown/kit/plugin/history'
import { clipboard } from '@milkdown/kit/plugin/clipboard'
import { trailing } from '@milkdown/kit/plugin/trailing'
import { listItemBlockComponent, listItemBlockConfig } from '@milkdown/kit/component/list-item-block'
import { emoji } from '@milkdown/plugin-emoji'
import { prism, prismConfig } from '@milkdown/plugin-prism'
import { nord } from '@milkdown/theme-nord'
import { setupBridge } from './bridge'

// Import Nord theme styles
import '@milkdown/theme-nord/style.css'

// Import Prism theme for syntax highlighting
import 'prism-themes/themes/prism-nord.css'

const defaultMarkdown = `# Heading 1 :tada:

## Heading 2

### Heading 3

#### Heading 4

This is a paragraph with **bold text**, *italic text*, and \`inline code\`. You can also add [links](https://example.com).

## Lists

### Bullet List

- First item
- Second item with a longer text to test line wrapping and vertical alignment
- Third item
  - Nested item 1
  - Nested item 2
    - Deeply nested item

### Numbered List

1. First numbered item
2. Second numbered item
3. Third item
   1. Nested numbered item
   2. Another nested item

### Task List :memo:

- [ ] :fire: High priority task
- [x] :tada: Completed task
- [ ] :bulb: Great idea to implement
- [ ] :rocket: Launch new feature
- [ ] :warning: Important reminder

## Emoji Examples

You can use emoji shortcodes like :smile:, :heart:, :star:, and :sparkles: in your text!

Popular task emojis: :white_check_mark: :x: :heavy_check_mark: :hourglass: :calendar:

## Code Blocks

### JavaScript

\`\`\`javascript
function greet(name) {
  console.log(\`Hello, \${name}!\`);
}
\`\`\`

### TypeScript

\`\`\`typescript
interface User {
  id: number;
  name: string;
  email?: string;
}

function getUser(id: number): Promise<User> {
  return fetch(\`/api/users/\${id}\`).then(res => res.json());
}
\`\`\`

### Swift

\`\`\`swift
struct Reminder: Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    mutating func toggle() {
        isCompleted.toggle()
    }
}
\`\`\`

### Python

\`\`\`python
def fibonacci(n: int) -> list[int]:
    """Generate Fibonacci sequence up to n terms."""
    if n <= 0:
        return []
    sequence = [0, 1]
    while len(sequence) < n:
        sequence.append(sequence[-1] + sequence[-2])
    return sequence[:n]
\`\`\`

### JSON

\`\`\`json
{
  "name": "vigilare",
  "version": "1.0.0",
  "dependencies": {
    "@milkdown/kit": "^7.17.1"
  }
}
\`\`\`

### Bash

\`\`\`bash
#!/bin/bash
echo "Building Vigilare..."
xcodebuild -project Vigilare.xcodeproj -scheme Vigilare build
\`\`\`

## Blockquote

> This is a blockquote.
> It can span multiple lines.

## Mixed Content

Here's a paragraph followed by a list:

- Item with **bold** and *italic*
- Item with \`code\` and [link](https://example.com)

And here's some more text after the list.
`

async function createEditor() {
  const editor = await Editor.make()
    .config((ctx) => {
      ctx.set(rootCtx, '#editor')
      ctx.set(defaultValueCtx, defaultMarkdown)

      // Listen to markdown changes
      ctx.get(listenerCtx).markdownUpdated((ctx, markdown) => {
        // Send changes to Swift
        setupBridge().sendContent(markdown)
      })

      // Customize list item markers for modern appearance
      ctx.update(listItemBlockConfig.key, (prev) => ({
        ...prev,
        renderLabel: ({ label, listType, checked }) => {
          // Task list items - use native HTML checkbox
          if (checked != null) {
            return `<input type="checkbox" ${checked ? 'checked' : ''} style="pointer-events: none;" />`
          }
          // Bullet list - use simple bullet instead of double circle
          if (listType === 'bullet') {
            return '•'
          }
          // Ordered list - use the label (number)
          return label
        }
      }))
    })
    .config(nord)
    .use(commonmark)
    .use(gfm)
    .use(listItemBlockComponent)
    .use(emoji)
    .use(prism)
    .use(trailing)
    .use(listener)
    .use(history)
    .use(clipboard)
    .create()

  return editor
}

// Initialize editor
createEditor().then((editor) => {
  // Setup Swift bridge
  const bridge = setupBridge()
  bridge.setEditor(editor)

  // Detect initial theme from system preference
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  bridge.setTheme(prefersDark ? 'dark' : 'light')

  // Notify Swift that editor is ready
  bridge.notifyReady()

  // Auto-focus the editor after initialization
  setTimeout(() => {
    bridge.focus()
  }, 100)

  // Click on empty space should focus the editor
  const editorContainer = document.getElementById('editor')
  if (editorContainer) {
    editorContainer.addEventListener('click', (e) => {
      const target = e.target as HTMLElement

      // Handle link clicks with Cmd modifier (macOS standard)
      if (target.tagName === 'A' && e.metaKey) {
        e.preventDefault()
        const href = target.getAttribute('href')
        if (href) {
          bridge.openURL(href)
        }
        return
      }

      // If clicked on the container itself (not the content), focus the editor
      if (target === editorContainer || target.classList.contains('milkdown-theme-nord')) {
        bridge.focus()
      }
    })
  }
})
