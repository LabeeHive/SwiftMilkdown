import { $prose } from '@milkdown/kit/utils'
import { Plugin, PluginKey } from '@milkdown/prose/state'
import { editorViewCtx } from '@milkdown/kit/core'
import type { Ctx } from '@milkdown/kit/ctx'
import type { LinkPreviewResponse } from './types'
import { linkCardNodeId } from './linkCardNode'

/**
 * Plugin key for link card functionality
 */
export const linkCardPluginKey = new PluginKey('LINK_CARD_PLUGIN')

/**
 * URL regex pattern for detection
 */
const URL_REGEX = /^https?:\/\/[^\s<>\"{}|\\^`\[\]]+$/

/**
 * Pending preview requests
 */
const pendingRequests = new Map<string, { url: string }>()

/**
 * Generate unique request ID
 */
function generateRequestId(): string {
  return `lp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
}

/**
 * Check if text is a valid URL
 */
function isValidUrl(text: string): boolean {
  if (!URL_REGEX.test(text)) return false
  try {
    new URL(text)
    return true
  } catch {
    return false
  }
}

/**
 * Request link preview from Swift bridge
 */
function requestLinkPreview(requestId: string, url: string) {
  if (window.webkit?.messageHandlers?.editorBridge) {
    window.webkit.messageHandlers.editorBridge.postMessage({
      type: 'fetchLinkPreview',
      requestId,
      url,
    })
  }
}

/**
 * Link card plugin for Milkdown
 * Handles URL paste detection and preview fetching
 */
export const linkCardPlugin = $prose(() => {
  return new Plugin({
    key: linkCardPluginKey,
    props: {
      handlePaste: (view, event) => {
        const clipboardData = event.clipboardData
        if (!clipboardData) return false

        const text = clipboardData.getData('text/plain').trim()

        // Only handle if it's a standalone URL
        if (!isValidUrl(text)) return false

        // Check if we're at an empty paragraph (standalone URL line)
        const { $from, $to } = view.state.selection
        if ($from.pos !== $to.pos) return false

        // Check if current paragraph is empty
        const parentNode = $from.parent
        if (parentNode.type.name !== 'paragraph' || parentNode.content.size > 0) {
          return false
        }

        const linkCardType = view.state.schema.nodes[linkCardNodeId]
        const paragraphType = view.state.schema.nodes.paragraph
        const linkMark = view.state.schema.marks.link

        if (!linkCardType || !paragraphType || !linkMark) return false

        const requestId = generateRequestId()

        // Create URL paragraph with link mark
        const linkText = view.state.schema.text(text, [linkMark.create({ href: text })])
        const urlParagraph = paragraphType.create(null, linkText)

        // Create loading card
        const cardNode = linkCardType.create({
          url: text,
          loading: true,
        })

        // Replace current empty paragraph with URL paragraph + card
        const start = $from.before($from.depth)
        const end = $from.after($from.depth)
        const tr = view.state.tr.replaceWith(start, end, [urlParagraph, cardNode])
        view.dispatch(tr)

        // Store pending request
        pendingRequests.set(requestId, { url: text })

        // Request preview from Swift
        requestLinkPreview(requestId, text)

        return true
      },
    },
  })
})

/**
 * Handle link preview response from Swift
 * Called by bridge when preview data is received
 */
export function handleLinkPreviewResponse(ctx: Ctx, response: LinkPreviewResponse) {
  const pending = pendingRequests.get(response.requestId)
  if (!pending) return

  pendingRequests.delete(response.requestId)

  const view = ctx.get(editorViewCtx)
  if (!view) return

  const linkCardType = view.state.schema.nodes[linkCardNodeId]
  if (!linkCardType) return

  // Find the loading card node by URL
  let targetPos: number | null = null
  let targetNode: any = null

  view.state.doc.descendants((node, pos) => {
    if (
      node.type.name === linkCardNodeId &&
      node.attrs.loading === true &&
      node.attrs.url === pending.url
    ) {
      targetPos = pos
      targetNode = node
      return false
    }
    return true
  })

  if (targetPos === null || !targetNode) return

  // Update node with preview data or error state
  const attrs = response.data
    ? {
        url: response.data.url,
        title: response.data.title,
        description: response.data.description,
        imageUrl: response.data.imageUrl,
        iconUrl: response.data.iconUrl,
        siteName: response.data.siteName,
        loading: false,
      }
    : {
        ...targetNode.attrs,
        loading: false,
      }

  const newNode = linkCardType.create(attrs)
  const pos = targetPos as number
  const tr = view.state.tr.replaceWith(pos, pos + targetNode.nodeSize, newNode)
  view.dispatch(tr)
}

/**
 * Check if a paragraph contains only a standalone URL
 */
function isStandaloneUrlParagraph(node: any): string | null {
  if (node.type.name !== 'paragraph') return null
  if (node.content.childCount !== 1) return null

  const child = node.content.firstChild
  if (!child || !child.isText) return null

  const text = child.text?.trim()
  if (!text || !isValidUrl(text)) return null

  // Check if the text has a link mark
  const hasLinkMark = child.marks?.some((mark: any) => mark.type.name === 'link')
  if (!hasLinkMark) return null

  return text
}

/**
 * Scan document for standalone URL paragraphs and insert cards
 * Called after content is loaded to generate previews
 */
export function scanAndInsertCards(ctx: Ctx) {
  const view = ctx.get(editorViewCtx)
  if (!view) return

  const linkCardType = view.state.schema.nodes[linkCardNodeId]
  if (!linkCardType) return

  const urlsToProcess: Array<{ pos: number; url: string }> = []

  // Find all standalone URL paragraphs that don't have a card below
  view.state.doc.descendants((node, pos) => {
    const url = isStandaloneUrlParagraph(node)
    if (!url) return true

    // Check if there's already a card immediately after this paragraph
    const afterPos = pos + node.nodeSize
    const nodeAfter = view.state.doc.nodeAt(afterPos)
    if (nodeAfter?.type.name === linkCardNodeId && nodeAfter.attrs.url === url) {
      // Already has a card, skip
      return true
    }

    urlsToProcess.push({ pos: afterPos, url })
    return true
  })

  if (urlsToProcess.length === 0) return

  // Insert cards in reverse order to maintain positions
  let tr = view.state.tr
  for (let i = urlsToProcess.length - 1; i >= 0; i--) {
    const { pos, url } = urlsToProcess[i]
    const requestId = generateRequestId()

    const cardNode = linkCardType.create({
      url,
      loading: true,
    })

    tr = tr.insert(pos, cardNode)
    pendingRequests.set(requestId, { url })
    requestLinkPreview(requestId, url)
  }

  view.dispatch(tr)
}
