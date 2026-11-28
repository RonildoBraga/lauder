import Testing
import UIKit
import simd

@testable import Lauder

struct TouchInputTests {
  @Test
  func stickClampsMagnitudeAndInvertsScreenY() {
    #expect(TouchInput.movement(displacement: [0, -20], radius: 40) == [0, 0.5])
    #expect(TouchInput.movement(displacement: [40, 0], radius: 40) == [1, 0])
    let diagonal = TouchInput.movement(displacement: [80, 80], radius: 40)
    #expect(abs(simd_length(diagonal) - 1) < 0.00001)
    #expect(diagonal.x > 0 && diagonal.y < 0)
    #expect(TouchInput.movement(displacement: [.nan, 1], radius: 40) == .zero)
    #expect(TouchInput.movement(displacement: [1, 1], radius: 0) == .zero)
  }

  @Test
  func liftingOneFingerDoesNotReleaseOtherControls() {
    var touch = TouchInput()
    touch.setStick([0.5, 0], isTouching: true, generation: 0)
    touch.setButton(.guardAction, isPressed: true, generation: 0)
    touch.setButton(.attack, isPressed: true, generation: 0)
    _ = touch.sample()
    touch.setButton(.attack, isPressed: false, generation: 0)
    let movingGuard = touch.sample()
    #expect(movingGuard.touchStick == [0.5, 0] && movingGuard.touchIsTouching)
    #expect(movingGuard.touchGuard && !movingGuard.touchAttack)
    touch.setStick(.zero, isTouching: false, generation: 0)
    let guardOnly = touch.sample()
    #expect(guardOnly.touchGuard && !guardOnly.touchIsTouching)
  }

  @Test(arguments: TouchInput.Button.allCases)
  func quickTapsSurviveBetweenUpdatesOnce(button: TouchInput.Button) {
    var touch = TouchInput()
    touch.setButton(button, isPressed: true, generation: 0)
    touch.setButton(button, isPressed: false, generation: 0)
    #expect(touch.sample().hasTouchInput)
    #expect(touch.sample() == .init())
  }

  @Test
  func cancellationDropsQueuedInputAndRejectsOldCaptures() {
    var touch = TouchInput()
    touch.setStick([1, 0], isTouching: true, generation: 0)
    touch.setButton(.attack, isPressed: true, generation: 0)
    touch.cancel()
    #expect(touch.generation == 1)
    touch.setStick([1, 0], isTouching: true, generation: 0)
    touch.setButton(.attack, isPressed: true, generation: 0)
    #expect(touch.sample() == .init())
    touch.setStick(.zero, isTouching: true, generation: 1)
    #expect(touch.sample().touchIsTouching)
    touch.setButton(.guardAction, isPressed: true, generation: 1)
    #expect(touch.sample().touchGuard)
    touch.cancel()
    touch.setButton(.guardAction, isPressed: false, generation: 1)
    #expect(touch.sample() == .init())
  }

  @MainActor
  @Test
  func surfaceHasThreeCombatActionsAndSeparatePauseRestartTargets() throws {
    let controls = GameControls()
    let surface = TouchControls.Surface(controls: controls)
    surface.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
    surface.update(mode: .exploring, generation: controls.touchGeneration)
    surface.layoutIfNeeded()
    let visible = surface.subviews.filter { !$0.isHidden }
    #expect(
      Set(visible.compactMap(\.accessibilityLabel)) == [
        "Move", "Attack", "Guard", "Dodge", "Pause",
      ])
    #expect(visible.allSatisfy { $0.bounds.width >= 44 && $0.bounds.height >= 44 })
    #expect(surface.hitTest(CGPoint(x: 422, y: 195), with: nil) == nil)
    surface.update(mode: .paused, generation: controls.touchGeneration)
    let paused = surface.subviews.filter { !$0.isHidden }
    #expect(Set(paused.compactMap(\.accessibilityLabel)) == ["Move", "Resume", "Restart"])
    let restart = try #require(paused.first { $0.accessibilityLabel == "Restart" })
    let resume = try #require(paused.first { $0.accessibilityLabel == "Resume" })
    #expect(!restart.frame.intersects(resume.frame))
  }
}
