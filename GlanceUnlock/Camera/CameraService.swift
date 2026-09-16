@preconcurrency import AVFoundation
import SwiftUI

enum CameraPermission { case notDetermined, authorized, denied, restricted }

final class CameraService: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    @Published private(set) var permission: CameraPermission = .notDetermined
    @Published private(set) var hasReceivedFrame = false
    var frameHandler: ((CMSampleBuffer) -> Void)?
    private let sessionQueue = DispatchQueue(label: "GlanceUnlock.camera.session")
    private let outputQueue = DispatchQueue(label: "GlanceUnlock.camera.output")
    private var configured = false
    private var didReceiveFrameOnOutputQueue = false

    override init() { super.init(); refreshPermission() }

    func refreshPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: permission = .authorized
        case .denied: permission = .denied
        case .restricted: permission = .restricted
        case .notDetermined: permission = .notDetermined
        @unknown default: permission = .denied
        }
    }

    func requestAndStart() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { self?.permission = granted ? .authorized : .denied }
                if granted { self?.start() }
            }
        } else { refreshPermission(); if permission == .authorized { start() } }
    }

    func start() {
        outputQueue.sync { didReceiveFrameOnOutputQueue = false }
        DispatchQueue.main.async { [weak self] in self?.hasReceivedFrame = false }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured { self.configureSession() }
            guard self.configured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() { sessionQueue.async { [weak self] in self?.session.stopRunning() } }

    private func configureSession() {
        session.beginConfiguration(); defer { session.commitConfiguration() }
        session.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        // Keep analysis pixels in their native orientation. The preview is mirrored
        // independently so Vision receives a consistent camera image.
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        configured = true
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !didReceiveFrameOnOutputQueue {
            didReceiveFrameOnOutputQueue = true
            DispatchQueue.main.async { [weak self] in self?.hasReceivedFrame = true }
        }
        frameHandler?(sampleBuffer)
    }
}
