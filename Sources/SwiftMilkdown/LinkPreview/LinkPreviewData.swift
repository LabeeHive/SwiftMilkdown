//
//  LinkPreviewData.swift
//  SwiftMilkdown
//
//  Data structures for link preview functionality.
//

import Foundation

/// Data representing a link preview
public struct LinkPreviewData: Codable, Sendable {
  /// The URL of the link
  public let url: String

  /// The title of the page
  public let title: String?

  /// The description/summary of the page
  public let description: String?

  /// URL of the preview image (og:image)
  public let imageUrl: String?

  /// URL of the site's favicon/icon
  public let iconUrl: String?

  /// Name of the website (og:site_name)
  public let siteName: String?

  public init(
    url: String,
    title: String? = nil,
    description: String? = nil,
    imageUrl: String? = nil,
    iconUrl: String? = nil,
    siteName: String? = nil
  ) {
    self.url = url
    self.title = title
    self.description = description
    self.imageUrl = imageUrl
    self.iconUrl = iconUrl
    self.siteName = siteName
  }
}

/// Response sent back to JavaScript
struct LinkPreviewResponse: Codable {
  let requestId: String
  let data: LinkPreviewData?
  let error: String?
}
