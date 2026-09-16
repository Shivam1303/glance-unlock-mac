import SwiftUI
import Vision

@MainActor
final class EnrollmentViewModel: ObservableObject {
    let camera: CameraService
    private let analyzer = FaceAnalyzer()
    private let featurePrintService: FeaturePrintService
    private let store: FaceProfileStore
    private var samples: [VNFeaturePrintObservation] = []
    private var stableFrames = 0
    private var isProcessingSample = false
    private var lastCaptureAt = Date.distantPast
    private var activeCaptureID: UUID?
    @Published var guidance: FaceGuidance = .noFace
    @Published var isComplete = false
    @Published var errorMessage: String?
    @Published private(set) var sampleCount = 0
    @Published private(set) var captureEvent = 0
    @Published private(set) var isCapturingSample = false
    let requiredSamples = 5

    init(camera: CameraService, store: FaceProfileStore, featurePrintService: FeaturePrintService) {
        self.camera = camera; self.store = store; self.featurePrintService = featurePrintService
    }

    var progressText: String { "\(sampleCount) of \(requiredSamples) captured" }

    var poseInstruction: String {
        switch sampleCount {
        case 0: "Look straight at the camera"
        case 1: "Turn slightly to your left"
        case 2: "Turn slightly to your right"
        case 3: "Look forward with a relaxed expression"
        default: "One final straight-ahead sample"
        }
    }

    func start() {
        guard samples.count < requiredSamples, !isComplete else { return }
        let captureID = UUID()
        activeCaptureID = captureID
        camera.frameHandler = { [weak self] buffer in
            self?.analyzer.analyze(buffer) { [weak self] result in
                self?.consume(result, captureID: captureID)
            }
        }
        camera.requestAndStart()
    }

    func stop() {
        activeCaptureID = nil
        stableFrames = 0
        isProcessingSample = false
        isCapturingSample = false
        camera.frameHandler = nil
        camera.stop()
    }

    private func consume(_ result: AnalyzedFace, captureID: UUID) {
        guard activeCaptureID == captureID else { return }
        guidance = result.guidance
        guard result.guidance == .valid,
              let crop = result.crop,
              samples.count < requiredSamples,
              !isComplete else {
            stableFrames = 0
            return
        }
        stableFrames += 1
        guard stableFrames >= 3,
              !isProcessingSample,
              Date().timeIntervalSince(lastCaptureAt) >= 0.9 else { return }
        stableFrames = 0
        isProcessingSample = true
        isCapturingSample = true
        featurePrintService.makeFeaturePrintAsync(from: crop) { [weak self] result in
            guard let self else { return }
            guard self.activeCaptureID == captureID else { return }
            self.isProcessingSample = false
            self.isCapturingSample = false
            switch result {
            case .success(let feature):
                guard self.samples.count < self.requiredSamples else { return }
                self.samples.append(feature)
                self.sampleCount = self.samples.count
                self.captureEvent += 1
                self.lastCaptureAt = Date()
                if self.samples.count == self.requiredSamples {
                    // Invalidate analysis callbacks and release the camera before
                    // performing storage. Exactly five samples is a terminal
                    // capture state even if Keychain storage reports an error.
                    self.stop()
                    do {
                        try self.store.save(self.samples)
                        self.isComplete = true
                    } catch {
                        self.errorMessage = "Face samples were captured, but the profile could not be saved securely. No password was requested. \(error.localizedDescription)"
                    }
                }
            case .failure:
                self.errorMessage = "This camera frame could not form a local face representation. Move a little closer, hold still, then try again."
            }
        }
    }
}
