import XCTest

@testable import SwiftMilkdown

final class SwiftMilkdownTests: XCTestCase {
  func testEditorResourcesExist() throws {
    let htmlURL = Bundle.module.url(
      forResource: "index",
      withExtension: "html",
      subdirectory: "Editor"
    )
    XCTAssertNotNil(htmlURL, "Editor HTML should be bundled")
  }
}

// MARK: - MilkdownError Tests

final class MilkdownErrorTests: XCTestCase {

  func testResourceNotFoundError() {
    let error = MilkdownError.resourceNotFound

    // Verify it has no associated values
    let mirror = Mirror(reflecting: error)
    XCTAssertEqual(mirror.children.count, 0, "resourceNotFound should have no associated values")
  }

  func testLoadFailedError() {
    let underlyingError = NSError(domain: "TestDomain", code: 100, userInfo: nil)
    let error = MilkdownError.loadFailed(underlying: underlyingError)

    if case .loadFailed(let underlying) = error {
      XCTAssertEqual((underlying as NSError).code, 100)
      XCTAssertEqual((underlying as NSError).domain, "TestDomain")
    } else {
      XCTFail("Expected loadFailed error")
    }
  }

  func testContentUpdateFailedError() {
    let underlyingError = NSError(domain: "ContentDomain", code: 200, userInfo: nil)
    let error = MilkdownError.contentUpdateFailed(underlying: underlyingError)

    if case .contentUpdateFailed(let underlying) = error {
      XCTAssertEqual((underlying as NSError).code, 200)
      XCTAssertEqual((underlying as NSError).domain, "ContentDomain")
    } else {
      XCTFail("Expected contentUpdateFailed error")
    }
  }

  func testThemeUpdateFailedError() {
    let underlyingError = NSError(domain: "ThemeDomain", code: 300, userInfo: nil)
    let error = MilkdownError.themeUpdateFailed(underlying: underlyingError)

    if case .themeUpdateFailed(let underlying) = error {
      XCTAssertEqual((underlying as NSError).code, 300)
      XCTAssertEqual((underlying as NSError).domain, "ThemeDomain")
    } else {
      XCTFail("Expected themeUpdateFailed error")
    }
  }

  func testErrorIsSendable() {
    // Compile-time check: MilkdownError should be Sendable
    let error: any Sendable = MilkdownError.resourceNotFound
    XCTAssertNotNil(error)
  }
}
