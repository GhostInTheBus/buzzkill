// Synthesized sound: a wingbeat buzz while a fly is airborne (pitch follows
// flight effort, pan follows screen position) and a short wet splat on squish.
// Everything is generated in code — no audio assets.

import AVFoundation

final class FlySound {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var source: AVAudioSourceNode!
    private let lock = NSLock()
    // targets written by the render loop, smoothed on the audio thread
    private var tLevel: Float = 0, tPitch: Float = 1, tPan: Float = 0
    private var level: Float = 0, pitch: Float = 1
    private var phase: Float = 0, amPhase: Float = 0
    private var splatT: Float = -1          // seconds into the splat burst, <0 idle
    private var noiseState: UInt32 = 0x9E3779B9
    private var sampleRate: Float = 48_000
    private(set) var running = false

    init() {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: engine.outputNode.outputFormat(forBus: 0).sampleRate, channels: 1)!
        sampleRate = Float(fmt.sampleRate)
        source = AVAudioSourceNode(format: fmt) { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let self else { return noErr }
            let buf = UnsafeMutableAudioBufferListPointer(abl)
            guard let out = buf[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            self.render(out, Int(frameCount))
            return noErr
        }
        engine.attach(source); engine.attach(mixer)
        engine.connect(source, to: mixer, format: fmt)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        mixer.outputVolume = 0.14
    }

    func start() { guard !running else { return }; running = (try? engine.start()) != nil }
    func stop() { guard running else { return }; engine.stop(); running = false }

    /// level 0..1 (0 = silent), pitch multiplier (~0.8..1.6), pan -1..1
    func setBuzz(level: Float, pitch: Float, pan: Float) {
        lock.lock(); tLevel = level; tPitch = pitch; tPan = pan; lock.unlock()
    }
    func splat() { lock.lock(); splatT = 0; lock.unlock() }

    private func render(_ out: UnsafeMutablePointer<Float>, _ n: Int) {
        lock.lock()
        let gl = tLevel, gp = tPitch, pan = tPan
        var st = splatT
        lock.unlock()
        DispatchQueue.main.async { [weak self] in self?.mixer.pan = pan }
        let dt = 1 / sampleRate
        for i in 0..<n {
            // smooth toward targets (~30 ms)
            level += (gl - level) * 0.0007
            pitch += (gp - pitch) * 0.0007
            // wingbeat ~190 Hz: saw + 2nd harmonic, amplitude-modulated by a slow wobble
            let f = 190 * pitch
            phase += f * dt; if phase >= 1 { phase -= 1 }
            amPhase += 6.5 * dt; if amPhase >= 1 { amPhase -= 1 }
            let saw = 2 * phase - 1
            let h2 = sinf(2 * .pi * phase * 2) * 0.35
            let wobble = 0.75 + 0.25 * sinf(2 * .pi * amPhase)
            var s = (saw * 0.6 + h2) * wobble * level * 0.5
            // splat: 90 ms of decaying noise + a 95 Hz thud
            if st >= 0 {
                noiseState = noiseState &* 1664525 &+ 1013904223
                let noise = Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
                let env = expf(-st * 38)
                s += (noise * 0.55 + sinf(2 * .pi * 95 * st) * 0.6) * env * 0.9
                st += dt
                if st > 0.25 { st = -1 }
            }
            out[i] = max(-1, min(1, s))
        }
        lock.lock(); if splatT >= 0 { splatT = st }; lock.unlock()
    }
}
