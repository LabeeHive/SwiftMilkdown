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

// Default content is empty - content will be set from Swift via bridge.setContent()
const defaultMarkdown = ''

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
