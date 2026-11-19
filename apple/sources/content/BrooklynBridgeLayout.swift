// Where everything on the Brooklyn Bridge stands and how it is lit (ADR 0005), in metres: x
// across the deck, y up and z along it, with Brooklyn at +z and Manhattan at -z. Blender edits
// this file through blender/lauder_levels.py: Load builds the layout in Blender and Save writes
// it back. The numbers can also be edited here, and the next Load picks them up. Keep the
// entries in this form so that the script can read them.

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
    ],
    pieces: [
      .piece("river", at: [0, -30, 0], size: [400, 0.2, 500], surface: .river),
      .piece("lane-line-west", at: [-7.3, 0.006, 0], size: [0.12, 0.01, 248], surface: .paint),
      .piece("lane-line-east", at: [7.3, 0.006, 0], size: [0.12, 0.01, 248], surface: .paint),
      .piece("tower-top-brooklyn", at: [0, 20, 20], size: [28.4, 12, 10], surface: .granite),
      .piece("tower-top-manhattan", at: [0, 20, -80], size: [28.4, 12, 10], surface: .granite),
      .piece("walkway-south", at: [0, 4.2, 42], size: [5.4, 0.3, 132], surface: .steel),
      .piece(
        "walkway-south-rail-west", at: [-2.66, 4.8, 42], size: [0.08, 0.9, 132], surface: .metal),
      .piece(
        "walkway-south-post-west-1", at: [-2.1, 2.53, -18], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-west-2", at: [-2.1, 2.53, 2], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-west-3", at: [-2.1, 2.53, 22], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-west-4", at: [-2.1, 2.53, 42], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-west-5", at: [-2.1, 2.53, 62], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-west-6", at: [-2.1, 2.53, 82], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-west-7", at: [-2.1, 2.53, 102], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-rail-east", at: [2.66, 4.8, 42], size: [0.08, 0.9, 132], surface: .metal),
      .piece(
        "walkway-south-post-east-1", at: [2.1, 2.53, -18], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-east-2", at: [2.1, 2.53, 2], size: [0.25, 3.05, 0.25], surface: .metal),
      .piece(
        "walkway-south-post-east-3", at: [2.1, 2.53, 22], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-east-4", at: [2.1, 2.53, 42], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-east-5", at: [2.1, 2.53, 62], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-east-6", at: [2.1, 2.53, 82], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-south-post-east-7", at: [2.1, 2.53, 102], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece("walkway-north", at: [0, 4.2, -73], size: [5.4, 0.3, 74], surface: .steel),
      .piece(
        "walkway-north-rail-west", at: [-2.66, 4.8, -73], size: [0.08, 0.9, 74], surface: .metal),
      .piece(
        "walkway-north-post-west-1", at: [-2.1, 2.53, -104], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-north-post-west-2", at: [-2.1, 2.53, -84], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-north-post-west-3", at: [-2.1, 2.53, -64], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-north-post-west-4", at: [-2.1, 2.53, -44], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-north-rail-east", at: [2.66, 4.8, -73], size: [0.08, 0.9, 74], surface: .metal),
      .piece(
        "walkway-north-post-east-1", at: [2.1, 2.53, -104], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-north-post-east-2", at: [2.1, 2.53, -84], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-north-post-east-3", at: [2.1, 2.53, -64], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "walkway-north-post-east-4", at: [2.1, 2.53, -44], size: [0.25, 3.05, 0.25],
        surface: .metal),
      .piece(
        "cable-west-1", at: [-12.4, 5.583, 106.667], size: [0.22, 0.22, 35.616],
        turn: [-0.9933, 0, 0, 0.1154], surface: .metal),
      .piece(
        "cable-west-2", at: [-12.4, 13.75, 72], size: [0.22, 0.22, 35.616],
        turn: [-0.9933, 0, 0, 0.1154], surface: .metal),
      .piece(
        "cable-west-3", at: [-12.4, 21.917, 37.333], size: [0.22, 0.22, 35.616],
        turn: [-0.9933, 0, 0, 0.1154], surface: .metal),
      .piece(
        "cable-west-4", at: [-12.4, 20.969, 13.75], size: [0.22, 0.22, 16.047],
        turn: [0.9431, 0, 0, 0.3324], surface: .metal),
      .piece(
        "cable-west-5", at: [-12.4, 12.344, 1.25], size: [0.22, 0.22, 14.419],
        turn: [0.9662, 0, 0, 0.258], surface: .metal),
      .piece(
        "cable-west-6", at: [-12.4, 6.594, -11.25], size: [0.22, 0.22, 13.223],
        turn: [0.9862, 0, 0, 0.1653], surface: .metal),
      .piece(
        "cable-west-7", at: [-12.4, 3.719, -23.75], size: [0.22, 0.22, 12.582],
        turn: [0.9984, 0, 0, 0.0572], surface: .metal),
      .piece(
        "cable-west-8", at: [-12.4, 3.719, -36.25], size: [0.22, 0.22, 12.582],
        turn: [-0.9984, 0, 0, 0.0572], surface: .metal),
      .piece(
        "cable-west-9", at: [-12.4, 6.594, -48.75], size: [0.22, 0.22, 13.223],
        turn: [-0.9862, 0, 0, 0.1653], surface: .metal),
      .piece(
        "cable-west-10", at: [-12.4, 12.344, -61.25], size: [0.22, 0.22, 14.419],
        turn: [-0.9662, 0, 0, 0.258], surface: .metal),
      .piece(
        "cable-west-11", at: [-12.4, 20.969, -73.75], size: [0.22, 0.22, 16.047],
        turn: [-0.9431, 0, 0, 0.3324], surface: .metal),
      .piece(
        "cable-west-12", at: [-12.4, 21.917, -87.333], size: [0.22, 0.22, 16.787],
        turn: [0.9679, 0, 0, 0.2513], surface: .metal),
      .piece(
        "cable-west-13", at: [-12.4, 13.75, -102], size: [0.22, 0.22, 16.787],
        turn: [0.9679, 0, 0, 0.2513], surface: .metal),
      .piece(
        "cable-west-14", at: [-12.4, 5.583, -116.667], size: [0.22, 0.22, 16.787],
        turn: [0.9679, 0, 0, 0.2513], surface: .metal),
      .piece(
        "suspender-west-1", at: [-12.4, 2.97, -118], size: [0.05, 3.741, 0.05], surface: .metal),
      .piece(
        "suspender-west-2", at: [-12.4, 6.311, -106], size: [0.05, 10.423, 0.05], surface: .metal),
      .piece(
        "suspender-west-3", at: [-12.4, 9.652, -94], size: [0.05, 17.105, 0.05], surface: .metal),
      .piece(
        "suspender-west-4", at: [-12.4, 9.41, -70], size: [0.05, 16.62, 0.05], surface: .metal),
      .piece(
        "suspender-west-5", at: [-12.4, 5.656, -58], size: [0.05, 9.113, 0.05], surface: .metal),
      .piece(
        "suspender-west-6", at: [-12.4, 3.228, -46], size: [0.05, 4.255, 0.05], surface: .metal),
      .piece(
        "suspender-west-7", at: [-12.4, 2.124, -34], size: [0.05, 2.047, 0.05], surface: .metal),
      .piece(
        "suspender-west-8", at: [-12.4, 2.344, -22], size: [0.05, 2.489, 0.05], surface: .metal),
      .piece(
        "suspender-west-9", at: [-12.4, 3.89, -10], size: [0.05, 5.58, 0.05], surface: .metal),
      .piece(
        "suspender-west-10", at: [-12.4, 6.76, 2], size: [0.05, 11.321, 0.05], surface: .metal),
      .piece(
        "suspender-west-11", at: [-12.4, 11.43, 38], size: [0.05, 20.66, 0.05], surface: .metal),
      .piece(
        "suspender-west-12", at: [-12.4, 10.016, 50], size: [0.05, 17.833, 0.05], surface: .metal),
      .piece(
        "suspender-west-13", at: [-12.4, 8.603, 62], size: [0.05, 15.006, 0.05], surface: .metal),
      .piece(
        "suspender-west-14", at: [-12.4, 7.189, 74], size: [0.05, 12.179, 0.05], surface: .metal),
      .piece(
        "suspender-west-15", at: [-12.4, 5.776, 86], size: [0.05, 9.352, 0.05], surface: .metal),
      .piece(
        "suspender-west-16", at: [-12.4, 4.363, 98], size: [0.05, 6.525, 0.05], surface: .metal),
      .piece(
        "suspender-west-17", at: [-12.4, 2.949, 110], size: [0.05, 3.698, 0.05], surface: .metal),
      .piece(
        "stay-west-brooklyn-1", at: [-12.4, 13.05, 13], size: [0.07, 0.07, 27.699],
        turn: [0.8676, 0, 0, 0.4973], surface: .metal),
      .piece(
        "stay-west-brooklyn-2", at: [-12.4, 13.05, 6], size: [0.07, 0.07, 36.813],
        turn: [0.9382, 0, 0, 0.346], surface: .metal),
      .piece(
        "stay-west-brooklyn-3", at: [-12.4, 13.05, 27], size: [0.07, 0.07, 27.699],
        turn: [0.4973, 0, 0, 0.8676], surface: .metal),
      .piece(
        "stay-west-brooklyn-4", at: [-12.4, 13.05, 34], size: [0.07, 0.07, 36.813],
        turn: [0.346, 0, 0, 0.9382], surface: .metal),
      .piece(
        "stay-west-manhattan-1", at: [-12.4, 13.05, -87], size: [0.07, 0.07, 27.699],
        turn: [0.8676, 0, 0, 0.4973], surface: .metal),
      .piece(
        "stay-west-manhattan-2", at: [-12.4, 13.05, -94], size: [0.07, 0.07, 36.813],
        turn: [0.9382, 0, 0, 0.346], surface: .metal),
      .piece(
        "stay-west-manhattan-3", at: [-12.4, 13.05, -73], size: [0.07, 0.07, 27.699],
        turn: [0.4973, 0, 0, 0.8676], surface: .metal),
      .piece(
        "stay-west-manhattan-4", at: [-12.4, 13.05, -66], size: [0.07, 0.07, 36.813],
        turn: [0.346, 0, 0, 0.9382], surface: .metal),
      .piece(
        "cable-east-1", at: [12.4, 5.583, 106.667], size: [0.22, 0.22, 35.616],
        turn: [-0.9933, 0, 0, 0.1154], surface: .metal),
      .piece(
        "cable-east-2", at: [12.4, 13.75, 72], size: [0.22, 0.22, 35.616],
        turn: [-0.9933, 0, 0, 0.1154], surface: .metal),
      .piece(
        "cable-east-3", at: [12.4, 21.917, 37.333], size: [0.22, 0.22, 35.616],
        turn: [-0.9933, 0, 0, 0.1154], surface: .metal),
      .piece(
        "cable-east-4", at: [12.4, 20.969, 13.75], size: [0.22, 0.22, 16.047],
        turn: [0.9431, 0, 0, 0.3324], surface: .metal),
      .piece(
        "cable-east-5", at: [12.4, 12.344, 1.25], size: [0.22, 0.22, 14.419],
        turn: [0.9662, 0, 0, 0.258], surface: .metal),
      .piece(
        "cable-east-6", at: [12.4, 6.594, -11.25], size: [0.22, 0.22, 13.223],
        turn: [0.9862, 0, 0, 0.1653], surface: .metal),
      .piece(
        "cable-east-7", at: [12.4, 3.719, -23.75], size: [0.22, 0.22, 12.582],
        turn: [0.9984, 0, 0, 0.0572], surface: .metal),
      .piece(
        "cable-east-8", at: [12.4, 3.719, -36.25], size: [0.22, 0.22, 12.582],
        turn: [-0.9984, 0, 0, 0.0572], surface: .metal),
      .piece(
        "cable-east-9", at: [12.4, 6.594, -48.75], size: [0.22, 0.22, 13.223],
        turn: [-0.9862, 0, 0, 0.1653], surface: .metal),
      .piece(
        "cable-east-10", at: [12.4, 12.344, -61.25], size: [0.22, 0.22, 14.419],
        turn: [-0.9662, 0, 0, 0.258], surface: .metal),
      .piece(
        "cable-east-11", at: [12.4, 20.969, -73.75], size: [0.22, 0.22, 16.047],
        turn: [-0.9431, 0, 0, 0.3324], surface: .metal),
      .piece(
        "cable-east-12", at: [12.4, 21.917, -87.333], size: [0.22, 0.22, 16.787],
        turn: [0.9679, 0, 0, 0.2513], surface: .metal),
      .piece(
        "cable-east-13", at: [12.4, 13.75, -102], size: [0.22, 0.22, 16.787],
        turn: [0.9679, 0, 0, 0.2513], surface: .metal),
      .piece(
        "cable-east-14", at: [12.4, 5.583, -116.667], size: [0.22, 0.22, 16.787],
        turn: [0.9679, 0, 0, 0.2513], surface: .metal),
      .piece(
        "suspender-east-1", at: [12.4, 2.97, -118], size: [0.05, 3.741, 0.05], surface: .metal),
      .piece(
        "suspender-east-2", at: [12.4, 6.311, -106], size: [0.05, 10.423, 0.05], surface: .metal),
      .piece(
        "suspender-east-3", at: [12.4, 9.652, -94], size: [0.05, 17.105, 0.05], surface: .metal),
      .piece(
        "suspender-east-4", at: [12.4, 9.41, -70], size: [0.05, 16.62, 0.05], surface: .metal),
      .piece(
        "suspender-east-5", at: [12.4, 5.656, -58], size: [0.05, 9.113, 0.05], surface: .metal),
      .piece(
        "suspender-east-6", at: [12.4, 3.228, -46], size: [0.05, 4.255, 0.05], surface: .metal),
      .piece(
        "suspender-east-7", at: [12.4, 2.124, -34], size: [0.05, 2.047, 0.05], surface: .metal),
      .piece(
        "suspender-east-8", at: [12.4, 2.344, -22], size: [0.05, 2.489, 0.05], surface: .metal),
      .piece(
        "suspender-east-9", at: [12.4, 3.89, -10], size: [0.05, 5.58, 0.05], surface: .metal),
      .piece(
        "suspender-east-10", at: [12.4, 6.76, 2], size: [0.05, 11.321, 0.05], surface: .metal),
      .piece(
        "suspender-east-11", at: [12.4, 11.43, 38], size: [0.05, 20.66, 0.05], surface: .metal),
      .piece(
        "suspender-east-12", at: [12.4, 10.016, 50], size: [0.05, 17.833, 0.05], surface: .metal),
      .piece(
        "suspender-east-13", at: [12.4, 8.603, 62], size: [0.05, 15.006, 0.05], surface: .metal),
      .piece(
        "suspender-east-14", at: [12.4, 7.189, 74], size: [0.05, 12.179, 0.05], surface: .metal),
      .piece(
        "suspender-east-15", at: [12.4, 5.776, 86], size: [0.05, 9.352, 0.05], surface: .metal),
      .piece(
        "suspender-east-16", at: [12.4, 4.363, 98], size: [0.05, 6.525, 0.05], surface: .metal),
      .piece(
        "suspender-east-17", at: [12.4, 2.949, 110], size: [0.05, 3.698, 0.05], surface: .metal),
      .piece(
        "stay-east-brooklyn-1", at: [12.4, 13.05, 13], size: [0.07, 0.07, 27.699],
        turn: [0.8676, 0, 0, 0.4973], surface: .metal),
      .piece(
        "stay-east-brooklyn-2", at: [12.4, 13.05, 6], size: [0.07, 0.07, 36.813],
        turn: [0.9382, 0, 0, 0.346], surface: .metal),
      .piece(
        "stay-east-brooklyn-3", at: [12.4, 13.05, 27], size: [0.07, 0.07, 27.699],
        turn: [0.4973, 0, 0, 0.8676], surface: .metal),
      .piece(
        "stay-east-brooklyn-4", at: [12.4, 13.05, 34], size: [0.07, 0.07, 36.813],
        turn: [0.346, 0, 0, 0.9382], surface: .metal),
      .piece(
        "stay-east-manhattan-1", at: [12.4, 13.05, -87], size: [0.07, 0.07, 27.699],
        turn: [0.8676, 0, 0, 0.4973], surface: .metal),
      .piece(
        "stay-east-manhattan-2", at: [12.4, 13.05, -94], size: [0.07, 0.07, 36.813],
        turn: [0.9382, 0, 0, 0.346], surface: .metal),
      .piece(
        "stay-east-manhattan-3", at: [12.4, 13.05, -73], size: [0.07, 0.07, 27.699],
        turn: [0.4973, 0, 0, 0.8676], surface: .metal),
      .piece(
        "stay-east-manhattan-4", at: [12.4, 13.05, -66], size: [0.07, 0.07, 36.813],
        turn: [0.346, 0, 0, 0.9382], surface: .metal),
    ],
    camera: .camera(offset: [0, 10, 9.9], fieldOfView: 42),
    lights: [
      .sun(
        "sun-key", from: [-3, 8, 5], color: [1, 0.91, 0.74], intensity: 4500, shadowDistance: 25),
      .sun("sky-fill", from: [3, 5, -4], color: [0.67, 0.81, 0.85], intensity: 600),
    ])
}
