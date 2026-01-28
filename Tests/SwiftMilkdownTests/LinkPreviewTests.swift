//
//  LinkPreviewTests.swift
//  SwiftMilkdown
//
//  Tests for link preview functionality.
//

import XCTest

@testable import SwiftMilkdown

// MARK: - LinkPreviewData Tests

final class LinkPreviewDataTests: XCTestCase {

  func testInitWithAllProperties() {
    let data = LinkPreviewData(
      url: "https://example.com",
      title: "Example Title",
      description: "Example Description",
      imageUrl: "https://example.com/image.png",
      iconUrl: "https://example.com/icon.png",
      siteName: "Example"
    )

    XCTAssertEqual(data.url, "https://example.com")
    XCTAssertEqual(data.title, "Example Title")
    XCTAssertEqual(data.description, "Example Description")
    XCTAssertEqual(data.imageUrl, "https://example.com/image.png")
    XCTAssertEqual(data.iconUrl, "https://example.com/icon.png")
    XCTAssertEqual(data.siteName, "Example")
  }

  func testInitWithMinimalProperties() {
    let data = LinkPreviewData(url: "https://example.com")

    XCTAssertEqual(data.url, "https://example.com")
    XCTAssertNil(data.title)
    XCTAssertNil(data.description)
    XCTAssertNil(data.imageUrl)
    XCTAssertNil(data.iconUrl)
    XCTAssertNil(data.siteName)
  }

  func testCodable() throws {
    let original = LinkPreviewData(
      url: "https://example.com",
      title: "Test",
      description: nil,
      imageUrl: "https://example.com/img.png",
      iconUrl: nil,
      siteName: "Test Site"
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LinkPreviewData.self, from: encoded)

    XCTAssertEqual(decoded.url, original.url)
    XCTAssertEqual(decoded.title, original.title)
    XCTAssertEqual(decoded.description, original.description)
    XCTAssertEqual(decoded.imageUrl, original.imageUrl)
    XCTAssertEqual(decoded.iconUrl, original.iconUrl)
    XCTAssertEqual(decoded.siteName, original.siteName)
  }

  func testIsSendable() {
    let data: any Sendable = LinkPreviewData(url: "https://example.com")
    XCTAssertNotNil(data)
  }
}

// MARK: - LinkPreviewError Tests

final class LinkPreviewErrorTests: XCTestCase {

  func testInvalidURLError() {
    let error = LinkPreviewError.invalidURL

    let mirror = Mirror(reflecting: error)
    XCTAssertEqual(mirror.children.count, 0, "invalidURL should have no associated values")
  }

  func testFetchFailedError() {
    let underlyingError = NSError(domain: "TestDomain", code: 500, userInfo: nil)
    let error = LinkPreviewError.fetchFailed(underlying: underlyingError)

    if case .fetchFailed(let underlying) = error {
      XCTAssertEqual((underlying as NSError).code, 500)
      XCTAssertEqual((underlying as NSError).domain, "TestDomain")
    } else {
      XCTFail("Expected fetchFailed error")
    }
  }

  func testNoMetadataError() {
    let error = LinkPreviewError.noMetadata

    let mirror = Mirror(reflecting: error)
    XCTAssertEqual(mirror.children.count, 0, "noMetadata should have no associated values")
  }

  func testErrorIsSendable() {
    let error: any Sendable = LinkPreviewError.invalidURL
    XCTAssertNotNil(error)
  }
}

// MARK: - LinkPreviewCache Tests

final class LinkPreviewCacheTests: XCTestCase {

  var cache: LinkPreviewCache!

  override func setUp() {
    super.setUp()
    cache = LinkPreviewCache.shared
    cache.clearAll()
  }

  override func tearDown() {
    cache.clearAll()
    super.tearDown()
  }

  func testSetAndGet() {
    let data = LinkPreviewData(
      url: "https://example.com",
      title: "Test Title"
    )

    cache.set(data, for: "https://example.com")
    let retrieved = cache.get(for: "https://example.com")

    XCTAssertNotNil(retrieved)
    XCTAssertEqual(retrieved?.url, data.url)
    XCTAssertEqual(retrieved?.title, data.title)
  }

  func testGetNonExistent() {
    let retrieved = cache.get(for: "https://nonexistent.com")
    XCTAssertNil(retrieved)
  }

  func testRemove() {
    let data = LinkPreviewData(url: "https://example.com")

    cache.set(data, for: "https://example.com")
    XCTAssertNotNil(cache.get(for: "https://example.com"))

    cache.remove(for: "https://example.com")
    XCTAssertNil(cache.get(for: "https://example.com"))
  }

  func testClearAll() {
    let data1 = LinkPreviewData(url: "https://example1.com")
    let data2 = LinkPreviewData(url: "https://example2.com")

    cache.set(data1, for: "https://example1.com")
    cache.set(data2, for: "https://example2.com")

    XCTAssertNotNil(cache.get(for: "https://example1.com"))
    XCTAssertNotNil(cache.get(for: "https://example2.com"))

    cache.clearAll()

    XCTAssertNil(cache.get(for: "https://example1.com"))
    XCTAssertNil(cache.get(for: "https://example2.com"))
  }

  func testExpiration() {
    let data = LinkPreviewData(url: "https://example.com")

    // Set with very short TTL
    cache.set(data, for: "https://example.com", ttl: 0.1)

    // Should exist immediately
    XCTAssertNotNil(cache.get(for: "https://example.com"))

    // Wait for expiration
    let expectation = XCTestExpectation(description: "Wait for expiration")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    // Should be expired now
    XCTAssertNil(cache.get(for: "https://example.com"))
  }

  func testDefaultTTL() {
    XCTAssertEqual(cache.defaultTTL, 24 * 60 * 60, "Default TTL should be 24 hours")
  }

  func testMaxMemoryCacheCount() {
    cache.maxMemoryCacheCount = 50
    XCTAssertEqual(cache.maxMemoryCacheCount, 50)
  }
}
