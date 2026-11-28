@testable import Lauder

/// An explicit initial actor for isolated native weapon fixtures. It does not select Laura
/// through the shipped Switch input or change an existing session's leadership authority.
func levelStarting(with member: PartyMember, from level: Level) -> Level {
  precondition(level.party.contains(member))
  return Level(
    id: level.id, ground: level.ground, boxes: level.boxes, scene: level.scene,
    triggers: level.triggers, encounters: level.encounters,
    party: [member] + level.party.filter { $0 != member }, spawns: level.spawns,
    heading: level.heading, cameraOffset: level.cameraOffset, fieldOfView: level.fieldOfView,
    lights: level.lights, opening: level.opening, objective: level.objective,
    objectiveChanges: level.objectiveChanges, goals: level.goals, lookAround: level.lookAround,
    restartNote: level.restartNote)
}
