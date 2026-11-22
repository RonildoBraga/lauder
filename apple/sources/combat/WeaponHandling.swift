/// One member's weapon timing, kept through changes between leading and following. All
/// mutation belongs to the fight's fixed step; a readiness query never consumes a shot, so
/// cover can predict exposure before the hostile's shot resolves in that same step.
struct WeaponHandling: Sendable {
  let weapon: Weapon
  private(set) var isDrawn = false
  private(set) var magazineRemaining: Int
  private(set) var reloadRemaining: Float = 0
  private var drawRemaining: Float = 0
  private var cooldown: Float = 0
  private var burstRemaining = 0

  init(weapon: Weapon) {
    precondition(weapon.capacity > 0 && weapon.reloadTime.isFinite && weapon.reloadTime > 0)
    self.weapon = weapon
    magazineRemaining = weapon.capacity
  }

  /// Shared by the leader and the companion firing rules. Their separate ammunition policy
  /// is checked by the caller: reloading neither spends nor creates the shared rounds.
  var isReady: Bool {
    isDrawn && drawRemaining <= 0 && cooldown <= 0 && reloadRemaining <= 0
      && magazineRemaining > 0
  }

  /// Advance exactly once per exploring step, including for a member who is not leading.
  /// Pause and application inactivity do not call this, so they cannot finish a reload.
  mutating func advance(dt: Float) {
    guard dt.isFinite, dt > 0 else { return }
    drawRemaining = max(0, drawRemaining - dt)
    cooldown = max(0, cooldown - dt)
    if reloadRemaining > 0 {
      reloadRemaining = max(0, reloadRemaining - dt)
      if reloadRemaining == 0 { magazineRemaining = weapon.capacity }
    }
  }

  /// A new draw starts once; holding aim or switching back does not restart its delay.
  mutating func draw() {
    guard !isDrawn else { return }
    isDrawn = true
    drawRemaining = weapon.drawTime
  }

  /// Release, a lost target or leadership change abandons the unfinished burst. Its ordinary
  /// recovery still applies, so rapidly tapping or switching cannot bypass a burst's interval.
  /// Releasing again changes neither the magazine nor its scheduled recovery/reload.
  mutating func releaseTrigger() {
    guard burstRemaining > 0 else { return }
    burstRemaining = 0
    cooldown = max(cooldown, weapon.interval)
  }

  /// Breaking contact cancels a burst and lowers the weapon without refilling or finishing a
  /// reload. Drawing it again uses the ordinary draw time.
  mutating func holster() {
    releaseTrigger()
    isDrawn = false
    drawRemaining = 0
  }

  /// Commit one actual discharge after the caller has checked readiness, aim and ammunition.
  /// An empty magazine starts reloading immediately, regardless of the shared pool; the
  /// caller's ammunition check still prevents a later shot when that pool is empty.
  mutating func fired() {
    guard isReady else { return }
    if burstRemaining == 0 { burstRemaining = max(1, weapon.burst) }
    burstRemaining -= 1
    magazineRemaining -= 1
    cooldown = burstRemaining > 0 ? weapon.burstGap : weapon.interval
    if magazineRemaining == 0 {
      burstRemaining = 0
      cooldown = weapon.interval
      reloadRemaining = weapon.reloadTime
    }
  }

  /// The click spends no round and starts no reload, but cannot be spammed to bypass cadence.
  mutating func emptyClick() {
    burstRemaining = 0
    cooldown = max(cooldown, weapon.interval)
  }
}
