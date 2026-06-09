import { $prose } from '@milkdown/kit/utils'
import { keymap } from '@milkdown/prose/keymap'
import { setBlockType } from '@milkdown/prose/commands'
import { headingSchema, paragraphSchema } from '@milkdown/kit/preset/commonmark'

// Milkdown's built-in DowngradeHeading lowers the heading level one step per Backspace
// (h3 → h2 → h1 → paragraph). Override so Backspace at the start of a heading
// converts directly to a paragraph, matching common WYSIWYG editor behavior.
// See https://github.com/Milkdown/milkdown/issues/1553
export const headingBackspacePlugin = $prose((ctx) => {
  return keymap({
    Backspace: (state, dispatch, view) => {
      const { $from, empty } = state.selection
      if (!empty || $from.parentOffset !== 0) return false
      if ($from.parent.type !== headingSchema.type(ctx)) return false
      return setBlockType(paragraphSchema.type(ctx))(state, dispatch, view)
    },
  })
})
