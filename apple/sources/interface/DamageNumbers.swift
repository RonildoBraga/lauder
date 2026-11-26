import SwiftUI

/// Screen-sized labels above actual world impacts, independent of the camera's zoom. There
/// are no timers or asynchronous animations to outlive the world's pause/reset boundaries.
struct DamageNumbers: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let labels: [DamageFeedback.Label]
  let projection: CameraProjection

  var body: some View {
    GeometryReader { geometry in
      ForEach(labels) { label in
        if let point = projection.screen(ofWorld: label.position),
          (0...1).contains(point.x), (0...1).contains(point.y)
        {
          number(label)
            .position(
              x: CGFloat(point.x) * geometry.size.width + lane(for: label.attacker),
              y: CGFloat(point.y) * geometry.size.height - 20
                - (reduceMotion ? 0 : CGFloat(label.progress) * 60)
            )
            .opacity(Double(label.opacity))
        }
      }
    }
    .allowsHitTesting(false)
    // The shared enemy health display carries accessible progress; announcing each automatic
    // round would swamp VoiceOver and interrupt the controls.
    .accessibilityHidden(true)
  }

  private func number(_ label: DamageFeedback.Label) -> some View {
    let weak = label.effectiveness == .weakpoint
    return HStack(spacing: 2) {
      if weak {
        Image(systemName: label.brokeComponent ? "sparkle" : "scope")
          .font(.system(size: 11, weight: .bold))
      }
      Text("\(label.amount)")
        .font(.system(size: weak ? 18 : 16, weight: weak ? .heavy : .bold, design: .rounded))
        .monospacedDigit()
    }
    .foregroundStyle(weak ? Color(red: 0.95, green: 0.22, blue: 0.16) : .white)
    .shadow(color: .black.opacity(0.95), radius: 1, x: 1, y: 1)
    .shadow(color: .black.opacity(0.95), radius: 1, x: -1, y: -1)
  }

  private func lane(for member: PartyMember) -> CGFloat {
    switch member {
    case .miki: -30
    case .laura: 0
    case .tom: 30
    }
  }
}
