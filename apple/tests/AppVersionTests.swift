import Foundation
import Testing

@testable import Lauder

/// The version and build that the pause menu shows, as TestFlight lists them.
struct AppVersionTests {
  @Test
  func theVersionReadsAsTestFlightListsIt() {
    #expect(
      AppVersion.label(from: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "14"])
        == "0.1.0 (14)")
    #expect(AppVersion.label(from: nil) == "? (?)")
    // The app's own comes from its bundle, with both parts present.
    #expect(AppVersion.current.wholeMatch(of: /\d+\.\d+\.\d+ \(\d+\)/) != nil)
  }
}
