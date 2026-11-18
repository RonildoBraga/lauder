import simd

/// A playable place: its scenery and blockers, who starts in the party and where, what can be
/// looked at, the contextual actions and the areas that show a line once. Content only: the
/// session owns progress and the world owns the bodies (ADR 0004).
struct Level {
  enum ID: String, CaseIterable, Sendable {
    case brooklynBridge = "brooklyn-bridge"
    case relayHouse = "relay-house"
  }

  enum Surface: Sendable {
    case ground, concrete, shelter, depot, hazard, asphalt, steel, granite, vehicle
  }

  /// Visible scenery. Every box blocks movement with its footprint; the ground is separate.
  struct Box {
    let name: String
    let position: SIMD3<Float>
    let size: SIMD3<Float>
    let surface: Surface
    /// A light cap along the top, added by the scene dressing.
    var wallCap = false

    var footprint: PartyMotion.Box { Level.footprint(position: position, size: size) }
  }

  struct PointOfInterest {
    let id: String
    let name: String
    /// The centre of the block's base, on the floor.
    let position: SIMD3<Float>
    /// The visible block, which is also its collision footprint.
    let size: SIMD3<Float>
    let observation: String
    /// What a look shows once Party C's mission reaches `changedAt`, at Relay House.
    var changedAt: GameSession.Phase?
    var changedObservation = ""

    var footprint: PartyMotion.Box { Level.footprint(position: position, size: size) }

    func observation(at phase: GameSession.Phase) -> String {
      if let changedAt, phase >= changedAt { return changedObservation }
      return observation
    }
  }

  enum ActionID: String, CaseIterable, Sendable {
    case reachLatch = "passage.reach-latch"
    case shiftPanel = "passage.shift-panel"
    case hearBriefing = "relay.briefing"
    case takeRegulator = "depot.take-regulator"
    case repairTransmitter = "relay.repair"
    case callCrew = "relay.call"
    case readPlan = "relay.read-plan"
  }

  /// A contextual action, usable only while the active body stands in its approach area.
  /// Approaches are authored on the usable side of any wall.
  struct Interaction {
    let id: ActionID
    let name: String
    /// The only member who can act here, or nil when any leader can.
    let member: PartyMember?
    let approach: PartyMotion.Box
    /// Companions keep clear of a small approach while its action is offered, so they cannot
    /// stand where the leader must.
    var keepClear = false
    /// Shown when another member leads at this approach.
    var suggestion = ""
    /// Shown instead when Miki leads here, where she can explain the alternatives.
    var mikiSuggestion: String?
    /// Shown when the action succeeds.
    let result: String
    /// Shown when the action has already succeeded.
    var repeated = ""
    /// Shown before the mission reaches the action.
    var early = ""
  }

  /// A barrier that the session's passage flag opens, as at Relay House.
  struct Passage {
    let barrier: Box
    /// Shown near the closed barrier when no action is offered there.
    let hint: String
  }

  /// An area that shows a line the first time the leader walks into it in a run.
  struct Trigger {
    let id: String
    let area: PartyMotion.Box
    let line: String
  }

  /// How close a point of interest must be for a look to describe it.
  static let interactionRadius: Float = 2.3

  let id: ID
  /// The floor. It bounds the navigation grid and blocks nothing.
  let ground: Box
  let boxes: [Box]
  let points: [PointOfInterest]
  let interactions: [Interaction]
  let triggers: [Trigger]
  let passage: Passage?
  /// Who is in the party when a run starts, leader first.
  let party: [PartyMember]
  /// Where each member's body starts, including members who join later.
  let spawns: [PartyMember: SIMD2<Float>]
  /// The direction the party faces at the start.
  let heading: SIMD2<Float>
  /// From the camera's target to the camera.
  let cameraOffset: SIMD3<Float>
  /// The first line a run shows.
  let opening: String
  /// The objective line, or nil where Party C's mission supplies it.
  let objective: String?
  /// What a look shows with nothing nearby, or nil where Party C's mission supplies it.
  let lookAround: String?
  /// What the pause menu says Restart does.
  let restartNote: String

  static func level(_ id: ID) -> Level {
    switch id {
    case .brooklynBridge: BrooklynBridge.level
    case .relayHouse: RelayHouse.level
    }
  }

  /// The floor's footprint, which the navigation grid covers.
  var bounds: PartyMotion.Box { ground.footprint }

  func spawn(_ member: PartyMember) -> SIMD2<Float> {
    guard let point = spawns[member] else {
      preconditionFailure("\(id.rawValue) has no spawn point for \(member.rawValue).")
    }
    return point
  }

  func interaction(_ action: ActionID) -> Interaction? {
    interactions.first { $0.id == action }
  }

  /// Movement blockers: the scenery and points of interest, and the passage's barrier while it
  /// is closed. The flat-floor footprints come from the same dimensions as the visible blocks.
  func obstacles(passageOpen: Bool) -> [PartyMotion.Box] {
    let fixed = boxes.map(\.footprint) + points.map(\.footprint)
    guard let passage, !passageOpen else { return fixed }
    return fixed + [passage.barrier.footprint]
  }

  static func footprint(position: SIMD3<Float>, size: SIMD3<Float>) -> PartyMotion.Box {
    let centre = SIMD2(position.x, position.z)
    let half = SIMD2(size.x, size.z) / 2
    return PartyMotion.Box(minimum: centre - half, maximum: centre + half)
  }
}

/// The stand-ins' shared body: every member has the same footprint and walking speed.
enum PartyBody {
  static let height: Float = 1.7
  static let radius: Float = 0.26
  static let speed: Float = 2.6
}
