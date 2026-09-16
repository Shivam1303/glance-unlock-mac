import SwiftUI
import Vision

enum UnlockState: Equatable {
    case lookingForFace, faceFound, blinkOnce, checking, unlocked, notRecognized
    var message: String {
        switch self {
        case .lookingForFace: "Looking for a face"
        case .faceFound: "Face found"
        case .blinkOnce: "Blink once"
        case .checking: "Checking locally"
        case .unlocked: "Unlocked"
        case .notRecognized: "Not recognized"
        }
    }
}

@MainActor
final class UnlockViewModel: ObservableObject {
    let camera: CameraService
    // Ten analysis frames per second gives a natural blink enough samples for
    // consecutive-frame confirmation. Enrolment keeps the lower default rate.
    private let analyzer = FaceAnalyzer(interval: 0.10)
    private let featurePrintService: FeaturePrintService
    private let store: FaceProfileStore
    private var enrolled: [VNFeaturePrintObservation] = []
    private var consecutiveMatches = 0
    private var matchedEyeOpenness: [Double] = []
    private var liveness = LivenessDetector(closedConfirmationFrames: 1)
    private var isCheckingFrame = false
    private var isBlinkChallengeActive = false
    private var activeSessionID: UUID?
    private let policy: MatchPolicy
    @Published var state: UnlockState = .lookingForFace
    @Published var unlocked = false
    @Published var diagnostics: String?
    @Published private(set) var blinkInstruction = "Keep both eyes open"

    init(camera: CameraService, store: FaceProfileStore, featurePrintService: FeaturePrintService, policy: MatchPolicy = MatchPolicy(threshold: Float(UserDefaults.standard.object(forKey: "matchDistanceThreshold") as? Double ?? 12.0))) {
        self.camera = camera; self.store = store; self.featurePrintService = featurePrintService; self.policy = policy
    }

    func start() {
        do {
            enrolled = try store.load() ?? []
        } catch {
            diagnostics = error.localizedDescription
            state = .notRecognized
            return
        }
        guard !enrolled.isEmpty else {
            diagnostics = "No enrolled face profile was found."
            state = .notRecognized
            return
        }

        let sessionID = UUID()
        activeSessionID = sessionID
        consecutiveMatches = 0
        matchedEyeOpenness = []
        isCheckingFrame = false
        isBlinkChallengeActive = false
        liveness.reset()
        blinkInstruction = "Keep both eyes open"
        state = .lookingForFace
        unlocked = false
        diagnostics = nil
        camera.frameHandler = { [weak self] buffer in
            self?.analyzer.analyze(buffer) { [weak self] result in
                self?.consume(result, sessionID: sessionID)
            }
        }
        camera.requestAndStart()
    }

    func stop() {
        activeSessionID = nil
        isCheckingFrame = false
        isBlinkChallengeActive = false
        camera.frameHandler = nil
        camera.stop()
    }

    private func consume(_ result: AnalyzedFace, sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        guard result.guidance == .valid, let crop = result.crop else { resetForLostFace(); return }

        if isBlinkChallengeActive {
            guard !isCheckingFrame else { return }
            state = .blinkOnce
            let livenessState = liveness.observe(eyeOpenness: result.eyeOpenness)
            updateBlinkInstruction(for: livenessState)
            if livenessState == .passed {
                // The reopened-eye frame must match too. Closed-eye frames are
                // intentionally not feature-matched because the requested blink
                // changes their image feature print.
                checkIdentity(crop: crop, eyeOpenness: result.eyeOpenness, sessionID: sessionID, isFinalVerification: true)
            }
            return
        }

        guard !isCheckingFrame else { return }
        checkIdentity(crop: crop, eyeOpenness: result.eyeOpenness, sessionID: sessionID, isFinalVerification: false)
    }

    private func checkIdentity(crop: CGImage, eyeOpenness: Double?, sessionID: UUID, isFinalVerification: Bool) {
        state = .checking
        isCheckingFrame = true
        featurePrintService.distancesAsync(from: crop, to: enrolled) { [weak self] featureResult in
            guard let self else { return }
            guard self.activeSessionID == sessionID else { return }
            self.isCheckingFrame = false
            guard let distances = try? featureResult.get() else {
                self.diagnostics = "The current camera frame could not be compared."
                self.resetForLostFace()
                return
            }
            guard self.policy.matches(distances) else {
                self.consecutiveMatches = 0
                self.matchedEyeOpenness = []
                self.isBlinkChallengeActive = false
                self.liveness.reset()
                self.state = .notRecognized
                return
            }

            if isFinalVerification {
                // A lost face while the asynchronous final comparison was in
                // flight invalidates the completed blink challenge.
                guard self.isBlinkChallengeActive, self.liveness.state == .passed else { return }
                self.succeed()
                return
            }

            if let eyeOpenness, eyeOpenness.isFinite, eyeOpenness > 0 {
                self.matchedEyeOpenness.append(eyeOpenness)
                if self.matchedEyeOpenness.count > self.policy.requiredConsistentFrames {
                    self.matchedEyeOpenness.removeFirst()
                }
            }
            self.consecutiveMatches += 1
            guard self.consecutiveMatches >= self.policy.requiredConsistentFrames else { self.state = .faceFound; return }
            self.isBlinkChallengeActive = true
            self.liveness = self.makeCalibratedLivenessDetector()
            self.state = .blinkOnce
            let livenessState = self.liveness.observe(eyeOpenness: eyeOpenness)
            self.updateBlinkInstruction(for: livenessState)
        }
    }

    private func makeCalibratedLivenessDetector() -> LivenessDetector {
        let sorted = matchedEyeOpenness.sorted()
        let openBaseline = sorted.isEmpty ? 0.18 : sorted[sorted.count / 2]
        let openThreshold = max(0.05, openBaseline * 0.80)
        let closedThreshold = min(openThreshold - 0.02, max(0.025, openBaseline * 0.72))
        return LivenessDetector(
            confirmationFrames: 2,
            closedConfirmationFrames: 1,
            timeout: 8,
            openThreshold: openThreshold,
            closedThreshold: closedThreshold
        )
    }

    private func updateBlinkInstruction(for state: LivenessDetector.State) {
        switch state {
        case .waitingForOpen:
            blinkInstruction = "Keep both eyes open"
        case .waitingForClosed:
            blinkInstruction = "Now close both eyes"
        case .waitingForReopen:
            blinkInstruction = "Open both eyes again"
        case .passed:
            blinkInstruction = "Blink confirmed"
        }
    }

    private func resetForLostFace() {
        consecutiveMatches = 0
        matchedEyeOpenness = []
        isBlinkChallengeActive = false
        liveness.reset()
        blinkInstruction = "Keep both eyes open"
        state = .lookingForFace
    }
    private func succeed() { state = .unlocked; unlocked = true; stop() }
}
