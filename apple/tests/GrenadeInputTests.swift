import Testing
import UIKit

@testable import Lauder

struct GrenadeInputTests {
  @Test(arguments: [
    InputRules.Raw(controllerGrenade: true), .init(keyboardGrenade: true),
    .init(touchGrenade: true),
  ])
  func eachSourceThrowsOnceUntilReleased(raw: InputRules.Raw) {
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(raw, state: &state).grenadePressed)
    #expect(!sample(raw, state: &state).grenadePressed)
    #expect(!sample(.init(), state: &state).grenadePressed)
    #expect(sample(raw, state: &state).grenadePressed)
  }

  @Test(arguments: [GameSession.Mode.paused, .dialogue])
  func inactiveModesConsumeTheThrowInsteadOfReplayingIt(mode: GameSession.Mode) {
    var state = InputRules.State(needsNeutralInput: false)
    let raw = InputRules.Raw(touchGrenade: true)
    #expect(!sample(raw, mode: mode, state: &state).grenadePressed)
    #expect(!sample(raw, state: &state).grenadePressed)
    _ = sample(.init(), state: &state)
    #expect(sample(raw, state: &state).grenadePressed)
  }

  @Test(arguments: [
    InputRules.Raw(controllerGrenade: true), .init(keyboardGrenade: true),
    .init(touchGrenade: true),
  ])
  func aHeldGrenadeKeepsTheNeutralGateUntilReleased(raw: InputRules.Raw) {
    var state = InputRules.State()
    #expect(sample(raw, state: &state) == .neutral && state.needsNeutralInput)
    #expect(sample(raw, state: &state) == .neutral && state.needsNeutralInput)
    #expect(sample(.init(), state: &state) == .neutral && !state.needsNeutralInput)
    #expect(sample(raw, state: &state).grenadePressed)
  }

  @Test(arguments: [
    InputRules.Raw(controllerPause: true), .init(controllerSwitch: true),
    .init(touchSwitch: true), .init(controllerFormation: true), .init(dpadUp: true),
    .init(dpadDown: true), .init(dpadLeft: true), .init(dpadRight: true),
    .init(controllerSwap: true), .init(touchSwap: true), .init(controllerDodge: true),
    .init(touchDodge: true), .init(controllerLock: true),
    .init(touchTarget: .acquire),
  ])
  func higherPriorityInputsConsumeASimultaneousThrow(other: InputRules.Raw) {
    var state = InputRules.State(needsNeutralInput: false)
    var raw = other
    raw.touchGrenade = true
    #expect(!sample(raw, state: &state).grenadePressed)
    #expect(!sample(.init(touchGrenade: true), state: &state).grenadePressed)
    _ = sample(.init(), state: &state)
    #expect(sample(.init(touchGrenade: true), state: &state).grenadePressed)
  }

  @Test
  func aThrowRequestPreservesCombatInputsUntilGameplayChecksItsAvailability() {
    var state = InputRules.State(needsNeutralInput: false)
    let raw = InputRules.Raw(
      touchStick: [0.4, 0.2], touchIsTouching: true, touchAction: true,
      touchFire: true, touchGrenade: true)
    let input = sample(raw, state: &state)
    #expect(input.grenadePressed && input.movement == [0.4, 0.2])
    #expect(input.fireHeld && input.firePressed && input.actionPressed)
    #expect(!input.dodgePressed && !input.swapPressed && !input.switchPressed)
    #expect(!sample(raw, state: &state).grenadePressed)
  }

  @Test
  func touchTapsLatchOnceAndCancellationDropsOldGenerations() {
    var touch = TouchInput()
    touch.setStick([0.5, 0], isTouching: true, generation: 0)
    touch.setButton(.grenade, isPressed: true, generation: 0)
    touch.setButton(.grenade, isPressed: false, generation: 0)
    let raw = touch.sample()
    #expect(raw.touchGrenade && raw.touchIsTouching && raw.touchStick == [0.5, 0])
    #expect(!touch.sample().touchGrenade)
    touch.setButton(.grenade, isPressed: true, generation: 0)
    touch.cancel()
    touch.setButton(.grenade, isPressed: true, generation: 0)
    touch.setButton(.grenade, isPressed: false, generation: 0)
    #expect(touch.sample() == .init())
    touch.setButton(.grenade, isPressed: true, generation: touch.generation)
    #expect(touch.sample().touchGrenade)
  }

  @Test
  func grenadeButtonsParticipateInSourceDetectionWithoutStealingOrderKeys() {
    #expect(InputRules.Raw(controllerGrenade: true).hasControllerInput)
    #expect(!InputRules.Raw(controllerGrenade: true).hasKeyboardInput)
    #expect(InputRules.Raw(keyboardGrenade: true).hasKeyboardInput)
    #expect(!InputRules.Raw(keyboardGrenade: true).hasControllerInput)
    #expect(!InputRules.Raw(touchGrenade: true).hasControllerInput)
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(.init(keyboardBothGo: true), state: &state).command == .bothGo)
    _ = sample(.init(), state: &state)
    #expect(sample(.init(keyboardHold: true), state: &state).command == .hold)
  }

  @Test
  func releasingTheGrenadeDoesNotClearAStillCentredStickContact() {
    var touch = TouchInput()
    touch.setStick(.zero, isTouching: true, generation: 0)
    touch.setButton(.grenade, isPressed: true, generation: 0)
    var state = InputRules.State()
    #expect(sample(touch.sample(), state: &state) == .neutral && state.needsNeutralInput)
    touch.setButton(.grenade, isPressed: false, generation: 0)
    #expect(sample(touch.sample(), state: &state) == .neutral && state.needsNeutralInput)
    touch.setStick(.zero, isTouching: false, generation: 0)
    #expect(sample(touch.sample(), state: &state) == .neutral && !state.needsNeutralInput)
    touch.setButton(.grenade, isPressed: true, generation: 0)
    #expect(sample(touch.sample(), state: &state).grenadePressed)
  }

  private func sample(
    _ raw: InputRules.Raw, mode: GameSession.Mode = .exploring, state: inout InputRules.State
  ) -> InputRules.Input {
    let result = InputRules.resolve(raw, mode: mode, state: state)
    state = result.state
    return result.input
  }
}

@MainActor
struct GrenadeSurfaceTests {
  @Test(arguments: [CGFloat(832), 874, 926])
  func theNewButtonKeepsExistingFramesAndDoesNotOverlapThem(width: CGFloat) throws {
    let (surface, controls, grenade) = try fixture(width: width)
    defer { controls.setActive(false) }
    let roll = try #require(surface.subviews.first { $0.accessibilityLabel == "Roll" })
    let formation = try #require(surface.subviews.first { $0.accessibilityLabel == "Formation" })
    let fire = try #require(surface.subviews.first { $0.accessibilityLabel == "Fire" })
    #expect(
      grenade.frame == CGRect(x: roll.frame.minX, y: formation.frame.minY, width: 112, height: 52))
    #expect(fire.frame == CGRect(x: width - 252, y: 360, width: 112, height: 52))
    #expect(surface.bounds.contains(grenade.frame))
    for other in surface.subviews where other !== grenade && other.isAccessibilityElement {
      #expect(!grenade.frame.intersects(other.frame))
    }
    #expect(grenade.accessibilityActivate())
    #expect(controls.sample(mode: .exploring).grenadePressed)
    #expect(!controls.sample(mode: .exploring).grenadePressed)
  }

  @Test(arguments: [GameSession.Mode.paused, .dialogue], [false, true])
  func aCapturedGrenadeSurvivesTheGateAndHidesOnLiftWithoutAnotherRedraw(
    mode: GameSession.Mode, cancelled: Bool
  ) throws {
    let (surface, controls, grenade) = try fixture()
    defer { controls.setActive(false) }
    let touch = GrenadeTouch(in: grenade)
    grenade.touchesBegan([touch], with: nil)
    #expect(controls.sample(mode: .exploring).grenadePressed)
    update(surface, controls: controls, mode: mode, showsGrenade: false)
    #expect(!grenade.isHidden)
    controls.requireNeutralInput()
    #expect(controls.sample(mode: mode) == .neutral && controls.needsNeutralInput)
    if cancelled {
      grenade.touchesCancelled([touch], with: nil)
    } else {
      grenade.touchesEnded([touch], with: nil)
    }
    #expect(grenade.isHidden)
    #expect(controls.sample(mode: mode) == .neutral && !controls.needsNeutralInput)
    #expect(!controls.sample(mode: .exploring).grenadePressed)
  }

  @Test
  func switchingAwayFromTomPreservesCaptureUntilLiftAndDoesNotReplayIt() throws {
    let (surface, controls, grenade) = try fixture()
    defer { controls.setActive(false) }
    let touch = GrenadeTouch(in: grenade)
    grenade.touchesBegan([touch], with: nil)
    #expect(controls.sample(mode: .exploring).grenadePressed)
    update(surface, controls: controls, showsGrenade: false)
    #expect(!grenade.isHidden)
    #expect(!controls.sample(mode: .exploring).grenadePressed)
    grenade.touchesEnded([touch], with: nil)
    #expect(grenade.isHidden)
    #expect(!controls.sample(mode: .exploring).grenadePressed)
    update(surface, controls: controls, showsGrenade: true)
    #expect(!grenade.isHidden)
    #expect(!controls.sample(mode: .exploring).grenadePressed)
    #expect(grenade.accessibilityActivate())
    #expect(controls.sample(mode: .exploring).grenadePressed)
  }

  @Test
  func cancelledSourceRejectsTheOldFingerAndRequiresFreshInput() throws {
    let (surface, controls, grenade) = try fixture()
    defer { controls.setActive(false) }
    let touch = GrenadeTouch(in: grenade)
    grenade.touchesBegan([touch], with: nil)
    _ = controls.sample(mode: .exploring)
    controls.setActive(false)
    controls.setActive(true)
    controls.useTouchControls()
    update(surface, controls: controls)
    grenade.touchesEnded([touch], with: nil)
    #expect(controls.sample(mode: .exploring) == .neutral && !controls.needsNeutralInput)
    #expect(!controls.sample(mode: .exploring).grenadePressed)
    #expect(grenade.accessibilityActivate())
    #expect(controls.sample(mode: .exploring).grenadePressed)
  }

  private func fixture(width: CGFloat = 926)
    throws -> (TouchControls.Surface, GameControls, UIView)
  {
    let controls = GameControls()
    controls.setActive(true)
    controls.useTouchControls()
    _ = controls.sample(mode: .exploring)
    let surface = TouchControls.Surface(controls: controls)
    surface.frame = CGRect(x: 0, y: 0, width: width, height: 428)
    update(surface, controls: controls)
    surface.layoutIfNeeded()
    let grenade = try #require(surface.subviews.first { $0.accessibilityLabel == "Grenade" })
    return (surface, controls, grenade)
  }

  private func update(
    _ surface: TouchControls.Surface, controls: GameControls,
    mode: GameSession.Mode = .exploring, showsGrenade: Bool = true
  ) {
    surface.update(
      actionTitle: "Look", nextLeaderName: "Miki", showsFire: true, swapTitle: "Shield",
      showsFormation: true, formationTitle: "Formation", orderNames: ("Miki", "Laura"),
      vibrationTitle: "Vibration: On", panelTitle: "Status panel: On", mode: mode,
      generation: controls.touchGeneration, grenadeTitle: "Grenade ready",
      showsGrenade: showsGrenade)
  }
}

@MainActor
private final class GrenadeTouch: UITouch {
  let source: UIView

  init(in source: UIView) {
    self.source = source
    super.init()
  }

  override func location(in view: UIView?) -> CGPoint {
    source.convert(CGPoint(x: source.bounds.midX, y: source.bounds.midY), to: view)
  }
}
