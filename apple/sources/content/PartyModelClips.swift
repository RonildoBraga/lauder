// Written from canonical Miki and blender/animations/party.blend by the Lauder Blender extension.
// Do not edit: change the saved Actions/calibration, then export the miki model.
// ./scripts/check verifies the source and export fingerprints.

import Foundation
import simd

enum PartyModelClips {
  enum Profile: String, CaseIterable {
    case party17
    case miki47
  }

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

  struct HandGrip {
    let offset: SIMD3<Float>
    let rotation: simd_quatf
  }

  static func profile(for jointNames: [String]) -> Profile? {
    let names = jointNames.map { String($0.split(separator: "/").last ?? "") }
    guard Set(names).count == names.count else { return nil }
    if Set(names)
      == Set([
        "ROOT", "chest", "foot_L", "foot_R",
        "forearm_L", "forearm_R", "hand_L", "hand_R",
        "head", "pelvis", "shin_L", "shin_R",
        "spine", "thigh_L", "thigh_R", "upper_arm_L",
        "upper_arm_R",
      ])
    {
      return .party17
    }
    if Set(names)
      == Set([
        "ROOT", "chest", "foot_L", "foot_R",
        "forearm_L", "forearm_R", "hand_L", "hand_R",
        "head", "index_01_L", "index_01_R", "index_02_L",
        "index_02_R", "index_03_L", "index_03_R", "middle_01_L",
        "middle_01_R", "middle_02_L", "middle_02_R", "middle_03_L",
        "middle_03_R", "pelvis", "pinky_01_L", "pinky_01_R",
        "pinky_02_L", "pinky_02_R", "pinky_03_L", "pinky_03_R",
        "ring_01_L", "ring_01_R", "ring_02_L", "ring_02_R",
        "ring_03_L", "ring_03_R", "shin_L", "shin_R",
        "spine", "thigh_L", "thigh_R", "thumb_01_L",
        "thumb_01_R", "thumb_02_L", "thumb_02_R", "thumb_03_L",
        "thumb_03_R", "upper_arm_L", "upper_arm_R",
      ])
    {
      return .miki47
    }
    return nil
  }

  static func take(for clip: Clip, profile: Profile = .party17) -> Take {
    switch profile {
    case .party17:
      switch clip {
      case .idle:
        Take(start: 0, end: 2, nominalSpeed: 0, loop: true, eventStart: 0)
      case .walk:
        Take(
          start: 2.008333333, end: 2.808333333, nominalSpeed: 1.012931034, loop: true, eventStart: 0
        )
      case .jog:
        Take(
          start: 2.816666667, end: 3.416666667, nominalSpeed: 2.133333333, loop: true, eventStart: 0
        )
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
          start: 8.433333333, end: 9.633333333, nominalSpeed: 0.428571429, loop: true, eventStart: 0
        )
      }
    case .miki47:
      switch clip {
      case .idle:
        Take(start: 0, end: 2, nominalSpeed: 0, loop: true, eventStart: 0)
      case .walk:
        Take(
          start: 2.008333333, end: 2.808333333, nominalSpeed: 1.012931034, loop: true, eventStart: 0
        )
      case .jog:
        Take(
          start: 2.816666667, end: 3.416666667, nominalSpeed: 2.133333333, loop: true, eventStart: 0
        )
      case .backward:
        Take(start: 3.425, end: 4.025, nominalSpeed: 2.133333333, loop: true, eventStart: 0)
      case .strafeLeft:
        Take(start: 4.033333333, end: 4.533333333, nominalSpeed: 1, loop: true, eventStart: 0)
      case .strafeRight:
        Take(start: 4.541666667, end: 5.041666667, nominalSpeed: 1, loop: true, eventStart: 0)
      case .aim:
        Take(start: 5.05, end: 5.8, nominalSpeed: 0, loop: true, eventStart: 0)
      case .fire:
        Take(start: 5.808333333, end: 6.308333333, nominalSpeed: 0, loop: false, eventStart: 0)
      case .hit:
        Take(start: 6.316666667, end: 6.916666667, nominalSpeed: 0, loop: false, eventStart: 0.08)
      case .run:
        Take(start: 6.925, end: 7.575, nominalSpeed: 2.710622711, loop: true, eventStart: 0)
      case .sneak:
        Take(
          start: 7.583333333, end: 8.783333333, nominalSpeed: 0.428571429, loop: true, eventStart: 0
        )
      }
    }
  }

  static func handGrip(left: Bool, profile: Profile) -> HandGrip? {
    guard profile == .miki47 else { return nil }
    if left {
      return HandGrip(
        offset: [-0.036350869, -0.086091958, -0.053390801],
        rotation: simd_quatf(real: 0.220333904, imag: [0.488252163, 0.738916993, -0.408735245]))
    } else {
      return HandGrip(
        offset: [0.08747521, 0.029452302, 0.030474424],
        rotation: simd_quatf(real: 0.410610616, imag: [-0.775962949, 0.313408107, -0.362016261]))
    }
  }

  static func garmentNames(profile: Profile) -> [String] {
    profile == .miki47 ? ["Skirt_front_L", "Skirt_front_R", "Skirt_back_L", "Skirt_back_R"] : []
  }
}
