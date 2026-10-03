// Hearing: sound primes the escape circuit. Loud moments — typing bursts
// (permission-free; the app already senses keystrokes) or, opt-in, the
// microphone — push a small sub-threshold current into the Giant Fiber and
// the wind-sensory neurons. Primed, the fly bolts at a slower approach, so
// you stalk quietly. The mic path is level-only: an RMS number per buffer,
// adaptive to room noise; no audio is kept.

import AVFoundation
import CoreAudio

private func audioTransport(of id: AudioDeviceID) -> UInt32 {
    var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                       mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var t: UInt32 = 0; var s = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(id, &a, 0, nil, &s, &t)
    return t
}
private func hasInput(_ id: AudioDeviceID) -> Bool {
    var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                       mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
    var s: UInt32 = 0
    return AudioObjectGetPropertyDataSize(id, &a, 0, nil, &s) == noErr && s > 0
}
/// The Mac's own microphone, if it has one.
private func builtInInputDevice() -> AudioDeviceID? {
    var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                       mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    let sys = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr, size > 0 else { return nil }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(sys, &a, 0, nil, &size, &ids) == noErr else { return nil }
    return ids.first { hasInput($0) && audioTransport(of: $0) == kAudioDeviceTransportTypeBuiltIn }
}
private func defaultInputDevice() -> AudioDeviceID? {
    var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                       mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var id = AudioDeviceID(0); var s = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &s, &id) == noErr, id != 0 else { return nil }
    return id
}

final class Hearing {
    /// 0..1 how loud the room is above its own ambient floor. Read from the render loop.
    private(set) var level: Float = 0
    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var floorDb: Float = -60       // slow estimate of the quiet level
    private(set) var running = false
    /// True when start was refused because the only input is Bluetooth (opening
    /// it would drop AirPods to call quality).
    private(set) var refusedBluetooth = false

    static var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }
    static func requestAccess(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { ok in DispatchQueue.main.async { done(ok) } }
    }

    private let queue = DispatchQueue(label: "buzzkill.hearing")

    /// Starts the mic tap off the main thread; `done(ok)` on main.
    func start(_ done: @escaping (Bool) -> Void) {
        if running { done(true); return }
        queue.async {
            let ok = self.startNow()
            DispatchQueue.main.async { done(ok) }
        }
    }

    private func startNow() -> Bool {
        let eng = AVAudioEngine()
        let input = eng.inputNode
        // Use the Mac's own mic regardless of the system default. If there isn't
        // one and the default input is Bluetooth, refuse rather than degrade it.
        refusedBluetooth = false
        if let dev = builtInInputDevice() {
            try? input.auAudioUnit.setDeviceID(dev)
        } else if let d = defaultInputDevice(),
                  [kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE].contains(audioTransport(of: d)) {
            refusedBluetooth = true
            return false
        }
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
