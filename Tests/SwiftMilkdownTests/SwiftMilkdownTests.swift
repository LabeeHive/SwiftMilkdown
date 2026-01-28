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
