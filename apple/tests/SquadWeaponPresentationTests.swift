import RealityKit
import Testing
import simd

@testable import Lauder

/// The visual weapon tip and shot origin must agree for all six of the party's weapons. These
/// value and geometry checks do not establish the sound or haptic feel of a physical device.
@MainActor
struct SquadWeaponPresentationTests {
  nonisolated static let partyKinds = PartyMember.allCases.flatMap {
    Weapon.pair(for: $0).map(\.kind)
  }

  @Test(arguments: partyKinds)
  func theRaisedGripAndPropTipMatchTheShotsMuzzle(kind: Weapon.Kind) {
    let profile = WeaponPose.profile(for: kind)
    let prop = SceneStyle().weapon(for: kind)
    let bounds = prop.visualBounds(relativeTo: prop)
    #expect(abs(bounds.min.z + profile.barrel) < 0.0001)

    var pose = WeaponPose(kind: kind)
    for _ in 0..<120 { pose.step(dt: 1 / 120, aiming: true) }
    #expect(simd_distance(pose.transform.position, profile.raisedGrip) < 0.0001)
    #expect(simd_distance(pose.transform.orientation.act([0, 0, -1]), [0, 0, -1]) < 0.0001)
    let facing = SIMD2<Float>(0, -1)
    let muzzle = WeaponPose.muzzle(from: [2, 3], facing: facing, kind: kind)
    #expect(
      simd_distance(muzzle, [2 + profile.raisedGrip.x, 3 + profile.raisedGrip.z - profile.barrel])
        < 0.0001)
  }

  @Test
  func aResetKeepsTheWeaponsOwnPoseAndRecoil() {
    func kick(_ kind: Weapon.Kind) -> Float {
      var pose = WeaponPose(kind: kind)
      pose.fired()
      return pose.transform.position.z - WeaponPose.profile(for: kind).raisedGrip.z
    }
    #expect(kick(.assaultRifle) < kick(.longRifle) && kick(.longRifle) < kick(.shotgun))

    for kind in Self.partyKinds {
      var pose = WeaponPose(kind: kind)
      pose.fired()
      pose.holster()
      #expect(pose.kind == kind && pose.raise == 0 && pose.kick == 0)
      #expect(
        simd_distance(pose.transform.position, WeaponPose.profile(for: kind).lowGrip) < 0.0001)
    }
  }

  /// Each gun's trigger break is bounded and distinct; the sword and the shield have none.
  @Test
  func theGunsTriggerBreaksAreBoundedAndDistinct() {
    let assault = CombatHaptics.triggerProfile(for: .assaultRifle)
    let long = CombatHaptics.triggerProfile(for: .longRifle)
    let shotgun = CombatHaptics.triggerProfile(for: .shotgun)
    #expect(assault.strength < long.strength && long.strength < shotgun.strength)
    #expect(assault.start < long.start && long.start < shotgun.start)
    for kind in Self.partyKinds where kind.shoots {
      let profile = CombatHaptics.triggerProfile(for: kind)
      #expect(profile.start >= 0 && profile.start < profile.end && profile.end <= 1)
      #expect(profile.strength > 0 && profile.strength <= 1)
    }
    #expect(CombatHaptics.triggerProfile(for: .energySword).strength == 0)
    #expect(CombatHaptics.triggerProfile(for: .shieldDome).strength == 0)
  }
}
