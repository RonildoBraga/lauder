import simd

/// The Relay House slice of Parties A to C, kept as a second level (ADR 0004).
enum RelayHouse {
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

  enum PointID: String, CaseIterable {
    case transmitter = "relay.transmitter"
    case regulator = "depot.regulator"
  }

  static let spawn: SIMD3<Float> = [-8, 0, 3]
  static let cameraOffset: SIMD3<Float> = [5.25, 10, 8.4]

  static let serviceMarkerSize: SIMD3<Float> = [1.2, 0.025, 0.12]
  static let serviceMarkerPositions: [SIMD3<Float>] = [[3.4, 0.02, -5.1], [3.4, 0.02, -3.9]]

  static func spawn(for member: PartyMember) -> SIMD3<Float> {
    switch member {
    case .miki: spawn
    case .laura: spawn + [0, 0, 0.8]
    case .tom: spawn + [0, 0, 1.6]
    }
  }

  // Low walls preserve the elevated camera's view of the party. The depot's front is
  // blocked; its west wall leaves a 1.8 m service opening around the corner.
  static let boxes: [Level.Box] = [
    make(.ground, position: [0, -0.15, 0], size: [28, 0.3, 20], surface: .ground),
    make(.southBoundary, position: [0, 0.45, 9.7], size: [28, 0.9, 0.6], surface: .concrete),
    make(.northBoundary, position: [0, 0.45, -9.7], size: [28, 0.9, 0.6], surface: .concrete),
    make(.westBoundary, position: [-13.7, 0.45, 0], size: [0.6, 0.9, 20], surface: .concrete),
    make(.eastBoundary, position: [13.7, 0.45, 0], size: [0.6, 0.9, 20], surface: .concrete),
    make(.shelterBack, position: [-9, 0.5, 0], size: [7, 1, 0.35], surface: .shelter),
    make(.shelterSide, position: [-12.3, 0.5, 2.5], size: [0.35, 1, 5], surface: .shelter),
    make(.streetWreck, position: [-1.5, 0.4, 1], size: [2.5, 0.8, 1.2], surface: .hazard),
    make(.fallenPanel, position: [1, 0.3, -2], size: [1.2, 0.6, 2.5], surface: .shelter),
    make(.depotBack, position: [7, 0.55, -7], size: [6.4, 1.1, 0.35], surface: .depot),
    make(.depotEast, position: [10, 0.55, -4], size: [0.35, 1.1, 6], surface: .depot),
    make(.depotWestBack, position: [4, 0.55, -6.2], size: [0.35, 1.1, 1.6], surface: .depot),
    make(.depotWestFront, position: [4, 0.55, -2.3], size: [0.35, 1.1, 2.6], surface: .depot),
    make(.depotFrontWest, position: [5, 0.55, -1], size: [2, 1.1, 0.35], surface: .depot),
    make(.depotFrontEast, position: [9, 0.55, -1], size: [2, 1.1, 0.35], surface: .depot),
    make(.blockedEntrance, position: [7, 0.45, -0.7], size: [2.2, 0.9, 1], surface: .hazard),
  ]

  static func box(_ id: BoxID) -> Level.Box {
    let matches = boxes.filter { $0.name == id.rawValue }
    precondition(matches.count == 1, "Layout must contain exactly one \(id.rawValue) box.")
    return matches[0]
  }

  static let points: [Level.PointOfInterest] = [
    Level.PointOfInterest(
      id: PointID.transmitter.rawValue, name: "Transmitter", position: [-10, 0, 1.5],
      size: [0.8, 1, 0.6], observation: "The transmitter can receive but cannot answer.",
      changedAt: .radioRepaired, changedObservation: "The transmitter is working again."
    ),
    Level.PointOfInterest(
      id: PointID.regulator.rawValue, name: "Regulator housing", position: [7, 0, -4.5],
      size: [0.5, 0.5, 0.5],
      observation: "A regulator sits in a disconnected housing, beside a working water bypass.",
      changedAt: .carryingRegulator,
      changedObservation: "The housing is empty. The water bypass beside it is still connected."
    ),
  ]

  static func point(_ id: PointID) -> Level.PointOfInterest {
    let matches = points.filter { $0.id == id.rawValue }
    precondition(matches.count == 1, "Layout must contain exactly one \(id.rawValue) point.")
    return matches[0]
  }

  // Party B: one closed barrier fills the 1.8 m service opening in the depot's west wall.
  // Either Laura's latch or Tom's loose panel opens the same ordinary ground passage.
  static let barrierPosition: SIMD3<Float> = [4, 0.55, -4.5]
  static let barrierSize: SIMD3<Float> = [0.35, 1.1, 1.8]
  static let barrierFootprint = Level.footprint(position: barrierPosition, size: barrierSize)
  static let barrierHint =
    "The service passage is closed. Laura could reach the latch, or Tom could shift the loose panel."

  /// Inside the shelter, around the transmitter, including where the party starts.
  static let transmitterApproach = PartyMotion.Box(minimum: [-11.4, 0.5], maximum: [-7.6, 3.4])
  /// Around the regulator's housing, inside the depot.
  static let housingApproach = PartyMotion.Box(minimum: [5.6, -5.9], maximum: [8.4, -3.1])

  static let interactions: [Level.Interaction] = [
    Level.Interaction(
      id: .reachLatch, name: "Reach latch", member: .laura,
      approach: PartyMotion.Box(minimum: [2.8, -5.35], maximum: [3.6, -4.65]), keepClear: true,
      suggestion: "Laura could reach the latch at the top of the barrier.",
      mikiSuggestion: barrierHint,
      result: "Laura reaches up and releases the latch. The passage is open for everyone.",
      repeated: "The passage is already open."),
    Level.Interaction(
      id: .shiftPanel, name: "Shift panel", member: .tom,
      approach: PartyMotion.Box(minimum: [2.8, -4.35], maximum: [3.6, -3.65]), keepClear: true,
      suggestion: "Tom could shift the loose panel at the foot of the barrier.",
      mikiSuggestion: barrierHint,
      result: "Tom braces and shifts the loose panel aside. The passage is open for everyone.",
      repeated: "The passage is already open."),
    // Party C. At the transmitter exactly one of these is offered in each phase.
    Level.Interaction(
      id: .hearBriefing, name: "Talk to keeper", member: nil, approach: transmitterApproach,
      result: "The party sets out to find a regulator at the depot.",
      repeated: "The keeper has already explained the fault."),
    Level.Interaction(
      id: .takeRegulator, name: "Take regulator", member: .miki, approach: housingApproach,
      suggestion: "Miki should inspect the regulator before anyone takes it.",
      result: "Miki takes the regulator. The water bypass stays connected.",
      repeated: "The housing is empty. The water bypass beside it is still connected.",
      early: "Talk to the keeper at the transmitter first."),
    Level.Interaction(
      id: .repairTransmitter, name: "Repair", member: .miki, approach: transmitterApproach,
      suggestion: "Miki can fit a regulator to the transmitter.",
      result: "The transmitter is ready.",
      repeated: "The transmitter is already repaired.",
      early: "Talk to the keeper first."),
    Level.Interaction(
      id: .callCrew, name: "Call", member: nil, approach: transmitterApproach,
      result: "Transmitter restored. Meeting agreed at Old Lock.",
      repeated: "The meeting at Old Lock is already agreed.",
      early: "The transmitter cannot answer yet."),
    Level.Interaction(
      id: .readPlan, name: "Read plan", member: nil, approach: transmitterApproach,
      result: "Old Lock, tomorrow afternoon, by the canal path.",
      early: "There is no plan to read yet."),
  ]

  static func interaction(_ id: Level.ActionID) -> Level.Interaction {
    let matches = interactions.filter { $0.id == id }
    precondition(matches.count == 1, "Layout must contain exactly one \(id.rawValue) action.")
    return matches[0]
  }

  static let level = Level(
    id: .relayHouse, ground: box(.ground),
    boxes: boxes.filter { $0.name != BoxID.ground.rawValue }, points: points,
    interactions: interactions, triggers: [],
    passage: Level.Passage(
      barrier: Level.Box(
        name: "passage.barrier", position: barrierPosition, size: barrierSize, surface: .hazard),
      hint: barrierHint),
    party: [.miki, .laura, .tom],
    spawns: Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        let point = spawn(for: $0)
        return ($0, SIMD2(point.x, point.z))
      }),
    heading: [0, -1], cameraOffset: cameraOffset, opening: MissionScript.opening,
    objective: nil, lookAround: nil,
    restartNote: "Restart begins a new run from the keeper's briefing.")

  /// Movement blockers with the passage open.
  static let obstacles = level.obstacles(passageOpen: true)

  /// Movement blockers for the current passage state.
  static func obstacles(passageOpen: Bool) -> [PartyMotion.Box] {
    passageOpen ? obstacles : level.obstacles(passageOpen: false)
  }

  private static func make(
    _ id: BoxID, position: SIMD3<Float>, size: SIMD3<Float>, surface: Level.Surface
  ) -> Level.Box {
    Level.Box(
      name: id.rawValue, position: position, size: size, surface: surface,
      wallCap: id.hasWallCap)
  }
}
