//
//  LinkPreviewService.swift
//  SwiftMilkdown
//
//  Service for fetching link preview data using LPMetadataProvider.
//

import Foundation
import LinkPresentation
import OSLog

/// Errors that can occur during link preview fetching
public enum LinkPreviewError: Error, Sendable {
  case invalidURL
  case fetchFailed(underlying: Error)
  case noMetadata
}

/// Service for fetching link preview metadata
@MainActor
public final class LinkPreviewService {
  /// Shared instance
  public static let shared = LinkPreviewService()

  /// Logger
  private static let logger = Logger(
    subsystem: Bundle.module.bundleIdentifier ?? "com.labeehive.SwiftMilkdown",
    category: "LinkPreviewService"
  )

  /// Cache instance
  private let cache = LinkPreviewCache.shared

  private init() {}

  // MARK: - Public API

  /// Fetch link preview data for a URL
  /// - Parameters:
  ///   - urlString: The URL string to fetch preview for
  ///   - useCache: Whether to use cache (default: true)
  /// - Returns: Link preview data
  public func fetchPreview(for urlString: String, useCache: Bool = true) async throws
    -> LinkPreviewData
  {
    // Check cache first
    if useCache, let cached = cache.get(for: urlString) {
      Self.logger.debug("Using cached preview for: \(urlString)")
      return cached
    }

    // Validate URL
    guard let url = URL(string: urlString) else {
      throw LinkPreviewError.invalidURL
    }

    Self.logger.debug("Fetching preview for: \(urlString)")

    // Fetch metadata using LPMetadataProvider
    let provider = LPMetadataProvider()
    let metadata: LPLinkMetadata

    do {
      metadata = try await provider.startFetchingMetadata(for: url)
    } catch {
      Self.logger.error("Failed to fetch metadata: \(error.localizedDescription)")
      throw LinkPreviewError.fetchFailed(underlying: error)
    }

    // Extract preview data
    let previewData = LinkPreviewData(
      url: urlString,
      title: metadata.title,
      description: nil,  // LPLinkMetadata doesn't provide description directly
      imageUrl: await extractImageURL(from: metadata),
      iconUrl: await extractIconURL(from: metadata),
      siteName: extractSiteName(from: metadata)
    )

    // Cache the result
    if useCache {
      cache.set(previewData, for: urlString)
    }

    Self.logger.debug("Successfully fetched preview for: \(urlString)")
    return previewData
  }

  /// Fetch link preview with request ID for bridge communication
  /// - Parameters:
  ///   - urlString: The URL string to fetch preview for
  ///   - requestId: The request ID for matching response
  /// - Returns: Link preview response
  func fetchPreviewForBridge(urlString: String, requestId: String) async
    -> LinkPreviewResponse
  {
    do {
      let data = try await fetchPreview(for: urlString)
      return LinkPreviewResponse(requestId: requestId, data: data, error: nil)
    } catch {
      let errorMessage: String
      switch error {
      case LinkPreviewError.invalidURL:
        errorMessage = "Invalid URL"
      case LinkPreviewError.fetchFailed(let underlying):
        errorMessage = "Fetch failed: \(underlying.localizedDescription)"
      case LinkPreviewError.noMetadata:
        errorMessage = "No metadata available"
      default:
        errorMessage = error.localizedDescription
      }
      return LinkPreviewResponse(requestId: requestId, data: nil, error: errorMessage)
    }
  }

  // MARK: - Private Helpers

  private func extractImageURL(from metadata: LPLinkMetadata) async -> String? {
    guard let imageProvider = metadata.imageProvider else { return nil }
    return await extractDataURL(from: imageProvider)
  }

  private func extractIconURL(from metadata: LPLinkMetadata) async -> String? {
    guard let iconProvider = metadata.iconProvider else { return nil }
    return await extractDataURL(from: iconProvider)
  }

  private func extractDataURL(from provider: NSItemProvider) async -> String? {
    // Try to load as image data
    let imageTypes = ["public.png", "public.jpeg", "public.image"]

    for typeIdentifier in imageTypes {
      if provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
        if let dataURL = await loadImageData(from: provider, typeIdentifier: typeIdentifier) {
          return dataURL
        }
      }
    }
    return nil
  }

  private func loadImageData(from provider: NSItemProvider, typeIdentifier: String) async -> String?
  {
    return await withCheckedContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
        guard let data = data, error == nil else {
          continuation.resume(returning: nil)
          return
        }

        // Determine MIME type
        let mimeType: String
        if typeIdentifier.contains("png") {
          mimeType = "image/png"
        } else if typeIdentifier.contains("jpeg") {
          mimeType = "image/jpeg"
        } else {
          mimeType = "image/png"  // Default to PNG
        }

        // Convert to base64 data URL
        let base64 = data.base64EncodedString()
        let dataURL = "data:\(mimeType);base64,\(base64)"
        continuation.resume(returning: dataURL)
      }
    }
  }

  private func extractSiteName(from metadata: LPLinkMetadata) -> String? {
    // LPLinkMetadata doesn't have a direct siteName property
    // Try to extract from the URL host
    if let url = metadata.url ?? metadata.originalURL {
      return url.host
    }
    return nil
  }
}
