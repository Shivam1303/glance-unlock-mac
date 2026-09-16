import Foundation

struct MatchPolicy {
    var threshold: Float = 12.0
    var requiredConsistentFrames = 3

    func aggregate(_ distances: [Float]) -> Float? {
        guard distances.count >= 3 else { return nil }
        let best = distances.sorted().prefix(3)
        return best.reduce(0, +) / Float(best.count)
    }

    func matches(_ distances: [Float]) -> Bool { guard let score = aggregate(distances) else { return false }; return score <= threshold }
}
