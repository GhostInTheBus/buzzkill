// Camera sense: a hand in front of the webcam, reported as a position on the
// fly's plane plus how much of the frame it fills (a hand lunging at the
// screen grows fast). Frames are analyzed on-device with Vision's hand-pose
// detector and dropped; nothing is stored or transmitted. Opt-in from the
// menu — this is the one sense that needs a permission.

import AVFoundation
import Vision

final class CameraSense: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Called on the capture queue with the most prominent hand: normalized
    /// point (0..1, origin bottom-left, x mirrored so your right is screen
    /// right) and its normalized bounding-box diagonal; nil/0 when no hand.
    var onHand: ((CGPoint?, CGFloat) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "desktopfly.camera", qos: .userInitiated)
    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()
    private var frameCount = 0
    private var configured = false

    static var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }
    static func requestAccess(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { ok in DispatchQueue.main.async { done(ok) } }
    }

    /// Returns false if no usable camera could be configured.
    func start() -> Bool {
        if !configured {
            // prefer the built-in camera over virtual ones (OBS etc.)
            guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                    ?? AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: dev) else { return false }
            session.beginConfiguration()
            session.sessionPreset = .vga640x480   // plenty for a hand; cheap
            guard session.canAddInput(input) else { session.commitConfiguration(); return false }
            session.addInput(input)
            let out = AVCaptureVideoDataOutput()
            out.alwaysDiscardsLateVideoFrames = true
            out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            out.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(out) else { session.commitConfiguration(); return false }
            session.addOutput(out)
            session.commitConfiguration()
            configured = true
        }
        queue.async { self.session.startRunning() }
        return true
    }

    func stop() {
        queue.async { self.session.stopRunning() }
        onHand?(nil, 0)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCount += 1
        if frameCount % 2 != 0 { return }   // ~15 Hz is enough to catch a swat
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: .up, options: [:])
        try? handler.perform([request])
        var best: (CGPoint, CGFloat)? = nil
        for obs in request.results ?? [] {
            guard let pts = try? obs.recognizedPoints(.all) else { continue }
            let good = pts.values.filter { $0.confidence > 0.3 }
            guard good.count >= 4 else { continue }
            var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0, sx = 0.0, sy = 0.0
            for p in good {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
                sx += p.x; sy += p.y
            }
            let extent = CGFloat(hypot(maxX - minX, maxY - minY))
            let n = Double(good.count)
            let c = CGPoint(x: 1 - sx / n, y: sy / n)   // mirror: your right = screen right
            if best == nil || extent > best!.1 { best = (c, extent) }
        }
        onHand?(best?.0, best?.1 ?? 0)
    }
}
