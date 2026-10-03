// Camera sense: sudden movement in front of the webcam, reported as where it
// is (centroid, normalized, mirrored so your right is screen right) and how
// much of the frame is moving. Plain frame differencing on a 64x48 sample —
// no face or hand model, so anything counts: a hand, a head, a cat. Frames
// are compared and dropped; nothing is stored or transmitted. Opt-in from the
// menu — this is the one sense that needs a permission.

import AVFoundation

final class CameraSense: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Called on the capture queue: motion centroid (0..1, origin bottom-left,
    /// x mirrored) and the moving fraction of the frame scaled to ~0..1; nil/0
    /// when nothing moves.
    var onHand: ((CGPoint?, CGFloat) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "buzzkill.camera", qos: .userInitiated)
    private var configured = false
    private var frameCount = 0
    private let gw = 64, gh = 48
    private var prev: [UInt8]?
    private let debug = ProcessInfo.processInfo.environment["DESKTOPFLY_CAMERA_DEBUG"] != nil
    private var dbgMax: CGFloat = 0, dbgFrames = 0

    static var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }
    static func requestAccess(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { ok in DispatchQueue.main.async { done(ok) } }
    }

    /// Configures and starts the camera off the main thread (device setup can
    /// block while the system permission prompt is up — never do it on main).
    /// `done(false)` on the main thread if no usable camera could be configured.
    func start(_ done: @escaping (Bool) -> Void) {
        queue.async {
            if !self.configured {
                // prefer the built-in camera over virtual ones (OBS etc.)
                guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                        ?? AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: dev) else { DispatchQueue.main.async { done(false) }; return }
                self.session.beginConfiguration()
                self.session.sessionPreset = .vga640x480
                guard self.session.canAddInput(input) else { self.session.commitConfiguration(); DispatchQueue.main.async { done(false) }; return }
                self.session.addInput(input)
                let out = AVCaptureVideoDataOutput()
                out.alwaysDiscardsLateVideoFrames = true
                out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                out.setSampleBufferDelegate(self, queue: self.queue)
                guard self.session.canAddOutput(out) else { self.session.commitConfiguration(); DispatchQueue.main.async { done(false) }; return }
                self.session.addOutput(out)
                self.session.commitConfiguration()
                self.configured = true
            }
            self.prev = nil
            self.session.startRunning()
            DispatchQueue.main.async { done(true) }
        }
    }

    func stop() {
        queue.async { self.session.stopRunning(); self.prev = nil }
        onHand?(nil, 0)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCount += 1
        if frameCount % 2 != 0 { return }   // ~15 Hz is plenty for a swat
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        let stride = CVPixelBufferGetBytesPerRow(pb)
        let px = base.assumingMemoryBound(to: UInt8.self)

        // luminance on a coarse grid
        var cur = [UInt8](repeating: 0, count: gw * gh)
        for gy in 0..<gh {
            let y = gy * h / gh
            for gx in 0..<gw {
                let x = gx * w / gw
                let o = y * stride + x * 4
                // BGRA -> approx luma
                cur[gy * gw + gx] = UInt8((Int(px[o]) * 29 + Int(px[o + 1]) * 150 + Int(px[o + 2]) * 77) >> 8)
            }
        }
        defer { prev = cur }
        guard let p = prev else { return }

        // changed cells: count + centroid
        var n = 0, sx = 0, sy = 0
        for i in 0..<(gw * gh) where abs(Int(cur[i]) - Int(p[i])) > 28 {
            n += 1; sx += i % gw; sy += i / gw
        }
        let frac = CGFloat(n) / CGFloat(gw * gh)
        if debug {
            dbgMax = max(dbgMax, frac); dbgFrames += 1
            if dbgFrames >= 15 { fputs(String(format: "camera motion: max %.3f of frame this second\n", dbgMax), stderr); dbgMax = 0; dbgFrames = 0 }
        }
        guard frac > 0.004 else { onHand?(nil, 0); return }   // sensor noise floor
        // mirror x; Vision-style origin bottom-left (grid row 0 is the top)
        let c = CGPoint(x: 1 - CGFloat(sx) / CGFloat(n) / CGFloat(gw), y: 1 - CGFloat(sy) / CGFloat(n) / CGFloat(gh))
        // a hand wave is ~5-15% of the frame; a lunge at the screen, 30%+
        onHand?(c, min(1, frac * 4))
    }
}
