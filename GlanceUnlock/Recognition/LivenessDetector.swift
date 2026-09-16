import Foundation

struct LivenessDetector {
    enum State: Equatable { case waitingForOpen, waitingForClosed, waitingForReopen, passed }
    private(set) var state: State = .waitingForOpen
    private(set) var consecutiveFrames = 0
    private var startedAt: Date?
    let confirmationFrames: Int
    let closedConfirmationFrames: Int
    let timeout: TimeInterval
    let openThreshold: Double
    let closedThreshold: Double

    init(
        confirmationFrames: Int = 2,
        closedConfirmationFrames: Int? = nil,
        timeout: TimeInterval = 8,
        openThreshold: Double = 0.20,
        closedThreshold: Double = 0.12
    ) {
        self.confirmationFrames = confirmationFrames
        self.closedConfirmationFrames = closedConfirmationFrames ?? confirmationFrames
        self.timeout = timeout
        self.openThreshold = openThreshold
        self.closedThreshold = closedThreshold
    }

    mutating func observe(eyeOpenness: Double?, now: Date = Date()) -> State {
        guard let eyeOpenness else { reset(); return state }
        if let startedAt, now.timeIntervalSince(startedAt) > timeout { reset() }
        if startedAt == nil { startedAt = now }
        let targetMet: Bool
        switch state {
        case .waitingForOpen, .waitingForReopen: targetMet = eyeOpenness >= openThreshold
        case .waitingForClosed: targetMet = eyeOpenness <= closedThreshold
        case .passed: return state
        }
        consecutiveFrames = targetMet ? consecutiveFrames + 1 : 0
        let requiredFrames = state == .waitingForClosed ? closedConfirmationFrames : confirmationFrames
        guard consecutiveFrames >= requiredFrames else { return state }
        consecutiveFrames = 0
        switch state {
        case .waitingForOpen: state = .waitingForClosed
        case .waitingForClosed: state = .waitingForReopen
        case .waitingForReopen: state = .passed
        case .passed: break
        }
        return state
    }

    mutating func reset() { state = .waitingForOpen; consecutiveFrames = 0; startedAt = nil }
}
