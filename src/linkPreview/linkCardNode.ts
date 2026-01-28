import { $node } from '@milkdown/kit/utils'

/**
 * Link card node ID
 */
export const linkCardNodeId = 'linkCard'

/**
 * Get hostname from URL safely
 */
function getHostname(url: string): string {
  try {
    return new URL(url).hostname
  } catch {
    return url
  }
}

/**
 * Link card node schema definition
 * Renders as a card with preview information
 */
export const linkCardNode = $node(linkCardNodeId, () => ({
  group: 'block',
  atom: true,
  isolating: true,
  marks: '',
  attrs: {
    url: { default: '' },
    title: { default: null },
    description: { default: null },
    imageUrl: { default: null },
    iconUrl: { default: null },
    siteName: { default: null },
    loading: { default: false },
  },
  parseDOM: [
    {
      tag: 'a[data-link-card]',
      getAttrs: (dom) => {
        const element = dom as HTMLElement
        return {
          url: element.getAttribute('data-url') || element.getAttribute('href') || '',
          title: element.getAttribute('data-title'),
          description: element.getAttribute('data-description'),
          imageUrl: element.getAttribute('data-image-url'),
          iconUrl: element.getAttribute('data-icon-url'),
          siteName: element.getAttribute('data-site-name'),
          loading: element.getAttribute('data-loading') === 'true',
        }
      },
    },
  ],
  toDOM: (node) => {
    const attrs = node.attrs
    const children: any[] = []

    // Card content
    const content: any[] = ['div', { class: 'link-card-content' }]

    // Image section (if available)
    if (attrs.imageUrl) {
      content.push(['div', { class: 'link-card-image' }, ['img', { src: attrs.imageUrl, alt: attrs.title || '' }]])
    }

    // Text section
    const textSection: any[] = ['div', { class: 'link-card-text' }]
    textSection.push(['div', { class: 'link-card-title' }, attrs.title || attrs.url])
    if (attrs.description) {
      textSection.push(['div', { class: 'link-card-description' }, attrs.description])
    }

    // Meta section
    const metaSection: any[] = ['div', { class: 'link-card-meta' }]
    if (attrs.iconUrl) {
      metaSection.push(['img', { src: attrs.iconUrl, class: 'link-card-favicon', alt: '' }])
    }
    metaSection.push(['span', { class: 'link-card-site' }, attrs.siteName || getHostname(attrs.url)])

    textSection.push(metaSection)
    content.push(textSection)
    children.push(content)

    // Loading overlay
    if (attrs.loading) {
      children.push(['div', { class: 'link-card-loading' }, 'Loading...'])
    }

    return [
      'a',
      {
        'data-link-card': 'true',
        'data-url': attrs.url,
        'data-title': attrs.title || '',
        'data-description': attrs.description || '',
        'data-image-url': attrs.imageUrl || '',
        'data-icon-url': attrs.iconUrl || '',
        'data-site-name': attrs.siteName || '',
        'data-loading': attrs.loading ? 'true' : 'false',
        class: 'link-card',
        href: attrs.url,
        target: '_blank',
        rel: 'noopener noreferrer',
      },
      ...children,
    ]
  },
  // No parseMarkdown - cards are generated from standalone URL paragraphs
  parseMarkdown: {
    match: () => false,
    runner: () => {},
  },
  // Don't serialize to markdown - URL paragraph above is the source of truth
  toMarkdown: {
    match: (node) => node.type.name === linkCardNodeId,
    runner: () => {
      // Intentionally empty - card is not saved to markdown
    },
  },
}))
