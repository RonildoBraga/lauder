import CoreGraphics
import Testing
import UIKit

@testable import Lauder

struct TouchOrderGeometryTests {
  @Test(arguments: [
    CGPoint(x: 200, y: 150), CGPoint(x: 200, y: 0), CGPoint(x: 200, y: 15),
    CGPoint(x: 200, y: 280), CGPoint(x: 0, y: 150), CGPoint(x: 380, y: 150),
  ])
  func everyDrawnItemSelectsItselfOutsideTheOriginalFingerReset(start: CGPoint) throws {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
    var opened = OrderPress(at: start, time: 0)
    let didOpen = opened.open(at: 1, in: bounds)
    #expect(didOpen)
    let layout = try #require(opened.menuLayout)
    #expect(bounds.contains(layout.frame))
    for choice in OrderPress.MenuLayout.choices {
      let frame = OrderPress.MenuLayout.itemFrame(choice).offsetBy(
        dx: layout.frame.minX, dy: layout.frame.minY)
      // Sample the whole rectangle, including the outer/lower Attack and Defend corners
      // which fell into the old angular companion sectors.
      for x in stride(from: frame.minX + 1, through: frame.maxX - 1, by: 8) {
        for y in stride(from: frame.minY + 1, through: frame.maxY - 1, by: 8) {
          var press = opened
          let point = CGPoint(x: x, y: y)
          let tap = press.end(at: point, time: 1.2)
          let expected: OrderPress.Choice =
            hypot(point.x - start.x, point.y - start.y) < OrderPress.centre ? .both : choice
          #expect(!tap && press.release == expected)
          #expect(press.start == start, "clamping never relocates the marked ground")
        }
      }
    }
  }

  @Test
  func theReviewedAttackPointAndDrawnBothUseTheirVisibleItems() {
    let start = CGPoint(x: 200, y: 150)
    var press = OrderPress(at: start, time: 0)
    let didOpen = press.open(at: 1, in: CGRect(x: 0, y: 0, width: 400, height: 300))
    #expect(didOpen)
    press.move(to: CGPoint(x: 90, y: 90))
    #expect(press.release == .attack, "offset (-110,-60) is inside drawn Attack")
    press.move(to: CGPoint(x: 170, y: 130))
    #expect(press.release == .both, "offset (-30,-20) is still inside drawn Both")
    press.move(to: CGPoint(x: 200, y: 90))
    #expect(press.release == nil, "straight up through the empty gap cancels")
    press.move(to: start)
    #expect(press.release == .both)
  }
}

@MainActor
struct TouchOrderSurfaceTests {
  @Test(
    arguments: [
      CGPoint(x: 350, y: 160), CGPoint(x: 350, y: 5), CGPoint(x: 350, y: 408),
      CGPoint(x: 5, y: 160), CGPoint(x: 920, y: 160),
    ], [OrderPress.Choice.both, .left, .right, .hold, .attack, .defend])
  func releasingOnTheActualClampedLabelSendsThatOrder(
    start: CGPoint, choice: OrderPress.Choice
  ) async throws {
    let (window, surface, controls) = try mountedSurface()
    defer {
      controls.setActive(false)
      withExtendedLifetime(window) {}
    }
    let touch = SurfaceTouch(in: surface, at: start, time: 1)
    surface.touchesBegan([touch], with: nil)
    try await Task.sleep(for: .milliseconds(400))
    let menu = try #require(
      surface.subviews.first { view in
        view.subviews.contains { ($0 as? UILabel)?.text == "Both" }
      })
    #expect(!menu.isHidden)
    #expect(surface.bounds.contains(menu.frame))
    let title: String =
      switch choice {
      case .both: "Both"
      case .left: "◀ Tom"
      case .right: "Laura ▶"
      case .hold: "Hold"
      case .attack: "↖ Attack"
      case .defend: "Defend ↗"
      }
    let label = try #require(
      menu.subviews.compactMap { $0 as? UILabel }.first { $0.text == title })
    let drawn = label.convert(label.bounds, to: surface).insetBy(dx: 1, dy: 1)
    let candidates = [
      CGPoint(x: drawn.midX, y: drawn.midY),
      CGPoint(x: drawn.minX, y: drawn.minY), CGPoint(x: drawn.maxX, y: drawn.minY),
      CGPoint(x: drawn.minX, y: drawn.maxY), CGPoint(x: drawn.maxX, y: drawn.maxY),
    ]
    let release = try #require(
      candidates.first { hypot($0.x - start.x, $0.y - start.y) >= OrderPress.centre })
    // No move callback: the UIKit release path must apply the final visible-item selection.
    touch.point = release
    touch.time = 1.2
    surface.touchesEnded([touch], with: nil)
    let input = controls.sample(mode: .exploring)
    #expect(input.command == choice.command)
    #expect(input.targetCommand == nil && !input.fireHeld)
    if choice == .attack || choice == .defend {
      #expect(input.commandPoint == nil)
    } else {
      let point = try #require(input.commandPoint)
      #expect(abs(point.x - Float(start.x / window.bounds.width)) < 0.00001)
      #expect(abs(point.y - Float(start.y / window.bounds.height)) < 0.00001)
    }
    #expect(menu.isHidden)
    #expect(controls.sample(mode: .exploring).command == nil)
  }

  @Test
  func aUIKitReleaseProducesOneTargetTapWithoutOpeningAnOrderMenu() throws {
    let (window, surface, controls) = try mountedSurface()
    defer {
      controls.setActive(false)
      withExtendedLifetime(window) {}
    }
    let touch = SurfaceTouch(in: surface, at: CGPoint(x: 350, y: 160), time: 1)
    surface.touchesBegan([touch], with: nil)
    touch.point = CGPoint(x: 354, y: 163)
    touch.time = 1.2
    surface.touchesEnded([touch], with: nil)
    let input = controls.sample(mode: .exploring)
    guard case .tap(let tap) = input.targetCommand else {
      Issue.record("the UIKit release did not emit its target tap")
      return
    }
    #expect(abs(tap.point.x - Float(354 / window.bounds.width)) < 0.00001)
    #expect(abs(tap.point.y - Float(163 / window.bounds.height)) < 0.00001)
    #expect(tap.viewHeight == Float(window.bounds.height))
    #expect(input.command == nil && !input.fireHeld && !input.firePressed)
    #expect(controls.sample(mode: .exploring).targetCommand == nil)
  }

  @Test(arguments: ["Fire", "Roll", "Swap to Assault rifle"], [false, true])
  func aCapturedWeaponButtonHidesOnReleaseInDialogueWithoutAnotherUpdate(
    title: String, cancelled: Bool
  ) throws {
    let (window, surface, controls) = try mountedSurface()
    defer {
      controls.setActive(false)
      withExtendedLifetime(window) {}
    }
    let zone = try #require(surface.subviews.first { $0.accessibilityLabel == title })
    let touch = SurfaceTouch(
      in: zone, at: CGPoint(x: zone.bounds.midX, y: zone.bounds.midY), time: 1)
    zone.touchesBegan([touch], with: nil)
    _ = controls.sample(mode: .exploring)
    update(surface, controls: controls, mode: .dialogue)
    #expect(!zone.isHidden, "a live capture remains mounted across the mode change")
    controls.requireNeutralInput()
    #expect(controls.sample(mode: .dialogue) == .neutral && controls.needsNeutralInput)
    if cancelled {
      zone.touchesCancelled([touch], with: nil)
    } else {
      zone.touchesEnded([touch], with: nil)
    }
    #expect(zone.isHidden, "release must refresh visibility without a SwiftUI update")
    #expect(controls.sample(mode: .dialogue) == .neutral && !controls.needsNeutralInput)
    #expect(!controls.sample(mode: .exploring).fireHeld)
  }

  private func mountedSurface() throws -> (UIWindow, TouchControls.Surface, GameControls) {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 926, height: 428)
    let controls = GameControls()
    controls.setActive(true)
    controls.useTouchControls()
    _ = controls.sample(mode: .exploring)
    let surface = TouchControls.Surface(controls: controls)
    surface.frame = window.bounds
    window.addSubview(surface)
    update(surface, controls: controls, mode: .exploring)
    surface.layoutIfNeeded()
    return (window, surface, controls)
  }

  private func update(
    _ surface: TouchControls.Surface, controls: GameControls, mode: GameSession.Mode
  ) {
    surface.update(
      actionTitle: "Look", nextLeaderName: "Tom", showsFire: true, swapTitle: "Assault rifle",
      showsFormation: true, formationTitle: "Formation", orderNames: ("Tom", "Laura"),
      vibrationTitle: "Vibration: On", panelTitle: "Status panel: On", mode: mode,
      generation: controls.touchGeneration)
  }
}

/// UIKit callbacks with explicit samples exercise the real capture owner and release path;
/// they do not establish physical touch or multi-touch acceptance.
@MainActor
private final class SurfaceTouch: UITouch {
  let source: UIView
  var point: CGPoint
  var time: TimeInterval

  init(in source: UIView, at point: CGPoint, time: TimeInterval) {
    self.source = source
    self.point = point
    self.time = time
    super.init()
  }

  override var timestamp: TimeInterval { time }

  override func location(in view: UIView?) -> CGPoint {
    source.convert(point, to: view)
  }
}
