import type { Editor } from '@milkdown/core'
import { editorViewCtx, parserCtx } from '@milkdown/kit/core'
import { Slice } from '@milkdown/prose/model'

/**
 * Bridge for communication between JavaScript and Swift
 */
class SwiftBridge {
  private editor: Editor | null = null

  setEditor(editor: Editor) {
    this.editor = editor
  }

  /**
   * Send content changes to Swift
   */
  sendContent(markdown: string) {
    if (window.webkit?.messageHandlers?.editorBridge) {
      window.webkit.messageHandlers.editorBridge.postMessage({
        type: 'contentChanged',
        content: markdown
      })
    }
  }

  /**
   * Notify Swift that editor is ready
   */
  notifyReady() {
    if (window.webkit?.messageHandlers?.editorBridge) {
      window.webkit.messageHandlers.editorBridge.postMessage({
        type: 'editorReady'
      })
    }
  }

  /**
   * Set content from Swift
   * This will be called from Swift side
   */
  setContent(markdown: string) {
    if (!this.editor) {
      return
    }

    try {
      this.editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        const parser = ctx.get(parserCtx)
        const doc = parser(markdown)

        if (!doc) {
          return
        }

        const state = view.state
        const tr = state.tr.replace(
          0,
          state.doc.content.size,
          new Slice(doc.content, 0, 0)
        )
        view.dispatch(tr)
      })
    } catch (error) {
      console.error('Error setting content:', error)
    }
  }

  /**
   * Focus the editor
   */
  focus() {
    if (this.editor) {
      this.editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        view.focus()
      })
    }
  }

  /**
   * Set editor theme (dark or light)
   * Called from Swift when appearance changes
   */
  setTheme(theme: 'dark' | 'light') {
    document.body.setAttribute('data-theme', theme)
  }

  /**
   * Request Swift to open URL in default browser
   */
  openURL(url: string) {
    if (window.webkit?.messageHandlers?.editorBridge) {
      window.webkit.messageHandlers.editorBridge.postMessage({
        type: 'openURL',
        url: url
      })
    }
  }
}

// Global bridge instance
let bridgeInstance: SwiftBridge | null = null

export function setupBridge(): SwiftBridge {
  if (!bridgeInstance) {
    bridgeInstance = new SwiftBridge()

    // Expose to window for Swift to call
    ;(window as any).editorBridge = bridgeInstance
  }

  return bridgeInstance
}

// TypeScript declarations for WebKit
declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        editorBridge?: {
          postMessage: (message: any) => void
        }
      }
    }
  }
}
