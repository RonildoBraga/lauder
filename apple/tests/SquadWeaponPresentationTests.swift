import RealityKit
import Testing
import simd

@testable import Lauder

/// The visual weapon tip and shot origin must agree for all three weapons. These value and
/// geometry checks do not establish the sound or haptic feel of a physical device.
@MainActor
struct SquadWeaponPresentationTests {
  @Test(arguments: [Weapon.Kind.carbine, .lightBurst, .closeScatter])
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
    var burst = WeaponPose(kind: .lightBurst)
    var carbine = WeaponPose()
    var scatter = WeaponPose(kind: .closeScatter)
    burst.fired()
    carbine.fired()
    scatter.fired()
    let burstKick = burst.transform.position.z - WeaponPose.profile(for: .lightBurst).raisedGrip.z
    let carbineKick = carbine.transform.position.z - WeaponPose.raisedGrip.z
    let scatterKick =
      scatter.transform.position.z - WeaponPose.profile(for: .closeScatter).raisedGrip.z
    #expect(burstKick < carbineKick && carbineKick < scatterKick)

    for kind in [Weapon.Kind.carbine, .lightBurst, .closeScatter] {
      var pose = WeaponPose(kind: kind)
      pose.fired()
      pose.holster()
      #expect(pose.kind == kind && pose.raise == 0 && pose.kick == 0)
      #expect(
        simd_distance(pose.transform.position, WeaponPose.profile(for: kind).lowGrip) < 0.0001)
    }
  }

  @Test
  func theThreeTriggerBreaksAreBoundedAndDistinct() {
    let burst = CombatHaptics.triggerProfile(for: .lightBurst)
    let carbine = CombatHaptics.triggerProfile(for: .carbine)
    let scatter = CombatHaptics.triggerProfile(for: .closeScatter)
    #expect(burst.strength < carbine.strength && carbine.strength < scatter.strength)
    #expect(burst.start < carbine.start && carbine.start < scatter.start)
    for profile in [burst, carbine, scatter] {
      #expect(profile.start >= 0 && profile.start < profile.end && profile.end <= 1)
      #expect(profile.strength > 0 && profile.strength <= 1)
    }
  }
}
