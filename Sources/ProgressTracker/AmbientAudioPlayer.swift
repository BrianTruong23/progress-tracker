import AVFoundation
import Foundation

/// Generates a gentle looping soundscape locally, so Focus music works offline
/// without bundling copyrighted audio files or using a network connection.
@MainActor
final class AmbientAudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published var volume: Double = 0.35 {
        didSet { player?.volume = Float(volume) }
    }

    private var player: AVAudioPlayer?
    private let soundURL: URL

    init() {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProgressTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        soundURL = directory.appendingPathComponent("quiet-garden.wav")
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func play() {
        if player == nil {
            if !FileManager.default.fileExists(atPath: soundURL.path) {
                Self.createQuietGardenTrack(at: soundURL)
            }
            player = try? AVAudioPlayer(contentsOf: soundURL)
            player?.numberOfLoops = -1
            player?.volume = Float(volume)
            player?.prepareToPlay()
        }
        player?.play()
        isPlaying = player?.isPlaying == true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    nonisolated private static func createQuietGardenTrack(at url: URL) {
        let sampleRate = 22_050
        let duration = 32
        let sampleCount = sampleRate * duration
        let chords: [[Double]] = [
            [130.81, 164.81, 196.00, 261.63],
            [110.00, 130.81, 164.81, 220.00],
            [87.31, 130.81, 174.61, 220.00],
            [98.00, 146.83, 196.00, 246.94]
        ]
        var samples = [Int16](repeating: 0, count: sampleCount)
        var random: UInt64 = 0x5EED_1234
        var filteredNoise = 0.0

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let chordPosition = time / 8.0
            let chordIndex = Int(chordPosition) % chords.count
            let nextChord = (chordIndex + 1) % chords.count
            let localPosition = chordPosition - floor(chordPosition)
            let blend = max(0, min(1, (localPosition - 0.76) / 0.24))
            let smoothBlend = blend * blend * (3 - 2 * blend)

            func pad(_ frequencies: [Double]) -> Double {
                frequencies.enumerated().reduce(0) { partial, item in
                    let detune = item.offset.isMultiple(of: 2) ? 0.997 : 1.003
                    let fundamental = sin(2 * .pi * item.element * time)
                    let warmLayer = sin(2 * .pi * item.element * detune * time + Double(item.offset) * 0.7)
                    return partial + fundamental * 0.55 + warmLayer * 0.25
                } / Double(frequencies.count)
            }

            let currentPad = pad(chords[chordIndex])
            let nextPad = pad(chords[nextChord])
            let slowBreath = 0.72 + 0.20 * sin(2 * .pi * 0.07 * time)
            var signal = ((1 - smoothBlend) * currentPad + smoothBlend * nextPad) * 0.31 * slowBreath

            // Occasional soft bell notes make the loop feel musical without being distracting.
            let bellPhase = time.truncatingRemainder(dividingBy: 4.0)
            if bellPhase < 2.2 {
                let notes = [523.25, 440.00, 349.23, 392.00]
                let note = notes[Int(time / 4.0) % notes.count]
                let envelope = exp(-bellPhase * 2.25)
                signal += sin(2 * .pi * note * time) * envelope * 0.085
                signal += sin(2 * .pi * note * 2.01 * time) * envelope * 0.018
            }

            // Very quiet, filtered noise resembles distant leaves and masks hard digital edges.
            random = random &* 6_364_136_223_846_793_005 &+ 1
            let whiteNoise = Double(Int64(bitPattern: random) >> 33) / Double(Int32.max)
            filteredNoise = filteredNoise * 0.985 + whiteNoise * 0.015
            signal += filteredNoise * 0.035

            let edgeFade = min(1, min(time / 0.18, (Double(duration) - time) / 0.18))
            let clamped = max(-1, min(1, signal * edgeFade))
            samples[index] = Int16(clamped * Double(Int16.max))
        }

        var data = Data()
        func appendASCII(_ text: String) { data.append(text.data(using: .ascii)!) }
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }

        let byteCount = UInt32(samples.count * MemoryLayout<Int16>.size)
        appendASCII("RIFF")
        appendLE(UInt32(36) + byteCount)
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendLE(UInt32(16))
        appendLE(UInt16(1))
        appendLE(UInt16(1))
        appendLE(UInt32(sampleRate))
        appendLE(UInt32(sampleRate * 2))
        appendLE(UInt16(2))
        appendLE(UInt16(16))
        appendASCII("data")
        appendLE(byteCount)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        try? data.write(to: url, options: .atomic)
    }
}
