// Where everything on the Brooklyn Bridge stands (ADR 0005), in metres: x across the
// deck, y up and z along it, with Brooklyn at +z and Manhattan at -z. Blender edits
// this file through scripts/blender/lauder_levels.py: Load builds the layout in
// Blender and Save writes it back. The numbers can also be edited here, and the next
// Load picks them up. Keep the entries in this form so that the script can read them.

extension BrooklynBridge {
  static let layout = Level.Layout(
    ground: .box("deck", at: [0, -0.15, 0], size: [24, 0.3, 250], surface: .asphalt),
    boxes: [
      .box("railing-west", at: [-11.8, 0.55, 0], size: [0.4, 1.1, 250], surface: .steel),
      .box("railing-east", at: [11.8, 0.55, 0], size: [0.4, 1.1, 250], surface: .steel),
      .box("brooklyn-barricade", at: [0, 0.6, 123.6], size: [23.2, 1.2, 0.8], surface: .hazard),
      .box("divider-south", at: [0, 0.5, 42], size: [5, 1, 132], surface: .steel),
      .box("divider-north", at: [0, 0.5, -73], size: [5, 1, 74], surface: .steel),
      .box("brooklyn-tower-pier", at: [0, 7, 20], size: [6, 14, 10], surface: .granite),
      .box("brooklyn-tower-west", at: [-12.6, 7, 20], size: [3.2, 14, 10], surface: .granite),
      .box("brooklyn-tower-east", at: [12.6, 7, 20], size: [3.2, 14, 10], surface: .granite),
      .box("manhattan-tower-pier", at: [0, 7, -80], size: [6, 14, 10], surface: .granite),
      .box("manhattan-tower-west", at: [-12.6, 7, -80], size: [3.2, 14, 10], surface: .granite),
      .box("manhattan-tower-east", at: [12.6, 7, -80], size: [3.2, 14, 10], surface: .granite),
      .box("car-a1", at: [9.6, 0.75, 100], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-a2", at: [4.4, 0.75, 92], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-a4", at: [9.8, 0.75, 80], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-b1", at: [4.4, 0.75, 62], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-b2", at: [9.8, 0.75, 56], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-b3", at: [4.6, 0.75, 48], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-b4", at: [9.4, 0.75, 44], size: [4, 1.5, 2], surface: .vehicle),
      .box("van-b", at: [9.6, 1.1, 30], size: [2.2, 2.2, 5.5], surface: .vehicle),
      .box("car-d1", at: [9.8, 0.75, 2], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-d2", at: [4.4, 0.75, -8], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("truck-d", at: [7.6, 1.6, -50], size: [2.5, 3.2, 8], surface: .vehicle),
      .box("car-d5", at: [4.6, 0.75, -60], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-a3", at: [-9.6, 0.75, 96], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-b5", at: [-4.4, 0.75, 58], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-b6", at: [-9.8, 0.75, 40], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-c1", at: [-4.6, 0.75, 6], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-d3", at: [-9.6, 0.75, -40], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-d4", at: [-4.4, 0.75, -56], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-e1", at: [-9.8, 0.75, -95], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("car-e2", at: [-4.4, 0.75, -102], size: [2, 1.5, 4.6], surface: .vehicle),
      .box("debris-a1", at: [5, 0.4, 75], size: [1.4, 0.8, 1.2], surface: .concrete),
      .box("debris-a2", at: [-5, 0.4, 84], size: [1.4, 0.8, 1.2], surface: .concrete),
      .box("debris-d1", at: [-9.4, 0.4, -64], size: [1.4, 0.8, 1.2], surface: .concrete),
    ],
    landmarks: [
      .landmark("bridge.booth", at: [0, 0, 113], size: [2.4, 2.6, 2.4]),
      .landmark("bridge.bus", at: [7.05, 0, -42], size: [9.3, 3, 2.6]),
      .landmark("bridge.manhattan-barricade", at: [0, 0, -123.6], size: [23.2, 1.6, 0.8]),
    ],
    areas: [
      .area("cars-ahead", from: [-12, 66], to: [12, 72]),
      .area("first-tower", from: [-12, 26], to: [12, 32]),
      .area("mid-span", from: [-12, -12], to: [12, -6]),
      .area("blocked-lanes", from: [3, -32], to: [12, -26]),
      .area("second-tower", from: [-12, -72], to: [12, -66]),
      .area("manhattan-end", from: [-12, -112], to: [12, -106]),
      .area("stranger", from: [-12, 47], to: [12, 52]),
      .area("search.stranger", from: [5.6, 40.6], to: [8.4, 43.4]),
    ],
    markers: [
      .marker("spawn.miki", at: [6.5, 116]),
      .marker("spawn.tom", at: [8.8, 37.5]),
      .marker("spawn.laura", at: [-7.6, -38]),
      .marker("stranger.hidden", at: [9.4, 41.6]),
      .marker("stranger.stand", at: [7, 42]),
      .marker("stranger.retry", at: [6.5, 55.5]),
      .marker("attacker.hidden", at: [10, 26]),
      .marker("attacker.stand", at: [7.6, 26.6]),
    ])
}
