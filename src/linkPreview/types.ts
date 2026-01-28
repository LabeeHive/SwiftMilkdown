/**
 * Link preview data structure
 */
export interface LinkPreviewData {
  url: string
  title: string | null
  description: string | null
  imageUrl: string | null
  iconUrl: string | null
  siteName: string | null
}

/**
 * Link preview request sent to Swift
 */
export interface LinkPreviewRequest {
  requestId: string
  url: string
}

/**
 * Link preview response from Swift
 */
export interface LinkPreviewResponse {
  requestId: string
  data: LinkPreviewData | null
  error: string | null
}
