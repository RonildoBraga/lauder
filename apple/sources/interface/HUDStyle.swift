import SwiftUI
import UIKit

/// The HUD's look in the frozen world (the visual direction): small, light frosted panels with
/// ink text and few lines, so the snow and the party stay the subject. The colours are the
/// palette's.
enum HUDStyle {
  /// The palette's ink, for words and outlines.
  static let ink = Color(red: 54 / 255, green: 65 / 255, blue: 75 / 255)
  /// Hints and other secondary words.
  static let muted = ink.opacity(0.7)
  /// Threats, in the palette's hostile red, dark enough to read on a frosted panel.
  static let threat = Color(red: 122 / 255, green: 46 / 255, blue: 42 / 255)
  /// Warnings, such as a companion who cannot find a way, in the palette's rust.
  static let warning = Color(red: 166 / 255, green: 90 / 255, blue: 67 / 255)
  /// The palette's snow, behind the scene.
  static let snow = Color(red: 236 / 255, green: 233 / 255, blue: 226 / 255)

  /// The ink for the touch controls, which UIKit draws.
  static let inkForTouch = UIColor(ink)
  /// The touch controls' frost: snow-tinted, translucent, and denser while pressed or chosen.
  static func frostForTouch(pressed: Bool) -> UIColor {
    UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: pressed ? 0.95 : 0.72)
  }
}

extension View {
  /// A light frosted panel with ink words and a faint ink outline.
  func frostedPanel(cornerRadius: CGFloat = 10) -> some View {
    foregroundStyle(HUDStyle.ink)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(HUDStyle.ink.opacity(0.12)))
      .environment(\.colorScheme, .light)
  }
}
