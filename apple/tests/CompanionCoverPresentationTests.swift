import RealityKit
import Testing
import simd

@testable import Lauder

/// Each squad member owns a reusable shield and receives the same temporary cover pose.
@MainActor
struct CompanionCoverPresentationTests {
  @Test
  func shieldsAreIndependentReusedAndHiddenWhenTheirMemberLeavesCover() throws {
    let level = Self.level
    let encounter = try #require(level.encounters.first)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let stage = EncounterStage(level: level, style: SceneStyle())
    let shields = try Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map { member in
        (member, try #require(stage.container.findEntity(named: "cover.shield.\(member.rawValue)")))
      })
    let originalCount = count(stage.container)
    #expect(shields.values.allSatisfy { !$0.isEnabled })
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    var figures = level.spawns
    func step() {
      _ = fight.step(
        dt: 1 / 120, leader: figures[.miki]!, facing: [0, -1], aiming: false,
        fireHeld: false, firePressed: false, mayDisrupt: false, signaturePressed: false,
        figures: figures, session: session)
      stage.update(fight, dt: 1 / 120)
    }
    step()
    #expect(shields.values.allSatisfy { $0.isEnabled })
    // Only Laura leaves. The other shields must keep their own placement and visibility.
    figures[.laura] = [0, 4]
    step()
    #expect(shields[.laura]?.isEnabled == false)
    #expect(shields[.miki]?.isEnabled == true && shields[.tom]?.isEnabled == true)
    fight.reset()
    stage.reset(fight)
    #expect(shields.values.allSatisfy { !$0.isEnabled })
    #expect(count(stage.container) == originalCount)
    for (member, shield) in shields {
      #expect(stage.container.findEntity(named: "cover.shield.\(member.rawValue)") === shield)
    }
  }

  @Test
  func companionsCrouchThenStandUprightAfterLeavingAndRestarting() throws {
    let world = GameWorld(level: Self.level)
    #expect(world.session.holdAll())
    run(world, upTo: 0.1)
    let figures = try Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map { member in
        let body = try #require(world.root.findEntity(named: "party.\(member.rawValue)"))
        let model = try #require(body.findEntity(named: "\(member.rawValue).model"))
        return (member, try #require(model.parent))
      })
    for figure in figures.values { #expect(abs(figure.scale.y - 0.68) < 0.001) }
    #expect(world.session.send(.laura, to: [0, 4]))
    #expect(run(world, upTo: 4) { (figures[.laura]?.scale.y ?? 0) > 0.99 })
    #expect(world.root.findEntity(named: "cover.shield.laura")?.isEnabled == false)
    #expect(abs((figures[.miki]?.scale.y ?? 0) - 0.68) < 0.001)
    #expect(abs((figures[.tom]?.scale.y ?? 0) - 0.68) < 0.001)

    world.restart()
    for figure in figures.values { #expect(abs(figure.scale.y - 1) < 0.001) }
    for member in PartyMember.allCases {
      #expect(world.root.findEntity(named: "cover.shield.\(member.rawValue)")?.isEnabled == false)
    }
  }

  private static let spawns: [PartyMember: SIMD2<Float>] = [
    .miki: [-2, 0.9], .laura: [0, 0.9], .tom: [2, 0.9],
  ]

  private static let level: Level = {
    let shooter = Level.Hostile(
      id: "observer", name: "The observer", hiddenAt: [0, -5], standAt: [0, -5], hits: 6,
      windUp: 100, recovery: 100, range: 14, inView: true, targetFromWindUp: true)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-10, -10], maximum: [10, 10])),
      retryAt: spawns[.miki], hostiles: [shooter], cues: [(at: 0, cue: .engage(shooter.id))])
    return Level(
      id: "companion-cover-presentation",
      ground: .box("ground", at: [0, -0.15, 0], size: [20, 0.3, 20]),
      boxes: [.box("shelter", at: [0, 0.5, 0], size: [8, 1, 1])],
      interactions: [], triggers: [], encounters: [encounter], startingAmmo: 60,
      party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
      cameraOffset: CombatYard.level.cameraOffset, fieldOfView: CombatYard.level.fieldOfView,
      opening: "A shelter.", objective: "Test.", lookAround: "A block.", restartNote: "Restart.",
      combat: Level.Combat(leaderCover: true))
  }()
}
