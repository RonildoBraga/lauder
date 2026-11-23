// Written from blender/animations/party.blend by the Lauder Blender extension.
// Do not edit it here: change the shared Actions, then export the miki model.
// ./scripts/check verifies the source and export fingerprints.

import Foundation

enum PartyModelClips {
  enum Clip: String, CaseIterable {
    case idle
    case walk
    case jog
    case backward
    case strafeLeft = "strafe_left"
    case strafeRight = "strafe_right"
    case aim
    case fire
    case hit
    case run
    case sneak
  }

  struct Take {
    let start: TimeInterval
    let end: TimeInterval
    let nominalSpeed: Float
    let loop: Bool
    let eventStart: TimeInterval

    var duration: TimeInterval { end - start }
  }

  static func take(for clip: Clip) -> Take {
    switch clip {
    case .idle:
      Take(start: 0, end: 2, nominalSpeed: 0, loop: true, eventStart: 0)
    case .walk:
      Take(
        start: 2.008333333, end: 2.808333333, nominalSpeed: 1.012931034, loop: true, eventStart: 0)
    case .jog:
      Take(
        start: 2.816666667, end: 3.416666667, nominalSpeed: 2.133333333, loop: true, eventStart: 0)
    case .backward:
      Take(start: 3.425, end: 4.025, nominalSpeed: 2.133333333, loop: true, eventStart: 0)
    case .strafeLeft:
      Take(start: 4.033333333, end: 4.533333333, nominalSpeed: 2, loop: true, eventStart: 0)
    case .strafeRight:
      Take(start: 4.541666667, end: 5.041666667, nominalSpeed: 2, loop: true, eventStart: 0)
    case .aim:
      Take(start: 5.05, end: 6.55, nominalSpeed: 0, loop: true, eventStart: 0)
    case .fire:
      Take(start: 6.558333333, end: 7.158333333, nominalSpeed: 0, loop: false, eventStart: 0.1)
    case .hit:
      Take(start: 7.166666667, end: 7.766666667, nominalSpeed: 0, loop: false, eventStart: 0.08)
    case .run:
      Take(start: 7.775, end: 8.425, nominalSpeed: 2.710622711, loop: true, eventStart: 0)
    case .sneak:
      Take(
        start: 8.433333333, end: 9.633333333, nominalSpeed: 0.428571429, loop: true, eventStart: 0)
    }
  }
}
