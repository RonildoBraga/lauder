import Testing
import simd

@testable import Lauder

@MainActor
struct EnemyTacticsTests {
  private static let party: [PartyMember: SIMD2<Float>] = [.miki: [0, 5]]
  private static let low = Level.Box.box("low", at: [0, 0.5, 0], size: [4, 1, 1])
  private static let tall = Level.Box.box("wall", at: [0, 1.5, 0], size: [8, 3, 1])

  @Test
  func coverShootersChooseAProtectedAnchorWithAValidFiringPoint() throws {
    let spec = enemy(behavior: .takeCover, at: [0, -2])
    let level = yard(hostiles: [spec], boxes: [Self.low])
    var tactics = EnemyTactics(level: level)
    let actor = engaged(spec)
    let step = tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 120)
    let goal = try #require(tactics.goals[spec.id])
    let cover = LeaderCover(boxes: level.boxes, ground: level.bounds)
    let target = try #require(Self.party[.miki])
    let shelter = try #require(cover.shelter(at: goal, facing: target - goal))
    #expect(shelter.isLow)
    #expect(
      !LineOfSight.isClear(
        from: target, to: goal, obstacles: cover.incomingBlockers(in: shelter, exposed: false)))
    let firing = try #require(cover.firingPoint(from: goal, in: shelter, facing: target - goal))
    #expect(
      LineOfSight.isClear(
        from: firing, to: target, obstacles: cover.incomingBlockers(in: shelter, exposed: true)))
    #expect(simd_distance(goal, actor.position) <= EnemyTactics.coverReach)
    #expect(step.moving.contains(spec.id))
  }

  @Test
  func aTallWallsMiddleWithoutAPeekDoesNotBecomeAFiringDestination() throws {
    let spec = enemy(behavior: .takeCover, at: [0, -1.2])
    let level = yard(hostiles: [spec], boxes: [Self.tall])
    var tactics = EnemyTactics(level: level)
    let actor = engaged(spec)
    let step = tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 120)
    #expect(tactics.goals[spec.id] == spec.standAt)
    #expect(step.positions.isEmpty && step.moving.isEmpty)
  }

  @Test
  func theFlankerChangesAngleWithBoundedContinuousMovement() throws {
    let spec = enemy(behavior: .flank, at: [0, -5])
    let level = yard(hostiles: [spec])
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    var tactics = EnemyTactics(level: level)
    var actor = engaged(spec)
    let dt: Float = 1 / 60
    var moved = false
    for _ in 0..<180 {
      let before = actor.position
      let step = tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: dt)
      if let next = step.positions[spec.id] {
        #expect(motion.canTraverse(from: before, to: next))
        #expect(simd_distance(next, before) <= EnemyTactics.speed * dt + 0.0001)
        #expect(simd_distance(next, spec.standAt) <= EnemyTactics.homeReach + 0.0001)
        #expect(level.bounds.contains(next))
        actor.reposition(to: next)
      }
      moved = moved || step.moving.contains(spec.id)
    }
    #expect(moved && abs(actor.position.x - spec.standAt.x) > 2)
  }

  @Test
  func aBlockedDirectFlankUsesTheGridWithoutCuttingTheWall() throws {
    let wall = Level.Box.box("across", at: [0, 1.5, -4], size: [4, 3, 1])
    let spec = enemy(behavior: .flank, at: [0, -6])
    let level = yard(hostiles: [spec], boxes: [wall])
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    var tactics = EnemyTactics(level: level, grid: NavigationGrid(level: level))
    var actor = engaged(spec)
    _ = tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 120)
    let goal = try #require(tactics.goals[spec.id])
    #expect(!motion.canTraverse(from: spec.standAt, to: goal))
    for _ in 0..<300 {
      let before = actor.position
      let step = tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 60)
      if let next = step.positions[spec.id] {
        #expect(motion.canTraverse(from: before, to: next))
        #expect(simd_distance(next, spec.standAt) <= EnemyTactics.homeReach + 0.0001)
        actor.reposition(to: next)
      }
    }
    #expect(abs(actor.position.x) > 2.3)
  }

  @Test
  func reactionCompletesBeforeMovementCanHoldTheAttackTimer() {
    let spec = enemy(behavior: .flank, at: [0, -5], reaction: 0.35)
    let level = yard(hostiles: [spec])
    var tactics = EnemyTactics(level: level)
    var actor = HostileState(spec: spec)
    actor.engage()
    #expect(
      tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 120).moving.isEmpty)
    #expect(tactics.goals.isEmpty)
    _ = actor.step(dt: spec.reactionDelay, canHit: false, toward: .zero)
    #expect(actor.isTargetable)
    #expect(
      tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 120).moving.contains(
        spec.id))
    // A fallback keeps the actor targetable, but its new engagement still pays the reaction
    // before tactical movement can freeze a weapon timer.
    actor.standDown()
    tactics.reset()
    actor.engage()
    #expect(actor.isTargetable && actor.phase == .recovering(remaining: spec.reactionDelay))
    #expect(
      tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 120).moving.isEmpty)
    #expect(tactics.goals.isEmpty)
    _ = actor.step(dt: spec.reactionDelay, canHit: false, toward: .zero)
    #expect(
      tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 120).moving.contains(
        spec.id))
  }

  @Test
  func aFlankerFinishesTheCommittedRouteAndHasTimeToFire() throws {
    let wall = Level.Box.box("across", at: [0, 1.5, -4], size: [4, 3, 1])
    let spec = enemy(behavior: .flank, at: [0, -6])
    var tactics = EnemyTactics(level: yard(hostiles: [spec], boxes: [wall]))
    var actor = engaged(spec)
    let dt: Float = 1 / 60
    var firstGoal: SIMD2<Float>?
    var arrived = false
    var fired = false
    for _ in 0..<1200 {
      let step = tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: dt)
      let goal = try #require(tactics.goals[spec.id])
      if firstGoal == nil { firstGoal = goal }
      if !arrived { #expect(goal == firstGoal) }
      if let point = step.positions[spec.id] { actor.reposition(to: point) }
      let moving = step.moving.contains(spec.id)
      if !moving, simd_distance(actor.position, goal) <= EnemyTactics.arrival + 0.001 {
        arrived = true
      }
      if actor.step(dt: dt, canHit: true, toward: [0, 5], canAttack: !moving) == .hit {
        fired = true
        break
      }
    }
    #expect(arrived && fired && abs(actor.position.x) > 2.3)
  }

  @Test
  func aCommittedPlanSurvivesSmallTargetChangesUntilItsScheduledRecheck() throws {
    let spec = enemy(behavior: .flank, at: [0, -5])
    var tactics = EnemyTactics(level: yard(hostiles: [spec]))
    var actor = engaged(spec)
    _ = tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 1 / 120)
    let goal = try #require(tactics.goals[spec.id])
    for _ in 0..<60 {
      let step = tactics.step(hostiles: [spec.id: actor], party: [.miki: [0.5, 5]], dt: 1 / 60)
      if let next = step.positions[spec.id] { actor.reposition(to: next) }
      #expect(tactics.goals[spec.id] == goal)
    }
    let zero = tactics.step(hostiles: [spec.id: actor], party: Self.party, dt: 0)
    #expect(zero.moving.isEmpty && tactics.goals[spec.id] == goal)
    tactics.reset()
    #expect(tactics.goals.isEmpty)
  }

  @Test
  func dictionaryOrderDoesNotChangeThePlansOrFirstMovement() {
    let first = enemy(id: "a", behavior: .flank, at: [-3, -5])
    let second = enemy(id: "b", behavior: .flank, at: [3, -5])
    let level = yard(hostiles: [first, second])
    var a = EnemyTactics(level: level)
    var b = EnemyTactics(level: level)
    let firstOrder = [first.id: engaged(first), second.id: engaged(second)]
    let reverseOrder = [second.id: engaged(second), first.id: engaged(first)]
    let stepA = a.step(hostiles: firstOrder, party: Self.party, dt: 1 / 120)
    let stepB = b.step(hostiles: reverseOrder, party: Self.party, dt: 1 / 120)
    #expect(a.goals == b.goals)
    #expect(stepA.positions == stepB.positions && stepA.moving == stepB.moving)
  }

  @Test
  func stationaryThrowingWaitingAndDownedActorsDoNotMove() {
    let stationary = enemy(id: "still", behavior: .stationary, at: [-4, -5])
    var throwing = enemy(id: "throw", behavior: .flank, at: [4, -5])
    throwing.attack = .throwGrenade
    let waiting = enemy(id: "waiting", behavior: .flank, at: [0, -5])
    let level = yard(hostiles: [stationary, throwing, waiting])
    var down = engaged(waiting)
    down.knockDown()
    var tactics = EnemyTactics(level: level)
    let step = tactics.step(
      hostiles: [
        stationary.id: engaged(stationary), throwing.id: engaged(throwing), waiting.id: down,
      ],
      party: Self.party, dt: 1 / 120)
    #expect(step.positions.isEmpty && step.moving.isEmpty && tactics.goals.isEmpty)
    var standingDown = engaged(waiting)
    standingDown.standDown()
    #expect(standingDown.isTargetable)
    #expect(
      tactics.step(hostiles: [waiting.id: standingDown], party: Self.party, dt: 1 / 120).positions
        .isEmpty)
  }

  private func enemy(
    id: String = "tactical", behavior: Level.Hostile.Behavior,
    at point: SIMD2<Float>, reaction: Float = 0
  ) -> Level.Hostile {
    Level.Hostile(
      id: id, name: "The tactical hostile", hiddenAt: point, standAt: point, hits: 3,
      behavior: behavior, reactionDelay: reaction, windUp: 1.5, recovery: 1.4, range: 14,
      inView: true, targetFromWindUp: true)
  }

  private func engaged(_ spec: Level.Hostile) -> HostileState {
    var state = HostileState(spec: spec)
    state.engage()
    if spec.reactionDelay > 0 {
      _ = state.step(dt: spec.reactionDelay, canHit: false, toward: .zero)
    }
    return state
  }

  private func yard(hostiles: [Level.Hostile], boxes: [Level.Box] = []) -> Level {
    Level(
      id: "enemy-tactics", ground: .box("ground", at: [0, -0.15, 0], size: [24, 0.3, 24]),
      boxes: boxes, interactions: [], triggers: [],
      encounters: [
        Level.Encounter(
          beat: .stranger, start: .area(PartyMotion.Box(minimum: [-12, -12], maximum: [12, 12])),
          retryAt: nil, hostiles: hostiles, cues: [])
      ],
      party: [.miki], spawns: [.miki: [0, 5]], heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42, opening: "Snow.", objective: "Test.",
      lookAround: "A yard.", restartNote: "Restart.")
  }
}
