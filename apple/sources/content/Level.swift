import simd

/// A playable place: its scenery and blockers, who starts in the party and where, the contextual
/// actions and the areas that show a line once. Content only: the session owns progress and the
/// world owns the bodies (ADR 0004).
struct Level {
  /// A box that blocks movement and sight with its footprint; the ground is separate. How it
  /// looks is up to the level's scene file (ADR 0002).
  struct Box {
    let name: String
    let position: SIMD3<Float>
    let size: SIMD3<Float>

    var footprint: PartyMotion.Box { Level.footprint(position: position, size: size) }
  }

  enum ActionID: String, Sendable {
    /// Searching the stranger's body, on the bridge (M3).
    case searchStranger = "bridge.search-stranger"
    /// Helping Laura with the medical kit, at mid-span (M4).
    case helpLaura = "bridge.help-laura"
  }

  /// A contextual action, usable by whoever leads while they stand in its approach area.
  struct Interaction {
    let id: ActionID
    let name: String
    let approach: PartyMotion.Box
    /// Shown when the action succeeds.
    let result: String
    /// Shown when the action has already succeeded.
    var repeated = ""
    /// Shown before the story reaches the action.
    var early = ""
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
    /// A member who lay hurt where they waited stands up.
    case stand(PartyMember)
    /// A scripted shot by a member that takes this hostile down.
    case shot(by: PartyMember, at: String)
    /// Two members turn to face each other.
    case face(PartyMember, PartyMember)
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
    /// The party stands still while the cues play, as in a short scripted scene: whoever leads
    /// and the companions, so that only the cues place and turn anyone until it ends.
    var holdsParty = false
    /// Where the camera leans while the cues play, so that what the scene is about comes into
    /// view, as it leans towards a hostile in a fight.
    var focus: SIMD2<Float>?
    /// The encounter waits until every companion is close to the leader, so a scene for the
    /// whole party never begins with someone holding elsewhere (ADR 0003, phase S3).
    var gathersParty = false
  }

  /// A short name, such as "brooklyn-bridge", for the scene and messages.
  let id: String
  /// The floor. It bounds the navigation grid and blocks nothing.
  let ground: Box
  let boxes: [Box]
  /// The scene file that shows the level, exported by Blender (ADR 0002): the name of a USDZ in
  /// the app's bundle. Without one, such as in a test, the game draws the ground and boxes as
  /// plain blocks.
  var scene: String?
  let interactions: [Interaction]
  let triggers: [Trigger]
  var encounters: [Encounter] = []
  /// Rounds for the leader's weapon when a run starts.
  var startingAmmo = 0
  /// Who is in the party when a run starts, leader first.
  let party: [PartyMember]
  /// Where each member's body starts, including members who join later.
  let spawns: [PartyMember: SIMD2<Float>]
  /// Members who lie hurt where they wait, in view from the start, until a scene stands them
  /// up. Others who have not joined stay hidden.
  var lying: Set<PartyMember> = []
  /// The direction the party faces at the start.
  let heading: SIMD2<Float>
  /// From the camera's target to the camera.
  let cameraOffset: SIMD3<Float>
  /// The camera's vertical field of view, in degrees.
  let fieldOfView: Float
  /// The lights, from the level's layout file (ADR 0002).
  var lights: [Light] = []
  /// The first line a run shows.
  let opening: String
  /// The objective line when a run starts.
  let objective: String
  /// The objective from each of these beats on, in story order.
  var objectiveChanges: [(beat: GameSession.Beat, text: String)] = []
  /// Where the compass points from each of these beats on, in story order; nil hides it.
  var goals: [(beat: GameSession.Beat, goal: Goal?)] = []
  /// What a look shows outside every action's approach.
  let lookAround: String
  /// What the pause menu says Restart does.
  let restartNote: String

  /// The floor's footprint, which the navigation grid covers.
  var bounds: PartyMotion.Box { ground.footprint }

  /// A place the compass points to: what the HUD calls it, and where it is on the ground.
  struct Goal: Equatable, Sendable {
    let name: String
    let point: SIMD2<Float>
  }

  func spawn(_ member: PartyMember) -> SIMD2<Float> {
    guard let point = spawns[member] else {
      preconditionFailure("\(id) has no spawn point for \(member.rawValue).")
    }
    return point
  }

  /// Movement blockers: the scenery and the ground's edges. The flat-floor footprints come from
  /// the same dimensions as the visible blocks.
  var obstacles: [PartyMotion.Box] { boxes.map(\.footprint) + edges }

  /// The ground's edges: a metre-thick wall just outside each side of its footprint, which
  /// nobody sees, so the party keeps to the ground, as on the buried bridge's road.
  var edges: [PartyMotion.Box] {
    let low = bounds.minimum
    let high = bounds.maximum
    return [
      PartyMotion.Box(minimum: [low.x - 1, low.y - 1], maximum: [low.x, high.y + 1]),
      PartyMotion.Box(minimum: [high.x, low.y - 1], maximum: [high.x + 1, high.y + 1]),
      PartyMotion.Box(minimum: [low.x, low.y - 1], maximum: [high.x, low.y]),
      PartyMotion.Box(minimum: [low.x, high.y], maximum: [high.x, high.y + 1]),
    ]
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
