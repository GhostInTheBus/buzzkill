// Hearing: sound primes the escape circuit. Loud moments — typing bursts
// (permission-free; the app already senses keystrokes) or, opt-in, the
// microphone — push a small sub-threshold current into the Giant Fiber and
// the wind-sensory neurons. Primed, the fly bolts at a slower approach, so
// you stalk quietly. The mic path is level-only: an RMS number per buffer,
// adaptive to room noise; no audio is kept.

import AVFoundation

final class Hearing {
    /// 0..1 how loud the room is above its own ambient floor. Read from the render loop.
    private(set) var level: Float = 0
    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var floorDb: Float = -60       // slow estimate of the quiet level
    private(set) var running = false

    static var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }
    static func requestAccess(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { ok in DispatchQueue.main.async { done(ok) } }
    }

    func start() -> Bool {
        guard !running else { return true }
        let eng = AVAudioEngine()
        let input = eng.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.channelCount > 0 else { return false }
        input.installTap(onBus: 0, bufferSize: 2048, format: fmt) { [weak self] buf, _ in
            guard let self, let ch = buf.floatChannelData?[0] else { return }
            let n = Int(buf.frameLength); guard n > 0 else { return }
            var sum: Float = 0
            for i in 0..<n { sum += ch[i] * ch[i] }
            let db = 10 * log10f(max(1e-9, sum / Float(n)))
            self.lock.lock()
            // the floor follows quiet quickly and loudness very slowly
            self.floorDb += (db - self.floorDb) * (db < self.floorDb ? 0.2 : 0.005)
            let above = db - self.floorDb
            // 10 dB over ambient starts to register; 30 dB over is a shout
            let target = max(0, min(1, (above - 10) / 20))
            self.level += (target - self.level) * (target > self.level ? 0.5 : 0.15)
            self.lock.unlock()
        }
        do { try eng.start() } catch { input.removeTap(onBus: 0); return false }
        engine = eng; running = true
        return true
    }

    func stop() {
        guard running, let eng = engine else { return }
        eng.inputNode.removeTap(onBus: 0)
        eng.stop()
        engine = nil; running = false
        lock.lock(); level = 0; lock.unlock()
    }

    func read() -> Float { lock.lock(); defer { lock.unlock() }; return level }
}
