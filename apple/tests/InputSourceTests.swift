import Testing

@testable import Lauder

@MainActor
struct InputSourceTests {
  @Test
  func pauseNeutralGateKeepsActualCentredTouchUntilLift() {
    let controls = GameControls()
    controls.setActive(true)
    controls.useTouchControls()
    defer { controls.setActive(false) }
    let generation = controls.touchGeneration
    _ = controls.sample(mode: .exploring)
    controls.setTouchStick(.zero, isTouching: true, generation: generation)
    controls.requireNeutralInput()
    #expect(controls.sample(mode: .paused) == .neutral)
    #expect(controls.needsNeutralInput)
    controls.setTouchStick(.zero, isTouching: false, generation: generation)
    _ = controls.sample(mode: .paused)
    #expect(!controls.needsNeutralInput)
  }

  @Test
  func lifecycleChangeCancelsTouchAndRejectsTheOldGeneration() {
    let controls = GameControls()
    controls.setActive(true)
    controls.useTouchControls()
    let oldGeneration = controls.touchGeneration
    _ = controls.sample(mode: .exploring)
    controls.setTouchButton(.attack, isPressed: true, generation: oldGeneration)
    controls.setActive(false)
    #expect(controls.status == .inactive)
    #expect(controls.touchGeneration > oldGeneration)
    controls.setActive(true)
    controls.useTouchControls()
    defer { controls.setActive(false) }
    controls.setTouchButton(.attack, isPressed: true, generation: oldGeneration)
    #expect(controls.sample(mode: .exploring) == .neutral)
    #expect(!controls.needsNeutralInput)
    #expect(controls.sample(mode: .exploring) == .neutral)
    let fresh = controls.touchGeneration
    controls.setTouchButton(.attack, isPressed: true, generation: fresh)
    #expect(controls.sample(mode: .exploring).attackPressed)
    #expect(!controls.sample(mode: .exploring).attackPressed)
  }

  @Test
  func inactiveTouchCannotCreateAnActionOnActivation() {
    let controls = GameControls()
    controls.setTouchButton(.attack, isPressed: true, generation: controls.touchGeneration)
    controls.setActive(true)
    controls.useTouchControls()
    defer { controls.setActive(false) }
    #expect(controls.sample(mode: .exploring) == .neutral)
    #expect(!controls.needsNeutralInput)
    #expect(controls.sample(mode: .exploring) == .neutral)
  }

  @Test
  func aHeldFocusContactPreventsPauseNeutralityUntilItsOwnRelease() {
    let controls = GameControls()
    controls.setActive(true)
    controls.useTouchControls()
    defer { controls.setActive(false) }
    let generation = controls.touchGeneration
    _ = controls.sample(mode: .exploring)
    controls.setTouchStick(.zero, isTouching: true, generation: generation)
    controls.setTouchButton(.focus, isPressed: true, generation: generation)
    controls.requireNeutralInput()
    #expect(controls.sample(mode: .paused) == .neutral)
    controls.setTouchStick(.zero, isTouching: false, generation: generation)
    #expect(controls.sample(mode: .paused) == .neutral)
    #expect(controls.needsNeutralInput, "Focus still owns its separate finger")
    controls.setTouchButton(.focus, isPressed: false, generation: generation)
    _ = controls.sample(mode: .paused)
    #expect(!controls.needsNeutralInput)
    #expect(controls.sample(mode: .exploring) == .neutral)
    controls.setTouchButton(.focus, isPressed: true, generation: generation)
    #expect(controls.sample(mode: .exploring).focusPressed)
    #expect(!controls.sample(mode: .exploring).focusPressed)
  }

  @Test
  func lifecycleCancellationRejectsOldFocusCapturesAndAcceptsOneFreshTap() {
    let controls = GameControls()
    controls.setActive(true)
    controls.useTouchControls()
    let oldGeneration = controls.touchGeneration
    _ = controls.sample(mode: .exploring)
    controls.setTouchButton(.focus, isPressed: true, generation: oldGeneration)
    controls.setActive(false)
    controls.setActive(true)
    controls.useTouchControls()
    defer { controls.setActive(false) }
    controls.setTouchButton(.focus, isPressed: true, generation: oldGeneration)
    #expect(controls.sample(mode: .exploring) == .neutral)
    #expect(!controls.needsNeutralInput)
    #expect(controls.sample(mode: .exploring) == .neutral)
    let generation = controls.touchGeneration
    controls.setTouchButton(.focus, isPressed: true, generation: generation)
    controls.setTouchButton(.focus, isPressed: false, generation: generation)
    #expect(controls.sample(mode: .exploring).focusPressed)
    #expect(controls.sample(mode: .exploring) == .neutral)
  }
}
