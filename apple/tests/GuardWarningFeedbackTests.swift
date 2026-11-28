import AVFoundation
import Testing
import simd

@testable import Lauder

struct GuardWarningFeedbackTests {
  @Test(arguments: PartyMember.allCases)
  func aTargetWarningRetainsItsMemberAndPositionWithoutAWeaponHaptic(member: PartyMember) {
    let position = SIMD2<Float>(3, -7)
    let event = CombatEvent.guardTargeted(member, at: position)
    #expect(event.position == position)
    #expect(CombatSound.of(event) == .guardWarning)
    #expect(HapticCue.of(event) == nil)
    #expect(CombatSound.of(.hostileFired(.rifle, at: position)) == .rifle)
    #expect(CombatSound.of(.hostileFired(.shotgun, at: position)) == .shotgun)
    #expect(HapticCue.of(.hostileFired(.rifle, at: position)) == nil)
  }

  @Test
  func theBundledWarningIsTwoBriefNotesWithASilentGap() throws {
    let file = try AVAudioFile(forReading: #require(CombatSound.guardWarning.url))
    let format = file.processingFormat
    #expect(format.channelCount == 1 && format.sampleRate == 44100)
    let seconds = Double(file.length) / format.sampleRate
    #expect(seconds >= 0.3 && seconds <= 0.5)
    let buffer = try #require(
      AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)))
    try file.read(into: buffer)
    let samples = try #require(buffer.floatChannelData?[0])
    func energy(from start: Double, to end: Double) -> Float {
      let first = Int(start * format.sampleRate)
      let last = min(Int(end * format.sampleRate), Int(buffer.frameLength))
      guard last > first else { return 0 }
      return (first..<last).reduce(Float(0)) { $0 + samples[$1] * samples[$1] }
        / Float(last - first)
    }
    #expect(energy(from: 0.025, to: 0.075) > 0.01)
    #expect(energy(from: 0.12, to: 0.15) < 0.000001)
    #expect(energy(from: 0.18, to: 0.26) > 0.01)
    #expect(energy(from: 0.32, to: 0.355) < 0.000001)
  }
}
