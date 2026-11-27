import simd

/// The opening: a compressed, flat greybox of the Brooklyn Bridge (ADR 0004), buried in snow.
/// Brooklyn is at +z and Manhattan at -z. The road and everything on it lie under a white plain
/// level with the old deck, and only the two towers stand above it. The party keeps to the line
/// of the buried road, inside an invisible edge at its width. The towers are the only cover, and
/// the machine that guards the first tower is the only fight.
///
/// Where everything stands, the decoration, the camera and the lights are in `layout`
/// (BrooklynBridgeLayout.swift), which Blender exports (ADR 0002). This file adds the words: what
/// each place is called and what it says.
enum BrooklynBridge {
  /// Where each tower's centre stands along the deck. Since this file names the piers, Blender's
  /// export refuses to drop them.
  static var brooklynTower: Float { layout.box(named: "brooklyn-tower-pier").position.z }
  static var manhattanTower: Float { layout.box(named: "manhattan-tower-pier").position.z }
  /// The camera stands high and far, as the visual direction sets out, and looks straight along
  /// the deck, so pushing up walks towards Manhattan. Blender edits it with the rest of the layout.
  static var cameraOffset: SIMD3<Float> { layout.camera.offset }

  /// Each shows its line the first time the leader walks in, once per run.
  static let triggers: [Level.Trigger] = [
    trigger("buried-road", "Snow covers the road and everything left on it."),
    trigger("first-tower", "The first tower. Its arches still stand."),
    trigger("mid-span", "Mid-span. The wind is stronger out here."),
    trigger("second-tower", "The second tower. Manhattan is close now."),
    trigger("manhattan-end", "The Manhattan end. The city lies buried beyond it."),
  ]

  /// C guards the outgoing side of the first tower. The stable "stranger" identifiers retain
  /// the existing authored marker and progression references; the visible encounter is a robot.
  /// It warns, commits its aim and fires a short burst, with the tower's stone as real cover.
  static let stranger = Level.Hostile(
    id: "stranger", name: "The guard robot", hiddenAt: layout.marker(named: "stranger.stand"),
    standAt: layout.marker(named: "stranger.stand"), hits: 6, attack: .robot, strategicGuard: true,
    windUp: 1, recovery: 1.8, range: 12)

  /// The first fight, as the party walks through the first tower. A retry starts just outside
  /// its area, in the east arch.
  static let strangerEncounter = Level.Encounter(
    beat: .stranger, start: .area(layout.area(named: "stranger")),
    retryAt: layout.marker(named: "stranger.retry"), hostiles: [stranger],
    cues: [
      (0, .reveal(stranger.id)),
      (0, .engage(stranger.id)),
      (0.6, .say(speaker: "Miki", line: "Armoured. I'll take its sensor when it cools.")),
    ], safeExit: layout.area(named: "robot.exit"))

  /// The end of the opening (M4): the three reach the Manhattan end together, the party stops,
  /// and a short exchange closes the slice. It waits until all three are there, so companions
  /// holding elsewhere must be called back first.
  static let arrival = Level.Encounter(
    beat: .arrived, start: .area(layout.area(named: "manhattan-end")), retryAt: nil,
    hostiles: [], cues: [(0.5, .talk(.arrival))], holdsParty: true, gathersParty: true)

  /// What the compass points to: the Manhattan end while crossing, and nothing once the three
  /// are there.
  static let goals: [(beat: StoryBeat, goal: Level.Goal?)] = [
    (.crossing, manhattan),
    (.arrived, nil),
  ]

  /// Where the three start, together at the Brooklyn end: Miki at her marker, and Tom and Laura
  /// in the Close formation's places behind her, Tom on the right and Laura on the left, the
  /// sides the D-pad's orders keep.
  private static var spawns: [PartyMember: SIMD2<Float>] {
    let miki = layout.marker(named: "spawn.miki")
    return [.miki: miki, .tom: miki + [0.9, 0.9], .laura: miki + [-0.9, 0.9]]
  }

  /// The Manhattan end's area, where the opening ends.
  private static var manhattan: Level.Goal {
    let end = layout.area(named: "manhattan-end")
    return Level.Goal(name: "Manhattan", point: (end.minimum + end.maximum) / 2)
  }

  static let level = Level(
    id: "brooklyn-bridge", ground: layout.ground, boxes: layout.boxes,
    // What the player sees, exported by Blender with the layout file from the level's own file.
    scene: "BrooklynBridge",
    triggers: triggers,
    encounters: [strangerEncounter, arrival],
    // The three cross together from the start, Miki leading.
    party: [.miki, .tom, .laura],
    spawns: spawns,
    heading: [0, -1], cameraOffset: cameraOffset, fieldOfView: layout.camera.fieldOfView,
    lights: layout.lights,
    opening: "The Brooklyn end of the bridge. Manhattan is on the far side.",
    objective: "Cross the bridge to Manhattan.",
    objectiveChanges: [(.arrived, "Manhattan, together.")],
    goals: goals,
    lookAround: "Manhattan is ahead, across the bridge.",
    restartNote: "Restart begins a new run at the Brooklyn end.")

  /// A trigger area from the layout, with the line it shows.
  private static func trigger(_ id: String, _ line: String) -> Level.Trigger {
    Level.Trigger(id: id, area: layout.area(named: id), line: line)
  }
}
