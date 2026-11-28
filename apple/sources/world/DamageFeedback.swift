import simd

/// Short-lived presentation of accepted damage. Every hit contributes its resolved amount;
/// rapid rounds share a brief bucket without renewing the number's lifetime.
struct DamageFeedback: Equatable, Sendable {
  static let lifetime: Float = 0.8
  static let rapidWindow: Float = 0.3
  static let maximumLabels = 8

  struct Label: Identifiable, Equatable, Sendable {
    let id: UInt64
    let target: String
    let attacker: PartyMember
    let weapon: Weapon.Kind?
    let effectiveness: DamageHit.Effectiveness
    /// A stable vertical place for reduced-motion presentation, separate for each attacker.
    let stackSlot: Int
    var amount: Int
    var position: SIMD3<Float>
    var brokeComponent: Bool
    var age: Float = 0

    var progress: Float { min(1, max(0, age / DamageFeedback.lifetime)) }
    var opacity: Float { min(1, max(0, (DamageFeedback.lifetime - age) / 0.25)) }
  }

  private(set) var labels: [Label] = []
  private var nextID: UInt64 = 0
  /// How many numbers have appeared so far: it rises whenever a new one shows.
  var serial: UInt64 { nextID }

  mutating func receive(_ hit: DamageHit) {
    guard hit.amount > 0, hit.position.indices.allSatisfy({ hit.position[$0].isFinite })
    else { return }
    if hit.weapon == .minigun || hit.weapon == .assaultRifle,
      let index = labels.lastIndex(where: {
        $0.target == hit.target && $0.attacker == hit.attacker && $0.weapon == hit.weapon
          && $0.effectiveness == hit.effectiveness && $0.age < Self.rapidWindow
      })
    {
      let sum = labels[index].amount.addingReportingOverflow(hit.amount)
      labels[index].amount = sum.overflow ? .max : sum.partialValue
      labels[index].position = hit.position
      labels[index].brokeComponent = labels[index].brokeComponent || hit.brokeComponent
      return
    }
    if labels.count >= Self.maximumLabels {
      labels.removeFirst(labels.count - Self.maximumLabels + 1)
    }
    let slot =
      (0..<Self.maximumLabels).first { candidate in
        !labels.contains { $0.attacker == hit.attacker && $0.stackSlot == candidate }
      } ?? 0
    labels.append(
      Label(
        id: nextID, target: hit.target, attacker: hit.attacker, weapon: hit.weapon,
        effectiveness: hit.effectiveness, stackSlot: slot, amount: hit.amount,
        position: hit.position,
        brokeComponent: hit.brokeComponent))
    nextID &+= 1
  }

  /// Called only as ordinary play advances; Pause freezes it. Lifecycle/reset clears it.
  mutating func advance(dt: Float) {
    guard dt.isFinite, dt > 0 else { return }
    for index in labels.indices { labels[index].age += dt }
    labels.removeAll { $0.age >= Self.lifetime }
  }

  mutating func clear() {
    labels.removeAll(keepingCapacity: true)
  }
}
