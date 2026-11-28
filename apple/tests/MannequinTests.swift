import RealityKit
import Testing
import UIKit
import simd

@testable import Lauder

@MainActor
struct MannequinTests {
  @Test func originalHierarchyAndNamedMeleeClipsArePackaged() {
    let library = MannequinLibrary.shared
    #expect(library.bones.count == 17)
    #expect(library.bones.first?.name == "ROOT")
    #expect(
      library.sourceSHA256 == "7abc47d922621f1685522083afee445927f3625f86b2c19eb7077f437703a4b8")
    #expect(library.clips["aim"] == nil && library.clips["fire"] == nil)
    for name in [
      "idle", "walk", "run", "backward", "strafe_left", "strafe_right", "slash", "sweep", "thrust",
      "guard", "dodge", "hit",
    ] {
      #expect(library.clips[name] != nil)
    }
    for (index, bone) in library.bones.enumerated() {
      #expect(bone.parent < index && bone.parent >= -1)
    }
  }

  @Test(arguments: [DuelAction.Kind.slash, .sweep, .thrust, .dodge])
  func actionClockOwnsPoseAndDuration(kind: DuelAction.Kind) throws {
    let mannequin = Mannequin(name: "clock", color: .gray)
    var fighter = fighter()
    var action = DuelAction(kind: kind, direction: [0, -1])
    action.elapsed = action.duration * 0.43
    fighter.action = action
    mannequin.pose(fighter: fighter, deltaTime: 0)
    let before = boneTransforms(mannequin)
    mannequin.pose(fighter: fighter, deltaTime: 0.25)
    #expect(boneTransforms(mannequin) == before, "presentation cannot advance an action clock")
    let clip = try #require(MannequinLibrary.shared.clips[mannequin.selectedClip])
    let phases = try #require(clip.phases)
    #expect(phases.windup == 0 && phases.windup < phases.active)
    #expect(phases.active < phases.recovery && phases.recovery < phases.end)
    #expect(phases.end == clip.duration)
  }

  @Test(arguments: ["slash", "sweep", "thrust", "dodge"])
  func phaseBoundariesAndRetimedPreparationUseAuthoredContactMarkers(name: String) throws {
    let library = MannequinLibrary.shared
    let markers = try #require(library.clips[name]?.phases)
    #expect(library.actionTime(name, phase: .windup, progress: 0) == markers.windup)
    #expect(library.actionTime(name, phase: .windup, progress: 1) == markers.active)
    #expect(library.actionTime(name, phase: .active, progress: 0) == markers.active)
    #expect(library.actionTime(name, phase: .active, progress: 1) == markers.recovery)
    #expect(library.actionTime(name, phase: .recovery, progress: 0) == markers.recovery)
    #expect(library.actionTime(name, phase: .recovery, progress: 1) == markers.end)
    // Equal-total schedules deliberately put the same elapsed time in different phases.
    let original = (windup: Float(0.19), active: Float(0.16), recovery: Float(0.32))
    let retimed = (windup: Float(0.35), active: Float(0.16), recovery: Float(0.16))
    func mapped(_ schedule: (windup: Float, active: Float, recovery: Float), at elapsed: Float)
      -> Float
    {
      let phase: DuelAction.Phase
      let progress: Float
      if elapsed < schedule.windup {
        phase = .windup
        progress = elapsed / schedule.windup
      } else if elapsed < schedule.windup + schedule.active {
        phase = .active
        progress = (elapsed - schedule.windup) / schedule.active
      } else {
        phase = .recovery
        progress = (elapsed - schedule.windup - schedule.active) / schedule.recovery
      }
      return library.actionTime(name, phase: phase, progress: progress)
    }
    #expect(
      abs(
        original.windup + original.active + original.recovery - retimed.windup - retimed.active
          - retimed.recovery) < 0.00001)
    let firstContact = mapped(original, at: original.windup)
    let laterContact = mapped(retimed, at: retimed.windup)
    #expect(firstContact == markers.active && laterContact == markers.active)
    #expect(library.sample(name, time: firstContact) == library.sample(name, time: laterContact))
    #expect(abs(mapped(original, at: 0.30) - mapped(retimed, at: 0.30)) > 0.01)

  }

  @Test(arguments: [DuelAction.Kind.slash, .sweep, .thrust])
  func fixedAuthoritativeHiltIsReachableThroughoutAction(kind: DuelAction.Kind) {
    let mannequin = Mannequin(name: "grip", color: .gray)
    var fighter = fighter()
    let duration = DuelAction(kind: kind, direction: [0, -1]).duration
    for index in 0...240 {
      var action = DuelAction(kind: kind, direction: [0, -1])
      action.elapsed = duration * Float(index) / 240
      fighter.action = action
      let target = grip(action)
      mannequin.pose(fighter: fighter, deltaTime: 0, rightHand: target)
      #expect(mannequin.rightGripGap < 0.001, "natural arm reach at \(kind) sample \(index)")
      #expect(
        simd_distance(mannequin.rightHand.position(relativeTo: mannequin.root), target) < 0.001)
    }
  }

  @Test(arguments: [SIMD2<Float>(0, -1), [0, 1], [-1, 0], [1, 0]])
  func guardBraceFitsShieldWhileLegsFollowResolvedTravel(direction: SIMD2<Float>) {
    let mannequin = Mannequin(name: "guard", color: .gray)
    var fighter = fighter()
    fighter.guarding = true
    mannequin.pose(fighter: fighter, deltaTime: 0)
    let target = SIMD3<Float>(-0.18, 1.05, -0.44)
    for _ in 0..<180 {
      fighter.position += direction * (1.12 / 120)
      mannequin.pose(
        fighter: fighter, deltaTime: 1 / 120, rightHand: [0, 1.08, -0.27], leftHand: target)
      #expect(mannequin.leftGripGap < 0.001)
      #expect(
        simd_distance(mannequin.leftHand.position(relativeTo: mannequin.root), target) < 0.001)
    }
  }

  @Test func hitRecoilCanAppearDuringOwedRecoveryWithoutAdvancingTheAttack() throws {
    let mannequin = Mannequin(name: "recoil", color: .gray)
    var fighter = fighter()
    var action = DuelAction(kind: .sweep, direction: [0, -1])
    action.elapsed = action.profile.windup + action.profile.active + 0.2
    fighter.action = action
    let target = grip(action)
    mannequin.pose(fighter: fighter, deltaTime: 0, rightHand: target)
    let torso = try #require(mannequin.root.findEntity(named: "recoil.bone.spine"))
    let before = torso.orientation
    fighter.hitFlash = 0.10
    mannequin.pose(fighter: fighter, deltaTime: 0, rightHand: target)
    #expect(abs(simd_dot(before.vector, torso.orientation.vector)) < 0.99999)
    #expect(fighter.action == action)
    #expect(mannequin.selectedClip == "sweep")
    #expect(mannequin.rightGripGap < 0.001)
    #expect(simd_distance(mannequin.rightHand.position(relativeTo: mannequin.root), target) < 0.001)
  }

  @Test func interpolatedFootBoxesStayAboveTheFlatFloor() {
    let library = MannequinLibrary.shared
    for (name, clip) in library.clips {
      for step in 0...120 {
        var pose = library.world(library.sample(name, time: clip.duration * Float(step) / 120))
        let lift = library.ground(&pose)
        #expect(lift < 0.015, "bounded flat-ground correction for \(name)")
        for proxy in library.proxies where proxy.name.hasPrefix("foot.") {
          let transform = pose[proxy.bone].applying(
            MannequinJointPose(proxy.position + proxy.rotation))
          for x in [Float(-0.5), 0.5] {
            for y in [Float(-0.5), 0.5] {
              for z in [Float(-0.5), 0.5] {
                let point =
                  transform.position
                  + transform.rotation.act(
                    [proxy.size[0] * x, proxy.size[1] * y, proxy.size[2] * z])
                #expect(point.y >= -0.000001)
              }
            }
          }
        }
      }
    }
  }

  @Test func pauseAndResetDoNotInventFootsteps() {
    let mannequin = Mannequin(name: "pause", color: .gray)
    var fighter = fighter()
    mannequin.pose(fighter: fighter, deltaTime: 0)
    fighter.position = [0, -0.03]
    mannequin.pose(fighter: fighter, deltaTime: 1 / 120)
    #expect(mannequin.selectedClip == "run")
    let frozen = boneTransforms(mannequin)
    for _ in 0..<10 { mannequin.pose(fighter: fighter, deltaTime: 0) }
    #expect(boneTransforms(mannequin) == frozen)
    mannequin.pose(fighter: fighter, deltaTime: 1 / 120)
    #expect(mannequin.selectedClip == "idle", "blocked/stopped travel is not a walking cycle")
    mannequin.resetMotion()
    fighter.position = [5, 4]
    mannequin.pose(fighter: fighter, deltaTime: 0)
    #expect(mannequin.selectedClip == "idle", "Retry/teleport is not travelled distance")
  }

  @Test(arguments: [SIMD2<Float>(0, -1), [0, 1], [-1, 0], [1, 0]])
  func focusedDodgeUsesDirectionNeutralCompression(direction: SIMD2<Float>) {
    let library = MannequinLibrary.shared
    let chest = library.index("chest")
    let clip = library.clips["dodge"]!
    let samples = (0...60).map { step in
      library.world(library.sample("dodge", time: clip.duration * Float(step) / 60))[chest].position
    }
    #expect(samples.map(\.y).max()! - samples.map(\.y).min()! > 0.1)
    #expect(samples.map(\.z).max()! - samples.map(\.z).min()! < 0.00002)
    let mannequin = Mannequin(name: "dodge", color: .gray)
    var fighter = fighter()
    fighter.yaw = 0  // Focus may keep facing the opponent during backward/side travel.
    var action = DuelAction(kind: .dodge, direction: direction)
    action.elapsed = action.duration * 0.5
    fighter.action = action
    mannequin.pose(fighter: fighter, deltaTime: 0)
    #expect(mannequin.selectedClip == "dodge")
    #expect(mannequin.root.orientation.vector == simd_quatf().vector)
  }

  private func fighter() -> DuelFighter {
    DuelFighter(position: .zero, yaw: 0, health: DuelSimulation.heroMaxHealth)
  }
  private func grip(_ action: DuelAction) -> SIMD3<Float> {
    if action.kind == .thrust { return [0, 1.08, -(action.bladeReach - 1.70) + 0.08] }
    return SIMD3<Float>(0, 1.08, 0)
      + simd_quatf(angle: action.bladeAngle, axis: [0, 1, 0]).act([0, 0, -0.27])
  }
  private func boneTransforms(_ mannequin: Mannequin) -> [Transform] {
    MannequinLibrary.shared.bones.map {
      mannequin.root.findEntity(
        named:
          "\(mannequin.root.name.replacingOccurrences(of: ".mannequin", with: "")).bone.\($0.name)")!
        .transform
    }
  }
}
