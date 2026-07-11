import type { Transaction } from '@milkdown/prose/state'
import type { EditorView } from '@milkdown/prose/view'

/**
 * Transaction meta key marking a transaction as a programmatic (non-user)
 * content change — e.g. Swift pushing new content, or the editor inserting
 * link-preview cards after the fact. Transactions tagged this way must not
 * be echoed back to Swift as `contentChanged`, since nothing the user typed
 * produced them.
 */
export const REMOTE_META_KEY = 'remote'

/**
 * Dispatches a transaction as a remote/programmatic change: tagged so the
 * dispatchTransaction hook won't echo it back to Swift, and excluded from
 * the undo history (the user never made this edit, so undoing shouldn't
 * revert it).
 */
export function applyRemote(view: EditorView, tr: Transaction) {
  tr.setMeta(REMOTE_META_KEY, true)
  tr.setMeta('addToHistory', false)
  view.dispatch(tr)
}
