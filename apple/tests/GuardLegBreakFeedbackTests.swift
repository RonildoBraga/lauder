import AVFoundation
import Testing
import simd

@testable import Lauder

struct GuardLegBreakFeedbackTests {
  @Test
  func aBrokenLegHasItsOwnPositionalSoundWithoutAWeaponHaptic() {
    let position = SIMD2<Float>(-4, 9)
    let event = CombatEvent.guardLegBroken(at: position)
    #expect(event.position == position)
    #expect(CombatSound.of(event) == .guardLegBreak)
    #expect(HapticCue.of(event) == nil)
    #expect(CombatSound.of(.struckBlock(at: position)) == .strikeBlock)
    #expect(CombatSound.of(.guardTargeted(.miki, at: position)) == .guardWarning)
  }

  @Test
  func theBundledJointCrackIsBriefWithHeadroomAndAQuietTail() throws {
    let file = try AVAudioFile(forReading: #require(CombatSound.guardLegBreak.url))
    let format = file.processingFormat
    #expect(file.fileFormat.channelCount == 1 && file.fileFormat.sampleRate == 44100)
    #expect(file.fileFormat.commonFormat == .pcmFormatInt16)
    let seconds = Double(file.length) / format.sampleRate
    #expect(seconds >= 0.3 && seconds <= 0.6)
    let buffer = try #require(
      AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)))
    try file.read(into: buffer)
    let samples = try #require(buffer.floatChannelData?[0])
    let count = Int(buffer.frameLength)
    let peak = (0..<count).reduce(Float(0)) { max($0, abs(samples[$1])) }
    #expect(peak > 0.5 && peak < 0.9)
    func energy(from start: Double, to end: Double) -> Float {
      let first = Int(start * format.sampleRate)
      let last = min(Int(end * format.sampleRate), count)
      guard last > first else { return 0 }
      return (first..<last).reduce(Float(0)) { $0 + samples[$1] * samples[$1] }
        / Float(last - first)
    }
    let attack = energy(from: 0, to: 0.05)
    #expect(attack > 0.02)
    #expect(energy(from: 0.05, to: 0.12) > 0.0001)
    #expect(energy(from: 0.32, to: seconds) < attack * 0.001)
    #expect(abs(samples[0]) < 0.0001 && abs(samples[count - 1]) < 0.0001)
  }
}
