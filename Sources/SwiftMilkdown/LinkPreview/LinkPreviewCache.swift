//
//  LinkPreviewCache.swift
//  SwiftMilkdown
//
//  Two-layer cache for link preview data (NSCache + FileManager).
//

import CommonCrypto
import Foundation
import OSLog

/// Cache entry with expiration
private struct CacheEntry: Codable {
  let data: LinkPreviewData
  let expirationDate: Date
}

/// Two-layer cache for link preview data
/// - Layer 1: NSCache (in-memory, fast access)
/// - Layer 2: FileManager (disk, persistent)
public final class LinkPreviewCache: @unchecked Sendable {
  /// Shared instance
  public static let shared = LinkPreviewCache()

  /// Logger
  private static let logger = Logger(
    subsystem: Bundle.module.bundleIdentifier ?? "com.labeehive.SwiftMilkdown",
    category: "LinkPreviewCache"
  )

  /// In-memory cache
  private let memoryCache = NSCache<NSString, NSData>()

  /// Cache directory
  private let cacheDirectory: URL

  /// Default TTL (24 hours)
  public var defaultTTL: TimeInterval = 24 * 60 * 60

  /// Maximum memory cache entries
  public var maxMemoryCacheCount: Int {
    get { memoryCache.countLimit }
    set { memoryCache.countLimit = newValue }
  }

  private init() {
    // Setup cache directory
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    cacheDirectory = cacheDir.appendingPathComponent("SwiftMilkdown/LinkPreview", isDirectory: true)

    // Create directory if needed
    try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

    // Configure memory cache
    memoryCache.countLimit = 100
    memoryCache.totalCostLimit = 50 * 1024 * 1024  // 50MB
  }

  // MARK: - Public API

  /// Get cached preview data for URL
  /// - Parameter url: The URL to look up
  /// - Returns: Cached preview data if available and not expired
  public func get(for url: String) -> LinkPreviewData? {
    let key = cacheKey(for: url)

    // Try memory cache first
    if let data = memoryCache.object(forKey: key as NSString) {
      if let entry = decodeEntry(from: data as Data) {
        if entry.expirationDate > Date() {
          Self.logger.debug("Memory cache hit for: \(url)")
          return entry.data
        } else {
          // Expired, remove from memory
          memoryCache.removeObject(forKey: key as NSString)
        }
      }
    }

    // Try disk cache
    let fileURL = cacheFileURL(for: key)
    if let data = try? Data(contentsOf: fileURL),
      let entry = decodeEntry(from: data)
    {
      if entry.expirationDate > Date() {
        Self.logger.debug("Disk cache hit for: \(url)")
        // Promote to memory cache
        if let encodedData = encodeEntry(entry) {
          memoryCache.setObject(encodedData as NSData, forKey: key as NSString)
        }
        return entry.data
      } else {
        // Expired, remove from disk
        try? FileManager.default.removeItem(at: fileURL)
      }
    }

    Self.logger.debug("Cache miss for: \(url)")
    return nil
  }

  /// Store preview data in cache
  /// - Parameters:
  ///   - data: The preview data to cache
  ///   - url: The URL associated with this data
  ///   - ttl: Time-to-live (defaults to defaultTTL)
  public func set(_ data: LinkPreviewData, for url: String, ttl: TimeInterval? = nil) {
    let key = cacheKey(for: url)
    let expiration = Date().addingTimeInterval(ttl ?? defaultTTL)
    let entry = CacheEntry(data: data, expirationDate: expiration)

    guard let encodedData = encodeEntry(entry) else {
      Self.logger.error("Failed to encode cache entry for: \(url)")
      return
    }

    // Store in memory cache
    memoryCache.setObject(encodedData as NSData, forKey: key as NSString)

    // Store on disk
    let fileURL = cacheFileURL(for: key)
    do {
      try encodedData.write(to: fileURL)
      Self.logger.debug("Cached preview for: \(url)")
    } catch {
      Self.logger.error("Failed to write cache to disk: \(error.localizedDescription)")
    }
  }

  /// Remove cached data for URL
  /// - Parameter url: The URL to remove from cache
  public func remove(for url: String) {
    let key = cacheKey(for: url)
    memoryCache.removeObject(forKey: key as NSString)
    let fileURL = cacheFileURL(for: key)
    try? FileManager.default.removeItem(at: fileURL)
  }

  /// Clear all cached data
  public func clearAll() {
    memoryCache.removeAllObjects()
    try? FileManager.default.removeItem(at: cacheDirectory)
    try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    Self.logger.info("Cache cleared")
  }

  /// Remove expired entries from disk cache
  public func removeExpired() {
    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: cacheDirectory, includingPropertiesForKeys: nil)
    else { return }

    var removedCount = 0
    for fileURL in files {
      if let data = try? Data(contentsOf: fileURL),
        let entry = decodeEntry(from: data),
        entry.expirationDate <= Date()
      {
        try? FileManager.default.removeItem(at: fileURL)
        removedCount += 1
      }
    }

    if removedCount > 0 {
      Self.logger.info("Removed \(removedCount) expired cache entries")
    }
  }

  // MARK: - Private Helpers

  private func cacheKey(for url: String) -> String {
    // Use SHA256 hash for safe filename
    let data = Data(url.utf8)
    var hash = [UInt8](repeating: 0, count: 32)
    data.withUnsafeBytes { buffer in
      _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
    }
    return hash.map { String(format: "%02x", $0) }.joined()
  }

  private func cacheFileURL(for key: String) -> URL {
    cacheDirectory.appendingPathComponent(key)
  }

  private func encodeEntry(_ entry: CacheEntry) -> Data? {
    try? JSONEncoder().encode(entry)
  }

  private func decodeEntry(from data: Data) -> CacheEntry? {
    try? JSONDecoder().decode(CacheEntry.self, from: data)
  }
}
