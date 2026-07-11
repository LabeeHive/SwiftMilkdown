import { defaultValueCtx, Editor, editorViewOptionsCtx, rootCtx, serializerCtx } from '@milkdown/kit/core'
import { commonmark, linkSchema } from '@milkdown/kit/preset/commonmark'
import { gfm } from '@milkdown/kit/preset/gfm'
import type { EditorView } from '@milkdown/prose/view'
import { history } from '@milkdown/kit/plugin/history'
import { clipboard } from '@milkdown/kit/plugin/clipboard'
import { trailing } from '@milkdown/kit/plugin/trailing'
import { listItemBlockComponent, listItemBlockConfig } from '@milkdown/kit/component/list-item-block'
import { emoji } from '@milkdown/plugin-emoji'
import { prism } from '@milkdown/plugin-prism'
import { nord } from '@milkdown/theme-nord'
import { setupBridge } from './bridge'
import { linkCardNode, linkCardPlugin } from './linkPreview'
import { headingBackspacePlugin } from './headingBackspace'
import { REMOTE_META_KEY } from './remoteTransaction'

// Import Nord theme styles
import '@milkdown/theme-nord/style.css'

// Import Prism theme for syntax highlighting
import 'prism-themes/themes/prism-nord.css'

// Import editor styles (tokens, reset, typography, components)
import './styles/index.css'

// Import link card styles
import './linkPreview/linkCard.css'

// Default content is empty - content will be set from Swift via bridge.setContent()
const defaultMarkdown = ''

async function createEditor() {
  // Last markdown value sent to Swift (or observed via a remote/programmatic
  // change). Tracked outside dispatchTransaction so a doc change that isn't
  // actually a value change (e.g. a link-card insertion) never re-sends, and
  // so a net-zero user edit (type then undo back to the same text) doesn't
  // wrongly appear as "changed" against a stale value.
  let lastBridgeMarkdown = defaultMarkdown

  const editor = await Editor.make()
    .config((ctx) => {
      ctx.set(rootCtx, '#editor')
      ctx.set(defaultValueCtx, defaultMarkdown)

      // Replaces the default dispatch behaviour entirely (ProseMirror calls
      // this instead of view.updateState(view.state.apply(tr)) when it's
      // set), so the default must be reproduced here explicitly.
      //
      // Only echo contentChanged to Swift for transactions that are both a
      // genuine document change AND not a programmatic/housekeeping change.
      // "Programmatic" is detected two ways:
      //  - Explicitly tagged REMOTE_META_KEY by applyRemote (setContent /
      //    scanAndInsertCards / handleLinkPreviewResponse).
      //  - addToHistory === false, ProseMirror's own convention for
      //    transactions that shouldn't create an undo step. This also
      //    catches Milkdown-internal housekeeping we don't control directly
      //    — e.g. preset-commonmark's syncHeadingIdPlugin re-dispatches its
      //    own addToHistory:false transaction reentrantly from a view.update
      //    hook whenever a heading's content changes, which would otherwise
      //    echo even for a purely remote setContent. If this stops working
      //    after a Milkdown upgrade, re-check for other plugins doing the
      //    same reentrant-dispatch pattern.
      // The markdown-equality check on top filters out changes that alter
      // the doc without altering its serialized value (e.g. inserting a
      // link-preview card).
      ctx.update(editorViewOptionsCtx, (prev) => ({
        ...prev,
        dispatchTransaction(this: EditorView, tr) {
          const view = this
          view.updateState(view.state.apply(tr))

          if (!tr.docChanged) return

          const isProgrammatic =
            tr.getMeta(REMOTE_META_KEY) === true || tr.getMeta('addToHistory') === false
          const markdown = ctx.get(serializerCtx)(view.state.doc)
          const changed = markdown !== lastBridgeMarkdown
          lastBridgeMarkdown = markdown

          if (!isProgrammatic && changed) {
            setupBridge().sendContent(markdown)
          }
        },
      }))

      // Link mark must not be inclusive: typing right after a link should
      // start plain text, not extend the link. This matches the standard
      // rich-text editor convention (see prosemirror-example-setup's link
      // schema) and is not addressed by Milkdown core (see
      // https://github.com/Milkdown/milkdown/issues/1835, closed as
      // "not planned" — app-level schema customization is the expected fix).
      ctx.update(linkSchema.key, (prev) => (c) => ({
        ...prev(c),
        inclusive: false,
      }))

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
    .use(headingBackspacePlugin)
    .use(commonmark)
    .use(gfm)
    .use(listItemBlockComponent)
    .use(emoji)
    .use(prism)
    .use(trailing)
    .use(history)
    .use(linkCardNode)
    .use(linkCardPlugin)
    .use(clipboard)
    .create()

  return editor
}

// Initialize editor
createEditor().then((editor) => {
  // Setup Swift bridge
  const bridge = setupBridge()
  bridge.setEditor(editor)
  bridge.enableLinkPreview()

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

      // Handle link card clicks - always open in browser
      const linkCard = target.closest('.link-card') as HTMLElement
      if (linkCard) {
        e.preventDefault()
        e.stopPropagation()
        const url = linkCard.getAttribute('data-url') || linkCard.getAttribute('href')
        if (url) {
          bridge.openURL(url)
        }
        return
      }

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
