import Testing

@testable import Lauder

struct SceneLayoutTests {
  @Test(arguments: PrototypeLayout.BoxID.allCases)
  func eachDeclaredBoxExistsExactlyOnce(id: PrototypeLayout.BoxID) {
    #expect(PrototypeLayout.boxes.filter { $0.id == id }.count == 1)
  }

  @MainActor
  @Test
  func plantersFitTheirSolidSupportFootprints() {
    let tolerance: Float = 0.00001
    for placement in SceneDressing.planterPlacements {
      let wall = PrototypeLayout.box(placement.support)
      let position = placement.basePosition
      let size = SceneDressing.planterSize
      #expect(placement.support.hasWallCap)
      #expect(abs(position.x - wall.position.x) + size.x / 2 <= wall.size.x / 2 + tolerance)
      #expect(abs(position.z - wall.position.z) + size.z / 2 <= wall.size.z / 2 + tolerance)
      #expect(
        abs(position.y - (wall.position.y + wall.size.y / 2 + SceneDressing.wallCapHeight))
          < tolerance)
    }
  }
}
