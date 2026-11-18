import simd

enum PrototypeLayout {
  enum Surface {
    case concrete, shelter, depot, hazard
  }

  enum BoxID: String, CaseIterable {
    case ground
    case southBoundary = "south-boundary"
    case northBoundary = "north-boundary"
    case westBoundary = "west-boundary"
    case eastBoundary = "east-boundary"
    case shelterBack = "shelter-back"
    case shelterSide = "shelter-side"
    case streetWreck = "street-wreck"
    case fallenPanel = "fallen-panel"
    case depotBack = "depot-back"
    case depotEast = "depot-east"
    case depotWestBack = "depot-west-back"
    case depotWestFront = "depot-west-front"
    case depotFrontWest = "depot-front-west"
    case depotFrontEast = "depot-front-east"
    case blockedEntrance = "blocked-entrance"

    var hasWallCap: Bool {
      switch self {
      case .southBoundary, .northBoundary, .westBoundary, .eastBoundary,
        .shelterBack, .shelterSide, .depotBack, .depotEast,
        .depotWestBack, .depotWestFront, .depotFrontWest, .depotFrontEast:
        true
      case .ground, .streetWreck, .fallenPanel, .blockedEntrance:
        false
      }
    }
  }

  struct Box {
    let id: BoxID
    let position: SIMD3<Float>
    let size: SIMD3<Float>
    let surface: Surface

    var name: String { id.rawValue }
  }

  enum InteractionID: String, CaseIterable {
    case transmitter = "relay.transmitter"
    case regulator = "depot.regulator"
  }

  struct PointOfInterest {
    let id: InteractionID
    let name: String
    let position: SIMD3<Float>
    /// The visible block, which is also its collision footprint.
    let size: SIMD3<Float>
    let observation: String
    /// What a look shows once the mission reaches `changedAt`.
    let changedAt: GameSession.Phase
    let changedObservation: String

    func observation(at phase: GameSession.Phase) -> String {
      phase >= changedAt ? changedObservation : observation
    }
  }

  static let spawn: SIMD3<Float> = [-8, 0, 3]
  static let cameraOffset: SIMD3<Float> = [5.25, 10, 8.4]
  static let characterHeight: Float = 1.7
  static let characterRadius: Float = 0.26
  static let speed: Float = 2.6
  static let movementDeadZone: Float = 0.15
  static let interactionRadius: Float = 2.3

  static let serviceMarkerSize: SIMD3<Float> = [1.2, 0.025, 0.12]
  static let serviceMarkerPositions: [SIMD3<Float>] = [[3.4, 0.02, -5.1], [3.4, 0.02, -3.9]]

  static func spawn(for member: PartyMember) -> SIMD3<Float> {
    switch member {
    case .miki: spawn
    case .lara: spawn + [0, 0, 0.8]
    case .tomas: spawn + [0, 0, 1.6]
    }
  }

  // Low walls preserve the elevated camera's view of the party. The depot's front is
  // blocked; its west wall leaves a 1.8 m service opening around the corner.
  static let boxes: [Box] = [
    Box(id: .ground, position: [0, -0.15, 0], size: [28, 0.3, 20], surface: .concrete),
    Box(
      id: .southBoundary, position: [0, 0.45, 9.7], size: [28, 0.9, 0.6], surface: .concrete),
    Box(
      id: .northBoundary, position: [0, 0.45, -9.7], size: [28, 0.9, 0.6], surface: .concrete),
    Box(
      id: .westBoundary, position: [-13.7, 0.45, 0], size: [0.6, 0.9, 20], surface: .concrete),
    Box(
      id: .eastBoundary, position: [13.7, 0.45, 0], size: [0.6, 0.9, 20], surface: .concrete),
    Box(id: .shelterBack, position: [-9, 0.5, 0], size: [7, 1, 0.35], surface: .shelter),
    Box(id: .shelterSide, position: [-12.3, 0.5, 2.5], size: [0.35, 1, 5], surface: .shelter),
    Box(id: .streetWreck, position: [-1.5, 0.4, 1], size: [2.5, 0.8, 1.2], surface: .hazard),
    Box(id: .fallenPanel, position: [1, 0.3, -2], size: [1.2, 0.6, 2.5], surface: .shelter),
    Box(id: .depotBack, position: [7, 0.55, -7], size: [6.4, 1.1, 0.35], surface: .depot),
    Box(id: .depotEast, position: [10, 0.55, -4], size: [0.35, 1.1, 6], surface: .depot),
    Box(
      id: .depotWestBack, position: [4, 0.55, -6.2], size: [0.35, 1.1, 1.6], surface: .depot),
    Box(
      id: .depotWestFront, position: [4, 0.55, -2.3], size: [0.35, 1.1, 2.6], surface: .depot),
    Box(id: .depotFrontWest, position: [5, 0.55, -1], size: [2, 1.1, 0.35], surface: .depot),
    Box(id: .depotFrontEast, position: [9, 0.55, -1], size: [2, 1.1, 0.35], surface: .depot),
    Box(
      id: .blockedEntrance, position: [7, 0.45, -0.7], size: [2.2, 0.9, 1], surface: .hazard),
  ]

  static func box(_ id: BoxID) -> Box {
    let matches = boxes.filter { $0.id == id }
    precondition(matches.count == 1, "Layout must contain exactly one \(id.rawValue) box.")
    return matches[0]
  }

  static let points: [PointOfInterest] = [
    PointOfInterest(
      id: .transmitter, name: "Transmitter", position: [-10, 0, 1.5], size: [0.8, 1, 0.6],
      observation: "The transmitter can receive but cannot answer.",
      changedAt: .radioRepaired, changedObservation: "The transmitter is working again."
    ),
    PointOfInterest(
      id: .regulator, name: "Regulator housing", position: [7, 0, -4.5], size: [0.5, 0.5, 0.5],
      observation: "A regulator sits in a disconnected housing, beside a working water bypass.",
      changedAt: .carryingRegulator,
      changedObservation: "The housing is empty. The water bypass beside it is still connected."
    ),
  ]

  static func point(_ id: InteractionID) -> PointOfInterest {
    let matches = points.filter { $0.id == id }
    precondition(matches.count == 1, "Layout must contain exactly one \(id.rawValue) point.")
    return matches[0]
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
  /// Approaches are authored on the usable side of any wall: the passage's on the street side,
  /// the transmitter's inside the shelter and the regulator's inside the depot.
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

  // Party B: one closed barrier fills the 1.8 m service opening in the depot's west wall.
  // Either Lara's latch or Tomas's loose panel opens the same ordinary ground passage.
  static let barrierPosition: SIMD3<Float> = [4, 0.55, -4.5]
  static let barrierSize: SIMD3<Float> = [0.35, 1.1, 1.8]
  static let barrierFootprint = footprint(position: barrierPosition, size: barrierSize)
  static let barrierHint =
    "The service passage is closed. Lara could reach the latch, or Tomas could shift the loose panel."

  /// Inside the shelter, around the transmitter, including where the party starts.
  static let transmitterApproach = PartyMotion.Box(minimum: [-11.4, 0.5], maximum: [-7.6, 3.4])
  /// Around the regulator's housing, inside the depot.
  static let housingApproach = PartyMotion.Box(minimum: [5.6, -5.9], maximum: [8.4, -3.1])

  static let interactions: [Interaction] = [
    Interaction(
      id: .reachLatch, name: "Reach latch", member: .lara,
      approach: PartyMotion.Box(minimum: [2.8, -5.35], maximum: [3.6, -4.65]), keepClear: true,
      suggestion: "Lara could reach the latch at the top of the barrier.",
      mikiSuggestion: barrierHint,
      result: "Lara reaches up and releases the latch. The passage is open for everyone.",
      repeated: "The passage is already open."),
    Interaction(
      id: .shiftPanel, name: "Shift panel", member: .tomas,
      approach: PartyMotion.Box(minimum: [2.8, -4.35], maximum: [3.6, -3.65]), keepClear: true,
      suggestion: "Tomas could shift the loose panel at the foot of the barrier.",
      mikiSuggestion: barrierHint,
      result: "Tomas braces and shifts the loose panel aside. The passage is open for everyone.",
      repeated: "The passage is already open."),
    // Party C. At the transmitter exactly one of these is offered in each phase.
    Interaction(
      id: .hearBriefing, name: "Talk to keeper", member: nil, approach: transmitterApproach,
      result: "The party sets out to find a regulator at the depot.",
      repeated: "The keeper has already explained the fault."),
    Interaction(
      id: .takeRegulator, name: "Take regulator", member: .miki, approach: housingApproach,
      suggestion: "Miki should inspect the regulator before anyone takes it.",
      result: "Miki takes the regulator. The water bypass stays connected.",
      repeated: "The housing is empty. The water bypass beside it is still connected.",
      early: "Talk to the keeper at the transmitter first."),
    Interaction(
      id: .repairTransmitter, name: "Repair", member: .miki, approach: transmitterApproach,
      suggestion: "Miki can fit a regulator to the transmitter.",
      result: "The transmitter is ready.",
      repeated: "The transmitter is already repaired.",
      early: "Talk to the keeper first."),
    Interaction(
      id: .callCrew, name: "Call", member: nil, approach: transmitterApproach,
      result: "Transmitter restored. Meeting agreed at Old Lock.",
      repeated: "The meeting at Old Lock is already agreed.",
      early: "The transmitter cannot answer yet."),
    Interaction(
      id: .readPlan, name: "Read plan", member: nil, approach: transmitterApproach,
      result: "Old Lock, tomorrow afternoon, by the canal path.",
      early: "There is no plan to read yet."),
  ]

  static func interaction(_ id: ActionID) -> Interaction {
    let matches = interactions.filter { $0.id == id }
    precondition(matches.count == 1, "Layout must contain exactly one \(id.rawValue) action.")
    return matches[0]
  }

  /// Movement blockers for the current passage state.
  static func obstacles(passageOpen: Bool) -> [PartyMotion.Box] {
    passageOpen ? obstacles : obstacles + [barrierFootprint]
  }

  // The flat-floor footprint comes from the same dimensions as the visible scenery.
  // Ground, decorations and party members do not block horizontal movement.
  static let obstacles: [PartyMotion.Box] =
    boxes.filter { $0.id != .ground }.map {
      footprint(position: $0.position, size: $0.size)
    }
    + points.map { footprint(position: $0.position, size: $0.size) }

  private static func footprint(position: SIMD3<Float>, size: SIMD3<Float>) -> PartyMotion.Box {
    let centre = SIMD2(position.x, position.z)
    let half = SIMD2(size.x, size.z) / 2
    return PartyMotion.Box(minimum: centre - half, maximum: centre + half)
  }
}
