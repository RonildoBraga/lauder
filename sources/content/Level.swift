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
    /// For decoration: rails, posts and cables, the river far below, and painted lines.
    case metal, river, paint
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
    /// Searching the stranger's body, on the bridge (M3).
    case searchStranger = "bridge.search-stranger"
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

  /// What a body yields when it is searched.
  struct Loot: Equatable, Sendable {
    var rounds = 0
    var medicalKits = 0
  }

  /// Someone who fights in an encounter: where they wait unseen, where they step out to, how
  /// many hits they take and how they attack.
  struct Hostile {
    /// How a hostile attacks once engaged.
    enum Attack: Equatable, Sendable {
      /// Aims with a visible wind-up, shoots, recovers and aims again.
      case shoot
      /// Runs at the leader at this speed, in metres per second.
      case charge(speed: Float)
    }

    let id: String
    let name: String
    let hiddenAt: SIMD2<Float>
    let standAt: SIMD2<Float>
    let hits: Int
    var attack = Attack.shoot
    /// The visible aim before each shot, long enough to take cover or answer.
    var windUp: Float = 0
    /// The pause after each shot before the next aim begins.
    var recovery: Float = 0
    var range: Float = 0
    /// The first shot misses on purpose, so the opening teaches without punishing.
    var firstShotMisses = false
    /// Shown after that deliberate miss: how to answer it.
    var missLine: String?
    /// What searching the body yields once the hostile is down.
    var loot: Loot?
  }

  /// What happens at a moment after an encounter begins.
  enum Cue {
    /// A hostile steps out from where it waited.
    case reveal(String)
    /// A short line, shown without stopping play.
    case say(speaker: String, line: String)
    /// A hostile starts to fight.
    case engage(String)
    /// The leader finishes searching this hostile's body, and its loot is taken.
    case loot(String)
    /// A member who has not joined yet appears where they wait.
    case appear(PartyMember)
    /// A scripted shot by a member that takes this hostile down.
    case shot(by: PartyMember, at: String)
    /// The leader and this member turn to face each other.
    case face(PartyMember)
    /// A conversation begins; what it settles takes effect when it ends.
    case talk(MissionScript.Conversation)
  }

  /// A story beat with hostiles: its first moments, how it begins, and where a retry places the
  /// leader after the last allowed hit.
  struct Encounter {
    enum Start {
      /// When the leader walks into this area.
      case area(PartyMotion.Box)
      /// When the leader performs this action.
      case action(ActionID)
    }

    let beat: GameSession.Beat
    let start: Start
    /// Just outside the area, or nil when the leader cannot be hurt.
    let retryAt: SIMD2<Float>?
    let hostiles: [Hostile]
    let cues: [(at: Float, cue: Cue)]
    /// The leader stands still while the cues play, as in a short scripted scene.
    var holdsLeader = false
  }

  /// How close a point of interest must be for a look to describe it.
  static let interactionRadius: Float = 2.3

  let id: ID
  /// The floor. It bounds the navigation grid and blocks nothing.
  let ground: Box
  let boxes: [Box]
  /// Decoration that blocks nothing, such as the bridge's walkway and cables.
  var pieces: [Piece] = []
  let points: [PointOfInterest]
  let interactions: [Interaction]
  let triggers: [Trigger]
  var encounters: [Encounter] = []
  /// Rounds for the leader's weapon when a run starts.
  var startingAmmo = 0
  let passage: Passage?
  /// Who is in the party when a run starts, leader first.
  let party: [PartyMember]
  /// Where each member's body starts, including members who join later.
  let spawns: [PartyMember: SIMD2<Float>]
  /// The direction the party faces at the start.
  let heading: SIMD2<Float>
  /// From the camera's target to the camera.
  let cameraOffset: SIMD3<Float>
  /// The camera's vertical field of view, in degrees.
  var fieldOfView: Float = 42
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
