import Foundation

/// The app's version and build as TestFlight lists them, such as "0.1.0 (14)". The pause menu
/// shows it, so a tester can tell which build they are playing.
enum AppVersion {
  /// This app's version and build.
  static let current = label(from: Bundle.main.infoDictionary)

  /// The version and build in a bundle's information, such as "0.1.0 (14)"; a question mark
  /// stands for either one that is missing.
  static func label(from info: [String: Any]?) -> String {
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(version) (\(build))"
  }
}
